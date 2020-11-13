local networkState = require("networkState.nut")
local activeOrder = require("activeOrder.nut")
local shipStateModule = require("shipStateModule.nut")
local hudLogs = require("hudLogs.nut")
local voiceChat = require("chat/voiceChat.nut")
local screenState = require("style/screenState.nut")
local radarComponent = require("radarComponent.nut")


local shipHud = @(){
  watch = networkState.isMultiplayer
  size = [SIZE_TO_CONTENT, flex()]
  padding = [0, 0, hdpx(32) + ::fpx(6), 0]
  margin = screenState.safeAreaSizeHud.value.borders
  flow = FLOW_VERTICAL
  valign = ALIGN_BOTTOM
  halign = ALIGN_LEFT
  gap = ::scrn_tgt(0.005)
  children = [
    voiceChat
    activeOrder
    networkState.isMultiplayer.value ? hudLogs : null
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
