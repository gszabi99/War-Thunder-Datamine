from "%rGui/globals/ui_library.nut" import *

let { missionProgressHeight, needShowDmgIndicator, isSpectatorMode
} = require("%rGui/hudState.nut")
let { safeAreaSizeHud } = require("%rGui/style/screenState.nut")
let { activeOrderComps }= require("%rGui/activeOrder.nut")
let voiceChat = require("%rGui/chat/voiceChat.nut")
let hudLogs = require("%rGui/hudLogs.nut")
let { dmgIndicatorWidth, updateDmgIndicatorElement } = require("%rGui/hud/dmgIndicatorState.nut")

let xraydoll = {
  rendObj = ROBJ_XRAYDOLL
  size = 1
}

let xrayIndicator = @() {
  watch = [needShowDmgIndicator, dmgIndicatorWidth]
  size = SIZE_TO_CONTENT
  behavior = Behaviors.RecalcHandler
  onRecalcLayout = updateDmgIndicatorElement
  children = needShowDmgIndicator.get()
    ? {
        rendObj = ROBJ_XRAYDOLL
        rotateWithCamera = true
        size = dmgIndicatorWidth.get()
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
  flow = isSpectatorMode.get() ? FLOW_HORIZONTAL : FLOW_VERTICAL
  valign = ALIGN_BOTTOM
  halign = ALIGN_LEFT
  gap = hdpx(10)
  children = isSpectatorMode.get() ? [hudLogs, xrayIndicator] : [
    voiceChat
    activeOrderComps
    logsComp
    xrayIndicator
  ]
}

return {
  leftPanel = panel
  xrayIndicator
}