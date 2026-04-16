options no_aot
require ecs
require ecs.ecs_template
require DagorConsole


[ecs_template]
struct backblast_reflected_debug
  backblastReflectedDebug : Tag
  backblast_reflected_debug__frames : int = 30000


[console_cmd(name="backblast.debug_reflected", hint="Toggle reflected backblast debug visualization (offline only)")]
def backblast_reflected_debug_toggle(frames : int = 30000)
  let found = find_query() <| $ [es(REQUIRE=backblastReflectedDebug)] (eid : EntityId)
    destroyEntity(eid)
    return true
  if !found
    createEntity("backblast_reflected_debug") <| $(init)
      init |> set("backblast_reflected_debug__frames", frames)
  console_print("{found ? "deactivated" : "activated"} backblast reflected debug (frames={frames})")
