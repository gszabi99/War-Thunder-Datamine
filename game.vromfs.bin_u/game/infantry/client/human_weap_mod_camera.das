require ecs
require DngHuman
require DagorMath
require AnimV20
require GeomNodeTree


def set_lookat_from_sight_node(cur_time : float;
                               human_net_phys : HumanActor;
                               optics_cam_node : int;
                               frontsight_cam_node : int;
                               animchar : AnimcharBaseComponent;
                               human__aimTm : float3x4;
                               human_weap__gunOffset : float3;
                               gunmod__gunOffsetMult : float;
                               gun_tm : float3x4;
                               bindedCamera : EntityId;
                               cam_shift_min : float;
                               cam_shift_max : float;
                               cam_fov_min : float;
                               cam_fov_max : float;
                               gunmod_eid : EntityId;
                               action__running : bool;
                               bipod__enabled : bool;
                               gunmod__scopeOffsetInBipod : float const?;
                               var camera__look_at : DPoint3&;
                               var gun_aim_offset : float2&;
                               var camera__lastValidGunAimPos : float3&)
  if optics_cam_node < 0
    return

  let wposRelScalar = *animchar.nodeTree |> geomtree_getNodeWposRel(optics_cam_node)
  let wtmOfs = *animchar.nodeTree |> geomtree_getWtmOfs()
  var wpos = DPoint3(wposRelScalar) + DPoint3(wtmOfs)

  var nodeDir = -DPoint3(gun_tm[2])
  if bipod__enabled && gunmod__scopeOffsetInBipod != null
    let offsetFromScope = *gunmod__scopeOffsetInBipod * normalize(gun_tm[2])
    camera__look_at = wpos + DPoint3(offsetFromScope)

  var aimOffset = gun_aim_offset
  if frontsight_cam_node > 0
    let fsPos = *animchar.nodeTree |> geomtree_getNodeWposRel(frontsight_cam_node)
    var frontSightTm : float3x4
    *animchar.nodeTree |> geomtree_getNodeWtmRelScalar(0, frontSightTm)
    frontSightTm[3] = fsPos
    let sightDir = normalize(inverse(frontSightTm) * wposRelScalar)
    aimOffset = float2(0.0, atan2(-sightDir.y, sightDir.z))
    let nodeDirF = normalize(fsPos - wposRelScalar)
    nodeDir = DPoint3(nodeDirF)

  query(bindedCamera) <| $ [es] (fov : float;
                                 camera__active : bool)
    if !camera__active
      return

    var aimTm = human__aimTm
    if abs(aimOffset.y) > 0.0
      var rotTm : float3x4
      rotzTM(-aimOffset.y, rotTm)
      aimTm = human__aimTm * rotTm
    let lookDir = normalize(aimTm[0])
    let shift = cvt(fov, cam_fov_min, cam_fov_max, cam_shift_min, cam_shift_max) + human_weap__gunOffset.x * gunmod__gunOffsetMult
    let threshold = 0.5
    wpos += nodeDir * threshold - DPoint3(lookDir) * (shift + threshold)

  assume hphys = human_net_phys.phys
  let interpK = get_phys_interpk_clamped(hphys, cur_time)
  let aimPosition = lerp(hphys.previousState.aimPosition, hphys.currentState.aimPosition, interpK)
  let zoomPosition = lerp(hphys.previousState.zoomPosition, hphys.currentState.zoomPosition, interpK)
  let baseValue = has(gunmod_eid, "isCameraAlwaysOnScope") && !action__running ? 1.0 : 0.0
  let lerpFactor = lerp(0.0, max(zoomPosition, baseValue), aimPosition)
  if !human_net_phys.phys.currentState |> human_phys_state_can_aim()
    wpos = DPoint3(camera__lastValidGunAimPos) + DPoint3(wtmOfs)
  else
    camera__lastValidGunAimPos = float3(wpos) - wtmOfs
  camera__look_at = lerp(camera__look_at, wpos, lerpFactor)
  gun_aim_offset = lerp(float2(0.0, 0.0), aimOffset, float2(lerpFactor))


[es(tag=render,
     before=before_camera_sync,
     after=(human_fpv_cam_pos, animchar_cam_target_es, animchar_cam_target_with_offset_es, human_gun_lookat_camera_es),
     REQUIRE=watchedByPlr)]

def human_optics_lookat_camera_es(info : UpdateStageInfoAct;
                                  bipod__enabled : bool;
                                  human__aimTm : float3x4;
                                  human_net_phys : HumanActor;
                                  human_weap__currentGunEid : EntityId;
                                  human_weap__gunOffset : float3;
                                  bindedCamera : EntityId;
                                  human_weap__currentScope : EntityId;
                                  var camera__look_at : DPoint3&;
                                  var camera__gunAimOffset : float2&;
                                  var camera__lastValidGunAimPos : float3&;
                                  action__running : bool = false)
  var gunScopeEid = human_weap__currentScope
  let isIntegratedScope = get_bool(human_weap__currentGunEid, "gun__integratedScope") ?? false
  if isIntegratedScope && !gunScopeEid
    gunScopeEid = human_weap__currentGunEid

  var gunTm = human__aimTm
  query(human_weap__currentGunEid) <| $ [es] (animchar : AnimcharBaseComponent;
                                              subsidiaryGunEid : EntityId = INVALID_ENTITY_ID)
    animchar |> animchar_get_tm(gunTm)
    if !!subsidiaryGunEid
      query(subsidiaryGunEid) <| $ [es] (sightPresets : Array const?)
        if sightPresets != null && length(*sightPresets) > 0
          gunScopeEid = subsidiaryGunEid


  query(gunScopeEid) <| $ [es] (gunmod__camNodeId : int;
                                animchar : AnimcharBaseComponent;
                                gunmod__camShiftMin : float;
                                gunmod__camShiftMax : float;
                                gunmod__gunOffsetMult : float;
                                gunmod__camFovMin : float;
                                gunmod__camFovMax : float;
                                gunmod__frontsightCamNodeId : int = -1;
                                gunmod__scopeOffsetInBipod : float const?)
    set_lookat_from_sight_node(info.curTime, human_net_phys,
                               gunmod__camNodeId, gunmod__frontsightCamNodeId, animchar,
                               human__aimTm, human_weap__gunOffset, gunmod__gunOffsetMult,
                               gunTm, bindedCamera,
                               gunmod__camShiftMin, gunmod__camShiftMax,
                               gunmod__camFovMin, gunmod__camFovMax,
                               gunScopeEid,
                               action__running,
                               bipod__enabled,
                               gunmod__scopeOffsetInBipod,
                               camera__look_at,
                               camera__gunAimOffset,
                               camera__lastValidGunAimPos)
