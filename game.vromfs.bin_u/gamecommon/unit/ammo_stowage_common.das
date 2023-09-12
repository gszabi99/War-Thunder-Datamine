module ammo_stowage_common shared

require daslib/lpipe
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


[with_bundle(v)]
def public apply_ammo_slot_effect(unit : Unit?; stowage_id : int; cluster_id : int; slot_id : int; effect : AmmoSlotEffectType;
                                  v : tuple<
                                    ammo_stowages__weaponTriggersRange : IPoint2List;
                                    ammo_stowage__weaponTriggers : IntList;
                                    ammo_slots__state : UInt32List- const;
                                    ammo_slots__numAmmo : IPoint2List;
                                    ammo_stowage__ammoLost : int-const;
                                    ammo_stowages__numAmmo : IPoint3List- const;
                                    ammo_stowages__numAmmoFirstStage : IPoint3List- const;
                                    ammo_clusters__state : UInt32List
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
              maxVal=bullet_set.bullet[0].count
            ]])

  if effect == AmmoSlotEffectType DESTROYED
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
    v.ammo_stowage__ammoLost += v.ammo_slots__numAmmo[slot_id].x

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
                                          ammo_stowage__weaponTriggers : IntList;
                                          ammo_slots__state : UInt32List- const;
                                          ammo_slots__numAmmo : IPoint2List;
                                          ammo_stowage__ammoLost : int-const;
                                          ammo_stowages__numAmmo : IPoint3List- const;
                                          ammo_stowages__numAmmoFirstStage : IPoint3List- const;
                                          ammo_clusters__state : UInt32List
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

