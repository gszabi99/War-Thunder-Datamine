from "%rGui/globals/ui_library.nut" import *
from "%rGui/shipStateConsts.nut" import FIRST_ROW_SIGNAL_TRIGGER, SECOND_ROW_SIGNAL_TRIGGER, gunState
from "%rGui/shipState.nut" import showReloadedSignalFirstRow, showReloadedSignalSecondRow
from "%rGui/shipFireControlCommon.nut" import gunStatusColors, mkCircle, mkFilledCircle, mkProgressCircle, mkProgressText, mkReloadCircleImages
from "mission" import get_mission_time

const noBulletsIconSize = hdpxi(32)

let signalPlayedWathByTrigger = {
  [FIRST_ROW_SIGNAL_TRIGGER] = showReloadedSignalFirstRow,
  [SECOND_ROW_SIGNAL_TRIGGER] = showReloadedSignalSecondRow
}

showReloadedSignalFirstRow.subscribe(@(val) val ? anim_start(FIRST_ROW_SIGNAL_TRIGGER) : null)
showReloadedSignalSecondRow.subscribe(@(val) val ? anim_start(SECOND_ROW_SIGNAL_TRIGGER) : null)

let mkNoBulletsIcon = @(size, noBulletsIcon) {
  size = size
  rendObj = ROBJ_IMAGE
  vplace = ALIGN_CENTER
  hplace = ALIGN_CENTER
  image = noBulletsIcon
  color = Color(255, 175, 45)
}

let mkGunStatus = @(gunStates, reloadedSignalTrigger, noBulletsIcon, circleImages) function() {
  let { state, isAimerInDeadZone, startTime, endTime, gunProgress, bulletsCount } = gunStates.get()
  if (state < 0)
    return { watch = gunStates }

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
  } else if (isAimerInDeadZone) {
    outerColor = gunStatusColors.readyDeadzone
    textColor = gunStatusColors.readyDeadzone
    innerColor = gunStatusColors.neuterDeadzone
    neuterColor = gunStatusColors.neuterDeadzone
    overheatColor = gunStatusColors.inoperableDeadzone
  }

  let childrenCircles = []

  if (state == gunState.INOPERABLE) {
    childrenCircles.append(mkFilledCircle(ph(100), gunStatusColors.inoperableBackground, circleImages.filled))
  }

  childrenCircles.append(
    mkCircle(ph(80), innerColor, circleImages.status)
  )

  if (state == gunState.NORMAL) {
    childrenCircles.append(
      mkCircle(ph(100), neuterColor, circleImages.status)
      mkProgressCircle(ph(100), startTime, endTime, curTime, outerColor, circleImages.status)
      mkProgressText(textColor, endTime)
    )
  } else {
    let hasReloadAnim = !isAimerInDeadZone && (state != gunState.DEADZONE)
    if (hasReloadAnim) {
      let isSignalPlayed = signalPlayedWathByTrigger[reloadedSignalTrigger].get()
      childrenCircles.append(mkCircle(ph(100), outerColor, circleImages.status, 1, reloadedSignalTrigger,
        isSignalPlayed, circleImages.blured))
    } else {
      childrenCircles.append(mkCircle(ph(100), outerColor, circleImages.status))
    }
  }

  if (state == gunState.OVERHEAT && gunProgress < 1) {
    childrenCircles.append(mkCircle(ph(100), overheatColor, circleImages.status, 1 - gunProgress))
  }

  if (bulletsCount == 0) {
    childrenCircles.append(mkNoBulletsIcon(ph(45), noBulletsIcon))
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

  let noBulletsIcon = Picture($"ui/gameuiskin#has_no_bullets_icon.svg:{noBulletsIconSize}:{noBulletsIconSize}:P")
  let circleImages = mkReloadCircleImages()
  let childrenGuns = [
    {
      size = size
      rendObj = ROBJ_IMAGE
      image = Picture($"{icon}:{size}:{size}")
    }
  ]

  for (local i = 0; i < gunStatesNumber; ++i) {
    childrenGuns.append(
      mkGunStatus(gunStatesArray[i], reloadedSignalTrigger, noBulletsIcon, circleImages)
    )
  }

  return @() {
    gap = hdpx(4)
    size = [SIZE_TO_CONTENT, size]
    flow = FLOW_HORIZONTAL
    children = childrenGuns
  }
}

return freeze({
  mkWeaponsStatus
})
