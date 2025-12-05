options no_aot
require ecs
require ecs.ecs_template
require DngHuman
require DagorConsole
require DagorDebug3D
require %game.utils.net_utils
require %appGame.infantry.es.net_console_macro


[ecs_template]
struct ladder_debug
  ladder_debug_tag : Tag


[console_cmd(name="ladder.debug_draw")]
def ladder_debug_draw_cmd()
  let found = find_query() <| $ [es(REQUIRE=ladder_debug_tag)] (eid : EntityId)
    destroyEntity(eid)
    console_print("ladder.debug_draw = false")
    return true
  if !found
    createEntity("ladder_debug")
    console_print("ladder.debug_draw = true")


[es(tag=gameClient, no_order, REQUIRE=hero)]
def debug_ladder_draw(evt : UpdateStageInfoAct;
                      human_ladder__attached : bool;
                      human_net_phys : HumanActor)
  if !human_ladder__attached
    return

  let found = find_query() <| $ [es(REQUIRE=ladder_debug_tag)] ()
    return true
  if !found
    return

  let soldierP = float3(human_net_phys.phys.currentState.location.P)
  let ladderTm = human_net_phys.phys.currentState.ladderTm
  let ladderOffset = human_net_phys.phys.collRad + length(ladderTm[0])
  let ladderOffsetP = normalize(ladderTm[0]) * ladderOffset

  draw_debug_line_buffered(ladderTm[3], ladderTm[3] + ladderTm[0], E3DCOLOR(0xffff0000), 10)
  draw_debug_line_buffered(ladderTm[3], ladderTm[3] + ladderTm[1], E3DCOLOR(0xff00ff00), 10)
  draw_debug_line_buffered(ladderTm[3], ladderTm[3] + ladderTm[2], E3DCOLOR(0xff0000ff), 10)
  draw_debug_line_buffered(ladderTm[3] + ladderTm[0], ladderTm[3] + ladderOffsetP, E3DCOLOR(0xffffff00), 10)
  draw_debug_sphere_buffered(ladderTm[3] + ladderOffsetP, 0.1, E3DCOLOR(0xffffff00), 12, 10)
  draw_debug_sphere_buffered(soldierP, 0.1, E3DCOLOR(0xffff0000), 12, 10)


[ecs_template]
struct ladder_debug_server
  ladder_debug_server_tag : Tag


[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct LadderServerEventDebug
  attached : bool
  tm : float3x4
  velocity : float3


[net_console_cmd(name="ladder.debug_server")]
def debug_ladder_from_server_in_events()
  let found = find_query() <| $ [es(REQUIRE=ladder_debug_server_tag)] (eid : EntityId)
    destroyEntity(eid)
    error("ladder.debug_server = false")
    return true
  if !found
    createEntity("ladder_debug_server")
    error("ladder.debug_server = true")


[es(tag=server, track=human_ladder__attached)]
def debug_ladder_on_attach_changes_server(evt : Event;
                                          eid : EntityId;
                                          possessedByPlr : EntityId;
                                          human_net_phys : HumanActor;
                                          transform : float3x4;
                                          human_ladder__attached : bool)
  let found = find_query() <| $ [es(REQUIRE=ladder_debug_server_tag)] () => true
  if !found
    return

  assume currentState = human_net_phys.phys.currentState
  send_net_event(eid, LadderServerEventDebug(attached = human_ladder__attached, tm = transform, velocity = currentState.velocity), target_entity_conn(possessedByPlr))

[es(tag=gameClient, REQUIRE=hero)]
def debug_ladder_on_attach_changes_client(evt : LadderServerEventDebug)
  console_print("Ladder Server Debug: {evt.attached ? "attached" : "detached"}, velocity=({evt.velocity})")
  draw_debug_sphere_buffered(evt.tm[3], 0.2, evt.attached ? E3DCOLOR(0xff00ff00) : E3DCOLOR(0xffff0000), 12, 1000)
