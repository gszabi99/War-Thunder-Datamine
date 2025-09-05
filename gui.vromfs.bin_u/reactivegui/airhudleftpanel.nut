from "%rGui/globals/ui_library.nut" import *

let { dmgIndicatorStates, missionProgressHeight,
  needShowDmgIndicator, isSpectatorMode
} = require("%rGui/hudState.nut")
let { safeAreaSizeHud } = require("%rGui/style/screenState.nut")
let activeOrder = require("%rGui/activeOrder.nut")
let voiceChat = require("%rGui/chat/voiceChat.nut")
let hudLogs = require("%rGui/hudLogs.nut")
let { eventbus_send } = require("eventbus")

let xraydoll = {
  rendObj = ROBJ_XRAYDOLL
  size = 1
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
        size = dmgIndicatorStates.get()?.size ?? SIZE_TO_CONTENT
        margin = hdpx(15)
      }
    : xraydoll
}

let logsComp = {
  size = SIZE_TO_CONTENT
  minHeight = hdpx(210) 
  children = hudLogs
}

let panel = @() {
  watch = [safeAreaSizeHud, missionProgressHeight, isSpectatorMode]
  size = FLEX_V
  padding = [0, 0, missionProgressHeight.get(), 0]
  margin = safeAreaSizeHud.get().borders
  flow = FLOW_VERTICAL
  valign = ALIGN_BOTTOM
  halign = ALIGN_LEFT
  gap = hdpx(10)
  children = isSpectatorMode.get() ? null : [
    voiceChat
    activeOrder
    logsComp
    xrayIndicator
  ]
}

return panel