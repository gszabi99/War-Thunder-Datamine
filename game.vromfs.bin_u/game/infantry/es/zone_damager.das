require ecs
require ecs.common
require math.base
require %appGame.infantry.es.hitpoints_common
require %appGame.infantry.es.team_common

require %appGame.wt_events
require Grid
require DagorMath
require PropsManager


let ZERO_MULT = 0.001 

def is_friendly_damage(victim_eid, offender_eid : EntityId; victim_team : int) : bool
  if offender_eid == INVALID_ENTITY_ID || victim_eid == offender_eid
    return false
  let offenderTeam = get_int(offender_eid, "team") ?? TEAM_UNASSIGNED
  return offenderTeam == victim_team

def burn_damage(cur_time, dt : float; victim_eid, offender_eid : EntityId; victim_team : int; victim_pos : float3;
                fire_affect, fire_start_time : float; gun_props_id, shell_id : PropsId)
  query(victim_eid) <| $ [es] (var burning__isBurning : bool&;
                               var burning__offender : EntityId&;
                               var burning__tickIncrement : float&;
                               var burning__offenderGunPropsId : PropsId&;
                               var burning__offenderShellId : PropsId&;
                               burning__friendlyDamagePerSecond : float = 0.0;
                               burning__friendlyDamageProtectionTime : float = 3.0;
                               entity_mods__fireDamageMult : float = 1.0)
    let isFriendlyDamageTime = fire_start_time >= 0.0 && cur_time < fire_start_time + burning__friendlyDamageProtectionTime
    if isFriendlyDamageTime && is_friendly_damage(victim_eid, offender_eid, victim_team)
      let friendlyDamage = burning__friendlyDamagePerSecond * dt * entity_mods__fireDamageMult
      sendEvent(victim_eid, CmdApplyDamage(offender = offender_eid, damageType = int(DamageType.DM_FIRE), shellId = props_pack_for_net(PropsId()), gunPropsId = props_pack_for_net(PropsId()), deltaHp = friendlyDamage, hitPos = victim_pos))

    else
      let fireDamage = fire_affect * dt * entity_mods__fireDamageMult
      if fireDamage <= 0.0
        return

      burning__isBurning = true
      burning__offender = offender_eid
      burning__tickIncrement = max(burning__tickIncrement, fireDamage)
      burning__offenderGunPropsId = gun_props_id
      burning__offenderShellId = shell_id


def dmgzone_check_visitor(visitor_eid, offender_eid : EntityId;
                          curTime, dt, dmgzone_damage, dmgzone_fireAffect, fire_source__startTime : float;
                          gun_props_id, shell_id : PropsId;
                          team_to_damage, damage_type_id : int;
                          damage_in_vehicle : bool; ignore_fire_resistance : bool;
                          var eids_in_zone : EidList?)
  query(visitor_eid) <| $ [es(REQUIRE=dmgzoneVulnerable, REQUIRE_NOT=deadEntity)] (transform : float3x4;
                                                                                   isInVehicleHidden : bool = false;
                                                                                   team : int = TEAM_UNASSIGNED;
                                                                                   game_effect__invisible : bool = false;
                                                                                   entity_mods__zoneDamageMult : float = 1.0;
                                                                                   dmgzone_fire_resistance__maxTicks : int = 0;
                                                                                   var dmgzone_fire_resistance__currentTicks : int&;
                                                                                   var dmgzone_fire_resistance__lastTickAt : float&)
    if !damage_in_vehicle && isInVehicleHidden
      return
    if team_to_damage != TEAM_UNASSIGNED && team_to_damage != team
      return
    if game_effect__invisible && offender_eid |> has("dmgzone__ignoreInvisibleTargets")
      return

    if eids_in_zone != null
      *eids_in_zone |> push(visitor_eid)

    if dmgzone_damage > 0.0 && entity_mods__zoneDamageMult > ZERO_MULT
      let damage = dmgzone_damage * dt * entity_mods__zoneDamageMult
      let damageType = DamageType(int(damage_type_id))
      
      sendEvent(visitor_eid, CmdApplyDamage(offender = offender_eid, damageType = int(damageType), shellId = props_pack_for_net(shell_id), gunPropsId = props_pack_for_net(gun_props_id), deltaHp = damage, hitPos = transform[3]))

    if ignore_fire_resistance || dmgzone_fireAffect > 0.0 && dmgzone_fire_resistance__currentTicks >= 0 
      dmgzone_fire_resistance__currentTicks += 1
      dmgzone_fire_resistance__lastTickAt = curTime
      let shouldDamage = ignore_fire_resistance || dmgzone_fire_resistance__maxTicks < dmgzone_fire_resistance__currentTicks

      if shouldDamage
        burn_damage(curTime, dt, visitor_eid, offender_eid, team, transform[3],
                    dmgzone_fireAffect, fire_source__startTime, gun_props_id, shell_id)


[es(tag=server, before=fire_damage)]
def dmgzone_es(info : UpdateStageInfoAct;
               eid : EntityId;
               transform : float3x4;
               dmgzone__damage : float;
               var dmgzone__lastUpdate : float&;
               var dmgzone__eidsInZone : EidList?;
               dmgzone__igniteEntitiesInitially : Tag const?;
               dmgzone__updateInterval : float = 1.0;
               dmgzone__teamToDamage : int = TEAM_UNASSIGNED;
               dmgzone__damageInVehicle : bool = true;
               dmgzone__fireAffect : float = -1.0;
               dmgzone__offender : EntityId const?;
               dm__damageTypeId : int = int(DamageType.DM_ZONE);
               fire_source__startTime : float = -1.0;
               dmgzone__gunPropsId : PropsId const?;
               dmgzone__shellId : PropsId const?;
               sphere_zone__radius : float;
               sphere_zone__inverted : bool = false)
  var dt : float
  var ignoreFireResistance = false

  if dmgzone__lastUpdate > 0.f
    dt = info.curTime - dmgzone__lastUpdate
    if dt < dmgzone__updateInterval
      return
    dmgzone__lastUpdate = info.curTime
  else 
    dmgzone__lastUpdate = info.curTime + dmgzone__updateInterval * eid_frnd(eid)
    if dmgzone__igniteEntitiesInitially != null
      ignoreFireResistance = true
      dt = 0.001 
    else
      return

  if dmgzone__eidsInZone != null
    *dmgzone__eidsInZone |> clear()
  let offenderEid = dmgzone__offender ?? eid

  var gunPropsId = PropsId()
  if dmgzone__gunPropsId != null
    gunPropsId = *dmgzone__gunPropsId

  var shellId = PropsId()
  if dmgzone__shellId != null
    shellId = *dmgzone__shellId

  if !sphere_zone__inverted
    for_each_entity_in_grid(ecs_hash("humans"), BSphere3(transform[3], sphere_zone__radius), GridEntCheck.BOUNDING) <| $(visitorEid : EntityId)
      dmgzone_check_visitor(visitorEid, offenderEid,
                            info.curTime, dt, dmgzone__damage, dmgzone__fireAffect, fire_source__startTime,
                            gunPropsId, shellId, dmgzone__teamToDamage, dm__damageTypeId,
                            dmgzone__damageInVehicle, ignoreFireResistance, dmgzone__eidsInZone)
  else
    let invTm = inverse(transform)
    let zoneRadiusSq = square(sphere_zone__radius)
    query() <| $ [es(REQUIRE=dmgzoneVulnerable, REQUIRE_NOT=deadEntity)] (eid : EntityId; transform : float3x4)
      if sphere_zone__inverted == (length_sq(invTm * transform[3]) < zoneRadiusSq)
        return
      dmgzone_check_visitor(eid, offenderEid,
                            info.curTime, dt, dmgzone__damage, dmgzone__fireAffect, fire_source__startTime,
                            gunPropsId, shellId, dmgzone__teamToDamage, dm__damageTypeId,
                            dmgzone__damageInVehicle, ignoreFireResistance, dmgzone__eidsInZone)















