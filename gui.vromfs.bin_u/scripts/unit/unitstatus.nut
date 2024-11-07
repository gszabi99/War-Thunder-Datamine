from "%scripts/dagui_natives.nut" import clan_get_exp, get_unit_elite_status, is_default_aircraft, shop_unit_research_status, is_era_available, wp_get_repair_cost
from "%scripts/dagui_library.nut" import *
let { bit_unit_status, getUnitReqExp, getUnitExp, getUnitCountry, getEsUnitType, getPrevUnit
} = require("%scripts/unit/unitInfo.nut")
let { canBuyUnit, isUnitBought } = require("%scripts/unit/unitShopInfo.nut")
let { isInFlight } = require("gameplayBinding")
let { getCrewByAir } = require("%scripts/crew/crewInfo.nut")
let { isUnitSpecial } = require("%appGlobals/ranks_common_shared.nut")
let { isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")

let isUnitInSlotbar = @(unit) getCrewByAir(unit) != null

function isUnitMaxExp(unit) { //temporary while not exist correct status between in_research and canBuy
  return isUnitSpecial(unit) || (getUnitReqExp(unit) <= getUnitExp(unit))
}

function canResearchUnit(unit) {
  let isInShop = unit?.isInShop
  if (isInShop == null) {
    debugTableData(unit)
    assert(false, "not existing isInShop param")
    return false
  }

  if (!isInShop)
    return false

  if (unit.reqUnlock && !isUnlockOpened(unit.reqUnlock))
    return false

  let status = shop_unit_research_status(unit.name)
  return (0 != (status & (ES_ITEM_STATUS_IN_RESEARCH | ES_ITEM_STATUS_CAN_RESEARCH))) && !isUnitMaxExp(unit)
}

let canBuyNotResearched = @(unit) unit.isVisibleInShop()
  && canResearchUnit(unit)
  && unit.isSquadronVehicle()
  && !unit.getOpenCost().isZero()

function getBitStatus(unit, params = {}) {
  let isLocalState = params?.isLocalState ?? true
  let forceNotInResearch  = params?.forceNotInResearch ?? false
  let shopResearchMode    = params?.shopResearchMode ?? false
  let isSquadronResearchMode  = params?.isSquadronResearchMode ?? false

  let isMounted      = isUnitInSlotbar(unit)
  let isOwn          = unit.isBought()
  let isSquadVehicle = unit.isSquadronVehicle()
  let researched     = unit.isResearched()

  let isVehicleInResearch = unit.isInResearch() && !forceNotInResearch
  let canResearch         = canResearchUnit(unit)

  let unitExpGranted      = unit.getExp()
  let diffExp = isSquadVehicle
    ? min(clan_get_exp(), getUnitReqExp(unit) - unitExpGranted)
    : (params?.diffExp ?? 0)
  let isLockedSquadronVehicle = isSquadVehicle && !::is_in_clan() && diffExp <= 0

  local bitStatus = 0
  if (!isLocalState || isInFlight())
    bitStatus = bit_unit_status.owned
  else if (unit.isBroken())
    bitStatus = bit_unit_status.broken
  else if (isMounted)
    bitStatus = bit_unit_status.mounted
  else if (isOwn)
    bitStatus = bit_unit_status.owned
  else if (canBuyUnit(unit) || ::canBuyUnitOnline(unit) || ::canBuyUnitOnMarketplace(unit))
    bitStatus = bit_unit_status.canBuy
  else if (isLockedSquadronVehicle && (!unit.unitType.canSpendGold() || !canBuyNotResearched(unit)))
    bitStatus = bit_unit_status.locked
  else if (researched)
    bitStatus = bit_unit_status.researched
  else if (isVehicleInResearch)
    bitStatus = bit_unit_status.inResearch
  else if (canResearch)
    bitStatus = bit_unit_status.canResearch
  else if (unit.isRented())
    bitStatus = bit_unit_status.inRent
  else if (unit.isCrossPromo)
    return bitStatus
  else
    bitStatus = bit_unit_status.locked

  if ((shopResearchMode
      && (isSquadVehicle || !(bitStatus &
        (bit_unit_status.locked
          | bit_unit_status.canBuy
          | bit_unit_status.inResearch
          | bit_unit_status.canResearch))))
    || (isSquadronResearchMode && !isSquadVehicle)) {
    bitStatus = bit_unit_status.disabled
  }

  return bitStatus
}

function isUnitEliteByStatus(status) {
  return status > ES_UNIT_ELITE_STAGE1
}

function isUnitElite(unit) {
  let unitName = unit?.name
  return unitName ? isUnitEliteByStatus(get_unit_elite_status(unitName)) : false
}

function isUnitDefault(unit) {
  if (!("name" in unit))
    return false
  return is_default_aircraft(unit.name)
}

function isUnitLocked(unit) {
  let status = shop_unit_research_status(unit.name)
  return 0 != (status & ES_ITEM_STATUS_LOCKED)
}

function isUnitInResearch(unit) {
  if (!unit)
    return false

  if (!("name" in unit))
    return false

  local status = shop_unit_research_status(unit.name)
  return ((status & ES_ITEM_STATUS_IN_RESEARCH) != 0) && !isUnitMaxExp(unit)
}

function isUnitsEraUnlocked(unit) {
  return is_era_available(getUnitCountry(unit), unit?.rank ?? -1, getEsUnitType(unit))
}

function isUnitGroup(unit) {
  return unit && "airsGroup" in unit
}

function isGroupPart(unit) {
  return unit && unit.group != null
}

let isRequireUnlockForUnit = @(unit) unit?.reqUnlock != null && !isUnlockOpened(unit.reqUnlock)

let getUnitRepairCost = @(unit) ("name" in unit) ? wp_get_repair_cost(unit.name) : 0

let isUnitBroken = @(unit) getUnitRepairCost(unit) > 0

function isUnitDescriptionValid(unit) {
  if (!hasFeature("UnitInfo"))
    return false
  if (hasFeature("WikiUnitInfo"))
    return true // Because there is link to wiki.
  let desc = unit ? loc($"encyclopedia/{unit.name}/desc", "") : ""
  return desc != "" && desc != loc("encyclopedia/no_unit_description")
}

/**
 * Returns true if unit can be installed in slotbar,
 * unit can be decorated with decals, etc...
 */
function isUnitUsable(unit) {
  return unit ? unit.isUsable() : false
}

function isUnitFeatureLocked(unit) {
  return unit.reqFeature != null && !hasFeature(unit.reqFeature)
}

function isUnitResearched(unit) {
  if (isUnitBought(unit) || canBuyUnit(unit))
    return true

  let status = shop_unit_research_status(unit.name)
  return (0 != (status & ES_ITEM_STATUS_RESEARCHED))
}

function isPrevUnitResearched(unit) {
  let prevUnit = getPrevUnit(unit)
  if (!prevUnit || isUnitResearched(prevUnit))
    return true
  return false
}

return {
  canBuyNotResearched
  getBitStatus
  isUnitEliteByStatus
  isUnitElite
  isUnitInSlotbar
  isUnitDefault
  isUnitLocked
  isUnitMaxExp
  canResearchUnit
  isUnitInResearch
  isUnitsEraUnlocked
  isUnitGroup
  isGroupPart
  isRequireUnlockForUnit
  isUnitBroken
  isUnitDescriptionValid
  isUnitUsable
  isUnitFeatureLocked
  isUnitResearched
  isPrevUnitResearched
}