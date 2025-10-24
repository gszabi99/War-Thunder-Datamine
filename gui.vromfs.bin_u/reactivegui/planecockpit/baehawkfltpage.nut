from "%rGui/globals/ui_library.nut" import *

let { Tas, CompassValue, Altitude, Tangage, Roll, BarAltitude, ClimbSpeed,
 Overload } = require("%rGui/planeState/planeFlyState.nut")
let { abs } = require("%sqstd/math.nut")
let string = require("string")
let { cvt } = require("dagor.math")
let { mpsToKnots, metrToFeet, mpsToFpm } = require("%rGui/planeIlses/ilsConstants.nut")

let baseColor = Color(0, 255, 0, 255)
let baseFontSize = 20
let baseLineWidth = 1

let line = {
  size = flex()
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = baseLineWidth
  color = baseColor
    commands = [
    [VECTOR_LINE, 5, 25, 10, 25],
    [VECTOR_LINE, 5, 44, 10, 44],
    [VECTOR_LINE, 5, 58, 10, 58],
    [VECTOR_LINE, 5, 73, 10, 73],
    [VECTOR_LINE, 5, 87, 10, 87],
    [VECTOR_LINE, 20, 92, 20, 97],
    [VECTOR_LINE, 33, 92, 33, 97],
    [VECTOR_LINE, 72, 92, 72, 97],
  ]
}

let ellipse = {
  size = ph(100)
  pos = [pw(50), ph(50)]
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = baseLineWidth
  color = baseColor
  fillColor = Color(0, 0, 0, 0)
    commands = [
    [VECTOR_ELLIPSE, 0, 0, 30, 30],
    [VECTOR_LINE, 0, 30, 0, 35],
    [VECTOR_LINE, 0, -30, 0, -32.5],
    [VECTOR_LINE, 30, 0, 35, 0],
    [VECTOR_LINE, -35, 0, -30, 0],
    [VECTOR_LINE, 5, 30, 5.5, 32.5],
    [VECTOR_LINE, -5, 30, -5.5, 32.5],
    [VECTOR_LINE, 10, 28.5, 10.5, 31],
    [VECTOR_LINE, -10, 28.5, -10.5, 31],
    [VECTOR_LINE, 15, 26.5, 15.5, 29],
    [VECTOR_LINE, -15, 26.5, -15.5, 29]
  ]
}

let buttons = {
  size = flex()
  children = [
    {
      pos = [pw(19), ph(3)]
      size = const [pw(8), ph(5)]
      flow = FLOW_VERTICAL
      children = [
        {
            size = SIZE_TO_CONTENT
            pos = [pw(5), ph(1)]
            rendObj = ROBJ_TEXT
            color = baseColor
            font = Fonts.ah64
            fontSize = baseFontSize
            text = "GS"
        }
      ]
    }
    {
      pos = [pw(5), ph(30)]
      size = const [pw(8), ph(5)]
      flow = FLOW_VERTICAL
      children = [
        {
          size = SIZE_TO_CONTENT
          pos = [pw(5), ph(1)]
          rendObj = ROBJ_TEXT
          color = baseColor
          font = Fonts.ah64
          fontSize = baseFontSize
          text = "GO"
        }
      ]
    }
    {
      pos = [pw(5), ph(34)]
      size = const [pw(8), ph(5)]
      flow = FLOW_VERTICAL
      children = [
        {
          size = SIZE_TO_CONTENT
          pos = [pw(5), ph(1)]
          rendObj = ROBJ_TEXT
          color = baseColor
          font = Fonts.ah64
          fontSize = baseFontSize
          text = "TO"
        }
      ]
    }
    {
      pos = [pw(5), ph(47)]
      size = const [pw(8), ph(5)]
      flow = FLOW_VERTICAL
      children = [
        {
          size = SIZE_TO_CONTENT
          pos = [pw(5), ph(1)]
          rendObj = ROBJ_TEXT
          color = baseColor
          font = Fonts.ah64
          fontSize = baseFontSize
          text = "\nIN"
        }
      ]
    }
    {
      pos = [pw(5), ph(51)]
      size = const [pw(8), ph(5)]
      flow = FLOW_VERTICAL
      children = [
        {
          size = SIZE_TO_CONTENT
          pos = [pw(5), ph(1)]
          rendObj = ROBJ_TEXT
          color = baseColor
          font = Fonts.ah64
          fontSize = baseFontSize
          text = "NAV"
        }
      ]
    }
    {
      pos = [pw(5), ph(62)]
      size = const [pw(8), ph(5)]
      flow = FLOW_VERTICAL
      children = [
        {
          size = SIZE_TO_CONTENT
          pos = [pw(5), ph(1)]
          rendObj = ROBJ_TEXT
          color = baseColor
          font = Fonts.ah64
          fontSize = baseFontSize
          text = "RAD"
        }
      ]
    }
    {
      pos = [pw(5), ph(66)]
      size = const [pw(8), ph(5)]
      flow = FLOW_VERTICAL
      children = [
        {
          size = SIZE_TO_CONTENT
          pos = [pw(5), ph(1)]
          rendObj = ROBJ_TEXT
          color = baseColor
          font = Fonts.ah64
          fontSize = baseFontSize
          text = "NAV"
        }
      ]
    }
    {
      size = SIZE_TO_CONTENT
      pos = [pw(5), ph(92)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ah64
      fontSize = baseFontSize
      text = "HSI"
    }
    {
      rendObj = ROBJ_FRAME
      pos = [pw(21.5), ph(92)]
      size = const [pw(10), ph(5)]
      color = baseColor
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      children = {
        size = SIZE_TO_CONTENT
        rendObj = ROBJ_TEXT
        color = baseColor
        font = Fonts.ah64
        fontSize = baseFontSize
        text = "DEV"
      }
    }
    {
      size = SIZE_TO_CONTENT
      pos = [pw(35), ph(92)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ah64
      fontSize = baseFontSize
      text = "DIR"
    }
    {
      size = SIZE_TO_CONTENT
      pos = [pw(75), ph(92)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ah64
      fontSize = baseFontSize
      text = "MENU"
    }
  ]
}

let CompassInt = Computed(@() ((360.0 + CompassValue.get()) % 360.0).tointeger())

let compassVal = @(){
  size = const [pw(8), ph(8)]
  pos = [pw(46), ph(3)]
  watch = CompassInt
  rendObj = ROBJ_TEXT
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  color = baseColor
  font = Fonts.ah64
  fontSize = baseFontSize * 1.1
  text = CompassInt.get().tostring()
}

function angleTxt(num, isLeft, x = 0, y = 0) {
  return {
    pos = [x, y + hdpx(baseFontSize * (num > 0 ? -0.5 : 0.5))]
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
  let newNum = num >= 0 ? num : (num - 10)
  return {
    size = const [pw(40), ph(18)]
    pos = [pw(30), 0]
    flow = FLOW_VERTICAL
    children = num == 0 ? [
      {
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * (num == 0 ? 1.0 : 0.5)
        color = Color(128, 64, 48)
        padding = const [0, 10]
        commands = [
          [VECTOR_LINE, -25, 0, 125, 0]
        ]
        children = [angleTxt(-10, true, pw(-32)), angleTxt(-10, false, pw(32))]
      }
    ] :
    [
      {
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * 2.0 * (num == 0 ? 1.0 : 0.5)
        color = newNum > 0 ? Color(0, 128, 255) : Color(128, 64, 48)
        commands = [
          [VECTOR_LINE, 10, 18, 90, 18],
          [VECTOR_LINE, 42, 70, 58, 70]
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
  size = const [pw(130), ph(130)]
  pos = [pw(-15), ph(-15)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = bankExtendSign.get() == 0 ? baseColor : Color(255, 255, 255)
  lineWidth = baseLineWidth * 3.0
  commands = [
    [VECTOR_LINE, 35, 24, 36, 25.75],
    [VECTOR_LINE, 65, 24, 64, 25.75],
    [VECTOR_LINE, 27, 30.72, 28.55, 32],
    [VECTOR_LINE, 30.72, 27, 32, 28.55],
    [VECTOR_LINE, 73, 30.72, 71.45, 32],
    [VECTOR_LINE, 69.28, 27, 68, 28.55],
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
  size = flex()
  rendObj = ROBJ_VECTOR_CANVAS
  color = baseColor
  commands = [
    [VECTOR_LINE, 29, 49.2, 38, 49.2],
    [VECTOR_LINE, 29, 50.7, 36.5, 50.7],
    [VECTOR_LINE, 38, 49.2, 38, 51.7],
    [VECTOR_LINE, 36.5, 51.7, 38, 51.7],
    [VECTOR_LINE, 36.5, 50.7, 36.5, 51.7],
    [VECTOR_LINE, 29, 49.2, 29, 50.7],
    [VECTOR_LINE, 49, 49.2, 51, 49.2],
    [VECTOR_LINE, 49, 50.7, 51, 50.7],
    [VECTOR_LINE, 49, 49.2, 49, 50.7],
    [VECTOR_LINE, 51, 49.2, 51, 50.7],
    [VECTOR_LINE, 71, 49.2, 62, 49.2],
    [VECTOR_LINE, 71, 50.7, 63.5, 50.7],
    [VECTOR_LINE, 62, 49.2, 62, 51.7],
    [VECTOR_LINE, 63.5, 51.7, 62, 51.7],
    [VECTOR_LINE, 63.5, 50.7, 63.5, 51.7],
    [VECTOR_LINE, 71, 49.2, 71, 50.7],
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
  size = const [pw(4), ph(40)]
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
    size = const [pw(8), ph(4)]
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
    size = const [ph(2), ph(1)]
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
  size = const [pw(2), ph(40)]
  pos = [pw(95), ph(30)]
  children = showAltitudeBar.get() ? @(){
    watch = altitudeBarLen
    size = [baseLineWidth * 3.0, ph(altitudeBarLen.get())]
    pos = [-baseLineWidth * 1.5, ph(100 - altitudeBarLen.get())]
    rendObj = ROBJ_SOLID
    color = Color(255, 0, 0)
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
    ]
  }
}

let speedVal = Computed(@() (Tas.get() * mpsToKnots).tointeger())
let speed = @(){
  watch = speedVal
  size = const [pw(8), ph(4.5)]
  pos = [pw(28), ph(3)]
  rendObj = ROBJ_TEXT
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  color = baseColor
  font = Fonts.ah64
  fontSize = baseFontSize * 1.2
  text = speedVal.get().tointeger()
  children = speedVal.get() >= 210 ? {
    size = const [pw(150), ph(150)]
    rendObj = ROBJ_BOX
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
    pos = [pw(85), ph(21)]
    rendObj = ROBJ_TEXT
    color = Color(255, 255, 255)
    font = Fonts.ah64
    fontSize = baseFontSize * 1.2
    text = string.format("%.1fG", OverloadVal.get() * 0.1)
  } : null
}

function BaeHawkFlt(pos, size) {
  return {
    size
    pos
    children = [
      buttons
      compassVal
      {
        size = const [pw(40), ph(50)]
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
      line
      ellipse
    ]
  }
}

return BaeHawkFlt