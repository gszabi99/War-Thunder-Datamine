from "%scripts/dagui_natives.nut" import is_era_available, shop_get_unit_exp, wp_get_cost, wp_get_cost_gold
from "%scripts/dagui_library.nut" import *
from "%scripts/gameModes/gameModeConsts.nut" import BATTLE_TYPES

let regexp2 = require("regexp2")
let { registerRespondent } = require("scriptRespondent")
let u = require("%sqStdLibs/helpers/u.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { get_ranks_blk } = require("blkGetters")
let { getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")
let { Cost } = require("%scripts/money.nut")
let { findUnitNoCase, getEsUnitType } = require("%scripts/unit/unitParams.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { hangar_get_loaded_unit_name, hangar_is_high_quality } = require("hangar")
let { isUnitBought } = require("%scripts/unit/unitShopInfo.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let reUnitLocNameSeparators = regexp2("".concat(@"[ \-_/.()", nbsp, "]"))















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

let getUnitTypeText = @(esUnitType) unitTypes.getByEsUnitType(esUnitType).name
let getUnitTypeByText = @(typeName, caseSensitive = false) unitTypes.getByName(typeName, caseSensitive).esUnitType

function get_unit_icon_by_unit(unit, iconName) {























  let esUnitType = getEsUnitType(unit)
  let t = unitTypes.getByEsUnitType(esUnitType)
  return $"{t.uiSkin}{iconName}.ddsx"
}

function image_for_air(air) {
  if (type(air) == "string")
    air = getAircraftByName(air)
  if (!air)
    return ""
  return air.customImage ?? get_unit_icon_by_unit(air, air.name)
}

function getUnitTypeTextByUnit(unit) {
  return getUnitTypeText(getEsUnitType(unit))
}

function getUnitCountry(unit) {
  return unit?.shopCountry ?? ""
}

function getUnitName(unit, shopName = true) {
  let unitId = u.isUnit(unit) ? unit.name
    : u.isString(unit) ? unit
    : ""
  let localized = loc($"{unitId}{shopName ? "_shop" : "_0"}", unitId)
  return shopName ? localized.replace(" ", nbsp) : localized
}

function getUnitCountryIcon(unit, needOperatorCountry = false, needOverride = true) {
  return getCountryIcon(needOperatorCountry ? unit.getOperatorCountry() : unit.shopCountry, needOverride)
}

function getUnitsNeedBuyToOpenNextInEra(countryId, unitType, rank, ranksBlk = null) {
  ranksBlk = ranksBlk || get_ranks_blk()
  let unitTypeText = getUnitTypeText(unitType)

  local rankToOpen = ranksBlk?.needBuyToOpenNextInEra[countryId][$"needBuyToOpenNextInEra{unitTypeText}{rank}"]
  if (rankToOpen != null)
    return rankToOpen

  rankToOpen = ranksBlk?.needBuyToOpenNextInEra[countryId][$"needBuyToOpenNextInEra{rank}"]
  if (rankToOpen != null)
    return rankToOpen

  return -1
}

function getRomanNumeralRankByUnitName (unitName) {
  let unit = unitName ? findUnitNoCase(unitName) : null
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

function getUnitRealCost(unit) {
  return Cost(unit.cost, unit.costGold)
}

function getUnitCost(unit) {
  return Cost(wp_get_cost(unit.name), wp_get_cost_gold(unit.name))
}

function getPrevUnit(unit) {
  if (unit?.isSlave())
    return getAircraftByName(unit.masterUnit)
  return "reqAir" in unit ? getAircraftByName(unit.reqAir) : null
}

function getNumberOfUnitsByYears(country, years) {
  let result = {}
  foreach (year in years) {
    result[$"year{year}"] <- 0
    result[$"beforeyear{year}"] <- 0
  }

  foreach (air in getAllUnits()) {
    if (getEsUnitType(air) != ES_UNIT_TYPE_AIRCRAFT)
      continue
    if (!("tags" in air) || !air.tags)
      continue;
    if (air.shopCountry != country)
      continue;

    local maxYear = 0
    foreach (year in years) {
      let parameter = $"year{year}";
      foreach (tag in air.tags)
        if (tag == parameter) {
          result[parameter]++
          maxYear = max(year, maxYear)
        }
    }
    if (maxYear)
      foreach (year in years)
        if (year > maxYear)
          result[$"beforeyear{year}"]++
  }
  return result;
}

function isLoadedModelHighQuality(def = true) {
  if (hangar_get_loaded_unit_name() == "")
    return def
  return hangar_is_high_quality()
}

local __types_for_coutries = null 
function getUnitTypesInCountries() {
  if (__types_for_coutries)
    return __types_for_coutries

  let defaultCountryData = {}
  foreach (unitType in unitTypes.types)
    defaultCountryData[unitType.esUnitType] <- false

  __types_for_coutries = {}
  foreach (country in shopCountriesList)
    __types_for_coutries[country] <- clone defaultCountryData

  foreach (unit in getAllUnits()) {
    if (!unit.unitType.isAvailable())
      continue
    let esUnitType = unit.unitType.esUnitType
    let countryData = __types_for_coutries?[getUnitCountry(unit)]
    if (countryData != null && !countryData?[esUnitType])
      countryData[esUnitType] <- isUnitBought(unit)
  }

  return __types_for_coutries
}

function getBattleTypeByUnit(unit) {
  let esUnitType = getEsUnitType(unit)
  if (esUnitType == ES_UNIT_TYPE_TANK)
    return BATTLE_TYPES.TANK
  if (esUnitType == ES_UNIT_TYPE_SHIP || esUnitType == ES_UNIT_TYPE_BOAT)
    return BATTLE_TYPES.SHIP
  return BATTLE_TYPES.AIR
}

function getCountryByAircraftName(airName) { 
  let unit = getAircraftByName(airName)
  let country = getUnitCountry(unit)
  let cPrefixLen = "country_".len()
  return country.len() > cPrefixLen ? country.slice(cPrefixLen) : ""
}

registerRespondent("getCountryByAircraftName", @(airName) getCountryByAircraftName(airName))

return {
  bit_unit_status,
  getUnitTypeTextByUnit, getUnitName,
  getUnitCountry, getUnitCountryIcon, getUnitsNeedBuyToOpenNextInEra,
  getRomanNumeralRankByUnitName
  getUnitReqExp
  getUnitExp
  getUnitRealCost
  getUnitCost
  getPrevUnit
  get_unit_icon_by_unit
  getUnitTypeText
  getUnitTypeByText
  image_for_air
  getNumberOfUnitsByYears
  isLoadedModelHighQuality
  getUnitTypesInCountries
  getBattleTypeByUnit
  getCountryByAircraftName
  reUnitLocNameSeparators
}