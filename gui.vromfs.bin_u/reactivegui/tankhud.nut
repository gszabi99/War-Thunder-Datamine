from "%rGui/globals/ui_library.nut" import *

let { eventbus_send } = require("eventbus")
let { mkRadar } = require("%rGui/radarComponent.nut")
let aamAim = require("%rGui/rocketAamAim.nut")
let agmAim = require("%rGui/agmAim.nut")
let { actionBarTopPanel } = require("%rGui/hud/actionBarTopPanel.nut")
let { tws } = require("%rGui/tws.nut")
let { IsMlwsLwsHudVisible, CollapsedIcon } = require("%rGui/twsState.nut")
let sightIndicators = require("%rGui/hud/tankSightIndicators.nut")
let activeProtectionSystem = require("%rGui/hud/activeProtectionSystem.nut")
let { needShowDmgIndicator, dmgIndicatorStates, isPlayingReplay, isSpectatorMode
} = require("%rGui/hudState.nut")
let { IndicatorsVisible } = require("%rGui/hud/tankState.nut")
let { lockSight, targetSize } = require("%rGui/hud/targetTracker.nut")
let { bw, bh, safeAreaSizeHud } = require("%rGui/style/screenState.nut")
let { AzimuthRange, IsRadarVisible, IsRadar2Visible, IsRadarHudVisible, IsCScopeVisible, IsBScopeVisible, isCollapsedRadarInReplay } = require("%rGui/radarState.nut")
let { PI } = require("%sqstd/math.nut")
let { radarHud, radarIndication } = require("%rGui/radar.nut")
let sensorViewIndicators = require("%rGui/hud/sensorViewIndicator.nut")
let { mkCollapseButton } = require("%rGui/airHudComponents.nut")
let mkTankSight = require("%rGui/tankSight.nut")
let { aaComplexMenu } = require("%rGui/antiAirComplexMenu/antiAirComplexMenu.nut")
let { isAAComplexMenuActive } = require("%appGlobals/hud/hudState.nut")




let activeOrder = require("%rGui/activeOrder.nut")
let voiceChat = require("%rGui/chat/voiceChat.nut")
let hudLogs = require("%rGui/hudLogs.nut")

let greenColor = Color(10, 202, 10, 250)
let redColor = Color(255, 35, 30, 255)

let styleAamAim = {
  color = greenColor
  fillColor = Color(0, 0, 0, 0)
  lineWidth = hdpx(2.0)
}

let radarPosComputed = Computed(@() isPlayingReplay.get() ? [bw.get() + sw(12), bh.get() + sh(5)] : [bw.get(), bh.get()])

let tankXrayIndicator = @() {
  rendObj = ROBJ_XRAYDOLL
  rotateWithCamera = true
  size = const [pw(62), ph(62)]
}

let xraydoll = {
  rendObj = ROBJ_XRAYDOLL     
  size = 1
}

function tankDmgIndicator() {
  if (!needShowDmgIndicator.get())
    return {
      watch = needShowDmgIndicator
      children = xraydoll
    }

  let colorWacthed = Watched(greenColor)
  let children = [
    tankXrayIndicator,
    activeProtectionSystem,
    


  ]
  if (IsMlwsLwsHudVisible.get())
    children.append(tws({
      colorWatched = colorWacthed,
      posWatched = Watched([0, 0]),
      sizeWatched = Computed(@() dmgIndicatorStates.get().size.map(@(v) 0.8*v)),
      relativCircleSize = 49,
      needDrawCentralIcon = false,
      needDrawBackground =  true,
      needAdditionalLights = false
    }))
  return {
    rendObj = ROBJ_IMAGE
    watch = [ IsMlwsLwsHudVisible, needShowDmgIndicator, dmgIndicatorStates ]
    pos = dmgIndicatorStates.get()?.pos ?? [0, 0]
    size = dmgIndicatorStates.get().size
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    image = Picture($"ui/gameuiskin/bg_dmg_board.svg:{dmgIndicatorStates.get().size[0]}:{dmgIndicatorStates.get().size[1]}")
    children
    behavior = Behaviors.RecalcHandler
    function onRecalcLayout(_initial, elem) {
      if (elem.getWidth() > 1 && elem.getHeight() > 1) {
        eventbus_send("update_damage_panel_state", {
          pos = [elem.getScreenPosX(), elem.getScreenPosY()]
          size = [elem.getWidth(), elem.getHeight()]
          visible = needShowDmgIndicator.get()
        })
      }
      else
        eventbus_send("update_damage_panel_state", {})
    }
  }
}

let leftPanelGap = hdpx(10)

let leftPanel = @() {
  size = FLEX_V
  watch = [safeAreaSizeHud, isSpectatorMode, isAAComplexMenuActive,
    needShowDmgIndicator, dmgIndicatorStates]
  margin = [safeAreaSizeHud.get().borders[0], 0,
    needShowDmgIndicator.get()
      ? sh(100) - (dmgIndicatorStates.get()?.pos[1] ?? 0) + leftPanelGap
      : safeAreaSizeHud.get().borders[0],
    safeAreaSizeHud.get().borders[1]]
  flow = FLOW_VERTICAL
  vplace = ALIGN_TOP
  valign = ALIGN_BOTTOM
  halign = ALIGN_LEFT
  gap = leftPanelGap
  children = isSpectatorMode.get() ? null
    : isAAComplexMenuActive.get() ? voiceChat
    : [
        voiceChat
        activeOrder
        hudLogs
      ]
}

let radarPic = Picture("!ui/gameuiskin#radar_stby_icon")
let isBScope = Computed(@() AzimuthRange.get() > PI)
let needRadarCollapsedIcon = Computed(@() IsRadarHudVisible.get() && ((!IsRadarVisible.get() && !IsRadar2Visible.get()) || isCollapsedRadarInReplay.get()) &&
 CollapsedIcon.get() && (IsCScopeVisible.get() || IsBScopeVisible.get()))
function Root() {
  let colorWacthed = Watched(greenColor)
  let colorAlertWatched = Watched(redColor)
  let radarColor = Watched(Color(0, 255, 0, 255))
  return {
    halign = ALIGN_LEFT
    valign = ALIGN_TOP
    watch = [IndicatorsVisible, isBScope, isAAComplexMenuActive]
    size = const [sw(100), sh(100)]
    children = isAAComplexMenuActive.get() ?
    [
      aaComplexMenu
      tankDmgIndicator
      actionBarTopPanel
      leftPanel
    ]
    :[
      mkRadar()
      @(){
        watch = needRadarCollapsedIcon
        children = needRadarCollapsedIcon.get() ? @(){
            watch = isPlayingReplay
            pos = [radarPosComputed.get()[0] + sw(10), radarPosComputed.get()[1] + (isPlayingReplay.get() ? sh(5) : 0) ]
            size = sh(5)
            rendObj = ROBJ_IMAGE
            image = radarPic
            color = radarColor.get()
            children = isPlayingReplay.get() ? mkCollapseButton([sh(5), sh(1)], isCollapsedRadarInReplay) : null
          } : null
      }
      aamAim(colorWacthed, colorAlertWatched)
      agmAim(colorWacthed, colorAlertWatched)
      tankDmgIndicator
      actionBarTopPanel
      sensorViewIndicators
      mkTankSight()
      


      @(){
        watch = [isCollapsedRadarInReplay, isPlayingReplay]
        size = flex()
        children = !isCollapsedRadarInReplay.get()
          ? [
              radarHud(isBScope.get() ? sh(40) : sh(32), isBScope.get() ? sh(40) : sh(32), radarPosComputed.get()[0], radarPosComputed.get()[1], radarColor, {
                hasTxtBlock = true
              })
              isPlayingReplay.get() ? mkCollapseButton([radarPosComputed.get()[0] + (isBScope.get() ? sh(40) : sh(32)), radarPosComputed.get()[1]], isCollapsedRadarInReplay) : null
            ]
          : null
      }
      radarIndication(radarColor, true)
      IndicatorsVisible.get()
        ? @() {
            children = [
              sightIndicators(styleAamAim, colorWacthed)
              lockSight(colorWacthed, hdpx(150), hdpx(100), sw(50), sh(50))
              targetSize(colorWacthed, sw(100), sh(100), false)
            ]
          }
        : null
      leftPanel
    ]
  }
}

return Root