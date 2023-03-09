module ammo_stowage_common private
require ecs
require dm
require app
require Unit
require UnitFx
require Weapon
require WTDamageModel
require DagorMath
require DagorDataBlock
require GeomNodeTree
require AmmoStowage
require DagorSystem
require %game.component_bundle_macro
require %game.ammo_stowage_events
require daslib/lpipe


def public get_flag(var state : uint; flag)
  return (state & uint(flag)) == uint(flag)

def public set_flag(var state : uint&; flag; present : bool)
  if present
    state |= uint(flag)
  else
    state &= ~uint(flag)

def read_flag(blk : DataBlock&; var state : uint&; flag; key : string; default_val : bool)
  set_flag(state, flag, blk |> datablock_getBool(key, default_val))

def read_flag(blk : DataBlock&; var state : uint&; flag; key : string)
  read_flag(blk, state, flag, key, get_flag(state, flag))


struct public PartRemap
  partId : PartId
  stowageId : int
  clusterId : int
  slotId : int

def public get_remap(remap : IPoint4List&; partId : PartId) : PartRemap
  let idx = int(partId.id)
  if idx < length(remap) && idx >= 0
    let r = remap[idx]
    if r.x >= 0
      return [[PartRemap partId=partId, stowageId=r.y, clusterId=r.z, slotId=r.w]]
  return [[PartRemap partId=PartId(), stowageId=-1, clusterId=-1, slotId=-1]]

def public add_remap(var remap : IPoint4List&; part : PartRemap) : bool
  assert(part.partId.valid)
  let idx = int(part.partId.id)
  if length(remap) <= idx
    let old_size = length(remap)
    remap |> resize(idx + 16)
    for i in range(old_size, length(remap))
      remap[i] = int4(-1)
  elif remap[idx].x != -1
    return false
  remap[idx] = int4(int(part.partId.id), part.stowageId, part.clusterId, part.slotId)
  return true


[with_bundle(v)]
def public ammo_stowage_contains_part(part_id : PartId; v : tuple<
                                        ammo_stowage__partIdRemap : IPoint4List;
                                        ammo_stowage__dpAmmo : int3
                                      >) : bool
  return get_remap(v.ammo_stowage__partIdRemap, part_id).partId.valid || (v.ammo_stowage__dpAmmo.x <= int(part_id.globalId) && int(part_id.globalId) <= v.ammo_stowage__dpAmmo.y)


[with_bundle(v)]
def push_stowage(var v : tuple<
                   ammo_stowages__state : UInt32List;
                   ammo_stowages__numAmmo : IPoint3List;
                   ammo_stowages__numAmmoFirstStage : IPoint3List;
                   ammo_stowages__replenishmentStartEnd : Point2List;
                   ammo_stowages__replenishmentTime : Point2List;
                   ammo_stowages__powderMassToSplash : AmmoStowageMassToSplashList;
                   ammo_stowages__clustersRange : IPoint2List;
                   ammo_stowages__weaponTriggersRange : IPoint2List;
                   ammo_stowage__weaponTriggers : IntList
                 >) : int
  let stowage_id = v.ammo_stowages__state |> length()
  v.ammo_stowages__state |> push(uint(AmmoStowageState REMOVE_LOADED_AMMO))
  v.ammo_stowages__numAmmo |> push(int3(0, 0, 0))
  v.ammo_stowages__numAmmoFirstStage |> push(int3(0, 0, 0))
  v.ammo_stowages__replenishmentStartEnd |> push(float2(-1.0f, -1.0f))
  v.ammo_stowages__replenishmentTime |> push(float2(0.0f, -1.0f))
  v.ammo_stowages__powderMassToSplash |> push_empty()
  v.ammo_stowages__clustersRange |> push(int2(0, 0))
  v.ammo_stowages__weaponTriggersRange |> push(int2(v.ammo_stowage__weaponTriggers |> length()))
  return stowage_id


struct DefaultAmmoCluster
  ammo_clusters__state : uint
  ammo_clusters__explosionEvtId : int
  ammo_clusters__fireEvtId : int
  ammo_clusters__fireParamsId : int
  ammo_clusters__damageEffectPresetId : int
  ammo_clusters__reloadTimeMult : float
  ammo_clusters__splashConstraints : float3
  ammo_clusters__shatterConstraints : float3
  ammo_stowage__wreckageIds : array<int>
  ammo_stowage__elevatorPartsIds : array<uint>


def make_default_cluster() : DefaultAmmoCluster
  return <- [[DefaultAmmoCluster
    ammo_clusters__state = (
      uint(AmmoClusterState EMPTY) |
      uint(AmmoClusterState REVERSE_FILL) |
      uint(AmmoClusterState FIRE_FATAL) |
      uint(AmmoClusterState EXPLOSION_FATAL)
    ),
    ammo_clusters__explosionEvtId= -1,
    ammo_clusters__fireEvtId = -1,
    ammo_clusters__fireParamsId = -1,
    ammo_clusters__damageEffectPresetId = -1,
    ammo_clusters__reloadTimeMult = 1.0f,
    ammo_clusters__splashConstraints = float3(-1.0f, -1.0f, -1.0f),
    ammo_clusters__shatterConstraints = float3(-1.0f, -1.0f, -1.0f)
  ]]


[with_bundle(v)]
def reserve_clusters(cluster_count : int; var v : tuple<
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
                       ammo_clusters__elevatorPartsRange : IPoint2List
                     >) : void
  v.ammo_clusters__type |> reserve(cluster_count)
  v.ammo_clusters__state |> reserve(cluster_count)
  v.ammo_clusters__fireEvtId |> reserve(cluster_count)
  v.ammo_clusters__fireParamsId |> reserve(cluster_count)
  v.ammo_clusters__explosionEvtId |> reserve(cluster_count)
  v.ammo_clusters__damageEffectPresetId |> reserve(cluster_count)
  v.ammo_clusters__reloadTimeMult |> reserve(cluster_count)
  v.ammo_clusters__splashConstraints |> reserve(cluster_count)
  v.ammo_clusters__shatterConstraints |> reserve(cluster_count)
  v.ammo_clusters__exterminatedAmmo |> reserve(cluster_count)
  v.ammo_clusters__entityMunition |> reserve(cluster_count)
  v.ammo_clusters__slotsRange |> reserve(cluster_count)
  v.ammo_clusters__wreckageRange |> reserve(cluster_count)
  v.ammo_clusters__elevatorPartsRange |> reserve(cluster_count)


[with_bundle(v)]
def push_cluster(cluster_type : int; def_cluster : DefaultAmmoCluster&; var v : tuple<
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
                   ammo_slots__state : UInt32List
                 >) : int
  let cluster_id = v.ammo_clusters__type |> length()
  v.ammo_clusters__type |> push(cluster_type)
  v.ammo_clusters__state |> push(def_cluster.ammo_clusters__state)
  v.ammo_clusters__fireEvtId |> push(def_cluster.ammo_clusters__fireEvtId)
  v.ammo_clusters__fireParamsId |> push(def_cluster.ammo_clusters__fireParamsId)
  v.ammo_clusters__explosionEvtId |> push(def_cluster.ammo_clusters__explosionEvtId)
  v.ammo_clusters__damageEffectPresetId |> push(def_cluster.ammo_clusters__damageEffectPresetId)
  v.ammo_clusters__reloadTimeMult |> push(def_cluster.ammo_clusters__reloadTimeMult)
  v.ammo_clusters__splashConstraints |> push(def_cluster.ammo_clusters__splashConstraints)
  v.ammo_clusters__shatterConstraints |> push(def_cluster.ammo_clusters__shatterConstraints)
  v.ammo_clusters__exterminatedAmmo |> push(0)
  v.ammo_clusters__entityMunition |> push("")
  v.ammo_clusters__slotsRange |> push(int2(v.ammo_slots__state |> length()))
  v.ammo_clusters__wreckageRange |> push(int2(v.ammo_stowage__wreckageIds |> length()))
  if length(def_cluster.ammo_stowage__wreckageIds) > 0
    for wreckage_id in def_cluster.ammo_stowage__wreckageIds
      v.ammo_stowage__wreckageIds |> push(wreckage_id)
    v.ammo_clusters__wreckageRange[cluster_id].y = length(v.ammo_stowage__wreckageIds)
  v.ammo_clusters__elevatorPartsRange |> push(int2(v.ammo_stowage__elevatorPartsIds |> length()))
  if length(def_cluster.ammo_stowage__elevatorPartsIds) > 0
    for packed_elevator_part_id in def_cluster.ammo_stowage__elevatorPartsIds
      v.ammo_stowage__elevatorPartsIds |> push(unpack_part_id(packed_elevator_part_id))
    v.ammo_clusters__elevatorPartsRange[cluster_id].y = length(v.ammo_stowage__elevatorPartsIds)
  return cluster_id


def load_cluster_params(blk : DataBlock&; var unit : Unit?;
                        var ammo_clusters__state : uint&;
                        var ammo_clusters__explosionEvtId : int&;
                        var ammo_clusters__fireEvtId : int&;
                        var ammo_clusters__fireParamsId : int&;
                        var ammo_clusters__damageEffectPresetId : int&;
                        var ammo_clusters__reloadTimeMult : float&;
                        var ammo_clusters__splashConstraints : float3&;
                        var ammo_clusters__shatterConstraints : float3&;
                        add_wreckage : block<(id : int) : void>;
                        add_elevator_part : block<(id : PartId) : void>) : void
  blk |> read_flag(ammo_clusters__state, AmmoClusterState AUTO_LOAD, "autoLoad")
  blk |> read_flag(ammo_clusters__state, AmmoClusterState FIRST_STAGE, "firstStage")
  blk |> read_flag(ammo_clusters__state, AmmoClusterState REVERSE_FILL, "reverseFill")
  blk |> read_flag(ammo_clusters__state, AmmoClusterState FIRE_FATAL, "fatalFire")
  blk |> read_flag(ammo_clusters__state, AmmoClusterState EXPLOSION_FATAL, "fatalExplosion")
  blk |> read_flag(ammo_clusters__state, AmmoClusterState ELEVATOR_DESTROY_BLOCK_SHOOT, "dstrElevatorDisablesShooting")
  blk |> read_flag(ammo_clusters__state, AmmoClusterState RESTORE_AFTER_DEAD, "restoreAfterDead")
  ammo_clusters__reloadTimeMult = blk |> datablock_getReal("reloadTimeMult", ammo_clusters__reloadTimeMult)
  ammo_clusters__splashConstraints.x = blk |> datablock_getReal("splashRadiusConstraint", ammo_clusters__splashConstraints.x)
  ammo_clusters__splashConstraints.y = blk |> datablock_getReal("splashDamageConstraint", ammo_clusters__splashConstraints.y)
  ammo_clusters__splashConstraints.z = blk |> datablock_getReal("splashPenetrationConstraint", ammo_clusters__splashConstraints.z)
  ammo_clusters__shatterConstraints.x = blk |> datablock_getReal("shatterRadiusConstraint", ammo_clusters__shatterConstraints.x)
  ammo_clusters__shatterConstraints.y = blk |> datablock_getReal("shatterDamageConstraint", ammo_clusters__shatterConstraints.y)
  ammo_clusters__shatterConstraints.z = blk |> datablock_getReal("shatterPenetrationConstraint", ammo_clusters__shatterConstraints.z)

  let fire_params_preset = blk |> datablock_getStr("fireParamsPreset", "")
  if fire_params_preset != ""
    ammo_clusters__fireParamsId = dm_get_fire_params_id(fire_params_preset)
  if ammo_clusters__fireParamsId < 0
    ammo_clusters__fireParamsId = dm_get_fire_params_id("default")
  let fire_event_name = blk |> datablock_getStr("fireEvent", "")
  if fire_event_name != ""
    ammo_clusters__fireEvtId = *get_unit_fx(unit) |> getEventIdByName(fire_event_name);
  if ammo_clusters__fireEvtId < 0
    ammo_clusters__fireEvtId = *get_unit_fx(unit) |> getEventIdByName("ammo_fire");
  let explosion_event_name = blk |> datablock_getStr("explosionEvent", "")
  if explosion_event_name != ""
    ammo_clusters__explosionEvtId = *get_unit_fx(unit) |> getEventIdByName(explosion_event_name);
  if ammo_clusters__explosionEvtId < 0
    ammo_clusters__explosionEvtId = *get_unit_fx(unit) |> getEventIdByName("ammo_explosion");
  ammo_clusters__damageEffectPresetId = dm_read_overrided_preset(unit.visual.damageEffects, blk, "damageEffect", -1, unit.visual.dmData);

  let wreckage_name_id = blk |> datablock_getNameId("wreckedPartId")
  let elevator_name_id = blk |> datablock_getNameId("elevator")
  blk |> datablock_for_each_param() <| $(i, t)
    let name_id = blk |> datablock_getParamNameId(uint(i))
    if name_id == wreckage_name_id && t == int(DataBlockParamType TYPE_INT)
      let wreckage_id = blk |> datablock_getInt(i)
      if wreckage_id < 0
        logerr("unit {unit.props.fileName} : invalid wrecked part id {wreckage_id}")
        return
      add_wreckage |> invoke(wreckage_id)
    elif name_id == elevator_name_id && t == int(DataBlockParamType TYPE_STRING)
      let elevator_part_name = blk |> datablock_getStr(i)
      let elevator_part_id = find_part_id(unit.dmData, elevator_part_name)
      if !elevator_part_id.valid
        // Some vehicles declare missing damage parts in ammo stowage. To keep logic for this vehicles unchanged,
        // we just ignore it and do not add elevators for this parts. This issue arises from including same ammo stowage configs into many different vehicles.
        logwarn("unit {unit.props.fileName} : ammo elevator part {elevator_part_name} not found, elevator is not added. This is not an error and will not break anything.")
        return
      add_elevator_part |> invoke(elevator_part_id)


[with_bundle(v)]
def load_cluster(blk : DataBlock&; var unit : Unit?;
                 stowage_id : int; cluster_id : int; var num_ammo : int&;

                 var v : tuple<
                   ammo_stowage__partIdRemap : IPoint4List;

                   ammo_clusters__type : IntList;
                   ammo_clusters__state : UInt32List;
                   ammo_clusters__explosionEvtId : IntList;
                   ammo_clusters__fireEvtId : IntList;
                   ammo_clusters__fireParamsId : IntList;
                   ammo_clusters__damageEffectPresetId : IntList;
                   ammo_clusters__reloadTimeMult : FloatList;
                   ammo_clusters__splashConstraints : Point3List;
                   ammo_clusters__shatterConstraints : Point3List;
                   ammo_clusters__slotsRange : IPoint2List;
                   ammo_clusters__wreckageRange : IPoint2List;
                   ammo_clusters__elevatorPartsRange : IPoint2List;
                   ammo_stowage__wreckageIds : IntList;
                   ammo_stowage__elevatorPartsIds : PartIdList;

                   ammo_slots__state : UInt32List;
                   ammo_slots__partId : PartIdList;
                   ammo_slots__numAmmo : IPoint2List;
                   ammo_slots__node : AmmoStowageSlotCollAndGeomNodesList
                 >) : void
  if blk.blockCount == 0u || unit.visual == null
    return

  assert(v.ammo_clusters__wreckageRange[cluster_id].y == length(v.ammo_stowage__wreckageIds))
  assert(v.ammo_clusters__elevatorPartsRange[cluster_id].y == length(v.ammo_stowage__elevatorPartsIds))
  load_cluster_params(blk, unit,
    v.ammo_clusters__state[cluster_id],
    v.ammo_clusters__explosionEvtId[cluster_id],
    v.ammo_clusters__fireEvtId[cluster_id],
    v.ammo_clusters__fireParamsId[cluster_id],
    v.ammo_clusters__damageEffectPresetId[cluster_id],
    v.ammo_clusters__reloadTimeMult[cluster_id],
    v.ammo_clusters__splashConstraints[cluster_id],
    v.ammo_clusters__shatterConstraints[cluster_id]
  ) <| $(wreckage_id : int)
    v.ammo_stowage__wreckageIds |> push(wreckage_id)
  lpipe <| $(elevator_part_id : PartId)
    v.ammo_stowage__elevatorPartsIds |> push(elevator_part_id)
  v.ammo_clusters__wreckageRange[cluster_id].y = length(v.ammo_stowage__wreckageIds)
  v.ammo_clusters__elevatorPartsRange[cluster_id].y = length(v.ammo_stowage__elevatorPartsIds)

  var num_undistributed_slots = 0

  v.ammo_clusters__slotsRange[cluster_id].x = v.ammo_slots__state |> length()
  let damage_effect_name_id = blk |> datablock_getNameId("damageEffect")
  blk |> datablock_for_each_block() <| $(slot_blk)
    if slot_blk.blockNameId == damage_effect_name_id
      return

    let slot_id = v.ammo_slots__state |> length()
    let part_id = find_part_id(unit.dmData, slot_blk.blockName)
    if !part_id.valid
      // Some vehicles declare missing damage parts in ammo stowage. To keep logic for this vehicles unchanged,
      // we just ignore this and add slots, that are bound to invalid parts. This issue arises from including same ammo stowage configs into many different vehicles.
      logwarn("unit {unit.props.fileName}: ammo slot part {slot_blk.blockName} not found, ammo slot is still added. This is not an error and will not break anything.")

    let num_ammo_max = slot_blk |> datablock_getInt("count", 0)
    v.ammo_slots__state |> push(uint(AmmoSlotState ENABLED))
    v.ammo_slots__partId |> push(part_id)
    v.ammo_slots__numAmmo |> push(int2(0, num_ammo_max))
    v.ammo_slots__node |> push_empty()

    if part_id.valid
      let remap_added = add_remap(v.ammo_stowage__partIdRemap, [[PartRemap partId=part_id, stowageId=stowage_id, clusterId=cluster_id, slotId=slot_id]])
      if !remap_added
        logerr("unit {unit.props.fileName}: part {slot_blk.blockName} is already used in another stowage!")

      let visual_node_name = slot_blk |> datablock_getStr("visual", "")
      if visual_node_name != ""
        *unit.visual |> dm_bind_visual_node(int(part_id.globalId), visual_node_name)

      if unit.collNodeTree != null
        let cnode = *unit.visual |> dm_get_collision_node_by_part_id(int(part_id.globalId))
        let geom_node_id = *unit.visual |> dm_get_geom_node_id_by_part_id(int(part_id.globalId))
        let node_wtm = *unit.collNodeTree |> get_node_wtm_rel_ptr(geom_node_id)
        v.ammo_slots__node[slot_id] := [[AmmoStowageSlotCollAndGeomNodes() cnode=cnode, nodeWtm=node_wtm]]

    num_ammo -= num_ammo_max
    if num_ammo_max == 0
      num_undistributed_slots++

    assume cluster_state = v.ammo_clusters__state[cluster_id]
    assume cluster_type = v.ammo_clusters__type[cluster_id]
    let fire_or_explosion_fatal = get_flag(cluster_state, AmmoClusterState FIRE_FATAL) || get_flag(cluster_state, AmmoClusterState EXPLOSION_FATAL)
    if !(cluster_type == int(AmmoClusterType CHARGES) || fire_or_explosion_fatal || v.ammo_slots__node[slot_id].cnode != null)
      logerr("unit {unit.props.fileName}: collision node for part {slot_blk.blockName} not found")
    if !(cluster_type == int(AmmoClusterType CHARGES) || fire_or_explosion_fatal || v.ammo_slots__node[slot_id].nodeWtm != null)
      logerr("unit {unit.props.fileName}: geometry node for part {slot_blk.blockName} not found")
  v.ammo_clusters__slotsRange[cluster_id].y = v.ammo_slots__state |> length()

  if num_ammo > 0 && num_undistributed_slots > 0
    let num_ammo_per_slot = num_ammo / num_undistributed_slots
    let residue_ammo = num_ammo % num_undistributed_slots
    for i in v.ammo_clusters__slotsRange[cluster_id].x..v.ammo_clusters__slotsRange[cluster_id].y
      if v.ammo_slots__numAmmo[i].y == 0
        v.ammo_slots__numAmmo[i].y = i < residue_ammo ? num_ammo_per_slot + 1 : num_ammo_per_slot
    num_ammo = 0


struct LegacyLoadParams
  triggerGroupId : int
  stowageId : int
  shells_blk : DataBlock const?
  charges_blk : DataBlock const?
  numAmmo : int
  triggerIds : array<int>


[with_bundle(v)]
def public load_ammo_stowage(blk : DataBlock&; model_name : string; can_load_to_breech : bool;
                             uid : int;
                             var v : tuple<
                               ammo_stowage__dpAmmo : int3 const;

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
                             >) : void

  var unit = get_unit(uid)
  assert(unit != null)

  v.ammo_stowage__fxEvAmmoFireId = *get_unit_fx(unit) |> getEventIdByName("ammo_fire")

  blk |> datablock_get_block("ammo") <| $(ammo_blk)
    v.ammo_stowage__combustionTime = ammo_blk |> datablock_getReal("combustionTime", v.ammo_stowage__combustionTime)
    if v.ammo_stowage__combustionTime < 1.0f
      logerr("unit {model_name} : invalid ammo combustion time {v.ammo_stowage__combustionTime} < 1.0")
      v.ammo_stowage__combustionTime = 1.0f
    v.ammo_stowage__detonateProb = ammo_blk |> datablock_getReal("detonateProb", v.ammo_stowage__detonateProb)
    v.ammo_stowage__detonatePortion = ammo_blk |> datablock_getPoint2("detonatePortion", v.ammo_stowage__detonatePortion)
    v.ammo_stowage__detonateMinCaliber = ammo_blk |> datablock_getReal("ammoMinCaliberForDetonate", v.ammo_stowage__detonateMinCaliber)
    v.ammo_stowage__damagePropsId = dm_register_props_ex(model_name + "^ammo", ammo_blk, "damage")

  if !unit.isHumanPlayer && !unit_change_data_has_any_bullets(unit)
    return

  var load_successful = false
  let weapon_controller = unit.weap

  datablock_get_block(unit.modBlk != null && *unit.modBlk |> datablock_block_exists("ammoStowages") ? *unit.modBlk : blk, "ammoStowages") <| $(stowages_blk)
    let trigger_count = weapon_controller.Weapons.triggerCount
    var num_ammos : array<int>
    var num_ammos_in_cartridge : array<int>
    num_ammos |> resize(trigger_count)
    num_ammos_in_cartridge |> resize(trigger_count)
    for trigger_id in 0..trigger_count
      for weapon in weapon_controller.Weapons |> get_weapons_by_trigger(trigger_id)
        if weapon != null
          num_ammos[trigger_id] += weapon.fullBullets
          let gun = weapon |> as_gun()
          if gun != null
            num_ammos_in_cartridge[trigger_id] += gun.currentBulletSet.bulletsCartridge
          else
            num_ammos_in_cartridge[trigger_id] += weapon.ammoParts.length

    let dm = unit.visual
    assert(dm != null)

    var reserved_cluster_count = 0
    stowages_blk |> datablock_for_each_block() <| $(stowage_blk)
      reserved_cluster_count += int(stowage_blk.blockCount)
    reserve_clusters(reserved_cluster_count) <| v

    stowages_blk |> datablock_for_each_block() <| $(stowage_blk)
      let stowage_id = push_stowage() <| v

      let ignore_replenishment = get_difficulty_config().ignoreReplenishment
      v.ammo_stowages__replenishmentTime[stowage_id] = (!ignore_replenishment ?
        float2(stowage_blk |> datablock_getReal("replenishmentTime", -1.0f), stowage_blk |> datablock_getReal("replenishmentDelay", 0.0f)) :
        float2(/* arcade replenishment time */ 0.1f, 0.0f)
      )

      stowage_blk |> read_flag(v.ammo_stowages__state[stowage_id], AmmoStowageState REMOVE_LOADED_AMMO, "removeLoadedAmmo", true)

      let stowage_munition = stowage_blk |> datablock_getStr("entityMunition", "")

      let mass_to_splash_blk = stowage_blk |> datablock_get_block_by_name("gunpowderMassToSplashParams")
      if mass_to_splash_blk != null
        v.ammo_stowages__powderMassToSplash[stowage_id].innerRadius |> read_interpolate_tab_float_p2(
          *datablock_get_block_by_name_ex(*mass_to_splash_blk, "gunpowderMassToInnerRadius"))
        v.ammo_stowages__powderMassToSplash[stowage_id].outerRadius |> read_interpolate_tab_float_p2(
          *datablock_get_block_by_name_ex(*mass_to_splash_blk, "gunpowderMassToOuterRadius"))
        v.ammo_stowages__powderMassToSplash[stowage_id].penetration |> read_interpolate_tab_float_p2(
          *datablock_get_block_by_name_ex(*mass_to_splash_blk, "gunpowderMassToPenetration"))
        v.ammo_stowages__powderMassToSplash[stowage_id].damage |> read_interpolate_tab_float_p2(
          *datablock_get_block_by_name_ex(*mass_to_splash_blk, "gunpowderMassToDamage"))
      else
        v.ammo_stowages__powderMassToSplash[stowage_id] := get_dm_params().gunpowderToSplash

      var num_ammo_in_storage = 0
      v.ammo_stowages__weaponTriggersRange[stowage_id].x = v.ammo_stowage__weaponTriggers |> length()
      stowage_blk |> datablock_for_each_param("weaponTrigger") <| $(i, t)
        if t != int(DataBlockParamType TYPE_STRING)
          return
        let trigger_name = stowage_blk |> datablock_getStr(i)
        let trigger_id = get_trigger_no_by_name(trigger_name)
        if trigger_id < 0
          logerr("unit {model_name} : unknown trigger name {trigger_name}")
          return

        v.ammo_stowage__weaponTriggers |> push(trigger_id)
        if v.ammo_stowage__triggerIdRemap |> length() <= trigger_id
          let last_len = length(v.ammo_stowage__triggerIdRemap)
          v.ammo_stowage__triggerIdRemap |> resize(trigger_id + 1)
          for trigger_remap_idx in last_len..length(v.ammo_stowage__triggerIdRemap)
            v.ammo_stowage__triggerIdRemap[trigger_remap_idx] = -1
        if v.ammo_stowage__triggerIdRemap[trigger_id] != -1
          logwarn("unit {model_name} : duplicate trigger {trigger_name} ({trigger_id}) form ammo stowages #{stowage_id} and #{v.ammo_stowage__triggerIdRemap[trigger_id]}")
        v.ammo_stowage__triggerIdRemap[trigger_id] = stowage_id;
        num_ammo_in_storage += num_ammos[trigger_id]
        if get_flag(v.ammo_stowages__state[stowage_id], AmmoStowageState REMOVE_LOADED_AMMO)
          num_ammo_in_storage -= num_ammos_in_cartridge[trigger_id]
      v.ammo_stowages__weaponTriggersRange[stowage_id].y = v.ammo_stowage__weaponTriggers |> length()

      var num_ammo_for_cluster_type = [[int[2] num_ammo_in_storage; num_ammo_in_storage]]
      var has_charges = false

      let gunpowder_mts_params_name_id = stowage_blk |> datablock_getNameId("gunpowderMassToSplashParams")
      let shells_name_id = stowage_blk |> datablock_getNameId("shells")
      let charges_name_id = stowage_blk |> datablock_getNameId("charges")

      var def_cluster <- make_default_cluster()
      load_cluster_params(stowage_blk, unit,
        def_cluster.ammo_clusters__state,
        def_cluster.ammo_clusters__explosionEvtId,
        def_cluster.ammo_clusters__fireEvtId,
        def_cluster.ammo_clusters__fireParamsId,
        def_cluster.ammo_clusters__damageEffectPresetId,
        def_cluster.ammo_clusters__reloadTimeMult,
        def_cluster.ammo_clusters__splashConstraints,
        def_cluster.ammo_clusters__shatterConstraints
      ) <| $(wreckage_id)
        def_cluster.ammo_stowage__wreckageIds |> push(wreckage_id)
      lpipe <| $(elevator_part_id)
        def_cluster.ammo_stowage__elevatorPartsIds |> push(elevator_part_id.packed)

      v.ammo_stowages__clustersRange[stowage_id].x = v.ammo_clusters__type |> length()

      stowage_blk |> datablock_for_each_block() <| $(cluster_blk)
        if cluster_blk.blockNameId == gunpowder_mts_params_name_id
          return

        var cluster_type = -1
        if cluster_blk.blockNameId == shells_name_id
          cluster_type = int(AmmoClusterType SHELLS)
        elif cluster_blk.blockNameId == charges_name_id
          cluster_type = int(AmmoClusterType CHARGES)
          has_charges = true
        else
          logerr("unit {model_name} : unknown trigger cluster type {cluster_blk.getBlockName}")
          return

        // add new cluster
        let cluster_id = push_cluster(cluster_type, def_cluster) <| v

        // load cluster
        let prev_num_ammo = num_ammo_for_cluster_type[v.ammo_clusters__type[cluster_id]]
        load_cluster(cluster_blk, unit, stowage_id, cluster_id, num_ammo_for_cluster_type[v.ammo_clusters__type[cluster_id]]) <| v
        v.ammo_clusters__entityMunition[cluster_id] := stowage_blk |> datablock_getStr("entityMunition", stowage_munition)

        if (get_flag(v.ammo_clusters__state[cluster_id], AmmoClusterState AUTO_LOAD))
          set_flag(v.ammo_stowages__state[stowage_id], AmmoStowageState HAS_AUTO_LOAD, true)

        if v.ammo_clusters__type[cluster_id] == int(AmmoClusterType SHELLS)
          let diff = prev_num_ammo - num_ammo_for_cluster_type[int(AmmoClusterType SHELLS)]
          v.ammo_stowages__numAmmo[stowage_id].z += diff
          if get_flag(v.ammo_clusters__state[cluster_id], AmmoClusterState AUTO_LOAD) || get_flag(v.ammo_clusters__state[cluster_id], AmmoClusterState FIRST_STAGE)
            v.ammo_stowages__numAmmoFirstStage[stowage_id].z += diff

      v.ammo_stowages__clustersRange[stowage_id].y = v.ammo_clusters__type |> length()

    setup_ammo_stowage(unit, can_load_to_breech, true) <| v;
    load_successful = true

  if load_successful
    return

  // legacy format
  blk |> datablock_get_block("ammoLoadDistribution") <| $(load_distrib_blk)
    var load_params : LegacyLoadParams[3]
    var legacy_load_data : array<tuple<triggerGroupId : int; shellsName : string; chargesName : string>>
    legacy_load_data |> reserve(3)
    legacy_load_data |> push([[auto int(WeaponTriggerGroups TRIGGER_GROUP_PRIMARY), "primaryShells", "primaryCharges"]])
    legacy_load_data |> push([[auto int(WeaponTriggerGroups TRIGGER_GROUP_SECONDARY), "secondaryShells", "secondaryCharges"]])
    legacy_load_data |> push([[auto int(WeaponTriggerGroups TRIGGER_GROUP_SPECIAL_GUN), "special", ""]])

    for params, load in load_params, legacy_load_data
      params.triggerGroupId = load.triggerGroupId
      params.shells_blk = load.shellsName != "" ? load_distrib_blk |> datablock_get_block_by_name_id(load_distrib_blk |> datablock_getNameId(load.shellsName)) : null
      params.charges_blk = load.chargesName != "" ? load_distrib_blk |> datablock_get_block_by_name_id(load_distrib_blk |> datablock_getNameId(load.chargesName)) : null
      params.stowageId = -1
      params.numAmmo = 0

    let remove_loaded_ammo = load_distrib_blk |> datablock_getBool("removeLoadedAmmo", true)
    for params in load_params
      if params.shells_blk != null || params.charges_blk != null
        params.stowageId = push_stowage() <| v
        set_flag(v.ammo_stowages__state[params.stowageId], AmmoStowageState REMOVE_LOADED_AMMO, remove_loaded_ammo)

    for turret in weapon_controller.turret
      let weapon = get_weapon(weapon_controller.Weapons, int(turret.triggerNo), int(turret.weaponIndex))
      if weapon == null
        continue

      var num_ammo = weapon.fullBullets
      let gun = weapon |> as_gun()
      if gun != null && remove_loaded_ammo
        num_ammo -= gun.currentBulletSet.bulletsCartridge

      if num_ammo > 0
        for params in load_params
          if params.stowageId >= 0 && params.triggerGroupId == int(turret.triggerGroupNo)
            params.numAmmo += num_ammo
            if find_index(params.triggerIds, int(turret.triggerNo)) == -1
              params.triggerIds |> push(int(turret.triggerNo))

    for params in load_params
      if params.stowageId >= 0
        v.ammo_stowages__weaponTriggersRange[params.stowageId].x = v.ammo_stowage__weaponTriggers |> length()
        for trigger in params.triggerIds
          v.ammo_stowage__weaponTriggers |> push(trigger)
        v.ammo_stowages__weaponTriggersRange[params.stowageId].y = v.ammo_stowage__weaponTriggers |> length()

    let def_cluster <- make_default_cluster()
    for params in load_params
      if params.stowageId < 0
        continue
      v.ammo_stowages__clustersRange[params.stowageId].x = v.ammo_clusters__type |> length()
      if params.shells_blk != null
        var num_shells = params.numAmmo
        let cluster_id = push_cluster(int(AmmoClusterType SHELLS), def_cluster) <| v
        load_cluster(*params.shells_blk, unit, params.stowageId, cluster_id, num_shells) <| v
        if num_shells > 0
          logerr("unit {model_name} : not enough free slots to distribute residue shells, {num_shells} remaining")
      if params.charges_blk != null
        var num_charges = params.numAmmo
        let cluster_id = push_cluster(int(AmmoClusterType CHARGES), def_cluster) <| v
        load_cluster(*params.charges_blk, unit, params.stowageId, cluster_id, num_charges) <| v
        if num_charges > 0
          logerr("unit {model_name} : not enough free slots to distribute residue charges, {num_charges} remaining")
      v.ammo_stowages__clustersRange[params.stowageId].y = v.ammo_clusters__type |> length()

    setup_ammo_stowage(unit, can_load_to_breech, true) <| v;
    load_successful = true

  if load_successful
    return

  /// for units without ammo stowage settings:
  /// 1. create single cluster in single stowage
  /// 2. put all bullets from primary guns to cluster
  /// 3. add all active ammo damage parts to cluster
  if v.ammo_stowage__dpAmmo.z >= 0
    let stowage_id = push_stowage() <| v
    v.ammo_stowages__clustersRange[stowage_id].x = v.ammo_clusters__type |> length()
    let cluster_id = push_cluster(int(AmmoClusterType SHELLS), make_default_cluster()) <| v
    v.ammo_stowages__clustersRange[stowage_id].y = v.ammo_clusters__type |> length()

    v.ammo_clusters__slotsRange[cluster_id].x = v.ammo_slots__state |> length()
    for part_no in v.ammo_stowage__dpAmmo.x..(v.ammo_stowage__dpAmmo.y + 1)
      let part_id = dm_get_remap(*unit.visual, part_no)
      if part_id.valid
        v.ammo_slots__state |> push(uint(AmmoSlotState ENABLED))
        v.ammo_slots__partId |> push(part_id)
        v.ammo_slots__numAmmo |> push(int2(0, 0))
        v.ammo_slots__node |> push_empty()
    v.ammo_clusters__slotsRange[cluster_id].y = v.ammo_slots__state |> length()
    let slot_count = v.ammo_clusters__slotsRange[cluster_id].y - v.ammo_clusters__slotsRange[cluster_id].x
    if slot_count == 0
      return

    var num_ammo_total = 0
    v.ammo_stowages__weaponTriggersRange[stowage_id].x = v.ammo_stowage__weaponTriggers |> length()
    for turret in weapon_controller.turret
      if turret.triggerGroupNo == int16(WeaponTriggerGroups TRIGGER_GROUP_PRIMARY)
        let weapon = get_weapon(weapon_controller.Weapons, int(turret.triggerNo), int(turret.weaponIndex))
        let num_ammo = weapon != null ? weapon.fullBullets : 0
        if num_ammo > 0
          num_ammo_total += num_ammo
          v.ammo_stowage__weaponTriggers |> push(int(turret.triggerNo))
    v.ammo_stowages__weaponTriggersRange[stowage_id].y = v.ammo_stowage__weaponTriggers |> length()

    if num_ammo_total > 0
      let num_ammo_per_slot = num_ammo_total / slot_count
      let residue_ammo = num_ammo_total % slot_count
      for slot_id in v.ammo_clusters__slotsRange[cluster_id].x..v.ammo_clusters__slotsRange[cluster_id].y
        if v.ammo_slots__numAmmo[slot_id].y == 0
          v.ammo_slots__numAmmo[slot_id].y = slot_id < residue_ammo ? num_ammo_per_slot + 1 : num_ammo_per_slot

    setup_ammo_stowage(unit, can_load_to_breech, true) <| v;
    load_successful = true


[with_bundle(v)]
def setup_cluster(var unit : Unit?; cluster_id : int; var num_ammos : int&; num_used : int; var base_index : int&;
                  v : tuple<
                    ammo_clusters__state : UInt32List- const;
                    ammo_clusters__slotsRange : IPoint2List;
                    ammo_slots__state : UInt32List- const;
                    ammo_slots__partId : PartIdList;
                    ammo_slots__numAmmo : IPoint2List- const
                  >) : bool
  var is_changed = false
  set_flag(v.ammo_clusters__state[cluster_id], AmmoClusterState EMPTY, num_ammos == 0)
  let cluster_state = v.ammo_clusters__state[cluster_id]
  let reverse_fill = get_flag(cluster_state, AmmoClusterState REVERSE_FILL)
  let slots_range = v.ammo_clusters__slotsRange[cluster_id]
  var i = reverse_fill ? slots_range.y - 1 : slots_range.x
  for _ in slots_range.x..slots_range.y
    let slot_id = reverse_fill ? i-- : i++
    let slot_enabled = get_flag(v.ammo_slots__state[slot_id], AmmoSlotState ENABLED)
    let slot_part_id = v.ammo_slots__partId[slot_id]
    if get_flag(cluster_state, AmmoClusterState RESTORE_AFTER_DEAD) && !slot_enabled && num_ammos > 0
      set_flag(v.ammo_slots__state[slot_id], AmmoSlotState ENABLED, true)
      *unit.visual |> dm_set_rel_hp(int(slot_part_id.globalId), 1.0f, false)
    if !reverse_fill && slot_id + base_index - slots_range.x < num_used
      v.ammo_slots__numAmmo[slot_id].x = 0
    elif slot_enabled && num_ammos > v.ammo_slots__numAmmo[slot_id].y
      v.ammo_slots__numAmmo[slot_id].x = v.ammo_slots__numAmmo[slot_id].y
      num_ammos -= v.ammo_slots__numAmmo[slot_id].x
    elif slot_enabled && num_ammos > 0
      if v.ammo_slots__numAmmo[slot_id].x == 0
        *unit.visual |> dm_set_rel_hp(int(slot_part_id.globalId), 1.0f, false)
      v.ammo_slots__numAmmo[slot_id].x = num_ammos
      num_ammos = 0
    else
      v.ammo_slots__numAmmo[slot_id].x = 0

    let is_enabled = v.ammo_slots__numAmmo[slot_id].x > 0
    if *unit.visual |> dm_is_part_enabled(slot_part_id) != is_enabled
      *unit.visual |> dm_set_part_enabled(slot_part_id, is_enabled)
      *unit.visual |> dm_set_decor_by_part_id(int(slot_part_id.globalId), is_enabled)
      is_changed = true
  base_index += slots_range.y - slots_range.x
  return is_changed


[with_bundle(v)]
def public setup_ammo_stowage(var unit : Unit?; can_load_to_breech : bool; init_num : bool;
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
                                ammo_clusters__slotsRange : IPoint2List;
                                ammo_slots__state : UInt32List- const;
                                ammo_slots__partId : PartIdList;
                                ammo_slots__numAmmo : IPoint2List- const
                              >) : bool
  let eid = unit.eid
  let weapon_controller = unit.weap
  var is_dm_changed = false
  var is_sync_required = false
  for state, stowage_num_ammo, stowage_num_ammo_first_stage, clusters_range, triggers_range in v.ammo_stowages__state, v.ammo_stowages__numAmmo, v.ammo_stowages__numAmmoFirstStage, v.ammo_stowages__clustersRange, v.ammo_stowages__weaponTriggersRange
    var num_ammo = 0
    for i in triggers_range.x..triggers_range.y
      for weapon in weapon_controller.Weapons |> get_weapons_by_trigger(v.ammo_stowage__weaponTriggers[i])
        if weapon == null
          continue
        let gun = weapon |> as_gun()
        if gun != null
          var count = 0
          for bullet_set in gun.properties.bulletSets
            if bullet_set.bulletsCount > 0
              count += bullet_set.bulletsCount
          let bullets_cartidge = gun.currentBulletSet.bulletsCartridge
          if count > 0
            if get_flag(state, AmmoStowageState REMOVE_LOADED_AMMO) && can_load_to_breech
              num_ammo += ((count - 1) / bullets_cartidge) * bullets_cartidge
            else
              num_ammo += count;
        else
          let count = weapon.countBullets
          if count > 0
            num_ammo += get_flag(state, AmmoStowageState REMOVE_LOADED_AMMO) ? count - 1 : count

    if num_ammo > stowage_num_ammo.x
      for cluster_id in clusters_range.x..clusters_range.y
        let slots_range = v.ammo_clusters__slotsRange[cluster_id]
        for slot_id in slots_range.x..slots_range.y
          if !get_flag(v.ammo_slots__state[slot_id], AmmoSlotState ENABLED)
            v.ammo_stowage__ammoLost = 0
            set_flag(v.ammo_slots__state[slot_id], AmmoSlotState ENABLED, true)
            *unit.visual |> dm_set_rel_hp(int(v.ammo_slots__partId[slot_id].globalId), 1.0f, false)

      if stowage_num_ammo_first_stage.z > 0
        stowage_num_ammo_first_stage.x = min(stowage_num_ammo_first_stage.x + num_ammo - stowage_num_ammo.x,  stowage_num_ammo_first_stage.z)
        is_sync_required = true

    if stowage_num_ammo_first_stage.z > 0 && num_ammo < stowage_num_ammo.x
      stowage_num_ammo_first_stage.x = max(get_flag(state, AmmoStowageState HAS_AUTO_LOAD) && get_flag(state, AmmoStowageState REMOVE_LOADED_AMMO) && can_load_to_breech ? -1 : 0,
                                            stowage_num_ammo_first_stage.x + num_ammo - stowage_num_ammo.x)
      is_sync_required = true

    stowage_num_ammo.x = num_ammo
    if init_num
      stowage_num_ammo.y = num_ammo
      stowage_num_ammo_first_stage.y = stowage_num_ammo_first_stage.x

    // das does not allow use this as array size directly, because this is not technically a constant, so we hardcode it and guard with assert
    assert(int(AmmoClusterType NUM_TYPES) == 2)
    var num_ammos : int[2]
    var num_ammos_first_stage : int[2]
    var base_index : int[2];
    for i in 0..int(AmmoClusterType NUM_TYPES)
      num_ammos_first_stage[i] = stowage_num_ammo_first_stage.x
      num_ammos[i] = num_ammo - stowage_num_ammo_first_stage.x
      base_index[i] = 0

    if stowage_num_ammo_first_stage.z > 0
      var i = clusters_range.y - 1
      for _ in clusters_range.x..clusters_range.y
        let cluster_id = i--
        if get_flag(v.ammo_clusters__state[cluster_id], AmmoClusterState FIRST_STAGE) || get_flag(v.ammo_clusters__state[cluster_id], AmmoClusterState AUTO_LOAD)
          let cluster_type = v.ammo_clusters__type[cluster_id]
          is_dm_changed = setup_cluster(unit, cluster_id, num_ammos_first_stage[cluster_type],
                                        stowage_num_ammo_first_stage.y - num_ammos_first_stage[cluster_type],
                                        base_index[cluster_type], v) || is_dm_changed
      for cluster_id in clusters_range.x..clusters_range.y
        if !get_flag(v.ammo_clusters__state[cluster_id], AmmoClusterState FIRST_STAGE) && !get_flag(v.ammo_clusters__state[cluster_id], AmmoClusterState AUTO_LOAD)
          let cluster_type = v.ammo_clusters__type[cluster_id]
          is_dm_changed = setup_cluster(unit, cluster_id, num_ammos[cluster_type],
                                        stowage_num_ammo.y - num_ammos[cluster_type],
                                        base_index[cluster_type], v) || is_dm_changed
    else
      for cluster_id in clusters_range.x..clusters_range.y
        if !get_flag(v.ammo_clusters__state[cluster_id], AmmoClusterState FIRST_STAGE) && !get_flag(v.ammo_clusters__state[cluster_id], AmmoClusterState AUTO_LOAD)
          let cluster_type = v.ammo_clusters__type[cluster_id]
          is_dm_changed = setup_cluster(unit, cluster_id, num_ammos[cluster_type],
                                        stowage_num_ammo.y - num_ammos[cluster_type],
                                        base_index[cluster_type], v) || is_dm_changed

  if is_dm_changed
    sendEvent(eid, [[EventAmmoStowageInvalidateRenderer]])
  return is_sync_required


struct BulletSetState
  gun : Gun?
  bulletSetId : int
  minVal : int
  maxVal : int

def get_bullets_count(bss : BulletSetState&)
  return bss.gun.properties.bulletSets[bss.bulletSetId].bulletsCount

def set_bullets_count(var bss : BulletSetState&; count : int)
  bss.gun.properties.bulletSets[bss.bulletSetId].bulletsCount = count


[with_bundle(v)]
def public set_slot_enabled(unit : Unit?; stowage_id : int; slot_id : int; state : AmmoSlotEnabledState;
                            v : tuple<
                              ammo_stowages__weaponTriggersRange : IPoint2List;
                              ammo_stowage__weaponTriggers : IntList;
                              ammo_slots__state : UInt32List- const;
                              ammo_slots__numAmmo : IPoint2List;
                              ammo_stowage__ammoLost : int-const
                            >) : void
  let weapon_controller = unit.weap
  let triggers_range = v.ammo_stowages__weaponTriggersRange[stowage_id]
  var bullet_set_states : array<BulletSetState>
  bullet_set_states |> reserve(triggers_range.y - triggers_range.x)
  for trigger_id_idx in triggers_range.x..triggers_range.y
    let trigger_id = v.ammo_stowage__weaponTriggers[trigger_id_idx]
    for weapon in weapon_controller.Weapons |> get_weapons_by_trigger(trigger_id)
      if weapon == null
        continue
      weapon.ammoDrowned = (state == AmmoSlotEnabledState DISABLED_DROWN)
      var gun = weapon |> as_gun()
      if gun == null
        continue
      for bullet_set, bullet_set_id in gun.properties.bulletSets, 0..length(gun.properties.bulletSets)
        if state == AmmoSlotEnabledState ENABLED
          if length(bullet_set.bullet) > 0
            bullet_set.bulletsCount = bullet_set.bullet[0].props.count - int(bullet_set.bulletsBorn)
        else
          let extracted = int(gun.chosenBulletType) == bullet_set_id || int(gun.nextBulletType) == bullet_set_id
          bullet_set_states |> push([[BulletSetState
            gun=gun,
            bulletSetId=bullet_set_id,
            minVal=extracted ? 1 : 0,
            maxVal=bullet_set.bullet[0].props.count
          ]])

  if state != AmmoSlotEnabledState ENABLED
    var undistributed = v.ammo_slots__numAmmo[slot_id].x;
    var changed = true
    while undistributed > 0 && changed
      changed = false
      var sum_max = 0
      for bullet_set_state in bullet_set_states
        if get_bullets_count(bullet_set_state) > bullet_set_state.minVal
          sum_max += bullet_set_state.maxVal
      if sum_max == 0
        break
      let k = float(undistributed) / float(sum_max)
      for bullet_set_state in bullet_set_states
        let bullets_count = get_bullets_count(bullet_set_state)
        let to_subtract = min(
          min(int(ceil(k * float(bullet_set_state.maxVal))), undistributed),
          bullets_count - bullet_set_state.minVal
        );
        if to_subtract > 0
          set_bullets_count(bullet_set_state, bullets_count - to_subtract)
          undistributed -= to_subtract
          changed = true

    if state == AmmoSlotEnabledState DISABLED_SIMPLE
      v.ammo_stowage__ammoLost += v.ammo_slots__numAmmo[slot_id].x

  set_flag(v.ammo_slots__state[slot_id], AmmoSlotState ENABLED, state == AmmoSlotEnabledState ENABLED)


[with_bundle(v)]
def public set_slot_enabled_by_part_id(unit : Unit?; part_id : PartId; state : AmmoSlotEnabledState;
                                       v : tuple<
                                         ammo_stowage__partIdRemap : IPoint4List;
                                         ammo_stowages__weaponTriggersRange : IPoint2List;
                                         ammo_stowage__weaponTriggers : IntList;
                                         ammo_slots__state : UInt32List- const;
                                         ammo_slots__numAmmo : IPoint2List;
                                         ammo_stowage__ammoLost : int-const
                                       >) : void
  let remap = get_remap(v.ammo_stowage__partIdRemap, part_id)
  if remap.partId.valid
    set_slot_enabled(unit, remap.stowageId, remap.slotId, state) <| v


[with_bundle(v)]
def public calc_slot_pos(slot_id : int;
                         v : tuple<
                           ammo_slots__node : AmmoStowageSlotCollAndGeomNodesList
                         >) : float3
  // TODO: workaround for crach fix, remove it after added check nodes to load!
  if v.ammo_slots__node[slot_id].nodeWtm == null || v.ammo_slots__node[slot_id].cnode == null
    return float3(0.0f)

  var tm : float3x4 = identity3x4()
  mat44f_to_TMatrix(*v.ammo_slots__node[slot_id].nodeWtm, tm);
  return tm * v.ammo_slots__node[slot_id].cnode.boundingSphere.c;


[with_bundle(v)]
def public ammo_stowage_calc_fill(v : tuple<
                                    ammo_slots__numAmmo : IPoint2List
                                  >) : float
  var total_ammo = int2(0)
  for num_ammo in v.ammo_slots__numAmmo
    total_ammo += num_ammo
  return safediv(float(total_ammo.x), float(total_ammo.y))

