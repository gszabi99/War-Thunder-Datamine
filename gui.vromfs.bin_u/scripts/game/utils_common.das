module utils_common shared
require math
require Unit
require Weapon

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
def foreach_torpedo_gun(var weapon_triggers: auto implicit =const; blk: block<(var weapon: Weapon?#):void>)
  get_weapons_by_trigger_group(weapon_triggers, WeaponTriggerGroups TRIGGER_GROUP_TORPEDOES) <| $(var weapons: array<Weapon?>#)
    for w in weapons
      invoke(blk, w)

[generic]
def foreach_torpedo_gun(weapon_triggers: auto implicit =const; blk: block<(weapon: Weapon const? const#):void>)
  get_weapons_by_trigger_group(weapon_triggers, WeaponTriggerGroups TRIGGER_GROUP_TORPEDOES) <| $(weapons: array<Weapon const? const> const#)
    for w in weapons
      invoke(blk, w)

[generic]
def weapon_calcShootTm(weapon; owner_tm: float3x4; var out_tm: float3x4)
  weapon |> weapon_calcShootTm(owner_tm, false, -1, false, out_tm)
