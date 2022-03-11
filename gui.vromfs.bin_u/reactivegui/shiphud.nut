local activeOrder = require("activeOrder.nut")
local shipStateModule = require("shipStateModule.nut")
local hudLogs = require("hudLogs.nut")
local voiceChat = require("chat/voiceChat.nut")
local { safeAreaSizeHud, bw, bh, rw, rh } = require("style/screenState.nut")
local { mkRadar} = require("radarComponent.nut")
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

local radarPosComputed = Computed(@() [bw.value + 0.055 * rw.value, bh.value + 0.25 * rh.value])

return {
  size = flex()
  children = [
    shipHud
    fireControl
    mkRadar(radarPosComputed)
  ]
}
