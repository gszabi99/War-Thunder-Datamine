module ammo_stowage_common shared

require daslib/lpipe
require ecs
require dm
require app
require net
require Unit
require UnitFx
require Weapon
require WTDamageModel
require DagorMath
require DagorDataBlock
require GeomNodeTree
require AmmoStowage
require DagorSystem
require %game.utils.component_bundle_macro
require %game.utils.utils_common
require %game.unit.ammo_stowage_events


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


struct BulletSetState
  gun : Gun?
  bulletSetId : int
  minVal : int
  maxVal : int

def get_bullets_count(bss : BulletSetState&)
  return bss.gun.properties.bulletSets[bss.bulletSetId].bulletsCount

def set_bullets_count(var bss : BulletSetState&; count : int)
  bss.gun.properties.bulletSets[bss.bulletSetId].bulletsCount = count


// for separate loading, find a cluster, associated with this one
// in case no such cluster is found, return -1
[with_bundle(v)]
def public find_associated_cluster(stowage_id : int; cluster_id : int;
                                   v : tuple<
                                     ammo_stowages__clustersRange : IPoint2List;
                                     ammo_clusters__type : IntList;
                                     ammo_clusters__slotsRange : IPoint2List
                                   >) : int
  let clusters_range = v.ammo_stowages__clustersRange[stowage_id];
  var candidate = -1;
  let cluster_type = v.ammo_clusters__type[cluster_id];
  let slots_cnt = v.ammo_clusters__slotsRange[cluster_id].y - v.ammo_clusters__slotsRange[cluster_id].x;
  for i in clusters_range.x..clusters_range.y
    if cluster_id != i && v.ammo_clusters__type[i] != cluster_type
      candidate = i;
      if slots_cnt == v.ammo_clusters__slotsRange[i].y - v.ammo_clusters__slotsRange[i].x
        return i;
  return candidate;


[with_bundle(v)]
def public apply_ammo_slot_effect(unit : Unit?; stowage_id : int; cluster_id : int; slot_id : int; effect : AmmoSlotEffectType;
                                  v : tuple<
                                    ammo_stowages__weaponTriggersRange : IPoint2List;
                                    ammo_stowages__numAmmo : IPoint3List- const;
                                    ammo_stowages__numAmmoFirstStage : IPoint3List- const;
                                    ammo_stowage__weaponTriggers : IntList;
                                    ammo_slots__state : UInt32List- const;
                                    ammo_slots__numAmmo : IPoint2List- const;
                                    ammo_stowage__ammoLost : int-const;
                                    ammo_stowages__state : UInt32List- const;
                                    ammo_stowages__clustersRange : IPoint2List;
                                    ammo_clusters__type : IntList;
                                    ammo_clusters__state : UInt32List;
                                    ammo_clusters__slotsRange : IPoint2List
                                  >) : void
  // resolve combined effects
  if effect == AmmoSlotEffectType FLOODED_AND_DESTROYED
    apply_ammo_slot_effect(unit, stowage_id, cluster_id, slot_id, AmmoSlotEffectType FLOODED) <| v
    apply_ammo_slot_effect(unit, stowage_id, cluster_id, slot_id, AmmoSlotEffectType DESTROYED) <| v
    return
  if effect == AmmoSlotEffectType DRIED_AND_RESTORED
    apply_ammo_slot_effect(unit, stowage_id, cluster_id, slot_id, AmmoSlotEffectType RESTORED) <| v
    apply_ammo_slot_effect(unit, stowage_id, cluster_id, slot_id, AmmoSlotEffectType DRIED) <| v
    return

  // skip if effect is a no-op
  if effect == AmmoSlotEffectType RESTORED && get_flag(v.ammo_slots__state[slot_id], AmmoSlotState ENABLED)
    return
  if effect == AmmoSlotEffectType DESTROYED && !get_flag(v.ammo_slots__state[slot_id], AmmoSlotState ENABLED)
    return
  if effect == AmmoSlotEffectType FLOODED && get_flag(v.ammo_slots__state[slot_id], AmmoSlotState FLOODED)
    return
  if effect == AmmoSlotEffectType DRIED && !get_flag(v.ammo_slots__state[slot_id], AmmoSlotState FLOODED)
    return

  var need_start_reload = get_flag(v.ammo_clusters__state[cluster_id], AmmoClusterState AMMO_LOADED_IN_GUN)
  if need_start_reload
    let slot_range = v.ammo_clusters__slotsRange[cluster_id]
    for i in slot_range.x..slot_range.y
      if v.ammo_slots__numAmmo[i].x > 0 && i != slot_id
        need_start_reload = false

  let weapon_controller = unit.weap
  let triggers_range = v.ammo_stowages__weaponTriggersRange[stowage_id]
  var bullet_set_states : array<BulletSetState>
  if effect == AmmoSlotEffectType DESTROYED
    bullet_set_states |> reserve(4)

  if effect == AmmoSlotEffectType RESTORED || effect == AmmoSlotEffectType DESTROYED
    for trigger_id_idx in triggers_range.x..triggers_range.y
      let trigger_id = v.ammo_stowage__weaponTriggers[trigger_id_idx]
      for weapon in weapon_controller.Weapons |> get_weapons_by_trigger(trigger_id)
        if weapon == null
          continue
        var gun = weapon |> as_gun()
        if gun == null
          continue

        if need_start_reload
          send_net_event(unit.eid, [[EventAmmoStowageForceReloadGun triggerId=trigger_id]])
        for bullet_set, bullet_set_id in gun.properties.bulletSets, 0..length(gun.properties.bulletSets)
          if effect == AmmoSlotEffectType RESTORED
            if length(bullet_set.bullet) > 0
              bullet_set.bulletsCount = bullet_set.bullet[0].count - int(bullet_set.bulletsBorn)
          elif effect == AmmoSlotEffectType DESTROYED
            let extracted = int(gun.chosenBulletType) == bullet_set_id || int(gun.nextBulletType) == bullet_set_id
            bullet_set_states |> push([[BulletSetState
              gun=gun,
              bulletSetId=bullet_set_id,
              minVal=extracted ? 1 : 0,
              maxVal=bullet_set.initialBulletsCount
            ]])

  if effect == AmmoSlotEffectType DESTROYED
    let destroyed_count = v.ammo_slots__numAmmo[slot_id].x
    v.ammo_stowage__ammoLost += destroyed_count
    v.ammo_slots__numAmmo[slot_id].x = 0
    var undistributed = destroyed_count
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

    // subtract destroyed count from stowage ammo count
    if get_flag(v.ammo_clusters__state[cluster_id], AmmoClusterState FIRST_STAGE) || get_flag(v.ammo_clusters__state[cluster_id], AmmoClusterState AUTO_LOAD)
      v.ammo_stowages__numAmmoFirstStage[stowage_id].x -= destroyed_count
    v.ammo_stowages__numAmmo[stowage_id].x -= destroyed_count
    // hack: for separate loading also subtract same amount from associated cluster slots,
    // so it will not subtract them twice
    let associated_cluster_id = find_associated_cluster(stowage_id, cluster_id) <| v
    if associated_cluster_id != -1
      let slots_range = v.ammo_clusters__slotsRange[associated_cluster_id];
      var to_subtract = destroyed_count
      for i in slots_range.x..slots_range.y
        let count_before = v.ammo_slots__numAmmo[i].x
        v.ammo_slots__numAmmo[i].x = max(0, v.ammo_slots__numAmmo[i].x - to_subtract)
        to_subtract -= count_before - v.ammo_slots__numAmmo[i].x
    // mark for sync
    set_flag(v.ammo_stowages__state[stowage_id], AmmoStowageState NEED_SYNC_BULLET_COUNT, true)

  if effect == AmmoSlotEffectType DESTROYED
    set_flag(v.ammo_slots__state[slot_id], AmmoSlotState ENABLED, false)
  if effect == AmmoSlotEffectType RESTORED
    set_flag(v.ammo_slots__state[slot_id], AmmoSlotState ENABLED, true)
  if effect == AmmoSlotEffectType FLOODED
    set_flag(v.ammo_slots__state[slot_id], AmmoSlotState FLOODED, true)
  if effect == AmmoSlotEffectType DRIED
    set_flag(v.ammo_slots__state[slot_id], AmmoSlotState FLOODED, false)


[with_bundle(v)]
def public apply_slot_effect_by_part_id(unit : Unit?; part_id : PartId; effect : AmmoSlotEffectType;
                                        v : tuple<
                                          ammo_stowage__partIdRemap : IPoint4List;
                                          ammo_stowages__weaponTriggersRange : IPoint2List;
                                          ammo_stowages__numAmmo : IPoint3List- const;
                                          ammo_stowages__numAmmoFirstStage : IPoint3List- const;
                                          ammo_stowage__weaponTriggers : IntList;
                                          ammo_slots__state : UInt32List- const;
                                          ammo_slots__numAmmo : IPoint2List- const;
                                          ammo_stowage__ammoLost : int-const;
                                          ammo_stowages__state : UInt32List- const;
                                          ammo_stowages__clustersRange : IPoint2List;
                                          ammo_clusters__type : IntList;
                                          ammo_clusters__state : UInt32List;
                                          ammo_clusters__slotsRange : IPoint2List
                                        >) : void
  let remap = get_remap(v.ammo_stowage__partIdRemap, part_id)
  if remap.partId.valid
    apply_ammo_slot_effect(unit, remap.stowageId, remap.clusterId, remap.slotId, effect) <| v


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

