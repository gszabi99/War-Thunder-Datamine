require ecs
require soundEvent
require sound_utils.modules.sound_player_common


[es(tag=sound, track=(door__isLocking, door__isBreaking, sound_preset__isLoaded))]
def door_sound_operations(evt : Event;
                          sound_preset__isLoaded : bool;
                          door__isLocking : bool;
                          door__isBreaking : bool;
                          door_sound_operations__lockingPath : string;
                          door_sound_operations__breakingPath : string;
                          var door_sound_operations__lockingEvent : SoundEvent&;
                          var door_sound_operations__breakingEvent : SoundEvent&;
                          transform : float3x4)

  door_sound_operations__lockingEvent |> play_or_abandon(door_sound_operations__lockingPath, transform[3], door__isLocking && sound_preset__isLoaded)
  door_sound_operations__breakingEvent |> play_or_abandon(door_sound_operations__breakingPath, transform[3], door__isBreaking && sound_preset__isLoaded)
