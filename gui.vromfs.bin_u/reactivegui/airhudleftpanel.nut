from "%rGui/globals/ui_library.nut" import *

let { dmgIndicatorStates, missionProgressHeight,
  needShowDmgIndicator, isSpectatorMode
} = require("%rGui/hudState.nut")
let { safeAreaSizeHud } = require("style/screenState.nut")
let activeOrder = require("activeOrder.nut")
let voiceChat = require("chat/voiceChat.nut")
let hudLogs = require("hudLogs.nut")
let { eventbus_send } = require("eventbus")
// Need add ROBJ_XRAYDOLL in scene for correct update isVisibleDmgIndicator state
let xraydoll = {
  rendObj = ROBJ_XRAYDOLL
  size = [1, 1]
}

let xrayIndicator = @() {
  watch = [dmgIndicatorStates, needShowDmgIndicator]
  size = SIZE_TO_CONTENT
  behavior = Behaviors.RecalcHandler
  function onRecalcLayout(_initial, elem) {
    if (elem.getWidth() > 1 && elem.getHeight() > 1) {
      eventbus_send("update_damage_panel_state", {
        pos = [elem.getScreenPosX(), elem.getScreenPosY()]
        size = [elem.getWidth(), elem.getHeight()]
        visible = needShowDmgIndicator.get()
      })
    }
    else
      eventbus_send("update_damage_panel_state", {})
  }
  children = needShowDmgIndicator.get()
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
  watch = [safeAreaSizeHud, missionProgressHeight, isSpectatorMode]
  size = [SIZE_TO_CONTENT, flex()]
  padding = [0, 0, missionProgressHeight.value, 0]
  margin = safeAreaSizeHud.value.borders
  flow = FLOW_VERTICAL
  valign = ALIGN_BOTTOM
  halign = ALIGN_LEFT
  gap = hdpx(10)
  children = isSpectatorMode.value ? null : [
    voiceChat
    activeOrder
    logsComp
    xrayIndicator
  ]
}

return panel