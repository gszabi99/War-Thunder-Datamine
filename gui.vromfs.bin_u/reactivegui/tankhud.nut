import "%rGui/rocketAamAim.nut" as aamAim
import "%rGui/agmAim.nut" as agmAim
import "%rGui/hud/tankSightIndicators.nut" as sightIndicators
import "%rGui/hud/activeProtectionSystem.nut" as activeProtectionSystem
import "%rGui/tankSight.nut" as mkTankSight
import "%rGui/chat/voiceChat.nut" as voiceChat
import "%rGui/hudLogs.nut" as hudLogs
from "%rGui/radarComponent.nut" import mkRadar
from "%rGui/hud/actionBarTopPanel.nut" import actionBarTopPanel
from "%rGui/tws.nut" import tws
from "%rGui/twsState.nut" import IsMlwsLwsHudVisible, CollapsedIcon
from "%rGui/hudState.nut" import needShowDmgIndicator, isPlayingReplay, isSpectatorMode, isMissionProgressVisible
from "%rGui/hud/tankState.nut" import IndicatorsVisible
from "%rGui/hud/targetTracker.nut" import lockSight, targetSize
from "%rGui/style/screenState.nut" import bw, bh
from "%rGui/radarState.nut" import AzimuthRange, IsRadarVisible, IsRadar2Visible, IsRadarHudVisible, IsCScopeVisible, IsBScopeVisible, isCollapsedRadarInReplay
from "%rGui/radar.nut" import radarHud, radarIndication
from "%rGui/airHudComponents.nut" import mkCollapseButton
from "%appGlobals/hud/hudState.nut" import isAAComplexMenuActive
from "%rGui/activeOrder.nut" import activeOrderComps
from "%rGui/hud/hitMarks.nut" import mkScreenHitMark
from "%rGui/hud/tankHudDebuffs.nut" import tankDebuffs
from "%rGui/hud/dmgIndicatorState.nut" import dmgIndicatorWidth, updateDmgIndicatorElement
from "math" import round
from "%sqstd/math.nut" import PI
from "%rGui/globals/ui_library.nut" import *
from "%globalScripts/gameRendObjs.nut" import *

let sensorViewIndicators = require("%rGui/hud/sensorViewIndicator.nut")
let { aaComplexMenu } = require("%rGui/antiAirComplexMenu/antiAirComplexMenu.nut")





const greenColor = Color(10, 202, 10, 250)
const redColor = Color(255, 35, 30, 255)

let styleAamAim = {
  color = greenColor
  fillColor = Color(0, 0, 0, 0)
  lineWidth = hdpx(2.0)
}

let radarPosComputed = Computed(@() isPlayingReplay.get() ? [bw.get() + sw(12), bh.get() + sh(5)] : [bw.get(), bh.get()])

const missionProgressHeight = round(32 * max(sh(100) / 1080, 1) + hdpx(6))

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
    onRecalcLayout = updateDmgIndicatorElement
  }
}

function missionProgressPanel() {
  if (!isMissionProgressVisible.get())
    return {watch = isMissionProgressVisible}
  return {
    watch = isMissionProgressVisible
    size = const [pw(100), missionProgressHeight]
  }
}

let leftPanel = @() {
  size = FLEX_V
  watch = [bw, bh, isSpectatorMode, isAAComplexMenuActive]
  margin = [bh.get(), 0, bh.get(), bw.get()]
  flow = isSpectatorMode.get() ? FLOW_HORIZONTAL : FLOW_VERTICAL
  vplace = ALIGN_TOP
  valign = ALIGN_BOTTOM
  halign = ALIGN_LEFT
  gap = hdpx(10)
  children = isSpectatorMode.get() ? [hudLogs, tankDmgIndicator]
    : isAAComplexMenuActive.get() ? [
        voiceChat
        tankDmgIndicator
        missionProgressPanel
      ]
    : [
        voiceChat
        activeOrderComps
        hudLogs
        tankDmgIndicator
        missionProgressPanel
      ]
}

let hitPanel = {
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  size = FLEX
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
            watch = [isPlayingReplay, radarPosComputed]
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
        size = FLEX
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