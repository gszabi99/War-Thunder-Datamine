from "%rGui/globals/ui_library.nut" import *

let { dmgIndicatorStates, missionProgressHeight,
  isVisibleDmgIndicator } = require("%rGui/hudState.nut")
let { safeAreaSizeHud } = require("style/screenState.nut")
let activeOrder = require("activeOrder.nut")
let voiceChat = require("chat/voiceChat.nut")
let hudLogs = require("hudLogs.nut")

// Need add ROBJ_XRAYDOLL in scene for correct update isVisibleDmgIndicator state
let xraydoll = {
  rendObj = ROBJ_XRAYDOLL
  size = [1, 1]
}

let xrayIndicator = @() {
  watch = [dmgIndicatorStates, isVisibleDmgIndicator]
  size = SIZE_TO_CONTENT
  children = isVisibleDmgIndicator.value
    ? {
        rendObj = ROBJ_XRAYDOLL
        rotateWithCamera = true
        size = dmgIndicatorStates.value?.size ?? SIZE_TO_CONTENT
        margin = hdpx(15)
      }
    : xraydoll
}

let logsComp = {
  size = SIZE_TO_CONTENT
  minHeight = hdpx(210) // reserve height to prevent shifting of order when log appears
  children = hudLogs
}

let panel = @() {
  watch = [safeAreaSizeHud, missionProgressHeight]
  size = [SIZE_TO_CONTENT, flex()]
  padding = [0, 0, missionProgressHeight.value, 0]
  margin = safeAreaSizeHud.value.borders
  flow = FLOW_VERTICAL
  valign = ALIGN_BOTTOM
  halign = ALIGN_LEFT
  gap = hdpx(10)
  children = [
    voiceChat
    activeOrder
    logsComp
    xrayIndicator
  ]
}

return panel