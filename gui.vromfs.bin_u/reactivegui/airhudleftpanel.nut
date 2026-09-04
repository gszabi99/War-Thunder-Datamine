import "%rGui/chat/voiceChat.nut" as voiceChat
import "%rGui/hudLogs.nut" as hudLogs
from "%rGui/hudState.nut" import missionProgressHeight, needShowDmgIndicator, isSpectatorMode
from "%rGui/style/screenState.nut" import safeAreaSizeHud
from "%rGui/activeOrder.nut" import activeOrderComps
from "%rGui/hud/dmgIndicatorState.nut" import dmgIndicatorWidth, updateDmgIndicatorElement
from "%rGui/globals/ui_library.nut" import *
from "%globalScripts/gameRendObjs.nut" import *


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
  watch = [safeAreaSizeHud, missionProgressHeight, isSpectatorMode, needShowDmgIndicator]
  size = FLEX_V
  padding = [0, 0, missionProgressHeight.get(), 0]
  margin = safeAreaSizeHud.get().borders
  flow = isSpectatorMode.get() ? FLOW_HORIZONTAL : FLOW_VERTICAL
  valign = ALIGN_BOTTOM
  halign = ALIGN_LEFT
  gap = hdpx(10)
  children = isSpectatorMode.get() ? [hudLogs, xrayIndicator] : [
    needShowDmgIndicator.get() ? null : xrayIndicator
    voiceChat
    activeOrderComps
    logsComp
    needShowDmgIndicator.get() ? xrayIndicator : null
  ]
}

return {
  leftPanel = panel
  xrayIndicator
}