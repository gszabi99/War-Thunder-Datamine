require ecs
require soundEvent

[es(tag=sound, track=shooting_range_dummy__stateDown)]
def mannequin_sound_operations(evt : Event;
                               sound_preset__isLoaded : bool;
                               shooting_range_dummy__stateDown : bool;
                               state_mannequin_sound__downPath : string;
                               state_mannequin_sound__upPath : string;
                               transform : float3x4)
  if !sound_preset__isLoaded
    return
  if shooting_range_dummy__stateDown
    oneshot(state_mannequin_sound__downPath, transform[3])
  else
    oneshot(state_mannequin_sound__upPath, transform[3])
