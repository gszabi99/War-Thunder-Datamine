let { getTimestampFromStringUtc } = require("scripts/time.nut")
let { GUI } = require("scripts/utils/configs.nut")

local baseCustomizationArray = null

let activeConfig = ::Watched(null)
let toBattleLocId = ::Computed(@() activeConfig.value?.toBattleLocId ?? "mainmenu/toBattle")
let toBattleLocIdShort = ::Computed(@() activeConfig.value?.toBattleLocIdShort ?? "mainmenu/toBattle/short")

toBattleLocId.subscribe(@(_) ::broadcastEvent("ToBattleLocChanged"))
toBattleLocIdShort.subscribe(@(_) ::broadcastEvent("ToBattleLocShortChanged"))

local updateCustomizationConfigTask = -1

let function initCustomConfigOnce() {
  if (baseCustomizationArray != null)
    return

  baseCustomizationArray = []
  let customizationsBlk = GUI.get()?.interface_customization
  if (customizationsBlk == null)
    return

  let configsCount = customizationsBlk.blockCount()
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
  let activeCustomizationConfig = {}
  foreach(customization in baseCustomizationArray) {
    let endTime = customization?.endDate != null
      ? getTimestampFromStringUtc(customization.endDate)
      : null
    let currentTime = ::get_charserver_time_sec()
    if (endTime == null || currentTime >= endTime)
      continue

    let startTime = customization?.beginDate != null
      ? getTimestampFromStringUtc(customization.beginDate)
      : null
    if (startTime != null && currentTime < startTime) {
      let updateTimeSec = startTime - currentTime
      minUpdateTimeSec = ::min(minUpdateTimeSec ?? updateTimeSec, updateTimeSec)
      continue
    }

    let updateTimeSec = endTime - currentTime
    minUpdateTimeSec = ::min(minUpdateTimeSec ?? updateTimeSec, updateTimeSec)
    activeCustomizationConfig.__update(customization)
  }

  activeConfig(activeCustomizationConfig)
  if (minUpdateTimeSec != null)
    updateCustomizationConfigTask = ::periodic_task_register(this,
      @(dt) updateActiveCustomConfig(), minUpdateTimeSec)
}

let function initActiveConfigeOnce() {
  if (activeConfig.value == null)
    updateActiveCustomConfig()
}

let function getToBattleLocId() {
  initActiveConfigeOnce()
  return toBattleLocId.value
}

let function getToBattleLocIdShort() {
  initActiveConfigeOnce()
  return toBattleLocIdShort.value
}

return {
  getToBattleLocId
  getToBattleLocIdShort
}
