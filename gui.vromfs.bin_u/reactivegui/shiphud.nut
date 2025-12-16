from "%rGui/globals/ui_library.nut" import *

let activeOrder = require("%rGui/activeOrder.nut")
let shipStateModule = require("%rGui/shipStateModule.nut")
let hudLogs = require("%rGui/hudLogs.nut")
let voiceChat = require("%rGui/chat/voiceChat.nut")
let { safeAreaSizeHud } = require("%rGui/style/screenState.nut")
let fireControl = require("%rGui/shipFireControl.nut")
let { missionProgressHeight, isSpectatorMode, isPlayingReplay } = require("%rGui/hudState.nut")
let { radarComponent, sonarComponent } = require("%rGui/shipHudComponents.nut")
let { actionBarTopPanel } = require("%rGui/hud/actionBarTopPanel.nut")
let shipObstacleRf = require("%rGui/shipObstacleRangefinder.nut")
let aamAim = require("%rGui/rocketAamAim.nut")
let { hitNotifications } = require("%rGui/shipHitNotification.nut")
let sensorViewIndicators = require("%rGui/hud/sensorViewIndicator.nut")

let greenColor = Color(10, 202, 10, 250)
let redColor = Color(255, 35, 30, 255)
let colorWacthed = Watched(greenColor)
let colorAlertWatched = Watched(redColor)

let shipHud = @() {
  watch = [safeAreaSizeHud, missionProgressHeight, isSpectatorMode]
  size = FLEX_V
  padding = [0, 0, missionProgressHeight.get(), 0]
  margin = safeAreaSizeHud.get().borders
  flow = FLOW_VERTICAL
  valign = ALIGN_BOTTOM
  halign = ALIGN_LEFT
  gap = scrn_tgt(0.005)
  children = isSpectatorMode.get() ? null : [
    voiceChat
    activeOrder
    hudLogs
    shipStateModule
  ]
}

return @(){
  size = flex()
  watch = isPlayingReplay
  children = isPlayingReplay.get() ? [
    sensorViewIndicators
  ] :
  [
    shipHud
    actionBarTopPanel
    fireControl
    radarComponent
    sonarComponent
    hitNotifications
    aamAim(colorWacthed, colorAlertWatched)
    shipObstacleRf
    sensorViewIndicators
  ]
}
