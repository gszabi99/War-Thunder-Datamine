from "%scripts/dagui_library.nut" import *

let { get_unittags_blk } = require("blkGetters")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { getFullUnitBlk } = require("%scripts/unit/unitParams.nut")
let { getStatCardInfo } = require("%scripts/unit/statCardInfo.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")

let protectionTypesByUnitClass = {
  type_light_tank = "bullet_proof_lite"
  type_medium_tank = "projectile_proof_medium"
  type_heavy_tank = "projectile_proof_heavy"
  type_missile_tank = "splinter_proof_rocket"
  type_tank_destroyer = "projectile_proof_sau"
  type_spaa = "bullet_proof_lite"
}

let armorTypes = [
  "hasNoArmor",
  "hasSteelArmor",
  "hasSpallLiner",
  "hasNBCLiner",
  "hasCompositeArmor",
  "hasAluminiumArmor",
  "hasArtilleryProtection",
  "hasReinforcedHullProtection",
  "hasLocalHullProtection",
  "hasCitadel",
  "hasAntiTorpedoProtection",
  "hasLocalSideProtection",
  "hasFullSideProtection",
  "hasReinforcedInternalProtection",
  "hasLocalInternalProtection"
]

let unitArmorCache = {}
let unitProtectionTypeCache = {}
let unitAPSCache = {}

function getUnitArmor(unitName) {
  if (unitName in unitArmorCache)
    return unitArmorCache[unitName]

  unitArmorCache[unitName] <- []

  let statCardInfo = getStatCardInfo()?[unitName]
  if (statCardInfo == null)
    return unitArmorCache[unitName]

  let unitArmor = armorTypes.filter(@(t) statCardInfo?[t] != null)
  let eraTypes = statCardInfo % "eraType"

  unitArmor.each(@(armor) unitArmorCache[unitName].append({
    itemName = loc($"info/material/{armor}")
    tooltipId = getTooltipType("UNIT_INFO_ARMOR").getTooltipId("armor", { armor, unitId = unitName })
  }))

  eraTypes.each(@(armor) unitArmorCache[unitName].append({
    itemName = loc($"armor_class/{armor}")
    tooltipId = ""
    isNotLink = true
  }))

  return unitArmorCache[unitName]
}

function getUnittags(unitName) {
  return get_unittags_blk()?[unitName] ?? {}
}

function getUnitProtectionType(unitName) {
  if (unitName in unitProtectionTypeCache)
    return unitProtectionTypeCache[unitName]

  let unitTags = getUnittags(unitName)
  let protectionType = unitTags?.Shop.mainArmorProtectionLevel ??
    protectionTypesByUnitClass.findvalue(@(_value, key) key in unitTags.tags)

  unitProtectionTypeCache[unitName] <- protectionType != null ? {
    itemName = loc($"info/material/{protectionType}")
    tooltipId = getTooltipType("UNIT_INFO_PROTECTION_TYPE").getTooltipId("protectionType", { protectionType, unitId = unitName })
  } : null
  return unitProtectionTypeCache[unitName]
}

function getUnitAPS(unitName) {
  if (unitName in unitAPSCache)
    return unitAPSCache[unitName]

  let hasApsInUnitTags = getUnittags(unitName)?.tags.has_aps ?? false
  if (!hasApsInUnitTags) {
    unitAPSCache[unitName] <- null
    return unitAPSCache[unitName]
  }

  let blk = getFullUnitBlk(unitName)
  let aps = blk?.ActiveProtectionSystem

  if (aps == null) {
    unitAPSCache[unitName] <- null
    return unitAPSCache[unitName]
  }

  let modelLoc = loc($"aps/{aps.model}")
  let data = {
    itemName = loc($"info/apsName", { name = modelLoc })
    tooltipId = getTooltipType("UNIT_INFO_APS").getTooltipId($"{aps.model}", { unitId = unitName })
  }

  unitAPSCache[unitName] <- data
  return unitAPSCache[unitName]
}

function combineUnitProtectionInfo(unitName) {
  let armorData = getUnitArmor(unitName)
  let protectionTypeData = getUnitProtectionType(unitName)
  let apsData = getUnitAPS(unitName)
  let data = [].extend(armorData, [protectionTypeData, apsData])
  return data.filter(@(v) v != null)
}

function getUnitProtectionMarkup(unitName) {
  let items = combineUnitProtectionInfo(unitName)
  return items.len() > 0 ? handyman.renderCached("%gui/unitInfo/unitSystems.tpl", { items, isTooltipByHold = showConsoleButtons.get() }) : null
}

function clearCaches() {
  unitArmorCache.clear()
  unitProtectionTypeCache.clear()
  unitAPSCache.clear()
}

addListenersWithoutEnv({
  GameLocalizationChanged = @(_) clearCaches()
})

return {
  getUnitProtectionMarkup
}
