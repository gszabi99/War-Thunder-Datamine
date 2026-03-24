require ecs
require net
require inventory
require %game.events

require %appGame.wt_events

[es(tag=server)]
def heal_item_used_es(evt : EventOnLootItemUsed; item__healAmount : float; item__healDamageOverTimeAmount : float const?)
  let targetEid = evt.target
  query(targetEid) <| $ [es] (isDowned : bool;
                              isAlive : bool)
    if isDowned || !isAlive 
      return
    if item__healAmount > 0f
      send_net_event(targetEid, CmdRestoreEntityHp(restoreHp = item__healAmount))
    if item__healDamageOverTimeAmount != null && *item__healDamageOverTimeAmount > 0f
      send_net_event(targetEid, CmdRestoreEntityDamageOverTime(restoreDot = *item__healDamageOverTimeAmount))









[es(tag=server, REQUIRE=item__restoreBreath)]
def restore_breath_item_used_es(evt : EventOnLootItemUsed)
  query(evt.target) <| $ [es] (var human_breath__timer : float&)
    human_breath__timer = 0f
