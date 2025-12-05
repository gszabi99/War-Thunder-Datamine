require ecs
require ecs.common
require soundHash
require soundEvent
require sound_utils.modules.sound_player_common


[es(tag=sound, track=human_net_phys__isClimbing, REQUIRE=humanSound)]
def human_climb_sound(evt : Event;
                      human_net_phys__isClimbing : bool;
                      human_sound__prefix : string = "";
                      sound_tags : Object;
                      var sound_event_group : SoundEventGroup&;
                      @shared_comp sound_paths : Object;
                      sound_preset__isLoaded : bool;
                      is_watched_sound : bool;
                      transform : float3x4)
  if human_net_phys__isClimbing && should_play(transform[3]) && sound_preset__isLoaded
    sound_player_common::play_path("climb", sound_paths, sound_tags, is_watched_sound, transform[3], sound_hash(""), sound_event_group, human_sound__prefix)
