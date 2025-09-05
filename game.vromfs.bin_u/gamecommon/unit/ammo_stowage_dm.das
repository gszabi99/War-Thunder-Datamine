require ecs
require net
require app
require dm
require math
require DagorRandom
require DagorMath
require DagorSystem
require GeomNodeTree
require Unit
require UnitFx
require AmmoStowage
require Weapon
require WTDamageModel
require IGroundModel
require %dasGameLibs.math.base
require %game.utils.utils_common
require %game.utils.component_bundle_macro
require %game.dm.fire_system_events
require %game.unit.unit_events
require %game.unit.ammo_stowage_common
require %game.unit.ammo_stowage_events
require %game.events







def get_dm_effect_flag(flags, flag)
  return get_flag(uint(flags), 1u << uint(flag))


[with_bundle(v)]
def ammo_stowage_contains_part(part_id : PartId; v : tuple<
                                 ammo_stowage__partIdRemap : IPoint4List;
                                 ammo_stowage__dpAmmo : int3
                                 >) : bool
  return get_remap(v.ammo_stowage__partIdRemap, part_id).partId.valid || (v.ammo_stowage__dpAmmo.x <= int(part_id.globalId) && int(part_id.globalId) <= v.ammo_stowage__dpAmmo.y)


[with_bundle(v)]
def calc_slot_pos(slot_id : int;
                  v : tuple<
                    ammo_slots__node : AmmoStowageSlotCollAndGeomNodesList
                    >) : float3
  
  if v.ammo_slots__node[slot_id].nodeWtm == null || v.ammo_slots__node[slot_id].cnode == null
    return float3(0.0f)

  var tm : float3x4 = identity3x4()
  mat44f_to_TMatrix(*v.ammo_slots__node[slot_id].nodeWtm, tm)
  return tm * v.ammo_slots__node[slot_id].cnode.boundingSphere.c


[with_bundle(v)]
def ammo_stowage_calc_fill(v : tuple<
                             ammo_slots__numAmmo : IPoint2List
                             >) : float
  var total_ammo = int2(0)
  for num_ammo in v.ammo_slots__numAmmo
    total_ammo += num_ammo
  return safediv(float(total_ammo.x), float(total_ammo.y))







[with_bundle(v)]
def find_adjacent_slot_in_cluster(cluster_id : int; slot_id : int; adjacent_cluster_id : int;
                                  v : tuple<
                                    ammo_clusters__slotsRange : IPoint2List;
                                    ammo_slots__numAmmo : IPoint2List;
                                    ammo_slots__ammoMaskAndType : UInt32List
                                    >) : int
  let num_ammo = v.ammo_slots__numAmmo[slot_id]
  let ammo_type = get_ammo_slot_type(slot_id, v)
  let slots_range = v.ammo_clusters__slotsRange[adjacent_cluster_id]
  
  if true
    let rel_slot_id = slot_id - v.ammo_clusters__slotsRange[cluster_id].x + slots_range.x
    assert(rel_slot_id >= slots_range.x)
    if rel_slot_id < slots_range.y && get_ammo_slot_type(rel_slot_id, v) == ammo_type && v.ammo_slots__numAmmo[rel_slot_id].x == num_ammo.x
      return rel_slot_id
  
  for adjacent_slot_id in slots_range.x..slots_range.y
    if get_ammo_slot_type(adjacent_slot_id, v) == ammo_type && v.ammo_slots__numAmmo[adjacent_slot_id].x == num_ammo.x
      return adjacent_slot_id
  return -1





[with_bundle(v)]
def gather_adjacent_slots(stowage_id : int; cluster_id : int; slot_id : int;
                          v : tuple<
                            ammo_stowages__clustersRange : IPoint2List;
                            ammo_clusters__typeAndStage : UInt16List;
                            ammo_clusters__slotsRange : IPoint2List;
                            ammo_slots__numAmmo : IPoint2List;
                            ammo_slots__ammoMaskAndType : UInt32List
                            >) : int2[2]
  var ordered_adjacent_clusters : array<int2>
  if true
    let clusters_range = v.ammo_stowages__clustersRange[stowage_id]
    ordered_adjacent_clusters |> reserve(clusters_range.y - clusters_range.x)
    let cluster_stage = get_ammo_cluster_stage(cluster_id, v)
    let cluster_type = get_ammo_cluster_type(cluster_id, v)
    let cluster_size = v.ammo_clusters__slotsRange[cluster_id].y - v.ammo_clusters__slotsRange[cluster_id].x
    for adjacent_cluster_id in clusters_range.x..clusters_range.y
      if get_ammo_cluster_type(adjacent_cluster_id, v) == cluster_type
        continue
      var adjacent_cluster_prio = 0
      if get_ammo_cluster_stage(adjacent_cluster_id, v) == cluster_stage
        adjacent_cluster_prio++
        if v.ammo_clusters__slotsRange[adjacent_cluster_id].y - v.ammo_clusters__slotsRange[adjacent_cluster_id].x == cluster_size
          adjacent_cluster_prio++
      ordered_adjacent_clusters |> push(int2(adjacent_cluster_id, adjacent_cluster_prio))
    sort(ordered_adjacent_clusters) <| $(a, b)
      return a.y > b.y

  assert(int(AmmoClusterType.NUM_TYPES) == 2)
  var slot_by_type : int2[2]
  for cluster_slot_id in slot_by_type
    cluster_slot_id = int2(-1, -1)
  slot_by_type[get_ammo_cluster_type(cluster_id, v)] = int2(cluster_id, slot_id)
  for adjacent_cluster in ordered_adjacent_clusters
    let adjacent_cluster_id = adjacent_cluster.x
    let cluster_type = get_ammo_cluster_type(adjacent_cluster_id, v)
    if slot_by_type[cluster_type].x == -1
      let adjacent_slot_id = find_adjacent_slot_in_cluster(cluster_id, slot_id, adjacent_cluster_id, v)
      if adjacent_slot_id != -1
        slot_by_type[cluster_type] = int2(adjacent_cluster_id, adjacent_slot_id)
  return slot_by_type


[with_bundle(v)]
def public apply_ammo_slot_effect(var unit : Unit?; stowage_id : int; cluster_id : int; slot_id : int; effect : AmmoSlotEffectType;
                                  v : tuple<
                                    ammo_stowage__ammoState : uint;
                                    ammo_stowage__ammoTypeRemap : IPoint4List;
                                    ammo_stowage__weaponsIds : IntList;
                                    ammo_slots__state : UInt32List -const;
                                    ammo_slots__numAmmo : IPoint2List -const;
                                    ammo_slots__ammoMaskAndType : UInt32List;
                                    ammo_slots__partId : PartIdList;
                                    ammo_stowage__ammoLost : int -const;
                                    ammo_stowages__state : UInt32List -const;
                                    ammo_stowages__clustersRange : IPoint2List;
                                    ammo_clusters__typeAndStage : UInt16List;
                                    ammo_clusters__slotsRange : IPoint2List
                                    >) : void
  
  if effect == AmmoSlotEffectType.FLOODED_AND_DESTROYED
    apply_ammo_slot_effect(unit, stowage_id, cluster_id, slot_id, AmmoSlotEffectType.FLOODED) <| v
    apply_ammo_slot_effect(unit, stowage_id, cluster_id, slot_id, AmmoSlotEffectType.DESTROYED) <| v
    return
  if effect == AmmoSlotEffectType.DRIED_AND_RESTORED
    apply_ammo_slot_effect(unit, stowage_id, cluster_id, slot_id, AmmoSlotEffectType.RESTORED) <| v
    apply_ammo_slot_effect(unit, stowage_id, cluster_id, slot_id, AmmoSlotEffectType.DRIED) <| v
    return

  
  if effect == AmmoSlotEffectType.RESTORED && get_flag(v.ammo_slots__state[slot_id], AmmoSlotState.ENABLED)
    return
  if effect == AmmoSlotEffectType.DESTROYED && !get_flag(v.ammo_slots__state[slot_id], AmmoSlotState.ENABLED)
    return
  if effect == AmmoSlotEffectType.FLOODED && get_flag(v.ammo_slots__state[slot_id], AmmoSlotState.FLOODED)
    return
  if effect == AmmoSlotEffectType.DRIED && !get_flag(v.ammo_slots__state[slot_id], AmmoSlotState.FLOODED)
    return

  
  if effect == AmmoSlotEffectType.DESTROYED
    
    let slot_ammo_type = get_ammo_slot_type(slot_id, v)
    let slot_num_ammo = v.ammo_slots__numAmmo[slot_id].x
    if slot_num_ammo > 0
      ammo_stowage_subtract_weapon_ammo(unit.weap, slot_ammo_type, false, slot_num_ammo, v)
      v.ammo_stowage__ammoLost += slot_num_ammo
    
    var need_start_reload = slot_num_ammo > 0 && get_ammo_cluster_stage(cluster_id, v) == int(AmmoClusterStage.LOADED_IN_GUN)
    if need_start_reload
      let slot_range = v.ammo_clusters__slotsRange[cluster_id]
      for i in slot_range.x..slot_range.y
        if v.ammo_slots__numAmmo[i].x > 0 && i != slot_id
          need_start_reload = false
    if need_start_reload
      let ammo_type_remap = v.ammo_stowage__ammoTypeRemap[slot_ammo_type]
      send_net_event(unit.eid, CmdAmmoStowageForceReloadGun(stowageId = ammo_type_remap.x))

    set_flag(v.ammo_stowages__state[stowage_id], AmmoStowageState.NEED_SYNC_BULLET_COUNT, true)

    
    for adjacent_cluster_and_slot in gather_adjacent_slots(stowage_id, cluster_id, slot_id, v)
      let adjacent_slot_id = adjacent_cluster_and_slot.y
      if adjacent_slot_id != -1
        v.ammo_slots__numAmmo[adjacent_slot_id].x = 0
        ammo_slot_set_dm_enabled(unit, adjacent_slot_id, false, v) \

  
  if effect == AmmoSlotEffectType.FLOODED || effect == AmmoSlotEffectType.DRIED
    sendEvent(unit.eid, CmdAmmoStowageRecalcReloadingTime(stowageId = stowage_id))

  
  if effect == AmmoSlotEffectType.DESTROYED
    set_flag(v.ammo_slots__state[slot_id], AmmoSlotState.ENABLED, false)
    ammo_slot_set_dm_enabled(unit, slot_id, false, v)
  if effect == AmmoSlotEffectType.RESTORED
    set_flag(v.ammo_slots__state[slot_id], AmmoSlotState.ENABLED, true)
    ammo_slot_set_dm_enabled(unit, slot_id, true, v)
  if effect == AmmoSlotEffectType.FLOODED
    set_flag(v.ammo_slots__state[slot_id], AmmoSlotState.FLOODED, true)
  if effect == AmmoSlotEffectType.DRIED
    set_flag(v.ammo_slots__state[slot_id], AmmoSlotState.FLOODED, false)


[es, with_bundle(v)]
def ammo_stowage_apply_slot_effect_es(evt : EventAmmoStowageApplySlotEffect;
                                      var unit__ref : UnitRef;
                                      v : tuple<
                                        ammo_stowage__ammoState : uint;
                                        ammo_stowage__partIdRemap : IPoint4List;
                                        ammo_stowage__ammoLost : int -const;
                                        ammo_stowage__ammoTypeRemap : IPoint4List;
                                        ammo_stowage__weaponsIds : IntList;
                                        ammo_stowages__state : UInt32List -const;
                                        ammo_stowages__clustersRange : IPoint2List;
                                        ammo_clusters__typeAndStage : UInt16List;
                                        ammo_clusters__slotsRange : IPoint2List;
                                        ammo_slots__state : UInt32List -const;
                                        ammo_slots__numAmmo : IPoint2List -const;
                                        ammo_slots__partId : PartIdList;
                                        ammo_slots__ammoMaskAndType : UInt32List
                                        >)
  var unit = unit__ref.unit
  if !unit.isDelayed
    let remap = get_remap(v.ammo_stowage__partIdRemap, evt.partId)
    if remap.partId.valid
      apply_ammo_slot_effect(unit, remap.stowageId, remap.clusterId, remap.slotId, evt.effect) <| v







struct ExplosionParams
  shellMass : float
  powderMass : float
  strengthEquivalent : float
  brisanceEquivalent : float
  splashDamageTypeId : int
  shatterDamageTypeId : int

struct AffectedByDmEffect
  expl : bool
  fire : bool

[with_bundle(v)]
def is_ammo_slot_affected_by_dm_effect(unit : Unit?; stowage_id : int; cluster_id : int; slot_id : int;
                                       v : tuple<
                                         ammo_stowage__ammoState : uint;
                                         ammo_stowage__ammoTypeRemap : IPoint4List;
                                         ammo_stowage__weaponsIds : IntList;
                                         ammo_clusters__typeAndStage : UInt16List;
                                         ammo_slots__ammoMaskAndType : UInt32List;
                                         ammo_slots__numAmmo : IPoint2List
                                         >) : AffectedByDmEffect
  if stowage_id < 0 || cluster_id < 0 || slot_id < 0 || unit == null
    return AffectedByDmEffect(expl = true, fire = true)
  let wc = unit.weap
  let slot_ammo = v.ammo_slots__numAmmo[slot_id]
  var result = AffectedByDmEffect(expl = false, fire = false)
  if slot_ammo.x == 0
    return result
  let is_charges = get_ammo_cluster_type(cluster_id, v) == int(AmmoClusterType.CHARGES)
  ammo_stowage_iter_all_ammo_props(wc, get_ammo_slot_type(slot_id, v), v) <| $ [unused_argument(fract)] (props; fract : float)
    if !is_charges
      result.expl = props.explosiveProps.mass > 0.f || result.expl
    result.fire = (props.powderPortion > 0.f && props.ballisticsProps.mass > 0.f) || result.fire
  return result


[with_bundle(v)]
def calc_explosion_params(unit : Unit?; cluster_id : int; var seed : int;
                          v : tuple<
                            ammo_stowage__ammoState : uint;
                            ammo_stowage__nonFatalDetonatePortion : float2;
                            ammo_stowage__splashProperties : SplashProps;
                            ammo_stowage__ammoTypeRemap : IPoint4List;
                            ammo_stowage__weaponsIds : IntList;
                            ammo_clusters__slotsRange : IPoint2List;
                            ammo_slots__ammoMaskAndType : UInt32List;
                            ammo_slots__numAmmo : IPoint2List
                            >) : ExplosionParams
  var result = ExplosionParams(
    shellMass = 0.0f,
    powderMass = 0.0f,
    strengthEquivalent = 0.0f,
    brisanceEquivalent = 0.0f,
    splashDamageTypeId = -1,
    shatterDamageTypeId = -1
  )
  let detonate_portion = _frnd(seed) * (v.ammo_stowage__nonFatalDetonatePortion.y - v.ammo_stowage__nonFatalDetonatePortion.x) + v.ammo_stowage__nonFatalDetonatePortion.x
  let wc = unit.weap
  let slots_range = v.ammo_clusters__slotsRange[cluster_id]
  for slot_id in slots_range.x..slots_range.y
    let slot_ammo = v.ammo_slots__numAmmo[slot_id]
    if slot_ammo.x == 0
      continue
    ammo_stowage_iter_all_ammo_props(wc, get_ammo_slot_type(slot_id, v), v) <| $(props; fract : float)
      let bullet_count = float(slot_ammo.x) * fract
      let fullMass = props.ballisticsProps.mass
      let explosiveMass = props.explosiveProps.mass * bullet_count * detonate_portion
      let shellMass = props.kineticMass * bullet_count
      let powderMass = props.powderPortion * fullMass * bullet_count

      result.shellMass += shellMass
      result.powderMass += powderMass
      result.strengthEquivalent += explosiveMass * props.explosiveProps.strength
      result.brisanceEquivalent += explosiveMass * props.explosiveProps.brisance
      if result.splashDamageTypeId < 0
        result.splashDamageTypeId = props.splashDamageTypeId
      if result.shatterDamageTypeId < 0
        result.shatterDamageTypeId = props.shatterDamageTypeId
  if (result.splashDamageTypeId < 0 || result.shatterDamageTypeId < 0) && (result.strengthEquivalent > 0.f || result.brisanceEquivalent > 0.f)
    logerr("ammo stowage exploded with invalid splash/shatter damage type: {result}")
  elif result.splashDamageTypeId < 0
    
    result.splashDamageTypeId = get_splash_damage_type_id(v.ammo_stowage__splashProperties)
  return result






[with_bundle(v)]
def ammo_stowage_send_explosion_fatal(eid : EntityId; ammo_left : float; var seed : int; full_expl : bool;
                                      v : tuple<
                                        ammo_stowage__explosiveProperties : ExplosiveProps -const;
                                        ammo_stowage__fatalDetonatePortion : float2;
                                        ammo_stowage__splashProperties : SplashProps -const
                                        >) : void
  var splash_params = calc_splash_params(v.ammo_stowage__explosiveProperties, v.ammo_stowage__splashProperties, false)
  if splash_params.outerRadius <= 0.0f
    return
  splash_params |> splash_params_scale(ammo_left *
    (_frnd(seed) * (v.ammo_stowage__fatalDetonatePortion.y - v.ammo_stowage__fatalDetonatePortion.x) + v.ammo_stowage__fatalDetonatePortion.x)
  )
  let splash_damage_type_id = get_splash_damage_type_id(v.ammo_stowage__splashProperties)
  sendEvent(eid, EventDoAmmoExplode(
    isFatal = true,
    fullExpl = full_expl,
    localPos = float3(0.0f),
    packedPartId = PartId().packed,
    rndSeed = seed,
    splashRadius = float2(splash_params.innerRadius, splash_params.outerRadius),
    splashPenetration = splash_params.penetration,
    splashDamage = splash_params.damage,
    splashDamageTypeId = splash_damage_type_id,
    shatterRadius = 0.0f,
    shatterCount = 0.0f,
    shatterPenetration = 0.0f,
    shatterDamage = 0.0f,
    shatterDamageTypeId = 0
  ))


[with_bundle(v)]
def do_fire_delayed(var unit : Unit?; eid : EntityId; stowage_id : int; cluster_id : int;
                    v : tuple<
                      ammo_stowage__ammoState : uint;
                      ammo_stowage__delayedOffender : OffenderData;
                      ammo_stowage__ammoTypeRemap : IPoint4List;
                      ammo_stowage__weaponsIds : IntList;
                      ammo_stowage__nonFatalDetonatePortion : float2;
                      ammo_stowage__splashProperties : SplashProps;
                      ammo_stowages__powderMassToSplash : AmmoStowageMassToSplashList;
                      ammo_clusters__fireParamsId : IntList;
                      ammo_clusters__fireEvtId : IntList;
                      ammo_clusters__slotsRange : IPoint2List;
                      ammo_slots__state : UInt32List -const;
                      ammo_slots__partId : PartIdList;
                      ammo_slots__numAmmo : IPoint2List -const;
                      ammo_slots__ammoMaskAndType : UInt32List;
                      ammo_slots__node : AmmoStowageSlotCollAndGeomNodesList
                      >) : bool
  let explosion_params = calc_explosion_params(unit, cluster_id, grnd()) <| v
  if explosion_params.powderMass == 0.f
    return false

  let slots_range = v.ammo_clusters__slotsRange[cluster_id]
  var hit_slot_id = -1
  var cluster_center_pos = float3(0.0f)
  for slot_id in slots_range.x..slots_range.y
    if hit_slot_id == -1 && get_flag(v.ammo_slots__state[slot_id], AmmoSlotState.ON_FIRE)
      hit_slot_id = slot_id
    cluster_center_pos += calc_slot_pos(slot_id) <| v
  if hit_slot_id == -1
    return false

  assume dm = *unit.visual
  let part_id = v.ammo_slots__partId[hit_slot_id]
  assume powder_mass_to_splash = v.ammo_stowages__powderMassToSplash[stowage_id]
  sendEvent(eid, EventAmmoStowageDoDelayedFireEffects(
    packedPartId = part_id.packed,
    stowageId = stowage_id,
    clusterId = cluster_id,
    innerRadius = powder_mass_to_splash.innerRadius |> interpolate_tab_float_interpolate(explosion_params.powderMass),
    outerRadius = powder_mass_to_splash.outerRadius |> interpolate_tab_float_interpolate(explosion_params.powderMass),
    penetration = powder_mass_to_splash.penetration |> interpolate_tab_float_interpolate(explosion_params.powderMass),
    damage = powder_mass_to_splash.damage |> interpolate_tab_float_interpolate(explosion_params.powderMass),
    damageTypeId = explosion_params.splashDamageTypeId,
    pos = cluster_center_pos / float(slots_range.y - slots_range.x)
  ))
  sendEvent(eid, EventFireSystemStartBurnWithOffender(
    partId = part_id,
    fireParamsId = v.ammo_clusters__fireParamsId[cluster_id],
    fireFxId = v.ammo_clusters__fireEvtId[cluster_id],
    offender = v.ammo_stowage__delayedOffender
  ))
  return true


[with_bundle(v)]
def do_explosion_delayed(var unit : Unit?; eid : EntityId; stowage_id : int; cluster_id : int;
                         v : tuple<
                           ammo_stowage__ammoState : uint;
                           ammo_stowage__ammoTypeRemap : IPoint4List;
                           ammo_stowage__weaponsIds : IntList;
                           ammo_stowage__nonFatalDetonatePortion : float2;
                           ammo_stowage__splashProperties : SplashProps;
                           ammo_clusters__explosionEvtId : IntList;
                           ammo_clusters__slotsRange : IPoint2List;
                           ammo_slots__state : UInt32List -const;
                           ammo_slots__ammoMaskAndType : UInt32List;
                           ammo_slots__numAmmo : IPoint2List -const;
                           ammo_slots__partId : PartIdList;
                           ammo_slots__node : AmmoStowageSlotCollAndGeomNodesList
                           >) : bool
  let explosion_params = calc_explosion_params(unit, cluster_id, grnd()) <| v
  if explosion_params.strengthEquivalent == 0.0f && explosion_params.brisanceEquivalent == 0.0f
    return false

  let slots_range = v.ammo_clusters__slotsRange[cluster_id]
  var hit_slot_id = -1
  var cluster_center_pos = float3(0.0f)
  for slot_id in slots_range.x..slots_range.y
    if hit_slot_id == -1 && get_flag(v.ammo_slots__state[slot_id], AmmoSlotState.ON_EXPLODE)
      hit_slot_id = slot_id
    cluster_center_pos += calc_slot_pos(slot_id) <| v
  if hit_slot_id == -1
    return false
  let hit_slot_part_id = v.ammo_slots__partId[hit_slot_id]

  if unit.isAuthority
    var unit_fx = unit |> get_unit_fx()
    if unit_fx != null
      let geom_node_id = *unit.visual |> dm_get_geom_node_id_by_part_id(int(hit_slot_part_id.globalId))
      let coll_node = *unit.visual |> dm_get_collision_node_by_part_id(int(hit_slot_part_id.globalId))
      let zero = float3(0.0f)
      *unit_fx |> startFxEvent(v.ammo_clusters__explosionEvtId[cluster_id], geom_node_id, zero, coll_node.boundingSphere.c)
  sendEvent(eid, EventAmmoStowageDoDelayedExplosionEffects(
    packedPartId = hit_slot_part_id.packed,
    stowageId = stowage_id,
    clusterId = cluster_id,
    pos = cluster_center_pos / float(slots_range.y - slots_range.x),
    strengthEquivalent = explosion_params.strengthEquivalent,
    brisanceEquivalent = explosion_params.brisanceEquivalent,
    shellMass = explosion_params.shellMass,
    splashDamageTypeId = explosion_params.splashDamageTypeId,
    shatterDamageTypeId = explosion_params.shatterDamageTypeId
  ))
  return true


[with_bundle(v)]
def ammo_stowage_disable_affected_slots(var unit : Unit?; stowage_id : int; cluster_id : int;
                                        v : tuple<
                                          ammo_stowage__ammoState : uint;
                                          ammo_stowage__ammoLost : int -const;
                                          ammo_stowage__ammoTypeRemap : IPoint4List;
                                          ammo_stowage__weaponsIds : IntList;
                                          ammo_stowages__state : UInt32List -const;
                                          ammo_stowages__clustersRange : IPoint2List;
                                          ammo_clusters__typeAndStage : UInt16List;
                                          ammo_clusters__slotsRange : IPoint2List;
                                          ammo_slots__state : UInt32List -const;
                                          ammo_slots__ammoMaskAndType : UInt32List;
                                          ammo_slots__numAmmo : IPoint2List -const;
                                          ammo_slots__partId : PartIdList
                                          >) : void
  let slots_range = v.ammo_clusters__slotsRange[cluster_id]
  for slot_id in slots_range.x..slots_range.y
    if get_flag(v.ammo_slots__state[slot_id], AmmoSlotState.ON_FIRE) || get_flag(v.ammo_slots__state[slot_id], AmmoSlotState.ON_EXPLODE)
      apply_ammo_slot_effect(unit, stowage_id, cluster_id, slot_id, AmmoSlotEffectType.DESTROYED) <| v
      set_flag(v.ammo_slots__state[slot_id], AmmoSlotState.ON_EXPLODE, false)
      set_flag(v.ammo_slots__state[slot_id], AmmoSlotState.ON_FIRE, false)


[es, with_bundle(v)]
def ammo_stowage_delayed_effects_es(evt : ParallelUpdateFrameDelayed;
                                    var unit__ref : UnitRef;
                                    eid : EntityId;
                                    v : tuple<
                                      ammo_stowage__ammoState : uint -const;
                                      ammo_stowage__timeAmmoFire : float -const;
                                      ammo_stowage__combustionTime : float;
                                      ammo_stowage__explosiveProperties : ExplosiveProps -const;
                                      ammo_stowage__detonateProb : float;
                                      ammo_stowage__fatalDetonatePortion : float2;
                                      ammo_stowage__nonFatalDetonatePortion : float2;
                                      ammo_stowage__ammoLost : int -const;
                                      ammo_stowage__delayedOffender : OffenderData -const;
                                      ammo_stowage__ammoTypeRemap : IPoint4List;
                                      ammo_stowage__weaponsIds : IntList;
                                      ammo_stowages__state : UInt32List -const;
                                      ammo_stowages__clustersRange : IPoint2List;
                                      ammo_stowages__powderMassToSplash : AmmoStowageMassToSplashList;
                                      ammo_clusters__fireParamsId : IntList;
                                      ammo_clusters__fireEvtId : IntList;
                                      ammo_clusters__explosionEvtId : IntList;
                                      ammo_clusters__typeAndStage : UInt16List;
                                      ammo_clusters__state : UInt32List -const;
                                      ammo_clusters__slotsRange : IPoint2List;
                                      ammo_slots__state : UInt32List -const;
                                      ammo_slots__partId : PartIdList;
                                      ammo_slots__ammoMaskAndType : UInt32List;
                                      ammo_slots__numAmmo : IPoint2List -const;
                                      ammo_slots__node : AmmoStowageSlotCollAndGeomNodesList;
                                      ammo_stowage__splashProperties : SplashProps -const
                                      >)
  if get_flag(v.ammo_stowage__ammoState, AmmoState.ON_FIRE) || get_flag(v.ammo_stowage__ammoState, AmmoState.ON_EXPLODE)
    set_flag(v.ammo_stowage__ammoState, AmmoState.ON_FIRE, false)
    set_flag(v.ammo_stowage__ammoState, AmmoState.ON_EXPLODE, false)

    var unit = unit__ref.unit
    if unit.isDelayed
      return

    for stowage_id, clusters_range in iter_range(v.ammo_stowages__clustersRange), v.ammo_stowages__clustersRange
      for cluster_id in clusters_range.x..clusters_range.y
        var any_affected = false
        if get_flag(v.ammo_clusters__state[cluster_id], AmmoClusterState.ON_FIRE)
          any_affected = do_fire_delayed(unit, eid, stowage_id, cluster_id, v) || any_affected
        if get_flag(v.ammo_clusters__state[cluster_id], AmmoClusterState.ON_EXPLODE)
          any_affected = do_explosion_delayed(unit, eid, stowage_id, cluster_id, v) || any_affected
        set_flag(v.ammo_clusters__state[cluster_id], AmmoClusterState.ON_FIRE, false)
        set_flag(v.ammo_clusters__state[cluster_id], AmmoClusterState.ON_EXPLODE, false)
        if any_affected
          ammo_stowage_disable_affected_slots(unit, stowage_id, cluster_id, v)
          sendEvent(eid, EventAmmoStowageInvalidateRenderer())
    v.ammo_stowage__delayedOffender |> clear_offender_data()

  if v.ammo_stowage__timeAmmoFire > 0.0f
    let unit = unit__ref.unit
    if !unit.isAlive && !unit.isDelayed
      v.ammo_stowage__timeAmmoFire -= evt.dt
      if v.ammo_stowage__timeAmmoFire > 0.0f
        let ammo_left = safediv(v.ammo_stowage__timeAmmoFire, v.ammo_stowage__combustionTime)
        if ammo_left > 0.0f && gfrnd() < v.ammo_stowage__detonateProb * evt.dt
          v.ammo_stowage__timeAmmoFire = -1.0f
          sendEvent(eid, EventAmmoStowageOnEndAmmoFire(doKillEffect = false ))
          ammo_stowage_send_explosion_fatal(eid, ammo_left, grnd(), false) <| v
      else
        sendEvent(eid, EventAmmoStowageOnEndAmmoFire(doKillEffect = true))

  
  
  
  if get_flag(v.ammo_stowage__ammoState, AmmoState.FATAL_FIRE) || get_flag(v.ammo_stowage__ammoState, AmmoState.FATAL_EXPLOSION)
    var unit = unit__ref.unit
    if unit.isAlive && !unit.isDelayed
      set_flag(v.ammo_stowage__ammoState, AmmoState.FATAL_FIRE, false)
      set_flag(v.ammo_stowage__ammoState, AmmoState.FATAL_EXPLOSION, false)







[with_bundle(v)]
def ammo_stowage_do_fire_fatal(eid : EntityId; stowage_id : int; cluster_id : int; part_id : PartId; offender : OffenderData;
                               v : tuple<
                                 ammo_stowage__ammoState : uint -const;
                                 ammo_slots__numAmmo : IPoint2List
                                 >) : void
  if get_flag(v.ammo_stowage__ammoState, AmmoState.FATAL_FIRE)
    return
  set_flag(v.ammo_stowage__ammoState, AmmoState.FATAL_FIRE, true)
  let ammo_left = ammo_stowage_calc_fill(v)
  sendEvent(eid, EventAmmoStowageDoFatalFire(
    stowageId = stowage_id,
    clusterId = cluster_id,
    partId = part_id,
    offender = offender,
    ammoLeft = ammo_left
  ))


[with_bundle(v)]
def ammo_stowage_do_explosion_fatal(eid : EntityId; stowage_id : int; cluster_id : int; part_id : PartId;
                                    offender : OffenderData; seed : int; full_expl : bool;
                                    v : tuple<
                                      ammo_stowage__ammoState : uint -const;
                                      ammo_stowage__explosiveProperties : ExplosiveProps -const;
                                      ammo_stowage__fatalDetonatePortion : float2;
                                      ammo_slots__numAmmo : IPoint2List;
                                      ammo_stowage__splashProperties : SplashProps -const
                                      >) : void
  if get_flag(v.ammo_stowage__ammoState, AmmoState.FATAL_EXPLOSION)
    return
  set_flag(v.ammo_stowage__ammoState, AmmoState.FATAL_EXPLOSION, true)

  let ammo_left = ammo_stowage_calc_fill(v)
  sendEvent(eid, EventAmmoStowageDoFatalExplosion(
    stowageId = stowage_id,
    clusterId = cluster_id,
    partId = part_id,
    offender = offender,
    ammoLeft = ammo_left,
    seed = seed,
    fullExpl = full_expl
  ))
  ammo_stowage_send_explosion_fatal(eid, ammo_left, seed, full_expl) <| v

[es, with_bundle(v)]
def ammo_stowage_send_explosion_fatal_es(evt : EventAmmoStowageSendExplosionFatal;
                                         eid : EntityId;
                                         v : tuple<
                                           ammo_stowage__explosiveProperties : ExplosiveProps -const;
                                           ammo_stowage__fatalDetonatePortion : float2;
                                           ammo_stowage__splashProperties : SplashProps -const
                                           >)
  ammo_stowage_send_explosion_fatal(eid, evt.ammoLeft, evt.seed, evt.fullExpl) <| v







[with_bundle(v)]
def ammo_stowage_do_fire(unit : Unit?; eid : EntityId; remap : PartRemap; offender : OffenderData;
                         v : tuple<
                           ammo_stowage__ammoTypeRemap : IPoint4List;
                           ammo_stowage__weaponsIds : IntList;
                           ammo_stowage__ammoState : uint -const;
                           ammo_stowage__delayedOffender : OffenderData -const;
                           ammo_clusters__state : UInt32List -const;
                           ammo_clusters__typeAndStage : UInt16List;
                           ammo_clusters__slotsRange : IPoint2List;
                           ammo_slots__state : UInt32List -const;
                           ammo_slots__ammoMaskAndType : UInt32List;
                           ammo_slots__numAmmo : IPoint2List
                           >) : void
  if !remap.partId.valid
    
    ammo_stowage_do_fire_fatal(eid, -1, -1, remap.partId, offender) <| v
    return

  
  if get_flag(v.ammo_slots__state[remap.slotId], AmmoSlotState.FLOODED)
    return

  if get_flag(v.ammo_clusters__state[remap.clusterId], AmmoClusterState.FIRE_FATAL)
    ammo_stowage_do_fire_fatal(eid, remap.stowageId, remap.clusterId, remap.partId, offender) <| v
    return

  
  if get_flag(v.ammo_stowage__ammoState, AmmoState.FATAL_FIRE)
    return

  
  set_flag(v.ammo_stowage__ammoState, AmmoState.ON_FIRE, true)
  set_flag(v.ammo_clusters__state[remap.clusterId], AmmoClusterState.ON_FIRE, true)
  v.ammo_stowage__delayedOffender = offender

  
  let slots_range = v.ammo_clusters__slotsRange[remap.clusterId]
  for slot_id in slots_range.x..slots_range.y
    if is_ammo_slot_affected_by_dm_effect(unit, remap.stowageId, remap.clusterId, slot_id, v).fire
      set_flag(v.ammo_slots__state[slot_id], AmmoSlotState.ON_FIRE, true)

  sendEventImmediate(eid, EventAmmoStowageDoImmediateFireEffects(
    packedPartId = remap.partId.packed,
    stowageId = remap.stowageId,
    clusterId = remap.clusterId))


[with_bundle(v)]
def ammo_stowage_do_explosion(unit : Unit?; eid : EntityId; remap : PartRemap; offender : OffenderData; seed : int; dm_effects : int;
                              v : tuple<
                                ammo_stowage__ammoState : uint -const;
                                ammo_stowage__delayedOffender : OffenderData -const;
                                ammo_stowage__explosiveProperties : ExplosiveProps -const;
                                ammo_stowage__fatalDetonatePortion : float2;
                                ammo_stowage__ammoTypeRemap : IPoint4List;
                                ammo_stowage__weaponsIds : IntList;
                                ammo_clusters__typeAndStage : UInt16List;
                                ammo_clusters__state : UInt32List -const;
                                ammo_clusters__slotsRange : IPoint2List;
                                ammo_slots__state : UInt32List -const;
                                ammo_slots__ammoMaskAndType : UInt32List;
                                ammo_slots__numAmmo : IPoint2List;
                                ammo_stowage__splashProperties : SplashProps -const
                                >) : void
  let is_full_expl = get_dm_effect_flag(dm_effects, DamageEffectType.DM_EFFECT_FULL_EXPL)
  if !remap.partId.valid
    
    ammo_stowage_do_explosion_fatal(eid, -1, -1, remap.partId, offender, seed, is_full_expl) <| v
    return

  
  if get_ammo_cluster_type(remap.clusterId, v) == int(AmmoClusterType.CHARGES)
    ammo_stowage_do_fire(unit, eid, remap, offender) <| v
    return

  if get_flag(v.ammo_clusters__state[remap.clusterId], AmmoClusterState.EXPLOSION_FATAL)
    ammo_stowage_do_explosion_fatal(eid, remap.stowageId, remap.clusterId, remap.partId, offender, seed, is_full_expl) <| v
    return

  
  if get_flag(v.ammo_stowage__ammoState, AmmoState.FATAL_EXPLOSION)
    return

  
  set_flag(v.ammo_stowage__ammoState, AmmoState.ON_EXPLODE, true)
  set_flag(v.ammo_clusters__state[remap.clusterId], AmmoClusterState.ON_EXPLODE, true)
  v.ammo_stowage__delayedOffender = offender

  
  let slots_range = v.ammo_clusters__slotsRange[remap.clusterId]
  for slot_id in slots_range.x..slots_range.y
    if is_ammo_slot_affected_by_dm_effect(unit, remap.stowageId, remap.clusterId, slot_id, v).expl
      set_flag(v.ammo_slots__state[slot_id], AmmoSlotState.ON_EXPLODE, true)

  sendEventImmediate(eid, EventAmmoStowageDoImmediateExplosionEffects(
    packedPartId = remap.partId.packed,
    stowageId = remap.stowageId,
    clusterId = remap.clusterId
  ))


[es, with_bundle(v)]
def ammo_stowage_part_damage_handler_es(evt : CmdApplyPartDamageEffect;
                                        eid : EntityId; var unit__ref : UnitRef;
                                        v : tuple<
                                          ammo_stowage__ammoState : uint -const;
                                          ammo_stowage__ammoTypeRemap : IPoint4List;
                                          ammo_stowage__weaponsIds : IntList;
                                          ammo_stowage__dpAmmo : int3;
                                          ammo_stowage__delayedOffender : OffenderData -const;
                                          ammo_stowage__explosiveProperties : ExplosiveProps -const;
                                          ammo_stowage__fatalDetonatePortion : float2;
                                          ammo_stowage__partIdRemap : IPoint4List;
                                          ammo_clusters__typeAndStage : UInt16List;
                                          ammo_clusters__state : UInt32List -const;
                                          ammo_clusters__slotsRange : IPoint2List;
                                          ammo_slots__state : UInt32List -const;
                                          ammo_slots__ammoMaskAndType : UInt32List;
                                          ammo_slots__numAmmo : IPoint2List;
                                          ammo_stowage__splashProperties : SplashProps -const
                                          >)
  var unit = unit__ref.unit
  if unit.isDelayed || !unit.isAlive || unit.visual == null
    return

  let partId = evt.partId
  if !ammo_stowage_contains_part(partId) <| v
    return

  let should_be_hp = rel_hp_fixed_to_float(evt.hpFixed)
  let remap = get_remap(v.ammo_stowage__partIdRemap, partId)
  let affected_by = is_ammo_slot_affected_by_dm_effect(unit, remap.stowageId, remap.clusterId, remap.slotId, v)
  if get_dm_effect_flag(evt.dmEffects, DamageEffectType.DM_EFFECT_EXPL) || get_dm_effect_flag(evt.dmEffects, DamageEffectType.DM_EFFECT_FULL_EXPL)
    if affected_by.expl
      ammo_stowage_do_explosion(unit, eid, remap, evt.offender, evt.seed, evt.dmEffects) <| v
    elif affected_by.fire
      ammo_stowage_do_fire(unit, eid, remap, evt.offender) <| v
  if get_dm_effect_flag(evt.dmEffects, DamageEffectType.DM_EFFECT_FIRE)
    if affected_by.fire
      ammo_stowage_do_fire(unit, eid, remap, evt.offender) <| v

  
  if should_be_hp <= 0.0f && remap.partId.valid && !get_flag(v.ammo_slots__state[remap.slotId], AmmoSlotState.ON_FIRE) && !get_flag(v.ammo_slots__state[remap.slotId], AmmoSlotState.ON_EXPLODE)
    sendEventImmediate(eid, EventAmmoStowageApplySlotEffect(
      partId = partId,
      effect = AmmoSlotEffectType.DESTROYED
    ))


[es, with_bundle(v)]
def ammo_stowage_on_damage_es(evt : EventUnitDamage;
                              eid : EntityId; var unit__ref : UnitRef;
                              v : tuple<
                                ammo_stowage__ammoTypeRemap : IPoint4List;
                                ammo_stowage__weaponsIds : IntList;
                                ammo_stowage__ammoState : uint -const;
                                ammo_stowage__delayedOffender : OffenderData -const;
                                ammo_stowage__explosiveProperties : ExplosiveProps -const;
                                ammo_stowage__fatalDetonatePortion : float2;
                                ammo_stowage__partIdRemap : IPoint4List;
                                ammo_clusters__typeAndStage : UInt16List;
                                ammo_clusters__state : UInt32List -const;
                                ammo_clusters__damageEffectPresetId : IntList;
                                ammo_clusters__slotsRange : IPoint2List;
                                ammo_slots__state : UInt32List -const;
                                ammo_slots__ammoMaskAndType : UInt32List;
                                ammo_slots__numAmmo : IPoint2List;
                                ammo_stowage__splashProperties : SplashProps -const
                                >)
  var unit = unit__ref.unit
  if unit.isDelayed || !unit.isAlive || (unit.isTank && !is_equal_float(unit.dmgScaleFromBot, 1.))
    return

  let remap = get_remap(v.ammo_stowage__partIdRemap, evt.partId)
  if !remap.partId.valid
    return

  let damage_effect_preset_id = v.ammo_clusters__damageEffectPresetId[remap.clusterId]
  if damage_effect_preset_id < 0
    return

  assume dm = *unit.visual
  let on_kill = int(evt.prevHpFixed) > 0 && evt.damage / get_part_hp_prop_value(unit.dmData, remap.partId) >= rel_hp_fixed_to_float(evt.prevHpFixed)
  if damage_effect_preset_id > length(dm.damageEffects.presets)
    logerr("invalid damage effect preset id {damage_effect_preset_id}")
    return

  let action = get_damage_effect_action_cluster(dm.damageEffects.presets[damage_effect_preset_id], on_kill, evt.damageTypeId, evt.damage)
  if action == null
    return

  var seed = evt.seed
  var dm_effects = 0
  var is_critical = false
  if on_kill
    dm_effect_on_part_kill(*action, dm_effects, seed, is_critical)
  else
    dm_effect_on_part_hit(*action, *get_dm_params(), dm_effects, seed, evt.effectProb, evt.effectProbFire, evt.prevHpFixed, is_critical)

  let affected_by = is_ammo_slot_affected_by_dm_effect(unit, remap.stowageId, remap.clusterId, remap.slotId, v)
  if get_dm_effect_flag(dm_effects, DamageEffectType.DM_EFFECT_EXPL) || get_dm_effect_flag(dm_effects, DamageEffectType.DM_EFFECT_FULL_EXPL)
    if affected_by.expl
      ammo_stowage_do_explosion(unit, eid, remap, evt.offender, seed, dm_effects) <| v
    elif affected_by.fire
      ammo_stowage_do_fire(unit, eid, remap, evt.offender) <| v
  if get_dm_effect_flag(dm_effects, DamageEffectType.DM_EFFECT_FIRE)
    if affected_by.fire
      ammo_stowage_do_fire(unit, eid, remap, evt.offender) <| v
