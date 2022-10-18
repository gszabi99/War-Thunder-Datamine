let { isWeaponAux, getLastWeapon, getLastPrimaryWeapon } = require("%scripts/weaponry/weaponryInfo.nut")
let { getModificationByName } = require("%scripts/weaponry/modificationInfo.nut")

let function getUnitMassPerSecValue(unit, showLocalState = true, lastWeapon = null)
{
  let lastPrimaryWeaponName = showLocalState ? getLastPrimaryWeapon(unit) : ""
  let lastPrimaryWeapon = getModificationByName(unit, lastPrimaryWeaponName)
  let weapons = unit.getWeapons()

  local massPerSecValue = lastPrimaryWeapon?.mass_per_sec_diff ?? 0

  if (weapons.len() == 0)
    return massPerSecValue

  lastWeapon = lastWeapon ?? (showLocalState ? getLastWeapon(unit.name) : "")

  foreach(idx, weapon in weapons)
  {
    if (lastWeapon != weapon.name || isWeaponAux(weapon))
      continue
    if ("mass_per_sec" in weapon)
      return massPerSecValue + weapon.mass_per_sec
    break
  }

  if (lastWeapon == "")
    massPerSecValue += weapons[0]?.mass_per_sec ?? 0

  return massPerSecValue
}

let function getUnitWeaponPresetsCount(unit)
{
  return unit.getWeapons().filter(@(w) !isWeaponAux(w)).len()
}

return {
  getUnitMassPerSecValue
  getUnitWeaponPresetsCount
}