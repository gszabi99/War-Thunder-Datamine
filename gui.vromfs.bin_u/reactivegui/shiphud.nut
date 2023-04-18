from "%rGui/globals/ui_library.nut" import *

let activeOrder = require("activeOrder.nut")
let shipStateModule = require("shipStateModule.nut")
let hudLogs = require("hudLogs.nut")
let voiceChat = require("chat/voiceChat.nut")
let { safeAreaSizeHud } = require("style/screenState.nut")
let fireControl = require("shipFireControl.nut")
let { missionProgressHeight, isSpectatorMode } = require("%rGui/hudState.nut")
let { radarComponent } = require("shipHudComponents.nut")


let shipHud = @() {
  watch = [safeAreaSizeHud, missionProgressHeight, isSpectatorMode]
  size = [SIZE_TO_CONTENT, flex()]
  padding = [0, 0, missionProgressHeight.value, 0]
  margin = safeAreaSizeHud.value.borders
  flow = FLOW_VERTICAL
  valign = ALIGN_BOTTOM
  halign = ALIGN_LEFT
  gap = scrn_tgt(0.005)
  children = isSpectatorMode.value ? null : [
    voiceChat
    activeOrder
    hudLogs
    shipStateModule
  ]
}

return {
  size = flex()
  children = [
    shipHud
    fireControl
    radarComponent
  ]
}
