require ecs


[es(tag=sound, on_appear, REQUIRE=watchedByPlr)]
def human_sound_set_watched(evt : Event;
                            var is_watched_sound : bool&)
  is_watched_sound = true


[es(tag=sound, on_disappear, REQUIRE=watchedByPlr)]
def human_sound_remove_watched(evt : Event;
                               var is_watched_sound : bool&)
  is_watched_sound = false
