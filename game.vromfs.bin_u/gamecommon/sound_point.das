require ecs
require Unit
require soundEvent
require soundSystem

[es(tag=gameClient, tag=sound)]
def sound_point_update_client_es(act : UpdateStageInfoAct;
                                 transform : float3x4;
                                 sound_point__event_name : string;
                                 var sound_point__event : SoundEvent&;
                                 sound_point__near_dist : float)

  if length(transform[3] - get_listener_pos()) < sound_point__near_dist
    if !is_playing(sound_point__event.handle)
      sound_point__event |> play(sound_point__event_name, transform[3])
  elif is_playing(sound_point__event.handle)
    abandon(sound_point__event.handle)
