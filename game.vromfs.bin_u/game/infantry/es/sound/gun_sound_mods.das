require ecs
require sound_utils.modules.sound_player_common


[es(tag=sound, on_appear, track=gun_sound_mods__suppressor)]
def gun_sound_mods_toggle(evt : Event;
                          gun_sound_mods__suppressor : float;
                          var sound_flags : Object&)
  set_sound_tag("suppressor", gun_sound_mods__suppressor != 0., sound_flags)


[es(tag=sound, on_disappear, REQUIRE=gun_sound_mods__suppressor)]
def gun_sound_mods_disappear(evt : Event;
                             var sound_flags : Object&)
  clear_sound_tag("suppressor", sound_flags)
