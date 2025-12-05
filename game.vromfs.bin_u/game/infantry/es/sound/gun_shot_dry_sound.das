require ecs
require app
require soundEvent
require DagorMath
require %appGame.infantry.es.sound.gun_sound_common


[es(tag=sound, on_event=EventShotDry)]
def gun_shot_dry_sound(evt : Event;
                       gun_shot_dry_sound__path : string;
                       gun_sound__prefix : string = "";
                       var gun_shot_dry_sound__nextTime : float&;
                       gun_shot_dry_sound__cooldown : float;
                       gun__owner : EntityId;
                       animchar_bbox : bbox3f)
  if get_sync_time() >= gun_shot_dry_sound__nextTime && is_watched_gun_sound(gun__owner)
    oneshot("{gun_sound__prefix}{gun_shot_dry_sound__path}", get_gun_sound_pos(animchar_bbox))
  gun_shot_dry_sound__nextTime = get_sync_time() + gun_shot_dry_sound__cooldown
