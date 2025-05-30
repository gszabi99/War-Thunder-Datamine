options no_aot
require ecs
require DagorConsole
require %game.events


[console_cmd(name="sound_area.init")]
def sound_area_init_cmd()
  broadcastEvent(EventSoundAreaInit())

[console_cmd(name="sound_area.debug")]
def sound_area_debug()
  query() <| $ [es(REQUIRE = sound_area__grid_step)] (eid : EntityId)
    if has(eid, "renderDebug")
      removeSubTemplate(eid, "render_debug")
    else
      addSubTemplate(eid, "render_debug")
