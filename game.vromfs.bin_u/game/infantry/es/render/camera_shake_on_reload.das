require ecs
require DagorMath
require AnimV20
require GeomNodeTree
require DagorSystem
require DngHuman


def clamp(x : float; minmax : float2)
  return clamp(x, minmax[0], minmax[1])


def get_weapon_direction(animchar : AnimcharBaseComponent; node1_index, node2_index : int)
  let node1Pos = geomtree_getNodeWpos(*animchar.nodeTree, node1_index)
  let node2Pos = geomtree_getNodeWpos(*animchar.nodeTree, node2_index)
  return normalize(node2Pos - node1Pos)


[es(tag=gameClient, on_appear)]
def camera_shake_on_reload_init(evt : Event;
                                eid : EntityId;
                                animchar : AnimcharBaseComponent;
                                gun_reload_camera_shake__node1Name : string;
                                gun_reload_camera_shake__node2Name : string;
                                var gun_reload_camera_shake__node1Index : int&;
                                var gun_reload_camera_shake__node2Index : int&)
  gun_reload_camera_shake__node1Index = geomtree_findNodeIndex(*animchar.nodeTree, gun_reload_camera_shake__node1Name)
  if gun_reload_camera_shake__node1Index == -1
    logerr("The weapon '{getEntityTemplateName(eid)}' does not contain node '{gun_reload_camera_shake__node1Name}'")

  gun_reload_camera_shake__node2Index = geomtree_findNodeIndex(*animchar.nodeTree, gun_reload_camera_shake__node2Name)
  if gun_reload_camera_shake__node2Index == -1
    logerr("The weapon '{getEntityTemplateName(eid)}' does not contain node '{gun_reload_camera_shake__node2Name}'")


[es(tag=gameClient, on_event=CmdWeapModToggle, track=(human_weap__reloadStartTime, human_weap__inspectStartTime), REQUIRE=(human_weap__reloadStartTime, human_weap__inspectStartTime))]
def camera_shake_on_reload(evt : Event;
                           transform aka soldier_transform : float3x4;
                           human_weap__currentGunEid : EntityId)
  query(human_weap__currentGunEid) <| $ [es] (animchar : AnimcharBaseComponent;
                                              gun_reload_camera_shake__node1Index : int;
                                              gun_reload_camera_shake__node2Index : int;
                                              var gun_reload_camera_shake__initialWeaponDirection : float3&;
                                              var gun_reload_camera_shake__restWeaponDirection : float3&)
    if gun_reload_camera_shake__node1Index != -1 && gun_reload_camera_shake__node2Index != -1
      let weaponDirectionInWorld = get_weapon_direction(animchar, gun_reload_camera_shake__node1Index, gun_reload_camera_shake__node2Index)
      gun_reload_camera_shake__initialWeaponDirection = rotate(inverse(soldier_transform), weaponDirectionInWorld)
      gun_reload_camera_shake__restWeaponDirection = gun_reload_camera_shake__initialWeaponDirection


[es(tag=gameClient, before=camera_shake_on_reload_update, REQUIRE=watchedPlayerItem)]
def camera_shake_on_reload_update_rest_weapon_direction(info : UpdateStageInfoAct;
                                                        gun__owner : EntityId;
                                                        gun_anim__reloadProgress : float;
                                                        gun_reload_camera_shake__initialWeaponDirection : float3;
                                                        gun_reload_camera_shake__relaxDuration : float;
                                                        var gun_reload_camera_shake__relaxTime : float&;
                                                        var gun_reload_camera_shake__restWeaponDirection : float3&)
  if gun_anim__reloadProgress > 0. && gun_anim__reloadProgress < 0.9
    query(gun__owner) <| $ [es] (camera__lookDir : float3;
                                 transform aka soldier_transform : float3x4;
                                 isInVehicle : bool;
                                 human_vehicle__isShootingPassenger : bool = false)
      if isInVehicle && !human_vehicle__isShootingPassenger
        return
      let restDirection = rotate(inverse(soldier_transform), camera__lookDir)
      gun_reload_camera_shake__restWeaponDirection = lerp(gun_reload_camera_shake__initialWeaponDirection, restDirection, float3(gun_anim__reloadProgress))
      gun_reload_camera_shake__relaxTime = gun_reload_camera_shake__relaxDuration


[es(tag=gameClient, after=shooter_cam_update_tm_es, before=after_camera_sync, REQUIRE=watchedByPlr)]
def camera_shake_on_reload_update(info : UpdateStageInfoAct;
                                  isTpsView : bool;
                                  isInVehicle : bool;
                                  human_vehicle__isShootingPassenger : bool = false;
                                  transform aka soldier_transform : float3x4;
                                  camera__lookDir : float3;
                                  
                                  human_weap__reloadDelayTime : float;
                                  bindedCamera : EntityId;
                                  human_net_phys : HumanActor;
                                  human_weap__currentGunEid : EntityId)
  if isTpsView || (isInVehicle && !human_vehicle__isShootingPassenger)
    return

  query(human_weap__currentGunEid) <| $ [es] (animchar : AnimcharBaseComponent;
                                              gun_reload_camera_shake__node1Index : int;
                                              gun_reload_camera_shake__node2Index : int;
                                              gun_reload_camera_shake__restWeaponDirection : float3;
                                              gun_reload_camera_shake__limitX : float2;
                                              gun_reload_camera_shake__limitY : float2;
                                              gun_reload_camera_shake__scale : float2;
                                              gun_anim__reloadProgress : float;
                                              gun_reload_camera_shake__relaxDuration : float;
                                              var gun_reload_camera_shake__relaxTime : float&)
    if human_net_phys.phys.currentState.weapEquipState.curState != HUWeaponEquipState.EES_EQUIPED
      gun_reload_camera_shake__relaxTime = 0.0
      return

    assume isReload = gun_anim__reloadProgress > 0.0 && gun_anim__reloadProgress < 1.0
    if isReload && human_weap__reloadDelayTime > 0.0
      return
    if (gun_anim__reloadProgress <= 0.0 && gun_reload_camera_shake__relaxTime <= 0.0) || gun_reload_camera_shake__node1Index == -1 || gun_reload_camera_shake__node2Index == -1
      return

    
    let cameraEid = bindedCamera

    query(cameraEid) <| $ [es] (var transform aka camera_transform : float3x4&)
      let weaponDirInWorld = get_weapon_direction(animchar, gun_reload_camera_shake__node1Index, gun_reload_camera_shake__node2Index)
      let weaponDirLocal = rotate(inverse(soldier_transform), weaponDirInWorld)
      let weaponRotateQuat = quat(quat_from_unit_arc(gun_reload_camera_shake__restWeaponDirection, weaponDirLocal))
      let cameraRotatedDirection = weaponRotateQuat * camera__lookDir
      let cameraDiffDir = cameraRotatedDirection - camera__lookDir

      let projX = dot(cameraDiffDir, -soldier_transform[2])
      let projY = dot(cameraDiffDir, soldier_transform[1])

      var offsetX = clamp(projX * gun_reload_camera_shake__scale.x, gun_reload_camera_shake__limitX)
      var offsetY = clamp(projY * gun_reload_camera_shake__scale.y, gun_reload_camera_shake__limitY)

      if gun_reload_camera_shake__relaxDuration > 0.
        let relaxFactor = gun_reload_camera_shake__relaxTime / gun_reload_camera_shake__relaxDuration
        offsetX *= relaxFactor
        offsetY *= relaxFactor

      gun_reload_camera_shake__relaxTime = max(gun_reload_camera_shake__relaxTime - info.dt, 0.0)

      var q : quat
      euler_to_quat(offsetY, offsetX, offsetX, q)
      var shakerTm : float3x4
      make_tm(q, float3(0.0), shakerTm)
      camera_transform = camera_transform * shakerTm
