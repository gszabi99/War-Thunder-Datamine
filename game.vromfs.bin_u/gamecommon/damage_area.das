require ecs
require DagorMath
require DagorDebug3D
require DagorConsole
require DagorRandom
require GamePhys
require level
require Mission
require WTDamageModel
require WTFx
require DmDebug
require DagorSystem
require %dasGameLibs.math.base
require %game.utils.utils_common


[es(on_appear)]
def damage_area_init(evt : Event;
                     var damage_area__vel : float3&;
                     damage_area__fallVel : float3;
                     damage_area__velocityMult : float;
                     damage_area__maxRise : float)
  let vel = damage_area__fallVel * damage_area__velocityMult
  let speed = length(vel)
  let verSpeed = min(abs(vel.y), sqrt(2. * damage_area__maxRise * gravity()))
  let horSpeed = sqrt(square(speed) - square(verSpeed))
  var horVel = float2(vel.x, vel.z)
  horVel = normalize(horVel) * horSpeed
  damage_area__vel.x = horVel.x
  damage_area__vel.y = verSpeed
  damage_area__vel.z = horVel.y


[es(tag=gameClient, on_appear, after=damage_area_init)]
def damage_area_init_client_es(evt : Event;
                               damage_area__emitterCount : int;
                               damage_area__emitterDispersion : float;
                               damage_area__pos1 : float3;
                               damage_area__vel : float3;
                               damage_area__radius : float;
                               damage_area__maxFlightDist : float;
                               damage_area__fxType : string;
                               var damage_area__emitterVel : Point3List&;
                               var damage_area__emitterPos : Point3List&;
                               var damage_area__emitterPosPrev : Point3List&;
                               var damage_area__emitterFxIds : IntList&;
                               var damage_area__burnFxCounts : IntList&;
                               damage_area__fallVel : float3;
                               damage_area__debugCommonId, damage_area__debugTraceId : int)
  let dir = normalize(damage_area__vel) * damage_area__maxFlightDist
  let len = length(damage_area__vel)
  let left = normalize(float3(-damage_area__vel.z, 0., damage_area__vel.x)) * damage_area__radius
  let dir1 = normalize(dir + left)
  let dir2 = normalize(dir - left)
  for i in range(damage_area__emitterCount)
    var curVel = len * normalize(dir1 * float(i) + dir2 * float(damage_area__emitterCount - i - 1))
    curVel.y *= rnd_float(1. - damage_area__emitterDispersion, 1. + damage_area__emitterDispersion)
    damage_area__emitterVel |> push(curVel)
    let fxId = damage_area_create_fx(damage_area__fxType, damage_area__pos1, curVel, true)
    damage_area__emitterFxIds |> push(fxId)
    damage_area__emitterPos |> push(damage_area__pos1)
    damage_area__emitterPosPrev |> push(damage_area__pos1)
    damage_area__burnFxCounts |> push(0)
  let dbgId = int(DmDebugTool.DAMAGE_AREA)
  if (is_dm_dbg_tool_enabled(dbgId))
    dm_dbg_render_clear(dbgId, damage_area__debugCommonId)
    dm_dbg_render_clear(dbgId, damage_area__debugTraceId)
    let fallVecColor = E3DCOLOR(0xFF00FF00)
    let p1 = damage_area__pos1 - damage_area__fallVel
    dm_dbg_render_add_line_3d(dbgId, damage_area__debugTraceId, damage_area__pos1, p1, fallVecColor)


[es(tag=gameClient, on_disappear)]
def damage_area_destroy_client_es(evt : Event;
                                  damage_area__emitterFxIds : IntList;
                                  damage_area__burnFxIds : IntList)
  for emitterFxId in damage_area__emitterFxIds
    damage_area_destroy_fx(emitterFxId)
  for burnFxId in damage_area__burnFxIds
    damage_area_destroy_fx(burnFxId)


[es(no_order)]
def damage_area_update_es(act : UpdateStageInfoAct;
                          var damage_area__move : bool&;
                          var damage_area__pos2 : float3&;
                          var damage_area__pos2_prev : float3&;
                          var damage_area__vel : float3&;
                          damage_area__pos1 : float3;
                          var damage_area__flightTime : float&;
                          damage_area__radius : float;
                          damage_area__maxFlightTime, damage_area__maxFlightDist : float)
  if (damage_area__move && (damage_area__flightTime > damage_area__maxFlightTime || length(damage_area__pos1 - damage_area__pos2) > damage_area__maxFlightDist))
    damage_area__move = false
  if (damage_area__move)
    damage_area__pos2_prev = damage_area__pos2
    damage_area__vel.y -= act.dt * gravity()
    damage_area__pos2 += act.dt * damage_area__vel
    damage_area__flightTime += act.dt
    let height = get_scene_height(damage_area__pos2, true)
    if (damage_area__pos2.y < height)
      if (height - damage_area__pos2.y > damage_area__radius)
        damage_area__move = false
      damage_area__pos2.y = height


[es(tag=server, after=damage_area_update_es)]
def damage_area_update_server_es(act : UpdateStageInfoAct;
                                 eid : EntityId;
                                 damage_area__pos1, damage_area__pos2 : float3;
                                 damage_area__endTime, damage_area__radius, damage_area__damage : float;
                                 damage_area__damageTypeId, damage_area__seed : int;
                                 damage_area__offender : OffenderData;
                                 var damage_area__nextUpdateTime : float&)
  if (act.curTime > damage_area__nextUpdateTime)
    damage_area__nextUpdateTime = act.curTime + 1.
    var pos2 = damage_area__pos2
    pos2.y = get_scene_height(damage_area__pos2, false)
    volumetric_damage(damage_area__pos1, pos2, damage_area__radius,
      damage_area__damage, damage_area__damageTypeId, damage_area__offender, damage_area__seed)
  elif (act.curTime >= damage_area__endTime)
    destroyEntity(eid)


[es(tag=gameClient, after=damage_area_update_es)]
def damage_area_update_client_es(act : UpdateStageInfoAct;
                                 eid : EntityId;
                                 damage_area__pos1 : float3;
                                 damage_area__pos2 : float3;
                                 damage_area__radius : float;
                                 damage_area__move : bool;
                                 var damage_area__firstTick : bool&;
                                 damage_area__emitterCount : int;
                                 var damage_area__emitterVel : Point3List&;
                                 var damage_area__emitterPos : Point3List&;
                                 var damage_area__emitterPosPrev : Point3List&;
                                 damage_area__emitterFxIds : IntList;
                                 damage_area__burnFxType : string;
                                 damage_area__burnFxSize : float;
                                 var damage_area__burnFxIds : IntList&;
                                 var damage_area__burnFxCounts : IntList&;
                                 damage_area__debugCommonId, damage_area__debugTraceId : int;
                                 damage_area__debugEmitterColor, damage_area__debugTraceColor, damage_area__debugCombustColor : E3DCOLOR)
  if (damage_area__move || damage_area__firstTick)
    damage_area__firstTick = false
    let up = float3(1., 0., 0.)
    for i in range(damage_area__emitterCount)
      damage_area__emitterPosPrev[i] = damage_area__emitterPos[i]
      damage_area__emitterVel[i].y -= act.dt * gravity()
      damage_area__emitterPos[i] += act.dt * damage_area__emitterVel[i]
      let height = get_scene_height(damage_area__emitterPos[i], true)
      if (damage_area__emitterPos[i].y < height)
        damage_area__emitterPos[i].y = height
      attach_fire_to_units(damage_area__emitterPosPrev[i], damage_area__emitterPos[i], damage_area__radius)
      if (damage_area__emitterFxIds[i] >= 0)
        var emitterPos = damage_area__emitterPos[i]
        emitterPos.y += 0.1
        damage_area_update_fx(damage_area__emitterFxIds[i], damage_area__emitterPos[i], up, 1.)
      
      var count = 1
      if (damage_area__burnFxSize > 0.)
        count = 1 + int(length(damage_area__pos1 - damage_area__emitterPos[i]) / damage_area__burnFxSize)
      if (damage_area__burnFxCounts[i] < count)
        let dir = normalize(damage_area__emitterPos[i] - damage_area__pos1)
        for j in range(damage_area__burnFxCounts[i], count)
          var fxPos = damage_area__pos1 + dir * (damage_area__burnFxSize * float(j))
          if j > 0
            fxPos.y = get_scene_height(fxPos, false)
          let burnFxId = damage_area_create_fx(damage_area__burnFxType, fxPos, up, true)
          damage_area__burnFxIds |> push(burnFxId)
        damage_area__burnFxCounts[i] = count
    
    let dbgId = int(DmDebugTool.DAMAGE_AREA)
    if (is_dm_dbg_tool_enabled(dbgId))
      dm_dbg_render_clear(dbgId, damage_area__debugCommonId)
      for i in range(damage_area__emitterCount)
        dm_dbg_render_add_line_3d(dbgId, damage_area__debugTraceId, damage_area__emitterPos[i], damage_area__emitterPosPrev[i], damage_area__debugTraceColor)
      if (is_dm_dbg_tool_enabled(dbgId))
        dm_dbg_render_add_sph(dbgId, damage_area__debugCommonId, damage_area__pos2, damage_area__radius * 1.1, damage_area__debugEmitterColor)
        var pos2 = damage_area__pos2
        pos2.y = get_scene_height(damage_area__pos2, false)
        dm_dbg_render_add_capsule(dbgId, damage_area__debugCommonId, damage_area__pos1, pos2, damage_area__radius, damage_area__debugCombustColor)
  attach_fire_to_wheels(damage_area__pos1, damage_area__pos2, damage_area__radius, eid)


[es(tag=gameClient, track=damage_area__move)]
def damage_area_move_track_es(evt : Event;
                              damage_area__move : bool;
                              damage_area__pos1, damage_area__pos2 : float3;
                              damage_area__radius : float;
                              var damage_area__emitterFxIds : IntList&;
                              damage_area__scorchMarginSize, damage_area__scorchStrength, damage_area__scorchDuration : float;
                              damage_area__debugTraceId : int)
  if (!damage_area__move && damage_area__scorchStrength > 0. && damage_area__scorchDuration > 0.)
    for fxId in damage_area__emitterFxIds
      damage_area_destroy_fx(fxId)
    damage_area__emitterFxIds |> clear()
    let pos1 = float2(damage_area__pos1.x, damage_area__pos1.z)
    let pos2 = float2(damage_area__pos2.x, damage_area__pos2.z)
    let decalDir = normalize(pos2 - pos1)
    let len = length(pos1 - pos2) * 0.5
    let decalLen = len + damage_area__radius
    let decalPos = pos1 + decalDir * len
    let decalSize = float2(decalLen + damage_area__scorchMarginSize, damage_area__radius + damage_area__scorchMarginSize)
    add_burning_decals(decalPos, decalDir, decalSize, damage_area__scorchStrength, damage_area__scorchDuration)
    
    let dbgId = int(DmDebugTool.DAMAGE_AREA)
    if (is_dm_dbg_tool_enabled(dbgId))
      let scorchColor = E3DCOLOR(0xFF000000)
      let left = float2(-decalDir.y, decalDir.x)
      let pp0 = decalPos - decalDir * decalSize.x - left * decalSize.y
      let p0 = float3(pp0.x, damage_area__pos1.y, pp0.y)
      let pp1 = decalPos + decalDir * decalSize.x - left * decalSize.y
      let p1 = float3(pp1.x, damage_area__pos1.y, pp1.y)
      let pp2 = decalPos + decalDir * decalSize.x + left * decalSize.y
      let p2 = float3(pp2.x, damage_area__pos1.y, pp2.y)
      let pp3 = decalPos - decalDir * decalSize.x + left * decalSize.y
      let p3 = float3(pp3.x, damage_area__pos1.y, pp3.y)
      dm_dbg_render_add_line_3d(dbgId, damage_area__debugTraceId, p0, p1, scorchColor)
      dm_dbg_render_add_line_3d(dbgId, damage_area__debugTraceId, p1, p2, scorchColor)
      dm_dbg_render_add_line_3d(dbgId, damage_area__debugTraceId, p2, p3, scorchColor)
      dm_dbg_render_add_line_3d(dbgId, damage_area__debugTraceId, p3, p0, scorchColor)
