options no_aot
options no_global_variables = false
require ecs
require DagorConsole
require math

var g_tps_angle = 0.0

[console_cmd(name="player.tps_angle")]
def player_tps_angle(ang : float = 0.0)
  g_tps_angle = ang
  if ang == 0.0
    console_print("TPS angle reset (camera behind)")
  else
    console_print("TPS camera angle {ang} deg")

[es(tag=render, REQUIRE=isTpsView, after=shooter_cam_update_tm_es, before=after_camera_sync)]
def dev_tps_angle_cam_es(info : UpdateStageInfoAct;
                         camera__active : bool;
                         camera__target : EntityId;
                         var transform aka camera_transform : float3x4&;
                         var camera__accuratePos : DPoint3&)
  if !camera__active || g_tps_angle == 0.0
    return
  query(camera__target) <| $ [es] (camera__look_at : DPoint3)
    var rotTm : float3x4
    let up = float3(0, 1, 0)
    make_tm(up, g_tps_angle * (PI / 180.0), rotTm)
    let curPos = DPoint3(camera_transform[3])
    let offset = float3(curPos - camera__look_at)
    let rotatedOffset = rotate(rotTm, offset)
    let newPos = camera__look_at + DPoint3(rotatedOffset)
    camera_transform = rotTm * camera_transform
    camera_transform[3] = float3(newPos)
    camera__accuratePos = newPos


[console_cmd(name="player.enable_tps_camera")]
def player_enable_tps_camera()
  find_query() <| $ [es] (eid : EntityId;
                          isTpsView : bool = false;
                          camera__target : EntityId;
                          transform : float3x4)
    let removeTempl = isTpsView ? "dev_tps_cam" : "soldier_cam_perlin"
    let addTempl = isTpsView ? "soldier_cam_perlin" : "dev_tps_cam"

    let cb1 <- @ <| (reid : EntityId)
      addSubTemplate(eid, addTempl) <| $(var init : ComponentsInitializer)
        set(init, "camera__target", camera__target)
        set(init, "transform", transform)

    let curCamtemplateName = getEntityFutureTemplateName(eid)
    let newTemplateName = remove_sub_template_name(curCamtemplateName, removeTempl)
    reCreateEntityFrom(eid, newTemplateName, cb1) <| $ [unused_argument(init)] (var init) {}
    return true
