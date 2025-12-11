require ecs
require ecs.common
require math
require math.base
require DagorMath
require DagorMathUtils
require WTInput
require DagorSystem
require SmokeOccluder
require GridCollision
require HumanPhys
require DngWeapon
require DngHuman
require DaWeapons
require AnimV20
require GeomNodeTree
require CollRes
require Dacoll
require RendInst
require %game.events
require %game.input.input_events
require %appGame.infantry.input.aim_assist_common
require %appGame.infantry.es.team_common
require %appGame.infantry.es.human_weap_common


[es(tag=input, on_appear)]
def aim_assist_init_es(evt : Event;
                       var aim_assist__targetMaxAngle : float&;
                       aim_assist__slowdownMaxAngle : float = 0.0;
                       aim_assist__onAimingStartAngles : float2 = float2(0.0, 0.0);
                       aim_assist__rotationAimMaxAngle : float = 0.0)
  aim_assist__targetMaxAngle = max(aim_assist__targetMaxAngle, aim_assist__slowdownMaxAngle)
  aim_assist__targetMaxAngle = max(aim_assist__targetMaxAngle, aim_assist__onAimingStartAngles.y)
  aim_assist__targetMaxAngle = max(aim_assist__targetMaxAngle, aim_assist__rotationAimMaxAngle)


[es(on_appear)]
def aim_assist_node_load_es(evt : Event;
                            eid : EntityId;
                            animchar : AnimcharBaseComponent;
                            aim_assist_target__nodeName : string;
                            var aim_assist_target__nodeIdx : int&)
  aim_assist_target__nodeIdx = geomtree_findNodeIndex(*animchar.nodeTree, aim_assist_target__nodeName)
  if aim_assist_target__nodeIdx < 0
    logerr("aim_assist_target__nodeName /*{aim_assist_target__nodeName}*/ not found in entity /*{eid}*/=/*{getEntityTemplateName(eid)}*/")


[es(tag=input, on_appear)]
def aim_assist_target_nodes_on_appear(evt : Event;
                                      collres : CollisionResource;
                                      aim_assist_target__skipNodeNames : StringList;
                                      var aim_assist_target__nodeIds : IntList)
  for nodeId in range(0, collres_get_nodesCount(collres))
    let node = collres_get_node(collres, nodeId)
    let nodeName = collnode_get_name(node)
    if find_index(aim_assist_target__skipNodeNames, nodeName) < 0
      push(aim_assist_target__nodeIds, nodeId)


[es(tag=input, after=after_animchar_update_sync)]
def aim_assist_target_es(info : ParallelUpdateFrameDelayed;
                         eid : EntityId;
                         human_weap__currentGunEid : EntityId;
                         human_weap__currentGunModEids : EidList;
                         human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID;
                         human_net_phys : HumanActor;
                         team : int;
                         human_input__aimAngle : float2&;
                         aim_assist__enabled : bool;
                         aim_assist__targetMaxDist : float;
                         aim_assist__targetMaxAngle : float;
                         aim_assist__targetConeWidth : float;
                         var aim_assist__targetPos : float3&;
                         var aim_assist__targetEid : EntityId&;
                         var aim_assist__targetAngleCos : float&;
                         var aim_assist__targetDist : float&;
                         var aim_assist__targetDir : float3&;
                         nodes_los__minSmokeTraceDist : float = 7.;
                         aim_assist__gunmodZoomFactorMult : float = 0.5)
  aim_assist__targetEid = INVALID_ENTITY_ID
  if !aim_assist__enabled || !is_human_allowed_shooting(eid, human_attached_gun__attachedGunEid, human_net_phys)
    return
  if !is_control_bit_set(human_net_phys.phys.producedCT, HumanPhysControlType.HCT_AIM) && !is_control_bit_set(human_net_phys.phys.producedCT, HumanPhysControlType.HCT_ZOOM_VIEW)
    return

  let shootDir = angles_to_dir(human_input__aimAngle + lerp(human_net_phys.phys.previousState.breathOffset, human_net_phys.phys.currentState.breathOffset, float2(get_phys_interpk_clamped(human_net_phys.phys, info.curTime))))
  var shootPos : float3
  ecs::query(human_attached_gun__attachedGunEid != INVALID_ENTITY_ID ? human_attached_gun__attachedGunEid : human_weap__currentGunEid) <| $ [es] (gun : Gun)
    shootPos = gun.gunTm[3]

  var targetMaxDist = aim_assist__targetMaxDist
  for modEid in human_weap__currentGunModEids
    ecs::query(modEid) <| $ [es(REQUIRE=gunScope)] (gunmod__zoomFactor : float)
      targetMaxDist *= max(gunmod__zoomFactor * aim_assist__gunmodZoomFactorMult, aim_assist__targetMaxDist)

  var targets <- get_assist_targets(shootPos, shootDir, aim_assist__targetMaxDist, aim_assist__targetConeWidth * 1.5, cos(deg_to_rad(aim_assist__targetMaxAngle)), team)
  for target in targets
    var t = target.dist + 0.5
    var norm : float3
    if traceray_normalized(shootPos, target.dir, t, norm)
      continue
    if rayhit_entities_in_grid(ecs_hash("vehicles"), shootPos, target.dir, t, INVALID_ENTITY_ID)
      continue
    if traceTransparencyRayRIGenNormalized(shootPos, target.dir, target.dist, 0.01)
      continue
    if t > nodes_los__minSmokeTraceDist && rayhit_smoke_occluders(shootPos, target.pos)
      continue
    aim_assist__targetEid = target.eid
    aim_assist__targetAngleCos = target.dp
    aim_assist__targetDist = target.dist
    aim_assist__targetDir = target.dir
    aim_assist__targetPos = target.pos
    break

[es(tag=input)]
def aim_assist_slowdown_es(info : UpdateStageUpdateInput;
                           var human_input__aimingSensMult : float&;
                           aim_assist__targetEid : EntityId;
                           aim_assist__targetAngleCos : float;
                           aim_assist__targetDist : float;
                           aim_assist__targetConeWidth : float;
                           aim_assist__slowdownEnabled : bool;
                           human_input__aimAngle : float2;
                           human_attached_gun__attachedGunEid : EntityId;
                           human_weap__currentGunEid : EntityId;
                           aim_assist__rotationTargetNodeId : int;
                           aim_assist__slowdownMaxAngle : float;
                           aim_assist__slowdownSensMult : float)
  human_input__aimingSensMult = 1.0
  if !aim_assist__slowdownEnabled || !aim_assist__targetEid
    return
  var assistProgress = 0.
  if aim_assist__rotationTargetNodeId != -1
    query(aim_assist__targetEid) <| $ [es] (collres : CollisionResource;
                                            animchar : AnimcharBaseComponent;
                                            transform : float3x4)
      var ntm = IDENT_TM
      collres_get_collision_node_tm(collres, aim_assist__rotationTargetNodeId, transform, animchar.nodeTree, ntm)
      var shootPos : float3
      ecs::query(human_attached_gun__attachedGunEid != INVALID_ENTITY_ID ? human_attached_gun__attachedGunEid : human_weap__currentGunEid) <| $ [es] (gun : Gun)
        shootPos = gun.gunTm[3]
      let nodeDist = distance(ntm[3], shootPos)
      let nodeDir = normalize(ntm[3] - shootPos)
      let shootDir = angles_to_dir(human_input__aimAngle)
      let nodeAngleCos = dot(shootDir, nodeDir)
      assistProgress = get_assist_angle_progress(nodeDist, nodeAngleCos,
                                                 aim_assist__slowdownMaxAngle, aim_assist__targetConeWidth)
  else
    assistProgress = get_assist_angle_progress(aim_assist__targetDist, aim_assist__targetAngleCos,
                                                 aim_assist__slowdownMaxAngle, aim_assist__targetConeWidth)
  if assistProgress != 0.0
    human_input__aimingSensMult = aim_assist__slowdownSensMult


[es(tag=input, after=aim_assist_slowdown_es)]
def aim_assist_on_aim_start_es(info : UpdateStageUpdateInput;
                               human_net_phys : HumanActor;
                               var human_input__aimAngle : float2&;
                               aim_assist__targetEid : EntityId;
                               aim_assist__targetConeWidth : float;
                               aim_assist__targetAngleCos : float;
                               aim_assist__targetDist : float;
                               aim_assist__targetDir : float3&;
                               aim_assist__onAimingStartEnabled : bool;
                               aim_assist__onAimingStartAngles : float2;
                               var aim_assist__onAimingStartProgress : float&)
  if !aim_assist__targetEid
    return

  if aim_assist__onAimingStartEnabled && aim_assist__targetEid != INVALID_ENTITY_ID
    let aimProgress = lerp(human_net_phys.phys.previousState.aimPosition,
                           human_net_phys.phys.currentState.aimPosition,
                           get_phys_interpk_clamped(human_net_phys.phys, info.curTime))
    if human_net_phys.phys.currentState.aimPosition > human_net_phys.phys.previousState.aimPosition && aimProgress > aim_assist__onAimingStartProgress
      let minAngleCheck = get_assist_angle_progress(aim_assist__targetDist, aim_assist__targetAngleCos,
                                                    aim_assist__onAimingStartAngles.x, aim_assist__targetConeWidth)
      let maxAngleCheck = get_assist_angle_progress(aim_assist__targetDist, aim_assist__targetAngleCos,
                                                    aim_assist__onAimingStartAngles.y, aim_assist__targetConeWidth)
      if (minAngleCheck == 0.0 || aim_assist__onAimingStartProgress > 0.f) && maxAngleCheck != 0.0
        let aimAssist = aimProgress - aim_assist__onAimingStartProgress
        let wishAngle = dir_to_angles(aim_assist__targetDir)
        human_input__aimAngle += angle_diff(human_input__aimAngle, wishAngle) * aimAssist
        aim_assist__onAimingStartProgress = aimProgress

[es(tag=input, before=(aim_assist_rotating_aim_es, aim_assist_slowdown_es, aim_assist_on_aim_start_es))]
def aim_assist_move_compensation_es(info : UpdateStageUpdateInput;
                                    aim_assist__moveCompensationEnabled : bool;
                                    aim_assist__moveCompensationScale : float;
                                    var aim_assist__moveCompensationTargetEid : EntityId&;
                                    var aim_assist__moveCompensationPrevAngle : float2&;
                                    var aim_assist__targetPrevPos : float3&;
                                    aim_assist__targetPos : float3;
                                    transform : float3x4;
                                    aim_assist__targetEid : EntityId;
                                    var human_input__aimAngle : float2&;
                                    human_attached_gun__attachedGunEid : EntityId;
                                    human_weap__currentGunEid : EntityId)
  if !aim_assist__moveCompensationEnabled || !aim_assist__targetEid
    aim_assist__moveCompensationTargetEid = INVALID_ENTITY_ID
    return

  var shootPos : float3
  query(human_attached_gun__attachedGunEid != INVALID_ENTITY_ID ? human_attached_gun__attachedGunEid : human_weap__currentGunEid) <| $ [es] (gun : Gun)
    shootPos = gun.gunTm[3]

  if aim_assist__moveCompensationTargetEid != aim_assist__targetEid
    aim_assist__moveCompensationTargetEid = aim_assist__targetEid
    aim_assist__targetPrevPos = aim_assist__targetPos
    aim_assist__moveCompensationPrevAngle = dir_to_angles(normalize(aim_assist__targetPos - transform[3]))
    return

  let angleToPrevTargetPos = dir_to_angles(normalize(aim_assist__targetPrevPos - transform[3]))
  let availableCompensationAngleDiff = angle_diff(angleToPrevTargetPos, aim_assist__moveCompensationPrevAngle)

  let wishAngle = dir_to_angles(normalize(aim_assist__targetPos - shootPos))
  let wishAngleDiff = angle_diff(wishAngle, human_input__aimAngle)

  aim_assist__targetPrevPos = aim_assist__targetPos
  aim_assist__moveCompensationPrevAngle = dir_to_angles(normalize(aim_assist__targetPos - transform[3]))
  if sign(wishAngleDiff.x) == sign(availableCompensationAngleDiff.x)
    human_input__aimAngle.x -= sign(wishAngleDiff.x) * min(abs(wishAngleDiff.x), abs(availableCompensationAngleDiff.x)) * aim_assist__moveCompensationScale
  if sign(wishAngleDiff.y) == sign(availableCompensationAngleDiff.y)
    human_input__aimAngle.y -= sign(wishAngleDiff.y) * min(abs(wishAngleDiff.y), abs(availableCompensationAngleDiff.y)) * aim_assist__moveCompensationScale


[es(tag=input, after=aim_assist_on_aim_start_es)]
def aim_assist_on_aim_start_reset_es(info : UpdateStageUpdateInput;
                                     human_net_phys : HumanActor;
                                     var aim_assist__onAimingStartProgress : float&;
                                     aim_assist__onAimingResetTime = 1.f)
  if human_net_phys.phys.currentState.aimPosition <= human_net_phys.phys.previousState.aimPosition
    aim_assist__onAimingStartProgress -= safediv(info.dt, aim_assist__onAimingResetTime)
    aim_assist__onAimingStartProgress = max(0.f, aim_assist__onAimingStartProgress)


[es(tag=input, after=aim_assist_on_aim_start_reset_es)]
def aim_assist_rotating_aim_es(info : UpdateStageUpdateInput;
                               human_input__aimAngle : float2;
                               var human_input__aimAngleOffset : float2&;
                               
                               human_input__touch_aim : float2 = float2();
                               human_weap__currentGunEid : EntityId;
                               human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID;
                               aim_assist__targetEid : EntityId;
                               aim_assist__targetConeWidth : float;
                               aim_assist__targetAngleCos : float;
                               aim_assist__targetDist : float;
                               aim_assist__targetDir : float3&;
                               aim_assist__rotationAimEnabled : bool;
                               aim_assist__rotationAimMaxAngle : float;
                               var aim_assist__rotationTargetEid : EntityId&;
                               var aim_assist__rotationTargetNodeId : int&;
                               aim_assist__rotationTargetNodeMaxAngle : float;
                               aim_assist__rotationVisc : float)
  if !aim_assist__rotationAimEnabled || !aim_assist__targetEid
    return

  
  var mouseAngles = get_mouse_axes_delta()
    
    
    
  mouseAngles.y *= 0.5
  let aAim = mouseAngles

  let touchAim = float2(human_input__touch_aim.x, human_input__touch_aim.y)
  let isManualAiming = aAim.x != 0.0 || aAim.y != 0.0 || touchAim.x != 0.0 || touchAim.y != 0.0
  if isManualAiming
    ecs::query(aim_assist__targetEid) <| $ [es] (collres : CollisionResource;
                                                 animchar : AnimcharBaseComponent;
                                                 transform : float3x4;
                                                 aim_assist_target__nodeIds : IntList)
      let shootDir = angles_to_dir(human_input__aimAngle)
      var shootPos : float3
      ecs::query(human_attached_gun__attachedGunEid != INVALID_ENTITY_ID ? human_attached_gun__attachedGunEid : human_weap__currentGunEid) <| $ [es] (gun : Gun)
        shootPos = gun.gunTm[3]

      aim_assist__rotationTargetNodeId = -1
      var bestCos = cos(deg_to_rad(aim_assist__rotationTargetNodeMaxAngle))
      for ni in aim_assist_target__nodeIds
        var ntm : float3x4
        collres_get_collision_node_tm(collres, ni, transform, animchar.nodeTree, ntm)
        let nodeDir = normalize(ntm[3] - shootPos)
        let nodeAngleCos = dot(shootDir, nodeDir)
        if nodeAngleCos > bestCos
          bestCos = nodeAngleCos
          aim_assist__rotationTargetEid = aim_assist__targetEid
          aim_assist__rotationTargetNodeId = ni
    return

  let assistProgress = get_assist_angle_progress(aim_assist__targetDist, aim_assist__targetAngleCos,
                                                 aim_assist__rotationAimMaxAngle, aim_assist__targetConeWidth)
  if assistProgress != 0.0
    var wishDir = aim_assist__targetDir
    if aim_assist__targetEid != aim_assist__rotationTargetEid
      aim_assist__rotationTargetNodeId = -1

    if aim_assist__rotationTargetNodeId != -1
      ecs::query(aim_assist__targetEid) <| $ [es] (collres : CollisionResource;
                                                   animchar : AnimcharBaseComponent;
                                                   transform : float3x4)
        var shootPos : float3
        ecs::query(human_attached_gun__attachedGunEid != INVALID_ENTITY_ID ? human_attached_gun__attachedGunEid : human_weap__currentGunEid) <| $ [es] (gun : Gun)
          shootPos = gun.gunTm[3]

        var ntm : float3x4
        collres_get_collision_node_tm(collres, aim_assist__rotationTargetNodeId, transform, animchar.nodeTree, ntm)
        wishDir = normalize(ntm[3] - shootPos)

    let wishAngle = dir_to_angles(wishDir)
    let wishOffset = angle_diff(human_input__aimAngle, wishAngle)
    human_input__aimAngleOffset = approach(human_input__aimAngleOffset, wishOffset, info.dt, aim_assist__rotationVisc)
  else
    human_input__aimAngleOffset = approach(human_input__aimAngleOffset, float2(0.f, 0.f), info.dt, aim_assist__rotationVisc)
    aim_assist__rotationTargetEid = INVALID_ENTITY_ID
    aim_assist__rotationTargetNodeId = -1
