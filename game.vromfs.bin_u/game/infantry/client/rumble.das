require ecs
require ecs.common
require DagorMath
require WTInput
require %appGame.infantry.es.hero_common
require %appGame.infantry.es.hitpoints_common
require %appGame.wt_events
require %game.events
require hud
require app


[es(tag=gameClient)]
def rumble_on_entity_damage(evt : EventOnEntityHit)
  let victim = evt.victim
  if victim != get_controlled_hero_eid() || is_spectating() || is_playing_replay()
    return

  let deltaHp = evt.deltaHp
  if deltaHp <= 0.0
    return

  let maxHp = get_float(victim, "hitpoints__maxHp") ?? 100.0
  let relDmg = deltaHp / maxHp

  if evt.damageType == int(DamageType.DM_BACKSTAB)
    rumble_play("damagePunch", 1.0)
  elif evt.damageType == int(DamageType.DM_EXPLOSION)
    rumble_play("damagePunch", clamp(relDmg, 0.3, 1.0))
  elif evt.damageType == int(DamageType.DM_PROJECTILE)
    rumble_play("onDamageCenter", clamp(relDmg, 0.2, 1.0))
  elif evt.damageType == int(DamageType.DM_MELEE)
    rumble_play("onDamageCenter", clamp(relDmg, 0.3, 1.0))
  elif evt.damageType == int(DamageType.DM_COLLISION)
    rumble_play("onDamageCenter", clamp(relDmg, 0.1, 0.5))
  elif evt.damageType == int(DamageType.DM_FIRE) || evt.damageType == int(DamageType.DM_BLEEDING)
    rumble_play("fireOverheat", 0.3)
  elif evt.damageType == int(DamageType.DM_BARBWIRE)
    rumble_play("onDamageCenter", 0.15)
  else
    rumble_play("onDamageCenter", 0.3)


[es(tag=gameClient)]
def rumble_on_shot(evt : EventShot;
                   gun__owner : EntityId;
                   gun__curShellImpulse : float = 0.0)
  if gun__owner != get_controlled_hero_eid() || is_spectating() || is_playing_replay()
    return
  let level = clamp(gun__curShellImpulse * 0.7, 0.15, 1.0)
  rumble_play("shot", level)


[es(tag=gameClient, REQUIRE=controlledHero, track=concussion__isActive)]
def rumble_on_concussion(evt : Event;
                         concussion__isActive : bool;
                         concussion__intensityMult : float = 1.0)
  if is_spectating() || is_playing_replay()
    return
  if concussion__isActive
    rumble_play("damagePunch", clamp(concussion__intensityMult, 0.5, 1.0))
