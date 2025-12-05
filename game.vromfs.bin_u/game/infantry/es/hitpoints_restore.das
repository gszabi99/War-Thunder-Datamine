require ecs

require %appGame.wt_events
require %appGame.infantry.es.hitpoints_common

[es(tag=server, REQUIRE=(hitpoints, hitpoints__stoppingPower))]
def hitpoints_restore_es(evt : CmdRestoreEntityHp;
                         hitpoints__maxHp : float;
                         var hitpoints__hp : float&)
  hitpoints__hp = min(max(hitpoints__hp, 0.) + evt.restoreHp, hitpoints__maxHp)

[es(tag=server, REQUIRE=(hitpoints, hitpoints__stoppingPower))]
def hitpoints_clear_dot_damage_es(evt : CmdRestoreEntityDamageOverTime;
                                  var hitpoints__dotDamage : FloatList&;
                                  var hitpoints__totalDotAmount : float&)
  var amount = evt.restoreDot
  decrease_damage_over_time_amount(amount, hitpoints__dotDamage, hitpoints__totalDotAmount)
