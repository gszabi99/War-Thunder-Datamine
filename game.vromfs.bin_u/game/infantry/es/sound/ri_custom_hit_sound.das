require ecs
require soundEvent
require %appGame.wt_events


[es(tag=sound)]
def ri_hit_custom_sound_hit(evt : EventRendinstOnProjectileHit;
                            ri_hit_custom_sound__name : string)
  oneshot(ri_hit_custom_sound__name, evt.pos)