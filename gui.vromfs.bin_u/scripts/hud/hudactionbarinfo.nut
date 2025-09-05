from "%scripts/dagui_library.nut" import *
from "%scripts/dagui_natives.nut" import utf8_strlen

let { get_mission_time } = require("mission")
let { getWeaponDescTextByTriggerGroup, getDefaultBulletName } = require("%scripts/weaponry/weaponryDescription.nut")
let { getBulletSetNameByBulletName } = require("%scripts/weaponry/bulletsInfo.nut")
let { EII_BULLET, EII_ROCKET, EII_SMOKE_GRENADE, EII_FORCED_GUN, EII_SELECT_SPECIAL_WEAPON,
  EII_MISSION_SUPPORT_PLANE, EII_GRENADE
} = require("hudActionBarConst")
let { get_mission_difficulty_int } = require("guiMission")

let curHeroTemplates = Watched({})

local cachedUnitId = ""
let cache = {}

const ITEM_TINY_FONT_TEXT_LEN_THRESHOLD = 6
const ITEM_AMOUNT_TEXT_MAX_LEN = 8
const ITEM_AMOUNT_SEPARATOR_LENGTH = 1 

let shouldActionBarFontBeTiny  = @(text) utf8_strlen(text) >= ITEM_TINY_FONT_TEXT_LEN_THRESHOLD

let cacheActionDescs = function(unitId) {
  let unit = getAircraftByName(unitId)
  let ediff = get_mission_difficulty_int()
  cachedUnitId = unitId
  cache.clear()
  if (unit == null ||
      (unit.esUnitType != ES_UNIT_TYPE_SHIP && unit.esUnitType != ES_UNIT_TYPE_BOAT))
    return

  foreach (triggerGroup in [ "torpedoes", "bombs", "rockets", "mines" ])
    cache[triggerGroup] <- getWeaponDescTextByTriggerGroup(triggerGroup, unit, ediff)
}

let getActionDesc = function(unitId, triggerGroup) {
  if (unitId != cachedUnitId)
    cacheActionDescs(unitId)
  return cache?[triggerGroup] ?? ""
}

function getActionItemAmountText(modData, isFull = false) {
  let count = modData?.count ?? 0
  if (count < 0)
    return ""

  local text = ""
  if (modData.type == EII_SMOKE_GRENADE && "salvo" in modData)
    text = $"{modData.salvo}/{modData.count}"
  else {
    let countEx = modData?.countEx ?? 0
    let countStr = count.tostring()
    local countExText = modData?.isStreakEx ? loc("icon/nuclear_bomb") : (countEx < 0 ? "" : countEx.tostring())
    let shouldTruncate = !isFull
      && countExText.len() > 0
      && countExText.len() + countStr.len() + ITEM_AMOUNT_SEPARATOR_LENGTH > ITEM_AMOUNT_TEXT_MAX_LEN
    if (shouldTruncate)
      countExText = loc("weapon/bigAmountNumberIcon")
    text = countExText.len() > 0 ? $"{countStr}/{countExText}" : countStr
    if (modData.type == EII_MISSION_SUPPORT_PLANE)
      text = $"{countStr} {loc("multiplayer/spawnScore/abbr")}"
  }

  return isFull ? $"{loc("options/count")}{loc("ui/colon")}{text}" : text
}

function getActionItemModificationName(item, unit) {
  if (!unit)
    return null
  let itemType = item.type
  if (itemType == EII_ROCKET || itemType == EII_GRENADE)
    return getBulletSetNameByBulletName(unit, item?.bulletName)
  if (itemType == EII_SELECT_SPECIAL_WEAPON)
    return getBulletSetNameByBulletName(unit, item?.bulletName)
  if (itemType == EII_BULLET || itemType == EII_FORCED_GUN)
    return (item?.modificationName ?? "") != ""
      ? item.modificationName
      : getDefaultBulletName(unit)
  return null
}

function getActionItemStatus(item) {
  let { count = 0, available = true, cooldownEndTime = 0 } = item
  let isAvailable = available && count != 0
  return {
    isAvailable
    isReady = isAvailable && cooldownEndTime <= get_mission_time()
  }
}

return {
  cacheActionDescs
  getActionDesc
  shouldActionBarFontBeTiny
  getActionItemAmountText
  getActionItemModificationName
  getActionItemStatus
  curHeroTemplates
}
