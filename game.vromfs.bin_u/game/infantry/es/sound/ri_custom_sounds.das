require ecs
require soundEvent
require %appGame.wt_events
require DagorConsole

[es(tag=sound)]
def ri_hit_custom_sound_hit(evt : EventRendinstOnProjectileHit;
                            ri_hit_custom_sound__name : string)
  oneshot(ri_hit_custom_sound__name, evt.pos)


[es(tag=sound)]
def wt_tree_collision_sound_play(evt : EventTreeCollisionSound;
                                 wt_tree_collision_sound__name : string)
  oneshot(wt_tree_collision_sound__name, evt.pos)
