//-file:plus-string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { get_game_params } = require("gameparams")
let { getSavedBullets } = require("%scripts/weaponry/savedWeaponry.nut")

let AMMO = {
  PRIMARY      = 0, //bullets, modifications
  MODIFICATION = 0,
  SECONDARY    = 1,  //weapon presets
  WEAPON       = 1
}

let function getAmmoAmount(unit, ammoName, ammoType) {
  if (!ammoName)
    return 0
  if (ammoType == AMMO.MODIFICATION)
    return ::shop_is_modification_purchased(unit.name, ammoName)
  return  ::shop_is_weapon_purchased(unit.name, ammoName)
}

let function getAmmoCost(unit, ammoName, ammoType) {
  let res = ::Cost()
  if (ammoType == AMMO.MODIFICATION) {
    res.wp = max(::wp_get_modification_cost(unit.name, ammoName), 0)
    res.gold = max(::wp_get_modification_cost_gold(unit.name, ammoName), 0)
  }
  else {
    res.wp = ::wp_get_cost2(unit.name, ammoName)
    res.gold = ::wp_get_cost_gold2(unit.name, ammoName)
  }
  return  res
}

let function getAmmoMaxAmount(unit, ammoName, ammoType) {
  if (ammoType == AMMO.MODIFICATION) {
    local res = ::wp_get_modification_max_count(unit.name, ammoName)
    //for unlimited ammo code return also 1, same as for other modifications
    if (res == 1 && getAmmoCost(unit, ammoName, ammoType).isZero())
      res = 0 //unlimited
    return res
  }
  return  ::wp_get_weapon_max_count(unit.name, ammoName)
}

let function getAmmoMaxAmountInSession(unit, ammoName, ammoType) {
  if (ammoType == AMMO.MODIFICATION)
    return ::shop_get_modification_baseval(unit.name, ammoName)
  return  ::shop_get_weapon_baseval(unit.name, ammoName)
}

let function isAmmoFree(unit, ammoName, ammoType) {
  return getAmmoCost(unit, ammoName, ammoType) <= ::zero_money
}

let function getAmmoWarningMinimum(ammoType, unit, maxAmount) {
  if (unit.unitType == unitTypes.SHIP || unit.unitType == unitTypes.BOAT)
    return max(1, maxAmount / 10)
  let gp = get_game_params()
  if (gp == null)
    return 1
  return (ammoType == AMMO.MODIFICATION)
        ? gp.weaponsWarningMinimumPrimary
        : gp.weaponsWarningMinimumSecondary
}

let function getAmmoAmountData(unit, ammoName, ammoType) {
  let res = { text = "", warning = false, amount = 0, buyAmount = 0,
               airName = unit.name, ammoName = ammoName, ammoType = ammoType }

  res.amount = getAmmoAmount(unit, ammoName, ammoType)
  let maxAmount = getAmmoMaxAmount(unit, ammoName, ammoType)
  let text = ::getAmountAndMaxAmountText(res.amount, maxAmount)
  if (text == "")
    return res

  let fullText = "(" + text + ")"
  let amountWarning = getAmmoWarningMinimum(ammoType, unit, maxAmount)
  if (res.amount < amountWarning) {
    res.text = "<color=@weaponWarning>" + fullText + "</color>"
    res.warning = true
    res.buyAmount = amountWarning - res.amount
    return res
  }
  res.text = fullText
  return res
}

let function checkAmmoAmount(unit, ammoName, ammoType) {
  let data = getAmmoAmountData(unit, ammoName, ammoType)
  if (data.warning)
    return data.amount ? UNIT_WEAPONS_WARNING : UNIT_WEAPONS_ZERO

  return UNIT_WEAPONS_READY
}

let function getUnitNotReadyAmmoList(unit, lastWeapon, readyStatus = UNIT_WEAPONS_WARNING) {
  let res = []
  let addAmmoData = function(ammoData) {
    if (readyStatus == UNIT_WEAPONS_READY
        || (readyStatus == UNIT_WEAPONS_ZERO && !ammoData.amount)
        || (readyStatus == UNIT_WEAPONS_WARNING && ammoData.warning))
      res.append(ammoData)
  }

  addAmmoData(getAmmoAmountData(unit, lastWeapon, AMMO.WEAPON))

  for (local i = 0; i < unit.unitType.bulletSetsQuantity; i++) {
    let modifName = getSavedBullets(unit.name, i)
    if (modifName != "")
      addAmmoData(getAmmoAmountData(unit, modifName, AMMO.MODIFICATION))
  }

  return res
}

return {
  AMMO
  getUnitNotReadyAmmoList
  getAmmoAmount
  getAmmoMaxAmount
  getAmmoMaxAmountInSession
  getAmmoCost
  isAmmoFree
  getAmmoWarningMinimum
  getAmmoAmountData
  checkAmmoAmount
}