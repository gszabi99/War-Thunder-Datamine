local { getWeaponDescTextByTriggerGroup, getDefaultBulletName } = require("scripts/weaponry/weaponryDescription.nut")
local { getBulletSetNameByBulletName } = require("scripts/weaponry/bulletsInfo.nut")

local cachedUnitId = ""
local cache = {}

local LONG_ACTIONBAR_TEXT_LEN = 6;

local cacheActionDescs = function(unitId) {
  local unit = ::getAircraftByName(unitId)
  local ediff = ::get_mission_difficulty_int()
  cachedUnitId = unitId
  cache.clear()
  if (unit == null ||
      (unit.esUnitType != ::ES_UNIT_TYPE_SHIP && unit.esUnitType != ::ES_UNIT_TYPE_BOAT))
    return

  foreach (triggerGroup in [ "torpedoes", "bombs", "rockets", "mines" ])
    cache[triggerGroup] <- getWeaponDescTextByTriggerGroup(triggerGroup, unit, ediff)
}

local getActionDesc = function(unitId, triggerGroup) {
  if (unitId != cachedUnitId)
    cacheActionDescs(unitId)
  return cache?[triggerGroup] ?? ""
}

local function getActionItemAmountText(modData, isFull = false) {
  local count = modData?.count ?? 0
  if (count < 0)
    return ""

  local text = ""
  if (modData.type == ::EII_SMOKE_GRENADE && "salvo" in modData)
    text = $"{modData.salvo}/{modData.count}"
  else
  {
    local countEx = modData?.countEx ?? 0
    local countStr = count.tostring()
    local countExText = modData?.isStreakEx ? ::loc("icon/nuclear_bomb") : (countEx < 0 ? "" : countEx.tostring())
    if (countExText.len() > 0 && countExText.len() > (LONG_ACTIONBAR_TEXT_LEN - countStr.len()))
      countExText = ::loc("weapon/bigAmountNumberIcon")
    text = countExText.len() > 0 ? $"{countStr}/{countExText}" : countStr
  }

  return isFull ? $"{::loc("options/count")}{::loc("ui/colon")}{text}" : text
}

local function getActionItemModificationName(item, unit) {
  if (!unit)
    return null

  switch (item.type)
  {
    case ::EII_ROCKET:
      return getBulletSetNameByBulletName(unit, item?.bulletName)
    case ::EII_BULLET:
    case ::EII_FORCED_GUN:
      return item?.modificationName ?? getDefaultBulletName(unit)
  }

  return null
}

return {
  cacheActionDescs
  getActionDesc
  LONG_ACTIONBAR_TEXT_LEN
  getActionItemAmountText
  getActionItemModificationName
}
