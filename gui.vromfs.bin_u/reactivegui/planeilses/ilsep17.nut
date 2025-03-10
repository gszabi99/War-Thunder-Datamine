from "%rGui/globals/ui_library.nut" import *
let { IlsColor, IlsLineScale, BombCCIPMode, RocketMode, CannonMode, BombingMode,
 TargetPosValid, TargetPos, TvvMark, RadarTargetDist, DistToTarget, IlsPosSize,
 RadarTargetPos, AimLockPos, AimLockValid, TimeBeforeBombRelease } = require("%rGui/planeState/planeToolsState.nut")
let { baseLineWidth, mpsToKnots, metrToFeet, metrToNavMile, mpsToKmh } = require("ilsConstants.nut")
let { Speed, Mach, BarAltitude, Altitude, Overload, Aoa, Tangage, Roll } = require("%rGui/planeState/planeFlyState.nut")
let string = require("string")
let { GuidanceLockState, IlsTrackerX, IlsTrackerY } = require("%rGui/rocketAamAimState.nut")
let { GuidanceLockResult } = require("guidanceConstants")
let { cvt } = require("dagor.math")
let { AamLaunchZoneDistMaxVal, AamLaunchZoneDistMinVal, RadarModeNameId, modeNames } = require("%rGui/radarState.nut")
let { compassWrap, generateCompassMarkSU145 } = require("ilsCompasses.nut")
let { setInterval, clearTimer } = require("dagor.workcycle")

let isAAMMode = Computed(@() GuidanceLockState.value > GuidanceLockResult.RESULT_STANDBY)
let isCCIPMode = Computed(@() RocketMode.value || BombCCIPMode.value || CannonMode.value)
let speedMpsValue = Computed(@() (Speed.value * mpsToKnots).tointeger())
let speedKmhValue = Computed(@() (Speed.value * mpsToKmh).tointeger())
function speed(width, height, is_metric) {
  return {
    size = [width * 0.1 + baseLineWidth * IlsLineScale.value, height * 0.3 + baseLineWidth * IlsLineScale.value]
    pos = [pw(10), height * 0.35 - baseLineWidth * IlsLineScale.value * 0.5]
    clipChildren  = true
    children = [
      {
        size = [width * 0.1, height * 0.3]
        pos = [0, baseLineWidth * IlsLineScale.value * 0.5]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value * 0.7
        commands = [
          [VECTOR_LINE, 100, -10, 100, 110],
          [VECTOR_LINE, 85, 0, 100, 0],
          [VECTOR_LINE, 85, 16.6, 100, 16.6],
          [VECTOR_LINE, 85, 33.3, 100, 33.3],
          [VECTOR_LINE, 85, 50, 100, 50],
          [VECTOR_LINE, 85, 66.6, 100, 66.6],
          [VECTOR_LINE, 85, 66.6, 100, 66.6],
          [VECTOR_LINE, 85, 83.3, 100, 83.3],
          [VECTOR_LINE, 85, 100, 100, 100]
        ]
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            translate = [0, ((Speed.value * (is_metric ? mpsToKmh : mpsToKnots)) % 50.0) * height * 0.001]
          }
        }
      }
      {
        size = [pw(20), ph(8)]
        pos = [pw(70), ph(48)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value * 0.7
        commands = [
          [VECTOR_LINE, 0, 0, 100, 50],
          [VECTOR_LINE, 0, 100, 100, 50]
        ]
      }
      @(){
        watch = is_metric ? speedKmhValue : speedMpsValue
        size = [pw(70), SIZE_TO_CONTENT]
        pos = [0, ph(46)]
        rendObj = ROBJ_TEXT
        padding = [0, 5]
        halign= ALIGN_RIGHT
        color = IlsColor.value
        font = Fonts.mirage_ils
        fontSize = (is_metric ? speedKmhValue : speedMpsValue).get() > 1000 ? 30 : 40
        text = (is_metric ? speedKmhValue : speedMpsValue).get().tostring()
      }
    ]
  }
}

let machWatched = Computed(@() (Mach.value * 100.0).tointeger())
let mach = @() {
  watch = [machWatched, IlsColor]
  rendObj = ROBJ_TEXT
  pos = [pw(10), ph(70)]
  color = IlsColor.value
  fontSize = 40
  font = Fonts.mirage_ils
  text = Mach.value >= 1. ? string.format("M%.2f", Mach.value) : string.format("M .%02d", machWatched.value)
}

let generateAltMark = function(num) {
  return {
    size = [pw(100), ph(20)]
    pos = [pw(15), 0]
    flow = FLOW_HORIZONTAL
    children = [
      (num == 0 ?
      {
        size = [baseLineWidth * IlsLineScale.value * 0.7, ph(30)]
        pos = [0, ph(35)]
        rendObj = ROBJ_SOLID
        color = IlsColor.value
      } : null),
      @() {
        watch = IlsColor
        size = [baseLineWidth * (num % 500 > 0 && num > 500 ? 2 : 4), baseLineWidth * IlsLineScale.value * 0.7]
        rendObj = ROBJ_SOLID
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
        vplace = ALIGN_CENTER
      },
      (num % 500 > 0 && num > 500 ? null :
        @() {
          watch = IlsColor
          size = [SIZE_TO_CONTENT, flex()]
          rendObj = ROBJ_TEXT
          color = IlsColor.value
          valign = ALIGN_CENTER
          padding = [0, 0, 0, 10]
          fontSize = 40
          font = Fonts.mirage_ils
          text = string.format("%d", num > 500 ? num / 1000 : num)
        }
      ),
      (num % 500 > 0 || num <= 500 ? null :
        @() {
          watch = IlsColor
          size = [SIZE_TO_CONTENT, flex()]
          pos = [0, 5]
          rendObj = ROBJ_TEXT
          color = IlsColor.value
          valign = ALIGN_CENTER
          fontSize = 30
          font = Fonts.hud
          text = string.format("%03d", num % 1000)
        }
      )
    ]
  }
}

function altitude(height, generateFunc, is_metric) {
  let children = []
  for (local i = 65000; i >= 0;) {
    children.append(generateFunc(i))
    i -= i > 500 ? 250 : 100
  }

  let mul = is_metric ? 1.0 : metrToFeet
  let getOffset = @() ((65000 - max(BarAltitude.value * mul, 500)) * 0.0008 + (BarAltitude.value * mul >= 500 ? 0.0 : ((500 - BarAltitude.value * mul) * 0.002)) - 0.37) * height
  return {
    size = [pw(100), ph(100)]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, -getOffset()]
      }
    }
    flow = FLOW_VERTICAL
    children = children
  }
}

let altValueThousandF = Computed(@() (Altitude.value * metrToFeet / 1000.0).tointeger())
let altValueModF = Computed(@() (Altitude.value * metrToFeet % 1000.0).tointeger())
let altValueThousandM = Computed(@() (Altitude.value / 1000.0).tointeger())
let altValueModM = Computed(@() (Altitude.value % 1000.0).tointeger())

function altCompressed(is_metric) {
  return {
    size = flex()
    children = [
      {
        pos = [0, ph(45)]
        size = flex()
        flow = FLOW_HORIZONTAL
        children = [
          @(){
            watch = is_metric ? altValueThousandM : altValueThousandF
            size = SIZE_TO_CONTENT
            rendObj = ROBJ_TEXT
            color = IlsColor.value
            padding = [0, 5]
            font = Fonts.mirage_ils
            fontSize = 45
            text = (is_metric ? altValueThousandM : altValueThousandF).get().tostring()
          }
          @(){
            watch = is_metric ? altValueModM : altValueModF
            pos = [0, 10]
            rendObj = ROBJ_TEXT
            valign = ALIGN_BOTTOM
            color = IlsColor.value
            font = Fonts.mirage_ils
            fontSize = 30
            text = string.format("%03d", (is_metric ? altValueModM : altValueModF).get())
          }
        ]
      }
      @(){
        watch = IlsColor
        rendObj = ROBJ_TEXT
        pos = [pw(20), ph(35)]
        size = SIZE_TO_CONTENT
        color = IlsColor.value
        font = Fonts.mirage_ils
        fontSize = 45
        text = "A"
      }
    ]
  }
}

function altWrap(width, height, generateFunc, is_metric) {
  let altElem = altitude(height * 0.4, generateFunc, is_metric)
  return @(){
    watch = isAAMMode
    size = [width * 0.17, height * 0.4]
    pos = [width * 0.75, height * 0.3]
    clipChildren = true
    children = !isAAMMode.value ? [
      altElem
      {
        rendObj = ROBJ_VECTOR_CANVAS
        size = [width * 0.02, height * 0.024]
        pos = [0, ph(50)]
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value * 0.7
        commands = [
          [VECTOR_LINE, 0, 0, 100, 50],
          [VECTOR_LINE, 0, 100, 100, 50]
        ]
      }
    ] : altCompressed(is_metric)
  }
}

let pitchWrap = @(){
  size = [pw(800), ph(800)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.value
  fillColor = Color(0, 0, 0, 0)
  lineWidth = baseLineWidth * IlsLineScale.value * 0.7
  commands = [
    [VECTOR_LINE, -2, 0, 2, 0],
    [VECTOR_LINE, 0, -2, 0, 2],
    [VECTOR_LINE, 0.1, 1.8, 0, 2],
    [VECTOR_LINE, -0.1, 1.8, 0, 2],
    [VECTOR_LINE, 0.1, -1.8, 0, -2],
    [VECTOR_LINE, -0.1, -1.8, 0, -2],
    [VECTOR_LINE, 1.8, 0.1, 2, 0],
    [VECTOR_LINE, 1.8, -0.1, 2, 0],
    [VECTOR_LINE, -1.8, 0.1, -2, 0],
    [VECTOR_LINE, -1.8, -0.1, -2, 0],
    [VECTOR_ELLIPSE, 0, 0, 5.55, 5.55],
    [VECTOR_ELLIPSE, 0, 0, 11.11, 11.11],
    [VECTOR_ELLIPSE, 0, 0, 16.67, 16.67],
    [VECTOR_ELLIPSE, 0, 0, 22.22, 22.22],
    [VECTOR_ELLIPSE, 0, 0, 27.78, 27.78],
    [VECTOR_ELLIPSE, 0, 0, 33.33, 33.33],
    [VECTOR_ELLIPSE, 0, -38.89, 77.78, 77.78],
    [VECTOR_LINE, -100, 44.44, 100, 44.44],
    [VECTOR_LINE, -100, 50, -3, 50],
    [VECTOR_LINE, 3, 50, 100, 50],
    [VECTOR_LINE, -2.5, 50, -2.5, 50],
    [VECTOR_LINE, -2, 50, -2, 50],
    [VECTOR_LINE, -1.5, 50, -1.5, 50],
    [VECTOR_LINE, -1, 50, -1, 50],
    [VECTOR_LINE, -0.5, 50, -0.5, 50],
    [VECTOR_LINE, 0.5, 50, 0.5, 50],
    [VECTOR_LINE, 1, 50, 1, 50],
    [VECTOR_LINE, 1.5, 50, 1.5, 50],
    [VECTOR_LINE, 2, 50, 2, 50],
    [VECTOR_LINE, 2.5, 50, 2.5, 50],
    [VECTOR_LINE, -30, 55.56, -5.4, 55.56],
    [VECTOR_LINE, -5, 55.56, -5.2, 54.91],
    [VECTOR_LINE, -5.4, 55.56, -5.2, 54.91],
    [VECTOR_LINE, -5, 55.56, 2.3, 55.56],
    [VECTOR_LINE, 2.3, 55.56, 2.525, 54.91],
    [VECTOR_LINE, 2.75, 55.56, 2.525, 54.91],
    [VECTOR_LINE, 2.75, 55.56, 30, 55.56],
    [VECTOR_SECTOR, 0, 138.89, 77.78, 77.78, 210, 266],
    [VECTOR_SECTOR, 0, 138.89, 77.78, 77.78, 266.3, 271.7],
    [VECTOR_SECTOR, 0, 138.89, 77.78, 77.78, -88, -40],
    [VECTOR_LINE, 2.3, 61.11, 2.525, 60.5],
    [VECTOR_LINE, 2.75, 61.15, 2.525, 60.5],
    [VECTOR_LINE, -5, 61.25, -5.22, 60.65],
    [VECTOR_LINE, -5.4, 61.3, -5.22, 60.65],
    [VECTOR_SECTOR, 0, 100, 33.33, 33.33, 261, 277],
    [VECTOR_SECTOR, 0, 100, 33.33, 33.33, -82.2, -20],
    [VECTOR_SECTOR, 0, 100, 33.33, 33.33, 210, 260.2],
    [VECTOR_LINE, 4.05, 66.9, 4.35, 66.35],
    [VECTOR_LINE, 4.55, 67, 4.35, 66.35],
    [VECTOR_LINE, -5.25, 67.1, -5.6, 66.45],
    [VECTOR_LINE, -5.70, 67.15, -5.6, 66.45],
    [VECTOR_SECTOR, 0, 100, 27.78, 27.78, 259, 279],
    [VECTOR_SECTOR, 0, 100, 27.78, 27.78, -80, -20],
    [VECTOR_SECTOR, 0, 100, 27.78, 27.78, 210, 258.2],
    [VECTOR_LINE, 4.35, 72.55, 4.7, 71.95],
    [VECTOR_LINE, 4.85, 72.6, 4.7, 71.95],
    [VECTOR_LINE, -5.3, 72.7, -5.6, 72.15],
    [VECTOR_LINE, -5.7, 72.8, -5.6, 72.15],
    [VECTOR_SECTOR, 0, 100, 22.22, 22.22, 256, 281],
    [VECTOR_SECTOR, 0, 100, 22.22, 22.22, -77.8, -20],
    [VECTOR_SECTOR, 0, 100, 22.22, 22.22, 200, 255],
    [VECTOR_LINE, 4.25, 78.2, 4.6, 77.65],
    [VECTOR_LINE, 4.7, 78.27, 4.6, 77.65],
    [VECTOR_LINE, -5.35, 78.45, -5.7, 77.9],
    [VECTOR_LINE, -5.75, 78.52, -5.7, 77.9],
    [VECTOR_SECTOR, 0, 100, 16.67, 16.67, 254, 286],
    [VECTOR_SECTOR, 0, 100, 16.67, 16.67, -72.5, -20],
    [VECTOR_SECTOR, 0, 100, 16.67, 16.67, 200, 252.5],
    [VECTOR_LINE, 4.6, 84, 4.95, 83.45],
    [VECTOR_LINE, 5.0, 84.1, 4.95, 83.45],
    [VECTOR_LINE, -4.6, 83.95, -5.0, 83.45],
    [VECTOR_LINE, -5.0, 84.1, -5.0, 83.45],
    [VECTOR_SECTOR, 0, 100, 11.11, 11.11, 254, 286],
    [VECTOR_SECTOR, 0, 100, 11.11, 11.11, -71.5, 0],
    [VECTOR_SECTOR, 0, 100, 11.11, 11.11, 180, 251.5],
    [VECTOR_LINE, 3.05, 89.3, 3.45, 88.7],
    [VECTOR_LINE, 3.55, 89.45, 3.45, 88.7],
    [VECTOR_LINE, -3.05, 89.3, -3.5, 88.7],
    [VECTOR_LINE, -3.55, 89.45, -3.5, 88.7],
    [VECTOR_SECTOR, 0, 100, 5.55, 5.55, -88, -62],
    [VECTOR_SECTOR, 0, 100, 5.55, 5.55, -58, -32],
    [VECTOR_SECTOR, 0, 100, 5.55, 5.55, -28, -2],
    [VECTOR_SECTOR, 0, 100, 5.55, 5.55, 2, 28],
    [VECTOR_SECTOR, 0, 100, 5.55, 5.55, 32, 58],
    [VECTOR_SECTOR, 0, 100, 5.55, 5.55, 62, 88],
    [VECTOR_SECTOR, 0, 100, 5.55, 5.55, 92, 118],
    [VECTOR_SECTOR, 0, 100, 5.55, 5.55, 122, 148],
    [VECTOR_SECTOR, 0, 100, 5.55, 5.55, 152, 178],
    [VECTOR_SECTOR, 0, 100, 5.55, 5.55, 242, 268],
    [VECTOR_SECTOR, 0, 100, 5.55, 5.55, 212, 238],
    [VECTOR_SECTOR, 0, 100, 5.55, 5.55, 182, 208],
    [VECTOR_LINE, -0.2, 94.45, 0, 93.8],
    [VECTOR_LINE, 0.2, 94.45, 0, 93.8],
    [VECTOR_LINE, 2.941, 95.29, 3.1, 94.63],
    [VECTOR_LINE, 2.61, 95.1, 3.1, 94.63],
    [VECTOR_LINE, 4.707, 97.06, 5.37, 96.9],
    [VECTOR_LINE, 4.9, 97.4, 5.37, 96.9],
    [VECTOR_LINE, 5.55, 99.8, 6.2, 100],
    [VECTOR_LINE, 5.55, 100.2, 6.2, 100],
    [VECTOR_LINE, 4.707, 102.94, 5.37, 103.1],
    [VECTOR_LINE, 4.9, 102.6, 5.37, 103.1],
    [VECTOR_LINE, 2.941, 104.71, 3.1, 105.37],
    [VECTOR_LINE, 2.61, 104.9, 3.1, 105.37],
    [VECTOR_LINE, -2.941, 104.71, -3.1, 105.37],
    [VECTOR_LINE, -2.61, 104.9, -3.1, 105.37],
    [VECTOR_LINE, -5.55, 99.8, -6.2, 100],
    [VECTOR_LINE, -5.55, 100.2, -6.2, 100],
    [VECTOR_LINE, -4.707, 102.94, -5.37, 103.1],
    [VECTOR_LINE, -4.9, 102.6, -5.37, 103.1],
    [VECTOR_LINE, -4.707, 97.06, -5.37, 96.9],
    [VECTOR_LINE, -4.9, 97.4, -5.37, 96.9],
    [VECTOR_LINE, -2.941, 95.29, -3.1, 94.63],
    [VECTOR_LINE, -2.61, 95.1, -3.1, 94.63],
    [VECTOR_LINE, -0.2, 105.55, 0, 106.2],
    [VECTOR_LINE, 0.2, 105.55, 0, 106.2],
    [VECTOR_SECTOR, 0, 100, 2, 2, -85, -5],
    [VECTOR_SECTOR, 0, 100, 2, 2, 5, 85],
    [VECTOR_SECTOR, 0, 100, 2, 2, 95, 175],
    [VECTOR_SECTOR, 0, 100, 2, 2, 185, 265],
    [VECTOR_LINE, -0.2, 98, 0, 97.35],
    [VECTOR_LINE, 0.2, 98, 0, 97.35],
    [VECTOR_LINE, 2, 99.8, 2.65, 100],
    [VECTOR_LINE, 2, 100.2, 2.65, 100],
    [VECTOR_LINE, -0.2, 102, 0, 102.65],
    [VECTOR_LINE, 0.2, 102, 0, 102.65],
    [VECTOR_LINE, -2, 99.8, -2.65, 100],
    [VECTOR_LINE, -2, 100.2, -2.65, 100],
    [VECTOR_LINE, -0.2, 100, 0.2, 100],
    [VECTOR_LINE, 0, 100.2, 0, 99.8],
  ]
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      translate = [0, -(90.0 - Tangage.value) * 0.044445 * IlsPosSize[3]]
      rotate = -Roll.value
      pivot = [0, (90.0 - Tangage.value) * 0.044445 / 8]
    }
  }
  children = [
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(5), ph(44)]
      color = IlsColor.value
      font = Fonts.mirage_ils
      fontSize = 35
      text = "10"
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(5), ph(38.2)]
      color = IlsColor.value
      font = Fonts.mirage_ils
      fontSize = 35
      text = "20"
      transform = {
        rotate = -5
      }
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(5), ph(32.4)]
      color = IlsColor.value
      font = Fonts.mirage_ils
      fontSize = 35
      text = "30"
      transform = {
        rotate = -10
      }
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(5), ph(26.8)]
      color = IlsColor.value
      font = Fonts.mirage_ils
      fontSize = 35
      text = "40"
      transform = {
        rotate = -15
      }
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(5), ph(21.1)]
      color = IlsColor.value
      font = Fonts.mirage_ils
      fontSize = 35
      text = "50"
      transform = {
        rotate = -15
      }
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(5), ph(15.3)]
      color = IlsColor.value
      font = Fonts.mirage_ils
      fontSize = 35
      text = "60"
      transform = {
        rotate = -20
      }
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(3.5), ph(10)]
      color = IlsColor.value
      font = Fonts.mirage_ils
      fontSize = 35
      text = "70"
      transform = {
        rotate = -25
      }
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(1), ph(5)]
      color = IlsColor.value
      font = Fonts.mirage_ils
      fontSize = 35
      text = "80"
      transform = {
        rotate = -15
      }
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(5), ph(-1)]
      color = IlsColor.value
      font = Fonts.mirage_ils
      fontSize = 35
      text = "80"
      transform = {
        rotate = -105
      }
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(-5.45), ph(1)]
      color = IlsColor.value
      font = Fonts.mirage_ils
      fontSize = 35
      text = "80"
      transform = {
        rotate = 75
      }
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(-1), ph(-5.5)]
      color = IlsColor.value
      font = Fonts.mirage_ils
      fontSize = 35
      text = "80"
      transform = {
        rotate = 170
      }
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(5), ph(55)]
      color = IlsColor.value
      font = Fonts.mirage_ils
      fontSize = 35
      text = "-10"
      transform = {
        rotate = 0
      }
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(5), ph(60.9)]
      color = IlsColor.value
      font = Fonts.mirage_ils
      fontSize = 35
      text = "-20"
      transform = {
        rotate = 5
      }
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(5), ph(66.7)]
      color = IlsColor.value
      font = Fonts.mirage_ils
      fontSize = 35
      text = "-30"
      transform = {
        rotate = 7
      }
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(5.3), ph(72.4)]
      color = IlsColor.value
      font = Fonts.mirage_ils
      fontSize = 35
      text = "-40"
      transform = {
        rotate = 10
      }
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(5.3), ph(78.1)]
      color = IlsColor.value
      font = Fonts.mirage_ils
      fontSize = 35
      text = "-50"
      transform = {
        rotate = 10
      }
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(5.3), ph(83.9)]
      color = IlsColor.value
      font = Fonts.mirage_ils
      fontSize = 35
      text = "-60"
      transform = {
        rotate = 17
      }
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(5.3), ph(90)]
      color = IlsColor.value
      font = Fonts.mirage_ils
      fontSize = 35
      text = "-70"
      transform = {
        rotate = 30
      }
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(3.7), ph(95.7)]
      color = IlsColor.value
      font = Fonts.mirage_ils
      fontSize = 35
      text = "-80"
      transform = {
        rotate = 45
      }
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(-4.5), ph(95.7)]
      color = IlsColor.value
      font = Fonts.mirage_ils
      fontSize = 35
      text = "-80"
      transform = {
        rotate = -45
      }
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(-4.2), ph(104.1)]
      color = IlsColor.value
      font = Fonts.mirage_ils
      fontSize = 35
      text = "-80"
      transform = {
        rotate = -135
      }
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(3.7), ph(103.8)]
      color = IlsColor.value
      font = Fonts.mirage_ils
      fontSize = 35
      text = "-80"
      transform = {
        rotate = 135
      }
    }
  ]
}

let airSymbolHide = Computed(@() TargetPos.value[0] < TvvMark[0] + IlsPosSize[2] * 0.06 && TargetPos.value[0] > TvvMark[0] - IlsPosSize[2] * 0.06 &&
 TargetPos.value[1] < TvvMark[1] + IlsPosSize[3] * 0.06 && TargetPos.value[1] > TvvMark[1] - IlsPosSize[3] * 0.06)
let tvvLinked = {
  size = flex()
  children = [
    @(){
      watch = [IlsColor, airSymbolHide]
      rendObj = ROBJ_VECTOR_CANVAS
      size = [pw(5), ph(5)]
      color = IlsColor.value
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.value * 0.7
      commands = airSymbolHide.value ? [] : [
        [VECTOR_ELLIPSE, 0, 0, 30, 30],
        [VECTOR_LINE, -100, 0, -30, 0],
        [VECTOR_LINE, 100, 0, 30, 0],
        [VECTOR_LINE, 0, -80, 0, -30]
      ]
    }
    pitchWrap
  ]
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      translate = TvvMark
    }
  }
}

let overloadWatch = Computed(@() (Overload.value * 10.0).tointeger())
let overload = @(){
  watch = overloadWatch
  rendObj = ROBJ_TEXT
  pos = [pw(10), ph(30)]
  size = SIZE_TO_CONTENT
  color = IlsColor.value
  font = Fonts.mirage_ils
  fontSize = 40
  text = string.format("G %.1f", overloadWatch.value / 10.0)
}

let needReticle = Computed(@() !isAAMMode.value && TargetPosValid.value && !isCCIPMode.value)
let reticle = @(){
  watch = needReticle
  size = flex()
  children = needReticle.value ? {
    size = [pw(8), ph(8)]
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.value
    lineWidth = baseLineWidth * IlsLineScale.value * 1.4
    commands = [
      [VECTOR_LINE, 0, 0, 0, 0],
      [VECTOR_LINE, -100, 0, -100, 0],
      [VECTOR_LINE, -50, -86.6, -50, -86.6],
      [VECTOR_LINE, -86.6, -50, -86.6, -50],
      [VECTOR_LINE, 0, -100, 0, -100],
      [VECTOR_LINE, 50, -86.6, 50, -86.6],
      [VECTOR_LINE, 86.6, -50, 86.6, -50],
      [VECTOR_LINE, 100, 0, 100, 0],
      [VECTOR_LINE, 50, 86.6, 50, 86.6],
      [VECTOR_LINE, 86.6, 50, 86.6, 50],
      [VECTOR_LINE, 0, 100, 0, 100],
      [VECTOR_LINE, -50, 86.6, -50, 86.6],
      [VECTOR_LINE, -86.6, 50, -86.6, 50],
      [VECTOR_WIDTH, baseLineWidth * IlsLineScale.value],
      [VECTOR_LINE, -20, -10, -20, 10],
      [VECTOR_LINE, 20, -10, 20, 10]
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [TargetPos.value[0], TargetPos.value[1]]
      }
    }
  } : null
}

let dist = Computed(@() isCCIPMode.value ? DistToTarget.value : RadarTargetDist.value)
let radarDistWatched = Computed(@() (dist.value * 0.01).tointeger())
let radarDistSectorA = Computed(@() dist.value <= 0.0 ? -179 : cvt(dist.value, 0.0, 8400.0, 180.0, -179.0).tointeger())
let IsLaunchZoneVisible = Computed(@() isAAMMode.value && AamLaunchZoneDistMaxVal.value > 0.0)
let needDistReticle = Computed(@() isAAMMode.value || (isCCIPMode.value && TargetPosValid.value))
let reticleWithDist = @(){
  watch = needDistReticle
  size = flex()
  children = needDistReticle.value ? {
    size = flex()
    children = [
      {
        size = [pw(8), ph(8)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value * 1.4
        commands = [
          [VECTOR_LINE, 0, 0, 0, 0],
          [VECTOR_LINE, -50, -86.6, -50, -86.6],
          [VECTOR_LINE, -86.6, -50, -86.6, -50],
          [VECTOR_LINE, 50, -86.6, 50, -86.6],
          [VECTOR_LINE, 86.6, -50, 86.6, -50],
          [VECTOR_LINE, 50, 86.6, 50, 86.6],
          [VECTOR_LINE, 86.6, 50, 86.6, 50],
          [VECTOR_LINE, 0, 100, 0, 100],
          [VECTOR_LINE, -50, 86.6, -50, 86.6],
          [VECTOR_LINE, -86.6, 50, -86.6, 50],
          [VECTOR_WIDTH, baseLineWidth * IlsLineScale.value],
          [VECTOR_LINE, 100, 0, 120, 0],
          [VECTOR_LINE, 0, -150, 0, -100],
          [VECTOR_LINE, -120, 0, -100, 0]
        ]
        children = [
          @(){
            watch = radarDistSectorA
            rendObj = ROBJ_VECTOR_CANVAS
            size = flex()
            color = IlsColor.value
            fillColor = Color(0, 0, 0, 0)
            lineWidth = baseLineWidth * IlsLineScale.value
            commands = [
              [VECTOR_SECTOR, 0, 0, 100, 100, radarDistSectorA.value, 180]
            ]
          },
          {
            rendObj = ROBJ_VECTOR_CANVAS
            size = flex()
            color = IlsColor.value
            lineWidth = baseLineWidth * IlsLineScale.value * 0.7
            commands = [
              [VECTOR_LINE, 80, -10, 100, 0],
              [VECTOR_LINE, 80, 10, 100, 0]
            ]
            behavior = Behaviors.RtPropUpdate
            update = @() {
              transform = {
                rotate = radarDistSectorA.value
                pivot = [0, 0]
              }
            }
          },
          @(){
            watch = IsLaunchZoneVisible
            size = flex()
            children = IsLaunchZoneVisible.value ? [
              {
                size = flex()
                rendObj = ROBJ_VECTOR_CANVAS
                color = IlsColor.value
                lineWidth = baseLineWidth * IlsLineScale.value * 0.7
                commands = [
                  [VECTOR_LINE, 100, 0, 115, 0],
                  [VECTOR_LINE, 115, 0, 115, -15]
                ]
                behavior = Behaviors.RtPropUpdate
                update = @() {
                  transform = {
                    rotate = cvt(AamLaunchZoneDistMinVal.value, 0.0, 8400.0, 180.0, -179.9)
                    pivot = [0, 0]
                  }
                }
              }
              {
                size = flex()
                rendObj = ROBJ_VECTOR_CANVAS
                color = IlsColor.value
                lineWidth = baseLineWidth * IlsLineScale.value * 0.7
                commands = [
                  [VECTOR_LINE, 100, 0, 115, 0],
                  [VECTOR_LINE, 115, 10, 115, -10]
                ]
                behavior = Behaviors.RtPropUpdate
                update = @() {
                  transform = {
                    rotate = cvt(AamLaunchZoneDistMaxVal.value, 0.0, 8400.0, 180.0, -179.9)
                    pivot = [0, 0]
                  }
                }
              }
            ] : null
          }
        ]
      }
      @(){
        watch = radarDistWatched
        size = [pw(16), SIZE_TO_CONTENT]
        pos = [pw(-8), ph(10)]
        rendObj = ROBJ_TEXT
        color = IlsColor.value
        halign = ALIGN_CENTER
        font = Fonts.mirage_ils
        fontSize = 35
        text = radarDistWatched.value <= 0.0 ? "" : string.format("%.1f", radarDistWatched.value * 0.1)
      }
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = isCCIPMode.value ? TargetPos.value : [IlsPosSize[2] * 0.5, IlsPosSize[3] * 0.5]
      }
    }
  } : null
}

let AoaWatched = Computed(@() Aoa.value.tointeger())
let aoa = @() {
  watch = AoaWatched
  size = SIZE_TO_CONTENT
  pos = [pw(10), ph(25)]
  rendObj = ROBJ_TEXT
  color = IlsColor.value
  font = Fonts.mirage_ils
  fontSize = 40
  text = string.format("α %d", AoaWatched.value)
}

let RadarLockLimited = Watched(false)
let RadarLockDir = Watched([])
function updRadarLockLimited() {
  RadarLockLimited(RadarTargetPos[0] < IlsPosSize[2] * 0.04 || RadarTargetPos[0] > IlsPosSize[2] * 0.96 || RadarTargetPos[1] < IlsPosSize[3] * 0.04 || RadarTargetPos[1] > IlsPosSize[3] * 0.96)
  let posLimited = [clamp(RadarTargetPos[0], IlsPosSize[2] * 0.04, IlsPosSize[2] * 0.96),
              clamp(RadarTargetPos[1], IlsPosSize[3] * 0.04, IlsPosSize[3] * 0.96)]
  RadarLockDir([(RadarTargetPos[0] - posLimited[0]) / IlsPosSize[2] / 0.04, (RadarTargetPos[1] - posLimited[1]) / IlsPosSize[3] / 0.04])
}
let radarTargetVisible = Computed(@() RadarTargetDist.value > 0.0 && !BombingMode.value)
let radarTargetMark = @(){
  watch = radarTargetVisible
  size = flex()
  children = radarTargetVisible.value ? [
    {
      size = [pw(4), ph(4)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.value
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.value * 0.7
      commands = [
        [VECTOR_ELLIPSE, 0, 0, 80, 80]
      ]
      behavior = Behaviors.RtPropUpdate
      update = function() {
        let pos = [clamp(RadarTargetPos[0], IlsPosSize[2] * 0.04, IlsPosSize[2] * 0.96),
          clamp(RadarTargetPos[1], IlsPosSize[3] * 0.04, IlsPosSize[3] * 0.96)]
        return {
          transform = {
            translate = pos
          }
        }
      }
      function onAttach() {
        updRadarLockLimited()
        setInterval(0.5, updRadarLockLimited)
      }
      onDetach = @() clearTimer(updRadarLockLimited)
      children = [
        {
          size = flex()
          rendObj = ROBJ_VECTOR_CANVAS
          color = IlsColor.value
          lineWidth = baseLineWidth * IlsLineScale.value * 0.7
          commands = [
            [VECTOR_LINE, -100, -100, -85, -85],
            [VECTOR_LINE, -100, 100, -85, 85],
            [VECTOR_LINE, 100, 100, 85, 85],
            [VECTOR_LINE, 100, -100, 85, -85]
          ]
          animations = [
            { prop = AnimProp.opacity, from = -1, to = 1, duration = 0.5, play = true, loop = true }
          ]
        }
        @() {
          watch = RadarLockLimited
          size = flex()
          children = RadarLockLimited.value ? @(){
            watch = RadarLockDir
            size = flex()
            rendObj = ROBJ_VECTOR_CANVAS
            color = IlsColor.value
            lineWidth = baseLineWidth * IlsLineScale.value * 0.7
            commands = [
              [VECTOR_LINE, 0, 0, RadarLockDir.value[0] * 100, RadarLockDir.value[1] * 100]
            ]
          } : null
        }
      ]
    }
  ] : null
}

let aamLockLimited = Watched(false)
let aamLockDir = Watched([])
function updAamLockLimited() {
  aamLockLimited(IlsTrackerX.value < IlsPosSize[2] * 0.04 || IlsTrackerX.value > IlsPosSize[2] * 0.96 || IlsTrackerY.value < IlsPosSize[3] * 0.04 || IlsTrackerY.value > IlsPosSize[3] * 0.96)
  let posLimited = [clamp(IlsTrackerX.value, IlsPosSize[2] * 0.04, IlsPosSize[2] * 0.96),
              clamp(IlsTrackerY.value, IlsPosSize[3] * 0.04, IlsPosSize[3] * 0.96)]
  aamLockDir([(IlsTrackerX.value - posLimited[0]) / IlsPosSize[2] / 0.04, (IlsTrackerY.value - posLimited[1]) / IlsPosSize[3] / 0.04])
}
let aamTargetVisible = Computed(@() isAAMMode.value && !radarTargetVisible.value)
let aamReady = Computed(@() aamTargetVisible.value && GuidanceLockState.value == GuidanceLockResult.RESULT_TRACKING)
let aamTargetMark = @(){
  watch = aamTargetVisible
  size = flex()
  children = aamTargetVisible.value ? [
    {
      size = [pw(4), ph(4)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.value
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.value * 0.7
      commands = [
        [VECTOR_ELLIPSE, 0, 0, 80, 80]
      ]
      behavior = Behaviors.RtPropUpdate
      update = function() {
        let pos = [clamp(IlsTrackerX.value, IlsPosSize[2] * 0.04, IlsPosSize[2] * 0.96),
          clamp(IlsTrackerY.value, IlsPosSize[3] * 0.04, IlsPosSize[3] * 0.96)]
        return {
          transform = {
            translate = pos
          }
        }
      }
      function onAttach() {
        updAamLockLimited()
        setInterval(0.5, updAamLockLimited)
      }
      onDetach = @() clearTimer(updAamLockLimited)
      children = [
        {
          size = flex()
          rendObj = ROBJ_VECTOR_CANVAS
          color = IlsColor.value
          lineWidth = baseLineWidth * IlsLineScale.value * 0.7
          commands = [
            [VECTOR_LINE, -100, -100, -85, -85],
            [VECTOR_LINE, -100, 100, -85, 85],
            [VECTOR_LINE, 100, 100, 85, 85],
            [VECTOR_LINE, 100, -100, 85, -85]
          ]
          animations = [
            { prop = AnimProp.opacity, from = -1, to = 1, duration = 0.5, play = true, loop = true }
          ]
        }
        @() {
          watch = aamLockLimited
          size = flex()
          children = aamLockLimited.value ? @(){
            watch = aamLockDir
            size = flex()
            rendObj = ROBJ_VECTOR_CANVAS
            color = IlsColor.value
            lineWidth = baseLineWidth * IlsLineScale.value * 0.7
            commands = [
              [VECTOR_LINE, 0, 0, aamLockDir.value[0] * 100, aamLockDir.value[1] * 100]
            ]
          } : null
        }
      ]
    }
  ] : null
}

let aamTargetDir = Watched([0, 0])
let aamReadyMark = @() {
  watch = aamReady
  size = flex()
  children = aamReady.value ? @() {
    rendObj = ROBJ_VECTOR_CANVAS
    size = [ph(1), ph(1)]
    color = IlsColor.value
    fillColor = Color(0, 0, 0, 0)
    lineWidth = baseLineWidth * IlsLineScale.value * 0.5
    commands = [
      [VECTOR_ELLIPSE, 0, 0, 100, 100],
      [VECTOR_LINE, -70, -70, 70, 70],
      [VECTOR_LINE, -70, 70, 70, -70]
    ]
    behavior = Behaviors.RtPropUpdate
    update = function() {
      let aamPos = [clamp(IlsTrackerX.value, IlsPosSize[2] * 0.04, IlsPosSize[2] * 0.96),
          clamp(IlsTrackerY.value, IlsPosSize[3] * 0.04, IlsPosSize[3] * 0.96)]
      aamTargetDir([(aamPos[0] - TvvMark[0]) / IlsPosSize[2], (aamPos[1] - TvvMark[1]) / IlsPosSize[3]])
      return {
        transform = {
          translate = TvvMark
        }
      }
    }
    children = @(){
      watch = aamTargetDir
      size = [IlsPosSize[2], IlsPosSize[3]]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.value
      lineWidth = baseLineWidth * IlsLineScale.value * 0.7
      commands = [
        [VECTOR_LINE, 0, 0, aamTargetDir.value[0] * 100, aamTargetDir.value[1] * 100]
      ]
    }
  } : null
}

let maxDistOfLaunchZone = Computed(@() max(max(RadarTargetDist.value, AamLaunchZoneDistMaxVal.value), 1.0) * 1.1)
let curDistMarkPos = Computed(@() (RadarTargetDist.value / maxDistOfLaunchZone.value * 100.0).tointeger())
let maxDistMarkPos = Computed(@() (AamLaunchZoneDistMaxVal.value / maxDistOfLaunchZone.value * 100.0).tointeger())
let minDistMarkPos = Computed(@() (AamLaunchZoneDistMinVal.value / maxDistOfLaunchZone.value * 100.0).tointeger())
let distMiles = Computed(@() (RadarTargetDist.value * metrToNavMile * 10.0).tointeger())
let distKm = Computed(@() (RadarTargetDist.value * 0.001 * 10.0).tointeger())
function launchZone(is_metric) {
  return @(){
    watch = radarTargetVisible
    size = flex()
    pos = [pw(40), ph(60)]
    children = radarTargetVisible.value ? {
      size = [pw(20), ph(10)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.value
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.value * 0.7
      commands = [
        [VECTOR_ELLIPSE, 0, 50, 5, 10],
        [VECTOR_LINE, 5, 50, 100, 50]
      ]
      children = [
        {
          rendObj = ROBJ_TEXT
          pos = [pw(-5), ph(40)]
          size = [pw(10), ph(20)]
          color = IlsColor.value
          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
          font = Fonts.mirage_ils
          fontSize = 20
          text = "R"
        }
        @(){
          watch = curDistMarkPos
          size = flex()
          rendObj = ROBJ_VECTOR_CANVAS
          color = IlsColor.value
          lineWidth = baseLineWidth * IlsLineScale.value * 0.5
          commands = [
            [VECTOR_LINE, curDistMarkPos.value, 50, curDistMarkPos.value - 3, 40],
            [VECTOR_LINE, curDistMarkPos.value, 50, curDistMarkPos.value + 3, 40],
            [VECTOR_LINE, curDistMarkPos.value - 3, 40, curDistMarkPos.value - 8, 40]
          ]
        }
        @(){
          watch = maxDistMarkPos
          size = flex()
          rendObj = ROBJ_VECTOR_CANVAS
          color = IlsColor.value
          lineWidth = baseLineWidth * IlsLineScale.value * 0.5
          commands = [
            [VECTOR_LINE, maxDistMarkPos.value, 50, maxDistMarkPos.value, 65],
            [VECTOR_LINE, maxDistMarkPos.value - 4, 65, maxDistMarkPos.value, 65]
          ]
        }
        @(){
          watch = minDistMarkPos
          size = flex()
          rendObj = ROBJ_VECTOR_CANVAS
          color = IlsColor.value
          lineWidth = baseLineWidth * IlsLineScale.value * 0.5
          commands = [
            [VECTOR_LINE, minDistMarkPos.value, 50, minDistMarkPos.value, 65],
            [VECTOR_LINE, minDistMarkPos.value + 4, 65, minDistMarkPos.value, 65]
          ]
        }
        @() {
          watch = is_metric ? distKm : distMiles
          size = [flex(), SIZE_TO_CONTENT]
          pos = [0, ph(70)]
          rendObj = ROBJ_TEXT
          color = IlsColor.value
          halign = ALIGN_CENTER
          font = Fonts.mirage_ils
          fontSize = 25
          text = string.format("R%.1f", (is_metric ? distKm : distMiles).get() * 0.1)
        }
      ]
    } : null
  }
}

function getRadarMode() {
  if (RadarModeNameId.value >= 0) {
    let mode = modeNames[RadarModeNameId.value]
    if (mode == "hud/ACM" || mode == "hud/LD ACM" || mode == "hud/PD ACM" || mode == "hud/PD VS ACM" || mode == "hud/MTI ACM" || mode == "hud/TWS ACM" ||  mode == "hud/IRST ACM")
      return "WVR+"
    if (mode == "hud/GTM track" || mode == "hud/TWS GTM search" || mode == "hud/GTM search" || mode == "hud/GTM acquisition" || mode == "hud/TWS GTM acquisition")
      return "GRD"
  }
  return "BVR+"
}

let radarMode = @(){
  watch = RadarModeNameId
  rendObj = ROBJ_TEXT
  pos = [pw(5), ph(95)]
  size = SIZE_TO_CONTENT
  color = IlsColor.value
  font = Fonts.hud
  fontSize = 30
  text = getRadarMode()
  children = {
    rendObj = ROBJ_SOLID
    size = [flex(), baseLineWidth * IlsLineScale.value * 0.7]
    pos = [0, ph(80)]
    color = IlsColor.value
  }
}

let aimLock = @(){
  watch = AimLockValid
  size = flex()
  children = AimLockValid.value ? @(){
    rendObj = ROBJ_VECTOR_CANVAS
    size = [pw(3), ph(3)]
    color = IlsColor.value
    fillColor = Color(0, 0, 0, 0)
    lineWidth = baseLineWidth * IlsLineScale.value * 0.7
    commands = [
      [VECTOR_ELLIPSE, 0, 0, 40, 40],
      [VECTOR_LINE, -100, 0, -40, 0],
      [VECTOR_LINE, 100, 0, 40, 0],
      [VECTOR_LINE, 0, -100, 0, -40],
      [VECTOR_LINE, 0, 100, 0, 40]
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
         translate = AimLockPos
       }
    }
  } : null
}

let lowerSolutionCue = @(){
  watch = IlsColor
  size = [pw(10), baseLineWidth * IlsLineScale.value]
  rendObj = ROBJ_SOLID
  color = IlsColor.value
  lineWidth = baseLineWidth * IlsLineScale.value
  behavior = Behaviors.RtPropUpdate
  update = function() {
    let cuePos = TimeBeforeBombRelease.value <= 0.0 ? 0.4 : cvt(TimeBeforeBombRelease.value, 0.0, 10.0, 0, 0.4)
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
            size = [baseLineWidth * IlsLineScale.value, flex()]
            rendObj = ROBJ_SOLID
            color = IlsColor.value
            lineWidth = baseLineWidth * IlsLineScale.value
          }
        ]
      }
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [AimLockPos[0], 0]
        rotate = -Roll.value
        pivot = [0, AimLockPos[1] / IlsPosSize[3]]
      }
    }
  }
}

let SecondsToRelease = Computed(@() TimeBeforeBombRelease.value.tointeger())
let timeToRelease = @() {
  watch = SecondsToRelease
  rendObj = ROBJ_TEXT
  size = SIZE_TO_CONTENT
  color = IlsColor.value
  pos = [pw(82), ph(95)]
  font = Fonts.mirage_ils
  fontSize = 30
  text = SecondsToRelease.value > 0 ? string.format("%d SEC", SecondsToRelease.value) : ""
  children = {
    rendObj = ROBJ_SOLID
    size = [flex(), baseLineWidth * IlsLineScale.value * 0.7]
    pos = [0, ph(90)]
    color = IlsColor.value
  }
}

let ccrpMarks = @() {
  watch = BombingMode
  size = flex()
  children = BombingMode.value ? [
    timeToRelease
    rotatedBombReleaseReticle()
  ] : null
}

function EP17(width, height, is_metric) {
  return {
    size = [width, height]
    children = [
      speed(width, height, is_metric)
      mach
      altWrap(width, height, generateAltMark, is_metric)
      tvvLinked
      overload
      reticle
      reticleWithDist
      aoa
      compassWrap(width, height, 0.1, generateCompassMarkSU145, 0.8, 5.0, false, 12, Fonts.mirage_ils)
      {
        rendObj = ROBJ_VECTOR_CANVAS
        size = [pw(2), ph(2)]
        pos = [pw(49), ph(19)]
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value * 0.7
        commands = [
          [VECTOR_LINE, 0, 100, 50, 0],
          [VECTOR_LINE, 100, 100, 50, 0]
        ]
      }
      radarTargetMark
      launchZone(is_metric)
      aamTargetMark
      aamReadyMark
      radarMode
      aimLock
      ccrpMarks
    ]
  }
}

return EP17