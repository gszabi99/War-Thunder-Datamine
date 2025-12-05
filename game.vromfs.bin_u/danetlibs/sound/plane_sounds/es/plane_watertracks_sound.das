require ecs
require soundEvent
require soundSystem
require DngPlane
require sound_utils.modules.sound_control_common


[es(tag=sound, on_event=ParallelUpdateFrameDelayed, after=(plane_phys_es, sound_control_update, sound_begin_update_es), before=sound_end_update_es)]
def plane_watertracks_sound(evt : Event;
                            sound_control__state : int;
                            plane_net_phys : PlaneActor;
                            plane_watertracks_sound__path : string;
                            var plane_watertracks_sound__event : SoundEvent&;
                            vehicle_sound_speed_state__speed : float;
                            transform : float3x4)
  let shouldPlay = have_sound(sound_control__state) && plane_net_phys.phys.Gears.onWater
  if plane_watertracks_sound__event.enabled != shouldPlay
    plane_watertracks_sound__event.enabled = shouldPlay
    abandon(plane_watertracks_sound__event)
    if plane_watertracks_sound__event.enabled
      plane_watertracks_sound__event |> play(plane_watertracks_sound__path, transform[3])

  if plane_watertracks_sound__event.enabled
    set_var(plane_watertracks_sound__event, "speed", vehicle_sound_speed_state__speed)
    set_pos(plane_watertracks_sound__event, transform[3])
