from "%scripts/dagui_natives.nut" import get_unit_elite_status, is_default_aircraft, shop_unit_research_status, is_era_available, wp_get_repair_cost
from "%scripts/dagui_library.nut" import *

let { getUnitReqExp, getUnitExp, getUnitCountry, getPrevUnit } = require("%scripts/unit/unitInfo.nut")
let { getEsUnitType } = require("%scripts/unit/unitParams.nut")
let { canBuyUnit, isUnitBought, isUnitGift } = require("%scripts/unit/unitShopInfo.nut")
let { isUnitSpecial } = require("%appGlobals/ranks_common_shared.nut")
let { isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")
let { isUnitAvailableForGM } = require("%scripts/unit/unitInSlotbarStatus.nut")
let { approversUnitToPreviewLiveResource } = require("%scripts/customization/skinUtils.nut")

function isUnitDefault(unit) {
  if (!("name" in unit))
    return false
  return is_default_aircraft(unit.name)
}

function isUnitMaxExp(unit) { 
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


function isUnitEliteByStatus(status) {
  return status > ES_UNIT_ELITE_STAGE1
}

function isUnitElite(unit) {
  let unitName = unit?.name
  return unitName ? isUnitEliteByStatus(get_unit_elite_status(unitName)) : false
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
    return true 
  let desc = unit ? loc($"encyclopedia/{unit.name}/desc", "") : ""
  return desc != "" && desc != loc("encyclopedia/no_unit_description")
}





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

function isPrevUnitBought(unit) {
  let prevUnit = getPrevUnit(unit)
  if (!prevUnit || isUnitBought(prevUnit))
    return true
  return false
}

function isTestFlightAvailable(unit, skipUnitCheck = false) {
  if (!isUnitAvailableForGM(unit, GM_TEST_FLIGHT) || unit.isSlave())
    return false

  if (unit.isUsable()
      || skipUnitCheck
      || canResearchUnit(unit)
      || isUnitGift(unit)
      || isUnitResearched(unit)
      || isUnitSpecial(unit)
      || approversUnitToPreviewLiveResource.get() == unit
      || unit?.isSquadronVehicle?())
    return true

  return false
}

return {
  canBuyNotResearched
  isUnitEliteByStatus
  isUnitElite
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
  isPrevUnitBought
  isTestFlightAvailable
}