from "%rGui/globals/ui_library.nut" import *
from "%rGui/hud/actionBarState.nut" import actionBarPos
from "string" import format
from "%sqstd/math.nut" import lerpClamped
from "mission" import get_mission_time
from "eventbus" import eventbus_send

const reloadCircleSize = hdpxi(76)
const reloadSignalSize = hdpxi(110)

let panelAnchorY = Computed(@() (actionBarPos.get()?[1] ?? sh(100)) - hdpx(11))

let hudHintsAnchorPanelPos = mkWatched(persist, "hudHintsAnchorPanelPos", [0,0])
hudHintsAnchorPanelPos.subscribe(@(v) eventbus_send("update_hud_hints_anchor_pos", {pos = v}))

function trackPanelPos(_initial, elem) {
  let x = elem.getScreenPosX()
  let y = elem.getScreenPosY()
  if (hudHintsAnchorPanelPos.get()[0] == x && hudHintsAnchorPanelPos.get()[1] == y)
    return
  hudHintsAnchorPanelPos.set([x, y])
}

function mkActionBarPanel(getChildren, extraWatch = [], innerProps = {}) {
  let watch = [panelAnchorY].extend(extraWatch)
  return @() {
    watch
    pos = [0, panelAnchorY.get()]
    hplace = ALIGN_CENTER
    children = innerProps.__merge({
      pos = const [0, elemh(-100)]
      halign = ALIGN_CENTER
      children = getChildren()
      behavior = Behaviors.RecalcHandler
      onRecalcLayout = trackPanelPos
    })
  }
}

let gunStatusColors = {
  ready = Color(0, 255, 0, 255)
  inoperable = Color(255, 0, 0, 255)
  inoperableDeadzone = Color(128, 0, 0, 255)
  deadzone = Color(128, 128, 128, 255)
  readyDeadzone = Color(0, 128, 0, 255)
  neuterDeadzone = Color(64, 64, 64, 255)
  inner = Color(128, 128, 128, 255)
  inoperableBackground = Color(255, 0, 0, 96)
}

let weaponColors = {
  active = {
    ready = gunStatusColors.ready
    spent = gunStatusColors.inner
  }
  dimmed = {
    ready = gunStatusColors.readyDeadzone
    spent = gunStatusColors.neuterDeadzone
  }
  deadzone = {
    ready = gunStatusColors.deadzone
    spent = gunStatusColors.neuterDeadzone
  }
  inoperable = {
    ready = gunStatusColors.inoperable
    spent = gunStatusColors.inoperableDeadzone
  }
}

function weaponPalette(st) {
  let { isOperable, isAllowedBySelection, isInDeadZone, isOnTargetSector } = st
  return !isOperable ? weaponColors.inoperable
    : (!isAllowedBySelection || isInDeadZone) ? weaponColors.deadzone
    : !isOnTargetSector ? weaponColors.dimmed
    : weaponColors.active
}

let mkStatusCircleImage = @(px) Picture($"ui/gameuiskin#ship_weapon_status_circle.svg:{px}:{px}:P")

let mkReloadCircleImages = @() {
  status = mkStatusCircleImage(reloadCircleSize)
  blured = Picture($"ui/gameuiskin#ship_weapon_reloaded_signal.avif:{reloadSignalSize}:{reloadSignalSize}:P")
  filled = Picture($"ui/gameuiskin#dmg_ship_status_bg.svg:{reloadCircleSize}:{reloadCircleSize}:P")
}

function mkFilledCircle(size, color, filledCircleImg) {
  return {
    size = size
    rendObj = ROBJ_IMAGE
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    image = filledCircleImg
    color = color
    fValue = 1
  }
}

function mkCircle(size, color, image, fValue = 1, reloadSignalTrigger = "", playReloadSignal = false,
                  bluredCircleImg = null) {
  return {
    size = size
    rendObj = ROBJ_PROGRESS_CIRCULAR
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    image
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

function mkProgressCircle(size, startTime, endTime, curTime, color, image) {
  let timeLeft = endTime - curTime
  local startValue = startTime >= endTime ? 1.0
    : lerpClamped(startTime, endTime, 0.0, 1.0, curTime)

  return {
    key = {}
    size = size
    rendObj = ROBJ_PROGRESS_CIRCULAR
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    image
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

return {
  mkActionBarPanel
  gunStatusColors
  mkStatusCircleImage
  mkReloadCircleImages
  mkFilledCircle
  mkCircle
  mkProgressCircle
  getReloadText
  mkProgressText
  weaponPalette
}
