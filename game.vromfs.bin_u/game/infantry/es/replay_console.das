options no_aot
require ecs
require ecs.ecs_template
require DagorConsole
require DagorDebug3D

require %appGame.wt_events


[console_cmd(name="replay.attach_to_weapon")]
def replay_attach_to_weapon_cmd()
  find_query() <| $ [es(REQUIRE=camera__active)] (eid aka camera_eid : EntityId;
                                                  camera__active : bool;
                                                  replay_camera__tpsFree : Tag const?)
    if !camera__active
      return false
    if replay_camera__tpsFree == null
      addSubTemplate(camera_eid, "replay_camera_tps_free")
      return true
    sendEvent(camera_eid, ReplayTrackAttachToWeapon())
    return true

[console_cmd(name="replay.detach_from_weapon")]
def replay_detach_from_weapon_cmd()
  find_query() <| $ [es(REQUIRE=replay_camera__tpsFree)] (eid aka camera_eid : EntityId)
    removeSubTemplate(camera_eid, "replay_camera_tps_free")
    return true

[console_cmd(name="replay.save_post_production_entities")]
def replay_post_production_save_cmd()
  find_query() <| $ [es(REQUIRE=replayPostProduction)] (eid : EntityId)
    sendEvent(eid, ReplayPostProdSaveFile())
    return true

[console_cmd(name="replay.load_post_production_entities")]
def replay_post_production_load_cmd()
  find_query() <| $ [es(REQUIRE=replayPostProduction)] (eid : EntityId)
    sendEvent(eid, ReplayPostProdLoadFile())
    return true

[ecs_template]
struct draw_post_production_entities_to_save
  draw_post_production_entities : Tag

[console_cmd(name="replay.draw_post_production_save_list")]
def replay_post_production_draw_save_list()
  let found = find_query() <| $ [es(REQUIRE=draw_post_production_entities_to_save)] (eid : EntityId)
    destroyEntity(eid)
    console_print("Post production save list draw OFF")
    return true
  if !found
    createEntity("draw_post_production_entities_to_save")
    console_print("Post production save list draw ON")

[es(tag=gameClient, no_order, REQUIRE=draw_post_production_entities)]
def replay_post_production_drawing(info : UpdateStageInfoRenderDebug)
  query() <| $ [es(REQUIRE=postProductionEntityToSave)] (transform : float3x4;
                                                         saving_entity__template : string;
                                                         saving_entity__creationTime : float)
    begin_draw_cached_debug_lines(false, false, false)

    draw_cached_debug_sphere(transform[3], 0.25, E3DCOLOR(0xFFFF0000), 8)
    add_debug_text_mark(transform[3], "time = {saving_entity__creationTime}, template = {saving_entity__template}", -1, 3.5f, E3DCOLOR(0x00000000))

    end_draw_cached_debug_lines()
