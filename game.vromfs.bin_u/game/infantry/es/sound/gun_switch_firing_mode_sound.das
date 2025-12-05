require ecs
require soundEvent
require DagorMath
require %appGame.infantry.es.sound.gun_sound_common


[es(tag=sound, track=gun__firingModeIndex, REQUIRE=gun__firingModeIndex)]
def gun_switch_firing_mode_sound(evt : Event;
                                 gun__owner : EntityId;
                                 animchar_bbox : bbox3f;
                                 gun_sound__prefix : string = "";
                                 gun_switch_firing_mode_sound__path : string)
  if is_watched_gun_sound(gun__owner)
    oneshot("{gun_sound__prefix}{gun_switch_firing_mode_sound__path}", get_gun_sound_pos(animchar_bbox))
