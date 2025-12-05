module vehicle_turrets_common shared

require ecs
require Weapon


def find_turret_weapon(weap : WeaponController const?; trigger_group : int; fn : block<(weapon : Weapon const?; i : int) : bool>)
  for i, turret in iter_range(weap.turret), weap.turret
    if trigger_group >= 0 && int(turret.triggerGroupNo) != trigger_group
      continue
    let weapon = get_weapon(weap.Weapons, int(turret.triggerNo), int(turret.weaponIndex))
    if weapon == null
      continue
    let gun = as_gun(weapon)
    if gun == null
      continue
    if invoke(fn, weapon, i)
      return true
  return false

def find_turret_weapon(weap : WeaponController const?; trigger_group : int; fn : block<(weapon : Weapon const?) : bool>)
  find_turret_weapon(weap, trigger_group) <| $ [unused_argument(i)] (weapon, i)
    return invoke(fn, weapon)

def iterate_turret_weapons(weap : WeaponController const?; trigger_group : int; fn : block<(weapon : Weapon const?; i : int) : void>)
  find_turret_weapon(weap, trigger_group) <| $(weapon, i)
    invoke(fn, weapon, i)
    return false

def iterate_turret_weapons(weap : WeaponController const?; trigger_group : int; fn : block<(weapon : Weapon const?) : void>)
  iterate_turret_weapons(weap, trigger_group) <| $ [unused_argument(i)] (weapon, i)
    invoke(fn, weapon)

def iterate_turret_weapons_by_idxs(weap : WeaponController const?; weaponIdxs : IntList; fn : block<(weapon : Weapon const?; i : int) : void>)
  for i, idx in iter_range(weaponIdxs), weaponIdxs
    let weapon = get_weapon(weap.Weapons, idx)
    if weapon == null
      continue
    invoke(fn, weapon, i)

def is_turret_dangerous(weapon : Weapon const?)
  let gun = as_gun(weapon)
  if gun == null
    return false
  if gun.isInoperable || gun.currentBulletSet.bulletsCount == 0
    return false
  let hasMoreCartridges = gun.currentBulletSet.bulletsCartridge > 1
  let isNowEmpty = gun.currentBulletSet.bulletsCount == 0
  if gun.isInoperable || (!hasMoreCartridges && isNowEmpty)
    return false
  return true
