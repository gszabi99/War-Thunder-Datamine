require ecs
require soundEvent


[es(tag=sound, on_appear, REQUIRE=(airplane, vehicleWithWatched))]
def plane_sound_propagation_suspend(evt : Event)
  suspend_occlusion_backend(true)


[es(tag=sound, on_disappear, REQUIRE=(airplane, vehicleWithWatched))]
def plane_sound_propagation_resume(evt : Event)
  suspend_occlusion_backend(false)
