options no_aot
require ecs
require ecs.common
require DagorConsole

[console_cmd(name="ai.custom_nav_debug")]
def custom_nav_debug()
  let found = ecs::find_query() <| $ [es(REQUIRE=customNavDebug)] (eid : EntityId)
    destroyEntity(eid)
    return true
  if !found
    createEntity("custom_nav_debug")
