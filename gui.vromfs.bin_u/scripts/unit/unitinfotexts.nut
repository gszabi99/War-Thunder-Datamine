from "%scripts/dagui_natives.nut" import wp_get_cost_gold, wp_get_cost
from "%scripts/dagui_library.nut" import *

let { isUnitSpecial } = require("%appGlobals/ranks_common_shared.nut")
let { round, fabs } = require("math")
let { utf8ToLower } = require("%sqstd/string.nut")
let { getEsUnitType, bit_unit_status, getUnitCountry, getUnitsNeedBuyToOpenNextInEra, getUnitName,
  getPrevUnit
} = require("%scripts/unit/unitInfo.nut")
let { get_wpcost_blk } = require("blkGetters")
let { isUnitDefault, isUnitsEraUnlocked, isPrevUnitResearched, isUnitResearched, isPrevUnitBought,
  isRequireUnlockForUnit, canResearchUnit, isUnitInResearch
} = require("%scripts/unit/unitStatus.nut")
let { canBuyUnit, isUnitGift, isUnitBought } = require("%scripts/unit/unitShopInfo.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { getUnitRequireUnlockText } = require("%scripts/unlocks/unlocksViewModule.nut")
let { getProfileInfo } = require("%scripts/user/userInfoStats.nut")
let { basicUnitRoles, getRoleText } = require("%scripts/unit/unitInfoRoles.nut")

let unitRoleByTag = {
  type_light_fighter    = "light_fighter",
  type_medium_fighter   = "medium_fighter",
  type_heavy_fighter    = "heavy_fighter",
  type_naval_fighter    = "naval_fighter",
  type_jet_fighter      = "jet_fighter",
  type_light_bomber     = "light_bomber",
  type_medium_bomber    = "medium_bomber",
  type_heavy_bomber     = "heavy_bomber",
  type_naval_bomber     = "naval_bomber",
  type_jet_bomber       = "jet_bomber",
  type_dive_bomber      = "dive_bomber",
  type_common_bomber    = "common_bomber", //to use as a second type: "Light fighter / Bomber"
  type_common_assault   = "common_assault",
  type_strike_fighter   = "strike_fighter",
  type_attack_helicopter  = "attack_helicopter",
  type_utility_helicopter = "utility_helicopter",
  //tanks:
  type_tank             = "tank" //used in profile stats
  type_light_tank       = "light_tank",
  type_medium_tank      = "medium_tank",
  type_heavy_tank       = "heavy_tank",
  type_tank_destroyer   = "tank_destroyer",
  type_spaa             = "spaa",
  //battle vehicles:
  type_lbv              = "lbv",
  type_mbv              = "mbv",
  type_hbv              = "hbv",
  //ships:
  type_ship             = "ship",
  type_boat             = "boat",
  type_heavy_boat       = "heavy_boat",
  type_barge            = "barge",
  type_destroyer        = "destroyer",
  type_frigate          = "frigate",
  type_light_cruiser    = "light_cruiser",
  type_cruiser          = "cruiser",
  type_heavy_cruiser    = "heavy_cruiser",
  type_battlecruiser    = "battlecruiser",
  type_battleship       = "battleship",
  type_submarine        = "submarine",
  //basic types
  type_fighter          = "medium_fighter",
  type_assault          = "common_assault",
  type_bomber           = "medium_bomber"
}

let chancesText = [
  { text = "chance_to_met/high",    color = "@chanceHighColor",    brDiff = 0.0 }
  { text = "chance_to_met/average", color = "@chanceAverageColor", brDiff = 0.34 }
  { text = "chance_to_met/low",     color = "@chanceLowColor",     brDiff = 0.71 }
  { text = "chance_to_met/never",   color = "@chanceNeverColor",   brDiff = 1.01 }
]

let unitRoleByName = {}

function getUnitRole(unitData) { //  "fighter", "bomber", "assault", "transport", "diveBomber", "none"
  local unit = unitData
  if (type(unitData) == "string")
    unit = getAircraftByName(unitData);

  if (!unit)
    return ""; //not found

  local role = unitRoleByName?[unit.name] ?? ""
  if (role == "") {
    foreach (tag in unit.tags)
      if (tag in unitRoleByTag) {
        role = unitRoleByTag[tag]
        break
      }
    unitRoleByName[unit.name] <- role
  }

  return role
}

let getRoleTextByTag = @(tag) loc($"mainmenu/{tag}")

/*
  typeof @source == Unit     -> @source is unit
  typeof @source == "string" -> @source is role id
*/

function getUnitTooltipImage(unit) {
  if (unit.customTooltipImage)
    return unit.customTooltipImage

  let unitType = getEsUnitType(unit)
  if (unitType == ES_UNIT_TYPE_AIRCRAFT)
    return $"!ui/aircrafts/{unit.name}"
  if (unitType == ES_UNIT_TYPE_HELICOPTER)
    return $"!ui/aircrafts/{unit.name}"
  if (unitType == ES_UNIT_TYPE_TANK)
    return $"!ui/tanks/{unit.name}"
  if (unitType == ES_UNIT_TYPE_BOAT)
    return $"!ui/ships/{unit.name}"
  if (unitType == ES_UNIT_TYPE_SHIP)
    return $"!ui/ships/{unit.name}"
  return ""
}

function getFullUnitRoleText(unit) {
  let tags = unit?.tags
  if (tags == null)
    return ""

  if (unit?.isSubmarine())
    return getRoleText("submarine")

  let needShowBaseTag = tags.indexof("visibleBaseTag") != null
  let basicRoles = basicUnitRoles?[getEsUnitType(unit)] ?? []
  local basicRole = ""
  let textsList = []
  foreach (tag in tags)
    if (tag.len() > 5 && tag.slice(0, 5) == "type_") {
      if (!isInArray(tag, basicRoles))
        textsList.append(getRoleTextByTag(tag))
      else if (basicRole == "") {
        basicRole = tag
        if (needShowBaseTag)
          textsList.append(getRoleTextByTag(tag))
      }
    }

  if (textsList.len())
    return loc("mainmenu/unit_type_separator").join(textsList, true)

  return basicRole != "" ? getRoleTextByTag(basicRole) : ""
}

function getChanceToMeetText(battleRating1, battleRating2) {
  let brDiff = fabs(battleRating1.tofloat() - battleRating2.tofloat())
  local brData = null
  foreach (data in chancesText)
    if (!brData
        || (data.brDiff <= brDiff && data.brDiff > brData.brDiff))
      brData = data
  return brData ? colorize(brData.color, loc(brData.text)) : ""
}

function getShipMaterialTexts(unitId) {
  let res = {}
  let blk = get_wpcost_blk()?[unitId ?? ""]?.Shop
  let parts = [ "hull", "superstructure" ]
  foreach (part in parts) {
    let material  = blk?[$"{part}Material"]  ?? ""
    let thickness = blk?[$"{part}Thickness"] ?? 0.0
    if (thickness && material) {
      res[$"{part}Label"] <- loc($"info/ship/part/{part}")
      res[$"{part}Value"] <- "".concat(loc($"armor_class/{material}/short", loc($"armor_class/{material}")),
        loc("ui/comma"), round(thickness), " ", loc("measureUnits/mm"))
    }
  }
  if (res?.superstructureValue && res?.superstructureValue == res?.hullValue) {
    res.hullLabel = " ".concat(res.hullLabel, loc("clan/rankReqInfoCondType_and"),
      utf8ToLower(res.superstructureLabel))
    res.$rawdelete("superstructureLabel")
    res.$rawdelete("superstructureValue")
  }
  return res
}

function getUnitItemStatusText(bitStatus, isGroup = false) {
  local statusText = ""
  if (bit_unit_status.locked & bitStatus)
    statusText = "locked"
  else if (bit_unit_status.broken & bitStatus)
    statusText = "broken"
  else if (bit_unit_status.disabled & bitStatus)
    statusText = "disabled"
  else if (bit_unit_status.empty & bitStatus)
    statusText = "empty"

  if (!isGroup && statusText != "")
    return statusText

  if (bit_unit_status.inResearch & bitStatus)
    statusText = "research"
  else if (bit_unit_status.mounted & bitStatus)
    statusText = "mounted"
  else if ((bit_unit_status.owned & bitStatus) || (bit_unit_status.inRent & bitStatus))
    statusText = "owned"
  else if (bit_unit_status.canBuy & bitStatus)
    statusText = "canBuy"
  else if (bit_unit_status.researched & bitStatus)
    statusText = "researched"
  else if (bit_unit_status.canResearch & bitStatus)
    statusText = "canResearch"
  return statusText
}

function getUnitRarity(unit) {
  if (isUnitDefault(unit))
    return "reserve"
  if (isUnitSpecial(unit))
    return "premium"
  if (isUnitGift(unit))
    return "gift"
  if (unit.isSquadronVehicle())
    return "squadron"
  return "common"
}

function getUnitClassColor(unit) {
  let role = getUnitRole(unit) //  "fighter", "bomber", "assault", "transport", "diveBomber", "none"
  if (role == null || role == "" || role == "none")
    return "white";
  return $"{role}Color"
}

let getUnitClassIco = @(unit) unit.customClassIco ?? $"#ui/gameuiskin#{unit.name}_ico.svg"

function getCantBuyUnitReason(unit, isShopTooltip = false) {
  if (!unit)
    return loc("leaderboards/notAvailable")

  if (isUnitBought(unit) || isUnitGift(unit))
    return ""

  let special = isUnitSpecial(unit)
  let isSquadronVehicle = unit.isSquadronVehicle()
  if (!special && !isSquadronVehicle && !isUnitsEraUnlocked(unit)) {
    let countryId = getUnitCountry(unit)
    let unitType = getEsUnitType(unit)
    let rank = unit?.rank ?? -1

    for (local prevRank = rank - 1; prevRank > 0; prevRank--) {
      local unitsCount = 0
      foreach (un in getAllUnits())
        if (isUnitBought(un) && (un?.rank ?? -1) == prevRank && getUnitCountry(un) == countryId && getEsUnitType(un) == unitType)
          unitsCount++
      let unitsNeed = getUnitsNeedBuyToOpenNextInEra(countryId, unitType, prevRank)
      let unitsLeft = max(0, unitsNeed - unitsCount)

      if (unitsLeft > 0) {
        return  "\n".concat(
          loc("shop/unlockTier/locked", { rank = get_roman_numeral(rank) }),
          loc("shop/unlockTier/reqBoughtUnitsPrevRank",
            { prevRank = get_roman_numeral(prevRank), amount = unitsLeft }))
      }
    }
    return loc("shop/unlockTier/locked", { rank = get_roman_numeral(rank) })
  }
  else if (!isPrevUnitResearched(unit)) {
    if (isShopTooltip)
      return loc("mainmenu/needResearchPreviousVehicle")
    if (!isUnitResearched(unit))
      return loc("msgbox/need_unlock_prev_unit/research",
        { name = colorize("userlogColoredText", getUnitName(getPrevUnit(unit), true)) })
    return loc("msgbox/need_unlock_prev_unit/researchAndPurchase",
      { name = colorize("userlogColoredText", getUnitName(getPrevUnit(unit), true)) })
  }
  else if (!isPrevUnitBought(unit)) {
    if (isShopTooltip)
      return loc("mainmenu/needBuyPreviousVehicle")
    return loc("msgbox/need_unlock_prev_unit/purchase", { name = colorize("userlogColoredText", getUnitName(getPrevUnit(unit), true)) })
  }
  else if (isRequireUnlockForUnit(unit))
    return getUnitRequireUnlockText(unit)
  else if (!special && !isSquadronVehicle && !canBuyUnit(unit) && canResearchUnit(unit))
    return loc(isUnitInResearch(unit) ? "mainmenu/needResearch/researching" : "mainmenu/needResearch")

  if (!isShopTooltip) {
    let info = getProfileInfo()
    let balance = info?.balance ?? 0
    let balanceG = info?.gold ?? 0

    if (special && (wp_get_cost_gold(unit.name) > balanceG))
      return loc("mainmenu/notEnoughGold")
    else if (!special && (wp_get_cost(unit.name) > balance))
      return loc("mainmenu/notEnoughWP")
  }

  return ""
}

return {
  getUnitRole
  getUnitTooltipImage
  getFullUnitRoleText
  getChanceToMeetText
  getShipMaterialTexts
  getUnitItemStatusText
  getUnitRarity
  getUnitClassColor
  getUnitClassIco
  getCantBuyUnitReason
}
