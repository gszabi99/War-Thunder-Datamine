require ecs
require net
require app
require dm
require math
require DagorRandom
require DagorMath
require Unit
require UnitFx
require AmmoStowage
require Weapon
require WTDamageModel
require IGroundModel
require %game.component_bundle_macro
require %dasGameLibs.math.base
require %game.events
require %game.unit_events
require %game.ammo_stowage_common
require %game.ammo_stowage_events
require %game.fire_system_events


def get_dm_effect_flag(flags, flag)
  return get_flag(uint(flags), 1u << uint(flag))


[es, with_bundle(v)]
def ammo_stowage_init_es(evt : CmdInitComponent;
                         uid : int;
                         var v : tuple<
                           ammo_stowage__dpAmmo : int3;
                           ammo_stowage__dpTorpedo : int3;
                           ammo_stowage__dpDepthCharge : int3;

                           ammo_stowage__ammoLost : int;
                           ammo_stowage__combustionTime : float;
                           ammo_stowage__detonateProb : float;
                           ammo_stowage__detonatePortion : float2;
                           ammo_stowage__detonateMinCaliber : float;
                           ammo_stowage__damagePropsId : int;
                           ammo_stowage__fxEvAmmoFireId : int;
                           ammo_stowage__partIdRemap : IPoint4List;
                           ammo_stowage__triggerIdRemap : IntList;

                           ammo_stowages__state : UInt32List;
                           ammo_stowages__numAmmo : IPoint3List;
                           ammo_stowages__numAmmoFirstStage : IPoint3List;
                           ammo_stowages__replenishmentStartEnd : Point2List;
                           ammo_stowages__replenishmentTime : Point2List;
                           ammo_stowages__powderMassToSplash : AmmoStowageMassToSplashList;
                           ammo_stowages__clustersRange : IPoint2List;
                           ammo_stowages__weaponTriggersRange : IPoint2List;
                           ammo_stowage__weaponTriggers : IntList;

                           ammo_clusters__type : IntList;
                           ammo_clusters__state : UInt32List;
                           ammo_clusters__fireEvtId : IntList;
                           ammo_clusters__fireParamsId : IntList;
                           ammo_clusters__explosionEvtId : IntList;
                           ammo_clusters__damageEffectPresetId : IntList;
                           ammo_clusters__reloadTimeMult : FloatList;
                           ammo_clusters__splashConstraints : Point3List;
                           ammo_clusters__shatterConstraints : Point3List;
                           ammo_clusters__exterminatedAmmo : IntList;
                           ammo_clusters__entityMunition : StringList;
                           ammo_clusters__slotsRange : IPoint2List;
                           ammo_clusters__wreckageRange : IPoint2List;
                           ammo_clusters__elevatorPartsRange : IPoint2List;
                           ammo_stowage__wreckageIds : IntList;
                           ammo_stowage__elevatorPartsIds : PartIdList;

                           ammo_slots__state : UInt32List;
                           ammo_slots__partId : PartIdList;
                           ammo_slots__numAmmo : IPoint2List;
                           ammo_slots__node : AmmoStowageSlotCollAndGeomNodesList
                         >)
  let unit = get_unit(uid)
  assert(unit != null)
  if !unit.isGroundModel || v.ammo_stowages__state |> length() > 0
    return

  v.ammo_stowage__dpAmmo = dm_find_part_kind("ammo")
  v.ammo_stowage__dpTorpedo = dm_find_part_kind("torpedo")
  v.ammo_stowage__dpDepthCharge = dm_find_part_kind("depth_charge")

  load_ammo_stowage(*evt.modelBlk, "{unit.props.fileName}", !get_app().isInHangar, uid) <| v


[es, with_bundle(v)]
def ammo_stowage_respawn_handle(evt : EventUnitRespawn; eid : EntityId;
                                var v : tuple<
                                  ammo_slots__state : UInt32List
                                >) : void
  for state in v.ammo_slots__state
    set_flag(state, AmmoSlotState ENABLED, true)
  sendEvent(eid, [[EventBulletsAmountChanged]])


[es, with_bundle(v)]
def ammo_stowage_respair_handle(evt : EventUnitRepair; eid : EntityId;
                                var v : tuple<
                                  ammo_slots__state : UInt32List
                                >) : void
  for state in v.ammo_slots__state
    set_flag(state, AmmoSlotState ENABLED, true)
  sendEvent(eid, [[EventBulletsAmountChanged]])


[es, with_bundle(v)]
def ammo_stowage_bullets_amount_changed_es(evt : EventBulletsAmountChanged; active : bool; eid : EntityId; uid : int;
                                           v : tuple<
                                             ammo_stowage__ammoLost : int-const;
                                             ammo_stowages__state : UInt32List- const;
                                             ammo_stowages__replenishmentStartEnd : Point2List;
                                             ammo_stowages__numAmmo : IPoint3List- const;
                                             ammo_stowages__numAmmoFirstStage : IPoint3List- const;
                                             ammo_stowages__clustersRange : IPoint2List;
                                             ammo_stowages__weaponTriggersRange : IPoint2List;
                                             ammo_stowage__weaponTriggers : IntList;
                                             ammo_clusters__type : IntList;
                                             ammo_clusters__state : UInt32List- const;
                                             ammo_clusters__slotsRange : IPoint2List;
                                             ammo_slots__state : UInt32List- const;
                                             ammo_slots__partId : PartIdList;
                                             ammo_slots__numAmmo : IPoint2List- const
                                           >)
  if !active
    return
  var unit = get_unit(uid)
  if unit != null && !unit.isDelayed
    let sync_required = setup_ammo_stowage(unit, !get_app().isInHangar, false) <| v
    if sync_required
      ammo_stowage_send_net_sync(eid) <| v


[es, with_bundle(v)]
def ammo_stowage_setup_stowage_es(evt : EventAmmoStowageSetup; active : bool; eid : EntityId; uid : int;
                                  v : tuple<
                                    ammo_stowage__ammoLost : int-const;
                                    ammo_stowages__state : UInt32List- const;
                                    ammo_stowages__replenishmentStartEnd : Point2List;
                                    ammo_stowages__numAmmo : IPoint3List- const;
                                    ammo_stowages__numAmmoFirstStage : IPoint3List- const;
                                    ammo_stowages__clustersRange : IPoint2List;
                                    ammo_stowages__weaponTriggersRange : IPoint2List;
                                    ammo_stowage__weaponTriggers : IntList;
                                    ammo_clusters__type : IntList;
                                    ammo_clusters__state : UInt32List- const;
                                    ammo_clusters__slotsRange : IPoint2List;
                                    ammo_slots__state : UInt32List- const;
                                    ammo_slots__partId : PartIdList;
                                    ammo_slots__numAmmo : IPoint2List- const
                                  >)
  if !active
    return
  var unit = get_unit(uid)
  if unit != null && !unit.isDelayed
    let sync_required = setup_ammo_stowage(unit, true, false) <| v
    if sync_required
      ammo_stowage_send_net_sync(eid) <| v


[es, with_bundle(v)]
def ammo_stowage_replenishment_updater_es(info : ParallelUpdateFrameDelayed;
                                          active : bool;
                                          eid : EntityId;
                                          uid : int;
                                          v : tuple<
                                            ammo_stowages__state : UInt32List;
                                            ammo_stowages__replenishmentStartEnd : Point2List- const;
                                            ammo_stowages__replenishmentTime : Point2List- const;
                                            ammo_stowages__weaponTriggersRange : IPoint2List;
                                            ammo_stowages__numAmmo : IPoint3List- const;
                                            ammo_stowages__numAmmoFirstStage : IPoint3List- const;
                                            ammo_stowage__weaponTriggers : IntList
                                          >)
  var unit = get_unit(uid)
  if unit == null || unit.isDelayed || !active
    return

  let current_time = float(get_app().usefulTotalTime)
  let weapon_controller = unit.weap
  for state, replenishment_start_end, replenishment_time, num_ammo, num_ammo_first_stage, triggers_range in v.ammo_stowages__state, v.ammo_stowages__replenishmentStartEnd, v.ammo_stowages__replenishmentTime, v.ammo_stowages__numAmmo, v.ammo_stowages__numAmmoFirstStage, v.ammo_stowages__weaponTriggersRange
    if replenishment_time.x < VERY_SMALL_NUMBER || num_ammo_first_stage.z <= 0
      continue

    if (num_ammo_first_stage.x >= num_ammo_first_stage.z ||
        num_ammo_first_stage.x >= num_ammo.x ||
        unit.isBurn)
      replenishment_start_end = float2(-1.0f)
      continue

    if (!get_flag(state, AmmoStowageState HAS_AUTO_LOAD) ||
        num_ammo_first_stage.x > (get_flag(state, AmmoStowageState REMOVE_LOADED_AMMO) ? -1 : 0))
      var end_stowage_update = false
      for i in triggers_range.x..triggers_range.y
        if weapon_controller.Weapons |> is_weapon_reloading(v.ammo_stowage__weaponTriggers[i], current_time)
          replenishment_start_end.x = -1.0f
          replenishment_start_end.y = -1.0f
          end_stowage_update = true
          break
      if end_stowage_update
        continue

    var can_reload = false
    for i in triggers_range.x..triggers_range.y
      if unit |> is_loading_crewman_available(v.ammo_stowage__weaponTriggers[i])
        can_reload = true
        break
    if !can_reload
      replenishment_start_end.x = -1.0f
      replenishment_start_end.y = -1.0f
      continue

    if replenishment_start_end.x < 0.0f
      replenishment_start_end.x = current_time + /* delay */ replenishment_time.y
      continue

    if replenishment_start_end.x >= current_time && replenishment_start_end.y < 0.0f
      replenishment_start_end.y = replenishment_start_end.x + /* time */ replenishment_time.y * unit.loaderPenalty

    if current_time > replenishment_start_end.y
      num_ammo_first_stage.x++
      if num_ammo_first_stage.x < num_ammo_first_stage.y && num_ammo_first_stage.x < num_ammo.x
        replenishment_start_end.x = replenishment_start_end.y
        replenishment_start_end.y += /* time */ replenishment_time.y * unit.loaderPenalty
      sendEvent(eid, [[EventAmmoStowageSetup]])


[with_bundle(v)]
def ammo_stowage_send_explosion_fatal(eid : EntityId; ammo_left : float; var seed : int; full_expl : bool;
                                      v : tuple<
                                        ammo_stowage__damagePropsId : int;
                                        ammo_stowage__detonatePortion : float2
                                      >) : void
  if v.ammo_stowage__damagePropsId < 0
    return
  var splash_params = calc_splash_params(v.ammo_stowage__damagePropsId, false)
  if splash_params.outerRadius <= 0.0f
    return
  splash_params |> splash_params_scale(ammo_left *
    (_frnd(seed) * (v.ammo_stowage__detonatePortion.y - v.ammo_stowage__detonatePortion.x) + v.ammo_stowage__detonatePortion.x)
  )
  let splash_damage_type_id = get_splash_damage_type_prop_value(v.ammo_stowage__damagePropsId, -1)
  sendEvent(eid, [[EventDoAmmoExplode
    isFatal=true,
    fullExpl=full_expl,
    localPos=float3(0.0f),
    packedPartId=PartId().packed,
    rndSeed=seed,
    splashRadius=float2(splash_params.innerRadius, splash_params.outerRadius),
    splashPenetration=splash_params.penetration,
    splashDamage=splash_params.damage,
    splashDamageTypeId=splash_damage_type_id,
    shatterRadius=0.0f,
    shatterCount=0.0f,
    shatterPenetration=0.0f,
    shatterDamage=0.0f,
    shatterDamageTypeId=0
  ]])


struct ExplosionParams
  shellMass : float
  powderMass : float
  strengthEquivalent : float
  brisanceEquivalent : float
  splashDamageTypeId : int
  shatterDamageTypeId : int


def add_to_explosion_params(var params : ExplosionParams&;
                            ballistics_props : BallisticsProjectileProps&;
                            dmg_props_id : int;
                            bullet_count : int)
  let explosive_props = get_explosive_props(dmg_props_id)
  let explosive_mass = explosive_props != null ? explosive_props.mass * float(bullet_count) : 0.0f
  let shell_mass = get_mass_prop_value(dmg_props_id, 0.0f) * float(bullet_count)
  let powder_props = get_powder_props(dmg_props_id)
  let powder_mass = powder_props != null ? powder_props.portion * ballistics_props.mass * float(bullet_count) : 0.0f

  params.shellMass += shell_mass
  params.powderMass += powder_mass
  params.strengthEquivalent += explosive_mass * (explosive_props != null ? explosive_props.strength : 1.f);
  params.brisanceEquivalent += explosive_mass * (explosive_props != null ? explosive_props.brisance : 1.f);
  if params.splashDamageTypeId < 0
    params.splashDamageTypeId = get_splash_damage_type_prop_value(dmg_props_id, -1)
  if params.shatterDamageTypeId < 0
    params.shatterDamageTypeId = get_shatter_damage_type_prop_value(dmg_props_id, -1)


[with_bundle(v)]
def calc_explosion_params(unit : Unit?; stowage_id : int; cluster_id : int;
                          v : tuple<
                            ammo_stowages__weaponTriggersRange : IPoint2List;
                            ammo_stowage__weaponTriggers : IntList;
                            ammo_clusters__exterminatedAmmo : IntList
                          >) : ExplosionParams
  var result = [[ExplosionParams
    shellMass=0.0f,
    powderMass=0.0f,
    strengthEquivalent=0.0f,
    brisanceEquivalent=0.0f,
    splashDamageTypeId=-1,
    shatterDamageTypeId=-1
  ]]
  var num_ammo = 0

  let wc = unit.weap
  let weapon_triggers_range = v.ammo_stowages__weaponTriggersRange[stowage_id]
  for i in weapon_triggers_range.x..weapon_triggers_range.y
    let trigger_id = v.ammo_stowage__weaponTriggers[i]
    for weapon in wc.Weapons |> get_weapons_by_trigger(trigger_id)
      let gun = weapon |> as_gun()
      let base_gun = weapon |> as_base_gun()
      if gun != null
        for bullet_set in gun.properties.bulletSets
          for ptr, dmg_props_id in bullet_set.bullet, bullet_set.damagePropsIds
            num_ammo += bullet_set.bulletsCount
            add_to_explosion_params(result, ptr.props.ballisticProps, dmg_props_id, bullet_set.bulletsCount)
      elif base_gun != null
        num_ammo += base_gun.countBullets
        add_to_explosion_params(result, base_gun.prop.shellProps.ballisticProps, base_gun.damagePropsId, base_gun.countBullets)

  if num_ammo > 0
    let k = float(v.ammo_clusters__exterminatedAmmo[cluster_id]) / float(num_ammo);
    result.powderMass *= k;
    result.strengthEquivalent *= k;
    result.brisanceEquivalent *= k;
    result.shellMass *= k;

  return result


[with_bundle(v)]
def do_fire_delayed(var unit : Unit?; eid : EntityId; stowage_id : int; cluster_id : int;
                    v : tuple<
                      ammo_stowage__ammoLost : int-const;
                      ammo_stowage__delayedOffender : OffenderData;
                      ammo_stowages__state : UInt32List- const;
                      ammo_stowages__numAmmo : IPoint3List- const;
                      ammo_stowages__numAmmoFirstStage : IPoint3List- const;
                      ammo_stowages__clustersRange : IPoint2List;
                      ammo_stowages__powderMassToSplash : AmmoStowageMassToSplashList;
                      ammo_stowages__weaponTriggersRange : IPoint2List;
                      ammo_clusters__fireParamsId : IntList;
                      ammo_clusters__fireEvtId : IntList;
                      ammo_stowage__weaponTriggers : IntList;
                      ammo_clusters__type : IntList;
                      ammo_clusters__state : UInt32List- const;
                      ammo_clusters__slotsRange : IPoint2List;
                      ammo_clusters__exterminatedAmmo : IntList;
                      ammo_slots__state : UInt32List- const;
                      ammo_slots__partId : PartIdList;
                      ammo_slots__numAmmo : IPoint2List- const;
                      ammo_slots__node : AmmoStowageSlotCollAndGeomNodesList
                    >) : void
  let explosion_params = calc_explosion_params(unit, stowage_id, cluster_id) <| v

  let slots_range = v.ammo_clusters__slotsRange[cluster_id]
  var hit_slot_id = -1
  for slot_id in slots_range.x..slots_range.y
    set_slot_enabled(unit, stowage_id, slot_id, AmmoSlotEnabledState DISABLED_SIMPLE) <| v
    if hit_slot_id == -1 && get_flag(v.ammo_slots__state[slot_id], AmmoSlotState ON_FIRE)
      hit_slot_id = slot_id
    set_flag(v.ammo_slots__state[slot_id], AmmoSlotState ON_FIRE, false)
  setup_ammo_stowage(unit, true, false) <| v
  if hit_slot_id == -1
    return

  assume dm = *unit.visual
  let part_id = v.ammo_slots__partId[hit_slot_id]

  assume powder_mass_to_splash = v.ammo_stowages__powderMassToSplash[stowage_id]
  sendEvent(eid, [[EventAmmoStowageDoDelayedFireEffects
    packedPartId=part_id.packed,
    stowageId = stowage_id,
    clusterId = cluster_id,
    innerRadius = powder_mass_to_splash.innerRadius |> interpolate_tab_float_interpolate(explosion_params.powderMass),
    outerRadius = powder_mass_to_splash.outerRadius |> interpolate_tab_float_interpolate(explosion_params.powderMass),
    penetration = powder_mass_to_splash.penetration |> interpolate_tab_float_interpolate(explosion_params.powderMass),
    damage = powder_mass_to_splash.damage |> interpolate_tab_float_interpolate(explosion_params.powderMass),
    damageTypeId = explosion_params.splashDamageTypeId,
    pos = calc_slot_pos(hit_slot_id) <| v
  ]])

  sendEvent(eid, [[EventFireSystemStartBurnWithOffender
    partId=part_id,
    fireParamsId = v.ammo_clusters__fireParamsId[cluster_id],
    fireFxId = v.ammo_clusters__fireEvtId[cluster_id],
    offender = v.ammo_stowage__delayedOffender
  ]])


[with_bundle(v)]
def do_explosion_delayed(var unit : Unit?; eid : EntityId; stowage_id : int; cluster_id : int;
                         v : tuple<
                           ammo_stowage__ammoLost : int-const;
                           ammo_stowages__state : UInt32List- const;
                           ammo_stowages__numAmmo : IPoint3List- const;
                           ammo_stowages__numAmmoFirstStage : IPoint3List- const;
                           ammo_stowages__clustersRange : IPoint2List;
                           ammo_stowages__weaponTriggersRange : IPoint2List;
                           ammo_stowage__weaponTriggers : IntList;
                           ammo_clusters__type : IntList;
                           ammo_clusters__state : UInt32List- const;
                           ammo_clusters__exterminatedAmmo : IntList;
                           ammo_clusters__explosionEvtId : IntList;
                           ammo_clusters__slotsRange : IPoint2List;
                           ammo_slots__state : UInt32List- const;
                           ammo_slots__numAmmo : IPoint2List- const;
                           ammo_slots__partId : PartIdList;
                           ammo_slots__node : AmmoStowageSlotCollAndGeomNodesList
                         >) : void
  let explosion_params = calc_explosion_params(unit, stowage_id, cluster_id) <| v
  if explosion_params.strengthEquivalent == 0.0f && explosion_params.brisanceEquivalent == 0.0f
    return

  let slots_range = v.ammo_clusters__slotsRange[cluster_id]
  var hit_slot_id = -1
  for slot_id in slots_range.x..slots_range.y
    set_slot_enabled(unit, stowage_id, slot_id, AmmoSlotEnabledState DISABLED_SIMPLE) <| v
    if hit_slot_id == -1 && get_flag(v.ammo_slots__state[slot_id], AmmoSlotState ON_EXPLODE)
      hit_slot_id = slot_id
    set_flag(v.ammo_slots__state[slot_id], AmmoSlotState ON_EXPLODE, false)
  setup_ammo_stowage(unit, true, false) <| v
  if hit_slot_id == -1
    return
  let hit_slot_part_id = v.ammo_slots__partId[hit_slot_id]

  if unit.isAuthority
    var unit_fx = unit |> get_unit_fx()
    if unit_fx != null
      let geom_node_id = *unit.visual |> dm_get_geom_node_id_by_part_id(int(hit_slot_part_id.globalId))
      let coll_node = *unit.visual |> dm_get_collision_node_by_part_id(int(hit_slot_part_id.globalId))
      let zero = float3(0.0f)
      *unit_fx |> startFxEvent(v.ammo_clusters__explosionEvtId[cluster_id], geom_node_id, zero, coll_node.boundingSphere.c);

  sendEvent(eid, [[EventAmmoStowageDoDelayedExplosionEffects
    packedPartId=hit_slot_part_id.packed,
    stowageId=stowage_id,
    clusterId=cluster_id,
    pos=calc_slot_pos(hit_slot_id) <| v,
    strengthEquivalent=explosion_params.strengthEquivalent,
    brisanceEquivalent=explosion_params.brisanceEquivalent,
    shellMass=explosion_params.shellMass,
    splashDamageTypeId=explosion_params.splashDamageTypeId,
    shatterDamageTypeId=explosion_params.shatterDamageTypeId
  ]])


[es, with_bundle(v)]
def ammo_stowage_delayed_effects_es(evt : ParallelUpdateFrameDelayed;
                                    uid : int;
                                    eid : EntityId;
                                    v : tuple<
                                      ammo_stowage__ammoState : uint- const;
                                      ammo_stowage__timeAmmoFire : float-const;
                                      ammo_stowage__combustionTime : float;
                                      ammo_stowage__damagePropsId : int;
                                      ammo_stowage__detonateProb : float;
                                      ammo_stowage__detonatePortion : float2;
                                      ammo_stowage__ammoLost : int-const;
                                      ammo_stowage__delayedOffender : OffenderData- const;
                                      ammo_stowages__state : UInt32List- const;
                                      ammo_stowages__numAmmo : IPoint3List- const;
                                      ammo_stowages__numAmmoFirstStage : IPoint3List- const;
                                      ammo_stowages__clustersRange : IPoint2List;
                                      ammo_clusters__fireParamsId : IntList;
                                      ammo_clusters__fireEvtId : IntList;
                                      ammo_clusters__explosionEvtId : IntList;
                                      ammo_stowages__weaponTriggersRange : IPoint2List;
                                      ammo_stowages__powderMassToSplash : AmmoStowageMassToSplashList;
                                      ammo_stowage__weaponTriggers : IntList;
                                      ammo_clusters__type : IntList;
                                      ammo_clusters__state : UInt32List- const;
                                      ammo_clusters__exterminatedAmmo : IntList;
                                      ammo_clusters__slotsRange : IPoint2List;
                                      ammo_slots__state : UInt32List- const;
                                      ammo_slots__partId : PartIdList;
                                      ammo_slots__numAmmo : IPoint2List- const;
                                      ammo_slots__node : AmmoStowageSlotCollAndGeomNodesList
                                    >)
  if get_flag(v.ammo_stowage__ammoState, AmmoState ON_FIRE) || get_flag(v.ammo_stowage__ammoState, AmmoState ON_EXPLODE)
    set_flag(v.ammo_stowage__ammoState, AmmoState ON_FIRE, false)
    set_flag(v.ammo_stowage__ammoState, AmmoState ON_EXPLODE, false)

    var unit = get_unit(uid)
    if unit == null || unit.isDelayed
      return

    for stowage_id, clusters_range in iter_range(v.ammo_stowages__clustersRange), v.ammo_stowages__clustersRange
      for cluster_id in clusters_range.x..clusters_range.y
        if get_flag(v.ammo_clusters__state[cluster_id], AmmoClusterState ON_FIRE)
          do_fire_delayed(unit, eid, stowage_id, cluster_id) <| v
        if get_flag(v.ammo_clusters__state[cluster_id], AmmoClusterState ON_EXPLODE)
          do_explosion_delayed(unit, eid, stowage_id, cluster_id) <| v
        set_flag(v.ammo_clusters__state[cluster_id], AmmoClusterState ON_FIRE, false)
        set_flag(v.ammo_clusters__state[cluster_id], AmmoClusterState ON_EXPLODE, false)
    v.ammo_stowage__delayedOffender |> clear_offender_data()

  if v.ammo_stowage__timeAmmoFire > 0.0f
    var unit = get_unit(uid)
    if unit != null && !unit.isAlive && !unit.isDelayed
      v.ammo_stowage__timeAmmoFire -= evt.dt
      if v.ammo_stowage__timeAmmoFire > 0.0f
        let ammo_left = safediv(v.ammo_stowage__timeAmmoFire, v.ammo_stowage__combustionTime)
        if ammo_left > 0.0f && gfrnd() < v.ammo_stowage__detonateProb * evt.dt
          v.ammo_stowage__timeAmmoFire = -1.0f
          sendEvent(eid, [[EventAmmoStowageOnEndAmmoFire doKillEffect=true]])
          ammo_stowage_send_explosion_fatal(eid, ammo_left, grnd(), false) <| v
        else
          sendEvent(eid, [[EventAmmoStowageOnEndAmmoFire doKillEffect=true]])

  // this flags are used to send fatal fire/explosion events once, even if there are several clusters exploded at once,
  // so reseting them every tick is valid
  set_flag(v.ammo_stowage__ammoState, AmmoState FATAL_FIRE, false)
  set_flag(v.ammo_stowage__ammoState, AmmoState FATAL_EXPLOSION, false)


[with_bundle(v)]
def ammo_stowage_do_fire_fatal(eid : EntityId; stowage_id : int; cluster_id : int; part_id : PartId; offender : OffenderData;
                               v : tuple<
                                 ammo_stowage__ammoState : uint- const;
                                 ammo_slots__numAmmo : IPoint2List
                               >) : void
  if get_flag(v.ammo_stowage__ammoState, AmmoState FATAL_FIRE)
    return
  set_flag(v.ammo_stowage__ammoState, AmmoState FATAL_FIRE, true)
  let ammo_left = ammo_stowage_calc_fill(v)
  sendEvent(eid, [[EventAmmoStowageDoFatalFire
    stowageId=stowage_id,
    clusterId=cluster_id,
    partId=part_id,
    offender=offender,
    ammoLeft=ammo_left
  ]])


[with_bundle(v)]
def ammo_stowage_do_explosion_fatal(eid : EntityId; stowage_id : int; cluster_id : int; part_id : PartId;
                                    offender : OffenderData; seed : int; full_expl : bool;
                                    v : tuple<
                                      ammo_stowage__ammoState : uint- const;
                                      ammo_stowage__damagePropsId : int;
                                      ammo_stowage__detonatePortion : float2;
                                      ammo_slots__numAmmo : IPoint2List
                                    >) : void
  if get_flag(v.ammo_stowage__ammoState, AmmoState FATAL_EXPLOSION)
    return
  set_flag(v.ammo_stowage__ammoState, AmmoState FATAL_EXPLOSION, true)

  let ammo_left = ammo_stowage_calc_fill(v)
  sendEvent(eid, [[EventAmmoStowageDoFatalExplosion
    stowageId=stowage_id,
    clusterId=cluster_id,
    partId=part_id,
    offender=offender,
    ammoLeft=ammo_left,
    seed=seed,
    fullExpl=full_expl
  ]])
  ammo_stowage_send_explosion_fatal(eid, ammo_left, seed, full_expl) <| v


[with_bundle(v)]
def ammo_stowage_do_fire(eid : EntityId; part_id : PartId; offender : OffenderData;
                         v : tuple<
                           ammo_stowage__ammoState : uint- const;
                           ammo_stowage__delayedOffender : OffenderData- const;
                           ammo_stowage__partIdRemap : IPoint4List;
                           ammo_clusters__state : UInt32List- const;
                           ammo_clusters__exterminatedAmmo : IntList- const;
                           ammo_clusters__slotsRange : IPoint2List;
                           ammo_slots__state : UInt32List- const;
                           ammo_slots__numAmmo : IPoint2List
                         >) : void
  let remap = get_remap(v.ammo_stowage__partIdRemap, part_id)
  if !remap.partId.valid
    // Why are we doing fatal fire, if no clusters are hit?
    ammo_stowage_do_fire_fatal(eid, -1, -1, part_id, offender) <| v
    return

  if get_flag(v.ammo_clusters__state[remap.clusterId], AmmoClusterState ON_FIRE)
    return

  if get_flag(v.ammo_clusters__state[remap.clusterId], AmmoClusterState FIRE_FATAL)
    ammo_stowage_do_fire_fatal(eid, remap.stowageId, remap.clusterId, part_id, offender) <| v
    return

  set_flag(v.ammo_stowage__ammoState, AmmoState ON_FIRE, true)
  set_flag(v.ammo_clusters__state[remap.clusterId], AmmoClusterState ON_FIRE, true)
  set_flag(v.ammo_slots__state[remap.slotId], AmmoSlotState ON_FIRE, true)
  v.ammo_stowage__delayedOffender = offender

  var exterminated_ammo_count = 0
  let slots_range = v.ammo_clusters__slotsRange[remap.clusterId]
  for slot_id in slots_range.x..slots_range.y
    exterminated_ammo_count += v.ammo_slots__numAmmo[slot_id].x
  v.ammo_clusters__exterminatedAmmo[remap.clusterId] = exterminated_ammo_count


[with_bundle(v), unused_argument(eid, seed, dm_effects)]
def ammo_stowage_do_explosion(eid : EntityId; part_id : PartId; offender : OffenderData; seed : int; dm_effects : int;
                              v : tuple<
                                ammo_stowage__ammoState : uint- const;
                                ammo_stowage__delayedOffender : OffenderData- const;
                                ammo_stowage__damagePropsId : int;
                                ammo_stowage__detonatePortion : float2;
                                ammo_stowage__partIdRemap : IPoint4List;
                                ammo_clusters__type : IntList;
                                ammo_clusters__state : UInt32List- const;
                                ammo_clusters__exterminatedAmmo : IntList- const;
                                ammo_clusters__slotsRange : IPoint2List;
                                ammo_slots__state : UInt32List- const;
                                ammo_slots__numAmmo : IPoint2List
                              >) : void
  let is_full_expl = get_dm_effect_flag(dm_effects, DamageEffectType DM_EFFECT_FULL_EXPL)
  let remap = get_remap(v.ammo_stowage__partIdRemap, part_id)
  if !remap.partId.valid
    // Why are we doing fatal explosion, if no clusters are hit?
    ammo_stowage_do_explosion_fatal(eid, -1, -1, part_id, offender, seed, is_full_expl) <| v
    return

  if get_flag(v.ammo_clusters__state[remap.clusterId], AmmoClusterState ON_EXPLODE) || v.ammo_clusters__type[remap.clusterId] == int(AmmoClusterType CHARGES)
    return

  if get_flag(v.ammo_clusters__state[remap.clusterId], AmmoClusterState EXPLOSION_FATAL)
    ammo_stowage_do_explosion_fatal(eid, remap.stowageId, remap.clusterId, part_id, offender, seed, is_full_expl) <| v
    return

  set_flag(v.ammo_stowage__ammoState, AmmoState ON_EXPLODE, true)
  set_flag(v.ammo_clusters__state[remap.clusterId], AmmoClusterState ON_EXPLODE, true)
  set_flag(v.ammo_slots__state[remap.slotId], AmmoSlotState ON_EXPLODE, true)
  v.ammo_stowage__delayedOffender = offender

  var exterminated_ammo_count = 0
  let slots_range = v.ammo_clusters__slotsRange[remap.clusterId]
  for slot_id in slots_range.x..slots_range.y
    exterminated_ammo_count += v.ammo_slots__numAmmo[slot_id].x
  v.ammo_clusters__exterminatedAmmo[remap.clusterId] = exterminated_ammo_count


[es, with_bundle(v)]
def ammo_stowage_part_damage_handler_es(evt : CmdApplyPartDamageEffect;
                                        eid : EntityId; uid : int; active : bool;
                                        v : tuple<
                                          ammo_stowage__ammoState : uint- const;
                                          ammo_stowage__ammoLost : int-const;
                                          ammo_stowage__dpAmmo : int3;
                                          ammo_stowage__delayedOffender : OffenderData- const;
                                          ammo_stowage__damagePropsId : int;
                                          ammo_stowage__detonatePortion : float2;
                                          ammo_stowage__partIdRemap : IPoint4List;
                                          ammo_stowages__state : UInt32List- const;
                                          ammo_stowages__numAmmo : IPoint3List- const;
                                          ammo_stowages__numAmmoFirstStage : IPoint3List- const;
                                          ammo_stowages__clustersRange : IPoint2List;
                                          ammo_stowages__weaponTriggersRange : IPoint2List;
                                          ammo_stowage__weaponTriggers : IntList;
                                          ammo_clusters__type : IntList;
                                          ammo_clusters__state : UInt32List- const;
                                          ammo_clusters__exterminatedAmmo : IntList- const;
                                          ammo_clusters__slotsRange : IPoint2List;
                                          ammo_slots__state : UInt32List- const;
                                          ammo_slots__partId : PartIdList;
                                          ammo_slots__numAmmo : IPoint2List- const
                                        >)
  var unit = get_unit(uid)
  if !active || unit == null || unit.isDelayed || !unit.isAlive || unit.visual == null
    return

  let partId = evt.partId
  if !ammo_stowage_contains_part(partId) <| v
    return

  let should_be_hp = rel_hp_fixed_to_float(evt.hpFixed)
  if get_dm_effect_flag(evt.dmEffects, DamageEffectType DM_EFFECT_EXPL)
    ammo_stowage_do_explosion(eid, partId, evt.offender, evt.seed, evt.dmEffects) <| v
  elif get_dm_effect_flag(evt.dmEffects, DamageEffectType DM_EFFECT_FIRE)
    ammo_stowage_do_fire(eid, partId, evt.offender) <| v
  elif should_be_hp <= 0.0f
    set_slot_enabled_by_part_id(unit, partId, AmmoSlotEnabledState DISABLED_SIMPLE) <| v
    setup_ammo_stowage(unit, true, false) <| v


[es, with_bundle(v)]
def ammo_stowage_on_damage_es(evt : EventUnitDamage;
                              eid : EntityId; uid : int; active : bool;
                              v : tuple<
                                ammo_stowage__ammoState : uint- const;
                                ammo_stowage__delayedOffender : OffenderData- const;
                                ammo_stowage__damagePropsId : int;
                                ammo_stowage__detonatePortion : float2;
                                ammo_stowage__partIdRemap : IPoint4List;
                                ammo_clusters__type : IntList;
                                ammo_clusters__state : UInt32List- const;
                                ammo_clusters__exterminatedAmmo : IntList- const;
                                ammo_clusters__damageEffectPresetId : IntList;
                                ammo_clusters__slotsRange : IPoint2List;
                                ammo_slots__state : UInt32List- const;
                                ammo_slots__numAmmo : IPoint2List
                              >)
  let unit = get_unit(uid)
  if !active || unit == null || unit.isDelayed || !unit.isAlive
    return

  let remap = get_remap(v.ammo_stowage__partIdRemap, evt.partId)
  if !remap.partId.valid
    return

  let damage_effect_preset_id = v.ammo_clusters__damageEffectPresetId[remap.clusterId]
  if damage_effect_preset_id < 0
    return

  assume dm = *unit.visual
  let part_props_id = dm_get_part_props_id(dm, remap.partId)
  let on_kill = int(evt.prevHpFixed) > 0 && evt.damage / get_part_hp_prop_value(part_props_id, 0.0f) >= rel_hp_fixed_to_float(evt.prevHpFixed)
  assert(damage_effect_preset_id < length(dm.damageEffects.presets))
  let action = dm.damageEffects.presets[damage_effect_preset_id] |> get_damage_effect_action_cluster(on_kill, evt.damageTypeId, evt.damage)
  if action == null
    return

  var seed = evt.seed
  var dm_effects = 0
  var is_critical = false
  if on_kill
    dm_effect_on_part_kill(*action, dm_effects, seed, is_critical) <| $(part_id, can_cut)
      let allowed_dm_effects = (can_cut ? uint(DamageEffectsMask DM_EFFECTS_MASK_ALL) :
                                          uint(DamageEffectsMask DM_EFFECTS_MASK_ALL) & ~uint(DamageEffectsMask DM_EFFECTS_MASK_CUT))
      sendEvent(eid, [[EventUnitDoPartDamageOffender
        partId=evt.partId,
        offender=evt.offender,
        damage=get_part_hp_prop_value(dm_get_part_props_id(dm, part_id), 0.0f),
        damageTypeId=evt.damageTypeId,
        chanceMult=1.0f,
        chanceMultFire=1.0f,
        chanceMultExplFuel=1.0f,
        pos=float3(0.0f),
        dir=float3(0.0f, 1.0f, 0.0f),
        damageEvent=null,
        allowedDmEffects=int(allowed_dm_effects)
      ]])
  else
    dm_effect_on_part_hit(
      *action, get_dm_params().dmParams, dm_effects, seed, evt.effectProb, evt.prevHpFixed, is_critical,
      $ [unused_argument(part_id)] (effect_type, part_id) {
        return effect_type == int(DamageEffectType DM_EFFECT_FIRE) ? evt.effectProbFire : 1.0f;
      }
    ) <| $(part_id, can_cut)
      let allowed_dm_effects = (can_cut ? uint(DamageEffectsMask DM_EFFECTS_MASK_ALL) :
                                          uint(DamageEffectsMask DM_EFFECTS_MASK_ALL) & ~uint(DamageEffectsMask DM_EFFECTS_MASK_CUT))
      sendEvent(eid, [[EventUnitDoPartDamageOffender
        partId=evt.partId,
        offender=evt.offender,
        damage=get_part_hp_prop_value(dm_get_part_props_id(dm, part_id), 0.0f),
        damageTypeId=evt.damageTypeId,
        chanceMult=1.0f,
        chanceMultFire=1.0f,
        chanceMultExplFuel=1.0f,
        pos=float3(0.0f),
        dir=float3(0.0f, 1.0f, 0.0f),
        damageEvent=null,
        allowedDmEffects=int(allowed_dm_effects)
      ]])

  if get_dm_effect_flag(dm_effects, DamageEffectType DM_EFFECT_EXPL)
    ammo_stowage_do_explosion(eid, remap.partId, evt.offender, seed, dm_effects) <| v
    return
  if get_dm_effect_flag(dm_effects, DamageEffectType DM_EFFECT_FIRE)
    ammo_stowage_do_fire(eid, remap.partId, evt.offender) <| v
    return


[es(on_event=EventOnStopBurn)]
def ammo_stowage_on_stop_burn_es(evt : Event;
                                 uid : int; active : bool;
                                 var unit_fx : UnitFx;
                                 var ammo_clusters__state : UInt32List&;
                                 ammo_clusters__fireEvtId : IntList)

  let unit = get_unit(uid)
  if !active || unit == null || unit.isDelayed || !unit.isAuthority
    return

  for state, fire_event_id in ammo_clusters__state, ammo_clusters__fireEvtId
    if !get_flag(state, AmmoClusterState FIRE_FATAL)
      unit_fx |> stopFxEvent(fire_event_id)


[es, with_bundle(v)]
def ammo_stowage_set_slot_enabled_by_part_es(evt : EventAmmoStowageSetSlotEnabled;
                                             uid : int;
                                             v : tuple<
                                               ammo_stowage__partIdRemap : IPoint4List;
                                               ammo_stowage__weaponTriggers : IntList;
                                               ammo_stowage__ammoLost : int-const;
                                               ammo_stowages__state : UInt32List- const;
                                               ammo_stowages__numAmmo : IPoint3List- const;
                                               ammo_stowages__numAmmoFirstStage : IPoint3List- const;
                                               ammo_stowages__clustersRange : IPoint2List;
                                               ammo_stowages__weaponTriggersRange : IPoint2List;
                                               ammo_clusters__type : IntList;
                                               ammo_clusters__state : UInt32List- const;
                                               ammo_clusters__slotsRange : IPoint2List;
                                               ammo_slots__state : UInt32List- const;
                                               ammo_slots__numAmmo : IPoint2List- const;
                                               ammo_slots__partId : PartIdList
                                             >)
  var unit = get_unit(uid)
  if unit != null && !unit.isDelayed
    for state in each_enum(AmmoSlotEnabledState ENABLED)
      if int(state) == evt.state
        set_slot_enabled_by_part_id(unit, evt.partId, state) <| v
        setup_ammo_stowage(unit, true, false) <| v
        break


[es]
def ammo_stowage_cancel_replenishment_es(evt : EventAmmoStowageCancelReplenishment;
                                         var ammo_stowages__replenishmentStartEnd : Point2List&)
  for start_end in ammo_stowages__replenishmentStartEnd
    start_end.x = -1.0f
    start_end.y = -1.0f


[es, with_bundle(v)]
def ammo_stowage_send_explosion_fatal_es(evt : EventAmmoStowageSendExplosionFatal;
                                         eid : EntityId;
                                         v : tuple<
                                           ammo_stowage__damagePropsId : int;
                                           ammo_stowage__detonatePortion : float2
                                         >)
  ammo_stowage_send_explosion_fatal(eid, evt.ammoLeft, evt.seed, evt.fullExpl) <| v


[with_bundle(v)]
def ammo_stowage_send_net_sync(eid : EntityId; v : tuple<
                                 ammo_stowages__replenishmentStartEnd : Point2List;
                                 ammo_stowages__numAmmo : IPoint3List;
                                 ammo_stowages__numAmmoFirstStage : IPoint3List
                               >) : void
  if !is_server()
    return
  let current_time = float(get_app().usefulTotalTime)

  using() <| $(var data : IntList)
    data |> reserve(4)
    for replenishment_start_end, num_ammo, num_ammo_first_stage in v.ammo_stowages__replenishmentStartEnd, v.ammo_stowages__numAmmo, v.ammo_stowages__numAmmoFirstStage
      let packed_remaining_time = replenishment_start_end.x > 0.0f ? int((replenishment_start_end.y - current_time) * 1000.0f) : -1
      data |> push(num_ammo.x)
      data |> push(num_ammo_first_stage.x)
      data |> push(packed_remaining_time)
    send_net_event(eid, [[EventAmmoStowageNetSync data=ecs_addr(data)]])


[es(tag=netClient), with_bundle(v)]
def ammo_stowage_net_sync_es(evt : EventAmmoStowageNetSync;
                             eid : EntityId;
                             var v : tuple<
                               ammo_stowages__replenishmentStartEnd : Point2List;
                               ammo_stowages__numAmmo : IPoint3List;
                               ammo_stowages__numAmmoFirstStage : IPoint3List
                             >) : void
  let current_time = float(get_app().usefulTotalTime)
  let updates_stowage_count = min(length(v.ammo_stowages__numAmmo), length(*evt.data) / 3)
  assume data = *evt.data;
  for stowage_id in 0..updates_stowage_count
    v.ammo_stowages__numAmmo[stowage_id].x = data[stowage_id * 3 + 0]
    v.ammo_stowages__numAmmoFirstStage[stowage_id].x = data[stowage_id * 3 + 1]
    let packed_remaining_time = data[stowage_id * 3 + 2]
    if packed_remaining_time > 0
      v.ammo_stowages__replenishmentStartEnd[stowage_id].y = current_time + float(packed_remaining_time) / 1000.0f
      if v.ammo_stowages__replenishmentStartEnd[stowage_id].x < 0.0f
        v.ammo_stowages__replenishmentStartEnd[stowage_id].x = current_time
    else
      v.ammo_stowages__replenishmentStartEnd[stowage_id] = float2(-1.0f)
  sendEvent(eid, [[EventBulletsAmountChanged]])
