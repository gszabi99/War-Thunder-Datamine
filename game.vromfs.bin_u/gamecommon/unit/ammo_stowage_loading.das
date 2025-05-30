require daslib/algorithm
require ecs
require dm
require app
require DagorDataBlock
require DagorSystem
require GeomNodeTree
require Unit
require UnitFx
require Weapon
require AmmoStowage
require WTDamageModel
require %game.utils.component_bundle_macro
require %game.utils.utils_common
require %game.unit.unit_events
require %game.unit.ammo_stowage_events
require %game.unit.ammo_stowage_common

[with_bundle(v)]
def push_stowage(var v : tuple<
                   ammo_stowages__state : UInt32List;
                   ammo_stowages__bulletsCartridge : IntList;
                   ammo_stowages__replenishmentStartEnd : Point2List;
                   ammo_stowages__replenishmentTime : Point2List;
                   ammo_stowages__floodedAmmoReloadMult : FloatList;
                   ammo_stowages__powderMassToSplash : AmmoStowageMassToSplashList;
                   ammo_stowages__clustersRange : IPoint2List;
                   ammo_stowages__weaponTriggersRange : IPoint2List;
                   ammo_stowage__weaponTriggers : IntList
                   >) : int
  let stowage_id = v.ammo_stowages__state |> length()
  v.ammo_stowages__state |> push(uint(AmmoStowageState.REMOVE_LOADED_AMMO))
  v.ammo_stowages__bulletsCartridge |> push(1)
  v.ammo_stowages__replenishmentStartEnd |> push(float2(-1.0f, -1.0f))
  v.ammo_stowages__replenishmentTime |> push(float2(0.0f, -1.0f))
  v.ammo_stowages__floodedAmmoReloadMult |> push(1.0f)
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
  ammo_clusters__fireSplashConstraints : float3
  ammo_stowage__wreckageIds : array<int>
  ammo_stowage__relatedPartsIds : array<uint>


def make_default_cluster() : DefaultAmmoCluster
  return <- DefaultAmmoCluster(
    ammo_clusters__state = (
      uint(AmmoClusterState.EMPTY) |
      uint(AmmoClusterState.REVERSE_FILL) |
      uint(AmmoClusterState.FIRE_FATAL) |
      uint(AmmoClusterState.EXPLOSION_FATAL)
    ),
    ammo_clusters__explosionEvtId = -1,
    ammo_clusters__fireEvtId = -1,
    ammo_clusters__fireParamsId = -1,
    ammo_clusters__damageEffectPresetId = -1,
    ammo_clusters__reloadTimeMult = 1.0f,
    ammo_clusters__splashConstraints = float3(-1.0f, -1.0f, -1.0f),
    ammo_clusters__shatterConstraints = float3(-1.0f, -1.0f, -1.0f),
    ammo_clusters__fireSplashConstraints = float3(-1.0f, -1.0f, -1.0f)
  )


[with_bundle(v)]
def reserve_clusters(cluster_count : int; var v : tuple<
                       ammo_clusters__typeAndStage : UInt16List;
                       ammo_clusters__state : UInt32List;
                       ammo_clusters__fireEvtId : IntList;
                       ammo_clusters__fireParamsId : IntList;
                       ammo_clusters__explosionEvtId : IntList;
                       ammo_clusters__damageEffectPresetId : IntList;
                       ammo_clusters__reloadTimeMult : FloatList;
                       ammo_clusters__splashConstraints : Point3List;
                       ammo_clusters__shatterConstraints : Point3List;
                       ammo_clusters__fireSplashConstraints : Point3List;
                       ammo_clusters__entityMunition : StringList;
                       ammo_clusters__slotsRange : IPoint2List;
                       ammo_clusters__wreckageRange : IPoint2List;
                       ammo_clusters__relatedPartsRange : IPoint2List
                       >) : void
  v.ammo_clusters__typeAndStage |> reserve(cluster_count)
  v.ammo_clusters__state |> reserve(cluster_count)
  v.ammo_clusters__fireEvtId |> reserve(cluster_count)
  v.ammo_clusters__fireParamsId |> reserve(cluster_count)
  v.ammo_clusters__explosionEvtId |> reserve(cluster_count)
  v.ammo_clusters__damageEffectPresetId |> reserve(cluster_count)
  v.ammo_clusters__reloadTimeMult |> reserve(cluster_count)
  v.ammo_clusters__splashConstraints |> reserve(cluster_count)
  v.ammo_clusters__shatterConstraints |> reserve(cluster_count)
  v.ammo_clusters__fireSplashConstraints |> reserve(cluster_count)
  v.ammo_clusters__entityMunition |> reserve(cluster_count)
  v.ammo_clusters__slotsRange |> reserve(cluster_count)
  v.ammo_clusters__wreckageRange |> reserve(cluster_count)
  v.ammo_clusters__relatedPartsRange |> reserve(cluster_count)


[with_bundle(v)]
def push_cluster(cluster_type : int; cluster_stage : int; def_cluster : DefaultAmmoCluster&; var v : tuple<
                   ammo_clusters__typeAndStage : UInt16List;
                   ammo_clusters__state : UInt32List;
                   ammo_clusters__fireEvtId : IntList;
                   ammo_clusters__fireParamsId : IntList;
                   ammo_clusters__explosionEvtId : IntList;
                   ammo_clusters__damageEffectPresetId : IntList;
                   ammo_clusters__reloadTimeMult : FloatList;
                   ammo_clusters__splashConstraints : Point3List;
                   ammo_clusters__shatterConstraints : Point3List;
                   ammo_clusters__fireSplashConstraints : Point3List;
                   ammo_clusters__entityMunition : StringList;
                   ammo_clusters__slotsRange : IPoint2List;
                   ammo_clusters__wreckageRange : IPoint2List;
                   ammo_clusters__relatedPartsRange : IPoint2List;
                   ammo_stowage__wreckageIds : IntList;
                   ammo_stowage__relatedPartsIds : PartIdList;
                   ammo_slots__state : UInt32List
                   >) : int
  let cluster_id = v.ammo_clusters__typeAndStage |> length()
  v.ammo_clusters__typeAndStage |> push(uint16(cluster_type | (cluster_stage << 8)))
  v.ammo_clusters__state |> push(def_cluster.ammo_clusters__state)
  v.ammo_clusters__fireEvtId |> push(def_cluster.ammo_clusters__fireEvtId)
  v.ammo_clusters__fireParamsId |> push(def_cluster.ammo_clusters__fireParamsId)
  v.ammo_clusters__explosionEvtId |> push(def_cluster.ammo_clusters__explosionEvtId)
  v.ammo_clusters__damageEffectPresetId |> push(def_cluster.ammo_clusters__damageEffectPresetId)
  v.ammo_clusters__reloadTimeMult |> push(def_cluster.ammo_clusters__reloadTimeMult)
  v.ammo_clusters__splashConstraints |> push(def_cluster.ammo_clusters__splashConstraints)
  v.ammo_clusters__shatterConstraints |> push(def_cluster.ammo_clusters__shatterConstraints)
  v.ammo_clusters__fireSplashConstraints |> push(def_cluster.ammo_clusters__fireSplashConstraints)
  v.ammo_clusters__entityMunition |> push("")
  v.ammo_clusters__slotsRange |> push(int2(v.ammo_slots__state |> length()))
  v.ammo_clusters__wreckageRange |> push(int2(v.ammo_stowage__wreckageIds |> length()))
  if length(def_cluster.ammo_stowage__wreckageIds) > 0
    for wreckage_id in def_cluster.ammo_stowage__wreckageIds
      v.ammo_stowage__wreckageIds |> push(wreckage_id)
    v.ammo_clusters__wreckageRange[cluster_id].y = length(v.ammo_stowage__wreckageIds)
  v.ammo_clusters__relatedPartsRange |> push(int2(v.ammo_stowage__relatedPartsIds |> length()))
  if length(def_cluster.ammo_stowage__relatedPartsIds) > 0
    for packed_rel_part_id in def_cluster.ammo_stowage__relatedPartsIds
      v.ammo_stowage__relatedPartsIds |> push(unpack_part_id(packed_rel_part_id))
    v.ammo_clusters__relatedPartsRange[cluster_id].y = length(v.ammo_stowage__relatedPartsIds)
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
                        var ammo_clusters__fireSplashConstraints : float3&;
                        add_wreckage : block<(id : int) : void>;
                        add_related_part : block<(id : PartId) : void>) : void
  blk |> read_flag(ammo_clusters__state, AmmoClusterState.AUTO_LOAD, "autoLoad")
  blk |> read_flag(ammo_clusters__state, AmmoClusterState.REVERSE_FILL, "reverseFill")
  blk |> read_flag(ammo_clusters__state, AmmoClusterState.FIRE_FATAL, "fatalFire")
  blk |> read_flag(ammo_clusters__state, AmmoClusterState.EXPLOSION_FATAL, "fatalExplosion")
  blk |> read_flag(ammo_clusters__state, AmmoClusterState.DESTROYED_DM_BLOCKS_SHOOT, "dstrElevatorDisablesShooting")
  blk |> read_flag(ammo_clusters__state, AmmoClusterState.RESTORE_AFTER_DEAD, "restoreAfterDead", true)
  ammo_clusters__reloadTimeMult = blk |> datablock_getReal("reloadTimeMult", ammo_clusters__reloadTimeMult)
  ammo_clusters__splashConstraints.x = blk |> datablock_getReal("splashRadiusConstraint", ammo_clusters__splashConstraints.x)
  ammo_clusters__splashConstraints.y = blk |> datablock_getReal("splashDamageConstraint", ammo_clusters__splashConstraints.y)
  ammo_clusters__splashConstraints.z = blk |> datablock_getReal("splashPenetrationConstraint", ammo_clusters__splashConstraints.z)
  ammo_clusters__shatterConstraints.x = blk |> datablock_getReal("shatterRadiusConstraint", ammo_clusters__shatterConstraints.x)
  ammo_clusters__shatterConstraints.y = blk |> datablock_getReal("shatterDamageConstraint", ammo_clusters__shatterConstraints.y)
  ammo_clusters__shatterConstraints.z = blk |> datablock_getReal("shatterPenetrationConstraint", ammo_clusters__shatterConstraints.z)
  ammo_clusters__fireSplashConstraints.x = blk |> datablock_getReal("fireSplashRadiusConstraint", ammo_clusters__fireSplashConstraints.x)
  ammo_clusters__fireSplashConstraints.y = blk |> datablock_getReal("fireSplashDamageConstraint", ammo_clusters__fireSplashConstraints.y)
  ammo_clusters__fireSplashConstraints.z = blk |> datablock_getReal("fireSplashPenetrationConstraint", ammo_clusters__fireSplashConstraints.z)

  let fire_params_preset = blk |> datablock_getStr("fireParamsPreset", "")
  if fire_params_preset != ""
    ammo_clusters__fireParamsId = dm_get_fire_params_id(fire_params_preset)
  if ammo_clusters__fireParamsId < 0
    ammo_clusters__fireParamsId = dm_get_fire_params_id("default")
  let fire_event_name = blk |> datablock_getStr("fireEvent", "")
  if fire_event_name != ""
    ammo_clusters__fireEvtId = *get_unit_fx(unit) |> getEventIdByName(fire_event_name)
  if ammo_clusters__fireEvtId < 0
    ammo_clusters__fireEvtId = *get_unit_fx(unit) |> getEventIdByName("ammo_fire")
  let explosion_event_name = blk |> datablock_getStr("explosionEvent", "")
  if explosion_event_name != ""
    ammo_clusters__explosionEvtId = *get_unit_fx(unit) |> getEventIdByName(explosion_event_name)
  if ammo_clusters__explosionEvtId < 0
    ammo_clusters__explosionEvtId = *get_unit_fx(unit) |> getEventIdByName("ammo_explosion")
  ammo_clusters__damageEffectPresetId = dm_read_overrided_preset(unit.visual.damageEffects, blk, "damageEffect", -1, unit.dmData)

  let wreckage_name_id = blk |> datablock_getNameId("wreckedPartId")
  let elevator_name_id = blk |> datablock_getNameId("elevator")
  let autoloader_name_id = blk |> datablock_getNameId("autoloader")
  blk |> datablock_for_each_param() <| $(i, t)
    let name_id = blk |> datablock_getParamNameId(uint(i))
    if name_id == wreckage_name_id && t == int(DataBlockParamType.TYPE_INT)
      let wreckage_id = blk |> datablock_getInt(i)
      if wreckage_id < 0
        logerr("unit {unit.props.fileName} : invalid wrecked part id {wreckage_id}")
        return
      add_wreckage |> invoke(wreckage_id)
    elif name_id == elevator_name_id && t == int(DataBlockParamType.TYPE_STRING)
      let elevator_part_name = blk |> datablock_getStr(i)
      let elevator_part_id = find_part_id(unit.dmData, elevator_part_name)
      if !elevator_part_id.valid
        
        
        logwarn("unit {unit.props.fileName} : ammo elevator part {elevator_part_name} not found, elevator is not added. This is not an error and will not break anything.")
        return
      add_related_part |> invoke(elevator_part_id)
      set_flag(ammo_clusters__state, AmmoClusterState.HAS_ELEVATOR_PARTS, true)
    elif name_id == autoloader_name_id && t == int(DataBlockParamType.TYPE_STRING)
      let autoloader_part_name = blk |> datablock_getStr(i)
      let autoloader_part_id = find_part_id(unit.dmData, autoloader_part_name)
      if !autoloader_part_id.valid
        logwarn("unit {unit.props.fileName} : ammo autoloader part {autoloader_part_name} not found, elevator is not added. This is not an error and will not break anything.")
        return
      add_related_part |> invoke(autoloader_part_id)
      set_flag(ammo_clusters__state, AmmoClusterState.HAS_AUTOLOADER_PARTS, true)
      set_flag(ammo_clusters__state, AmmoClusterState.DESTROYED_DM_BLOCKS_SHOOT, true)

  if get_flag(ammo_clusters__state, AmmoClusterState.HAS_AUTOLOADER_PARTS)
    blk |> read_flag(ammo_clusters__state, AmmoClusterState.DESTROYED_DM_BLOCKS_SHOOT, "dstrAutoLoadBlocksShooting")


[with_bundle(v)]
def load_cluster(blk : DataBlock&; var unit : Unit?;
                 stowage_id : int; cluster_id : int; var num_ammo : int&;

                 var v : tuple<
                   ammo_stowage__partIdRemap : IPoint4List;

                   ammo_clusters__typeAndStage : UInt16List;
                   ammo_clusters__state : UInt32List;
                   ammo_clusters__explosionEvtId : IntList;
                   ammo_clusters__fireEvtId : IntList;
                   ammo_clusters__fireParamsId : IntList;
                   ammo_clusters__damageEffectPresetId : IntList;
                   ammo_clusters__reloadTimeMult : FloatList;
                   ammo_clusters__splashConstraints : Point3List;
                   ammo_clusters__shatterConstraints : Point3List;
                   ammo_clusters__fireSplashConstraints : Point3List;
                   ammo_clusters__slotsRange : IPoint2List;
                   ammo_clusters__wreckageRange : IPoint2List;
                   ammo_clusters__relatedPartsRange : IPoint2List;
                   ammo_stowage__wreckageIds : IntList;
                   ammo_stowage__relatedPartsIds : PartIdList;

                   ammo_slots__state : UInt32List;
                   ammo_slots__ammoMaskAndType : UInt32List;
                   ammo_slots__partId : PartIdList;
                   ammo_slots__numAmmo : IPoint2List;
                   ammo_slots__node : AmmoStowageSlotCollAndGeomNodesList
                   >) : void
  if blk.blockCount == 0u || unit.visual == null
    return

  assert(v.ammo_clusters__wreckageRange[cluster_id].y == length(v.ammo_stowage__wreckageIds))
  assert(v.ammo_clusters__relatedPartsRange[cluster_id].y == length(v.ammo_stowage__relatedPartsIds))
  load_cluster_params(blk, unit,
    v.ammo_clusters__state[cluster_id],
    v.ammo_clusters__explosionEvtId[cluster_id],
    v.ammo_clusters__fireEvtId[cluster_id],
    v.ammo_clusters__fireParamsId[cluster_id],
    v.ammo_clusters__damageEffectPresetId[cluster_id],
    v.ammo_clusters__reloadTimeMult[cluster_id],
    v.ammo_clusters__splashConstraints[cluster_id],
    v.ammo_clusters__shatterConstraints[cluster_id],
    v.ammo_clusters__fireSplashConstraints[cluster_id],
    $(wreckage_id : int) { v.ammo_stowage__wreckageIds |> push(wreckage_id); },
    $(rel_part_id : PartId) { v.ammo_stowage__relatedPartsIds |> push(rel_part_id); }
  )
  v.ammo_clusters__wreckageRange[cluster_id].y = length(v.ammo_stowage__wreckageIds)
  v.ammo_clusters__relatedPartsRange[cluster_id].y = length(v.ammo_stowage__relatedPartsIds)

  var num_undistributed_slots = 0

  v.ammo_clusters__slotsRange[cluster_id].x = v.ammo_slots__state |> length()
  let damage_effect_name_id = blk |> datablock_getNameId("damageEffect")

  var slot_blks : array<uint>
  slot_blks |> reserve(int(blk.blockCount))
  for blk_i in 0u..blk.blockCount
    let slot_blk = blk |> datablock_get_block(blk_i)
    if slot_blk == null || slot_blk.blockNameId == damage_effect_name_id
      continue
    slot_blks |> push(blk_i)

  if get_flag(v.ammo_clusters__state[cluster_id], AmmoClusterState.REVERSE_FILL)
    reverse(slot_blks)

  let param_name_id_type = blk |> datablock_getNameId("type")
  for blk_i in slot_blks
    let slot_blk = blk |> datablock_get_block(blk_i)
    let slot_id = v.ammo_slots__state |> length()
    let part_id = find_part_id(unit.dmData, slot_blk.blockName)
    if !part_id.valid
      
      
      logwarn("unit {unit.props.fileName}: ammo slot part {slot_blk.blockName} not found, ammo slot is still added. This is not an error and will not break anything.")

    var ammo_class_mask = 0u
    for param_i in 0u..slot_blk.paramCount
      let name_id = *slot_blk |> datablock_getParamNameId(param_i)
      if name_id == param_name_id_type
        let type_name = *slot_blk |> datablock_getStr(int(param_i))
        if type_name == "inert"
          ammo_class_mask |= 1u << uint(AmmoStowageAmmoClass.INERT)
        if type_name == "explosive"
          ammo_class_mask |= 1u << uint(AmmoStowageAmmoClass.EXPLOSIVE)
    if ammo_class_mask == 0u
      ammo_class_mask = ~0u

    let num_ammo_max = slot_blk |> datablock_getInt("count", 0)
    v.ammo_slots__state |> push(uint(AmmoSlotState.ENABLED))
    v.ammo_slots__ammoMaskAndType |> push(ammo_class_mask << 8u)
    v.ammo_slots__partId |> push(part_id)
    v.ammo_slots__numAmmo |> push(int2(0, num_ammo_max))
    v.ammo_slots__node |> push_empty()

    if part_id.valid
      let remap_added = add_remap(v.ammo_stowage__partIdRemap, PartRemap(partId = part_id, stowageId = stowage_id, clusterId = cluster_id, slotId = slot_id))
      if !remap_added
        logerr("unit {unit.props.fileName}: part {slot_blk.blockName} is already used in another stowage!")

      let visual_node_name = slot_blk |> datablock_getStr("visual", "")
      if visual_node_name != ""
        *unit.visual |> dm_bind_visual_node(int(part_id.globalId), visual_node_name)

      if unit.collNodeTree != null
        let cnode = *unit.visual |> dm_get_collision_node_by_part_id(int(part_id.globalId))
        let geom_node_id = *unit.visual |> dm_get_geom_node_id_by_part_id(int(part_id.globalId))
        let node_wtm = *unit.collNodeTree |> get_node_wtm_rel_ptr(geom_node_id)
        v.ammo_slots__node[slot_id] := AmmoStowageSlotCollAndGeomNodes(cnode = cnode, nodeWtm = node_wtm)

    num_ammo -= num_ammo_max
    if num_ammo_max == 0
      num_undistributed_slots++

    assume cluster_state = v.ammo_clusters__state[cluster_id]
    assume cluster_type = get_ammo_cluster_type(cluster_id, v)
    let fire_or_explosion_fatal = get_flag(cluster_state, AmmoClusterState.FIRE_FATAL) || get_flag(cluster_state, AmmoClusterState.EXPLOSION_FATAL)
    if !(cluster_type == int(AmmoClusterType.CHARGES) || fire_or_explosion_fatal || v.ammo_slots__node[slot_id].cnode != null)
      logerr("unit {unit.props.fileName}: collision node for part {slot_blk.blockName} not found")
    if !(cluster_type == int(AmmoClusterType.CHARGES) || fire_or_explosion_fatal || v.ammo_slots__node[slot_id].nodeWtm != null)
      logerr("unit {unit.props.fileName}: geometry node for part {slot_blk.blockName} not found")
  v.ammo_clusters__slotsRange[cluster_id].y = v.ammo_slots__state |> length()

  if num_ammo > 0 && num_undistributed_slots > 0
    let num_ammo_per_slot = num_ammo / num_undistributed_slots
    let residue_ammo = num_ammo % num_undistributed_slots
    for i in v.ammo_clusters__slotsRange[cluster_id].x..v.ammo_clusters__slotsRange[cluster_id].y
      if v.ammo_slots__numAmmo[i].y == 0
        v.ammo_slots__numAmmo[i].y = i < residue_ammo ? num_ammo_per_slot + 1 : num_ammo_per_slot
    num_ammo = 0


def load_cluster_stage(cluster_blk : DataBlock&) : int
  var cluster_stage = int(AmmoClusterStage.SECOND_STAGE)
  if datablock_getBool(cluster_blk, "ammoLoadedInGun", false)
    cluster_stage = int(AmmoClusterStage.LOADED_IN_GUN)
  elif datablock_getBool(cluster_blk, "firstStage", false) || datablock_getBool(cluster_blk, "autoLoad", false)
    cluster_stage = int(AmmoClusterStage.FIRST_STAGE)
  elif datablock_getBool(cluster_blk, "noReload", false)
    cluster_stage = int(AmmoClusterStage.NO_RELOAD)
  return cluster_stage


def load_clusters_in_order(stowage_blk : DataBlock&; model_name : string; load_cluster : block<(cluster_blk : DataBlock; cluster_type : int; cluster_stage : int; idx : int) : void>)
  let shells_name_id = stowage_blk |> datablock_getNameId("shells")
  let charges_name_id = stowage_blk |> datablock_getNameId("charges")
  let gunpowder_mts_params_name_id = stowage_blk |> datablock_getNameId("gunpowderMassToSplashParams")

  var clusters : array<tuple<blk_i : uint; index : int; cluster_type : int; cluster_stage : int>>
  clusters |> reserve(int(stowage_blk.blockCount))
  var indexed = false

  
  for blk_i in 0u..stowage_blk.blockCount
    var cluster_blk = stowage_blk |> datablock_get_block(blk_i)
    if cluster_blk == null || cluster_blk.blockNameId == gunpowder_mts_params_name_id
      continue
    let idx = cluster_blk |> datablock_getInt("index", -1)
    var cluster_type = -1
    if cluster_blk.blockNameId == shells_name_id
      cluster_type = int(AmmoClusterType.SHELLS)
    elif cluster_blk.blockNameId == charges_name_id
      cluster_type = int(AmmoClusterType.CHARGES)
    else
      logerr("unit {model_name} : unknown cluster type {cluster_blk.getBlockName}, cluster will not be loaded")
      continue

    if length(clusters) == 0
      indexed = idx != -1
    elif indexed && idx == -1 || !indexed && idx != -1
      logerr("unit {model_name}: not all ammo clusters are indexed (must be all or none), all indices will be ignored")
      indexed = false

    let cluster_stage = load_cluster_stage(*cluster_blk)
    clusters |> push((blk_i, idx, cluster_type, cluster_stage))

  
  clusters |> sort() <| $(a, b)
    if a.cluster_stage != b.cluster_stage
      return a.cluster_stage < b.cluster_stage
    if a.index != b.index && indexed
      return a.index < b.index
    return a.blk_i > b.blk_i

  if indexed
    
    if length(clusters) > 0
      assert(int(AmmoClusterType.NUM_TYPES) == 2)
      var dbg_for_type : tuple<last_idx : int; max_fs_idx : int; min_non_fs_idx : int>[2]
      for dbg in dbg_for_type
        dbg.last_idx = -1
        dbg.max_fs_idx = -1
        dbg.min_non_fs_idx = -1
      for cluster in clusters
        assume dbg = dbg_for_type[cluster.cluster_type]
        if dbg.last_idx != cluster.index - 1
          logerr("unit {model_name}: ammo cluster indices must be unique for cluster type, contiguous and start from 0")
          break
        dbg.last_idx = cluster.index
      for cluster in clusters
        assume dbg = dbg_for_type[cluster.cluster_type]
        if cluster.cluster_stage < int(AmmoClusterStage.SECOND_STAGE) && (dbg.max_fs_idx == -1 || dbg.max_fs_idx < cluster.index)
          dbg.max_fs_idx = cluster.index
        if cluster.cluster_stage >= int(AmmoClusterStage.SECOND_STAGE) && (dbg.min_non_fs_idx == -1 || dbg.min_non_fs_idx > cluster.index)
          dbg.min_non_fs_idx = cluster.index
      for dbg in dbg_for_type
        if dbg.max_fs_idx >= dbg.min_non_fs_idx && dbg.max_fs_idx != -1 && dbg.min_non_fs_idx != -1
          logerr("unit {model_name}: ammo cluster index for firstStage/autoLoad cluster ({dbg.max_fs_idx}) is bigger " +
                 "than index for normal cluster ({dbg.min_non_fs_idx}), however ammo from firstStage/autoLoad cluster will be " +
                 "used first anyway because of its flags, this is misleading and must be fixed")

  for cluster in clusters
    let cluster_blk = stowage_blk |> datablock_get_block(cluster.blk_i)
    load_cluster |> invoke(*cluster_blk, cluster.cluster_type, cluster.cluster_stage, cluster.index)


struct LegacyLoadParams
  triggerGroupId : int
  stowageId : int
  shells_blk : DataBlock const?
  charges_blk : DataBlock const?
  numAmmo : int
  triggerIds : array<int>

[es, with_bundle(v)]
def ammo_stowage_load_es(evt : CmdInitComponent;
                         var unit__ref : UnitRef;
                         var v : tuple<
                           ammo_stowage__ammoState : uint;
                           ammo_stowage__dpAmmo : int3;
                           ammo_stowage__dpTorpedo : int3;
                           ammo_stowage__dpDepthCharge : int3;

                           ammo_stowage__combustionTime : float;
                           ammo_stowage__detonateProb : float;
                           ammo_stowage__fatalDetonatePortion : float2;
                           ammo_stowage__nonFatalDetonatePortion : float2;
                           ammo_stowage__explosiveProperties : ExplosiveProps;
                           ammo_stowage__fxEvAmmoFireId : int;
                           ammo_stowage__partIdRemap : IPoint4List;

                           ammo_stowages__state : UInt32List;
                           ammo_stowages__bulletsCartridge : IntList;
                           ammo_stowages__replenishmentStartEnd : Point2List;
                           ammo_stowages__replenishmentTime : Point2List;
                           ammo_stowages__floodedAmmoReloadMult : FloatList;
                           ammo_stowages__powderMassToSplash : AmmoStowageMassToSplashList;
                           ammo_stowages__clustersRange : IPoint2List;
                           ammo_stowages__weaponTriggersRange : IPoint2List;
                           ammo_stowage__weaponTriggers : IntList;

                           ammo_clusters__typeAndStage : UInt16List;
                           ammo_clusters__state : UInt32List;
                           ammo_clusters__fireEvtId : IntList;
                           ammo_clusters__fireParamsId : IntList;
                           ammo_clusters__explosionEvtId : IntList;
                           ammo_clusters__damageEffectPresetId : IntList;
                           ammo_clusters__reloadTimeMult : FloatList;
                           ammo_clusters__splashConstraints : Point3List;
                           ammo_clusters__shatterConstraints : Point3List;
                           ammo_clusters__fireSplashConstraints : Point3List;
                           ammo_clusters__entityMunition : StringList;
                           ammo_clusters__slotsRange : IPoint2List;
                           ammo_clusters__wreckageRange : IPoint2List;
                           ammo_clusters__relatedPartsRange : IPoint2List;
                           ammo_stowage__wreckageIds : IntList;
                           ammo_stowage__relatedPartsIds : PartIdList;

                           ammo_slots__state : UInt32List;
                           ammo_slots__ammoMaskAndType : UInt32List;
                           ammo_slots__partId : PartIdList;
                           ammo_slots__numAmmo : IPoint2List;
                           ammo_slots__node : AmmoStowageSlotCollAndGeomNodesList;

                           ammo_stowage__splashProperties : SplashProps
                           >)

  v.ammo_stowage__partIdRemap |> clear()
  v.ammo_stowage__wreckageIds |> clear()
  v.ammo_stowage__relatedPartsIds |> clear()
  v.ammo_stowage__weaponTriggers |> clear()
  v.ammo_stowages__state |> clear()
  v.ammo_stowages__bulletsCartridge |> clear()
  v.ammo_stowages__replenishmentStartEnd |> clear()
  v.ammo_stowages__replenishmentTime |> clear()
  v.ammo_stowages__floodedAmmoReloadMult |> clear()
  v.ammo_stowages__powderMassToSplash |> clear()
  v.ammo_stowages__clustersRange |> clear()
  v.ammo_stowages__weaponTriggersRange |> clear()
  v.ammo_clusters__typeAndStage |> clear()
  v.ammo_clusters__state |> clear()
  v.ammo_clusters__fireEvtId |> clear()
  v.ammo_clusters__fireParamsId |> clear()
  v.ammo_clusters__explosionEvtId |> clear()
  v.ammo_clusters__damageEffectPresetId |> clear()
  v.ammo_clusters__reloadTimeMult |> clear()
  v.ammo_clusters__splashConstraints |> clear()
  v.ammo_clusters__shatterConstraints |> clear()
  v.ammo_clusters__fireSplashConstraints |> clear()
  v.ammo_clusters__entityMunition |> clear()
  v.ammo_clusters__slotsRange |> clear()
  v.ammo_clusters__wreckageRange |> clear()
  v.ammo_clusters__relatedPartsRange |> clear()
  v.ammo_slots__state |> clear()
  v.ammo_slots__ammoMaskAndType |> clear()
  v.ammo_slots__partId |> clear()
  v.ammo_slots__numAmmo |> clear()
  v.ammo_slots__node |> clear()

  var unit = unit__ref.unit
  assert(unit != null)
  if !unit.isGroundModel
    return

  let model_name = "{unit.props.fileName}"
  assume blk = *evt.modelBlk

  v.ammo_stowage__dpAmmo = dm_find_part_kind("ammo")
  v.ammo_stowage__dpTorpedo = dm_find_part_kind("torpedo")
  v.ammo_stowage__dpDepthCharge = dm_find_part_kind("depth_charge")
  v.ammo_stowage__fxEvAmmoFireId = *get_unit_fx(unit) |> getEventIdByName("ammo_fire")

  blk |> datablock_get_block("ammo") <| $(ammo_blk)
    v.ammo_stowage__combustionTime = ammo_blk |> datablock_getReal("combustionTime", v.ammo_stowage__combustionTime)
    if v.ammo_stowage__combustionTime < 1.0f
      logerr("unit {model_name} : invalid ammo combustion time {v.ammo_stowage__combustionTime} < 1.0")
      v.ammo_stowage__combustionTime = 1.0f
    v.ammo_stowage__detonateProb = ammo_blk |> datablock_getReal("detonateProb", v.ammo_stowage__detonateProb)
    v.ammo_stowage__fatalDetonatePortion = ammo_blk |> datablock_getPoint2("detonatePortion", v.ammo_stowage__fatalDetonatePortion)
    v.ammo_stowage__nonFatalDetonatePortion = ammo_blk |> datablock_getPoint2("ammoStowageDetonatePortion",  get_wt_dm_params().ammoStowageDetonatePortion)
    explosive_props_load(v.ammo_stowage__explosiveProperties, ammo_blk, 1.f)
    splash_props_load(v.ammo_stowage__splashProperties, ammo_blk)

  if !unit.isHumanPlayer && !unit_change_data_has_any_bullets(unit)
    return

  var load_successful = false
  let weapon_controller = unit.weap

  datablock_get_block(unit.modBlk != null && *unit.modBlk |> datablock_block_exists("ammoStowages") ? *unit.modBlk : blk, "ammoStowages") <| $(stowages_blk)
    let def_flooded_ammo_reload_mult = stowages_blk |> datablock_getReal("floodedAmmoReloadTimeMult", get_game_params().floodedAmmoReloadTimeMult)
    stowages_blk |> read_flag(v.ammo_stowage__ammoState, AmmoState.ALLOW_USE_OF_FLOODED_AMMO, "allowUseOfFloodedAmmo", get_game_params().allowUseOfFloodedAmmo)
    stowages_blk |> read_flag(v.ammo_stowage__ammoState, AmmoState.ENABLE_PER_AMMO_TYPES, "enablePerAmmoTypesAndConstraints", false)

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
          var bullets_cartridge = 1
          if gun != null
            bullets_cartridge = gun.currentBulletSet.bulletsCartridge
          else
            bullets_cartridge = length(weapon.ammoParts)
          num_ammos_in_cartridge[trigger_id] = max(num_ammos_in_cartridge[trigger_id], bullets_cartridge)

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
        float2( 0.1f, 0.0f)
      )
      v.ammo_stowages__floodedAmmoReloadMult[stowage_id] = stowage_blk |> datablock_getReal("floodedAmmoReloadTimeMult", def_flooded_ammo_reload_mult)

      stowage_blk |> read_flag(v.ammo_stowages__state[stowage_id], AmmoStowageState.REMOVE_LOADED_AMMO, "removeLoadedAmmo", true)
      stowage_blk |> read_flag(v.ammo_stowages__state[stowage_id], AmmoStowageState.REPLENISH_ONLY_EMPTY, "replenishOnlyIfEmpty", false)

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
        v.ammo_stowages__powderMassToSplash[stowage_id] := get_wt_dm_params().gunpowderToSplash

      var num_ammo_in_storage = 0
      var num_ammo_in_cartridge = 1
      let replenish_by_cartridge = stowage_blk |> datablock_getBool("replenishByCartridge", false)
      v.ammo_stowages__weaponTriggersRange[stowage_id].x = v.ammo_stowage__weaponTriggers |> length()
      stowage_blk |> datablock_for_each_param("weaponTrigger") <| $(i, t)
        if t != int(DataBlockParamType.TYPE_STRING)
          return
        let trigger_name = stowage_blk |> datablock_getStr(i)
        let trigger_id = get_trigger_no_by_name(trigger_name)
        if trigger_id < 0
          logerr("unit {model_name} : unknown trigger name {trigger_name}")
          return
        v.ammo_stowage__weaponTriggers |> push(trigger_id)
        num_ammo_in_storage += num_ammos[trigger_id]
        if get_flag(v.ammo_stowages__state[stowage_id], AmmoStowageState.REMOVE_LOADED_AMMO)
          num_ammo_in_storage -= num_ammos_in_cartridge[trigger_id]
        if replenish_by_cartridge
          num_ammo_in_cartridge = max(num_ammo_in_cartridge, num_ammos_in_cartridge[trigger_id])
      v.ammo_stowages__weaponTriggersRange[stowage_id].y = v.ammo_stowage__weaponTriggers |> length()
      v.ammo_stowages__bulletsCartridge[stowage_id] = num_ammo_in_cartridge

      var num_ammo_for_cluster_type = fixed_array<int>(num_ammo_in_storage, num_ammo_in_storage)
      var has_charges = false

      var def_cluster <- make_default_cluster()
      load_cluster_params(stowage_blk, unit,
        def_cluster.ammo_clusters__state,
        def_cluster.ammo_clusters__explosionEvtId,
        def_cluster.ammo_clusters__fireEvtId,
        def_cluster.ammo_clusters__fireParamsId,
        def_cluster.ammo_clusters__damageEffectPresetId,
        def_cluster.ammo_clusters__reloadTimeMult,
        def_cluster.ammo_clusters__splashConstraints,
        def_cluster.ammo_clusters__shatterConstraints,
        def_cluster.ammo_clusters__fireSplashConstraints,
        $(wreckage_id) { def_cluster.ammo_stowage__wreckageIds |> push(wreckage_id); },
        $(rel_part_id) { def_cluster.ammo_stowage__relatedPartsIds |> push(rel_part_id.packed); }
      )

      v.ammo_stowages__clustersRange[stowage_id].x = v.ammo_clusters__state |> length()
      load_clusters_in_order(stowage_blk, model_name) <| $ [unused_argument(order_idx)] (cluster_blk, cluster_type, cluster_stage, order_idx)
        
        let cluster_id = push_cluster(cluster_type, cluster_stage, def_cluster) <| v
        if cluster_type == int(AmmoClusterType.CHARGES)
          has_charges = true

        
        load_cluster(cluster_blk, unit, stowage_id, cluster_id, num_ammo_for_cluster_type[cluster_type]) <| v
        v.ammo_clusters__entityMunition[cluster_id] := stowage_blk |> datablock_getStr("entityMunition", stowage_munition)

        if (get_flag(v.ammo_clusters__state[cluster_id], AmmoClusterState.AUTO_LOAD))
          set_flag(v.ammo_stowages__state[stowage_id], AmmoStowageState.HAS_AUTO_LOAD, true)

      v.ammo_stowages__clustersRange[stowage_id].y = v.ammo_clusters__state |> length()

    load_successful = true

  if load_successful
    return

  
  blk |> datablock_get_block("ammoLoadDistribution") <| $(load_distrib_blk)
    var load_params : LegacyLoadParams[3]
    var legacy_load_data : array<tuple<triggerGroupId : int; shellsName : string; chargesName : string>>
    legacy_load_data |> reserve(3)
    legacy_load_data |> push((int(WeaponTriggerGroups.TRIGGER_GROUP_PRIMARY), "primaryShells", "primaryCharges"))
    legacy_load_data |> push((int(WeaponTriggerGroups.TRIGGER_GROUP_SECONDARY), "secondaryShells", "secondaryCharges"))
    legacy_load_data |> push((int(WeaponTriggerGroups.TRIGGER_GROUP_SPECIAL_GUN), "special", ""))

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
        set_flag(v.ammo_stowages__state[params.stowageId], AmmoStowageState.REMOVE_LOADED_AMMO, remove_loaded_ammo)

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
      v.ammo_stowages__clustersRange[params.stowageId].x = v.ammo_clusters__state |> length()
      if params.shells_blk != null
        var num_shells = params.numAmmo
        let cluster_id = push_cluster(int(AmmoClusterType.SHELLS), load_cluster_stage(*params.shells_blk), def_cluster) <| v
        load_cluster(*params.shells_blk, unit, params.stowageId, cluster_id, num_shells) <| v
        if num_shells > 0
          logerr("unit {model_name} : not enough free slots to distribute residue shells, {num_shells} remaining")
      if params.charges_blk != null
        var num_charges = params.numAmmo
        let cluster_id = push_cluster(int(AmmoClusterType.CHARGES), load_cluster_stage(*params.charges_blk), def_cluster) <| v
        load_cluster(*params.charges_blk, unit, params.stowageId, cluster_id, num_charges) <| v
        if num_charges > 0
          logerr("unit {model_name} : not enough free slots to distribute residue charges, {num_charges} remaining")
      v.ammo_stowages__clustersRange[params.stowageId].y = v.ammo_clusters__state |> length()

    load_successful = true

  if load_successful
    return

  
  
  
  
  if v.ammo_stowage__dpAmmo.z >= 0
    let stowage_id = push_stowage() <| v
    v.ammo_stowages__clustersRange[stowage_id].x = v.ammo_clusters__state |> length()
    let cluster_id = push_cluster(int(AmmoClusterType.SHELLS), int(AmmoClusterStage.SECOND_STAGE), make_default_cluster()) <| v
    v.ammo_stowages__clustersRange[stowage_id].y = v.ammo_clusters__state |> length()

    v.ammo_clusters__slotsRange[cluster_id].x = v.ammo_slots__state |> length()
    for part_no in v.ammo_stowage__dpAmmo.x..(v.ammo_stowage__dpAmmo.y + 1)
      let part_id = dm_get_remap(*unit.visual, part_no)
      if part_id.valid
        v.ammo_slots__state |> push(uint(AmmoSlotState.ENABLED))
        v.ammo_slots__ammoMaskAndType |> push(~0u) 
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
      if turret.triggerGroupNo == int16(WeaponTriggerGroups.TRIGGER_GROUP_PRIMARY)
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
    load_successful = true


[es(after=ammo_stowage_load_es), with_bundle(v)]
def ammo_stowage_init_es(evt : CmdInitComponent;
                         eid : EntityId;
                         var unit__ref : UnitRef;
                         v : tuple<
                           ammo_stowage__ammoState : uint;
                           ammo_stowage__ammoTypeToMask : UInt32List -const;
                           ammo_stowage__ammoTypeRemap : IPoint4List -const;
                           ammo_stowage__weaponTriggers : IntList;
                           ammo_stowage__weaponsRemap : Int16List -const;
                           ammo_stowage__weaponsIds : IntList -const;
                           ammo_stowages__state : UInt32List -const;
                           ammo_stowages__clustersRange : IPoint2List;
                           ammo_stowages__weaponTriggersRange : IPoint2List;
                           ammo_clusters__typeAndStage : UInt16List;
                           ammo_clusters__ammoClassConstraints : UInt32List -const;
                           ammo_clusters__slotsRange : IPoint2List;
                           ammo_slots__ammoMaskAndType : UInt32List;

                           ammo_per_type_data__state : UInt32List -const;
                           ammo_per_type_data__numAmmoFs : IntList -const;
                           ammo_per_type_data__numAmmoFsSync : IntList -const
                           >)
  var unit = unit__ref.unit
  assert(unit != null)
  if v.ammo_stowages__clustersRange |> length() == 0
    return

  
  for stowage_state, clusters_range in v.ammo_stowages__state, v.ammo_stowages__clustersRange
    set_flag(stowage_state, AmmoStowageState.SEPARATE_LOADING, false)
    for cluster_id in clusters_range.x..clusters_range.y
      if get_ammo_cluster_type(cluster_id, v) == int(AmmoClusterType.CHARGES)
        set_flag(stowage_state, AmmoStowageState.SEPARATE_LOADING, true)

  
  v.ammo_stowage__ammoTypeRemap |> clear()
  v.ammo_stowage__ammoTypeRemap |> reserve(16)
  ammo_stowage_iter_all_ammo_types(unit.weap, v) <| $(info : WeaponAndAmmoInfo)
    if length(v.ammo_stowage__ammoTypeRemap) <= info.ammo_type
      v.ammo_stowage__ammoTypeRemap |> resize(info.ammo_type + 1)
    v.ammo_stowage__ammoTypeRemap[info.ammo_type] = int4(info.stowage_id, -1, -1, info.bullet_set_id)
  let ammo_type_count = length(v.ammo_stowage__ammoTypeRemap)
  let ammo_stowage_count = length(v.ammo_stowages__clustersRange)

  
  v.ammo_stowage__weaponsRemap |> resize(unit.weap.Weapons.weaponCount * 2 + 3)
  for remap in v.ammo_stowage__weaponsRemap
    remap = int16(-1)
  if true
    var cur_ammo_type = -1
    ammo_stowage_iter_all_weapons_and_bullet_sets(unit.weap, v) <| $(info : WeaponAndAmmoInfo)
      
      if info.ammo_type != cur_ammo_type
        if cur_ammo_type >= 0
          v.ammo_stowage__ammoTypeRemap[cur_ammo_type].z = length(v.ammo_stowage__weaponsIds)
          assert(cur_ammo_type + 1 == info.ammo_type)
        cur_ammo_type = info.ammo_type
        v.ammo_stowage__ammoTypeRemap[cur_ammo_type].y = length(v.ammo_stowage__weaponsIds)

      
      let glob_weapon_idx = info.first_weapon_idx
      let weapon_offset = glob_weapon_idx * 2 + 3
      if v.ammo_stowage__weaponsRemap[weapon_offset] == int16(-1)
        v.ammo_stowage__weaponsRemap[weapon_offset] = int16(info.stowage_id)
        v.ammo_stowage__weaponsRemap[weapon_offset + 1] = int16(length(v.ammo_stowage__weaponsRemap))
      v.ammo_stowage__weaponsRemap |> push(int16(info.ammo_type))
      v.ammo_stowage__weaponsRemap |> push(int16(info.ammo_type + info.stowage_id * ammo_type_count))

      
      var add_weapon = true
      for i in v.ammo_stowage__ammoTypeRemap[cur_ammo_type].y..length(v.ammo_stowage__weaponsIds)
        if v.ammo_stowage__weaponsIds[i] == glob_weapon_idx
          add_weapon = false
      if add_weapon
        v.ammo_stowage__weaponsIds |> push(glob_weapon_idx)
    if cur_ammo_type >= 0
      v.ammo_stowage__ammoTypeRemap[cur_ammo_type].z = length(v.ammo_stowage__weaponsIds)

  
  let per_ammo_data_size = ammo_stowage_count * ammo_type_count
  v.ammo_per_type_data__state |> resize(per_ammo_data_size)
  v.ammo_per_type_data__numAmmoFs |> resize(per_ammo_data_size)
  v.ammo_per_type_data__numAmmoFsSync |> resize(per_ammo_data_size)

  v.ammo_stowage__weaponsRemap[0] = int16(unit.weap.Weapons.weaponCount)
  v.ammo_stowage__weaponsRemap[1] = int16(ammo_type_count)
  v.ammo_stowage__weaponsRemap[2] = int16(per_ammo_data_size)

  
  let ammo_constrains_enabled = get_flag(v.ammo_stowage__ammoState, AmmoState.ENABLE_PER_AMMO_TYPES)
  v.ammo_stowage__ammoTypeToMask |> resize(ammo_type_count)
  for ammo_type, mask in iter_range(v.ammo_stowage__ammoTypeToMask), v.ammo_stowage__ammoTypeToMask
    mask = ~0u
    if !ammo_constrains_enabled
      continue
    ammo_stowage_iter_all_ammo_props(unit.weap, ammo_type, v) <| $ [unused_argument(fract)] (props; fract : float)
      if props.explosiveProps.mass > 0.f
        mask &= ~uint(AmmoStowageAmmoClass.INERT)
      if props.powderPortion > 0.f && props.ballisticsProps.mass > 0.f && props.splashDamageTypeId >= 0
        mask &= ~uint(AmmoStowageAmmoClass.INERT)

  
  v.ammo_clusters__ammoClassConstraints |> resize(length(v.ammo_clusters__slotsRange))
  for cluster_constraints, slots_range in v.ammo_clusters__ammoClassConstraints, v.ammo_clusters__slotsRange
    cluster_constraints = 0u
    for slot_id in slots_range.x..slots_range.y
      let mask = get_ammo_slot_class_mask(slot_id, v)
      cluster_constraints |= mask

  
  sendEventImmediate(eid, EventAmmoStowageSetup(
    netSyncIfRequired = false,
    initNum = true,
    isRefill = true))
