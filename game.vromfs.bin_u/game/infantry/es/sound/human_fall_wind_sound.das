require ecs
require soundEvent
require soundSystem
require sound_utils.modules.sound_player_common


[es(tag=sound, on_event=ParallelUpdateFrameDelayed, track=sound_preset__isLoaded, REQUIRE=watchedByPlr, after=sound_begin_update_es, before=sound_end_update_es)]
def human_fall_wind_sound_update(evt : Event;
                                 sound_preset__isLoaded : bool;
                                 human_fall_wind_sound__startSpeed : float;
                                 human_fall_wind_sound__path : string;
                                 var human_fall_wind_sound__event : SoundEvent&;
                                 human_net_phys__velocity : float3;
                                 isInVehicle : bool)

  let shouldPlay = -human_net_phys__velocity.y >= human_fall_wind_sound__startSpeed && !isInVehicle && sound_preset__isLoaded
  if human_fall_wind_sound__event |> play_or_abandon(human_fall_wind_sound__path, get_listener_pos(), shouldPlay)
    set_var(human_fall_wind_sound__event, "speed", -human_net_phys__velocity.y)


[es(tag=sound, on_disappear, REQUIRE=watchedByPlr)]
def human_fall_wind_sound_disappear(evt : Event;
                                    var human_fall_wind_sound__event : SoundEvent&)
  release_play_or(human_fall_wind_sound__event)
