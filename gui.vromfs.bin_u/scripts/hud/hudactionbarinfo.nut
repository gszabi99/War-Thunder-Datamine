from "%scripts/weaponry/weaponryDescription.nut" import getWeaponDescTextByTriggerGroup, getDefaultBulletName
from "%scripts/weaponry/bulletsInfo.nut" import getBulletSetNameByBulletName
from "mission" import get_mission_time
from "hudActionBarConst" import EII_BULLET, EII_ROCKET, EII_SMOKE_GRENADE, EII_FORCED_GUN, EII_SELECT_SPECIAL_WEAPON, EII_MISSION_SUPPORT_PLANE, EII_GRENADE
from "guiMission" import get_mission_difficulty_int
from "%scripts/dagui_library.nut" import *
from "%globalScripts/unitTypeConsts.nut" import *
from "%scripts/dagui_natives.nut" import utf8_strlen
from "%scripts/langUtils/textFormat.nut" import shortTextFromNum

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
  let { count = 0, countEx = 0, salvo = null, isStreakEx = false } = modData
  if (count < 0)
    return ""

  let itemType = modData.type
  let countStr = count.tostring()
  local text = countStr
  if (itemType == EII_SMOKE_GRENADE && salvo != null)
    text = $"{salvo}/{count}"
  else if (itemType == EII_MISSION_SUPPORT_PLANE)
    text = $"{shortTextFromNum(count)} {loc("multiplayer/spawnScore/abbr")}"
  else if (isStreakEx)
    text = $"{countStr}/{loc("icon/nuclear_bomb")}"
  else if (countEx >= 0) {
    let countExStr = countEx.tostring()
    let isCountExTooLong = !isFull
      && countStr.len() + ITEM_AMOUNT_SEPARATOR_LENGTH + countExStr.len() > ITEM_AMOUNT_TEXT_MAX_LEN
    text = $"{countStr}/{isCountExTooLong ? loc("weapon/bigAmountNumberIcon") : countExStr}"
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

return freeze({
  cacheActionDescs
  getActionDesc
  shouldActionBarFontBeTiny
  getActionItemAmountText
  getActionItemModificationName
  getActionItemStatus
  curHeroTemplates
})
