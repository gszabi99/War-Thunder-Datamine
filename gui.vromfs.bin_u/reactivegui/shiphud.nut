let activeOrder = require("activeOrder.nut")
let shipStateModule = require("shipStateModule.nut")
let hudLogs = require("hudLogs.nut")
let voiceChat = require("chat/voiceChat.nut")
let { safeAreaSizeHud, bw, bh, rw, rh } = require("style/screenState.nut")
let { mkRadar} = require("radarComponent.nut")
let fireControl = require("shipFireControl.nut")
let { dmgIndicatorStates } = require("%rGui/hudState.nut")


let shipHud = @(){
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

let radarPosComputed = Computed(@() [bw.value + 0.055 * rw.value, bh.value + 0.25 * rh.value])

return {
  size = flex()
  children = [
    shipHud
    fireControl
    mkRadar(radarPosComputed)
  ]
}
