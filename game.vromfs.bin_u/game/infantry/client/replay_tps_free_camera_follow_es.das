require ecs
require math.base

require %appGame.wt_events
require DagorMath
require DagorSystem
require DagorConsole
require AnimV20
require GeomNodeTree
require math
require app
require WTCamera


def private deg_to_fov(deg : float)
  return safediv(1.f, tan(deg_to_rad(0.5f * deg)))

[es(tag=playingReplay, on_appear, on_event=ReplayTrackAttachToWeapon)]
def replay_track_attach_to_weapon(evt : Event;
                                  transform aka camera_transform : float3x4;
                                  var replay_camera__trackingEnabled : bool&;
                                  var fov : float&;
                                  var fovSettings : float&;
                                  var replay_camera__trackWeaponEid : EntityId&;
                                  var replay_camera__trackWeaponNodeId : int&;
                                  var replay_camera__trackWeaponRelativeTm : float3x4&)
  query() <| $ [es(REQUIRE=watchedByPlr)] (eid aka soldier_eid : EntityId)
    query(soldier_eid) <| $ [es] (human_weap__currentGunEid : EntityId)
      query(human_weap__currentGunEid) <| $ [es] (animchar : AnimcharBaseComponent)
        let weaponName = getEntityTemplateName(human_weap__currentGunEid)
        var nodeTm : float3x4
        var nodeName = "bullet"
        replay_camera__trackWeaponNodeId = *animchar.nodeTree |> geomtree_findNodeIndex(nodeName)
        if replay_camera__trackWeaponNodeId < 0
          nodeName = "weaponRoot_2"
          replay_camera__trackWeaponNodeId = *animchar.nodeTree |> geomtree_findNodeIndex(nodeName)
        if replay_camera__trackWeaponNodeId < 0
          nodeName = "weaponRoot"
          replay_camera__trackWeaponNodeId = *animchar.nodeTree |> geomtree_findNodeIndex(nodeName)
        if replay_camera__trackWeaponNodeId < 0
          logerr("Cannot attach to a weapon '{weaponName}', node '{nodeName}' not found")
          return
        geomtree_getNodeWtmScalar(*animchar.nodeTree, replay_camera__trackWeaponNodeId, nodeTm)
        replay_camera__trackWeaponRelativeTm = inverse(nodeTm) * camera_transform
        replay_camera__trackWeaponEid = human_weap__currentGunEid
        replay_camera__trackingEnabled = true
        console_print("Camera attached to a weapon '{weaponName}' (node: '{nodeName}')")
        let app = get_app()
        if app == null || app.flightControlMode == null
          return
        let camera = app.flightControlMode.cameraControl.cur
        if camera != null
          fov = fov_to_deg(camera.viewData.fov)
          fovSettings = fov
        console_command("camera.select human")

[es(tag=playingReplay, after=(after_camera_sync, shooter_cam_update_tm_es), before=main_update_camera_es, REQUIRE=replay_camera__tpsFree)]
def replay_track_follow_weapon_node(info : UpdateStageInfoAct;
                                    isTpsView : bool;
                                    camera__active : bool;
                                    replay_camera__trackingEnabled : bool;
                                    replay_camera__trackWeaponEid : EntityId;
                                    replay_camera__trackWeaponNodeId : int;
                                    replay_camera__trackWeaponRelativeTm : float3x4;
                                    var transform : float3x4&;
                                    var camera__accuratePos : DPoint3&)
  if !isTpsView || !camera__active || !replay_camera__trackingEnabled || replay_camera__trackWeaponNodeId < 0
    return

  query(replay_camera__trackWeaponEid) <| $ [es] (animchar : AnimcharBaseComponent)
    var nodeTm : float3x4
    geomtree_getNodeWtmScalar(*animchar.nodeTree, replay_camera__trackWeaponNodeId, nodeTm)
    transform = nodeTm * replay_camera__trackWeaponRelativeTm
    camera__accuratePos = DPoint3(transform[3])
