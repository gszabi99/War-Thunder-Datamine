require ecs
require ecs.common
require ecs.safe
require strings
require math.base
require dm
require DagorConsole
require DagorMath
require DagorRandom
require DagorSystem
require Weapon
require DngHuman
require WTPhysActor
require PhysMat
require PropsManager
require level
require app
require Unit
require net
require %appGame.infantry.es.team_common
require %appGame.infantry.es.armor_common
require %appGame.infantry.es.hitpoints_common
require %appGame.infantry.es.hit_result_common
require %game.utils.net_utils
require %game.dm.dm_events
require %game.events
require vehicle
require AnimV20
require GeomNodeTree
require CollRes
require WTDamageModel

require %appGame.wt_events

struct ApplyDamageData
  victim : EntityId
  offender : EntityId
  pos : float3
  projPropsId : PropsId = PropsId()
  damageToHp : float
  damageToArmor : float
  armorSegmentEid : EntityId
  damageType : DamageType
  collNodeId : int
  dir : float3
  isExplosionHaveProps : bool
  armorEfficiency : float
  damageToArmorPercent : float
  outputDebug : bool

[cpp_event(unicast)]
struct EventOnPhysImpulse
  atTime : float
  nodeId : int
  pos : float3
  impulse : float3

struct EntityHitData
  victim : EntityId
  offender : EntityId
  gunEid : EntityId
  projPropsId : PropsId = PropsId()
  pos : float3
  dir : float3
  collNodeId : int
  vel : float3
  distance : float
  piercingShift : float
  startPos : float3
  startVel : float3

struct EntityShatterHitData
  victim : EntityId
  offender : EntityId
  projPropsId : PropsId = PropsId()
  pos : float3
  dir : float3
  collNodeId : int
  penetration : float

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct EventNotifyServerOnHitEntity
  offender : EntityId
  gunEid : EntityId
  projPropsId : uint
  pos : float3
  dir : float3
  collNodeId : int
  vel : float3
  distance : float
  piercingShift : float
  startPos : float3
  startVel : float3


def damage_debug_msg(s : string)
  logmessage(3, s) 
  console_print(s)


[es(tag=render, on_appear)]
def init_hit_fx_material(evt : Event;
                         entity__hitFxMaterialName : string;
                         var entity__hitFxMaterialId : int&)
  entity__hitFxMaterialId = get_material_id(entity__hitFxMaterialName)


[es(tag=render, on_appear)]
def init_hit_fx_material_item(evt : Event;
                              item__hitFxMaterialNames : StringList;
                              var item__hitFxMaterialIds : IntList&)
  for name in item__hitFxMaterialNames
    push(item__hitFxMaterialIds, get_material_id(string(name)))


def apply_damage(data : ApplyDamageData)
  apply_damage(data.victim, data.offender, data.pos, data.projPropsId, data.damageToHp,
    data.damageToArmor, data.armorSegmentEid, data.damageType, data.collNodeId, data.outputDebug,
    data.dir, data.isExplosionHaveProps, data.armorEfficiency, data.damageToArmorPercent)


def apply_damage(victim : EntityId;
                 offender : EntityId;
                 hit_pos : float3;
                 proj_props_id : PropsId;
                 damage_to_hp : float;
                 damage_to_armor : float;
                 armor_item_eid : EntityId;
                 damage_type : DamageType;
                 coll_node_id : int;
                 output_debug = false;
                 hit_dir = float3(0., 0., 0.);
                 is_explosion_have_props : bool = true;
                 armor_efficiency : float = 0.;
                 damage_to_armor_percent : float = 0.)
  query(victim) <| $ [es] (beh_tree__enabled aka victim_beh_tree__enabled : bool = false;
                           var hitpoints__hp : float&;
                           hitpoints__maxHp : float;
                           var hitpoints__lastHitPos : float3&;
                           var hitpoints__lastOffender : OffenderData&;
                           var mainOffender : OffenderData&;
                           var isAlive : bool&;
                           dm_parts__type : StringList const?;
                           hitpoints__dmgMult : float = 1.f;
                           hitpoints__deathHpThreshold : float = -10.f)
    let isDowned = hitpoints__hp <= 0.f
    var deltaHp = damage_to_hp * hitpoints__dmgMult
    var victim_unit = get_unit(victim)

    var offenderPossessedByPlayer = INVALID_ENTITY_ID
    let offenderExists = query(offender) <| $ [es] (possessedByPlr : EntityId)
      offenderPossessedByPlayer = possessedByPlr

    let victimPlayer = get_Eid(victim, "possessedByPlr") ?? INVALID_ENTITY_ID
    if victim != offender
      let isOffenderBehTreeEnabled = get_bool(offender, "beh_tree__enabled") ?? false
      
      if !isOffenderBehTreeEnabled && victim_beh_tree__enabled
        query(offenderPossessedByPlayer) <| $ [es] (player__damageToBotsScale : float)
          deltaHp *= player__damageToBotsScale
      
      if isOffenderBehTreeEnabled && !victim_beh_tree__enabled
        query(victimPlayer) <| $ [es] (player__damageFromBotsScale : float)
          deltaHp *= player__damageFromBotsScale

    let wasDead = hitpoints__hp <= 0f
    let prevHitpointsHp = hitpoints__hp

    
    if damage_type == DamageType.DM_BACKSTAB
      hitpoints__hp = hitpoints__deathHpThreshold
    elif isDowned && (damage_type == DamageType.DM_MELEE || damage_type == DamageType.DM_BACKSTAB)
      hitpoints__hp = hitpoints__deathHpThreshold
    else
      hitpoints__hp = max(hitpoints__hp - deltaHp, hitpoints__deathHpThreshold)

    if output_debug
      damage_debug_msg("---HP CHANGE---")
      damage_debug_msg("before {prevHitpointsHp}, after {hitpoints__hp}")

    var hitr : HitResult
    if wasDead
      hitr = HitResult.HIT_RES_NONE
    elif hitpoints__hp > 0.
      hitr = HitResult.HIT_RES_NORMAL
    else
      hitr = HitResult.HIT_RES_KILLED

    var offender_data = OffenderData(offender, proj_props_id)
    if damage_type == DamageType.DM_COLLISION && offender != INVALID_ENTITY_ID && offender != victim
      offender_data.dmgTypeForUnlock = UnlockDmgType.UNL_DMG_TYPE_GENERIC
      offender_data.setDmgInitiatorWeaponName("ran_over")

    
    if hitr == HitResult.HIT_RES_KILLED && victim_unit != null
      
      var deathReasonByDamageType = UnitDeathReasonInner.DR_UNKNOWN
      if damage_type == DamageType.DM_PROJECTILE
        let isPartIndexValid = dm_parts__type != null && uint(coll_node_id) < uint(length(*dm_parts__type))
        let nodeType = isPartIndexValid ? string((*dm_parts__type)[coll_node_id]) : "null"
        let isHeadshot = nodeType == "head"
        if isHeadshot
          deathReasonByDamageType = UnitDeathReasonInner.DR_HEADSHOT_HIT
        else
          deathReasonByDamageType = UnitDeathReasonInner.DR_BULLET_HIT
      elif damage_type == DamageType.DM_EXPLOSION
        deathReasonByDamageType = UnitDeathReasonInner.DR_NEARBY_EXPLOSION
      elif damage_type == DamageType.DM_COLLISION
        
        if offender == victim
          deathReasonByDamageType = UnitDeathReasonInner.DR_FALL_DMG
        else
          deathReasonByDamageType = UnitDeathReasonInner.DR_RAN_OVER
      elif damage_type == DamageType.DM_MELEE || damage_type == DamageType.DM_BACKSTAB
        deathReasonByDamageType = UnitDeathReasonInner.DR_MELEE_HIT
      elif damage_type == DamageType.DM_BLEEDING
        deathReasonByDamageType = UnitDeathReasonInner.DR_BLEED_OUT
      elif damage_type == DamageType.DM_HOLD_BREATH
        deathReasonByDamageType = UnitDeathReasonInner.DR_HUMAN_DROWN
      
      if deathReasonByDamageType != UnitDeathReasonInner.DR_UNKNOWN
        *victim_unit |> trySetDeathInfoByKiller(deathReasonByDamageType, offender)
    if hitr != HitResult.HIT_RES_NONE && victim_unit != null
      
      if offender != victim && offender != INVALID_ENTITY_ID && damage_type != DamageType.DM_BLEEDING
        *victim_unit |> addHitOffender(offender_data, PartId(), deltaHp / hitpoints__maxHp,  deltaHp > 0.0)

    
    if hitr != HitResult.HIT_RES_NONE && victim_unit != null && !proj_props_id.valid
      if (damage_type == DamageType.DM_EXPLOSION && is_explosion_have_props) || damage_type == DamageType.DM_PROJECTILE
        logerr("no projectile props are passed to apply_damage, offender:{offender} victim:{victim}")

    if damage_type != DamageType.DM_BLEEDING
      send_net_event(offender, CmdShowHitMark(
        victim = victim,
        collNodeId = coll_node_id,
        armorEfficiency = armor_efficiency,
        damageToArmorPercent = damage_to_armor_percent,
        hitResult = int(hitr)
      ), target_entity_conn(offender))

      broadcastEvent(EventOnEntityHit( 
        victim = victim,
        offender = offender,
        damageType = int(damage_type),
        collNodeId = coll_node_id,
        deltaHp = deltaHp,
        hitPos = hit_pos,
        hitDir = hit_dir,
        hitResult = int(hitr)
      ))

    if !wasDead && hitpoints__hp <= 0.
      mainOffender = offender_data
      isAlive = false

      var victimTeam = TEAM_UNASSIGNED
      query(victim) <| $ [es] (team : int)
        victimTeam = team
      var offenderTeam = TEAM_UNASSIGNED
      query(offender) <| $ [es] (team : int)
        offenderTeam = team
      sendEvent(offender, EventEntityEnemyKilledToPart(collNodeId = coll_node_id, damageType = int(damage_type)))
      sendEvent(victim, EventEntityWasKilledToPart(collNodeId = coll_node_id, damageType = int(damage_type)))
      send_net_event(victim, EventEntityDied(victim = victim, offender = offender, victimTeam = victimTeam, offenderTeam = offenderTeam, collNodeId = coll_node_id))
      broadcast_net_event(EventAnyEntityDied(
        victim = victim,
        offender = offender,
        offenderPlayer = offenderPossessedByPlayer, 
        victimPlayer = victimPlayer,
        damageType = int(damage_type),
        collNodeId = coll_node_id,
        victimTeam = victimTeam,
        offenderTeam = offenderTeam
      ))

    if offender != INVALID_ENTITY_ID
      hitpoints__lastHitPos = hit_pos
      if hitpoints__lastOffender.eid != offender || proj_props_id.valid
        hitpoints__lastOffender = offender_data

    reduce_armor_durability(damage_to_armor, armor_item_eid, output_debug)


def apply_dot_damage(victim : EntityId;
                     damage : float)
  if damage <= 0.0
    return
  query(victim) <| $ [es] (hitpoints__dotBaseSpeed : float;
                           hitpoints__dotSpeedThreshold : float;
                           var hitpoints__dotDamage : FloatList&;
                           var hitpoints__totalDotAmount : float&)
    add_damage_over_time_entry(damage, hitpoints__dotBaseSpeed, hitpoints__dotSpeedThreshold, hitpoints__dotDamage, hitpoints__totalDotAmount)


def check_friendly_fire(victim_team : int;
                        offender_team : int;
                        offender_unit_type : int)
  if is_teams_friendly(victim_team, offender_team)
    if offender_unit_type == int(UnitType.UT_Airplane)
      return get_difficulty_config().aircraftFriendlyFireForBanOnly
    return true
  return false

[es(tag=gameClient)]
def on_hero_collision_damage(evt : EventOnEntityHit)
  if evt.deltaHp <= 0.f
    return
  query(evt.victim) <| $ [es(REQUIRE=hero)] (var unit__ref aka victim_unit__ref : UnitRef)
    query(evt.offender) <| $ [es] (unit__ref aka offender_unit__ref : UnitRef)
      *victim_unit__ref.unit |> onEffectiveHit(make_offender_data(offender_unit__ref.uid, -1), 0., uint8(0), CritDebuffType.CRIT_TYPE_NONE)

[es(tag=server, REQUIRE=human)]
def on_entity_collision_damage(evt : EventUnitToUnitCollision;
                               eid : EntityId;
                               team aka victim_team : int;
                               isAlive : bool;
                               human_net_phys__velocity = float3(0., 0., 0.);
                               human__enemySpeedDamageThreshold = 4.;
                               human__enemySpeedDifDamageThreshold = 4.;
                               human__enemyImpulseToDamageMul = 0.08;
                               human__friendlyImpulseToDamageMul = 0.04)
  if isAlive && evt.damage > 0.0 && !evt.isFriction
    query(evt.toUnit) <| $ [es] (vehicle_net_phys : VehiclePhysActor;
                                 unitType : int;
                                 team aka offender_team : int = -1)
      let vehicleSpeed = float3(vehicle_net_phys.phys.currentState.velocity)
      if length(vehicleSpeed) < human__enemySpeedDamageThreshold
        return
      if length(vehicleSpeed - human_net_phys__velocity) < human__enemySpeedDifDamageThreshold
        return
      let friendly = check_friendly_fire(victim_team, offender_team, unitType)
      let impulseToDamage = friendly ? human__friendlyImpulseToDamageMul : human__enemyImpulseToDamageMul
      let damage = abs(evt.fullImpulse) * impulseToDamage
      apply_damage(eid, evt.toUnit, evt.lPos, PropsId(), damage, 0.0, INVALID_ENTITY_ID, DamageType.DM_COLLISION, 0)


[es(tag=server)]
def on_entity_hit_notify(evt : EventNotifyServerOnHitEntity;
                         eid : EntityId;
                         isAlive : bool)
  if isAlive
    let hitData = EntityHitData(victim = eid,
                                offender = evt.offender,
                                gunEid = evt.gunEid,
                                projPropsId = props_unpack_from_net(evt.projPropsId),
                                pos = evt.pos,
                                dir = evt.dir,
                                collNodeId = evt.collNodeId,
                                vel = evt.vel,
                                distance = evt.distance,
                                piercingShift = evt.piercingShift,
                                startPos = evt.startPos,
                                startVel = evt.startVel)
    var isStopped = false
    if !precheck_entity_hit(hitData.victim, hitData.offender, hitData.collNodeId, isStopped)
      return
    using() <| $(var kpp : KineticProjectileParams)
      var newPiercingShift = 0.0 
      var armorMatId = -1        
      var dotDamageToHp = 0.0
      var applyDamageData = ApplyDamageData()
      calc_entity_hit_damage(hitData, newPiercingShift, kpp, armorMatId, dotDamageToHp, applyDamageData)
      apply_dot_damage(hitData.victim, dotDamageToHp)
      apply_damage(applyDamageData)


[es(tag=server)]
def on_entity_apply_damage(evt : CmdApplyDamage;
                           eid : EntityId;
                           isAlive : bool)
  if isAlive
    let damageType = DamageType(evt.damageType)
    apply_damage(eid, evt.offender, evt.hitPos, props_unpack_from_net(evt.gunPropsId), evt.deltaHp, 0.0, INVALID_ENTITY_ID, damageType, -1)


def update_armor_ui_info(var armor_ui__info : Object&;
                         item_eid : EntityId;
                         item__armorDurabilityAmount : float;
                         item__armorDurabilityMaxAmount : float;
                         item__armorHudDmPart : string)
  if !empty(item__armorHudDmPart)
    armor_ui__info |> push_to_object(item__armorHudDmPart) <| $(var entry : Object)
      let value = safediv(item__armorDurabilityAmount, item__armorDurabilityMaxAmount)
      entry |> set("value", value)
      entry |> set("eid", item_eid)



[es(tag=gameClient, track=(item__ownerEid, item__armorDurabilityAmount), on_appear)]
def update_armor_ui_info_es(evt : Event;
                            eid : EntityId;
                            item__armorDurabilityAmount : float;
                            item__armorDurabilityMaxAmount : float;
                            item__armorHudDmPart : string;
                            item__ownerEid : EntityId)
  query(item__ownerEid) <| $ [es] (var armor_ui__info : Object&;
                                   var armor_ui__infoChanged : bool&)
    armor_ui__infoChanged = true
    update_armor_ui_info(armor_ui__info, eid, item__armorDurabilityAmount, item__armorDurabilityMaxAmount, item__armorHudDmPart)


[es(tag=gameClient, track=(item__ownerEid, segmented_armor__segmentsEids), on_appear)]
def update_segmented_armor_ui_info_es(evt : Event;
                                      segmented_armor__segmentsEids : EidList;
                                      item__ownerEid : EntityId)
  query(item__ownerEid) <| $ [es] (var armor_ui__info : Object&;
                                   var armor_ui__infoChanged : bool&)
    armor_ui__infoChanged = true
    for segmentEid in segmented_armor__segmentsEids
      query(segmentEid) <| $ [es] (item__armorDurabilityAmount : float;
                                   item__armorDurabilityMaxAmount : float;
                                   item__armorHudDmPart : string)
        update_armor_ui_info(armor_ui__info, segmentEid, item__armorDurabilityAmount, item__armorDurabilityMaxAmount, item__armorHudDmPart)


[es(tag=gameClient, track=dm_parts__armorItemEids, on_appear)]
def update_all_armor_ui_info_es(evt : Event;
                                dm_parts__armorItemEids : EidList;
                                var armor_ui__info : Object&;
                                var armor_ui__infoChanged : bool&)
  armor_ui__infoChanged = true
  for armorItemEid in dm_parts__armorItemEids
    query(armorItemEid) <| $ [es] (item__armorDurabilityAmount : float const?;
                                   item__armorDurabilityMaxAmount : float const?;
                                   item__armorHudDmPart : string = "";
                                   segmented_armor__segmentsEids : EidList const?)
      if segmented_armor__segmentsEids == null
        if item__armorDurabilityAmount != null && item__armorDurabilityMaxAmount != null
          update_armor_ui_info(armor_ui__info, armorItemEid, *item__armorDurabilityAmount, *item__armorDurabilityMaxAmount, item__armorHudDmPart)
      else
        for segmentEid in *segmented_armor__segmentsEids
          query(segmentEid) <| $ [es] (item__armorDurabilityAmount : float;
                                       item__armorDurabilityMaxAmount : float;
                                       item__armorHudDmPart : string)
            update_armor_ui_info(armor_ui__info, armorItemEid, item__armorDurabilityAmount, item__armorDurabilityMaxAmount, item__armorHudDmPart)


[es(tag=gameClient, no_order)]
def on_hero_armor_ui_info_change(info : UpdateStageInfoAct;
                                 var armor_ui__infoChanged : bool&;
                                 hero : Tag const?)
  if armor_ui__infoChanged
    armor_ui__infoChanged = false
    if hero != null
      broadcastEvent(EventArmorInfoChanged())


def notify_server_about_entity_hit(hitData : EntityHitData)
  send_net_event(hitData.victim, EventNotifyServerOnHitEntity(offender = hitData.offender,
                                                              gunEid = hitData.gunEid,
                                                              projPropsId = props_pack_for_net(hitData.projPropsId),
                                                              pos = hitData.pos,
                                                              dir = hitData.dir,
                                                              collNodeId = hitData.collNodeId,
                                                              vel = hitData.vel,
                                                              distance = hitData.distance,
                                                              piercingShift = hitData.piercingShift,
                                                              startPos = hitData.startPos,
                                                              startVel = hitData.startVel))

def calc_armor_durability_mult(durability_rel : float; durability_to_armor_table : Point2List)
  if empty(durability_to_armor_table)
    return 1.0

  if durability_rel >= durability_to_armor_table[0].x
    return durability_to_armor_table[0].y

  let maxIndex = length(durability_to_armor_table) - 1
  if durability_rel < durability_to_armor_table[maxIndex].x
    return durability_to_armor_table[maxIndex].y

  
  for i in 0..maxIndex
    let elemLower = durability_to_armor_table[i + 1]
    if durability_rel < elemLower.x
      continue
    let elemUpper = durability_to_armor_table[i]
    return cvt(durability_rel, elemLower.x, elemUpper.x, elemLower.y, elemUpper.y)

  
  return 0.0


def calc_total_armor(part_armor : float;
                     mod_armor_mult : float;
                     mod_def_armor : float;
                     water_armor : float)
  return part_armor * mod_armor_mult + mod_def_armor + water_armor


def calc_kinetic_damage_after_armor(props_id : PropsId;
                                    kinetic_projectile_params : KineticProjectileParams;
                                    projectile_dist : float;
                                    projectile_speed : float;
                                    piercing_shift_after_armor : float;
                                    residual_penetration : float;
                                    pos : float3)
  var kineticDamage = 0.0

  if residual_penetration > 0.0 
    let totalProjectileDistAfterArmor = projectile_dist + piercing_shift_after_armor
    let isUnderwater = pos.y < get_water_level()
    kineticDamage = calc_bullet_projectile_damage(props_id, kinetic_projectile_params, isUnderwater, totalProjectileDistAfterArmor, projectile_speed,  0.0)

  return kineticDamage


struct ChangesAfterArmor
  damage : float
  armorEfficiency : float
  piercingShiftAfterArmor : float

def calc_changes_after_armor(props_id : PropsId;
                             kinetic_projectile_params : KineticProjectileParams;
                             armor : float;
                             penetration : float;
                             projectile_dist : float;
                             piercing_shift : float;
                             projectile_speed : float;
                             pos : float3)
  var res : ChangesAfterArmor
  let residualPenetration = penetration - armor
  res.piercingShiftAfterArmor = armor < FLT_EPSILON ? piercing_shift : calc_penetration_shift(props_id, kinetic_projectile_params, residualPenetration, projectile_dist, 1.0, piercing_shift)
  res.damage = calc_kinetic_damage_after_armor(props_id, kinetic_projectile_params, projectile_dist, projectile_speed, res.piercingShiftAfterArmor, residualPenetration, pos)
  let damageWithoutArmor = calc_kinetic_damage_after_armor(props_id, kinetic_projectile_params, projectile_dist, projectile_speed, piercing_shift, penetration, pos)
  res.armorEfficiency = 1.0 - saturate(safediv(res.damage, damageWithoutArmor))
  return res


def calc_shatter_damage(armor : float;
                        penetration : float;
                        penetration_min : float;
                        penetration_max : float;
                        damage_min : float;
                        damage_max : float;
                        damage_scale : float)
  let residualPenetration = penetration - armor
  let damage = residualPenetration <= 0.0 ? 0.0 : cvt(residualPenetration, penetration_min, penetration_max, damage_min, damage_max) * damage_scale
  return damage


def format_segment_hit_chances(hit_chances : array<float>)
  let res = build_string() <| $(str)
    for hitChance in hit_chances
      if hitChance == -1.0
        str |> write("N/A    ")
      else
        str |> write("{format("%.2f", hitChance)}  ")
  return res


def calc_armor_params(victim_eid : EntityId;
                      animchar : AnimcharBaseComponent;
                      coll_node_id : int;
                      orientation_node_id : int;
                      dir : float3;
                      output_debug : bool;
                      var armor_segment_eid : EntityId&;
                      var part_armor : float&;
                      var part_armor_min : float&;
                      var armor_durability : float&;
                      var armor_durability_max : float&;
                      var armor_mat_id : int&)
  var foundArmorItemEid = INVALID_ENTITY_ID
  query(victim_eid) <| $ [es] (dm_parts__armorItemEids : EidList)
    for armorItemEid in dm_parts__armorItemEids
      query(armorItemEid) <| $ [es] (item__armoredPartsIds : IntList)
        if find_index(item__armoredPartsIds, coll_node_id) >= 0
          foundArmorItemEid = armorItemEid
      if !!foundArmorItemEid
        return

  armor_segment_eid = foundArmorItemEid
  armor_mat_id = -1

  if !foundArmorItemEid
    return

  var hitChances : array<float>
  var maxHitChance = 0.0
  query(foundArmorItemEid) <| $ [es] (@shared_comp segmented_armor__hitChances4Sides : Point4List)
    var orientationTm : float3x4
    *animchar.nodeTree |> geomtree_getNodeWtmScalar(orientation_node_id, orientationTm)
    let dirProjection = normalize(dir - dot(orientationTm[0], dir) * orientationTm[0])
    let forwardPart = -dot(dirProjection, orientationTm[1])
    let sidePart = dot(dirProjection, orientationTm[2])
    let hitAngle = atan2(sidePart, forwardPart)
    var quarter = -1
    var hitAngleInQuarter = 0.0
    if hitAngle < -HALF_PI
      quarter = 2
      hitAngleInQuarter = hitAngle + PI
    elif hitAngle < 0.0
      quarter = 3
      hitAngleInQuarter = hitAngle + HALF_PI
    elif hitAngle < HALF_PI
      quarter = 0
      hitAngleInQuarter = hitAngle
    else
      quarter = 1
      hitAngleInQuarter = hitAngle - HALF_PI
    for hitChance4Sides in segmented_armor__hitChances4Sides
      let hitChance = hitChance4Sides[quarter] * square(cos(hitAngleInQuarter)) + hitChance4Sides[(quarter + 1) % 4] * square(sin(hitAngleInQuarter))
      push(hitChances, hitChance)
      if hitChance > maxHitChance
        maxHitChance = hitChance
    if output_debug
      damage_debug_msg("---HIT DIRECTION---")
      damage_debug_msg("absolute angle {hitAngle * RAD_TO_DEG}, angle in quarter {hitAngleInQuarter * RAD_TO_DEG}, quarter {quarter + 1}")

  if empty(hitChances)
    query(foundArmorItemEid) <| $ [es] (@shared_comp segmented_armor__hitChances : FloatList)
      for hitChance in segmented_armor__hitChances
        push(hitChances, hitChance)
        if hitChance > maxHitChance
          maxHitChance = hitChance

  
  
  query(foundArmorItemEid) <| $ [es] (segmented_armor__armoredPartsIds : Array;
                                      segmented_armor__segmentsEids : EidList;
                                      segmented_armor__hitChanceRatioThreshold : float;
                                      @shared_comp segmented_armor__hudDMAssignment : StringList)
    if output_debug
      damage_debug_msg("---SEGMENT SELECTION---")
      damage_debug_msg("hit chances before filtering: {format_segment_hit_chances(hitChances)}")
    for hitChance, partsIdsCC in hitChances, segmented_armor__armoredPartsIds
      if safediv(hitChance, maxHitChance) < segmented_armor__hitChanceRatioThreshold
        hitChance = 0.0
        continue
      let partsIds = get_ecs_IntList(partsIdsCC)
      if partsIds == null || find_index(*partsIds, coll_node_id) < 0
        hitChance = -1.0 
    if output_debug
      damage_debug_msg("hit chances after filtering:  {format_segment_hit_chances(hitChances)}")
    var consideredSegments : array<EntityId>
    var consideredSegmentsAccumHitChances : array<float>
    var totalHitChance = 0.0
    for segmentEid, hitChance in segmented_armor__segmentsEids, hitChances
      if hitChance > 0.0
        totalHitChance += hitChance
        push(consideredSegmentsAccumHitChances, totalHitChance)
        push(consideredSegments, segmentEid)
    for accumHitChance in consideredSegmentsAccumHitChances
      accumHitChance /= totalHitChance
    let rand = rnd_float(0.0, 1.0)
    for segmentEid, accumHitChance in consideredSegments, consideredSegmentsAccumHitChances
      if rand <= accumHitChance
        armor_segment_eid = segmentEid
        if output_debug
          if segmentEid == INVALID_ENTITY_ID
            damage_debug_msg("chosen segment #: body")
          else
            let idx = find_index(segmented_armor__segmentsEids, segmentEid)
            damage_debug_msg("chosen segment #: {idx} ({segmented_armor__hudDMAssignment[idx]})")
        return
    armor_segment_eid = INVALID_ENTITY_ID 

  query(armor_segment_eid) <| $ [es] (item__armorAmount : float;
                                      item__armorAmountMin : float;
                                      item__armorDurabilityAmount : float;
                                      item__armorDurabilityMaxAmount : float;
                                      item__durabilityToArmorTable : Point2List;
                                      item__durabilityToArmorMinTable : Point2List;
                                      item__hitFxMaterialRelDurabilities : FloatList;
                                      item__hitFxMaterialIds : IntList)
    let armorDurabilityAmountRel = safediv(item__armorDurabilityAmount, item__armorDurabilityMaxAmount)
    let armorDurabilityMult = calc_armor_durability_mult(armorDurabilityAmountRel, item__durabilityToArmorTable)
    let armorMinDurabilityMult = calc_armor_durability_mult(armorDurabilityAmountRel, item__durabilityToArmorMinTable)
    part_armor = item__armorAmount * armorDurabilityMult
    part_armor_min = item__armorAmountMin * armorMinDurabilityMult
    armor_durability = item__armorDurabilityAmount
    armor_durability_max = item__armorDurabilityMaxAmount
    let armorRelDurability = safediv(armor_durability, armor_durability_max)
    if !is_dedicated()
      for relDurability, id in item__hitFxMaterialRelDurabilities, item__hitFxMaterialIds
        if armorRelDurability <= relDurability
          armor_mat_id = id
          break
    if output_debug
      let armorTemplate = split_template(getEntityTemplateName(armor_segment_eid))[0]
      damage_debug_msg("---ARMOR DURABILITY---")
      damage_debug_msg("template: {armorTemplate}")
      damage_debug_msg("max: {armor_durability_max}, current: {armor_durability}, relative: {armorRelDurability}")


def reduce_armor_durability(damage_to_armor : float; armor_item_eid : EntityId; output_debug : bool)
  if damage_to_armor < FLT_EPSILON
    return
  query(armor_item_eid) <| $ [es] (var item__armorDurabilityAmount : float&)
    let prevDurabilityAmount = item__armorDurabilityAmount
    item__armorDurabilityAmount = max(item__armorDurabilityAmount - damage_to_armor, 0.)
    if output_debug
      damage_debug_msg("---ARMOR CHANGE---")
      damage_debug_msg("before: {prevDurabilityAmount}, after: {item__armorDurabilityAmount}")


def should_projectile_damage_entity(offender_team : int;
                                    offender_unit_type : int;
                                    victim_team : int;
                                    victim_allow_friendly_damage : bool)
  return !check_friendly_fire(victim_team, offender_team, offender_unit_type) || victim_allow_friendly_damage


def calc_piercing_through_entity(damage : float;
                                 distance : float;
                                 piercing_shift : float;
                                 penetration_mult : float;
                                 proj_props_id : PropsId;
                                 hitpoints__fleshArmor : float;
                                 var kinetic_proj_params : KineticProjectileParams&;
                                 var new_piercing_shift : float&)
  new_piercing_shift = FLT_MAX
  if hitpoints__fleshArmor <= 0.0 || damage <= 0.0
    return false
  let armorPenetrationPower = penetration_mult * calc_armor_penetration(proj_props_id, kinetic_proj_params, distance + piercing_shift)
  if armorPenetrationPower > hitpoints__fleshArmor
    let residualPenetration = armorPenetrationPower - hitpoints__fleshArmor
    new_piercing_shift = calc_penetration_shift(proj_props_id, kinetic_proj_params, residualPenetration, distance, 1.0, piercing_shift)
    return true
  return false


def precheck_entity_hit(victim : EntityId;
                        offender : EntityId;
                        coll_node_id : int;
                        var is_stopped : bool&;
                        is_self_damage_allowed : bool = false)
  is_stopped = false
  let isSelfDamage = victim == offender

  if !is_self_damage_allowed && isSelfDamage
    return false

  var isSuccessful = false
  query(victim) <| $ [es] (dm_parts__bulletTransparent : BoolList;
                           allow_friendly_damage : Tag const?;
                           isAlive = true;
                           team aka victim_team : int = TEAM_UNASSIGNED)
    if !isAlive
      return

    let offenderTeam = get_int(offender, "team") ?? TEAM_UNASSIGNED
    let offenderUnitType = get_int(offender, "unitType") ?? -1

    if !isSelfDamage && !should_projectile_damage_entity(offenderTeam, offenderUnitType, victim_team, allow_friendly_damage != null)
      is_stopped = true
      return

    if dm_parts__bulletTransparent?[coll_node_id] ?? false
      return

    isSuccessful = true
  return isSuccessful


def calc_entity_hit_damage(hit_data : EntityHitData;
                           var new_piercing_shift : float&;
                           var kinetic_proj_params : KineticProjectileParams&;
                           var armor_mat_id : int&;
                           var dot_damage_to_hp : float&;
                           var apply_damage_data : ApplyDamageData&)
  var impactResult = ImpactResult.STOP
  new_piercing_shift = FLT_MAX
  armor_mat_id = -1
  query(hit_data.victim) <| $ [es] (animchar : AnimcharBaseComponent;
                                    collres : CollisionResource;
                                    human__segmentedArmorOrientationNodeId : int;
                                    human__damageTypeMultsById : FloatList;
                                    dm_parts__dmgMult : FloatList;
                                    dm_parts__dotMult : FloatList const?;
                                    hitpoints__fleshArmor : float = 0.0;
                                    entity_mods__defArmor = 0.0;
                                    entity_mods__armorMult = 1.0)
    let eid = hit_data.victim
    let offenderEid = hit_data.offender
    let gunEid = hit_data.gunEid
    let projPropsId = hit_data.projPropsId
    let collNodeId = hit_data.collNodeId
    let pos = hit_data.pos
    let dir = hit_data.dir
    
    let vel = hit_data.vel
    let distance = hit_data.distance
    let piercingShift = hit_data.piercingShift
    let startPos = hit_data.startPos
    let startVel = hit_data.startVel
    let dmgMult = dm_parts__dmgMult?[collNodeId] ?? 1.f
    let dotMult = dm_parts__dotMult == null ? 0.f : (*dm_parts__dotMult)?[collNodeId] ?? 0.f
    let kineticProps = get_kinetic_props(projPropsId)
    let damageTypeId = get_kinetic_damage_type_id(*kineticProps)
    let damageTypeMult = human__damageTypeMultsById?[int(damageTypeId)] ?? 1.f

    let outputDebug = find_query() <| $ [es(REQUIRE=projectileHpDamageDebug)] () => true
    if outputDebug
      damage_debug_msg("------PROJECTILE HIT------")
      damage_debug_msg("eid: {eid}")
      damage_debug_msg("---COLLISION---")
      let collNode = collres_get_node(collres, collNodeId)
      let collNodeName = collNode == null ? "ERROR!" : (*collNode).name
      damage_debug_msg("node name: {collNodeName}, node idx: {collNodeId}, dmg mult: {dmgMult}, dot mult: {dotMult}, dmg type mult: {damageTypeMult}")

    let projectileSpeed = length(vel)
    calculate_projectile_kinetic_params(kinetic_proj_params, projPropsId, startPos, startVel)
    let penetrationMult = get_float(gunEid, "gun__armorPowerMult") ?? 1.f
    let penetration = penetrationMult * calc_armor_penetration(projPropsId, kinetic_proj_params, distance + piercingShift)
    
    let waterArmor = 0.0
    let kineticDamageMult = get_float(gunEid, "gun__kineticDamageMult") ?? 1.f
    let partDmgMult = kineticDamageMult * dmgMult * damageTypeMult

    
    var armorSegmentEid = INVALID_ENTITY_ID
    var partArmor = 0.f
    var partArmorMin = 0.f
    var armorDurability = 0.f
    var armorDurabilityMax = 0.f
    calc_armor_params(eid, animchar, collNodeId, human__segmentedArmorOrientationNodeId, dir, outputDebug, armorSegmentEid, partArmor, partArmorMin, armorDurability, armorDurabilityMax, armor_mat_id)

    
    let partArmorTotal = calc_total_armor(partArmor, entity_mods__armorMult, entity_mods__defArmor, waterArmor)
    let changesHp = calc_changes_after_armor(projPropsId, kinetic_proj_params, partArmorTotal, penetration, distance,
                                             piercingShift, projectileSpeed, pos)
    let damageToHp = changesHp.damage * partDmgMult
    let piercingShiftAfterArmor = changesHp.piercingShiftAfterArmor
    let armorEfficiency = changesHp.armorEfficiency
    if outputDebug
      damage_debug_msg("---ARMOR PROTECTION (HUMAN)---")
      damage_debug_msg("penetration: {penetration}")
      damage_debug_msg("base armor: {partArmor}, total armor: {partArmorTotal}, efficiency: {armorEfficiency}")
      damage_debug_msg("base damage: {changesHp.damage}, damage: {damageToHp}")

    
    dot_damage_to_hp = damageToHp * dotMult
    if outputDebug
      damage_debug_msg("---HP DAMAGE OVER TIME---")
      damage_debug_msg("damage: {dot_damage_to_hp}")

    
    var damageToArmor = 0.f
    var damageToArmorPercent = 0.f
    var piercingShiftAfterArmorMin = 0.f
    if armorSegmentEid != INVALID_ENTITY_ID
      let partArmorMinTotal = calc_total_armor(partArmorMin, entity_mods__armorMult, entity_mods__defArmor, waterArmor)
      let changesArmor = calc_changes_after_armor(projPropsId, kinetic_proj_params, partArmorMinTotal, penetration, distance,
                                                  piercingShift, projectileSpeed, pos)
      damageToArmor = changesArmor.damage
      damageToArmorPercent = safediv(damageToArmor, armorDurabilityMax)
      piercingShiftAfterArmorMin = changesArmor.piercingShiftAfterArmor
      if outputDebug
        damage_debug_msg("---ARMOR PROTECTION (ARMOR)---")
        damage_debug_msg("penetration: {penetration}")
        damage_debug_msg("base armor: {partArmorMin}, total armor: {partArmorMinTotal}")
        damage_debug_msg("damage: {damageToArmor}")

    
    let canPierceHPEntity = has(gunEid, "gun__canPierceHPEntity")
    if canPierceHPEntity && calc_piercing_through_entity(damageToHp, distance, piercingShiftAfterArmor, penetrationMult, projPropsId, hitpoints__fleshArmor, kinetic_proj_params, new_piercing_shift)
      impactResult = ImpactResult.PENETRATE
    if outputDebug && canPierceHPEntity
      damage_debug_msg("---PIERCE THROUGH---")
      damage_debug_msg("pierced through: {impactResult == ImpactResult.PENETRATE}")

    if outputDebug
      damage_debug_msg("---EFFECTIVE DISTANCES---")
      damage_debug_msg("original: {distance + piercingShift}, into armor: {distance + piercingShiftAfterArmorMin}, into human: {distance + piercingShiftAfterArmor}, through human: {distance + new_piercing_shift}")

    apply_damage_data.victim = eid
    apply_damage_data.offender = offenderEid
    apply_damage_data.pos = pos
    apply_damage_data.projPropsId = projPropsId
    apply_damage_data.damageToHp = damageToHp
    apply_damage_data.damageToArmor = damageToArmor
    apply_damage_data.armorSegmentEid = armorSegmentEid
    apply_damage_data.damageType = DamageType.DM_PROJECTILE
    apply_damage_data.collNodeId = collNodeId
    apply_damage_data.outputDebug = outputDebug
    apply_damage_data.dir = dir
    apply_damage_data.isExplosionHaveProps = true
    apply_damage_data.armorEfficiency = armorEfficiency
    apply_damage_data.damageToArmorPercent = damageToArmorPercent
  return impactResult


def calc_and_apply_entity_shatter_hit_damage(hit_data : EntityShatterHitData;
                                             penetration_min : float;
                                             penetration_max : float;
                                             damage_min : float;
                                             damage_max : float;
                                             damage_scale : float;
                                             var penetrated_armor : float&)
  query(hit_data.victim) <| $ [es] (animchar : AnimcharBaseComponent;
                                    collres : CollisionResource;
                                    human__segmentedArmorOrientationNodeId : int;
                                    human__damageTypeMultsById : FloatList;
                                    dm_parts__dmgMult : FloatList;
                                    dm_parts__dotMult : FloatList const?;
                                    var hitpoints__dotDamage : FloatList?;
                                    var hitpoints__totalDotAmount : float?;
                                    hitpoints__dotBaseSpeed : float = 1.0;
                                    hitpoints__dotSpeedThreshold : float = 1.0;
                                    entity_mods__defArmor = 0.0;
                                    entity_mods__armorMult = 1.0)
    let eid = hit_data.victim
    let offenderEid = hit_data.offender
    let projPropsId = hit_data.projPropsId
    let collNodeId = hit_data.collNodeId
    let pos = hit_data.pos
    let dir = hit_data.dir
    
    let penetration = hit_data.penetration

    let dmgMult = dm_parts__dmgMult?[collNodeId] ?? 1.f
    let dotMult = dm_parts__dotMult == null ? 0.f : (*dm_parts__dotMult)?[collNodeId] ?? 0.f
    let damageTypeMult = human__damageTypeMultsById[int(get_damage_type_id_by_name("shatter"))]

    let outputDebug = find_query() <| $ [es(REQUIRE=projectileHpDamageDebug)] () => true
    if outputDebug
      damage_debug_msg("------SHATTER HIT------")
      damage_debug_msg("eid: {hit_data.victim}")
      damage_debug_msg("---COLLISION---")
      let collNode = collres_get_node(collres, collNodeId)
      let collNodeName = collNode == null ? "ERROR!" : (*collNode).name
      damage_debug_msg("node name: {collNodeName}, node idx: {collNodeId}, dmg mult: {dmgMult}, dot mult: {dotMult}, dmg type mult: {damageTypeMult}")

    
    let waterArmor = 0.0
    let partDmgMult = dmgMult * damageTypeMult

    
    var armorSegmentEid = INVALID_ENTITY_ID
    var partArmor = 0.f
    var partArmorMin = 0.f
    var armorDurability = 0.f
    var armorDurabilityMax = 0.f
    var armorMatId = -1
    calc_armor_params(eid, animchar, collNodeId, human__segmentedArmorOrientationNodeId, dir, outputDebug, armorSegmentEid, partArmor, partArmorMin, armorDurability, armorDurabilityMax, armorMatId)

    
    let partArmorTotal = calc_total_armor(partArmor, entity_mods__armorMult, entity_mods__defArmor, waterArmor)
    let baseDamageToHp = calc_shatter_damage(partArmorTotal, penetration, penetration_min, penetration_max, damage_min, damage_max, damage_scale)
    let damageToHp = baseDamageToHp * partDmgMult
    penetrated_armor = min(penetration, partArmorTotal)
    if outputDebug
      damage_debug_msg("---ARMOR PROTECTION (HUMAN)---")
      damage_debug_msg("penetration: {penetration}")
      damage_debug_msg("base armor: {partArmor}, total armor: {partArmorTotal}")
      damage_debug_msg("base damage: {baseDamageToHp}, damage: {damageToHp}")

    
    if hitpoints__dotDamage != null && dm_parts__dotMult != null && hitpoints__totalDotAmount != null
      let dotDamageToHp = damageToHp * dotMult
      if dotDamageToHp > 0.0
        add_damage_over_time_entry(dotDamageToHp, hitpoints__dotBaseSpeed, hitpoints__dotSpeedThreshold, *hitpoints__dotDamage, *hitpoints__totalDotAmount)
        if outputDebug
          damage_debug_msg("---HP DAMAGE OVER TIME---")
          damage_debug_msg("damage: {dotDamageToHp}")

    
    var damageToArmor = 0.f
    var partArmorMinTotal = 0.f
    if armorSegmentEid != INVALID_ENTITY_ID
      partArmorMinTotal = calc_total_armor(partArmorMin, entity_mods__armorMult, entity_mods__defArmor, waterArmor)
      damageToArmor = calc_shatter_damage(partArmorMinTotal, penetration, penetration_min, penetration_max, damage_min, damage_max, damage_scale)
      if outputDebug
        damage_debug_msg("---ARMOR PROTECTION (ARMOR)---")
        damage_debug_msg("penetration: {penetration}")
        damage_debug_msg("base armor: {partArmorMin}, total armor: {partArmorMinTotal}")
        damage_debug_msg("damage: {damageToArmor}")

    apply_damage(eid, offenderEid, pos, projPropsId, damageToHp, damageToArmor, armorSegmentEid, DamageType.DM_EXPLOSION, collNodeId, outputDebug, dir)

    
    
  return true 


def get_hit_armor_mat_id(eid : EntityId;
                         coll_node_id : int;
                         dir : float3)
  var armorMatId = -1
  query(eid) <| $ [es] (animchar : AnimcharBaseComponent;
                        human__segmentedArmorOrientationNodeId : int;
                        entity__hitFxMaterialId : int = -1)
    
    var armorSegmentEid = INVALID_ENTITY_ID
    var partArmor = 0.f
    var partArmorMin = 0.f
    var armorDurability = 0.f
    var armorDurabilityMax = 0.f
    calc_armor_params(eid, animchar, coll_node_id, human__segmentedArmorOrientationNodeId, dir, false, armorSegmentEid, partArmor, partArmorMin, armorDurability, armorDurabilityMax, armorMatId)
    if armorMatId < 0
      armorMatId = entity__hitFxMaterialId
  return armorMatId


[es]
def on_entity_hit(var evt : EventOnHitEntity&;
                  eid : EntityId;
                  collres : CollisionResource)
  evt.impactRes = int(ImpactResult.NONE)
  evt.hitMatId = -1
  evt.newPiercingShift = evt.piercingShift

  let offender = evt.offender
  let gunEid = evt.gunEid
  let bulletEid = evt.bullet
  let projPropsId = PropsId(evt.packedProjPropsId)
  let collNodeId = evt.collNodeId
  let pos = evt.pos
  let dir = evt.dir
  
  let vel = evt.vel
  let distance = evt.distance
  let piercingShift = evt.piercingShift
  let startPos = evt.startPos
  let startVel = evt.startVel

  var isAlreadyPenetrated = false
  query(bulletEid) <| $ [es] (bullet__penetratedEids : EidList)
    isAlreadyPenetrated = has_value(bullet__penetratedEids, eid)

  if isAlreadyPenetrated
    return

  let mass = get_kinetic_props(projPropsId).coreMass

  let hitData = EntityHitData(victim = eid,
                              offender = offender,
                              gunEid = gunEid,
                              projPropsId = projPropsId,
                              pos = pos,
                              dir = dir,
                              collNodeId = collNodeId,
                              vel = vel,
                              distance = distance,
                              piercingShift = piercingShift,
                              startPos = startPos,
                              startVel = startVel)

  let collNodeCount = uint(collres_get_nodesCount(collres))

  var isStopped = false
  if !precheck_entity_hit(hitData.victim, hitData.offender, hitData.collNodeId, isStopped)
    if isStopped
      if uint(collNodeId) < collNodeCount
        sendEvent(hitData.victim, EventOnPhysImpulse(atTime = get_sync_time(), nodeId = collNodeId, pos = pos, impulse = vel * mass))
      evt.impactRes = int(ImpactResult.STOP)
      if !is_dedicated()
        evt.hitMatId = get_hit_armor_mat_id(hitData.victim, collNodeId, dir)
    return

  if uint(collNodeId) < collNodeCount
    sendEvent(hitData.victim, EventOnPhysImpulse(atTime = get_sync_time(), nodeId = collNodeId, pos = pos, impulse = vel * mass))

  query(offender) <| $ [es] (unit__ref aka offender_unit__ref : UnitRef)
    let offenderUnit = offender_unit__ref.unit
    let authority = (uint(offenderUnit.role) & uint(NetRole.URF_AUTHORITY)) != 0u
    let controlled = (uint(offenderUnit.role) & uint(NetRole.URF_LOCAL_CONTROL)) != 0u

    if !controlled
      evt.impactRes = int(ImpactResult.PENETRATE)
      if !is_dedicated()
        evt.hitMatId = get_hit_armor_mat_id(hitData.victim, collNodeId, dir)
      return

    var dotDamageToHp = 0.0
    var applyDamageData = ApplyDamageData()
    using() <| $(var kpp : KineticProjectileParams)
      evt.impactRes = int(calc_entity_hit_damage(hitData, evt.newPiercingShift, kpp, evt.hitMatId, dotDamageToHp, applyDamageData))
    if authority
      apply_dot_damage(hitData.victim, dotDamageToHp)
      apply_damage(applyDamageData)
    else
      notify_server_about_entity_hit(hitData)

    query(bulletEid) <| $ [es] (var bullet__penetratedEids : EidList&)
      push(bullet__penetratedEids, hitData.victim)


[es(tag=server)]
def on_splash_entity_hit(var evt : EventSplashHitEntity&;
                         eid : EntityId;
                         isAlive : bool;
                         team aka victim_team = TEAM_UNASSIGNED)
  let damage = evt.splashDamage + evt.shatterDamage

  
  let impulseK = 100.
  let impulse = evt.dir * damage * impulseK
  sendEvent(eid, EventOnPhysImpulse(atTime = get_sync_time(), nodeId = 0, pos = evt.pos, impulse = impulse))

  if !isAlive
    return

  var authority = true
  var friendly = false
  query(evt.offender) <| $ [es] (unit__ref : UnitRef;
                                 unitType : int;
                                 team aka offender_team = TEAM_UNASSIGNED)
    let unit = unit__ref.unit
    authority = (uint(unit.role) & uint(NetRole.URF_AUTHORITY)) != 0u

    friendly = evt.offender != eid && check_friendly_fire(victim_team, offender_team, unitType)

  if authority && !friendly
    apply_damage(eid, evt.offender, evt.pos, PropsId(evt.packedProjPropsId), damage, 0.0, INVALID_ENTITY_ID, DamageType.DM_EXPLOSION, 0,  false, evt.dir, evt.isExplosionHaveProps)

[es(tag=server)]
def on_melee_entity_hit(evt : EventMeleeHitEntity;
                        eid : EntityId;
                        isAlive : bool;
                        team aka victim_team = TEAM_UNASSIGNED)
  if !isAlive
    return

  query(evt.offender) <| $ [es] (unit__ref : UnitRef;
                                 unitType : int;
                                 team aka offender_team = TEAM_UNASSIGNED)
    let unit = unit__ref.unit
    let authority = (uint(unit.role) & uint(NetRole.URF_AUTHORITY)) != 0u
    if !authority
      return

    let friendly = check_friendly_fire(victim_team, offender_team, unitType)
    if friendly
      return

    apply_damage(eid, evt.offender, evt.pos, PropsId(evt.packedProjPropsId), evt.damage, 0.0, INVALID_ENTITY_ID, evt.isBackstab ? DamageType.DM_BACKSTAB : DamageType.DM_MELEE, evt.collNodeId)

[es(tag=server)]
def on_shatter_entity_hit(var evt : EventShatterHitEntity&;
                          eid : EntityId;
                          collres : CollisionResource;
                          isAlive : bool)
  let impulseK = 0.1
  let impulse = evt.dir * evt.damage * impulseK
  let collNodeCount = uint(collres_get_nodesCount(collres))
  if uint(evt.collNodeId) < collNodeCount
    sendEvent(eid, EventOnPhysImpulse(atTime = get_sync_time(), nodeId = evt.collNodeId, pos = evt.pos, impulse = impulse))

  if !isAlive
    return

  query(evt.offender) <| $ [es] (unit__ref : UnitRef)
    let offenderUnit = unit__ref.unit
    let authority = (uint(offenderUnit.role) & uint(NetRole.URF_AUTHORITY)) != 0u
    if !authority
      return

    let hitData = EntityShatterHitData(victim = eid,
                                       offender = evt.offender,
                                       projPropsId = PropsId(evt.packedProjPropsId),
                                       pos = evt.pos,
                                       dir = evt.dir,
                                       collNodeId = evt.collNodeId,
                                       penetration = evt.penetration)
    var isStopped = false
    if !precheck_entity_hit(hitData.victim, hitData.offender, hitData.collNodeId, isStopped,  true)
      return

    calc_and_apply_entity_shatter_hit_damage(hitData, evt.penetrationMin, evt.penetrationMax, evt.damageMin, evt.damageMax, evt.damageScale, evt.penetratedArmor)


[es(tag=server, REQUIRE_NOT=deadEntity)]
def hitpoints_damage_over_time_es(info : ParallelUpdateFrameDelayed;
                                  eid : EntityId;
                                  hitpoints__dotInterval : float;
                                  hitpoints__dotBaseSpeed : float;
                                  hitpoints__dotSpeedThreshold : float;
                                  hitpoints__lastOffender : OffenderData;
                                  hitpoints__lastHitPos : float3;
                                  burning__isBurning : bool;
                                  human_inventory__canUseMedkit : bool;
                                  human_inventory__entityUseEnd : float;
                                  var hitpoints__dotUpdateAt : float&;
                                  var hitpoints__dotDamage : FloatList&;
                                  var hitpoints__totalDotAmount : float&)
  if empty(hitpoints__dotDamage) || info.curTime < hitpoints__dotUpdateAt
    return

  hitpoints__dotUpdateAt = info.curTime + hitpoints__dotInterval

  if human_inventory__canUseMedkit && !burning__isBurning && info.curTime < human_inventory__entityUseEnd
    return

  var damage = min(hitpoints__dotSpeedThreshold, float(length(hitpoints__dotDamage)) * hitpoints__dotBaseSpeed * hitpoints__dotInterval)
  decrease_damage_over_time_amount(damage, hitpoints__dotDamage, hitpoints__totalDotAmount)
  apply_damage(eid, hitpoints__lastOffender.eid, hitpoints__lastHitPos, hitpoints__lastOffender.projPropsId, damage, 0.0, INVALID_ENTITY_ID, DamageType.DM_BLEEDING, -1)


[es(tag=gameClient, track=hitpoints__totalDotAmount, REQUIRE=watchedByPlr)]
def damage_over_time_finished_es(evt : Event; eid : EntityId; hitpoints__totalDotAmount : float)
  if hitpoints__totalDotAmount == 0.0
    sendEvent(eid, EventDamageOverTimeFinished())


[es(tag=server)]
def hitpoints_restore_hp_es(evt : CmdRestoreHpPart;
                            hitpoints__maxHp : float;
                            var hitpoints__hp : float&;
                            var hitpoints__lastOffender : OffenderData&)
  hitpoints__hp = hitpoints__maxHp * saturate(evt.hp)
  hitpoints__lastOffender.clear()


[es(tag=server)]
def hitpoints_restore_armor_es(evt : CmdRestoreArmor;
                               eid : EntityId)
  resupply_armor_for_soldier(eid)


[es(tag=server, REQUIRE=hitpoints)]
def hitpoints_kill_es(evt : CmdKill;
                      eid : EntityId;
                      transform : float3x4;
                      hitpoints__hp : float;
                      var hitpoints__dmgMult : float?;
                      hitpoints__deathHpThreshold : float = 0.0)
  let damage = hitpoints__hp + abs(hitpoints__deathHpThreshold)
  let damageType = DamageType(int(evt.damageType))
  if hitpoints__dmgMult != null
    *hitpoints__dmgMult = 1.f
  apply_damage(eid, evt.offender, transform[3], PropsId(evt.packedGunPropsId), damage, 0.0, INVALID_ENTITY_ID, damageType, -1)

def calc_collision_damage(delta_vel : float;
                          vel_thres : float;
                          vel_mult : float;
                          vel_pow : float) : float
  if delta_vel < vel_thres
    return 0.f
  return pow(delta_vel - vel_thres, vel_pow) * vel_mult

[es(tag=server, REQUIRE=collision_damage__threshold)]
def collision_damage(evt : CmdCollisionDamage;
                     eid : EntityId)
  let dmg = evt.damage
  if dmg <= 0.f
    return
  let pos = evt.pos
  let offender = evt.offender
  apply_damage(eid, offender, pos, PropsId(), dmg, 0.0, INVALID_ENTITY_ID, DamageType.DM_COLLISION, -1)


[es(tag=server, no_order)]
def barbwire_mat_damage(info : ParallelUpdateFrameDelayed;
                        eid : EntityId;
                        transform : float3x4;
                        human_net_phys : HumanActor;
                        barbwire_damage__matId : int;
                        barbwire_damage__damagePerSecond : float)
  assume phys = human_net_phys.phys
  assume previousState = phys.previousState
  assume currentState = phys.currentState
  let matId = currentState.torsoContactMatId

  if matId == barbwire_damage__matId
    let isChangingPos = abs(currentState.heightCurVel) > 1.0
    let isRotating = length_sq(currentState.targetGunSpd) > 1.0
    let isMoving = length_sq(currentState.velocity) > 0.01
    let isChangingWeapon = currentState.weapEquipState.curState != HUWeaponEquipState.EES_EQUIPED
    let isChangingLean = abs(currentState.leanPosition - previousState.leanPosition) > 0.1
    if isRotating || isChangingPos || isMoving || isChangingWeapon || isChangingLean
      let damage = info.dt * barbwire_damage__damagePerSecond
      apply_damage(eid, INVALID_ENTITY_ID, transform[3], PropsId(), damage, 0.0, INVALID_ENTITY_ID, DamageType.DM_BARBWIRE, -1)


[es(tag=server, track=isAlive)]
def update_squad_props_on_member_death(evt : Event;
                                       isAlive : bool;
                                       mainOffender : OffenderData;
                                       squad_member__squad : EntityId)
  if !isAlive
    query(squad_member__squad) <| $ [es] (var squad__firstMemberDeathTime : float&;
                                          var squad__memberKillers : EidList&;
                                          var squad__onlyKiller : EntityId&;
                                          squad__numAliveMembers : int)
      if squad__firstMemberDeathTime <= 0.
        squad__firstMemberDeathTime = get_sync_time()
      if find_index(squad__memberKillers, mainOffender.eid) <= -1
        push(squad__memberKillers, mainOffender.eid)
      if squad__numAliveMembers == 1
        squad__onlyKiller = (length(squad__memberKillers) == 1) ? squad__memberKillers[0] : INVALID_ENTITY_ID


[es(tag=server, on_appear)]
def human_damage_type_mults_init(evt : Event;
                                 human__damageTypeMults : Object;
                                 var human__damageTypeMultsById : FloatList&)
  resize(human__damageTypeMultsById, get_damage_types_count())
  for mult in human__damageTypeMultsById
    mult = 1.0
  for entry in human__damageTypeMults
    let id = get_damage_type_id_by_name(entry.key)
    if id == DAMAGE_TYPE_INVALID_ID_VAL
      logerr("Damage type {entry.key} does not exist")
      continue
    let mult = get_float(entry.value) ?? 1.0
    human__damageTypeMultsById[int(id)] = mult
