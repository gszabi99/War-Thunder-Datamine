from "%rGui/globals/ui_library.nut" import *

let { get_mission_time } = require("mission")
let { ceil } = require("%sqstd/math.nut")
let { safeAreaSizeHud } = require("%rGui/style/screenState.nut")
let { CoaxialBullets, CoaxialCartridges, CoaxialCartridgeSize,
  CoaxialGunStartLoadAtTime, CoaxialGunNextShotAtTime,
  MachineGunBullets, MachineGunCartridges, MachineGunCartridgeSize,
  MachineGunStartLoadAtTime, MachineGunNextShotAtTime } = require("%rGui/hud/tankState.nut")

let boxWidth = shHud(12.5)
let boxHeight = shHud(2)
let fontHeight = shHud(1.2)
let bulletWidth = shHud(0.2)
let itemsGap = shHud(0.4)
let iconHeight = fontHeight
let iconWidth = (48.0 / 20 * iconHeight).tointeger()

let inactiveColor = Color(90, 90, 90)
let activeColor = Color(255, 255, 255)

let barsCount = 20

let coaxialGunIcon = Picture($"!ui/gameuiskin#coaxial_ammo_indicator.svg:{iconWidth}:{iconHeight}")
let machineGunIcon = Picture($"!ui/gameuiskin#aa_ammo_indicator.svg:{iconWidth}:{iconHeight}")

function mkProgressBar(bulletsCurrent, bulletsTotal, reloadStartTime, reloadEndTime) {
  let estimatedBarsCount = barsCount * bulletsCurrent / bulletsTotal
  let misTime = get_mission_time()
  let hasAnimation = misTime >= reloadStartTime && misTime < reloadEndTime
  local startAnimBulletIdx = 0
  local bulletAnimTime = 0
  if (hasAnimation) {
    let fullReloadTime = reloadEndTime - reloadStartTime
    let remainingReloadTime = reloadEndTime - misTime
    startAnimBulletIdx = barsCount - ceil(remainingReloadTime * barsCount / fullReloadTime)
    bulletAnimTime = remainingReloadTime / (barsCount - startAnimBulletIdx)
  }

  return array(barsCount).map(function(_, idx) {
    let bulletAnimDelay = bulletAnimTime * (idx - startAnimBulletIdx)
    return {
      rendObj = ROBJ_BOX
      key = $"{idx}_{reloadStartTime}_{reloadEndTime}"
      size = [bulletWidth, shHud(0.8)]
      fillColor = idx < estimatedBarsCount ? activeColor : inactiveColor
      borderRadius = [bulletWidth / 2, bulletWidth / 2, 0, 0]
      animations = hasAnimation && idx >= startAnimBulletIdx
        ? [
          {
            prop = AnimProp.fillColor
            duration = bulletAnimDelay
            from = inactiveColor
            to = inactiveColor
            play = true
          },
          {
            prop = AnimProp.fillColor
            duration = bulletAnimTime
            delay = bulletAnimDelay
            from = inactiveColor
            to = activeColor
            play = true
          }
        ]
        : null
    }
  })
}

function mkTankGun(triggerGroupIcon, cartridges, bullets, cartridgeSizeValue, reloadStartTime, reloadEndTime) {
  if (cartridgeSizeValue == 0)
    return null

  return {
    rendObj = ROBJ_BOX
    size = [boxWidth, boxHeight]
    padding = [0, itemsGap]
    fillColor = Color(45, 52, 60, 192)
    borderWidth = hdpx(1)
    borderRadius = hdpx(2)
    borderColor = Color(30, 30, 30)
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    children = [
      {
        rendObj = ROBJ_IMAGE
        size = [iconWidth, iconHeight]
        image = triggerGroupIcon
        color = activeColor
      }
      {
        size = [flex(), boxHeight]
        halign = ALIGN_RIGHT
        valign = ALIGN_CENTER
        flow = FLOW_HORIZONTAL
        gap = itemsGap
        children = [
          @() {
            rendObj = ROBJ_TEXT
            watch = cartridges
            padding = static [hdpx(2), 0, 0, 0]
            color = activeColor
            text = cartridges.value
            fontSize = fontHeight
          },
          @() {
            rendObj = ROBJ_BOX
            watch = [bullets, reloadStartTime, reloadEndTime]
            gap = 0.2 * bulletWidth
            flow = FLOW_HORIZONTAL
            children = mkProgressBar(bullets.value, cartridgeSizeValue, reloadStartTime.value, reloadEndTime.value)
          }
        ]
      }
    ]
  }
}

function tankGunsAmmo() {
  return {
    watch = [safeAreaSizeHud, CoaxialCartridgeSize, MachineGunCartridgeSize]
    flow = FLOW_HORIZONTAL
    hplace = ALIGN_CENTER
    gap = shHud(0.5)
    children = [
      mkTankGun(coaxialGunIcon,
        CoaxialCartridges, CoaxialBullets, CoaxialCartridgeSize.get(), CoaxialGunStartLoadAtTime, CoaxialGunNextShotAtTime),
      mkTankGun(machineGunIcon,
        MachineGunCartridges, MachineGunBullets, MachineGunCartridgeSize.get(), MachineGunStartLoadAtTime, MachineGunNextShotAtTime)
    ]
  }
}

return tankGunsAmmo
