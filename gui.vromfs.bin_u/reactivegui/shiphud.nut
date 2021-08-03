local activeOrder = require("activeOrder.nut")
local shipStateModule = require("shipStateModule.nut")
local hudLogs = require("hudLogs.nut")
local voiceChat = require("chat/voiceChat.nut")
local { safeAreaSizeHud, bw, bh, rw, rh } = require("style/screenState.nut")
local radarComponent = require("radarComponent.nut")
local fireControl = require("shipFireControl.nut")
local { dmgIndicatorStates } = require("reactiveGui/hudState.nut")


local shipHud = @(){
  watch = [safeAreaSizeHud, dmgIndicatorStates]
  size = [SIZE_TO_CONTENT, flex()]
  padding = dmgIndicatorStates.value.padding
  margin = safeAreaSizeHud.value.borders
  flow = FLOW_VERTICAL
  valign = ALIGN_BOTTOM
  halign = ALIGN_LEFT
  gap = ::scrn_tgt(0.005)
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
    radarComponent.mkRadar(bw() + rw(5.5), bh() + rh(17))
  ]
}
