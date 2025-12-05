require ecs
require ecs.common


[es(tag=sound, on_appear, REQUIRE=vehicleWithWatched)]
def vehicle_sound_set_watched(evt : Event;
                              var is_watched_sound : bool&)
  is_watched_sound = true


[es(tag=sound, on_disappear, REQUIRE=vehicleWithWatched)]
def vehicle_sound_remove_watched(evt : Event;
                                 var is_watched_sound : bool&)
  is_watched_sound = false
