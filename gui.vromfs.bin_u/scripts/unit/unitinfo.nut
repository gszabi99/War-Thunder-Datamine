from "%scripts/dagui_natives.nut" import is_era_available, shop_get_unit_exp, wp_get_repair_cost, wp_get_cost, wp_get_cost_gold
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")
let { blkOptFromPath } = require("%sqstd/datablock.nut")
let { getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")
let { get_ranks_blk } = require("blkGetters")
let { isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")
let { Cost } = require("%scripts/money.nut")

enum bit_unit_status {
  locked      = 1
  canResearch = 2
  inResearch  = 4
  researched  = 8
  canBuy      = 16
  owned       = 32
  mounted     = 64
  disabled    = 128
  broken      = 256
  inRent      = 512
  empty       = 1024
}

function getEsUnitType(unit) {
  return unit?.esUnitType ?? ES_UNIT_TYPE_INVALID
}

function getUnitTypeTextByUnit(unit) {
  return ::getUnitTypeText(getEsUnitType(unit))
}

function getUnitCountry(unit) {
  return unit?.shopCountry ?? ""
}

function isUnitsEraUnlocked(unit) {
  return is_era_available(getUnitCountry(unit), unit?.rank ?? -1, getEsUnitType(unit))
}

function getUnitName(unit, shopName = true) {
  let unitId = u.isUnit(unit) ? unit.name
    : u.isString(unit) ? unit
    : ""
  let localized = loc($"{unitId}{shopName ? "_shop" : "_0"}", unitId)
  return shopName ? localized.replace(" ", nbsp) : localized
}

function getUnitCountryIcon(unit, needOperatorCountry = false) {
  return getCountryIcon(needOperatorCountry ? unit.getOperatorCountry() : unit.shopCountry)
}

function getUnitsNeedBuyToOpenNextInEra(countryId, unitType, rank, ranksBlk = null) {
  ranksBlk = ranksBlk || get_ranks_blk()
  let unitTypeText = ::getUnitTypeText(unitType)

  local rankToOpen = ranksBlk?.needBuyToOpenNextInEra[countryId][$"needBuyToOpenNextInEra{unitTypeText}{rank}"]
  if (rankToOpen != null)
    return rankToOpen

  rankToOpen = ranksBlk?.needBuyToOpenNextInEra[countryId][$"needBuyToOpenNextInEra{rank}"]
  if (rankToOpen != null)
    return rankToOpen

  return -1
}

function isUnitGroup(unit) {
  return unit && "airsGroup" in unit
}

function isGroupPart(unit) {
  return unit && unit.group != null
}

let isRequireUnlockForUnit = @(unit) unit?.reqUnlock != null && !isUnlockOpened(unit.reqUnlock)

let unitSensorsCache = {}

function isUnitWithSensorType(unit, sensorType) {
  if (!unit)
    return false
  let unitName = unit.name
  if (unitName in unitSensorsCache)
    return unitSensorsCache[unitName]?[sensorType] ?? false

  unitSensorsCache[unitName] <- {}
  let unitBlk = ::get_full_unit_blk(unit.name)
  if (unitBlk?.sensors)
    foreach (sensor in (unitBlk.sensors % "sensor")) {
      let sensType = blkOptFromPath(sensor?.blk)?.type ?? ""
      if (sensType != "")
        unitSensorsCache[unitName][sensType] <- true
    }
  return unitSensorsCache[unitName]?[sensorType] ?? false
}

let isUnitWithRadar = @(unit) isUnitWithSensorType(unit, "radar")

let isUnitWithRwr = @(unit) isUnitWithSensorType(unit, "rwr")

function getRomanNumeralRankByUnitName (unitName) {
  let unit = unitName ? ::findUnitNoCase(unitName) : null
  return unit ? get_roman_numeral(unit.rank) : null
}

function getUnitReqExp(unit) {
  if (!("reqExp" in unit))
    return 0
  return unit.reqExp
}

function getUnitExp(unit) {
  return shop_get_unit_exp(unit.name)
}

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

function getUnitRealCost(unit) {
  return Cost(unit.cost, unit.costGold)
}

function getUnitCost(unit) {
  return Cost(wp_get_cost(unit.name), wp_get_cost_gold(unit.name))
}

return {
  bit_unit_status,
  getEsUnitType, getUnitTypeTextByUnit, isUnitsEraUnlocked, getUnitName,//next
  getUnitCountry, getUnitCountryIcon, getUnitsNeedBuyToOpenNextInEra,
  isUnitGroup, isGroupPart,
  isRequireUnlockForUnit,
  isUnitWithRadar,
  isUnitWithRwr
  getRomanNumeralRankByUnitName
  getUnitReqExp
  getUnitExp
  isUnitBroken
  isUnitDescriptionValid
  getUnitRealCost
  getUnitCost
}