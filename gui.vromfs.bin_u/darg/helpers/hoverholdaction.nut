from "daRg" import gui_scene

const REPAY_TIME = 0.3

local allTimers = {}

local function mkOnHover(groupId, itemId, action, repayTime = REPAY_TIME) {
  if (!(groupId in allTimers))
    allTimers[groupId] <- {}
  local groupTimers = allTimers[groupId]
  return function(on) {
    if (groupTimers?[itemId]) {
      gui_scene.clearTimer(groupTimers[itemId])
      delete groupTimers[itemId]
    }
    if (!on)
      return
    groupTimers[itemId] <- function() {
      delete groupTimers[itemId]
      action(itemId)
    }
    gui_scene.setTimeout(repayTime, groupTimers[itemId])
  }
}

return mkOnHover