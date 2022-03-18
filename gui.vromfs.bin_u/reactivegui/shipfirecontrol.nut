let interopGen = require("interopGen.nut")
let compass = require("compass.nut")
let {PI, cos, sin, fabs, sqrt} = require("std/math.nut")
let {CompassValue} = require("compassState.nut")
let {greenColor, greenColorGrid} = require("style/airHudStyle.nut")
let {fwdAngle, fov} = require("shipState.nut")
let {IsRadarVisible} = require("radarState.nut")

let redColor = Color(255, 109, 108, 255)
let greyColor = Color(45, 60, 60, 255)
let highlightColor = Color(255, 255, 255, 255)
let highlightScale = 1.5
let compassSize = [hdpx(500), hdpx(32)]
let compassPos = [sw(50) - 0.5 * compassSize[0], sh(0.5)]
let fcsWidth = sh(28)
let isExtraElementVisible = false
let rangefinderProgressBarColor1 = Color(0, 255, 0, 255)
let rangefinderProgressBarColor2 = Color(100, 100, 100, 50)

let fcsState = {
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

let compassComponent = {
  pos = compassPos
  children = compass(compassSize, greenColor)
}

let background = {
  rendObj = ROBJ_VECTOR_CANVAS
  size = [fcsWidth, fcsWidth]
  color = greenColorGrid
  fillColor = Color(0,32,0,120)
  lineWidth = hdpx(LINE_WIDTH)
  commands = [
    [VECTOR_ELLIPSE, 50, 50, 50, 50]
  ]
}

let function mkDashes(width, centerX, centerY, radius, angleStart, angleFinish, length, count) {
  let dashCommands = []

  let startRad = angleStart * PI / 180.0;
  let finishRad = angleFinish * PI / 180.0;
  let dAngle = (finishRad - startRad) / (count + 1)

  for (local i = 0; i < count; ++i) {
    let angle = startRad + (i + 1) * dAngle
    let cosA = cos(angle)
    let sinA = sin(angle)
    let dashStartX = centerX + (radius - length) * cosA
    let dashStartY = centerY + (radius - length) * sinA
    let dashFinishX = centerX + (radius) * cosA
    let dashFinishY = centerY + (radius) * sinA
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

let centerX1 = 50
let centerY1 = 80
let centerX2 = 50
let centerY2 = -3
let radius1 = 25
let radius2 = 60
let angle1 = 140.0
let angle2 = 250.0
let angle3 = 290.0
let angle4 = 400.0
let angle5 = 38.0
let angle6 = 142.0

let fcsMarkers = {
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

let function drawShipIcon(iconSize, iconPos, iconColor, absBearing) {
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

let targetSpeed = @() {
  watch = fcsState.TargetSpeed
  rendObj = ROBJ_DTEXT
  text = ::cross_call.measureTypes.SPEED.getMeasureUnitsText(fcsState.TargetSpeed.value)
  font = Fonts.tiny_text_hud
  pos = [0, sh(1)]
  color = greenColorGrid
  margin = [0,0,0,sh(1)]
}

let progress = @() {
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

let roundIndicator = @() {
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

let progressBar = @() {
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

let function drawArrow(x, y, dirX, dirY, color, fill=false, scale=1) {
  let arrowSize = sh(2)
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

let function drawDashLineToCircle(fromX, fromY, toX, toY, radius) {
  local dirX = (toX - fromX)
  local dirY = (toY - fromY)
  let len = sqrt(dirX * dirX + dirY * dirY)
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

let crosshairZeroMark = {
  children = [
    drawArrow(sw(50), sh(50), 0, 1, highlightColor, false, highlightScale)
    drawArrow(sw(50), sh(50), 0, 1, greyColor)
  ]
}

let function drawForestallIndicator(
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

  let circleSize = sh(4)
  let angleThreshold = 2
  let verticalOffset = -sh(35.1)

  let isPitchMatch = fabs(pitchDelta) < angleThreshold
  let isYawMatch = fabs(yawDelta) < angleThreshold
  let indicatorElements = [ ]

  if (showCentral) {
    let centralArrow = isYawMatch ? drawArrow(sw(50), sh(50), 0, 1, greenColorGrid) : crosshairZeroMark
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

let root = @() {
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