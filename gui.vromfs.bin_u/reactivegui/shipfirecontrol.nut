import "%rGui/fcsState.nut" as fcsState
import "%rGui/compass.nut" as compass
import "%rGui/shipTorpedoStatus.nut" as torpedoWeaponsStatus
from "%rGui/compassState.nut" import CompassValue
from "%rGui/style/airHudStyle.nut" import greenColor, greenColorGrid
from "%rGui/shipState.nut" import fov, gunStatesFirstNumber, gunStatesSecondNumber, artilleryType
from "%rGui/radarState.nut" import IsRadarVisible
from "%rGui/fcsComponent.nut" import drawArrow
from "%rGui/shipFireControlCommon.nut" import mkActionBarPanel
from "%rGui/shipStateConsts.nut" import FIRST_ROW_SIGNAL_TRIGGER, SECOND_ROW_SIGNAL_TRIGGER
from "%rGui/shipGunStatus.nut" import mkWeaponsStatus
from "%sqstd/math.nut" import PI, fabs, sqrt
from "%rGui/globals/ui_library.nut" import *
from "%globalScripts/weaponConsts.nut" import *

let { gunStatesFirstRow, gunStatesSecondRow } = require("%rGui/shipState.nut")

const redColor = Color(255, 109, 108, 255)
const greyColor = Color(15, 25, 25, 255)
const highlightColor = Color(255, 255, 255, 180)
const highlightScale = 2.5
let compassSize = [hdpx(500), hdpx(32)]
let compassPos = [sw(50) - 0.5 * compassSize[0], sh(0.5)]
const rangefinderProgressBarColor1 = Color(0, 255, 0, 255)
const rangefinderProgressBarColor2 = Color(100, 100, 100, 50)
const firstGunsRowHeight = hdpx(38)
const secondGunsRowHeight = hdpx(32)
const weaponGroupsGap = hdpx(20)

let compassComponent = {
  pos = compassPos
  children = compass(compassSize, greenColor)
}

let progressBarContent = {
  halign = ALIGN_RIGHT
  children = {
    children = [
      @() {
        watch = fcsState.CalcProgress
        size = FLEX
        opacity = 0.25
        fValue = fcsState.CalcProgress.get()
        rendObj = ROBJ_PROGRESS_LINEAR
        fgColor = rangefinderProgressBarColor1
        bgColor = rangefinderProgressBarColor2
      }
      @() {
        watch = fcsState.IsTargetDataAvailable
        isHidden = !fcsState.IsTargetDataAvailable.get()
        size = const [SIZE_TO_CONTENT, sh(2)]
        padding = const [0, hdpx(5)]
        color = Color(0, 0, 0, 255)
        valign = ALIGN_CENTER
        rendObj = ROBJ_INSCRIPTION
        font = Fonts.tiny_text_hud
        text = loc("updating_range")
      }
      @() {
        watch = fcsState.IsTargetDataAvailable
        isHidden = fcsState.IsTargetDataAvailable.get()
        size = const [SIZE_TO_CONTENT, sh(2)]
        padding = const [0, hdpx(5)]
        color = Color(0, 0, 0, 255)
        valign = ALIGN_CENTER
        halign = ALIGN_RIGHT
        rendObj = ROBJ_INSCRIPTION
        font = Fonts.tiny_text_hud
        text = loc("measuring_range")
      }
    ]
  }
}

let progressBar = @() {
  watch = [fcsState.OpticsWidth, fcsState.StaticFov]
  pos = [sw(52) + fcsState.OpticsWidth.get(), fcsState.StaticFov.get() > 6. ? sh(56.5) : sh(55)]
  children = progressBarContent
}

function drawDashLineToCircle(fromX, fromY, toX, toY, radius) {
  local dirX = (toX - fromX)
  local dirY = (toY - fromY)
  let len = sqrt(dirX * dirX + dirY * dirY)
  if (len < radius / 2)
    return null

  dirX = dirX / len * radius / 2
  dirY = dirY / len * radius / 2

  return {
    rendObj = ROBJ_VECTOR_CANVAS
    size = const [sw(100), sh(100)]
    lineWidth = hdpx(3)
    color = greenColorGrid
    fillColor = Color(0, 0, 0, 0)
    commands = [[
      VECTOR_LINE_DASHED,
      fromX / sw(100) * 100,
      fromY / sh(100) * 100,
      (toX - dirX) / sw(100) * 100,
      (toY - dirY) / sh(100) * 100,
      hdpx(1),
      hdpx(12)
    ]]
  }
}

let crosshairZeroMark = {
  children = [
    drawArrow(sw(50), sh(50), 0, 1.6, highlightColor, false, highlightScale)
    drawArrow(sw(50), sh(50), 0, 1.6, greyColor)
  ]
}

let crosshairZeroMarkMatch = {
  children = [
    drawArrow(sw(50), sh(50), 0, 1.6, highlightColor, false, highlightScale)
    drawArrow(sw(50), sh(50), 0, 1.6, greenColorGrid)
  ]
}

function drawForestallIndicator(
  forestallX,
  forestallY,
  targetX,
  targetY,
  pitchDelta,
  yawDelta,
  showVertical,
  showHorizontal,
  showMarker,
  showProgress,
  showCentral) {

  const circleSize = sh(4)
  const angleThreshold = 2
  const verticalOffset = -sh(35.1)

  let isPitchMatch = fabs(pitchDelta) < angleThreshold
  let isYawMatch = fabs(yawDelta) < angleThreshold
  let indicatorElements = [ ]

  if (showCentral) {
    let centralArrow = isYawMatch ? crosshairZeroMarkMatch : crosshairZeroMark
    indicatorElements.append(centralArrow)
  }
  if (showMarker) {
    indicatorElements.append({
      rendObj = ROBJ_VECTOR_CANVAS
      size = const [circleSize, circleSize]
      pos = [forestallX - circleSize * 0.5, forestallY - circleSize * 0.5]
      color = greenColorGrid
      fillColor =  Color(0, 0, 0, 0)
      commands = [[VECTOR_ELLIPSE, 50, 50, 50, 50]]
    },
    drawDashLineToCircle(targetX, targetY, forestallX, forestallY, circleSize))
    if (showProgress)
      indicatorElements.append(
        @() {
          watch = fcsState.CalcProgress
          rendObj = ROBJ_VECTOR_CANVAS
          size = const [circleSize * 0.7, circleSize * 0.7]
          pos = [forestallX - circleSize * 0.35, forestallY - circleSize * 0.35]
          color = greenColorGrid
          fillColor =  Color(0, 0, 0, 0)
          commands = [[VECTOR_SECTOR, 50, 50, 50, 50, -90, -90 + fcsState.CalcProgress.get() * 360]]})
  }
  if (showHorizontal) {
    indicatorElements.append(drawArrow(forestallX, sh(50), 0, -1, isYawMatch ? greenColorGrid : redColor))
  }
  if (showVertical) {
    indicatorElements.append(
      drawArrow(sw(50) + verticalOffset, forestallY, -1, 0, isPitchMatch ? greenColorGrid : redColor),
      drawArrow(sw(50) + verticalOffset - sh(1), sh(50), 1, 0, isPitchMatch ? greenColorGrid : greyColor, true))
  }

  return indicatorElements
}

let forestallIndicator = @() {
  watch = [
    fcsState.ForestallPosX,
    fcsState.ForestallPosY,
    fcsState.TargetPosX,
    fcsState.TargetPosY,
    fcsState.ForestallPitchDelta,
    fcsState.ForestallAzimuth,
    fcsState.IsBinocular,
    CompassValue,
    fov,
    fcsState.IsHorizontalAxisVisible,
    fcsState.IsVerticalAxisVisible,
    fcsState.IsForestallMarkerVisible
  ]
  children = drawForestallIndicator(
    fcsState.ForestallPosX.get(),
    fcsState.ForestallPosY.get(),
    fcsState.TargetPosX.get(),
    fcsState.TargetPosY.get(),
    fcsState.ForestallPitchDelta.get() * PI / fov.get(),
    (CompassValue.get() - fcsState.ForestallAzimuth.get()) * PI / fov.get(),
    fcsState.IsBinocular.get() && fcsState.IsHorizontalAxisVisible.get(),
    fcsState.IsBinocular.get() && fcsState.IsVerticalAxisVisible.get(),
    fcsState.IsForestallMarkerVisible.get(),
    !fcsState.IsBinocular.get(),
    fcsState.IsBinocular.get())
}

function getWeaponsStatusChildren() {
  let artType = artilleryType.get()
  let firstRowIcon = artType == TRIGGER_GROUP_PRIMARY     ? "!ui/gameuiskin#artillery_weapon_state_indicator.svg"
                   : artType == TRIGGER_GROUP_SECONDARY   ? "!ui/gameuiskin#artillery_secondary_weapon_state_indicator.svg"
                   : artType == TRIGGER_GROUP_MACHINE_GUN ? "!ui/gameuiskin#machine_gun_weapon_state_indicator.svg"
                   : "!ui/gameuiskin#artillery_weapon_state_indicator.svg"

  let hasSecondRow = gunStatesSecondNumber.get() > 0

  local childrens = [
    {
      gap = weaponGroupsGap
      flow = FLOW_HORIZONTAL
      valign = ALIGN_CENTER
      children = [
        mkWeaponsStatus(firstGunsRowHeight, gunStatesFirstNumber.get(), gunStatesFirstRow, firstRowIcon, FIRST_ROW_SIGNAL_TRIGGER)
        torpedoWeaponsStatus
      ]
    }
  ]
  if (hasSecondRow) {
    childrens.append(mkWeaponsStatus(secondGunsRowHeight, gunStatesSecondNumber.get(), gunStatesSecondRow, "!ui/gameuiskin#artillery_secondary_weapon_state_indicator.svg", SECOND_ROW_SIGNAL_TRIGGER))
  }

  return childrens
}

let weaponsStatus = mkActionBarPanel(getWeaponsStatusChildren,
  [gunStatesFirstNumber, gunStatesSecondNumber, artilleryType],
  { gap = hdpx(11), flow = FLOW_VERTICAL })


let root = @() {
  watch = [fcsState.IsForestallVisible, fcsState.IsBinocular, IsRadarVisible, fcsState.IsTargetSelected, fcsState.IsAutoAim]
  children = [
    !IsRadarVisible.get() ? compassComponent : null
    fcsState.IsForestallVisible.get() ? forestallIndicator
        : (fcsState.IsBinocular.get() ? crosshairZeroMark : null)
    fcsState.IsBinocular.get() && fcsState.IsTargetSelected.get() && !fcsState.IsAutoAim.get() ? progressBar : null
  ]
}

return @() {
  watch = [fcsState.IsVisible, fcsState.IsBinocular]
  halign = ALIGN_LEFT
  valign = ALIGN_TOP
  size = const [sw(100), SIZE_TO_CONTENT]
  children = fcsState.IsVisible.get() ? [root, weaponsStatus]
    : fcsState.IsBinocular.get() ? [crosshairZeroMark, weaponsStatus]
    : weaponsStatus
}
