from "%rGui/globals/ui_library.nut" import *

let compass = require("compass.nut")
let { format } = require("string")
let { PI, fabs, sqrt, lerpClamped } = require("%sqstd/math.nut")
let { get_mission_time } = require("mission")
let { CompassValue } = require("compassState.nut")
let { greenColor, greenColorGrid } = require("style/airHudStyle.nut")
let { fov, gunStatesFirstNumber, gunStatesSecondNumber, gunStatesFirstRow,
  gunStatesSecondRow, artilleryType, showReloadedSignalFirstRow, showReloadedSignalSecondRow
} = require("shipState.nut")
let { IsRadarVisible } = require("radarState.nut")
let fcsState = require("%rGui/fcsState.nut")
let { actionBarPos, isActionBarCollapsed } = require("%rGui/hud/actionBarState.nut")
let { eventbus_send } = require("eventbus")
let { drawArrow } = require("fcsComponent.nut")
let { FIRST_ROW_SIGNAL_TRIGGER, SECOND_ROW_SIGNAL_TRIGGER, gunState } = require("shipStateConsts.nut")

let redColor = Color(255, 109, 108, 255)
let greyColor = Color(15, 25, 25, 255)
let highlightColor = Color(255, 255, 255, 180)
let highlightScale = 2.5
let compassSize = [hdpx(500), hdpx(32)]
let compassPos = [sw(50) - 0.5 * compassSize[0], sh(0.5)]
let rangefinderProgressBarColor1 = Color(0, 255, 0, 255)
let rangefinderProgressBarColor2 = Color(100, 100, 100, 50)
let reloadCircleSize = hdpxi(76)
let reloadSignalSize = hdpxi(110)
let firstGunsRowHeight = hdpx(38)
let secondGunsRowHeight = hdpx(32)
let noBulletsIconSize = hdpxi(32)

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

let signalPlayedWathByTrigger = {
  [FIRST_ROW_SIGNAL_TRIGGER] = showReloadedSignalFirstRow,
  [SECOND_ROW_SIGNAL_TRIGGER] = showReloadedSignalSecondRow
}

let emptyCircleImg = Picture($"ui/gameuiskin#ship_weapon_status_circle.svg:{reloadCircleSize}:{reloadCircleSize}:P")
let bluredCircleImg = Picture($"ui/gameuiskin#ship_weapon_reloaded_signal.avif:{reloadSignalSize}:{reloadSignalSize}:P")
let filledCircleImg = Picture($"ui/gameuiskin#dmg_ship_status_bg.svg:{reloadCircleSize}:{reloadCircleSize}:P")
let noBulletsIcon = Picture($"ui/gameuiskin#has_no_bullets_icon.svg:{noBulletsIconSize}:{noBulletsIconSize}:P")

let compassComponent = {
  pos = compassPos
  children = compass(compassSize, greenColor)
}

let shipFireControlCachedPos = mkWatched(persist, "shipFireControlCachedPos", [0,0])
shipFireControlCachedPos.subscribe(@(v) eventbus_send("update_ship_fire_control_panel", {pos = v}))
showReloadedSignalFirstRow.subscribe(@(val) val ? anim_start(FIRST_ROW_SIGNAL_TRIGGER) : null)
showReloadedSignalSecondRow.subscribe(@(val) val ? anim_start(SECOND_ROW_SIGNAL_TRIGGER) : null)

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
          isHidden = fcsState.IsTargetDataAvailable.value
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

  let circleSize = sh(4)
  let angleThreshold = 2
  let verticalOffset = -sh(35.1)

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
      size = [circleSize, circleSize]
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
          size = [circleSize * 0.7, circleSize * 0.7]
          pos = [forestallX - circleSize * 0.35, forestallY - circleSize * 0.35]
          color = greenColorGrid
          fillColor =  Color(0, 0, 0, 0)
          commands = [[VECTOR_SECTOR, 50, 50, 50, 50, -90, -90 + fcsState.CalcProgress.value * 360]]})
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
    !fcsState.IsBinocular.value,
    fcsState.IsBinocular.value)
}

function mkFilledCircle(size, color) {
  return {
    size = [size, size]
    rendObj = ROBJ_IMAGE
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    image = filledCircleImg
    color = color
    fValue = 1
  }
}

function mkCircle(size, color, fValue = 1, reloadSignalTrigger = "", playReloadSignal = false) {
  return {
    size = [size, size]
    rendObj = ROBJ_PROGRESS_CIRCULAR
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    image = emptyCircleImg
    color = color
    fgColor = color
    fValue = fValue

    children = (reloadSignalTrigger == "") ? null : {
      size = pw(120)
      rendObj = ROBJ_IMAGE
      vplace = ALIGN_CENTER
      hplace = ALIGN_CENTER
      image = bluredCircleImg
      color = color
      fgColor = color
      transform = {}
      opacity = 0
      animations = [
        {
          prop = AnimProp.opacity, from = 0.1, to = 0.5, duration = 0.7, easing = InOutQuad,
          trigger = reloadSignalTrigger,
          play = playReloadSignal
        },
        {
          prop = AnimProp.scale, from = [0.85, 0.85], to = [1.6, 1.6], duration = 0.7, easing = InOutQuad,
          trigger = reloadSignalTrigger,
          play = playReloadSignal
        }
      ]
    }
  }
}

let mkNoBulletsIcon = @(size) {
  size = [size, size]
  rendObj = ROBJ_IMAGE
  vplace = ALIGN_CENTER
  hplace = ALIGN_CENTER
  image = noBulletsIcon
  color = Color(255, 175, 45)
}

function mkProgressCircle(size, startTime, endTime, curTime, color) {
  let timeLeft = endTime - curTime
  local startValue = startTime >= endTime ? 1.0
    : lerpClamped(startTime, endTime, 0.0, 1.0, curTime)

  return {
    key = {}
    size = [size, size]
    rendObj = ROBJ_PROGRESS_CIRCULAR
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    image = emptyCircleImg
    fgColor = color
    fValue = 1
    animations = timeLeft <= 0 ? null :
      [{ prop = AnimProp.fValue, from = startValue, duration = timeLeft , play = true }]
  }
}

function getReloadText(endTime) {
  let timeToReload = endTime - get_mission_time()
  return timeToReload <= 0 ? ""
    : timeToReload > 9.5 ? format("%.0f", timeToReload)
    : format("%.1f", timeToReload)
}

function mkProgressText(textColor, endTime) {
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

let mkGunStatus = @(gunStates, reloadedSignalTrigger) function() {
  let { state, inDeadZone, startTime, endTime, gunProgress, bulletsCount } = gunStates.get()
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

  if (bulletsCount == 0) {
    outerColor = gunStatusColors.deadzone
    textColor = gunStatusColors.deadzone
    innerColor = gunStatusColors.deadzone
    neuterColor = gunStatusColors.deadzone
    overheatColor = gunStatusColors.deadzone
  } else if (state == gunState.INOPERABLE) {
    innerColor = gunStatusColors.inoperable
    outerColor = gunStatusColors.inoperable
  } else if (state == gunState.DEADZONE) {
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

  if (state == gunState.INOPERABLE) {
    childrenCircles.append(mkFilledCircle(ph(100), gunStatusColors.inoperableBackground))
  }

  childrenCircles.append(
    mkCircle(ph(80), innerColor)
  )

  if (state == gunState.NORMAL) {
    childrenCircles.append(
      mkCircle(ph(100), neuterColor)
      mkProgressCircle(ph(100), startTime, endTime, curTime, outerColor)
      mkProgressText(textColor, endTime)
    )
  } else {
    let hasReloadAnim = !inDeadZone && (state != gunState.DEADZONE)
    if (hasReloadAnim) {
      let isSignalPlayed = signalPlayedWathByTrigger[reloadedSignalTrigger].get()
      childrenCircles.append(mkCircle(ph(100), outerColor, 1, reloadedSignalTrigger, isSignalPlayed))
    } else {
      childrenCircles.append(mkCircle(ph(100), outerColor))
    }
  }

  if (state == gunState.OVERHEAT && gunProgress < 1) {
    childrenCircles.append(mkCircle(ph(100), overheatColor, 1 - gunProgress))
  }

  if (bulletsCount == 0) {
    childrenCircles.append(mkNoBulletsIcon(ph(45)))
  }

  return {
    size = ph(100)
    watch = gunStates
    children = childrenCircles
  }
}

function mkWeaponsStatus(size, gunStatesNumber, gunStatesArray, icon, reloadedSignalTrigger) {
  if (gunStatesNumber <= 0) {
    return null
  }

  let childrenGuns = [
    {
      size = [size, size]
      rendObj = ROBJ_IMAGE
      image = Picture($"{icon}:{size}:{size}")
    }
  ]

  for (local i = 0; i < gunStatesNumber; ++i) {
    childrenGuns.append(
      mkGunStatus(gunStatesArray[i], reloadedSignalTrigger)
    )
  }

  return @() {
    gap = hdpx(4)
    size = [SIZE_TO_CONTENT, size]
    flow = FLOW_HORIZONTAL
    children = childrenGuns
  }
}

function weaponsStatus(){
  let gap = hdpx(11)

  let artType = artilleryType.value
  let firstRowIcon = artType == TRIGGER_GROUP_PRIMARY     ? "!ui/gameuiskin#artillery_weapon_state_indicator.svg"
                   : artType == TRIGGER_GROUP_SECONDARY   ? "!ui/gameuiskin#artillery_secondary_weapon_state_indicator.svg"
                   : artType == TRIGGER_GROUP_MACHINE_GUN ? "!ui/gameuiskin#machine_gun_weapon_state_indicator.svg"
                   : "!ui/gameuiskin#artillery_weapon_state_indicator.svg"

  let hasSecondRow = gunStatesSecondNumber.value > 0
  local childrens = [mkWeaponsStatus(firstGunsRowHeight, gunStatesFirstNumber.value, gunStatesFirstRow, firstRowIcon, FIRST_ROW_SIGNAL_TRIGGER)]
  if (hasSecondRow) {
    childrens.append(mkWeaponsStatus(secondGunsRowHeight, gunStatesSecondNumber.value, gunStatesSecondRow, "!ui/gameuiskin#artillery_secondary_weapon_state_indicator.svg", SECOND_ROW_SIGNAL_TRIGGER))
  }

  let height = hasSecondRow ? firstGunsRowHeight + secondGunsRowHeight + gap : firstGunsRowHeight
  let position = [0, (actionBarPos.get() != null ? actionBarPos.get()[1] : 0) - height - hdpx(11)]

  return {
    watch = [gunStatesFirstNumber, gunStatesSecondNumber, actionBarPos, isActionBarCollapsed, artilleryType]
    pos = position
    gap = gap
    hplace = ALIGN_CENTER
    flow = FLOW_VERTICAL
    halign = ALIGN_CENTER
    children = childrens
    behavior = Behaviors.RecalcHandler
    function onRecalcLayout(_initial, elem) {
      let x = elem.getScreenPosX()
      let y = elem.getScreenPosY()
      if (shipFireControlCachedPos.value[0] == x && shipFireControlCachedPos.value[1] == y)
        return
      shipFireControlCachedPos([x, y])
    }
  }
}


let root = @() {
  watch = [fcsState.IsForestallVisible, fcsState.IsBinocular, IsRadarVisible, fcsState.IsTargetSelected, fcsState.IsAutoAim]
  children = [
    !IsRadarVisible.value ? compassComponent : null
    fcsState.IsForestallVisible.value ? forestallIndicator
        : (fcsState.IsBinocular.value ? crosshairZeroMark : null)
    fcsState.IsBinocular.value && fcsState.IsTargetSelected.value && !fcsState.IsAutoAim.value ? progressBar : null
  ]
}

return @() {
  watch = [fcsState.IsVisible, fcsState.IsBinocular]
  halign = ALIGN_LEFT
  valign = ALIGN_TOP
  size = const [sw(100), SIZE_TO_CONTENT]
  children = fcsState.IsVisible.value ? [root, weaponsStatus]
    : fcsState.IsBinocular.value ? [crosshairZeroMark, weaponsStatus]
    : weaponsStatus
}