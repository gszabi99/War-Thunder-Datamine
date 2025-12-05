options no_aot
require ecs
require DagorConsole

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
