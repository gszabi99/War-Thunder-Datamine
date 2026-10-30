from "%scripts/slotbar/slotbarState.nut" import getSelSlotsData
from "%scripts/crew/crewInfo.nut" import isCrewLockedByPrevBattle, getCrewByAir
from "%scripts/weaponry/ammoInfo.nut" import getAmmoCost, getUnitNotReadyAmmoList
from "%scripts/weaponry/weaponryInfo.nut" import getLastWeapon
from "%scripts/slotbar/crewsList.nut" import getCrewsList
from "%scripts/crew/crew.nut" import getCrewUnit
from "%scripts/unit/unitWeaponryInfo.nut" import isShipWithoutPurshasedTorpedoes
from "%scripts/dagui_natives.nut" import wp_get_repair_cost
from "%scripts/dagui_library.nut" import *
from "%scripts/weaponry/weaponryConsts.nut" import UNIT_WEAPONS_WARNING





function getBrokenAirsInfo(countries, respawn, checkAvailFunc = null) {
  let res = {
          canFlyout = true
          canFlyoutIfRepair = true
          canFlyoutIfRefill = true
          weaponWarning = false
          repairCost = 0
          broken_countries = [] 
          unreadyAmmoList = []
          unreadyAmmoCost = 0
          unreadyAmmoCostGold = 0

          haveRespawns = respawn
          randomCountry = countries.len() > 1

          shipsWithoutPurshasedTorpedoes = []
        }

  local readyWeaponsFound = false
  let unreadyAmmo = []
  if (!respawn) {
    let selList = getSelSlotsData().units
    foreach (c, airName in selList)
      if ((isInArray(c, countries)) && airName != "") {
        let repairCost = wp_get_repair_cost(airName)
        if (repairCost > 0) {
          res.repairCost += repairCost
          res.broken_countries.append({ country = c, airs = [airName] })
          res.canFlyout = false
        }
        let air = getAircraftByName(airName)
        let crew = air && getCrewByAir(air)
        if (!crew || isCrewLockedByPrevBattle(crew))
          res.canFlyoutIfRepair = false

        let ammoList = getUnitNotReadyAmmoList(
          air, getLastWeapon(air.name), UNIT_WEAPONS_WARNING)
        if (ammoList.len())
          unreadyAmmo.extend(ammoList)
        else
          readyWeaponsFound = true

        if (isShipWithoutPurshasedTorpedoes(air))
          res.shipsWithoutPurshasedTorpedoes.append(air)
      }
  }
  else
    foreach (cc in getCrewsList())
      if (isInArray(cc.country, countries)) {
        local have_repaired_in_country = false
        local have_unlocked_in_country = false
        let brokenList = []
        foreach (crew in cc.crews) {
          let unit = getCrewUnit(crew)
          if (!unit || (checkAvailFunc && !checkAvailFunc(unit)))
            continue

          let repairCost = wp_get_repair_cost(unit.name)
          if (repairCost > 0) {
            brokenList.append(unit.name)
            res.repairCost += repairCost
          }
          else
            have_repaired_in_country = true

          if (!isCrewLockedByPrevBattle(crew))
            have_unlocked_in_country = true

          let ammoList = getUnitNotReadyAmmoList(
            unit, getLastWeapon(unit.name), UNIT_WEAPONS_WARNING)
          if (ammoList.len())
            unreadyAmmo.extend(ammoList)
          else
            readyWeaponsFound = true

          if (isShipWithoutPurshasedTorpedoes(unit))
            res.shipsWithoutPurshasedTorpedoes.append(unit)
        }
        res.canFlyout = res.canFlyout && have_repaired_in_country
        res.canFlyoutIfRepair = res.canFlyoutIfRepair && have_unlocked_in_country
        if (brokenList.len() > 0)
          res.broken_countries.append({ country = cc.country, airs = brokenList })
      }
  res.canFlyout = res.canFlyout && res.canFlyoutIfRepair

  let allUnitsMustBeReady = countries.len() > 1
  if (unreadyAmmo.len() && (allUnitsMustBeReady || (!allUnitsMustBeReady && !readyWeaponsFound))) {
    res.weaponWarning = true
    res.canFlyoutIfRefill = res.canFlyout

    res.canFlyout = false

    res.unreadyAmmoList = unreadyAmmo
    foreach (ammo in unreadyAmmo) {
      let cost = getAmmoCost(getAircraftByName(ammo.airName), ammo.ammoName, ammo.ammoType)
      res.unreadyAmmoCost     += ammo.buyAmount * cost.wp
      res.unreadyAmmoCostGold += ammo.buyAmount * cost.gold
    }
  }
  return res
}

return freeze({
  getBrokenAirsInfo
})
