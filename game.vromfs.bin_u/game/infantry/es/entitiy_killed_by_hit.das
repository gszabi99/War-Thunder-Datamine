require ecs
require net
require %appGame.infantry.es.hitpoints_common

require %appGame.wt_events

[es(tag=server)]
def entity_enemy_killed_by_headshot(evt : EventEntityEnemyKilledToPart;
                                    eid : EntityId;
                                    dm_parts__type : StringList)
  let hitHead = uint(evt.collNodeId) < uint(length(dm_parts__type)) && dm_parts__type[evt.collNodeId] == "head"
  if evt.damageType == int(DamageType.DM_PROJECTILE) && hitHead
    let forceDisabled = find_query() <| $ [es(REQUIRE=forceDisableHeadShotSound)] () => true
    if forceDisabled
      return
    send_net_event(eid, EventHeadShotKill() )

[es(tag=server)]
def entity_was_killed_by_headshot(evt : EventEntityWasKilledToPart;
                                  dm_parts__type : StringList;
                                  var human__isKilledByHeadShot : bool&)
  let hitHead = uint(evt.collNodeId) < uint(length(dm_parts__type)) && dm_parts__type[evt.collNodeId] == "head"
  if evt.damageType == int(DamageType.DM_PROJECTILE) && hitHead
    human__isKilledByHeadShot = true