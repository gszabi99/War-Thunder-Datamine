//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { getTimestampFromStringUtc } = require("%scripts/time.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")

let activeConfig = Watched(null)
let toBattleLocId = Computed(@() activeConfig.value?.toBattleLocId ?? "mainmenu/toBattle")
let toBattleLocIdShort = Computed(@() activeConfig.value?.toBattleLocIdShort ?? "mainmenu/toBattle/short")

toBattleLocId.subscribe(@(_) broadcastEvent("ToBattleLocChanged"))
toBattleLocIdShort.subscribe(@(_) broadcastEvent("ToBattleLocShortChanged"))

local updateCustomizationConfigTask = -1

let scheduledEvents = [
  {
    beginDate = "04-12 06:07:00"
    endDate = "04-12 23:59:59"
    toBattleLocId = "mainmenu/toBattle/12april"
    toBattleLocIdShort = "mainmenu/toBattle/12april"
  }
]

local updateActiveCustomConfig = @() null
updateActiveCustomConfig = function() {
  if (updateCustomizationConfigTask >= 0) {
    ::periodic_task_unregister(updateCustomizationConfigTask)
    updateCustomizationConfigTask = -1
  }

  local minUpdateTimeSec = null
  let activeCustomizationConfig = {}
  foreach (customization in scheduledEvents) {
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
      minUpdateTimeSec = min(minUpdateTimeSec ?? updateTimeSec, updateTimeSec)
      continue
    }

    let updateTimeSec = endTime - currentTime
    minUpdateTimeSec = min(minUpdateTimeSec ?? updateTimeSec, updateTimeSec)
    activeCustomizationConfig.__update(customization)
  }

  activeConfig(activeCustomizationConfig)
  if (minUpdateTimeSec != null)
    updateCustomizationConfigTask = ::periodic_task_register(this,
      @(_dt) updateActiveCustomConfig(), minUpdateTimeSec)
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
