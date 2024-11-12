from "%rGui/globals/ui_library.nut" import *

let { Speed, Altitude, Roll, Tangage, Mach, CompassValue, Tas, ClimbSpeed } = require("%rGui/planeState/planeFlyState.nut")
let { baseLineWidth, mpsToKnots, metrToFeet, degToRad, metrToNavMile, mpsToFpm } = require("ilsConstants.nut")
let { IlsColor, IlsLineScale, IlsPosSize, TvvMark, BombingMode, AimLockPos,
 AimLockValid, TimeBeforeBombRelease, AimLockDist } = require("%rGui/planeState/planeToolsState.nut")
let { format } = require("string")
let { cvt } = require("dagor.math")
let { cos, sin, abs } = require("%sqstd/math.nut")
let { cancelBombing } = require("commonElements.nut")

let SpeedValue = Computed(@() (Speed.get() * mpsToKnots).tointeger())
let speed = @(){
  watch = IlsColor
  rendObj = ROBJ_FRAME
  pos = [pw(10), ph(50)]
  size = [pw(10), ph(5)]
  color = IlsColor.get()
  borderWidth = baseLineWidth * IlsLineScale.get() * 0.5
  children = @(){
    watch = SpeedValue
    size = flex()
    rendObj = ROBJ_TEXT
    color = IlsColor.get()
    fontSize = 45
    padding = [0, 2]
    text = SpeedValue.get().tostring()
    halign = ALIGN_RIGHT
    valign = ALIGN_CENTER
  }
}

let AltValue = Computed(@() (Altitude.get() * metrToFeet).tointeger())
let altitude = @(){
  watch = IlsColor
  rendObj = ROBJ_FRAME
  pos = [pw(80), ph(50)]
  size = [pw(12), ph(5)]
  color = IlsColor.get()
  borderWidth = baseLineWidth * IlsLineScale.get() * 0.5
  flow = FLOW_HORIZONTAL
  halign = ALIGN_RIGHT
  children = [
    @(){
      watch = AltValue
      size = [SIZE_TO_CONTENT, flex()]
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      fontSize = 45
      text = (AltValue.get() / 1000).tostring()
      halign = ALIGN_RIGHT
      valign = ALIGN_CENTER
    }
    @(){
      watch = AltValue
      size = [SIZE_TO_CONTENT, flex()]
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      fontSize = 35
      padding = [0, 2]
      text = format("%03d", AltValue.get() % 1000)
      halign = ALIGN_RIGHT
      valign = ALIGN_CENTER
    }
  ]
}

let rollIndicator = @(){
  watch = IlsColor
  pos = [pw(50), ph(50)]
  size = [pw(35), ph(35)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.get()
  lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
  commands = [
    [VECTOR_LINE, 0, 90, 0, 100],
    [VECTOR_LINE, 90 * sin(5 * degToRad), 90 * cos(5 * degToRad), 95 * sin(5 * degToRad), 95 * cos(5 * degToRad)],
    [VECTOR_LINE, 90 * sin(10 * degToRad), 90 * cos(10 * degToRad), 100 * sin(10 * degToRad), 100 * cos(10 * degToRad)],
    [VECTOR_LINE, 90 * sin(20 * degToRad), 90 * cos(20 * degToRad), 100 * sin(20 * degToRad), 100 * cos(20 * degToRad)],
    [VECTOR_LINE, 90 * sin(30 * degToRad), 90 * cos(30 * degToRad), 100 * sin(30 * degToRad), 100 * cos(30 * degToRad)],
    [VECTOR_LINE, 90 * sin(-5 * degToRad), 90 * cos(-5 * degToRad), 95 * sin(-5 * degToRad), 95 * cos(-5 * degToRad)],
    [VECTOR_LINE, 90 * sin(-10 * degToRad), 90 * cos(-10 * degToRad), 100 * sin(-10 * degToRad), 100 * cos(-10 * degToRad)],
    [VECTOR_LINE, 90 * sin(-20 * degToRad), 90 * cos(-20 * degToRad), 100 * sin(-20 * degToRad), 100 * cos(-20 * degToRad)],
    [VECTOR_LINE, 90 * sin(-30 * degToRad), 90 * cos(-30 * degToRad), 100 * sin(-30 * degToRad), 100 * cos(-30 * degToRad)]
  ]
  children = {
    rendObj = ROBJ_VECTOR_CANVAS
    size = flex()
    color = IlsColor.get()
    lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
    fillColor = Color(0, 0, 0, 0)
    commands = [
      [VECTOR_POLY, 0, 88, -4, 80, 4, 80]
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        rotate = -Roll.get()
        pivot = [0.0, 0.0]
      }
    }
  }
}

function generatePitchLine(num) {
  let sign = num > 0 ? 1 : -1
  let angle = max(abs(num), 0) * degToRad
  return {
    size = [pw(50), ph(50)]
    pos = [pw(25), 0]
    children = [
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
        color = IlsColor.value
        commands = [
          (num == 0 ? [VECTOR_LINE, 0, 0, 30, 0] : []),
          (num == 0 ? [VECTOR_LINE, 70, 0, 100, 0] : []),
          (num == 0 ? [VECTOR_LINE, 100, 0, 100, 5] : []),
          (num == 0 ? [VECTOR_LINE, 0, 0, 0, 5] : []),
          (num > 0 ? [VECTOR_LINE, 12, 0, 30, 30 * sin(angle)] : []),
          (num > 0 ? [VECTOR_LINE, 70, 30 * sin(angle), 88, 0] : []),
          (num != 0 ? [VECTOR_LINE, 88, 0, 88, 5 * sign] : []),
          (num != 0 ? [VECTOR_LINE, 12, 0, 12, 5 * sign] : []),
          (num < 0 ? [VECTOR_LINE_DASHED, 12, 0, 30, -28 * sin(angle), 20, 20] : []),
          (num < 0 ? [VECTOR_LINE_DASHED, 64, -28 * sin(angle), 88, 0, 20, 20] : [])
        ]
      },
      (num != 0 ? @() {
        size = SIZE_TO_CONTENT
        pos = [pw(90), ph(-5)]
        watch = IlsColor
        rendObj = ROBJ_TEXT
        lineWidth = baseLineWidth * IlsLineScale.get()
        color = IlsColor.get()
        fontSize = 35
        font = Fonts.hud
        text = num.tostring()
      } : null),
      (num != 0 ? @() {
        size = [pw(20), SIZE_TO_CONTENT]
        pos = [pw(-10), ph(-5)]
        watch = IlsColor
        rendObj = ROBJ_TEXT
        lineWidth = baseLineWidth * IlsLineScale.get()
        color = IlsColor.get()
        fontSize = 35
        font = Fonts.hud
        text = num.tostring()
        halign = ALIGN_RIGHT
      } : null)
    ]
  }
}

function pitch(width, height, generateFunc) {
  const step = 5.0
  let children = []

  for (local i = 90.0 / step; i >= -90.0 / step; --i) {
    let num = (i * step).tointeger()

    children.append(generateFunc(num))
  }
  return {
    size = [width * 0.75, height * 0.5]
    flow = FLOW_VERTICAL
    children = children
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, -height * (90.0 - Tangage.get()) * 0.05]
        rotate = -Roll.get()
        pivot = [0.5, (90.0 - Tangage.get()) * 0.1]
      }
    }
  }
}

function pitchWrap(width, height) {
  return {
    size = [pw(50), ph(50)]
    pos = [pw(-37.5), 0]
    children = pitch(width, height, generatePitchLine)
  }
}

function tvvLinked(width, height) {
  return {
    size = flex()
    children = [
      @(){
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        size = [pw(4), ph(4)]
        color = IlsColor.get()
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
        commands = [
          [VECTOR_ELLIPSE, 0, 0, 30, 30],
          [VECTOR_LINE, -100, 0, -30, 0],
          [VECTOR_LINE, 100, 0, 30, 0],
          [VECTOR_LINE, 0, -80, 0, -30]
        ]
      }
      pitchWrap(width, height)
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = TvvMark
      }
    }
  }
}

let MachValue = Computed(@() (Mach.get() * 100).tointeger())
let mach = @(){
  watch = [IlsColor, MachValue]
  rendObj = ROBJ_TEXT
  size = [pw(7), ph(5)]
  pos = [pw(10), ph(45)]
  color = IlsColor.get()
  fontSize = 35
  halign = ALIGN_RIGHT
  valign = ALIGN_BOTTOM
  text = MachValue.get() >= 100.0 ? format("%.2f", Mach.get()) : format(".%02d", MachValue.get())
}

let generateCompassMark = function(num, width) {
  return {
    size = [width * 0.05, ph(100)]
    pos = [0, 40]
    children = [
      {
        size = SIZE_TO_CONTENT
        pos = [0, -40]
        rendObj = ROBJ_TEXT
        color = IlsColor.get()
        hplace = ALIGN_CENTER
        fontSize = 35
        text = num % 30 == 0 ? (num / 10).tostring() : ""
      }
      {
        size = [baseLineWidth * 0.8, baseLineWidth * (num % 10 == 0 ? 6 : 3)]
        pos = [0, baseLineWidth * (num % 10 == 0 ? 0 : 3)]
        rendObj = ROBJ_SOLID
        color = IlsColor.get()
        lineWidth = baseLineWidth
        hplace = ALIGN_CENTER
      }
    ]
  }
}

function compass(width, generateFunc) {
  let children = []
  let step = 5.0

  for (local i = 0; i <= 2.0 * 360.0 / step; ++i) {

    let num = (i * step) % 360

    children.append(generateFunc(num, width))
  }
  let getOffset = @() (360.0 + CompassValue.get()) * 0.01 * width
  return {
    size = flex()
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [-getOffset() + 0.425 * width, 0]
      }
    }
    flow = FLOW_HORIZONTAL
    children = children
  }
}

function compassWrap(width, height, generateFunc) {
  return {
    size = [width * 0.4, height]
    pos = [width * 0.3, height * 0.1]
    clipChildren = true
    children = [
      compass(width * 0.4, generateFunc)
    ]
  }
}

let CompassInt = Computed(@() ((360.0 + CompassValue.value) % 360.0).tointeger())
let compassVal = @(){
  watch = IlsColor
  size = [pw(8), ph(5)]
  pos = [pw(46), ph(8)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.get()
  lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
  fillColor = Color(0, 0, 0, 0)
  commands = [
    [VECTOR_RECTANGLE, 0, 0, 100, 100]
  ]
  children = [
    @() {
      watch = CompassInt
      rendObj = ROBJ_TEXT
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      size = flex()
      color = IlsColor.get()
      lineWidth = baseLineWidth
      fontSize = 45
      text = CompassInt.value.tostring()
    }
  ]
}

let gsValue = Computed(@() (Tas.get() * mpsToKnots).tointeger())
let groundSpeed = @(){
  watch = gsValue
  pos = [pw(13), ph(10)]
  rendObj = ROBJ_TEXT
  size = SIZE_TO_CONTENT
  color = IlsColor.get()
  fontSize = 35
  text = format("GS %d", gsValue.get())
}

let aimLockDistVal = Computed(@() (AimLockDist.get() * metrToNavMile * 10.0).tointeger())
let aimLock = @(){
  watch = AimLockValid
  size = flex()
  children = AimLockValid.get() ? [
    @(){
      watch = IlsColor
      size = [pw(4), ph(4)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
      fillColor = 0
      commands = [
        [VECTOR_RECTANGLE, -50, -50, 100, 100]
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = AimLockPos
        }
      }
    }
    @(){
      watch = [IlsColor, aimLockDistVal]
      size = SIZE_TO_CONTENT
      pos = [pw(70), ph(85)]
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      fontSize = 35
      text = format("DME %.1f", aimLockDistVal.get() * 0.1)
    }
  ] : null
}

let markH = Computed(@() cvt(ClimbSpeed.get() * mpsToFpm, 1000, -2000, 0, 100).tointeger())
let ClimbValue = Computed(@() (ClimbSpeed.get() * mpsToFpm * 0.1).tointeger())
let verticalSpeed = @() {
  watch = [markH, IlsColor]
  rendObj = ROBJ_VECTOR_CANVAS
  size = [pw(5), ph(30)]
  pos = [pw(80), ph(10)]
  color = IlsColor.get()
  fillColor = IlsColor.get()
  lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
  commands = [
    [VECTOR_LINE, 0, 0, 50, 0],
    [VECTOR_LINE, 25, 16, 50, 16],
    [VECTOR_LINE, 25, 52, 50, 52],
    [VECTOR_LINE, 0, 68, 50, 68],
    [VECTOR_LINE, 25, 84, 50, 84],
    [VECTOR_LINE, 0, 100, 50, 100],
    [VECTOR_LINE, 0, 34, 50, 34],
    [VECTOR_POLY, 55, markH.get(), 80, markH.get() - 2, 80, markH.get() + 2],
    [VECTOR_LINE, 100, 34, 100, markH.get()],
    [VECTOR_LINE, 80, markH.get(), 100, markH.get()]
  ]
  children = @(){
    watch = ClimbValue
    rendObj = ROBJ_TEXT
    pos = [pw(120), ph(28)]
    size = SIZE_TO_CONTENT
    color = IlsColor.get()
    fontSize = 35
    text = (ClimbValue.get() * 10).tostring()
  }
}

let lowerSolutionCue = @(){
  watch = IlsColor
  size = [pw(10), baseLineWidth * IlsLineScale.get() * 0.5]
  rendObj = ROBJ_SOLID
  color = IlsColor.get()
  behavior = Behaviors.RtPropUpdate
  update = function() {
    let cuePos = TimeBeforeBombRelease.get() <= 0.0 ? 0.4 : cvt(TimeBeforeBombRelease.get(), 0.0, 10.0, 0, 0.4)
    return {
      transform = {
        translate = [IlsPosSize[2] * - 0.05, TvvMark[1] - cuePos * IlsPosSize[3]]
      }
    }
  }
}

function rotatedBombReleaseReticle() {
  return {
    size = flex()
    children = [
      lowerSolutionCue,
      {
        size = flex()
        children = [
          @() {
            watch = IlsColor
            size = [baseLineWidth * IlsLineScale.get() * 0.5, flex()]
            rendObj = ROBJ_SOLID
            color = IlsColor.get()
          }
        ]
      }
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [AimLockPos[0], 0]
        rotate = -Roll.get()
        pivot = [0, AimLockPos[1] / IlsPosSize[3]]
      }
    }
  }
}

let timeRelease = Computed(@() TimeBeforeBombRelease.get().tointeger())
let ccrp = @(){
  watch = BombingMode
  size = flex()
  children = BombingMode.get() ? [
    @(){
      watch = timeRelease
      pos = [pw(12), ph(85)]
      size = flex()
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      fontSize = 35
      text = format("TTG %02d:%02d", timeRelease.get() / 60, timeRelease.get() % 60)
    }
    rotatedBombReleaseReticle()
    cancelBombing(50, 70)
   ] : null
}

function ilsF117(width, height) {
  return {
    size = [width, height]
    children = [
      speed
      altitude
      rollIndicator
      tvvLinked(width, height)
      mach
      compassWrap(width, height, generateCompassMark)
      compassVal
      groundSpeed
      aimLock
      verticalSpeed
      ccrp
    ]
  }
}

return ilsF117