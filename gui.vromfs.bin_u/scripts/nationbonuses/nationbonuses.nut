from "%scripts/dagui_library.nut" import *

let { getTopUnitsInfo } = require("chard")
let { addListenersWithoutEnv, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings } = require("%scripts/clientState/localProfile.nut")
let DataBlock = require("DataBlock")
let { convertBlk } = require("%sqstd/datablock.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { getShopVisibleCountries } = require("%scripts/shop/shopCountriesList.nut")
let g_listener_priority = require("%scripts/g_listener_priority.nut")

local unitsWithBonusData = null
local nationBonusMarkState = null
local bonusesData = null

function getBonusesCountryData(country) {
  if (bonusesData == null)
    bonusesData = getTopUnitsInfo()
  return bonusesData[country]
}

function getUnitsWithNationBonuses() {
  let units = []
  let maxRanks = {}
  let countries = getShopVisibleCountries()
  if(unitsWithBonusData != null)
    return unitsWithBonusData

  foreach (unit in getAllUnits()) {
    if (!unit.isVisibleInShop() || unit.isSquadronVehicle())
      continue

    let { unitType, shopCountry, rank, esUnitType } = unit

    if (!(shopCountry in maxRanks))
      maxRanks[shopCountry] <- {}
    let currentMaxRank = maxRanks[shopCountry]?[unitType.armyId] ?? 0
    maxRanks[shopCountry][unitType.armyId] <- max(currentMaxRank, rank)

    if(!::isUnitInResearch(unit) || unit.isRecentlyReleased())
      continue

    let countryBonusesData = getBonusesCountryData(shopCountry)
    let battlesRemainCount = countryBonusesData?.battlesRemain[esUnitType] ?? 0
    if (battlesRemainCount == 0 || !(countryBonusesData?.unitTypeWithBonuses.contains(esUnitType) ?? false))
      continue

    units.append({
      unit
      countryIndex = countries.indexof(shopCountry)
      visualSortOrder = unitType.visualSortOrder
      battlesRemainCount
    })
  }

  unitsWithBonusData = {
    units = units.sort(@(v1, v2) v1.countryIndex <=> v2.countryIndex || v1.visualSortOrder <=> v2.visualSortOrder)
    maxRanks
  }
  return unitsWithBonusData
}

function loadNationBonusMarksState() {
  nationBonusMarkState = convertBlk(loadLocalAccountSettings("nationBonusMarkState", DataBlock()))
}

function saveNationBonusMarksState() {
  saveLocalAccountSettings("nationBonusMarkState", nationBonusMarkState)
}

function getNationBonusMarkState(country, armyId) {
  if(nationBonusMarkState == null)
    loadNationBonusMarksState()
  return nationBonusMarkState?[country][armyId] ?? true
}

function setNationBonusMarkState(country, armyId, state) {
  if(nationBonusMarkState == null)
    loadNationBonusMarksState()
  if (!(country in nationBonusMarkState))
    nationBonusMarkState[country] <- {}
  nationBonusMarkState[country][armyId] <- state
  saveNationBonusMarksState()
  broadcastEvent("NationBonusMarkStateChange")
}

function invalidateCachedData() {
  unitsWithBonusData = null
  bonusesData = null
}

addListenersWithoutEnv({
  UnitResearch = @(_p) invalidateCachedData()
  BattleEnded = @(_p) invalidateCachedData()
}, g_listener_priority.CONFIG_VALIDATION)

return {
  getUnitsWithNationBonuses
  getNationBonusMarkState
  setNationBonusMarkState
}