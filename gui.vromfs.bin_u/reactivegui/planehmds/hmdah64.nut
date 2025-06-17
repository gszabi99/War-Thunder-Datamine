from "%rGui/globals/ui_library.nut" import *
let { isInVr } = require("%rGui/style/screenState.nut")
let { floor, abs, fabs } = require("%sqstd/math.nut")
let { HorVelX, HorVelY, TATargetVisible, Rpm, TrtMode, RocketAimX, RocketAimY,
 CannonMode } = require("%rGui/airState.nut")
let { mpsToKnots, metrToFeet, mpsToFpm } = require("%rGui/planeIlses/ilsConstants.nut")
let { cvt } = require("dagor.math")
let { Speed, CompassValue, Altitude, ClimbSpeed, BarAltitude,
 Tangage, Roll, HorAccelX, HorAccelY, Accel } = require("%rGui/planeState/planeFlyState.nut")
let { hudFontHgt } = require("%rGui/style/airHudStyle.nut")
let { TargetX, TargetY } = require("%rGui/hud/targetTrackerState.nut")
let string = require("string")
let { HmdYaw, HmdPitch, AimLockYaw, AimLockPitch, AimLocked, ScreenFwdDirPos, TvvHMDMark,
 RocketMode, HmdTargetPosValid, HmdTargetPos, HmdGunTargeting } = require("%rGui/planeState/planeToolsState.nut")

let baseColor = isInVr ? Color(0, 255, 0, 30) : Color(0, 255, 0, 10)
let baseLineWidth = floor(LINE_WIDTH + 0.5)
let TrtModeForRpm = TrtMode[0]
let isHoverMode = Computed(@() TrtModeForRpm.value == AirThrottleMode.CLIMB)
let isTransitionMode = Computed(@() !isHoverMode.value && Speed.value <= 20.0)

let velVectLen = Computed(@() cvt(Speed.value * mpsToKnots, 0.0, isHoverMode.value ? 6.0 : 60.0, 0.0, 100.0).tointeger())
let velocityVector = @() {
  watch = [isHoverMode, isTransitionMode]
  size = flex()
  children = isHoverMode.value || isTransitionMode.value ?
    @(){
      watch = [HorVelX, HorVelY, velVectLen]
      pos = [pw(50), ph(50)]
      size = ph(15)
      rendObj = ROBJ_VECTOR_CANVAS
      color = baseColor
      lineWidth = baseLineWidth
      commands = [
        [VECTOR_LINE, 0, 0, -HorVelY.value * velVectLen.value, -HorVelX.value * velVectLen.value]
      ]
    }
  : null
}

let accVectLen = Computed(@() cvt(fabs(Accel.value), 0.0, 3.0, 0.0, 15.0).tointeger())
let accel = @() {
  watch = [isHoverMode, isTransitionMode]
  size = flex()
  children = isHoverMode.value || isTransitionMode.value ?
    @(){
      watch = [HorAccelX, HorAccelY, accVectLen]
      pos = [pw(50 - HorAccelY.value * accVectLen.value), ph(50 - HorAccelX.value * accVectLen.value)]
      size = ph(15)
      rendObj = ROBJ_VECTOR_CANVAS
      color = baseColor
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth
      commands = [
        [VECTOR_ELLIPSE, 0, 0, 2, 2]
      ]
    }
  : null
}

let losReticle = {
  rendObj = ROBJ_VECTOR_CANVAS
  size = ph(2.5)
  pos = [pw(50), ph(50)]
  color = baseColor
  lineWidth = baseLineWidth * 2.0
  commands = [
    [VECTOR_LINE, 30, 0, 100, 0],
    [VECTOR_LINE, -30, 0, -100, 0],
    [VECTOR_LINE, 0, 30, 0, 100],
    [VECTOR_LINE, 0, -30, 0, -100]
  ]
}

let CompassInt = Computed(@() ((360.0 + CompassValue.value) % 360.0).tointeger())
let generateCompassMark = function(num, width) {
  local text = num % 30 == 0 ? (num / 10).tostring() : ""
  if (num == 90)
    text = "E"
  else if (num == 180)
    text = "S"
  else if (num == 270)
    text = "W"
  else if (num == 0)
    text = "N"
  return {
    size = [width * 0.05, ph(100)]
    flow = FLOW_VERTICAL
    children = [
      {
        size = SIZE_TO_CONTENT
        rendObj = ROBJ_TEXT
        color = baseColor
        hplace = ALIGN_CENTER
        fontSize = hudFontHgt * 1.2
        font = Fonts.hud
        text = text
        behavior = Behaviors.RtPropUpdate
        update = @() {
          opacity = abs(num - CompassInt.value) < 20 ? 0.0 : 1.0
        }
      }
      {
        size = [baseLineWidth * 1.5, baseLineWidth * (num % 30 == 0 ? 6 : 4)]
        rendObj = ROBJ_SOLID
        color = baseColor
        hplace = ALIGN_CENTER
      }
    ]
  }
}

function compass(width, generateFunc) {
  let children = []
  let step = 10.0

  for (local i = 0; i <= 2.0 * 360.0 / step; ++i) {

    let num = (i * step) % 360

    children.append(generateFunc(num, width))
  }
  let getOffset = @() (360.0 + CompassValue.value) * 0.005 * width
  return {
    size = flex()
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [-getOffset() + 0.475 * width, 0]
      }
    }
    flow = FLOW_HORIZONTAL
    children = children
  }
}

function compassWrap(width, height, generateFunc) {
  return {
    size = [width * 0.2, height]
    pos = [width * 0.4, height * 0.25]
    clipChildren = true
    children = [
      compass(width * 0.2, generateFunc)
      {
        rendObj = ROBJ_SOLID
        color = baseColor
        size = [baseLineWidth * 2.0, ph(3)]
        pos = [width * 0.1 - baseLineWidth, height * 0.037]
      }
    ]
  }
}

let compassVal = @(){
  size = const [pw(4), ph(3)]
  pos = [pw(48), ph(24.5)]
  watch = CompassInt
  rendObj = ROBJ_TEXT
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  color = baseColor
  font = Fonts.hud
  fontSize = hudFontHgt * 1.5
  text = CompassInt.value.tostring()
}

let cuedLosReticleVis = Computed(@() TATargetVisible.value && TargetX.value >= sw(30) && TargetX.value <= sw(70) && TargetY.value >= sh(30) && TargetY.value <= sh(80))
let cuedLosReticle = @(){
    watch = cuedLosReticleVis
    size = flex()
    children = cuedLosReticleVis.value ? {
      rendObj = ROBJ_VECTOR_CANVAS
      size = ph(3)
      color = baseColor
      lineWidth = baseLineWidth * 2.0
      commands = [
        [VECTOR_LINE, 30, 0, 50, 0],
        [VECTOR_LINE, 80, 0, 100, 0],
        [VECTOR_LINE, -30, 0, -50, 0],
        [VECTOR_LINE, -80, 0, -100, 0],
        [VECTOR_LINE, 0, 30, 0, 50],
        [VECTOR_LINE, 0, 80, 0, 100],
        [VECTOR_LINE, 0, -30, 0, -50],
        [VECTOR_LINE, 0, -80, 0, -100]
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = [TargetX.value, TargetY.value]
        }
      }
    } : null
}

let upCueDotVis = Computed(@() sh(50) - TargetY.value > sh(4))
let leftCueDotVis = Computed(@() sw(50) - TargetX.value > sh(4))
let rightCueDotVis = Computed(@() TargetX.value - sw(50) > sh(4))
let bottomCueDotVis = Computed(@() TargetY.value - sh(50) > sh(4))
let cueDots = @(){
  watch = TATargetVisible
  size = flex()
  children = TATargetVisible.value ? [
    @() {
      watch = upCueDotVis
      size = flex()
      children = upCueDotVis.value ? {
        rendObj = ROBJ_VECTOR_CANVAS
        pos = [pw(50), ph(46.5)]
        color = baseColor
        lineWidth = baseLineWidth * 3.5
        commands = [
          [VECTOR_LINE, 0, 0, 0, 0]
        ]
      } : null
    }
    @() {
      watch = leftCueDotVis
      size = flex()
      children = leftCueDotVis.value ? {
        rendObj = ROBJ_VECTOR_CANVAS
        pos = [pw(48.3), ph(50)]
        color = baseColor
        lineWidth = baseLineWidth * 3.5
        commands = [
          [VECTOR_LINE, 0, 0, 0, 0]
        ]
      } : null
    }
    @() {
      watch = rightCueDotVis
      size = flex()
      children = rightCueDotVis.value ? {
        rendObj = ROBJ_VECTOR_CANVAS
        pos = [pw(51.7), ph(50)]
        color = baseColor
        lineWidth = baseLineWidth * 3.5
        commands = [
          [VECTOR_LINE, 0, 0, 0, 0]
        ]
      } : null
    }
    @() {
      watch = bottomCueDotVis
      size = flex()
      children = bottomCueDotVis.value ? {
        rendObj = ROBJ_VECTOR_CANVAS
        pos = [pw(50), ph(53.5)]
        color = baseColor
        lineWidth = baseLineWidth * 3.5
        commands = [
          [VECTOR_LINE, 0, 0, 0, 0]
        ]
      } : null
    }
  ] : null
}

let showAltitudeBar = Computed(@() Altitude.value <= 60.96)
let climbSpeedGrid = @(){
  watch = showAltitudeBar
  size = const [pw(2), ph(30)]
  pos = [pw(65), ph(35)]
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = baseLineWidth
  color = baseColor
  commands = [
    [VECTOR_LINE, 0, 0, 40, 0],
    [VECTOR_LINE, 0, 25, 40, 25],
    [VECTOR_LINE, 20, 30, 40, 30],
    [VECTOR_LINE, 20, 35, 40, 35],
    [VECTOR_LINE, 20, 40, 40, 40],
    [VECTOR_LINE, 20, 45, 40, 45],
    [VECTOR_LINE, 20, 55, 40, 55],
    [VECTOR_LINE, 20, 60, 40, 60],
    [VECTOR_LINE, 20, 65, 40, 65],
    [VECTOR_LINE, 20, 70, 40, 70],
    [VECTOR_LINE, 0, 75, 40, 75],
    [VECTOR_LINE, 0, 100, 40, 100],
    [VECTOR_WIDTH, baseLineWidth * 1.8],
    [VECTOR_LINE, 0, 50, 50, 50]
  ]
  children = showAltitudeBar.value ? {
    size = flex()
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth
    color = baseColor
    commands = [
      [VECTOR_LINE, 60, 0, 100, 0],
      [VECTOR_LINE, 60, 25, 100, 25],
      [VECTOR_LINE, 60, 50, 100, 50],
      [VECTOR_LINE, 60, 75, 100, 75],
      [VECTOR_LINE, 60, 80, 80, 80],
      [VECTOR_LINE, 60, 85, 80, 85],
      [VECTOR_LINE, 60, 90, 80, 90],
      [VECTOR_LINE, 60, 95, 80, 95],
      [VECTOR_LINE, 60, 100, 100, 100]
    ]
  } : null
}

let altValue = Computed(@() (Altitude.value * metrToFeet < 50.0 ? Altitude.value * metrToFeet : Altitude.value * metrToFeet * 0.1).tointeger())
let altitudeText = @() {
  watch = altValue
  size = const [pw(3), ph(2)]
  pos = [pw(61), ph(49.3)]
  rendObj = ROBJ_TEXT
  color = baseColor
  halign = ALIGN_RIGHT
  valign = ALIGN_CENTER
  font = Fonts.hud
  fontSize = hudFontHgt
  text = (Altitude.value * metrToFeet < 50.0 ? altValue.value : altValue.value * 10).tostring()
}

function climbSpeedMark(width, height){
  return {
    size = const [ph(1), ph(0.5)]
    rendObj = ROBJ_VECTOR_CANVAS
    color = baseColor
    lineWidth = baseLineWidth
    fillColor = baseColor
    commands = [
      [VECTOR_POLY, 0, -100, 100, 0, 0, 100]
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [width * 0.643, height * (0.5 + cvt(ClimbSpeed.value * mpsToFpm, -1000.0, 1000.0, 0.15, -0.15))]
      }
    }
  }
}

let altitudeBarLen = Computed(@() clamp(Altitude.value * metrToFeet * 0.5, 0.0, 100.0).tointeger())
let altitudeBar = @(){
  watch = showAltitudeBar
  size = const [pw(2), ph(30)]
  pos = [pw(66), ph(35)]
  children = showAltitudeBar.value ? @(){
    watch = altitudeBarLen
    size = [baseLineWidth * 3.0, ph(altitudeBarLen.value)]
    pos = [-baseLineWidth * 1.5, ph(100 - altitudeBarLen.value)]
    rendObj = ROBJ_SOLID
    color = baseColor
  } : null
}

let lowAlt = @(){
  watch = showAltitudeBar
  size = flex()
  children = showAltitudeBar.value ? {
    rendObj = ROBJ_TEXT
    size = SIZE_TO_CONTENT
    pos = [pw(62.8), ph(52)]
    color = baseColor
    font = Fonts.hud
    fontSize = hudFontHgt * 1.2
    text = "LO"
  } : null
}

function climbSpeed(width, height) {
  return {
    size = flex()
    children = [
      climbSpeedGrid
      altitudeText
      climbSpeedMark(width, height)
      altitudeBar
      lowAlt
    ]
  }
}

let speedVal = Computed(@() (Speed.value * mpsToKnots).tointeger())
let speed = @(){
  watch = speedVal
  size = SIZE_TO_CONTENT
  pos = [pw(35), ph(49)]
  rendObj = ROBJ_TEXT
  color = baseColor
  font = Fonts.hud
  fontSize = hudFontHgt
  text = speedVal.value.tointeger()
  children = speedVal.value >= 210 ? {
    size = const [pw(150), ph(150)]
    pos = [pw(-25), ph(-25)]
    rendObj = ROBJ_BOX
    fillColor = Color(0, 0, 0, 0)
    borderColor = baseColor
    borderWidth = baseLineWidth
    borderRadius = hdpx(5)
  } : null
}

let engineTorq = @(){
  watch = Rpm
  size = const [pw(2.5), ph(3)]
  pos = [pw(35.5), ph(35)]
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  rendObj = ROBJ_TEXT
  color = baseColor
  font = Fonts.hud
  fontSize = hudFontHgt
  text = string.format("%d%%", Rpm.value)
  children = Rpm.value >= 98 ? {
    size = flex()
    rendObj = ROBJ_BOX
    fillColor = Color(0, 0, 0, 0)
    borderColor = baseColor
    borderWidth = baseLineWidth
    borderRadius = hdpx(5)
  } : null
}

let hmdPosX = Computed(@() cvt(HmdYaw.value, -72.0, 72.0, 0.0, 80.0).tointeger())
let hmdPosY = Computed(@() cvt(HmdPitch.value, 13.0, -32.0, 0.0, 60.0).tointeger())
let aimLockX = Computed(@() cvt(AimLockYaw.value, -90.0, 90.0, 0.0, 100.0).tointeger())
let aimLockY = Computed(@() cvt(AimLockPitch.value, 20.0, -45.0, 0.0, 100.0).tointeger())
function fieldOfRegard(width, height) {
  return {
    rendObj = ROBJ_BOX
    size = const [ph(18), ph(6)]
    pos = [width * 0.5 - height * 0.09, ph(70)]
    fillColor = Color(0, 0, 0, 0)
    borderColor = baseColor
    borderWidth = baseLineWidth
    children = [
      {
        rendObj = ROBJ_VECTOR_CANVAS
        size = flex()
        color = baseColor
        lineWidth = baseLineWidth
        commands = [
          [VECTOR_LINE, 50, 1, 50, 10],
          [VECTOR_LINE, 50, 90, 50, 99],
          [VECTOR_LINE, 1, 30, 5, 30],
          [VECTOR_LINE, 95, 30, 99, 30]
        ]
        children = [
          @(){
            watch = [hmdPosX, hmdPosY]
            size = const [pw(20), ph(40)]
            pos = [pw(hmdPosX.value), ph(hmdPosY.value)]
            rendObj = ROBJ_BOX
            fillColor = Color(0, 0, 0, 0)
            borderColor = baseColor
            borderWidth = baseLineWidth * 0.8
          }
          @() {
            watch = AimLocked
            size = flex()
            children = AimLocked.value ? @(){
              watch = [aimLockX, aimLockY]
              size = flex()
              pos = [pw(aimLockX.value), ph(aimLockY.value)]
              rendObj = ROBJ_VECTOR_CANVAS
              color = baseColor
              lineWidth = baseLineWidth * 5
              commands = [
                [VECTOR_LINE, 0, 0, 0, 0]
              ]
            } : null
          }
        ]
      }
    ]
  }
}

let phmd = {
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(36), ph(70)]
  color = baseColor
  font = Fonts.hud
  fontSize = hudFontHgt
  text = "P-HMD"
}

let gunsModeLocal = CannonMode[0]
let gunModeWatched = Computed(@() (gunsModeLocal.value & (1 << WeaponMode.CCRP_MODE)) ? "TADS" : (HmdGunTargeting.get() ? "PHS" : "FXD"))
let gunMode = @(){
  watch = gunModeWatched
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(63), ph(70)]
  color = baseColor
  font = Fonts.hud
  fontSize = hudFontHgt
  text = gunModeWatched.value
}

let headTracker = {
  size = ph(3)
  rendObj = ROBJ_VECTOR_CANVAS
  color = baseColor
  lineWidth = baseLineWidth
  commands = [
    [VECTOR_LINE, -100, 0, -70, 30],
    [VECTOR_LINE, -100, 0, -70, -30],
    [VECTOR_LINE, -30, -70, 0, -100],
    [VECTOR_LINE, 30, -70, 0, -100],
    [VECTOR_LINE, 100, 0, 70, 30],
    [VECTOR_LINE, 100, 0, 70, -30],
    [VECTOR_LINE, -30, 70, 0, 100],
    [VECTOR_LINE, 30, 70, 0, 100]
  ]
  behavior = Behaviors.RtPropUpdate
  update = function() {
    let visible = ScreenFwdDirPos[0] >= sw(30) && ScreenFwdDirPos[0] <= sw(70) && ScreenFwdDirPos[1] >= sh(30) && ScreenFwdDirPos[1] <= sh(80)
    return {
      opacity = visible ? 1.0 : 0.0
      transform = {
        translate = ScreenFwdDirPos
      }
    }
  }
}

let barAltValue = Computed(@() (BarAltitude.value * metrToFeet).tointeger())
let barAltitude = @(){
  watch = [isHoverMode, isTransitionMode]
  size = flex()
  children = !isHoverMode.value && !isTransitionMode.value ? @(){
    watch = barAltValue
    size = SIZE_TO_CONTENT
    pos = [pw(62), ph(34)]
    rendObj = ROBJ_TEXT
    color = baseColor
    font = Fonts.hud
    fontSize = hudFontHgt
    text = barAltValue.value.tostring()
  } : null
}

let bank = Computed(@() cvt(HorAccelY.value * fabs(Accel.value), -1.5, 1.5, -50.0, 50.0).tointeger())
let skidBall = {
  size = const [pw(3), ph(2)]
  pos = [pw(48.5), ph(68)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = baseColor
  lineWidth = baseLineWidth
  commands = [
    [VECTOR_LINE, 30, 0, 30, 100],
    [VECTOR_LINE, 70, 0, 70, 100]
  ]
  children = @(){
    watch = bank
    rendObj = ROBJ_VECTOR_CANVAS
    size = pw(40)
    pos = [pw(50 - bank.value), ph(50)]
    lineWidth = baseLineWidth
    color = baseColor
    fillColor = baseColor
    commands = [
      [VECTOR_ELLIPSE, 0, 0, 30, 30]
    ]
  }
}


function angleTxt(num, isLeft, x = 0, y = 0) {
  return {
    pos = [x, y]
    rendObj = ROBJ_TEXT
    vplace = num < 0 ? ALIGN_BOTTOM : ALIGN_TOP
    hplace = isLeft ? ALIGN_LEFT : ALIGN_RIGHT
    color = baseColor
    fontSize = hudFontHgt
    font = Fonts.hud
    text = abs(num).tostring()
  }
}

function generatePitchLine(num) {
  let sign = num > 0 ? 1 : -1
  let newNum = num >= 0 ? num : (num - 10)
  return {
    size = const [pw(60), ph(50)]
    pos = [pw(20), 0]
    flow = FLOW_VERTICAL
    children = num == 0 ? [
      {
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth
        color = baseColor
        padding = const [0, 10]
        commands = [
          [VECTOR_LINE, -50, 0, 150, 0]
        ]
        children = [angleTxt(-10, true, pw(-20)), angleTxt(-10, false, pw(20))]
      }
    ] :
    [
      {
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth
        color = baseColor
        commands = [
          [VECTOR_LINE, 0, 10 * sign, 0, 0],
          [VECTOR_LINE, 0, 0, num > 0 ? 30 : 5, 0 ],
          (num < 0 ? [VECTOR_LINE, 10, 0, 17, 0] : []),
          (num < 0 ? [VECTOR_LINE, 23, 0, 30, 0] : []),
          [VECTOR_LINE, 100, 10 * sign, 100, 0],
          [VECTOR_LINE, 100, 0, num > 0 ? 70 : 95, 0],
          (num < 0 ? [VECTOR_LINE, 90, 0, 83, 0] : []),
          (num < 0 ? [VECTOR_LINE, 77, 0, 70, 0] : [])
        ]
        children = newNum <= 90 ? [angleTxt(newNum, true, pw(-15)), angleTxt(newNum, false, pw(15))] : null
      }
    ]
  }
}


function pitch(width, height, generateFunc) {
  const step = 10.0
  let children = []

  for (local i = 90.0 / step; i >= -90.0 / step; --i) {
    let num = (i * step).tointeger()

    children.append(generateFunc(num))
  }

  return {
    size = [width * 0.4, height * 0.5]
    pos = [width * 0.3, height * 0.5]
    flow = FLOW_VERTICAL
    children = children
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, -height * (90.0 - Tangage.value) * 0.025]
        rotate = -Roll.value
        pivot = [0.5, (90.0 - Tangage.value) * 0.05]
      }
    }
  }
}

let rocketVisible = Computed(@() RocketAimX.value >= sw(30) && RocketAimX.value <= sw(70) && RocketAimY.value >= sh(30) && RocketAimY.value <= sh(80))
let rocketReticle = @(){
  watch = [RocketMode, rocketVisible]
  size = flex()
  children = RocketMode.value && rocketVisible.value ? {
    size = const [pw(1), ph(3.2)]
    rendObj = ROBJ_VECTOR_CANVAS
    color = baseColor
    lineWidth = baseLineWidth * 1.5
    commands = [
      [VECTOR_LINE, 0, -90, 0, -20],
      [VECTOR_LINE, 0, 90, 0, 20],
      [VECTOR_LINE, -100, -100, -20, -100],
      [VECTOR_LINE, 100, -100, 20, -100],
      [VECTOR_LINE, 100, 100, 20, 100],
      [VECTOR_LINE, -100, 100, -20, 100]
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [RocketAimX.value, RocketAimY.value]
      }
    }
  } : null
}

let tvvMark = @(){
  watch = isHoverMode
  size = flex()
  children = !isHoverMode.value ? {
    size = ph(2)
    rendObj = ROBJ_VECTOR_CANVAS
    color = baseColor
    fillColor = Color(0, 0, 0, 0)
    lineWidth = baseLineWidth * 1.5
    commands = [
      [VECTOR_ELLIPSE, 0, 0, 50, 50],
      [VECTOR_LINE, -100, 0, -50, 0],
      [VECTOR_LINE, 100, 0, 50, 0],
      [VECTOR_LINE, 0, -100, 0, -50]
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = TvvHMDMark
      }
    }
  } : null
}

function pitchWrap(width, height) {
  return @(){
    watch = [isHoverMode, isTransitionMode]
    size = const [pw(40), ph(50)]
    pos = [pw(30), ph(25)]
    clipChildren = true
    children = !isHoverMode.value && !isTransitionMode.value ? [
      pitch(width * 0.4, height * 0.5, generatePitchLine)
      {
        rendObj = ROBJ_VECTOR_CANVAS
        size = flex()
        color = baseColor
        lineWidth = baseLineWidth
        fillColor = baseColor
        commands = [
          [VECTOR_POLY, 49.25, 10, 50, 8, 50.75, 10]
        ]
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            rotate = -Roll.value
            pivot = [0.5, 0.5]
          }
        }
      }
     ] : null
  }
}

function horizontLine(height) {
  return @() {
    watch = isTransitionMode
    size = const [pw(24), ph(50)]
    pos = [pw(38), ph(25)]
    clipChildren = true
    children = isTransitionMode.value ? {
      size = flex()
      rendObj = ROBJ_VECTOR_CANVAS
      color = baseColor
      lineWidth = baseLineWidth
      commands = [
        [VECTOR_LINE, 0, 0, 40, 0],
        [VECTOR_LINE, 60, 0, 100, 0]
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = [0, (0.25 + Tangage.value * 0.005) * height]
          rotate = -Roll.value
          pivot = [0.5, 0]
        }
      }
    } : null
  }
}

let gunReticle = @(){
    watch = [RocketMode, HmdTargetPosValid, TATargetVisible]
    size = flex()
    children = !RocketMode.value && HmdTargetPosValid.value && !TATargetVisible.value ? {
      rendObj = ROBJ_VECTOR_CANVAS
      size = ph(3)
      color = baseColor
      lineWidth = baseLineWidth * 2.0
      commands = [
        [VECTOR_LINE, 30, 0, 50, 0],
        [VECTOR_LINE, 80, 0, 100, 0],
        [VECTOR_LINE, -30, 0, -50, 0],
        [VECTOR_LINE, -80, 0, -100, 0],
        [VECTOR_LINE, 0, 30, 0, 50],
        [VECTOR_LINE, 0, 80, 0, 100],
        [VECTOR_LINE, 0, -30, 0, -50],
        [VECTOR_LINE, 0, -80, 0, -100]
      ]
      behavior = Behaviors.RtPropUpdate
      update = function() {
        let visible = HmdTargetPos[0] >= sw(30) && HmdTargetPos[0] <= sw(70) && HmdTargetPos[1] >= sh(30) && HmdTargetPos[1] <= sh(80)
        return {
          opacity = visible ? 1.0 : 0.0
          transform = {
            translate = HmdTargetPos
          }
        }
      }
    } : null
}

function hmd(width, height) {
  return {
    size = [width, height]
    children = [
      velocityVector
      accel
      losReticle
      compassWrap(width, height, generateCompassMark)
      compassVal
      cuedLosReticle
      cueDots
      climbSpeed(width, height)
      speed
      engineTorq
      fieldOfRegard(width, height)
      phmd
      headTracker
      barAltitude
      skidBall
      pitchWrap(width, height)
      gunMode
      horizontLine(height)
      tvvMark
      rocketReticle
      gunReticle
    ]
  }
}

return hmd