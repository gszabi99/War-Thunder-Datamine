local activeOrder = require("activeOrder.nut")
local shipStateModule = require("shipStateModule.nut")
local hudLogs = require("hudLogs.nut")
local voiceChat = require("chat/voiceChat.nut")
local { safeAreaSizeHud } = require("style/screenState.nut")
local radarComponent = require("radarComponent.nut")


local shipHud = @(){
  watch = safeAreaSizeHud
  size = [SIZE_TO_CONTENT, flex()]
  padding = [0, 0, hdpx(32) + ::fpx(6), 0]
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
    shipHud,
    radarComponent.radar(false, sh(4), sh(18))
  ]
}
