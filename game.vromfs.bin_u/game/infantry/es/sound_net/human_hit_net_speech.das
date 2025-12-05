require ecs
require ecs.safe
require %appGame.infantry.es.team_common
require math
require math.base

require %appGame.wt_events
require %appGame.infantry.es.hitpoints_common
require %appGame.infantry.es.hit_result_common
require human_net_speech.modules.human_net_speech_request_common


def was_killed(evt : EventOnEntityHit)
  return (evt.hitResult == int(HitResult.HIT_RES_KILLED))


def is_concussed(eid : EntityId)
  var isConcussed = false
  query(eid) <| $ [es] (concussion__isActive : bool)
    isConcussed = concussion__isActive
  return isConcussed


[es(tag=server)]
def human_hit_net_speech(evt : EventOnEntityHit;
                         eid : EntityId;
                         transform : float3x4;
                         isAlive : bool;
                         team : int;
                         human_net_speech__isFarKillThreshold = 100.)
  if evt.victim == evt.offender || !isAlive
    return

  if evt.victim != eid && evt.offender != eid
    return

  if evt.hitResult == int(HitResult.HIT_RES_NONE)
    return

  assume dd = evt
  if dd.damageType != int(DamageType.DM_PROJECTILE) && dd.damageType != int(DamageType.DM_EXPLOSION) && dd.damageType != int(DamageType.DM_MELEE) && dd.damageType != int(DamageType.DM_BACKSTAB)
    return

  let thisTeam = team
  var isFriendly = false
  query(evt.victim != eid ? evt.victim : evt.offender) <| $ [es] (team aka other_team : int)
    isFriendly = is_teams_friendly(thisTeam, other_team)
  if isFriendly
    return

  if evt.victim == eid
    if !was_killed(evt) && (dd.damageType == int(DamageType.DM_PROJECTILE) || dd.damageType == int(DamageType.DM_EXPLOSION))
      request_net_speech(evt.victim, "wounded")

  elif evt.offender == eid
    if was_killed(evt) && !is_concussed(evt.victim)
      if dd.damageType == int(DamageType.DM_EXPLOSION)
        request_net_speech(evt.offender, "enemyKillExplode")
      elif length_sq(dd.hitPos - transform[3]) > square(human_net_speech__isFarKillThreshold)
        request_net_speech(evt.offender, "enemyKillFar")
      else
        request_net_speech(evt.offender, "enemyKill")
    else
      request_net_speech(evt.offender, "enemyHit")


























