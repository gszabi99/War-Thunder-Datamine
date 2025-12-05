options no_aot
require ecs
require ecs.ecs_template
require %appGame.infantry.es.net_console_macro
require %game.events
require DagorConsole
require DagorDebug3D


[ecs_template]
struct hitmark_debug_draw
  hitmarkPositionDebug : Tag

[net_console_cmd(name="hitmark.debug_draw")]
def hitmark_debug_draw_cmd()
  let exists = find_query() <| $ [es(REQUIRE=hitmarkPositionDebug)] (eid : EntityId)
    destroyEntity(eid)
    return true
  if !exists
    createEntity("hitmark_debug_draw")


[es(tag=gameClient, no_order, REQUIRE=hitmarkPositionDebug)]
def hitmark_debug_draw_update(evt : ParallelUpdateFrameDelayed)
  query() <| $ [es(REQUIRE=hero)] (human_weap__hitmarkPotentialPosition : float3)
    draw_debug_sphere_buffered(human_weap__hitmarkPotentialPosition, 0.02, E3DCOLOR(0xFFFF0000), 24, 1)
