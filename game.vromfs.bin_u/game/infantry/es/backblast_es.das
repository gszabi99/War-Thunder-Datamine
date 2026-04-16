require ecs
require DagorSystem
require %appGame.infantry.es.concussion_common
require %appGame.infantry.es.hitpoints_common
require %appGame.infantry.es.team_common
require %appGame.wt_events
require %game.events
require PropsManager
require math.base
require DagorMath
require Grid
require AnimV20
require GeomNodeTree
require Dacoll
require DagorDebug3D
require %appGame.es.render.draw_debug_utils_common


[es(tag=server, on_appear)]
def human_backblast_bone_init_es(evt : Event;
                                 eid : EntityId;
                                 human__backblastCheckBoneNames : StringList;
                                 var human__backblastCheckBoneIds : IntList;
                                 animchar : AnimcharBaseComponent)
  for boneName in human__backblastCheckBoneNames
    let nodeIdx = *animchar.nodeTree |> geomtree_findNodeIndex(string(boneName))
    push(human__backblastCheckBoneIds, nodeIdx)
    if nodeIdx < 0
      logerr("{getEntityTemplateName(eid)} backblast bone not found: {boneName}")


[es(tag=server)]
def gun_backblast_create_on_launch_es(evt : CmdLaunchProjectile;
                                      eid : EntityId)
  let gunEid = evt.gunEid
  let launchTm = evt.launchDesc.tm
  let owner = eid
  query(gunEid) <| $ [es] (backblast__coneHeight : float;
                           backblast__coneAngle : float;
                           backblast__maxConcussionIntensity : float;
                           backblast__maxDamage : float;
                           backblast__concussionDuration : float;
                           backblast__reflectedRadius : float;
                           backblast__reflectedMaxConcussionIntensity : float;
                           backblast__reflectedConcussionDuration : float;
                           backblast__reflectedTraceLen : float;
                           backblast__reflectedTraceSpreadAngle : float;
                           backblast__reflectedNumTraces : int;
                           gun__backblastOffset : float = 0.85)
    let shootDir = normalize(launchTm[0])
    let coneVertexPos = launchTm[3] - shootDir * gun__backblastOffset
    let coneDir = -shootDir
    let gunPropsId = int(props_pack_for_net(evt.launchDesc.gunPropsId))

    let ownerTeam = get_int(owner, "team") ?? TEAM_UNASSIGNED
    let angleRad = deg_to_rad(backblast__coneAngle / 2.0)
    let coneCos = cos(angleRad)
    let coneRadius = backblast__coneHeight * tan(angleRad)
    let sphereCenterRad = (square(backblast__coneHeight) + square(coneRadius)) / (2.0 * backblast__coneHeight)
    let spherePos = coneVertexPos + coneDir * sphereCenterRad
    let sphere = BSphere3(spherePos, 2.0 * sphereCenterRad)
    for_each_entity_in_grid(ecs_hash("humans"), sphere, GridEntCheck.BOUNDING) <| $(human_eid : EntityId)
      if human_eid == owner
        return
      query(human_eid) <| $ [es(REQUIRE_NOT=deadEntity)] (human__backblastCheckBoneIds : IntList;
                                                          animchar : AnimcharBaseComponent;
                                                          isInVehicleHidden : bool = false;
                                                          team : int = TEAM_UNASSIGNED)
        if isInVehicleHidden
          return
        var pointsInsideCone : array<float3>
        for nodeIdx in human__backblastCheckBoneIds
          if nodeIdx < 0
            continue
          let bonePos = *animchar.nodeTree |> geomtree_getNodeWpos(nodeIdx)
          let distToSphereCenter = length(bonePos - spherePos)
          if distToSphereCenter > sphereCenterRad
            continue
          let dir = bonePos - coneVertexPos
          let targetCos = dot(normalize(dir), normalize(coneDir))
          if targetCos < coneCos
            continue
          push(pointsInsideCone, bonePos)
        sort(pointsInsideCone) <| $(lhs, rhs : float3)
          return length(lhs - coneVertexPos) < length(rhs - coneVertexPos)
        var closestDist = -1.0
        for point in pointsInsideCone
          let dir = point - coneVertexPos
          let len = length(dir)
          let d = normalize(dir)
          if !rayhit_normalized(coneVertexPos, d, len, ETF_DEFAULT, -1)
            closestDist = len
            break
        if closestDist >= 0.0
          let intens      = cvt(closestDist, 0.0, backblast__coneHeight, backblast__maxConcussionIntensity, 0.0)
          let damageVal   = cvt(closestDist, 0.0, backblast__coneHeight, backblast__maxDamage, 0.0)
          enable_concussion_affect([
                owner_eid=human_eid,
                duration=backblast__concussionDuration,
                intensity=intens,
                is_blocks_sprint=false,
                look_sens_mult=1.0,
                look_inertia=0.0,
                move_inertia=0.0
              ])
          if !is_teams_friendly(team, ownerTeam)
            sendEvent(human_eid, CmdApplyDamage(
              offender = owner,
              damageType = int(DamageType.DM_FIRE),
              shellId = props_pack_for_net(PropsId()),
              gunPropsId = uint(gunPropsId),
              deltaHp = float(damageVal),
              hitPos = coneVertexPos))

    if backblast__reflectedRadius > 0.0
      apply_reflected_backblast(
        coneVertexPos,
        coneDir,
        backblast__reflectedTraceLen,
        backblast__reflectedTraceSpreadAngle,
        backblast__reflectedNumTraces,
        backblast__reflectedRadius,
        backblast__reflectedMaxConcussionIntensity,
        backblast__reflectedConcussionDuration)


def private apply_reflected_backblast(cone_vertex_pos : float3;
                                      cone_dir : float3;
                                      trace_len : float;
                                      spread_angle_deg : float;
                                      num_traces : int;
                                      radius : float;
                                      max_intensity : float;
                                      concussion_duration : float)
  let ref_up = abs(dot(cone_dir, float3(0.0, 1.0, 0.0))) > 0.99 ? float3(1.0, 0.0, 0.0) : float3(0.0, 1.0, 0.0)
  let right = normalize(cross(cone_dir, ref_up))
  let local_up = cross(right, cone_dir)

  let spread_tan = tan(deg_to_rad(spread_angle_deg))
  var trace_dirs : array<float3>
  push(trace_dirs, cone_dir)
  for i in range(num_traces - 1)
    let angle = float(i) / float(num_traces - 1) * PI * 2.0
    push(trace_dirs, normalize(cone_dir + (right * cos(angle) + local_up * sin(angle)) * spread_tan))

  var dbg_frames = 0
  find_query() <| $ [es(REQUIRE=backblastReflectedDebug)] (backblast_reflected_debug__frames : int)
    dbg_frames = backblast_reflected_debug__frames
    return true

  let offset_by_normal = 0.1
  var offset_points : array<float3>
  for trace_dir in trace_dirs
    if dbg_frames > 0
      draw_debug_line_buffered(cone_vertex_pos, cone_vertex_pos + trace_dir * trace_len, E3DCOLOR(0xFF00FFFF), dbg_frames)
    var t = trace_len
    var hit_norm : float3
    if traceray_normalized(cone_vertex_pos, trace_dir, t, hit_norm, ETF_DEFAULT | ETF_RI_PHYS)
      if t > 0.1
        let hit_pos = cone_vertex_pos + trace_dir * t
        let offset_pos = hit_pos + hit_norm * offset_by_normal
        push(offset_points, offset_pos)
        if dbg_frames > 0
          draw_debug_sphere_buffered(offset_pos, 0.05, E3DCOLOR(0xFFFFFF00), 120, dbg_frames)
          draw_debug_text_mark_buffered(offset_pos, "hit t={t}", dbg_frames, E3DCOLOR(0xFFFFFF00))

  let num_hits = length(offset_points)
  if num_hits == 0
    return

  var center = float3(0.0, 0.0, 0.0)
  for pt in offset_points
    center += pt
  center /= float(num_hits)

  if dbg_frames > 0
    draw_debug_sphere_buffered(center, 0.15, E3DCOLOR(0xFF00FF00), 12, dbg_frames)

  let to_center = center - cone_vertex_pos
  let to_center_len = length(to_center)
  if to_center_len > 0.01
    let to_center_dir = to_center / to_center_len
    var val_t = to_center_len
    var val_norm : float3
    if traceray_normalized(cone_vertex_pos, to_center_dir, val_t, val_norm, ETF_DEFAULT | ETF_RI_PHYS)
      center = cone_vertex_pos + to_center_dir * val_t

  if dbg_frames > 0
    draw_debug_sphere_buffered(center, 0.15, E3DCOLOR(0xFFFF0000), 120, dbg_frames)
    draw_debug_sphere_buffered(center, radius, E3DCOLOR(0xFFFF0000), 120, dbg_frames)
    draw_debug_text_mark_buffered(center, "reflected wave center, r={radius}", dbg_frames, E3DCOLOR(0xFFFF0000))

  for_each_entity_in_grid(ecs_hash("humans"), BSphere3(center, radius), GridEntCheck.BOUNDING) <| $(human_eid : EntityId)
    query(human_eid) <| $ [es(REQUIRE_NOT=deadEntity)] (human__backblastCheckBoneIds : IntList;
                                                        human__backblastCheckBoneNames : StringList;
                                                        animchar : AnimcharBaseComponent;
                                                        isInVehicleHidden : bool = false)
      if isInVehicleHidden
        return
      var closestDist = -1.0
      for nodeIdx, i in human__backblastCheckBoneIds, range(length(human__backblastCheckBoneIds))
        if nodeIdx < 0
          continue
        let bone_pos = *animchar.nodeTree |> geomtree_getNodeWpos(nodeIdx)
        let d = length(bone_pos - center)
        if d > radius
          continue
        let dir = bone_pos - center
        let dir_n = normalize(dir)
        if d > 0.01 && rayhit_normalized(center, dir_n, d, ETF_DEFAULT | ETF_RI_PHYS, -1)
          continue
        if dbg_frames > 0
          draw_debug_sphere_buffered(bone_pos, 0.05, E3DCOLOR(0xFFFF00FF), 120, dbg_frames)
          draw_debug_text_mark_buffered(bone_pos, "bone ({human__backblastCheckBoneNames[i]}) hit d={d}", dbg_frames, E3DCOLOR(0xFFFF00FF))

        if closestDist < 0.0 || d < closestDist
          closestDist = d
      if closestDist < 0.0
        return
      let dist_factor = 1.0 - (closestDist / radius)
      let intens = max_intensity * dist_factor
      if dbg_frames > 0
        let rootPos = *animchar.nodeTree |> geomtree_getNodeWpos(0)
        draw_debug_text_mark_buffered(rootPos, "concussion for soldier {human_eid}: int={intens} dur={concussion_duration}", dbg_frames, E3DCOLOR(0xFFFF00FF))
      enable_concussion_affect([
        owner_eid = human_eid,
        duration = concussion_duration,
        intensity = intens,
        is_blocks_sprint = false,
        look_sens_mult = 1.0,
        look_inertia = 0.0,
        move_inertia = 0.0])
