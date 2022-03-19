local interopGen = require("interopGen.nut")
local compass = require("compass.nut")
local {PI, cos, sin, fabs, sqrt} = require("std/math.nut")
local {CompassValue} = require("compassState.nut")
local {greenColor, greenColorGrid} = require("style/airHudStyle.nut")
local {fwdAngle, fov} = require("shipState.nut")
local {IsRadarVisible} = require("radarState.nut")

local redColor = Color(255, 109, 108, 255)
local greyColor = Color(45, 60, 60, 255)
local highlightColor = Color(255, 255, 255, 255)
local highlightScale = 1.5
local compassSize = [hdpx(500), hdpx(32)]
local compassPos = [sw(50) - 0.5 * compassSize[0], sh(0.5)]
local fcsWidth = sh(28)
local isExtraElementVisible = false
local rangefinderProgressBarColor1 = Color(0, 255, 0, 255)
local rangefinderProgressBarColor2 = Color(100, 100, 100, 50)

local fcsState = {
  IsVisible = Watched(false)
  IsBinocular = Watched(false)
  OpticsWidth = Watched(0.0)
  StaticFov = Watched(0.0)
  CalcProgress = Watched(-1.0)

  IsTargetSelected = Watched(false)
  IsTargetDataAvailable = Watched(false)
  TargetFwdDir = Watched(0.0)
  TargetSpeed = Watched(0.0)
  TargetAzimuth = Watched(0.0)

  IsForestallVisible = Watched(false)
  IsHorizontalAxisVisible = Watched(true)
  IsVerticalAxisVisible = Watched(true)
  IsForestallMarkerVisible = Watched(true)
  ForestallAzimuth = Watched(0.0)
  ForestallAzimuthWidth = Watched(0.0)
  ForestallPitchDelta = Watched(0.0)
  ForestallPosX = Watched(0.0)
  ForestallPosY = Watched(0.0)
  TargetPosX = Watched(0.0)
  TargetPosY = Watched(0.0)
}

interopGen({
  stateTable = fcsState
  prefix = "fcs"
  postfix = "Update"
})

local compassComponent = {
  pos = compassPos
  children = compass(compassSize, greenColor)
}

local background = {
  rendObj = ROBJ_VECTOR_CANVAS
  size = [fcsWidth, fcsWidth]
  color = greenColorGrid
  fillColor = Color(0,32,0,120)
  lineWidth = hdpx(LINE_WIDTH)
  commands = [
    [VECTOR_ELLIPSE, 50, 50, 50, 50]
  ]
}

local function mkDashes(width, centerX, centerY, radius, angleStart, angleFinish, length, count) {
  local dashCommands = []

  local startRad = angleStart * PI / 180.0;
  local finishRad = angleFinish * PI / 180.0;
  local dAngle = (finishRad - startRad) / (count + 1)

  for (local i = 0; i < count; ++i) {
    local angle = startRad + (i + 1) * dAngle
    local cosA = cos(angle)
    local sinA = sin(angle)
    local dashStartX = centerX + (radius - length) * cosA
    local dashStartY = centerY + (radius - length) * sinA
    local dashFinishX = centerX + (radius) * cosA
    local dashFinishY = centerY + (radius) * sinA
    dashCommands.append([VECTOR_LINE, dashStartX, dashStartY, dashFinishX, dashFinishY])
  }

  return {
    rendObj = ROBJ_VECTOR_CANVAS
    size = [width, width]
    color = greenColorGrid
    lineWidth = max(hdpx(LINE_WIDTH), LINE_WIDTH)
    commands = dashCommands
  }
}

local centerX1 = 50
local centerY1 = 80
local centerX2 = 50
local centerY2 = -3
local radius1 = 25
local radius2 = 60
local angle1 = 140.0
local angle2 = 250.0
local angle3 = 290.0
local angle4 = 400.0
local angle5 = 38.0
local angle6 = 142.0

local fcsMarkers = {
  rendObj = ROBJ_VECTOR_CANVAS
  size = [fcsWidth, fcsWidth]
  color = greenColorGrid
  fillColor = Color(0, 0, 0, 0)
  lineWidth = max(hdpx(LINE_WIDTH), LINE_WIDTH)
  commands = [
    [VECTOR_SECTOR, centerX1, centerY1, radius1, radius1, angle1, angle2],
    [VECTOR_SECTOR, centerX1, centerY1, radius1, radius1, angle3, angle4],
    [VECTOR_SECTOR, centerX2, centerY2, radius2, radius2, angle5, angle6]
  ]
  children = [
    mkDashes(fcsWidth, centerX1, centerY1, radius1, angle1, angle2, 2, 5)
    mkDashes(fcsWidth, centerX1, centerY1, radius1, angle3, angle4, 2, 5)
    mkDashes(fcsWidth, centerX2, centerY2, radius2, angle5, angle6, 2, 9)
  ]
}

local function drawShipIcon(iconSize, iconPos, iconColor, absBearing) {
  return {
    rendObj = ROBJ_VECTOR_CANVAS
    size = iconSize
    pos = iconPos
    color = iconColor
    transform = {
      pivot = [0.5, 0.5]
      rotate = absBearing.value - fcsState.TargetAzimuth.value
    }
    lineWidth = hdpx(LINE_WIDTH)
    commands = [
      [VECTOR_LINE, 40, 100, 40, 10],
      [VECTOR_LINE, 40, 10, 50, 0],
      [VECTOR_LINE, 50, 0, 60, 10],
      [VECTOR_LINE, 60, 10, 60, 100],
      [VECTOR_LINE, 60, 100, 40, 100]
    ]
  }
}

local targetSpeed = @() {
  watch = fcsState.TargetSpeed
  rendObj = ROBJ_DTEXT
  text = ::cross_call.measureTypes.SPEED.getMeasureUnitsText(fcsState.TargetSpeed.value)
  font = Fonts.tiny_text_hud
  pos = [0, sh(1)]
  color = greenColorGrid
  margin = [0,0,0,sh(1)]
}

local progress = @() {
  watch = [fcsState.CalcProgress, fcsState.IsTargetDataAvailable]
  rendObj = ROBJ_VECTOR_CANVAS
  size = [fcsWidth, fcsWidth]
  color = greenColorGrid
  fillColor =  Color(0, 0, 0, 0)
  lineWidth = hdpx(LINE_WIDTH) * (fcsState.IsTargetDataAvailable.value ? 1.5 : 3)
  commands = [
    [VECTOR_SECTOR, 50, 50, 50, 50, -90, -90 + fcsState.CalcProgress.value * 360],
  ]
}

local roundIndicator = @() {
  pos = [sh(4), sh(18)]
  halign = ALIGN_CENTER
  watch = [fcsState.TargetAzimuth, fwdAngle, fcsState.IsTargetSelected, fcsState.IsTargetDataAvailable, fcsState.TargetFwdDir]
  children = [
    background
    fcsState.IsTargetSelected.value ? progress : null
    fcsMarkers
    drawShipIcon([sh(8), sh(8)], [0, sh(18)], greenColorGrid, fwdAngle)
    fcsState.IsTargetDataAvailable.value ? drawShipIcon([sh(14), sh(14)], [0, sh(1)], Color(255, 128, 32, 255), fcsState.TargetFwdDir) : null
    fcsState.IsTargetDataAvailable.value ? targetSpeed : null
  ]
}

local progressBar = @() {
  watch = [fcsState.OpticsWidth, fcsState.StaticFov]
  pos = [sw(50) + fcsState.OpticsWidth.value, fcsState.StaticFov.value > 6. ? sh(54.5) : sh(53)]
  children = {
    halign = ALIGN_RIGHT
    size = flex()
    children = {
      children = [
        @() {
          watch = fcsState.CalcProgress
          size = flex()
          opacity = 0.25
          fValue = fcsState.CalcProgress.value
          rendObj = ROBJ_PROGRESS_LINEAR
          fgColor = rangefinderProgressBarColor1
          bgColor = rangefinderProgressBarColor2
        }
        @() {
          watch = fcsState.IsTargetDataAvailable
          isHidden = !fcsState.IsTargetDataAvailable.value
          size = [SIZE_TO_CONTENT, sh(2)]
          padding = [0, 5]
          color = Color(0, 0, 0, 255)
          valign = ALIGN_CENTER
          rendObj = ROBJ_STEXT
          font = Fonts.tiny_text_hud
          text = ::loc("updating_range")
        }
        @() {
          watch = fcsState.IsTargetDataAvailable
          isHidden = fcsState.IsTargetDataAvailable.value
          size = [flex(), sh(2)]
          color = Color(0, 0, 0, 255)
          valign = ALIGN_CENTER
          halign = ALIGN_RIGHT
          rendObj = ROBJ_STEXT
          font = Fonts.tiny_text_hud
          text = ::loc("measuring_range")
        }
      ]
    }
  }
}

local function drawArrow(x, y, dirX, dirY, color, fill=false, scale=1) {
  local arrowSize = sh(2)
  local arrowCommands = []

  if (fill) {
    arrowCommands = dirX == 0
      ? [[VECTOR_POLY, 0, 0, 25, dirY * 50, -25, dirY * 50]]
      : [[VECTOR_POLY, 0, 0, -dirX * 50, 25, -dirX * 50, -25]]
  } else {
    arrowCommands = dirX == 0 ? [
        [VECTOR_LINE, 0, dirY * 5, 25,  dirY * 55],
        [VECTOR_LINE, 0, dirY * 5, -25, dirY * 55]
      ] : [
        [VECTOR_LINE, -dirX * 5, 0, -dirX * 55, 25],
        [VECTOR_LINE, -dirX * 5, 0, -dirX * 55, -25]
      ]
  }

  return {
    rendObj = ROBJ_VECTOR_CANVAS
    size = [arrowSize, arrowSize]
    pos = [x, y]
    lineWidth = hdpx(2 * scale)
    color = color
    fillColor = fill ? color : Color(0, 0, 0, 0)
    commands = arrowCommands
  }
}

local function drawDashLineToCircle(fromX, fromY, toX, toY, radius) {
  local dirX = (toX - fromX)
  local dirY = (toY - fromY)
  local len = sqrt(dirX * dirX + dirY * dirY)
  if (len < radius / 2)
    return null

  dirX = dirX / len * radius / 2
  dirY = dirY / len * radius / 2

  return {
    rendObj = ROBJ_VECTOR_CANVAS
    size = [sw(100), sh(100)]
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

local crosshairZeroMark = {
  children = [
    drawArrow(sw(50), sh(50), 0, 1, highlightColor, false, highlightScale)
    drawArrow(sw(50), sh(50), 0, 1, greyColor)
  ]
}

local function drawForestallIndicator(
  forestallX,
  forestallY,
  targetX,
  targetY,
  pitchDelta,
  yawDelta,
  showVertical,
  showHorizontal,
  showMarker,
  showCentral) {

  local circleSize = sh(4)
  local angleThreshold = 2
  local verticalOffset = -sh(35.1)

  local isPitchMatch = fabs(pitchDelta) < angleThreshold
  local isYawMatch = fabs(yawDelta) < angleThreshold
  local indicatorElements = [ ]

  if (showCentral) {
    local centralArrow = isYawMatch ? drawArrow(sw(50), sh(50), 0, 1, greenColorGrid) : crosshairZeroMark
    indicatorElements.append(centralArrow)
  }
  if (showMarker) {
    indicatorElements.append({
      rendObj = ROBJ_VECTOR_CANVAS
      size = [circleSize, circleSize]
      pos = [forestallX - circleSize * 0.5, forestallY - circleSize * 0.5]
      color = greenColorGrid
      fillColor =  Color(0, 0, 0, 0)
      commands = [[VECTOR_ELLIPSE, 50, 50, 50, 50]]
    },
    @() {
      watch = fcsState.CalcProgress
      rendObj = ROBJ_VECTOR_CANVAS
      size = [circleSize * 0.7, circleSize * 0.7]
      pos = [forestallX - circleSize * 0.35, forestallY - circleSize * 0.35]
      color = greenColorGrid
      fillColor =  Color(0, 0, 0, 0)
      commands = [[VECTOR_SECTOR, 50, 50, 50, 50, -90, -90 + fcsState.CalcProgress.value * 360]]
    },
    drawDashLineToCircle(targetX, targetY, forestallX, forestallY, circleSize))
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

local forestallIndicator = @() {
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
    fcsState.ForestallPosX.value,
    fcsState.ForestallPosY.value,
    fcsState.TargetPosX.value,
    fcsState.TargetPosY.value,
    fcsState.ForestallPitchDelta.value * PI / fov.value,
    (CompassValue.value - fcsState.ForestallAzimuth.value) * PI / fov.value,
    fcsState.IsBinocular.value && fcsState.IsHorizontalAxisVisible.value,
    fcsState.IsBinocular.value && fcsState.IsVerticalAxisVisible.value,
    fcsState.IsForestallMarkerVisible.value,
    fcsState.IsBinocular.value)
}

local root = @() {
  watch = [fcsState.IsForestallVisible, fcsState.IsBinocular, IsRadarVisible, fcsState.IsTargetSelected]
  children = [
    !IsRadarVisible.value ? compassComponent : null
    fcsState.IsForestallVisible.value ? forestallIndicator
        : (fcsState.IsBinocular.value ? crosshairZeroMark : null)
    isExtraElementVisible ? roundIndicator : null
    fcsState.IsBinocular.value && fcsState.IsTargetSelected.value && (!fcsState.IsForestallVisible.value || !fcsState.IsForestallMarkerVisible.value) ? progressBar : null
  ]
}

return @() {
  watch = [fcsState.IsVisible, fcsState.IsBinocular]
  halign = ALIGN_LEFT
  valign = ALIGN_TOP
  size = [sw(100), sh(100)]
  children = fcsState.IsVisible.value ? root
    : fcsState.IsBinocular.value ? crosshairZeroMark : null
}