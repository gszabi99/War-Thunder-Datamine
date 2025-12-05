require ecs
require %game.events

require %appGame.wt_events
require DngHuman

[es(tag=server)]
def human_collider_damage(evt : CmdPostPhysUpdate;
                          eid : EntityId;
                          human_net_phys : HumanActor;
                          transform : float3x4;
                          isAlive : bool;
                          hitpoints__hp : float;
                          human_coll_damage__minDmgSpd : float;
                          human_coll_damage__dmgPow : float;
                          human_coll_damage__hpCoeff : float;
                          human_coll_damage__minFallDmgVal : float;
                          human_coll_damage__minHpLevel : float;
                          disable_collision : bool = false;
                          entity_mods__lessFallDmgMult : float = 1.f)
  if !evt.isForReal || disable_collision
    return

  let minDmgSpdSquare = human_coll_damage__minDmgSpd * human_coll_damage__minDmgSpd
  if isAlive && length_sq(human_net_phys.phys.currentState.spdSummaryDiff) > minDmgSpdSquare
    let dmgSpd = length(human_net_phys.phys.currentState.spdSummaryDiff)

    var damage = human_coll_damage__minFallDmgVal
    damage += pow(dmgSpd - human_coll_damage__minDmgSpd, human_coll_damage__dmgPow) * human_coll_damage__hpCoeff

    if human_net_phys.phys.currentState.spdSummaryDiff.y > 0.f
      damage *= entity_mods__lessFallDmgMult

    if hitpoints__hp > 0.0
      damage = min(damage, hitpoints__hp - human_coll_damage__minHpLevel)

    if damage > 0.f
      sendEvent(eid, CmdCollisionDamage(damage = damage, pos = transform[3], offender = eid))
