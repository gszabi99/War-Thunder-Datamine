local {round, PI, cos, sin} = require("std/math.nut")
local {
  IsMachineGunEmpty, GunOverheatState, GunDirectionX, IsCannonEmpty, isAllCannonsEmpty,
  GunDirectionY, GunDirectionVisible, GunInDeadZone, GunSightMode,
  TurretsDirectionX, TurretsDirectionY, TurretsOverheat, TurretsReloading, TurretsVisible,
  FixedGunDirectionVisible, FixedGunDirectionX, FixedGunDirectionY, FixedGunSightMode, FixedGunOverheat,
  IsAgmEmpty, IsATGMOutOfTrackerSector, AtgmTrackerRadius, IsLaserDesignatorEnabled, Agm,
  RocketAimX, RocketAimY, RocketAimVisible, RocketSightMode,
  NoLosToATGM, AlertColorHigh, HudColor, CurrentTime} = require("airState.nut")
local { TargetX, TargetY } = require("reactiveGui/hud/targetTrackerState.nut")

local { backgroundColor } = require("style/airHudStyle.nut")
local { LaserPoint, HaveLaserPoint } = require("planeState.nut")

const NUM_TURRETS_MAX = 10
const NUM_CANNONS_MAX = 3

local styleLineForeground = {
  fillColor = Color(0, 0, 0, 0)
  lineWidth = hdpx(LINE_WIDTH)
}

local sqL = 80
local l = 20
local offset = (100 - sqL) * 0.5

local normalTurretSight = [
  [VECTOR_LINE, -50 + offset, -50 + offset, 50 - offset, -50 + offset],
  [VECTOR_LINE, 50 - offset, 50 - offset, 50 - offset, -50 + offset],
  [VECTOR_LINE, -50 + offset, 50 - offset, 50 - offset, 50 - offset],
  [VECTOR_LINE, -50 + offset, -50 + offset, -50 + offset, 50 - offset]
]

local ccipTurretSight = [
  [VECTOR_LINE, -50 + offset, -50 + offset, 50 - offset, -50 + offset],
  [VECTOR_LINE, 50 - offset, 50 - offset, 50 - offset, -50 + offset],
  [VECTOR_LINE, -50 + offset, 50 - offset, 50 - offset, 50 - offset],
  [VECTOR_LINE, -50 + offset, -50 + offset, -50 + offset, 50 - offset],
  [VECTOR_LINE, 40, 40, 55, 55],
  [VECTOR_LINE, -40, 40, -55, 55],
  [VECTOR_LINE, 40, -40, 55, -55],
  [VECTOR_LINE, -40, -40, -55, -55]
]

local dashTurretSight = [
  [VECTOR_LINE, 0, -50, 0, -50 + l],
  [VECTOR_LINE, 50 - l, 0, 50, 0],
  [VECTOR_LINE, 0, 50 - l, 0, 50],
  [VECTOR_LINE, -50, 0, -50 + l, 0]
]

local ccipDashTurretSight = [
  [VECTOR_LINE, 0, -50, 0, -50 + l],
  [VECTOR_LINE, 50 - l, 0, 50, 0],
  [VECTOR_LINE, 0, 50 - l, 0, 50],
  [VECTOR_LINE, -50, 0, -50 + l, 0],
  [VECTOR_LINE, 40, 40, 55, 55],
  [VECTOR_LINE, -40, 40, -55, 55],
  [VECTOR_LINE, 40, -40, 55, -55],
  [VECTOR_LINE, -40, -40, -55, -55]
]

local triggerGun = {}
local isGunBlinking = keepref(Computed(@() GunInDeadZone.value))
isGunBlinking.subscribe(@(v) v ? ::anim_start(triggerGun) : ::anim_request_stop(triggerGun))

local gunDirection = @(isBackground, isSightHud) function() {

  local watchList = [GunSightMode, GunOverheatState, IsMachineGunEmpty, GunDirectionX, GunDirectionY, HudColor,
                     isAllCannonsEmpty, AlertColorHigh, GunDirectionVisible, IsCannonEmpty]
  local res = { watch = watchList}

  if (GunSightMode.value == 0 && isSightHud)
    return res
  if (!GunDirectionVisible.value)
    return res


  local mainCommands = []
  local overheatCommands = []
  local selectedSightCommands = GunSightMode.value == 0 ? normalTurretSight : ccipTurretSight

  for (local i = 0; i < selectedSightCommands.len(); ++i) {
    if (i >= GunOverheatState.value) {

      mainCommands.append(selectedSightCommands[i])
      if (!isAllCannonsEmpty.value || !IsMachineGunEmpty.value)
        mainCommands.append(GunSightMode.value == 0 ? dashTurretSight[i] : ccipDashTurretSight[i])
    }
    else {

      overheatCommands.append(selectedSightCommands[i])
      if (!isAllCannonsEmpty.value || !IsMachineGunEmpty.value)
        overheatCommands.append(GunSightMode.value == 0 ? dashTurretSight[i] : ccipDashTurretSight[i])
    }
  }

  return res.__update({
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    animations = [{ prop = AnimProp.opacity, from = 1, to = 0, duration = 0.5, loop = true, easing = InOutSine, trigger = triggerGun}]
    transform = {
      translate = [GunDirectionX.value, GunDirectionY.value]
    }
    children =
    [
      @() {
        watch = HudColor
        rendObj = ROBJ_VECTOR_CANVAS
        size = [sh(2), sh(2)]
        color = HudColor.value
        commands = mainCommands
      },
      @() {
        watch = AlertColorHigh
        rendObj = ROBJ_VECTOR_CANVAS
        size = [sh(2), sh(2)]
        color = isBackground ? backgroundColor : AlertColorHigh.value
        commands = overheatCommands
      }
    ]
  })
}

const dashCount = 36
const circleSize = 2.5
local angleReloadArrow = 90.0

local function reloadTurret(currentTime){
  local angleAnim = ((currentTime * 180) % 360) * (PI / 180)  // 360 per 2 sec
  local commands = []
  local angleDegree = angleReloadArrow / dashCount
  local angle = angleDegree * (PI / 180)
  for(local i = 0; i < dashCount; ++i) {
      commands.append([
        VECTOR_LINE,
        (cos(angle * (i-1) + angleAnim) - sin(angle * (i-1) + angleAnim)) * circleSize,
        (cos(angle * (i-1) + angleAnim) + sin(angle * (i-1) + angleAnim)) * circleSize,
        (cos(angle * i + angleAnim) - sin(angle * i + angleAnim)) * circleSize,
        (cos(angle * i + angleAnim) + sin(angle * i + angleAnim)) * circleSize
      ])
    }
  return commands
}


//used for aircraft turret Sight turret/fixedGun overheat/jam and fixed gun overheat
local function relativCircle(percent){

  if (percent >= 0.99999999){
    return [
      [VECTOR_ELLIPSE, 0, 0, circleSize * 1.3, circleSize * 1.3]
    ]
  }

  local commands = []
  local angleDegree = 360 / dashCount
  local angle = angleDegree * (PI / 180)
  local startingAngleOffset = 120 * (PI / 180)
  local dashAmmount = round((percent * 360) / angleDegree)
  for(local i = 0; i < dashAmmount; ++i) {
    commands.append([
      VECTOR_LINE,
      (cos(-startingAngleOffset + angle * (i-1)) - sin(-startingAngleOffset + angle * (i-1))) * circleSize,
      (cos(-startingAngleOffset + angle * (i-1)) + sin(-startingAngleOffset + angle * (i-1))) * circleSize,
      (cos(-startingAngleOffset + angle * i) -     sin(-startingAngleOffset + angle * i)) * circleSize,
      (cos(-startingAngleOffset + angle * i) +     sin(-startingAngleOffset + angle * i)) * circleSize
    ])
  }
  return commands
}

local createTurretSights = @(turretIndex) @() styleLineForeground.__merge({
  watch = [HudColor, TurretsDirectionX[turretIndex], TurretsDirectionY[turretIndex], TurretsReloading[turretIndex], TurretsVisible[turretIndex]]
  rendObj = ROBJ_VECTOR_CANVAS
  pos = [TurretsDirectionX[turretIndex].value, TurretsDirectionY[turretIndex].value]
  color = HudColor.value
  size = [sh(20), sh(20)]
  lineWidth = hdpx(1)
  fillColor = Color(0, 0, 0, 0)
  commands = TurretsReloading[turretIndex].value ? reloadTurret(CurrentTime.value)
    : TurretsVisible[turretIndex].value ? relativCircle(1)
    : null
  children = @() styleLineForeground.__merge({
    watch = [AlertColorHigh, TurretsVisible[turretIndex], TurretsReloading[turretIndex], TurretsOverheat[turretIndex]]
    rendObj = ROBJ_VECTOR_CANVAS
    size = flex()
    lineWidth = hdpx(1)
    fillColor = Color(0, 0, 0, 0)
    color = AlertColorHigh.value
    commands = (TurretsVisible[turretIndex].value && !TurretsReloading[turretIndex].value)
      ? relativCircle(TurretsOverheat[turretIndex].value)
      : null
  })
})

local function aircraftTurretsComponent(isBackground, isSightHud) {
  return {
    size = flex()
    children = array(NUM_TURRETS_MAX).map(@(_, i) createTurretSights(i))
  }
}



local function fixedGunsSight(sightId){
  if (sightId == 0) {
    return [
      [VECTOR_LINE, 0, 50, 0, 150],
      [VECTOR_LINE, 0, -50, 0, -150],
      [VECTOR_LINE, 50, 0, 150, 0],
      [VECTOR_LINE, -50, 0, -150, 0],
    ]
  }
  else if (sightId == 1) {
    return [
      [VECTOR_LINE, 0, 50, 0, 150],
      [VECTOR_LINE, 0, -50, 0, -150],
      [VECTOR_LINE, 50, 0, 150, 0],
      [VECTOR_LINE, -50, 0, -150, 0],
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

local fixedGunsDirection = @(isBackground) function() {

  local res = { watch = [FixedGunDirectionVisible, FixedGunDirectionX, FixedGunDirectionY] }

  if (!FixedGunDirectionVisible.value)
    return res

  local overheatLines = @(){
    watch = [AlertColorHigh, FixedGunOverheat]
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(1)
    size = [sh(50), sh(50)]
    color = isBackground ? backgroundColor : AlertColorHigh.value
    fillColor = Color(0, 0, 0, 0)
    commands = relativCircle(FixedGunOverheat.value)
  }
  local lines = @() {
    watch = [FixedGunSightMode, HudColor]
    rendObj = ROBJ_VECTOR_CANVAS
    size = [sh(0.625), sh(0.625)]
    color = isBackground ? backgroundColor : HudColor.value
    commands = fixedGunsSight(FixedGunSightMode.value)
    children = overheatLines
  }

  return res.__update({
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    pos = [FixedGunDirectionX.value, FixedGunDirectionY.value]
    children = lines
  })
}

local helicopterCCRP = @(isBackground) function() {

  local res =  { watch = [FixedGunDirectionX, FixedGunDirectionY, FixedGunDirectionVisible, FixedGunSightMode] }

  if (!FixedGunDirectionVisible.value || FixedGunSightMode.value != 2)
    return res

  local lines = @() styleLineForeground.__merge({
    watch = [TargetX, TargetY, HudColor]
    rendObj = ROBJ_VECTOR_CANVAS
    size = [sh(0.625), sh(0.625)]
    color = isBackground ? backgroundColor : HudColor.value
    commands = [[VECTOR_LINE, 0,0, TargetX.value, TargetY.value]]
  })

  return res.__update({
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    pos = [FixedGunDirectionX.value, FixedGunDirectionY.value]
    children = lines
  })
}

local function agmTrackZone(width, height, isBackground) {
  return @() styleLineForeground.__merge({
    watch = [IsAgmEmpty, IsATGMOutOfTrackerSector, AtgmTrackerRadius, HudColor]
    rendObj = ROBJ_VECTOR_CANVAS
    size = [width, height]
    opacity = AtgmTrackerRadius.value > 0.0 ? 100 : 0
    color = isBackground ? backgroundColor : HudColor.value
    fillColor = Color(0, 0, 0, 0)
    lineWidth = hdpx(LINE_WIDTH)
    commands = !IsAgmEmpty.value && IsATGMOutOfTrackerSector.value
      ?
      [
        [ VECTOR_ELLIPSE, 50, 50,
          AtgmTrackerRadius.value / width * 100,
          AtgmTrackerRadius.value / height * 100
        ]
      ]
      : null
  })
}

local function agmTrackZoneComponent(isBackground) {
  local width = sw(100)
  local height = sh(100)
  local pos = [sw(50) - width * 0.5, sh(50) - height * 0.5]
  return {
    pos = pos
    animations = [{ prop = AnimProp.opacity, from = 0, to = 1 duration = 0.5, play = true, loop = true, easing = InOutCubic}]
    children = agmTrackZone(width, height, isBackground)
  }
}

local function laserDesignator(width, height, isBackground) {
  local lhl = 5
  local lvl = 7
  return @() styleLineForeground.__merge({
    watch = [IsAgmEmpty, HudColor, AlertColorHigh]
    rendObj = ROBJ_VECTOR_CANVAS
    size = [width, height]
    color = (!isBackground && IsAgmEmpty.value) ? AlertColorHigh.value
      : isBackground ? backgroundColor
      : HudColor.value
    commands = [
      [VECTOR_LINE, 50 - lhl, 50 - lvl, 50 + lhl, 50 - lvl],
      [VECTOR_LINE, 50 - lhl, 50 + lvl, 50 + lhl, 50 + lvl],
      [VECTOR_LINE, 50 - lhl, 50 - lvl, 50 - lhl, 50 + lvl],
      [VECTOR_LINE, 50 + lhl, 50 - lvl, 50 + lhl, 50 + lvl],
    ]
  })
}

local function laserDesignatorComponent(isBackground) {
  local width = hdpx(150)
  local height = hdpx(100)
  return @() {
    watch = IsLaserDesignatorEnabled
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
    opacity = IsLaserDesignatorEnabled.value ? 100 : 0
    size = SIZE_TO_CONTENT
    children = laserDesignator(width, height, isBackground)
  }
}

local laserTrigger = {}
local needLaserBlink = Computed(@() (!IsLaserDesignatorEnabled.value &&
  Agm.timeToHit.value > 0))

needLaserBlink.subscribe(@(v) v ? ::anim_start(laserTrigger) : ::anim_request_stop(laserTrigger))

local function getLaserText(laserEnabled, timeToHit, timeToWarning) {
  local texts = laserEnabled ? ::loc("HUD/TXT_LASER_DESIGNATOR")
    : (timeToHit > 0 && timeToWarning <= 0) ? ::loc("HUD/TXT_ENABLE_LASER_NOW")
    : ""
  return texts
}

local laserDesignatorStatusComponent = @(isBackground) function() {

  local res = {
    watch = [IsLaserDesignatorEnabled, Agm.timeToHit, Agm.timeToWarning, HudColor]
    animations = [{ prop = AnimProp.opacity, from = 1, to = 0, duration = 0.5, play = needLaserBlink.value, loop = true, easing = InOutSine, trigger = laserTrigger}]
    key = needLaserBlink
  }

  if (!IsLaserDesignatorEnabled.value && Agm.timeToHit.value <= 0)
    return res

  return res.__update({
    pos = [sw(50), sh(38)]
    rendObj = ROBJ_DTEXT
    halign = ALIGN_CENTER
    text = getLaserText(IsLaserDesignatorEnabled.value, Agm.timeToHit.value, Agm.timeToWarning.value)
    color = isBackground ? backgroundColor : HudColor.value
  })
}

local atgmTrackerStatusComponent = @(isBackground) function() {

  local res = {
    watch = [IsATGMOutOfTrackerSector, NoLosToATGM, HudColor]
    animations = [{ prop = AnimProp.opacity, from = 1, to = 0, duration = 0.5, play = true, loop = true, easing = InOutSine}]
  }

  if (!IsATGMOutOfTrackerSector.value && !NoLosToATGM.value)
    return res

  return res.__update({
    pos = [sw(50), sh(41)]
    halign = ALIGN_CENTER
    rendObj = ROBJ_DTEXT
    color = isBackground ? backgroundColor : HudColor.value
    text = IsATGMOutOfTrackerSector.value ? ::loc("HUD/TXT_ATGM_OUT_OF_TRACKER_SECTOR") : ::loc("HUD/TXT_NO_LOS_ATGM")
  })
}

local function aircraftRocketSightMode(sightMode){

  if (sightMode == 0) {
    return [
      [VECTOR_LINE, 0, 0, 0, 300],
      [VECTOR_LINE, 20, 0, -20, 0],
      [VECTOR_LINE, 40, 100, -40, 100],
      [VECTOR_LINE, 60, 200, -60, 200],
      [VECTOR_LINE, 80, 300, -80, 300]
    ]
  }
  else if (sightMode == 1) {
    return [
      [VECTOR_LINE, -50, -50, -25, -25],
      [VECTOR_LINE, -50, 50, -25, 25],
      [VECTOR_LINE, 50, -50, 25, -25],
      [VECTOR_LINE, 50, 50, 25, 25],
      [VECTOR_ELLIPSE, 0, 0, 1.0, 1.0]
    ]
  }

  return [
    [VECTOR_LINE, -100, -100, 100, -100],
    [VECTOR_LINE, -100, 100, 100, 100],
    [VECTOR_LINE, -20, -100, -20, 100],
    [VECTOR_LINE, 20, -100, 20, 100],
    [VECTOR_LINE, 40, 40, -40, 40],
    [VECTOR_LINE, 40, -40, -40, -40],
    [VECTOR_LINE, 60, 20, 60, -20],
    [VECTOR_LINE, -60, 20, -60, -20],
  ]
}


local aircraftRocketSight = @(width, height, isBackground) function() {

  local res = { watch = [RocketAimX, RocketAimY, RocketAimVisible] }

  if (!RocketAimVisible.value)
    return res

  local lines = @() styleLineForeground.__merge({
    watch = RocketSightMode
    rendObj = ROBJ_VECTOR_CANVAS
    fillColor = Color(0,0,0,0)
    size = [width, height]
    commands = aircraftRocketSightMode(RocketSightMode.value)
  })

  return res.__update({
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    pos = [RocketAimX.value, RocketAimY.value]
    children = [lines]
  })
}

local function laserPoint(isBackground) {
  return {
    size = [ph(1.5), ph(1.5)]
    rendObj = ROBJ_VECTOR_CANVAS
    color = HudColor.value
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

local function laserPointComponent(isBackground) {
  return @() {
    watch = HaveLaserPoint
    size = flex()
    children = HaveLaserPoint.value && !isBackground ? laserPoint(isBackground) : null
  }
}

return {
  aircraftTurretsComponent
  gunDirection
  fixedGunsDirection
  helicopterCCRP
  atgmTrackerStatusComponent
  laserDesignatorStatusComponent
  laserDesignatorComponent
  laserPointComponent
  agmTrackZoneComponent
  aircraftRocketSight
}