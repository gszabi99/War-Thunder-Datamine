require ecs
require sound_utils.modules.sound_player_common


[es(tag=sound, REQUIRE=(humanSound, watchedByPlr), on_event=CmdRequestSuicide)]
def human_request_suicide_sound(evt : Event;
                                sound_preset__isLoaded : bool;
                                @shared_comp sound_paths : Object;
                                transform : float3x4;
                                sound_tags : Object;
                                human_hit_sound__prefix : string = "infantry/")
  if sound_preset__isLoaded
    sound_player_common::play_path("suicide", sound_paths, sound_tags, true, transform[3], true, human_hit_sound__prefix)
