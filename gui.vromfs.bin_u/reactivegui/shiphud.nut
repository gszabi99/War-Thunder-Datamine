import "%rGui/shipStateModule.nut" as shipMainPanel
import "%rGui/hudLogs.nut" as hudLogs
import "%rGui/chat/voiceChat.nut" as voiceChat
import "%rGui/shipFireControl.nut" as fireControl
import "%rGui/shipObstacleRangefinder.nut" as shipObstacleRf
import "%rGui/rocketAamAim.nut" as aamAim
from "%rGui/activeOrder.nut" import activeOrderComps
from "%rGui/style/screenState.nut" import safeAreaSizeHud
from "%rGui/hudState.nut" import missionProgressHeight, isSpectatorMode, isPlayingReplay
from "%rGui/hud/actionBarTopPanel.nut" import actionBarTopPanel
from "%rGui/shipHitNotification.nut" import hitNotifications
from "%rGui/globals/ui_library.nut" import *

let shipHudComponents = require("%rGui/shipHudComponents.nut")
let { radarComponent } = shipHudComponents





let sensorViewIndicators = require("%rGui/hud/sensorViewIndicator.nut")

const greenColor = Color(10, 202, 10, 250)
const redColor = Color(255, 35, 30, 255)
let colorWacthed = Watched(greenColor)
let colorAlertWatched = Watched(redColor)

let shipHud = @() {
  watch = [safeAreaSizeHud, missionProgressHeight, isSpectatorMode]
  size = FLEX_V
  padding = [0, 0, missionProgressHeight.get(), 0]
  margin = safeAreaSizeHud.get().borders
  flow = isSpectatorMode.get() ? FLOW_HORIZONTAL : FLOW_VERTICAL
  valign = ALIGN_BOTTOM
  halign = ALIGN_LEFT
  gap = scrn_tgt(0.005)
  children = isSpectatorMode.get() ? [hudLogs, shipMainPanel] : [
    voiceChat
    activeOrderComps
    hudLogs
    shipMainPanel
  ]
}

return @(){
  size = FLEX
  watch = isPlayingReplay
  children = isPlayingReplay.get() ? [
    sensorViewIndicators
    shipHud
  ] :
  [
    shipHud
    actionBarTopPanel
    fireControl
    radarComponent





    hitNotifications
    aamAim(colorWacthed, colorAlertWatched)
    shipObstacleRf
    sensorViewIndicators
  ]
}
