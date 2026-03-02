require ecs
require soundEvent
require soundSystem


let SOUND_SPEED = 335.

[es(tag=sound, on_event=ParallelUpdateFrameDelayed, after=sound_begin_update_es, before=sound_end_update_es)]
def lightning_sound(evt : Event;
                    animchar_render__enabled : bool;
                    transform : float3x4;
                    lightning_sound__path : string;
                    lightning_sound__maxDelay : float;
                    var lightning_sound__event : SoundEvent&)
  if animchar_render__enabled != lightning_sound__event.enabled
    lightning_sound__event.enabled = animchar_render__enabled
    abandon(lightning_sound__event)
    if animchar_render__enabled && sound_banks_is_master_preset_loaded()
      let pos = get_listener_pos()
      let dir = normalize(transform[3] - pos)
      let dist = min(length(transform[3] - pos), lightning_sound__maxDelay * SOUND_SPEED)
      lightning_sound__event |> play(lightning_sound__path, pos + dir * dist)
