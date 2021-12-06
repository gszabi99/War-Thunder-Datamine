local { getTimestampFromStringUtc } = require("scripts/time.nut")

local baseCustomizationArray = null

local activeConfig = ::Watched(null)
local toBattleLocId = ::Computed(@() activeConfig.value?.toBattleLocId ?? "mainmenu/toBattle")
local toBattleLocIdShort = ::Computed(@() activeConfig.value?.toBattleLocIdShort ?? "mainmenu/toBattle/short")

toBattleLocId.subscribe(@(_) ::broadcastEvent("ToBattleLocChanged"))
toBattleLocIdShort.subscribe(@(_) ::broadcastEvent("ToBattleLocShortChanged"))

local updateCustomizationConfigTask = -1

local function initCustomConfigOnce() {
  if (baseCustomizationArray != null)
    return

  baseCustomizationArray = []
  local customizationsBlk = ::configs.GUI.get()?.interface_customization
  if (customizationsBlk == null)
    return

  local configsCount = customizationsBlk.blockCount()
  for(local i = 0; i < configsCount; i++)
    baseCustomizationArray.append(::buildTableFromBlk(customizationsBlk.getBlock(i)))
}

local updateActiveCustomConfig = @() null
updateActiveCustomConfig = function() {
  initCustomConfigOnce()
  if (updateCustomizationConfigTask >= 0) {
    ::periodic_task_unregister(updateCustomizationConfigTask)
    updateCustomizationConfigTask = -1
  }

  local minUpdateTimeSec = null
  local activeCustomizationConfig = {}
  foreach(customization in baseCustomizationArray) {
    local endTime = customization?.endDate != null
      ? getTimestampFromStringUtc(customization.endDate)
      : null
    local currentTime = ::get_charserver_time_sec()
    if (endTime == null || currentTime >= endTime)
      continue

    local startTime = customization?.beginDate != null
      ? getTimestampFromStringUtc(customization.beginDate)
      : null
    if (startTime != null && currentTime < startTime) {
      local updateTimeSec = startTime - currentTime
      minUpdateTimeSec = ::min(minUpdateTimeSec ?? updateTimeSec, updateTimeSec)
      continue
    }

    local updateTimeSec = endTime - currentTime
    minUpdateTimeSec = ::min(minUpdateTimeSec ?? updateTimeSec, updateTimeSec)
    activeCustomizationConfig.__update(customization)
  }

  activeConfig(activeCustomizationConfig)
  if (minUpdateTimeSec != null)
    updateCustomizationConfigTask = ::periodic_task_register(this,
      @(dt) updateActiveCustomConfig(), minUpdateTimeSec)
}

local function initActiveConfigeOnce() {
  if (activeConfig.value == null)
    updateActiveCustomConfig()
}

local function getToBattleLocId() {
  initActiveConfigeOnce()
  return toBattleLocId.value
}

local function getToBattleLocIdShort() {
  initActiveConfigeOnce()
  return toBattleLocIdShort.value
}

return {
  getToBattleLocId
  getToBattleLocIdShort
}
