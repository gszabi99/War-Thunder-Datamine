//-file:plus-string
from "%scripts/dagui_library.nut" import *

let { isUnitSpecial } = require("%appGlobals/ranks_common_shared.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { round, fabs } = require("math")
let { utf8ToLower } = require("%sqstd/string.nut")
let { getEsUnitType, isUnitDefault, isUnitGift, bit_unit_status } = require("%scripts/unit/unitInfo.nut")
let { get_wpcost_blk } = require("blkGetters")

let basicUnitRoles = {
  [ES_UNIT_TYPE_AIRCRAFT] = ["type_fighter", "type_assault", "type_bomber"],
  [ES_UNIT_TYPE_TANK] = ["type_tank", "type_light_tank", "type_medium_tank", "type_heavy_tank",
    "type_tank_destroyer", "type_spaa", "type_lbv", "type_mbv", "type_hbv", "type_exoskeleton"],
  [ES_UNIT_TYPE_BOAT] = ["type_boat", "type_heavy_boat", "type_barge", "type_frigate"],
  [ES_UNIT_TYPE_SHIP] = ["type_ship", "type_destroyer", "type_light_cruiser",
    "type_heavy_cruiser", "type_battlecruiser", "type_battleship", "type_submarine"],
  [ES_UNIT_TYPE_HELICOPTER] = ["type_attack_helicopter", "type_utility_helicopter"],
}

let unitRoleFontIcons = {
  fighter                  = loc("icon/unitclass/fighter"),
  assault                  = loc("icon/unitclass/assault"),
  bomber                   = loc("icon/unitclass/bomber"),
  attack_helicopter        = loc("icon/unitclass/attack_helicopter"),
  utility_helicopter       = loc("icon/unitclass/utility_helicopter"),
  light_tank               = loc("icon/unitclass/light_tank"),
  medium_tank              = loc("icon/unitclass/medium_tank"),
  heavy_tank               = loc("icon/unitclass/heavy_tank"),
  tank_destroyer           = loc("icon/unitclass/tank_destroyer"),
  spaa                     = loc("icon/unitclass/spaa"),
  lbv                      = loc("icon/unitclass/light_tank")
  mbv                      = loc("icon/unitclass/medium_tank")
  hbv                      = loc("icon/unitclass/heavy_tank")
  exoskeleton              = loc("icon/unitclass/medium_tank"),
  ship                     = loc("icon/unitclass/ship"),
  boat                     = loc("icon/unitclass/gun_boat")
  heavy_boat               = loc("icon/unitclass/heavy_gun_boat")
  barge                    = loc("icon/unitclass/naval_ferry_barge")
  destroyer                = loc("icon/unitclass/destroyer")
  frigate                  = loc("icon/unitclass/destroyer")
  light_cruiser            = loc("icon/unitclass/light_cruiser")
  cruiser                  = loc("icon/unitclass/cruiser")
  heavy_cruiser            = loc("icon/unitclass/cruiser")
  battlecruiser            = loc("icon/unitclass/battlecruiser")
  battleship               = loc("icon/unitclass/battleship")
  submarine                = loc("icon/unitclass/submarine")
}

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

let getRoleName = @(role) role.slice(5)

function getUnitBasicRole(unit) {
  let unitType = getEsUnitType(unit)
  let basicRoles = basicUnitRoles?[unitType]
  if (!basicRoles || !basicRoles.len())
    return ""

  foreach (tag in unit.tags)
    if (isInArray(tag, basicRoles))
      return getRoleName(tag)
  return getRoleName(basicRoles[0])
}

let getRoleText = @(role) loc($"mainmenu/type_{role}")
let getRoleTextByTag = @(tag) loc($"mainmenu/{tag}")

/*
  typeof @source == Unit     -> @source is unit
  typeof @source == "string" -> @source is role id
*/
function getUnitRoleIcon(source) {
  let role = u.isString(source) ? source
    : getUnitBasicRole(source)
  return unitRoleFontIcons?[role] ?? ""
}

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
    let material  = blk?[part + "Material"]  ?? ""
    let thickness = blk?[part + "Thickness"] ?? 0.0
    if (thickness && material) {
      res[part + "Label"] <- loc($"info/ship/part/{part}")
      res[part + "Value"] <- loc("armor_class/" + material + "/short", loc("armor_class/" + material)) +
        loc("ui/comma") + round(thickness) + " " + loc("measureUnits/mm")
    }
  }
  if (res?.superstructureValue && res?.superstructureValue == res?.hullValue) {
    res.hullLabel += " " + loc("clan/rankReqInfoCondType_and") + " " +
      utf8ToLower(res.superstructureLabel)
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

return {
  getUnitRole
  getUnitBasicRole
  getRoleText
  getUnitRoleIcon
  getUnitTooltipImage
  getFullUnitRoleText
  getChanceToMeetText
  getShipMaterialTexts
  getUnitItemStatusText
  getUnitRarity
  getUnitClassColor
}
