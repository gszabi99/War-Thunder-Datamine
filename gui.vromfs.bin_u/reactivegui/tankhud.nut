from "%rGui/globals/ui_library.nut" import *

let { round } = require("math")
let { eventbus_send } = require("eventbus")
let { mkRadar } = require("%rGui/radarComponent.nut")
let aamAim = require("%rGui/rocketAamAim.nut")
let agmAim = require("%rGui/agmAim.nut")
let { actionBarTopPanel } = require("%rGui/hud/actionBarTopPanel.nut")
let { tws } = require("%rGui/tws.nut")
let { IsMlwsLwsHudVisible, CollapsedIcon } = require("%rGui/twsState.nut")
let sightIndicators = require("%rGui/hud/tankSightIndicators.nut")
let activeProtectionSystem = require("%rGui/hud/activeProtectionSystem.nut")
let { needShowDmgIndicator, isPlayingReplay, isSpectatorMode,
  isMissionProgressVisible } = require("%rGui/hudState.nut")
let { IndicatorsVisible } = require("%rGui/hud/tankState.nut")
let { lockSight, targetSize } = require("%rGui/hud/targetTracker.nut")
let { bw, bh } = require("%rGui/style/screenState.nut")
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
let { mkScreenHitMark } = require("%rGui/hud/hitMarks.nut")
let { tankDebuffs } = require("%rGui/hud/tankHudDebuffs.nut")
let { dmgIndicatorWidth } = require("%rGui/hud/tankDmgIndicatorState.nut")

let greenColor = Color(10, 202, 10, 250)
let redColor = Color(255, 35, 30, 255)

let styleAamAim = {
  color = greenColor
  fillColor = Color(0, 0, 0, 0)
  lineWidth = hdpx(2.0)
}

let radarPosComputed = Computed(@() isPlayingReplay.get() ? [bw.get() + sw(12), bh.get() + sh(5)] : [bw.get(), bh.get()])

let missionProgressHeight = round(32 * max(sh(100) / 1080, 1) + hdpx(6))

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
    


    tankDebuffs
  ]
  if (IsMlwsLwsHudVisible.get())
    children.append(tws({
      colorWatched = colorWacthed,
      posWatched = Watched([0, 0]),
      sizeWatched = Computed(@() [dmgIndicatorWidth.get() * 0.8, dmgIndicatorWidth.get() * 0.8]),
      relativCircleSize = 49,
      needDrawCentralIcon = false,
      needDrawBackground =  true,
      needAdditionalLights = false
    }))
  return {
    rendObj = ROBJ_IMAGE
    watch = [ IsMlwsLwsHudVisible, needShowDmgIndicator, dmgIndicatorWidth ]
    size = dmgIndicatorWidth.get()
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    image = Picture($"ui/gameuiskin/bg_dmg_board.svg:{dmgIndicatorWidth.get()}:{dmgIndicatorWidth.get()}")
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

function missionProgressPanel() {
  if (!isMissionProgressVisible.get())
    return {watch = isMissionProgressVisible}
  return {
    watch = isMissionProgressVisible
    size = [pw(100), missionProgressHeight]
  }
}

let leftPanel = @() {
  size = FLEX_V
  watch = [bw, bh, isSpectatorMode, isAAComplexMenuActive]
  margin = [bh.get(), 0, bh.get(), bw.get()]
  flow = FLOW_VERTICAL
  vplace = ALIGN_TOP
  valign = ALIGN_BOTTOM
  halign = ALIGN_LEFT
  gap = hdpx(10)
  children = isSpectatorMode.get() ? null
    : isAAComplexMenuActive.get() ? [
        voiceChat
        tankDmgIndicator
        missionProgressPanel
      ]
    : [
        voiceChat
        activeOrder
        hudLogs
        tankDmgIndicator
        missionProgressPanel
      ]
}

let hitPanel = {
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  size = flex()
  children = mkScreenHitMark
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
      hitPanel
      aaComplexMenu
      actionBarTopPanel
      leftPanel
    ]
    :[
      hitPanel
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
              }, true)
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