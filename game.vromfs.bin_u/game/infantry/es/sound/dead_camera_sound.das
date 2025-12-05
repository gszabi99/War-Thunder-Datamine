require ecs
require soundEvent
require soundSystem
require soundHash


[es(tag=sound, on_appear, track=(dead_camera__hitHead, dead_camera__ending), REQUIRE=(watchedByPlr, deadEntity))]
def dead_camera_sound_bodyfall(evt : Event;
                               dead_camera__hitHead : bool;
                               dead_camera__ending : bool;
                               dead_camera_sound__bodyfallPath : string;
                               dead_camera_sound__tinnitusPath : string;
                               var dead_camera_sound__tinnitusEvent : SoundEvent&;
                               transform : float3x4)
  if dead_camera__hitHead || dead_camera__ending
    if !dead_camera_sound__tinnitusEvent.enabled
      dead_camera_sound__tinnitusEvent.enabled = true
      oneshot(dead_camera_sound__bodyfallPath, transform[3])
      if sound_banks_is_master_preset_loaded()
        dead_camera_sound__tinnitusEvent |> play(dead_camera_sound__tinnitusPath, transform[3])


[es(tag=sound, on_disappear, REQUIRE=(watchedByPlr, deadEntity))]
def dead_camera_sound_disappear(evt : Event;
                                var dead_camera_sound__tinnitusEvent : SoundEvent&;
                                var human_death_sound__event : SoundEvent&)
  abandon(dead_camera_sound__tinnitusEvent)
  dead_camera_sound__tinnitusEvent.enabled = false
  release(human_death_sound__event)
