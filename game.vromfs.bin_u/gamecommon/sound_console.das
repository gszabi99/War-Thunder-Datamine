options no_aot
require ecs
require soundEvent
require DagorConsole
require %game.events
require DagorDebug3D
require DagorStdGuiRender
require Sound

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


[es(tag=sound, no_order)]
def snapshot_headphones_mode_update(act : UpdateStageInfoAct)
  if is_headphones_snapshot_active()
    let scrSize = StdGuiRender_screen_size()
    add_debug_text_mark_screen(scrSize.x * 0.05, scrSize.y * 0.05, "shapshot headphones", -1, 0., E3DCOLOR(0xFF00FFFF))


[es(tag=sound, no_order)]
def snapshot_headphones_wide_mode_update(act : UpdateStageInfoAct)
  let mode = get_headphones_wide_snapshot_mode()
  if mode >= 0
    let scrSize = StdGuiRender_screen_size()
    add_debug_text_mark_screen(scrSize.x * 0.065, scrSize.y * 0.08, "shapshot headphones wide {mode}", -1, 0., E3DCOLOR(0xFFFFFF00))