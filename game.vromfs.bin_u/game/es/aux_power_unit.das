require ecs
require %game.unit.unit_events
require %appGame.wt_events

[es(tag=server)]
def apu_auto_toggle_es(evt : EventApuAutoToggle;
                       var apu__autoEnabled : bool&)
  apu__autoEnabled = !apu__autoEnabled

[es(tag=server, on_event=EventUnitRespawn)]
def apu_respawn_handler_es(evt : Event;
                           var apu__autoEnabled : bool&)
  apu__autoEnabled = true
