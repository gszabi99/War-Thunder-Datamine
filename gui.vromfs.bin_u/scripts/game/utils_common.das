module utils_common shared
require math
require Unit
require Weapon
require WTCamera

[generic]
def get_unit(uid; blk:block<(unit:Unit?):void>)
  let unit = get_unit(uid)
  if unit != null && !unit.isDelayed
    blk |> invoke(unit)

[generic]
def get_unit_with_target(uid; blk:block<(unit,target:Unit?):void>)
  get_unit(uid) <| $(unit)
    let target = get_selectedTarget(unit)
    if target != null && target.isAlive && unit.weap != null
      blk |> invoke(unit, target)

[generic]
def get_unit_for_edit(uid; blk:block<(var unit:Unit?):void>)
  var unit = get_unit(uid)
  if unit != null && !unit.isDelayed
    blk |> invoke(unit)

[generic]
def get_unit_for_edit_with_target(uid; blk:block<(var unit:Unit?;target:Unit?):void>)
  get_unit_for_edit(uid) <| $(var unit)
    let target = get_selectedTarget(unit)
    if target != null && target.isAlive && unit.weap != null
      blk |> invoke(unit, target)

[generic]
def get_unit_target(uid; blk:block<(target:Unit const?):void>)
  var target: Unit const?
  get_unit(uid) <| $(unit) { target = get_selectedTarget(unit); }

  if target == null
    target = get_flight_control_mode()?.target

  if target != null
    blk |> invoke(target)

[generic]
def foreach_weapon(var weapon_triggers: auto implicit =const; blk: block<(var weapon: Weapon?#):void>)
  get_weapons_for_edit(weapon_triggers) <| $(var weapons: array<Weapon?>#)
    for w in weapons
      invoke(blk, w)

[generic]
def foreach_weapon(weapon_triggers: auto implicit =const; blk: block<(weapon: Weapon const? const#):void>)
  get_weapons(weapon_triggers) <| $(weapons: array<Weapon const? const> const#)
    for w in weapons
      invoke(blk, w)

[generic]
def foreach_weapon(var weapon_triggers: auto implicit =const; groups; blk: block<(var weapon: Weapon?#):void>)
  for group in groups
    get_weapons_by_trigger_group_for_edit(weapon_triggers, group) <| $(var weapons: array<Weapon?>#)
      for w in weapons
        invoke(blk, w)

[generic]
def foreach_weapon(weapon_triggers: auto implicit =const; groups; blk: block<(weapon: Weapon const? const#):void>)
  for group in groups
    get_weapons_by_trigger_group(weapon_triggers, group) <| $(weapons: array<Weapon const? const> const#)
      for w in weapons
        invoke(blk, w)

[generic]
def foreach_torpedo_gun(var weapon_triggers: auto implicit =const; blk: block<(var weapon: Weapon?#):void>)
  get_weapons_by_trigger_group_for_edit(weapon_triggers, WeaponTriggerGroups TRIGGER_GROUP_TORPEDOES) <| $(var weapons: array<Weapon?>#)
    for w in weapons
      invoke(blk, w)

[generic]
def foreach_torpedo_gun(weapon_triggers: auto implicit =const; blk: block<(weapon: Weapon const? const#):void>)
  get_weapons_by_trigger_group(weapon_triggers, WeaponTriggerGroups TRIGGER_GROUP_TORPEDOES) <| $(weapons: array<Weapon const? const> const#)
    for w in weapons
      invoke(blk, w)

[generic]
def foreach_rocket_gun(var weapon_triggers: auto implicit =const; blk: block<(var weapon: Weapon?#):void>)
  get_weapons_by_trigger_group_for_edit(weapon_triggers, WeaponTriggerGroups TRIGGER_GROUP_ROCKETS) <| $(var weapons: array<Weapon?>#)
    for w in weapons
      invoke(blk, w)

[generic]
def foreach_rocket_gun(weapon_triggers: auto implicit =const; blk: block<(weapon: Weapon const? const#):void>)
  get_weapons_by_trigger_group(weapon_triggers, WeaponTriggerGroups TRIGGER_GROUP_ROCKETS) <| $(weapons: array<Weapon const? const> const#)
    for w in weapons
      invoke(blk, w)

[generic]
def foreach_primary_gun(var weapon_triggers: auto implicit =const; blk: block<(var weapon: Weapon?#):void>)
  get_weapons_by_trigger_group_for_edit(weapon_triggers, WeaponTriggerGroups TRIGGER_GROUP_PRIMARY) <| $(var weapons: array<Weapon?>#)
    for w in weapons
      invoke(blk, w)

[generic]
def foreach_primary_gun(weapon_triggers: auto implicit =const; blk: block<(weapon: Weapon const? const#):void>)
  get_weapons_by_trigger_group(weapon_triggers, WeaponTriggerGroups TRIGGER_GROUP_PRIMARY) <| $(weapons: array<Weapon const? const> const#)
    for w in weapons
      invoke(blk, w)

[generic]
def weapon_calcShootTm(weapon; owner_tm: float3x4; var out_tm: float3x4)
  weapon |> weapon_calcShootTm(owner_tm, false, -1, false, out_tm)
