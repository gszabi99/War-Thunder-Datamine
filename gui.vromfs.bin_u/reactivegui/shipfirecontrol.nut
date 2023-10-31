from "%rGui/globals/ui_library.nut" import *
let cross_call = require("%rGui/globals/cross_call.nut")

let compass = require("compass.nut")
let { format } = require("string")
let { mkBitmapPicture } = require("%darg/helpers/bitmap.nut")
let { PI, cos, sin, fabs, sqrt, lerpClamped } = require("%sqstd/math.nut")
let { get_mission_time } = require("%rGui/globals/mission.nut")
let { CompassValue } = require("compassState.nut")
let { greenColor, greenColorGrid } = require("style/airHudStyle.nut")
let { fwdAngle, fov, gunStatesFirstNumber, gunStatesSecondNumber, gunStatesFirstRow, gunStatesSecondRow } = require("shipState.nut")
let { IsRadarVisible } = require("radarState.nut")
let fcsState = require("%rGui/fcsState.nut")

let function mkCirclePicture(radius, thickness) {
  let getDistance = @(x, y) sqrt(x * x + y * y)
  return  mkBitmapPicture(radius * 2, radius * 2,
  function(_, bmp) {
    for (local y = 0; y < radius * 2; y++)
      for (local x = 0; x < radius * 2; x++) {
        let distance = getDistance(x - radius, y - radius)
        let pixelColor = distance <= radius && distance >= (radius - thickness) ? 0xFFFFFFFF : 0x00000000
        bmp.setPixel(x, y, pixelColor)
      }
    })
}

let function mkFilledCirclePicture(radius) {
  let getDistance = @(x, y) sqrt(x * x + y * y)
  return  mkBitmapPicture(radius * 2, radius * 2,
  function(_, bmp) {
    for (local y = 0; y < radius * 2; y++)
      for (local x = 0; x < radius * 2; x++) {
        let distance = getDistance(x - radius, y - radius)
        let pixelColor = distance <= radius ? 0xFFFFFFFF : 0x00000000
        bmp.setPixel(x, y, pixelColor)
      }
    })
}

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

let gunStatusColors = {
  ready = Color(0, 255, 0, 255)
  overheat = Color(255, 0, 0, 255)
  inoperable = Color(255, 0, 0, 255)
  inoperableDeadzone = Color(128, 0, 0, 255)
  deadzone = Color(128, 128, 128, 255)
  readyDeadzone = Color(0, 128, 0, 255)
  neuterDeadzone = Color(64, 64, 64, 255)
  inner = Color(128, 128, 128, 255)
  inoperableBackground = Color(255, 0, 0, 96)
  defaultBackgroud = Color(0, 0, 0, 0)
  empty = Color(0, 0, 0, 0)
}

let bitmapCircles = {
  empty = mkCirclePicture(hdpx(38), hdpx(4))
  filled = mkFilledCirclePicture(hdpx(38))
}

let compassComponent = {
  pos = compassPos
  children = compass(compassSize, greenColor)
}


let gunState = {
  GUN_OVERHEAT = 0
  GUN_NORMAL = 1
  GUN_INOPERABLE = 2
  GUN_DEADZONE = 3
}


let background = {
  rendObj = ROBJ_VECTOR_CANVAS
  size = [fcsWidth, fcsWidth]
  color = greenColorGrid
  fillColor = Color(0, 32, 0, 120)
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
  rendObj = ROBJ_TEXT
  text = cross_call.measureTypes.SPEED.getMeasureUnitsText(fcsState.TargetSpeed.value)
  font = Fonts.tiny_text_hud
  pos = [0, sh(1)]
  color = greenColorGrid
  margin = [0, 0, 0, sh(1)]
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
  pos = [sw(52) + fcsState.OpticsWidth.value, fcsState.StaticFov.value > 6. ? sh(56.5) : sh(55)]
  children = {
    halign = ALIGN_RIGHT
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
          padding = [0, hdpx(5)]
          color = Color(0, 0, 0, 255)
          valign = ALIGN_CENTER
          rendObj = ROBJ_INSCRIPTION
          font = Fonts.tiny_text_hud
          text = loc("updating_range")
        }
        @() {
          watch = fcsState.IsTargetDataAvailable
          isHidden = fcsState.IsTargetDataAvailable.value
          size = [SIZE_TO_CONTENT, sh(2)]
          padding = [0, hdpx(5)]
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
}

let function drawArrow(x, y, dirX, dirY, color, fill = false, scale = 1) {
  let arrowSize = sh(2)
  local arrowCommands = []

  if (fill) {
    arrowCommands = dirX == 0
      ? [[VECTOR_POLY, 0, 0, 25, dirY * 50, -25, dirY * 50]]
      : [[VECTOR_POLY, 0, 0, -dirX * 50, 25, -dirX * 50, -25]]
  }
  else {
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

let function mkFilledCircle(size, color) {
  return {
    size = [size, size]
    rendObj = ROBJ_IMAGE
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    image = bitmapCircles.filled
    color = color
    fValue = 1
  }
}

let function mkCircle(size, color, fValue = 1) {
  return {
    size = [size, size]
    rendObj = ROBJ_PROGRESS_CIRCULAR
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    image = bitmapCircles.empty
    color = color
    fgColor = color
    fValue = fValue
  }
}

let function mkProgressCircle(size, startTime, endTime, curTime, color) {
  let timeLeft = endTime - curTime
  local startValue = startTime >= endTime ? 1.0
    : lerpClamped(startTime, endTime, 0.0, 1.0, curTime)

  return {
    size = [size, size]
    rendObj = ROBJ_PROGRESS_CIRCULAR
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    image = bitmapCircles.empty
    fgColor = color
    fValue = 1
    animations = timeLeft <= 0 ? null :
      [{ prop = AnimProp.fValue, from = startValue, duration = timeLeft , play = true }]
  }
}

let function getReloadText(endTime) {
  let timeToReload = endTime - get_mission_time()
  return timeToReload <= 0 ? ""
    : timeToReload > 9.5 ? format("%.0f", timeToReload)
    : format("%.1f", timeToReload)
}

let function mkProgressText(textColor, endTime) {
  return {
    color = textColor
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    rendObj = ROBJ_TEXT
    font = Fonts.tiny_text_hud
    behavior = Behaviors.RtPropUpdate
    text = getReloadText(endTime)
    update = @() {
      text = getReloadText(endTime)
    }
  }
}

let mkGunStatus = @(gunStates) function() {
  let { state, inDeadZone, startTime, endTime, gunProgress } = gunStates.get()
  if (state < 0)
    return { watch = gunStates }

  if (state < 0)
    return null

  local outerColor = gunStatusColors.ready
  local innerColor = gunStatusColors.inner
  local neuterColor = gunStatusColors.inner
  local overheatColor = gunStatusColors.inoperable
  local textColor = gunStatusColors.ready
  let curTime = get_mission_time();

  if (state == gunState.GUN_INOPERABLE) {
    innerColor = gunStatusColors.inoperable
    outerColor = gunStatusColors.inoperable
  } else if (state == gunState.GUN_DEADZONE) {
    innerColor = gunStatusColors.deadzone
    outerColor = gunStatusColors.deadzone
  } else if (inDeadZone) {
    outerColor = gunStatusColors.readyDeadzone
    textColor = gunStatusColors.readyDeadzone
    innerColor = gunStatusColors.neuterDeadzone
    neuterColor = gunStatusColors.neuterDeadzone
    overheatColor = gunStatusColors.inoperableDeadzone
  }

  let childrenCircles = []

  if (state == gunState.GUN_INOPERABLE) {
    childrenCircles.append(mkFilledCircle(ph(100), gunStatusColors.inoperableBackground))
  }

  childrenCircles.append(
    mkCircle(ph(80), innerColor)
  )

  if (state == gunState.GUN_NORMAL) {
    childrenCircles.append(
      mkCircle(ph(100), neuterColor)
      mkProgressCircle(ph(100), startTime, endTime, curTime, outerColor)
      mkProgressText(textColor, endTime)
    )
  } else {
    childrenCircles.append(mkCircle(ph(100), outerColor))
  }

  if (state == gunState.GUN_OVERHEAT && gunProgress < 1) {
    childrenCircles.append(mkCircle(ph(100), overheatColor, 1 - gunProgress))
  }


  return {
    size = [ph(100), ph(100)]
    watch = gunStates
    children = childrenCircles
  }
}

let function mkWeaponsStatus(size, gunStatesNumber, gunStatesArray) {
  if (gunStatesNumber <= 0) {
    return null
  }

  let childrenGuns = []
  for (local i = 0; i < gunStatesNumber; ++i) {
    childrenGuns.append(
      mkGunStatus(gunStatesArray[i])
    )
  }

  return @() {
    gap = hdpx(4)
    size = [SIZE_TO_CONTENT, size]
    flow = FLOW_HORIZONTAL
    children = childrenGuns
  }
}

let weaponsStatus = @() {
  watch = [gunStatesFirstNumber, gunStatesSecondNumber]
  pos = [0, sh(80)]
  gap = hdpx(11)
  hplace = ALIGN_CENTER
  flow = FLOW_VERTICAL
  halign = ALIGN_CENTER
  children = [
    mkWeaponsStatus(hdpx(38), gunStatesFirstNumber.value, gunStatesFirstRow)
    mkWeaponsStatus(hdpx(32), gunStatesSecondNumber.value, gunStatesSecondRow)
  ]
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
  children = fcsState.IsVisible.value ? [root, weaponsStatus]
    : fcsState.IsBinocular.value ? crosshairZeroMark : weaponsStatus
}