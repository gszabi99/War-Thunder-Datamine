module utils_common shared
require math
require Unit
require Weapon
require WTCamera
require DagorDataBlock

[generic]
def get_flag(state : uint; flag)
  return (state & uint(flag)) == uint(flag)

def test_any_flags(state : uint; flags : uint)
  return (state & flags) != 0u

def test_all_flags(state : uint; flags : uint)
  return (state & flags) == flags

[generic]
def set_flag(var state : uint&; flag; present : bool)
  if present
    state |= uint(flag)
  else
    state &= ~uint(flag)

[generic]
def read_flag(blk : DataBlock&; var state : uint&; flag; key : string; default_val : bool)
  set_flag(state, flag, blk |> datablock_getBool(key, default_val))

[generic]
def read_flag(blk : DataBlock&; var state : uint&; flag; key : string)
  read_flag(blk, state, flag, key, get_flag(state, flag))

def get_unit_target(unit : Unit?) : Unit?
  if unit == null
    return null
  var target = get_selectedTarget(unit)
  if target != null && target.isAlive && unit.weap != null
    return target
  return null

[generic]
def foreach_weapon(var weapon_triggers : auto implicit ==const; blk : block<(var weapon : Weapon?#) : void>)
  get_weapons_for_edit(weapon_triggers) <| $(var weapons : array<Weapon?>#)
    for w in weapons
      invoke(blk, w)

[generic]
def foreach_weapon(weapon_triggers : auto implicit ==const; blk : block<(weapon : Weapon const? const#) : void>)
  get_weapons(weapon_triggers) <| $(weapons : array<Weapon const? const> const#)
    for w in weapons
      invoke(blk, w)

[generic]
def foreach_weapon(var weapon_triggers : auto implicit ==const; groups; blk : block<(var weapon : Weapon?#) : void>)
  for group in groups
    get_weapons_by_trigger_group_for_edit(weapon_triggers, group) <| $(var weapons : array<Weapon?>#)
      for w in weapons
        invoke(blk, w)

[generic]
def foreach_weapon(weapon_triggers : auto implicit ==const; groups; blk : block<(weapon : Weapon const? const#) : void>)
  for group in groups
    get_weapons_by_trigger_group(weapon_triggers, group) <| $(weapons : array<Weapon const? const> const#)
      for w in weapons
        invoke(blk, w)

[generic]
def foreach_weapon_by_trigger_group(var weapon_triggers : auto implicit ==const; group; blk : block<(var weapon : Weapon?#) : void>)
  get_weapons_by_trigger_group_for_edit(weapon_triggers, group) <| $(var weapons : array<Weapon?>#)
    for w in weapons
      invoke(blk, w)

[generic]
def foreach_weapon_by_trigger_group(weapon_triggers : auto implicit ==const; group; blk : block<(weapon : Weapon const? const#) : void>)
  get_weapons_by_trigger_group(weapon_triggers, group) <| $(weapons : array<Weapon const? const> const#)
    for w in weapons
      invoke(blk, w)

[generic]
def foreach_torpedo_gun(var weapon_triggers : auto implicit ==const; blk : block<(var weapon : Weapon?#) : void>)
  get_weapons_by_trigger_group_for_edit(weapon_triggers, WeaponTriggerGroups.TRIGGER_GROUP_TORPEDOES) <| $(var weapons : array<Weapon?>#)
    for w in weapons
      invoke(blk, w)

[generic]
def foreach_torpedo_gun(weapon_triggers : auto implicit ==const; blk : block<(weapon : Weapon const? const#) : void>)
  get_weapons_by_trigger_group(weapon_triggers, WeaponTriggerGroups.TRIGGER_GROUP_TORPEDOES) <| $(weapons : array<Weapon const? const> const#)
    for w in weapons
      invoke(blk, w)

[generic]
def foreach_rocket_gun(var weapon_triggers : auto implicit ==const; blk : block<(var weapon : Weapon?#) : void>)
  get_weapons_by_trigger_group_for_edit(weapon_triggers, WeaponTriggerGroups.TRIGGER_GROUP_ROCKETS) <| $(var weapons : array<Weapon?>#)
    for w in weapons
      invoke(blk, w)

[generic]
def foreach_rocket_gun(weapon_triggers : auto implicit ==const; blk : block<(weapon : Weapon const? const#) : void>)
  get_weapons_by_trigger_group(weapon_triggers, WeaponTriggerGroups.TRIGGER_GROUP_ROCKETS) <| $(weapons : array<Weapon const? const> const#)
    for w in weapons
      invoke(blk, w)

[generic]
def foreach_primary_gun(var weapon_triggers : auto implicit ==const; blk : block<(var weapon : Weapon?#) : void>)
  get_weapons_by_trigger_group_for_edit(weapon_triggers, WeaponTriggerGroups.TRIGGER_GROUP_PRIMARY) <| $(var weapons : array<Weapon?>#)
    for w in weapons
      invoke(blk, w)

[generic]
def foreach_primary_gun(weapon_triggers : auto implicit ==const; blk : block<(weapon : Weapon const? const#) : void>)
  get_weapons_by_trigger_group(weapon_triggers, WeaponTriggerGroups.TRIGGER_GROUP_PRIMARY) <| $(weapons : array<Weapon const? const> const#)
    for w in weapons
      invoke(blk, w)

[generic]
def weapon_calcShootTm(weapon; owner_tm : float3x4; var out_tm : float3x4&)
  weapon |> weapon_calcShootTm(owner_tm, false, -1, false, out_tm)
