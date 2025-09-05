from "%rGui/globals/ui_library.nut" import *

let { PI, cos, sin } = require("%sqstd/math.nut")
let {
  isAllMachineGunsEmpty, GunOverheatState, GunDirectionX, isAllCannonsEmpty,
  GunDirectionY, GunDirectionVisible, GunInDeadZone, GunSightMode,
  TurretsDirectionX, TurretsDirectionY, TurretsOverheat, TurretsReloading, TurretsVisible,
  FixedGunDirectionVisible, FixedGunDirectionX, FixedGunDirectionY, FixedGunSightMode, FixedGunOverheat,
  IsAgmEmpty, IsATGMOutOfTrackerSector, AtgmTrackerRadius, IsLaserDesignatorEnabled, AgmTimeToHit, AgmTimeToWarning,
  GuidedBombsTimeToHit, GuidedBombsTimeToWarning,
  RocketAimX, RocketAimY, RocketAimVisible, RocketSightMode, RocketSightSizeFactor,
  NoLosToATGM, AlertColorHigh, HudColor, CurrentTime,
  BombReleaseVisible, BombReleaseDirX, BombReleaseBlockedState, BombReleaseBlockedStates, BombReleaseDirY, BombReleaseOpacity,
  BombReleasePoints, BombReleaseRelativToTarget, BombReleaseBlockedTextPosX, BombReleaseBlockedTextPosY
  RocketSightOpacity, RocketSightShadowOpacity,
  CanonSightLineWidthFactor, RocketSightLineWidthFactor, BombSightLineWidthFactor,
  CanonSightShadowLineWidthFactor, RocketSightShadowLineWidthFactor, BombSightShadowLineWidthFactor,
  BombSightShadowOpacity, TurretSightOpacity, TurretSightLineWidthFactor } = require("%rGui/airState.nut")
let { TargetX, TargetY } = require("%rGui/hud/targetTrackerState.nut")
let { mixColor, styleText, styleLineForeground, relativCircle, isDarkColor, fadeColor } = require("%rGui/style/airHudStyle.nut")
let { LaserPoint, HaveLaserPoint } = require("%rGui/planeState/planeWeaponState.nut")
let { crosshairColorOpt } = require("%rGui/options/options.nut")

const NUM_TURRETS_MAX = 10

const NUM_BOMB_RELEASE_POINT = 80

let sqL = 80
let l = 20
let offset = (100 - sqL) * 0.5

let normalTurretSight = freeze([
  [VECTOR_LINE, -50 + offset, -50 + offset, 50 - offset, -50 + offset],
  [VECTOR_LINE, 50 - offset, 50 - offset, 50 - offset, -50 + offset],
  [VECTOR_LINE, -50 + offset, 50 - offset, 50 - offset, 50 - offset],
  [VECTOR_LINE, -50 + offset, -50 + offset, -50 + offset, 50 - offset]
])

let ccipTurretSight = freeze([
  [VECTOR_LINE, -50 + offset, -50 + offset, 50 - offset, -50 + offset],
  [VECTOR_LINE, 50 - offset, 50 - offset, 50 - offset, -50 + offset],
  [VECTOR_LINE, -50 + offset, 50 - offset, 50 - offset, 50 - offset],
  [VECTOR_LINE, -50 + offset, -50 + offset, -50 + offset, 50 - offset],
  [VECTOR_LINE, 40, 40, 55, 55],
  [VECTOR_LINE, -40, 40, -55, 55],
  [VECTOR_LINE, 40, -40, 55, -55],
  [VECTOR_LINE, -40, -40, -55, -55]
])

let dashTurretSight = freeze([
  [VECTOR_LINE, 0, -50, 0, -50 + l],
  [VECTOR_LINE, 50 - l, 0, 50, 0],
  [VECTOR_LINE, 0, 50 - l, 0, 50],
  [VECTOR_LINE, -50, 0, -50 + l, 0]
])

let ccipDashTurretSight = freeze([
  [VECTOR_LINE, 0, -50, 0, -50 + l],
  [VECTOR_LINE, 50 - l, 0, 50, 0],
  [VECTOR_LINE, 0, 50 - l, 0, 50],
  [VECTOR_LINE, -50, 0, -50 + l, 0],
  [VECTOR_LINE, 40, 40, 55, 55],
  [VECTOR_LINE, -40, 40, -55, 55],
  [VECTOR_LINE, 40, -40, 55, -55],
  [VECTOR_LINE, -40, -40, -55, -55]
])

let triggerGun = {}
let isGunBlinking = keepref(Computed(@() GunInDeadZone.get()))
isGunBlinking.subscribe(@(v) v ? anim_start(triggerGun) : anim_request_stop(triggerGun))

function gunDirection(colorWatch, isSightHud) {
  let sightWatchList = freeze([GunSightMode, GunOverheatState, isAllMachineGunsEmpty, isAllCannonsEmpty])

  function sight() {
    let mainCommands = []
    let overheatCommands = []
    let selectedSightCommands = GunSightMode.value == 0 ? normalTurretSight : ccipTurretSight

    for (local i = 0; i < selectedSightCommands.len(); ++i) {
      if (i >= GunOverheatState.get()) {
        mainCommands.append(selectedSightCommands[i])
        if (!isAllCannonsEmpty.get() || !isAllMachineGunsEmpty.get())
          mainCommands.append(GunSightMode.value == 0 ? dashTurretSight[i] : ccipDashTurretSight[i])
      }
      else {
        overheatCommands.append(selectedSightCommands[i])
        if (!isAllCannonsEmpty.get() || !isAllMachineGunsEmpty.get())
          overheatCommands.append(GunSightMode.value == 0 ? dashTurretSight[i] : ccipDashTurretSight[i])
      }
    }

    let size = sh(2)
    return {
      watch = sightWatchList
      size
      children = [
        @() {
          watch = colorWatch
          rendObj = ROBJ_VECTOR_CANVAS
          size
          color = colorWatch.value
          commands = mainCommands
        },
        @() {
          watch = AlertColorHigh
          rendObj = ROBJ_VECTOR_CANVAS
          size
          color = AlertColorHigh.get()
          commands = overheatCommands
        }
      ]
    }
  }

  let rootWatchList = freeze([GunDirectionX, GunDirectionY, GunDirectionVisible])

  let animations = [
    { prop = AnimProp.opacity, from = 1, to = 0, duration = 0.5, loop = true, easing = InOutSine, trigger = triggerGun }
  ]

  return function() {
    let res = { watch = rootWatchList }

    if (GunSightMode.value == 0 && isSightHud)
      return res
    if (!GunDirectionVisible.get())
      return res

    return res.__update({
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      animations
      transform = {
        translate = [GunDirectionX.get(), GunDirectionY.get()]
      }
      children = sight
    })
  }
}

let dashCount = 36
const circleSize = 2.5
let angleReloadArrow = 90.0

function reloadTurret(currentTime) {
  let angleAnim = ((currentTime * 180) % 360) * (PI / 180)  
  let commands = []
  let angleDegree = angleReloadArrow / dashCount
  let angle = angleDegree * (PI / 180)
  for (local i = 0; i < dashCount; ++i) {
      commands.append([
        VECTOR_LINE,
        (cos(angle * (i - 1) + angleAnim) - sin(angle * (i - 1) + angleAnim)) * circleSize,
        (cos(angle * (i - 1) + angleAnim) + sin(angle * (i - 1) + angleAnim)) * circleSize,
        (cos(angle * i + angleAnim) - sin(angle * i + angleAnim)) * circleSize,
        (cos(angle * i + angleAnim) + sin(angle * i + angleAnim)) * circleSize
      ])
  }
  return commands
}

let createTurretSights = @(turretIndex, colorWatch) @() styleLineForeground.__merge({
  watch = [colorWatch, TurretsDirectionX[turretIndex], TurretsDirectionY[turretIndex],
    TurretsReloading[turretIndex], TurretsVisible[turretIndex], TurretSightOpacity, TurretSightLineWidthFactor]
  rendObj = ROBJ_VECTOR_CANVAS
  pos = [TurretsDirectionX[turretIndex].value, TurretsDirectionY[turretIndex].value]
  color = colorWatch.value
  size = sh(20)
  lineWidth = hdpx(LINE_WIDTH * TurretSightLineWidthFactor.get())
  fillColor = Color(0, 0, 0, 0)
  opacity = TurretSightOpacity.get()
  commands = !TurretsVisible[turretIndex].value ? null
    : TurretsReloading[turretIndex].value ? reloadTurret(CurrentTime.get())
    : relativCircle(1, circleSize)
  children = @() styleLineForeground.__merge({
    watch = [AlertColorHigh, TurretsVisible[turretIndex], TurretsReloading[turretIndex], TurretsOverheat[turretIndex]]
    rendObj = ROBJ_VECTOR_CANVAS
    size = flex()
    lineWidth = hdpx(LINE_WIDTH * TurretSightLineWidthFactor.get())
    fillColor = Color(0, 0, 0, 0)
    color = AlertColorHigh.get()
    opacity = TurretSightOpacity.get()
    commands = (TurretsVisible[turretIndex].value && !TurretsReloading[turretIndex].value)
      ? relativCircle(TurretsOverheat[turretIndex].value, circleSize)
      : null
  })
})

function aircraftTurretsComponent(colorWatch) {
  return {
    size = flex()
    children = array(NUM_TURRETS_MAX).map(@(_, i) createTurretSights(i, colorWatch))
  }
}



function fixedGunsSight(sightId) {
  local shifting = 30
  if (sightId == 0) {
    return [
      [VECTOR_LINE, 0, 50 + shifting, 0, 150 + shifting],
      [VECTOR_LINE, 0, -50 - shifting, 0, -150 - shifting],
      [VECTOR_LINE, 50 + shifting, 0, 150 + shifting, 0],
      [VECTOR_LINE, -50 - shifting, 0, -150 - shifting, 0],
    ]
  }
  else if (sightId == 1) {
    return [
      [VECTOR_LINE, 0, 50 + shifting, 0, 150 + shifting],
      [VECTOR_LINE, 0, -50 - shifting, 0, -150 - shifting],
      [VECTOR_LINE, 50 + shifting, 0, 150 + shifting, 0],
      [VECTOR_LINE, -50 - shifting, 0, -150 - shifting, 0],
      [VECTOR_LINE, 80, 80, 100, 100],
      [VECTOR_LINE, -80, 80, -100, 100],
      [VECTOR_LINE, 80, -80, 100, -100],
      [VECTOR_LINE, -80, -80, -100, -100],
    ]
  }

  return [
    [VECTOR_LINE, 0, 50, 0, 150],
    [VECTOR_LINE, 0, -50, 0, -150],
    [VECTOR_LINE, 50, 0, 150, 0],
    [VECTOR_LINE, -50, 0, -150, 0],
    [VECTOR_LINE, 60, 60, -60, 60],
    [VECTOR_LINE, 60, -60, -60, -60],
    [VECTOR_LINE, 60, 60, 60, -60],
    [VECTOR_LINE, -60, 60, -60, -60],
  ]
}

function overheatLines(color, line_width_factor) {
  let watch = [FixedGunOverheat, line_width_factor]
  return function() {
    let lineWidth = hdpx(LINE_WIDTH * line_width_factor.value)
    return {
      watch
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth
      size = sh(50)
      color
      fillColor = Color(0, 0, 0, 0)
      commands = relativCircle(FixedGunOverheat.get(), circleSize)
    }
  }
}

function fixedGunsDirection(colorWatch) {
  return function() {
    if (!FixedGunDirectionVisible.get())
      return { watch = FixedGunDirectionVisible }

    let overheatFg = overheatLines(AlertColorHigh.get(), CanonSightLineWidthFactor)

    function lines() {
      let lineWidth = hdpx(LINE_WIDTH * CanonSightLineWidthFactor.get())
      return {
        watch = [FixedGunSightMode, colorWatch, AlertColorHigh, CanonSightLineWidthFactor]
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth
        size = sh(0.625)
        color = fadeColor(colorWatch.value, 255)
        commands = fixedGunsSight(FixedGunSightMode.get())
        children = overheatFg
      }
    }

    let overheatBg = overheatLines(Color(0, 0, 0, 120), CanonSightShadowLineWidthFactor)

    function shadowLines() {
      let shadowLineWidth = hdpx(LINE_WIDTH * CanonSightShadowLineWidthFactor.get())
      return styleLineForeground.__merge({
        watch = [FixedGunSightMode, colorWatch, CanonSightShadowLineWidthFactor]
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = shadowLineWidth
        size = sh(0.625)
        fillColor = Color(0, 0, 0, 0)
        color = isDarkColor(colorWatch.value) ? Color(255, 255, 255, 255) : Color(0, 0, 0, 255)
        commands = fixedGunsSight(FixedGunSightMode.get())
        children = overheatBg
      })
    }

    return {
      watch = [FixedGunDirectionVisible, FixedGunDirectionX, FixedGunDirectionY]
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      pos = [FixedGunDirectionX.get(), FixedGunDirectionY.get()]
      children = [shadowLines, lines]
    }
  }
}

function helicopterCCRP(colorWatch) {
  return function() {
    let res = { watch = [FixedGunDirectionX, FixedGunDirectionY, FixedGunDirectionVisible, FixedGunSightMode] }

    if (!FixedGunDirectionVisible.get() || FixedGunSightMode.get() != 2)
      return res

    let lines = @() styleLineForeground.__merge({
      watch = [TargetX, TargetY, colorWatch]
      rendObj = ROBJ_VECTOR_CANVAS
      size = sh(0.625)
      color = colorWatch.value
      commands = [[VECTOR_LINE, 0, 0, TargetX.get(), TargetY.get()]]
    })

    return res.__update({
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      pos = [FixedGunDirectionX.get(), FixedGunDirectionY.get()]
      children = lines
    })
  }
}

function agmTrackZoneComponent(colorWatch) {
  function agmTrackZone(width, height) {
    return @() styleLineForeground.__merge({
      watch = [IsAgmEmpty, IsATGMOutOfTrackerSector, NoLosToATGM, AtgmTrackerRadius, colorWatch]
      rendObj = ROBJ_VECTOR_CANVAS
      size = [width, height]
      opacity = AtgmTrackerRadius.get() > 0.0 ? 100 : 0
      color = colorWatch.value
      fillColor = Color(0, 0, 0, 0)
      lineWidth = hdpx(LINE_WIDTH)
      commands = !IsAgmEmpty.get() && IsATGMOutOfTrackerSector.get() && !NoLosToATGM.get()
        ?
        [
          [ VECTOR_ELLIPSE, 50, 50,
            AtgmTrackerRadius.get() / width * 100,
            AtgmTrackerRadius.get() / height * 100
          ]
        ]
        : null
    })
  }

  let width = sw(100)
  let height = sh(100)
  return {
    pos = [sw(50) - width * 0.5, sh(50) - height * 0.5]
    animations = [{ prop = AnimProp.opacity, from = 0, to = 1 duration = 0.5, play = true, loop = true, easing = InOutCubic }]
    children = agmTrackZone(width, height)
  }
}

function laserDesignatorComponent(colorWatch, posX, posY) {
  function laserDesignator(width, height) {
    let color = Computed(@() IsAgmEmpty.get() ? AlertColorHigh.get() : colorWatch.value)
    return @() styleLineForeground.__merge({
      watch = [color]
      rendObj = ROBJ_VECTOR_CANVAS
      size = [width, height]
      color = color.get()
      fillColor = color.get()
      commands = [
        [ VECTOR_ELLIPSE, 50, 50,
          5.0 / width * 100,
          5.0 / height * 100
        ]
      ]
    })
  }

  let width = hdpx(150)
  let height = hdpx(100)
  return @() {
    pos = [posX - 0.5 * width, posY - 0.5 * height]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    watch = IsLaserDesignatorEnabled
    opacity = IsLaserDesignatorEnabled.get() ? 100 : 0
    size = SIZE_TO_CONTENT
    children = laserDesignator(width, height)
  }
}


let laserTrigger = {}
IsLaserDesignatorEnabled.subscribe(@(v) !v ? anim_start(laserTrigger) : anim_request_stop(laserTrigger))

function laserDesignatorStatusComponent(colorWatch, posX, posY) {
  let laserDesignatorStatus = @() styleText.__merge({
    rendObj = ROBJ_TEXT
    halign = ALIGN_CENTER
    text = IsLaserDesignatorEnabled.get() ? loc("HUD/TXT_LASER_DESIGNATOR") : loc("HUD/TXT_ENABLE_LASER_NOW")
    color = colorWatch.value
    watch = [IsLaserDesignatorEnabled, colorWatch]
    animations = [{ prop = AnimProp.opacity, from = 0, to = 1, duration = 0.5, play = !IsLaserDesignatorEnabled.get(), loop = true, easing = InOutSine, trigger = laserTrigger }]
  })

  let resCompoment = @() {
    pos = [posX, posY]
    halign = ALIGN_CENTER
    size = 0
    watch = [IsLaserDesignatorEnabled, AgmTimeToHit, AgmTimeToWarning, GuidedBombsTimeToHit, GuidedBombsTimeToWarning]
    children = IsLaserDesignatorEnabled.get()
      || (AgmTimeToHit.get() > 0 && AgmTimeToWarning.get() <= 0)
      || (GuidedBombsTimeToHit.get() > 0 && GuidedBombsTimeToWarning.get() <= 0)
      ? laserDesignatorStatus : null
  }
  return resCompoment
}

function agmTrackerStatusComponent(colorWatch, posX, posY) {
  let agmTrackerStatus = @() styleText.__merge({
    rendObj = ROBJ_TEXT
    halign = ALIGN_CENTER
    text = NoLosToATGM.get() ? loc("HUD/TXT_NO_LOS_ATGM") : loc("HUD/TXT_ATGM_OUT_OF_TRACKER_SECTOR")
    color = colorWatch.value
    watch = [NoLosToATGM, colorWatch]
    animations = [{ prop = AnimProp.opacity, from = 0, to = 1, duration = 0.5, play = true, loop = true, easing = InOutCubic }]
  })

  let resCompoment = @() {
    pos = [posX, posY]
    halign = ALIGN_CENTER
    size = 0
    watch = [IsATGMOutOfTrackerSector, NoLosToATGM]
    children = IsATGMOutOfTrackerSector.get() || NoLosToATGM.get() ? agmTrackerStatus : null
  }
  return resCompoment
}

function aircraftRocketSightMode(sightMode) {

  if (sightMode == 0) {
    return [
      [VECTOR_LINE, 0, 0, 0, 60],
      [VECTOR_LINE, 4, 0, -4, 0],
      [VECTOR_LINE, 8, 20, -8, 20],
      [VECTOR_LINE, 12, 40, -12, 40],
      [VECTOR_LINE, 16, 60, -16, 60]
    ]
  }
  else if (sightMode == 1) {
    return [
      [VECTOR_LINE, -10, -10, -5, -5],
      [VECTOR_LINE, -10, 10, -5, 5],
      [VECTOR_LINE, 10, -10, 5, -5],
      [VECTOR_LINE, 10, 10, 5, 5],
      [VECTOR_ELLIPSE, 0, 0, 1.0, 1.0]
    ]
  }

  return [
    [VECTOR_LINE, -20, -20, 20, -20],
    [VECTOR_LINE, -20, 20, 20, 20],
    [VECTOR_LINE, -4, -20, -4, 20],
    [VECTOR_LINE, 4, -20, 4, 20],
    [VECTOR_LINE, 8, 8, -8, 8],
    [VECTOR_LINE, 8, -8, -8, -8],
    [VECTOR_LINE, 12, 4, 12, -4],
    [VECTOR_LINE, -12, 4, -12, -4],
  ]
}


let aircraftRocketSight = @(width, height) function() {

  let res = { watch = [crosshairColorOpt, RocketAimX, RocketAimY, RocketAimVisible, RocketSightMode, RocketSightSizeFactor,
    RocketSightOpacity, RocketSightShadowOpacity, RocketSightLineWidthFactor, RocketSightShadowLineWidthFactor] }
  if (!RocketAimVisible.get())
    return res

  let lineWidth = hdpx(LINE_WIDTH * RocketSightLineWidthFactor.get())
  let shadowLineWidth = hdpx(LINE_WIDTH * RocketSightShadowLineWidthFactor.get())

  let lines = styleLineForeground.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    color = fadeColor(crosshairColorOpt.get(), 255)
    fillColor = 0
    lineWidth
    size =  [width * RocketSightSizeFactor.get(), height * RocketSightSizeFactor.get()]
    opacity = RocketSightOpacity.value
    commands = aircraftRocketSightMode(RocketSightMode.get())
  })

  let shadowLines = styleLineForeground.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    color = isDarkColor(HudColor.get()) ? Color(255, 255, 255, 255) : Color(0, 0, 0, 255)
    lineWidth = shadowLineWidth
    size = [width * RocketSightSizeFactor.get(), height * RocketSightSizeFactor.get()]
    opacity = RocketSightShadowOpacity.get()
    commands = aircraftRocketSightMode(RocketSightMode.get())
  })

  return res.__update({
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    pos = [RocketAimX.get(), RocketAimY.get()]
    children = [shadowLines, lines]
  })
}

function laserPoint(colorWatch) {
  return {
    size = hdpx(5.0)
    rendObj = ROBJ_VECTOR_CANVAS
    color = colorWatch.value
    fillColor = Color(0, 0, 0, 0)
    commands = [
      [VECTOR_ELLIPSE, 0, 0, 100, 100]
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [LaserPoint[0], LaserPoint[1]]
      }
    }
  }
}

function laserPointComponent(colorWatch) {
  return @() {
    watch = HaveLaserPoint
    size = flex()
    children = HaveLaserPoint.get() ? laserPoint(colorWatch) : null
  }
}

function getBombBlockedStateText(state) {
  if (state == BombReleaseBlockedStates.notBlocked)
    return ""

  return state == BombReleaseBlockedStates.highSpeed ? loc("HUD/BOMB_SIGHT_HIGH_SPEED") : loc("HUD/BOMB_SIGHT_BOMB_BAY")
}

let bombSightComponent = @(width, height, crosshairColorWatch) function() {
  let res = { watch = [BombReleaseVisible, BombReleaseDirX, BombReleaseDirY, BombReleasePoints,
    BombReleaseRelativToTarget, AlertColorHigh, HudColor, BombReleaseOpacity, BombSightShadowOpacity,
    BombSightLineWidthFactor, BombSightShadowLineWidthFactor, crosshairColorWatch] }

  if (!BombReleaseVisible.get())
    return res

  let commands = []
  for (local i = 0; i < NUM_BOMB_RELEASE_POINT; i += 4) {
    commands.append([VECTOR_LINE, BombReleasePoints.get()?[i], BombReleasePoints.get()?[i + 1], BombReleasePoints.get()?[i + 2], BombReleasePoints.get()?[i + 3]])
  }

  let finalBombSightColor = mixColor(crosshairColorWatch.value, AlertColorHigh.get(), BombReleaseRelativToTarget.get())

  let lineWidth = hdpx(LINE_WIDTH * BombSightLineWidthFactor.get())
  let shadowLineWidth = hdpx(LINE_WIDTH * BombSightShadowLineWidthFactor.get())

  let lines = styleLineForeground.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth
    fillColor = Color(0, 0, 0, 0)
    size = [width, height]
    pos = [BombReleaseDirX.get(), BombReleaseDirY.get()]
    color = fadeColor(finalBombSightColor, 255)
    opacity = BombReleaseOpacity.get()
    commands
  })

  let shadowLines = styleLineForeground.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = shadowLineWidth
    fillColor = Color(0, 0, 0, 0)
    size = [width, height]
    pos = [BombReleaseDirX.get(), BombReleaseDirY.get()]
    color = isDarkColor(finalBombSightColor) ? Color(255, 255, 255, 255) : Color(0, 0, 0, 255)
    opacity = BombReleaseOpacity.get() * BombSightShadowOpacity.get()
    fillOpacity = 0
    commands
  })

  let sightWarningText = @() styleText.__merge({
    rendObj = ROBJ_TEXT
    watch = [BombReleaseBlockedTextPosX, BombReleaseBlockedTextPosX, BombReleaseBlockedState]
    pos = [BombReleaseBlockedTextPosX.get(), BombReleaseBlockedTextPosY.value]
    text = getBombBlockedStateText(BombReleaseBlockedState.get())
  })

  return res.__update({
    pos = [0, 0]
    children = [shadowLines, lines, sightWarningText]
  })
}

return {
  aircraftTurretsComponent
  gunDirection
  fixedGunsDirection
  helicopterCCRP
  agmTrackerStatusComponent
  agmTrackZoneComponent
  laserDesignatorStatusComponent
  laserDesignatorComponent
  laserPointComponent
  aircraftRocketSight
  bombSightComponent
}