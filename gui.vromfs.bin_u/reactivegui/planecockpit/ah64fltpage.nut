from "%rGui/globals/ui_library.nut" import *

let { Tas, CompassValue, Altitude, Tangage, Roll, BarAltitude, ClimbSpeed,
 Overload, HorAccelY, Accel, TurnRate } = require("%rGui/planeState/planeFlyState.nut")
let { abs, fabs } = require("%sqstd/math.nut")
let { Rpm, TrtMode, EngineTemperature, HorVelX, HorVelY } = require("%rGui/airState.nut")
let string = require("string")
let { cvt } = require("dagor.math")
let { mpsToKnots, metrToFeet, mpsToFpm } = require("%rGui/planeIlses/ilsConstants.nut")

let baseColor = Color(0, 255, 0, 255)
let baseFontSize = 20
let baseLineWidth = 1

let TrtModeForRpm = TrtMode[0]
let isHoverMode = Computed(@() TrtModeForRpm.get() == AirThrottleMode.CLIMB)

let arrow = {
  size = flex()
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = baseLineWidth
  color = baseColor
  commands = [
    [VECTOR_LINE, 0, 50, 100, 50],
    [VECTOR_LINE, 80, 0, 100, 50],
    [VECTOR_LINE, 80, 100, 100, 50]
  ]
}

let buttons = {
  size = flex()
  children = [
    {
      pos = [pw(14), ph(1)]
      size = [pw(8), ph(5)]
      flow = FLOW_VERTICAL
      children = [
        arrow
        {
            size = SIZE_TO_CONTENT
            pos = [pw(5), ph(1)]
            rendObj = ROBJ_TEXT
            color = baseColor
            font = Fonts.ah64
            fontSize = baseFontSize
            text = "ENG"
        }
      ]
    }
    {
      pos = [pw(40), ph(1)]
      size = [pw(8), ph(5)]
      flow = FLOW_VERTICAL
      children = [
        arrow
        {
          size = SIZE_TO_CONTENT
          pos = [pw(5), ph(1)]
          rendObj = ROBJ_TEXT
          color = baseColor
          font = Fonts.ah64
          fontSize = baseFontSize
          text = "FUEL"
        }
      ]
    }
    {
      pos = [pw(53), ph(1)]
      size = [pw(8), ph(5)]
      flow = FLOW_VERTICAL
      children = [
        arrow
        {
          size = SIZE_TO_CONTENT
          pos = [pw(5), ph(1)]
          rendObj = ROBJ_TEXT
          color = baseColor
          font = Fonts.ah64
          fontSize = baseFontSize
          text = "PERF"
        }
      ]
    }
    {
      pos = [pw(78), ph(1)]
      size = [pw(8), ph(5)]
      flow = FLOW_VERTICAL
      children = [
        arrow
        {
          size = SIZE_TO_CONTENT
          pos = [pw(5), ph(1)]
          rendObj = ROBJ_TEXT
          color = baseColor
          font = Fonts.ah64
          fontSize = baseFontSize
          text = "UTIL"
        }
      ]
    }
    {
      size = SIZE_TO_CONTENT
      pos = [pw(79), ph(95)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ah64
      fontSize = baseFontSize
      text = "SET"
    }
    {
      rendObj = ROBJ_FRAME
      pos = [pw(13), ph(94)]
      size = [pw(10), ph(5)]
      color = baseColor
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      children = {
        size = SIZE_TO_CONTENT
        rendObj = ROBJ_TEXT
        color = baseColor
        font = Fonts.ah64
        fontSize = baseFontSize
        text = "FLT"
      }
    }
    {
      size = SIZE_TO_CONTENT
      pos = [pw(1), ph(66)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ah64
      fontSize = baseFontSize
      text = "-W-"
    }
  ]
}

let CompassInt = Computed(@() ((360.0 + CompassValue.get()) % 360.0).tointeger())
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
        fontSize = baseFontSize
        font = Fonts.ah64
        text = text
        behavior = Behaviors.RtPropUpdate
        update = @() {
          opacity = abs(num - CompassInt.get()) < 20 ? 0.0 : 1.0
        }
      }
      {
        size = [baseLineWidth * 1.5, baseLineWidth * (num % 30 == 0 ? 10 : 4)]
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
  let getOffset = @() (360.0 + CompassValue.get()) * 0.005 * width
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
    size = [width * 0.5, height]
    pos = [width * 0.25, height * 0.12]
    clipChildren = true
    children = [
      compass(width * 0.5, generateFunc)
      {
        rendObj = ROBJ_SOLID
        color = baseColor
        size = [baseLineWidth * 3.0, ph(4)]
        pos = [width * 0.25 - baseLineWidth, baseFontSize + baseLineWidth * 10]
      }
    ]
  }
}

let compassVal = @(){
  size = [pw(8), ph(8)]
  pos = [pw(46), ph(9)]
  watch = CompassInt
  rendObj = ROBJ_TEXT
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  color = baseColor
  font = Fonts.ah64
  fontSize = baseFontSize * 1.4
  text = CompassInt.get().tostring()
}

let engineTorq = @(){
  watch = Rpm
  size = [pw(10), ph(6)]
  pos = [pw(5), ph(13)]
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  rendObj = ROBJ_TEXT
  color = baseColor
  font = Fonts.ah64
  fontSize = baseFontSize * 1.2
  text = string.format("%d%%", Rpm.get())
  children = Rpm.get() >= 98 ? {
    size = flex()
    rendObj = ROBJ_BOX
    fillColor = Color(0, 0, 0, 0)
    borderColor = baseColor
    borderWidth = baseLineWidth
    borderRadius = hdpx(5)
  } : null
}

function angleTxt(num, isLeft, x = 0, y = 0) {
  return {
    pos = [x, y]
    rendObj = ROBJ_TEXT
    vplace = num < 0 ? ALIGN_BOTTOM : ALIGN_TOP
    hplace = isLeft ? ALIGN_LEFT : ALIGN_RIGHT
    color = num > 0 ? Color(0, 128, 255) : Color(128, 64, 48)
    fontSize = baseFontSize
    font = Fonts.ah64
    text = abs(num).tostring()
  }
}

function generatePitchLine(num) {
  let sign = num > 0 ? 1 : -1
  let newNum = num >= 0 ? num : (num - 10)
  return {
    size = [pw(60), ph(18)]
    pos = [pw(20), 0]
    flow = FLOW_VERTICAL
    children = num == 0 ? [
      {
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth
        color = Color(128, 64, 48)
        padding = [0, 10]
        commands = [
          [VECTOR_LINE, -50, 0, 150, 0]
        ]
        children = [angleTxt(-10, true, pw(-32)), angleTxt(-10, false, pw(32))]
      }
    ] :
    [
      {
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * 2.0
        color = newNum > 0 ? Color(0, 128, 255) : Color(128, 64, 48)
        commands = [
          [VECTOR_LINE, 0, 10 * sign, 0, 0],
          [VECTOR_LINE, 0, 0, num > 0 ? 30 : 5, 0 ],
          (num < 0 ? [VECTOR_LINE, 10, 0, 17, 0] : []),
          (num < 0 ? [VECTOR_LINE, 23, 0, 30, 0] : []),
          [VECTOR_LINE, 100, 10 * sign, 100, 0],
          [VECTOR_LINE, 100, 0, num > 0 ? 70 : 95, 0],
          (num < 0 ? [VECTOR_LINE, 90, 0, 83, 0] : []),
          (num < 0 ? [VECTOR_LINE, 77, 0, 70, 0] : []),
          [VECTOR_LINE, 47, 50, 53, 50]
        ]
        children = newNum <= 90 ? [angleTxt(newNum, true, pw(-25)), angleTxt(newNum, false, pw(25))] : null
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
    pos = [0, height * 0.25]
    flow = FLOW_VERTICAL
    children = children
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, -height * (90.0 - Tangage.get()) * 0.009]
        rotate = -Roll.get()
        pivot = [0.5, (90.0 - Tangage.get()) * 0.018]
      }
    }
  }
}

let bankExtendSign= Computed(@() Roll.get() > 20.0 ? 1 : (Roll.get() < -20 ? -1 : 0))
let bankAngle = @(){
  watch = bankExtendSign
  size = flex()
  rendObj = ROBJ_VECTOR_CANVAS
  color = bankExtendSign.get() == 0 ? baseColor : Color(255, 255, 255)
  lineWidth = baseLineWidth * 3.0
  commands = [
    [VECTOR_LINE, 35, 24, 36, 25.75],
    [VECTOR_LINE, 65, 24, 64, 25.75],
    (bankExtendSign.get() == 1 ? [VECTOR_LINE, 20, 50, 22, 50] : []),
    (bankExtendSign.get() == 1 ? [VECTOR_LINE, 20.46, 44.8, 22.43, 45.14] : []),
    (bankExtendSign.get() == 1 ? [VECTOR_LINE, 21.8, 39.74, 23.7, 40.4] : []),
    (bankExtendSign.get() == 1 ? [VECTOR_LINE, 24, 35, 25.75, 36] : []),
    (bankExtendSign.get() == 1 ? [VECTOR_LINE, 27, 30.72, 28.55, 32] : []),
    (bankExtendSign.get() == 1 ? [VECTOR_LINE, 30.72, 27, 32, 28.55] : []),
    (bankExtendSign.get() == 1 ? [VECTOR_LINE, 18, 50, 22, 50] : []),
    (bankExtendSign.get() == -1 ? [VECTOR_LINE, 79.54, 44.8, 77.57, 45.14] : []),
    (bankExtendSign.get() == -1 ? [VECTOR_LINE, 78.2, 39.74, 76.3, 40.4] : []),
    (bankExtendSign.get() == -1 ? [VECTOR_LINE, 76, 35, 74.25, 36] : []),
    (bankExtendSign.get() == -1 ? [VECTOR_LINE, 73, 30.72, 71.45, 32] : []),
    (bankExtendSign.get() == -1 ? [VECTOR_LINE, 69.28, 27, 68, 28.55] : []),
    (bankExtendSign.get() == -1 ? [VECTOR_LINE, 82, 50, 78, 50] : []),
    [VECTOR_WIDTH, baseLineWidth * 2.0],
    [VECTOR_LINE, 39.7, 21.8, 40.4, 23.7],
    [VECTOR_LINE, 60.3, 21.8, 59.6, 23.7],
    [VECTOR_LINE, 44.8, 20.45, 45.14, 22.43],
    [VECTOR_LINE, 55.2, 20.45, 54.86, 22.43],
    [VECTOR_WIDTH, baseLineWidth],
    [VECTOR_LINE, 37.32, 22.8, 37.74, 23.72],
    [VECTOR_LINE, 62.68, 22.8, 62.26, 23.72],
    [VECTOR_LINE, 42.24, 21, 42.5, 22],
    [VECTOR_LINE, 57.76, 21, 57.5, 22],
    [VECTOR_LINE, 47.4, 20.1, 47.47, 21.1],
    [VECTOR_LINE, 52.6, 20.1, 52.53, 21.1],
  ]
  children = {
    size = flex()
    rendObj = ROBJ_VECTOR_CANVAS
    color = baseColor
    lineWidth = baseLineWidth
    fillColor = baseColor
    commands = [
      [VECTOR_POLY, 50, 21, 49, 23, 51, 23]
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        rotate = -Roll.get()
      }
    }
  }
}

let flyPath = {
  size = [pw(20), ph(3)]
  pos = [pw(40), ph(50)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = baseColor
  lineWidth = baseLineWidth * 2.0
  commands = [
    [VECTOR_LINE, 0, 0, 36, 0],
    [VECTOR_LINE, 64, 0, 100, 0],
    [VECTOR_LINE, 64, 0, 57, 100],
    [VECTOR_LINE, 50, 0, 57, 100],
    [VECTOR_LINE, 50, 0, 43, 100],
    [VECTOR_LINE, 36, 0, 43, 100]
  ]
}

let barAltValue = Computed(@() (BarAltitude.get() * metrToFeet).tointeger())
let barAltitude = @(){
  watch = barAltValue
  size = SIZE_TO_CONTENT
  pos = [pw(85), ph(14)]
  rendObj = ROBJ_TEXT
  color = baseColor
  font = Fonts.ah64
  fontSize = baseFontSize * 1.2
  text = barAltValue.get().tostring()
}

let showAltitudeBar = Computed(@() Altitude.get() <= 60.96)
let climbSpeedGrid = @(){
  watch = showAltitudeBar
  size = [pw(4), ph(40)]
  pos = [pw(93), ph(30)]
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
  children = showAltitudeBar.get() ? {
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

let radarAltVisible = Computed(@() Altitude.get() <= 435.2)
let altValue = Computed(@() (Altitude.get() * metrToFeet < 50.0 ? Altitude.get() * metrToFeet : Altitude.get() * metrToFeet * 0.1).tointeger())
let altitudeText = @() {
  watch = radarAltVisible
  size = flex()
  children = radarAltVisible.get() ? @(){
    watch = altValue
    size = [pw(8), ph(4)]
    pos = [pw(81), ph(48.5)]
    rendObj = ROBJ_TEXT
    color = baseColor
    halign = ALIGN_RIGHT
    valign = ALIGN_CENTER
    font = Fonts.ah64
    fontSize = baseFontSize
    text = (Altitude.get() * metrToFeet < 50.0 ? altValue.get() : altValue.get() * 10).tostring()
  } : null
}

function climbSpeedMark(width, height){
  return {
    size = [ph(2), ph(1)]
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
        translate = [width * 0.9, height * (0.5 + cvt(ClimbSpeed.get() * mpsToFpm, -1000.0, 1000.0, 0.15, -0.15))]
      }
    }
  }
}

let altitudeBarLen = Computed(@() clamp(Altitude.get() * metrToFeet * 0.5, 0.0, 100.0).tointeger())
let altitudeBar = @(){
  watch = showAltitudeBar
  size = [pw(2), ph(40)]
  pos = [pw(95), ph(30)]
  children = showAltitudeBar.get() ? @(){
    watch = altitudeBarLen
    size = [baseLineWidth * 3.0, ph(altitudeBarLen.get())]
    pos = [-baseLineWidth * 1.5, ph(100 - altitudeBarLen.get())]
    rendObj = ROBJ_SOLID
    color = Color(255, 0, 0)
  } : null
}

let lowAlt = @(){
  watch = showAltitudeBar
  size = flex()
  children = showAltitudeBar.get() ? {
    rendObj = ROBJ_TEXT
    size = SIZE_TO_CONTENT
    pos = [pw(83), ph(54)]
    color = Color(255, 0, 0)
    font = Fonts.ah64
    fontSize = baseFontSize * 1.2
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

let speedVal = Computed(@() (Tas.get() * mpsToKnots).tointeger())
let speed = @(){
  watch = [speedVal, isHoverMode]
  size = [pw(8), ph(4.5)]
  pos = [pw(8), ph(48)]
  rendObj = ROBJ_TEXT
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  color = baseColor
  font = Fonts.ah64
  fontSize = baseFontSize * 1.2
  text = speedVal.get().tointeger()
  children = speedVal.get() >= 210 || isHoverMode.get() ? {
    size = [pw(150), ph(150)]
    rendObj = ROBJ_BOX
    fillColor = Color(0, 0, 0, 0)
    borderColor = isHoverMode.get() ? baseColor : Color(255, 0, 0)
    borderWidth = baseLineWidth
    borderRadius = hdpx(5)
  } : null
}

let OverloadVisible = Computed(@() Overload.get() >= 2.0)
let OverloadVal = Computed(@() (Overload.get() * 10.0).tointeger())
let overload = @(){
  watch = OverloadVisible
  size = flex()
  children = OverloadVisible.get() ? @(){
    watch = OverloadVal
    size = SIZE_TO_CONTENT
    pos = [pw(8), ph(54.5)]
    rendObj = ROBJ_TEXT
    color = Color(255, 255, 255)
    font = Fonts.ah64
    fontSize = baseFontSize * 1.2
    text = string.format("%.1fG", OverloadVal.get() * 0.1)
  } : null
}

let tvvVisible = Computed(@() Tas.get() * mpsToKnots >= 5.0)
function tvvMark(width, height) {
  return @(){
    watch = tvvVisible
    size = flex()
    children = tvvVisible.get() ? {
      size = [ph(4), ph(4)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = baseColor
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * 2
      commands = [
        [VECTOR_ELLIPSE, 0, 0, 50, 50],
        [VECTOR_LINE, -100, 0, -50, 0],
        [VECTOR_LINE, 100, 0, 50, 0],
        [VECTOR_LINE, 0, -100, 0, -50]
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = [(-HorVelY.get() * cvt(Tas.get(), 0.0, 100.0, 0.0, 0.2) + 0.5) * width, (-HorVelX.get() * cvt(Tas.get(), 0.0, 100.0, 0.0, 0.2) + 0.5) * height]
        }
      }
    } : null
  }
}

let bank = Computed(@() cvt(HorAccelY.get() * fabs(Accel.get()), -1.5, 1.5, -50.0, 50.0).tointeger())
let skidBall = {
  size = [pw(30), ph(4)]
  pos = [pw(35), ph(93)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = baseColor
  lineWidth = baseLineWidth
  commands = [
    [VECTOR_LINE, 42, 0, 42, 100],
    [VECTOR_LINE, 58, 0, 58, 100],
    [VECTOR_LINE, 0, 100, 100, 100]
  ]
  children = @(){
    watch = bank
    rendObj = ROBJ_VECTOR_CANVAS
    size = [pw(15), pw(15)]
    pos = [pw(50 - bank.get()), ph(50)]
    lineWidth = baseLineWidth
    color = baseColor
    fillColor = baseColor
    commands = [
      [VECTOR_ELLIPSE, 0, 0, 30, 30]
    ]
  }
}

let turnRatePos = Computed(@() cvt(TurnRate.get(), 0.0698132, -0.0698132, 0, 90).tointeger())
let turnRate = {
  size = [pw(30), ph(5)]
  pos = [pw(35), ph(86)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = baseColor
  fillColor = baseColor
  lineWidth = baseLineWidth
  commands = [
    [VECTOR_LINE, 0, 40, 0, 100],
    [VECTOR_LINE, 14.28, 40, 14.28, 100],
    [VECTOR_LINE, 28.57, 40, 28.57, 100],
    [VECTOR_LINE, 42.86, 40, 42.86, 100],
    [VECTOR_LINE, 57.14, 40, 57.14, 100],
    [VECTOR_LINE, 71.43, 40, 71.43, 100],
    [VECTOR_LINE, 85.71, 40, 85.71, 100],
    [VECTOR_LINE, 100, 40, 100, 100],
    [VECTOR_POLY, 45, 40, 50, 0, 55, 40],
    [VECTOR_POLY, 16.2, 40, 21.5, 0, 26.5, 40],
    [VECTOR_POLY, 73.6, 40, 78.6, 0, 83.6, 40]
  ]
  children = @(){
    watch = turnRatePos
    rendObj = ROBJ_SOLID
    size = [pw(10), ph(50)]
    pos = [pw(turnRatePos.get()), ph(45)]
    color = baseColor
  }
}

let engineTemperature0 = EngineTemperature[0]
let engineTemperature1 = EngineTemperature[1]
let engineTempVisible = Computed(@() engineTemperature0.get() > 807 || engineTemperature1.get() > 807)
let engineTempVal = Computed(@() max(engineTemperature0.get(), engineTemperature1.get()).tointeger())
let engineTemp = @(){
  watch = engineTempVisible
  size = flex()
  children = engineTempVisible.get() ? @(){
    watch = engineTempVal
    size = SIZE_TO_CONTENT
    pos = [pw(6), ph(20)]
    rendObj = ROBJ_TEXT
    color = Color(255, 200, 0)
    font = Fonts.ah64
    fontSize = baseFontSize * 1.2
    text = string.format("%dC", engineTempVal.get())
  } : null
}

function fltPage(pos, size) {
  return {
    size
    pos
    children = [
      buttons
      compassWrap(size[0], size[1], generateCompassMark)
      compassVal
      engineTorq
      {
        size = [pw(40), ph(50)]
        pos = [pw(30), ph(25)]
        clipChildren = true
        children = pitch(size[0], size[1], generatePitchLine)
      }
      flyPath
      bankAngle
      barAltitude
      climbSpeed(size[0], size[1])
      speed
      overload
      tvvMark(size[0], size[1])
      skidBall
      turnRate
      engineTemp
    ]
  }
}

return fltPage