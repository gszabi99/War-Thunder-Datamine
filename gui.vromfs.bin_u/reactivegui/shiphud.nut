from "%rGui/globals/ui_library.nut" import *

let activeOrder = require("activeOrder.nut")
let shipStateModule = require("shipStateModule.nut")
let hudLogs = require("hudLogs.nut")
let voiceChat = require("chat/voiceChat.nut")
let { safeAreaSizeHud } = require("style/screenState.nut")
let fireControl = require("shipFireControl.nut")
let { dmgIndicatorStates } = require("%rGui/hudState.nut")
let { radarComponent } = require("shipHudComponents.nut")


let shipHud = @(){
  watch = [safeAreaSizeHud, dmgIndicatorStates]
  size = [SIZE_TO_CONTENT, flex()]
  padding = dmgIndicatorStates.value.padding
  margin = safeAreaSizeHud.value.borders
  flow = FLOW_VERTICAL
  valign = ALIGN_BOTTOM
  halign = ALIGN_LEFT
  gap = scrn_tgt(0.005)
  children = [
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
