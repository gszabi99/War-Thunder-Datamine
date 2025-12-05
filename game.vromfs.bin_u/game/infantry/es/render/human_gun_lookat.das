require ecs
require math
require math.base
require DagorMath
require HumanPhys
require DngHuman
require AnimV20
require GeomNodeTree

[es(tag=gameClient, before=human_gun_lookat_camera_on_action_es)]
def human_weap_camera_in_action_es(act : UpdateStageInfoAct;
                                   action__running : bool;
                                   human_weap__cameraTransitionOnActionTime : float = 0.2;
                                   var human_weap__cameraTransitionOnActionProgress : float&)
  if action__running || human_weap__cameraTransitionOnActionProgress > 0.0
    let change = safediv(act.dt, human_weap__cameraTransitionOnActionTime)
    human_weap__cameraTransitionOnActionProgress += action__running ? change : -change
    human_weap__cameraTransitionOnActionProgress = saturate(human_weap__cameraTransitionOnActionProgress)

[es(tag=render, REQUIRE=watchedHero, after=(camera_set_sync, human_fpv_cam_pos), before=before_camera_sync,
     after=animchar_cam_target_es, after=animchar_cam_target_with_offset_es)]
def human_gun_lookat_camera_es(info : UpdateStageInfoAct;
                               human_net_phys : HumanActor;
                               human_weap__currentGunEid : EntityId;
                               human__aimTm : float3x4;
                               human_weap__gunOffset : float3;
                               action__running : bool = false;
                               var camera__aimPosition : float&;
                               var camera__gunAimOffset : float2&;
                               var camera__lastValidGunAimPos : float3&;
                               var camera__look_at : DPoint3&;
                               isReplayObserved : Tag const?)

  query(human_weap__currentGunEid) <| $ [es] (entity_cam_nodes__aimNodeIdx : int;
                                              weap__sightEid : EntityId;
                                              gun__maxSightOffset : float = 0.03;
                                              gun__sightOffsetToAimPositionPower : float = 3.;
                                              weapon_sight__minDistFrom : float = 0.05)

    if entity_cam_nodes__aimNodeIdx < 0
      return

    let interpK = get_phys_interpk_clamped(human_net_phys.phys, info.curTime)
    let physPreviousStateAimPosition = human_net_phys.phys.previousState.aimPosition
    let physCurrentStateAimPosition = human_net_phys.phys.currentState.aimPosition
    var wishAimPosition = lerp(physPreviousStateAimPosition, physCurrentStateAimPosition, interpK)

    query(weap__sightEid) <| $ [es] (animchar : AnimcharBaseComponent;
                                     weapon__aimPointRelativePos : float = 0.0;
                                     weapon__aimNodeOffset : float = 0.0;
                                     weapon_frontsight_node__nodeIdx : int const?;
                                     weapon_rearsight_node__nodeIdx : int const?)
      let wofsF = *animchar.nodeTree |> geomtree_getWtmOfs()
      let wofs = DPoint3(wofsF)
      var aimTm : float3x4
      *animchar.nodeTree |> geomtree_getNodeWtmRelScalar(entity_cam_nodes__aimNodeIdx, aimTm)
      var aimPos = aimTm[3] + aimTm[0] * weapon__aimNodeOffset
      var aimOffset = float2(0.0, 0.0)

      if weapon_frontsight_node__nodeIdx != null && weapon_rearsight_node__nodeIdx != null
        let weaponFrontsightNodeIdx = *weapon_frontsight_node__nodeIdx
        let weaponRearsightNodeIdx = *weapon_rearsight_node__nodeIdx

        if weaponFrontsightNodeIdx < 0 || weaponRearsightNodeIdx < 0
          return

        let fsPos = *animchar.nodeTree |> geomtree_getNodeWposRel(weaponFrontsightNodeIdx)
        let rsPos = *animchar.nodeTree |> geomtree_getNodeWposRel(weaponRearsightNodeIdx)
        var frontSightTm : float3x4
        *animchar.nodeTree |> geomtree_getNodeWtmRelScalar(0, frontSightTm)
        frontSightTm[3] = fsPos
        let sightDir = normalize(inverse(frontSightTm) * rsPos)
        frontSightTm[3] = fsPos + (rsPos - fsPos) * weapon__aimPointRelativePos

        
        var augmentedFrontSightTm = frontSightTm
        
        
        
        
        if isReplayObserved == null
          augmentedFrontSightTm[0] = human__aimTm[2]
          augmentedFrontSightTm[1] = human__aimTm[1]
          augmentedFrontSightTm[2] = -human__aimTm[0]

        var len = length(frontSightTm[3] - aimPos)
        let dir = rsPos - frontSightTm[3]
        let dist = length(dir)
        len = max(dist + weapon_sight__minDistFrom, len + human_weap__gunOffset.x)
        let currentRearSightPos = sightDir * len
        let trueAimPos = frontSightTm * currentRearSightPos
        let wishAimPos = augmentedFrontSightTm * currentRearSightPos

        let aimPosOffsetDir = wishAimPos - trueAimPos
        let aimPosOffsetLenSq = length_sq(aimPosOffsetDir)
        if aimPosOffsetLenSq < square(gun__maxSightOffset)
          aimPos = wishAimPos
        else
          let offsetRatio = safediv(gun__maxSightOffset, sqrt(aimPosOffsetLenSq))
          aimPos = trueAimPos + aimPosOffsetDir * offsetRatio
          wishAimPosition = min(wishAimPosition, pow(offsetRatio, gun__sightOffsetToAimPositionPower))
        aimOffset = float2(0.0, atan2(-sightDir.y, sightDir.z))

      if !human_net_phys.phys.currentState |> human_phys_state_can_aim()
        wishAimPosition = 0.0
        aimOffset = float2(0.0, 0.0)
        aimPos = camera__lastValidGunAimPos
      else
        camera__lastValidGunAimPos = aimPos

      let aimSpeed = human_net_phys.phys.aimSpeed * human_net_phys.phys.currentState.aimSpeedMult
      camera__aimPosition = move_to(camera__aimPosition, wishAimPosition, info.dt, aimSpeed)

      if !action__running
        camera__look_at = lerp(camera__look_at, wofs + DPoint3(aimPos), camera__aimPosition)
        aimOffset = lerp(float2(0.0, 0.0), aimOffset, float2(camera__aimPosition))
      else
        aimOffset = float2(0.0, 0.0)

      camera__gunAimOffset = approach(camera__gunAimOffset, aimOffset, info.dt, 0.1)

[es(tag=render, REQUIRE=watchedHero, after=camera_set_sync, before=before_camera_sync,
     after=human_gun_lookat_camera_es, after=human_optics_lookat_camera_es)]
def human_gun_lookat_camera_on_action_es(info : UpdateStageInfoAct;
                                         animchar : AnimcharBaseComponent;
                                         animchar_camera_target__nodeIndex : int;
                                         human_weap__cameraTransitionOnActionProgress : float;
                                         var camera__look_at : DPoint3&)
  let progress = saturate(human_weap__cameraTransitionOnActionProgress)
  if (progress > 0.0)
    let animcharCameraTargetPos = *animchar.nodeTree |> geomtree_getNodeWpos(animchar_camera_target__nodeIndex)
    camera__look_at = lerp(camera__look_at, DPoint3(animcharCameraTargetPos), progress)