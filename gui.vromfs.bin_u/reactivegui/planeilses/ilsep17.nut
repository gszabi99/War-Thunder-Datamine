from "%rGui/globals/ui_library.nut" import *
let { IlsColor, IlsLineScale, BombCCIPMode, RocketMode, CannonMode,
 TargetPosValid, TargetPos, TvvMark, RadarTargetDist, DistToTarget, IlsPosSize } = require("%rGui/planeState/planeToolsState.nut")
let { baseLineWidth, mpsToKnots, metrToFeet } = require("ilsConstants.nut")
let { Speed, Mach, BarAltitude, Altitude, Overload, Aoa, Tangage, Roll } = require("%rGui/planeState/planeFlyState.nut")
let string = require("string")
let { GuidanceLockState } = require("%rGui/rocketAamAimState.nut")
let { GuidanceLockResult } = require("%rGui/guidanceConstants.nut")
let { cvt } = require("dagor.math")
let { AamLaunchZoneDistMaxVal, AamLaunchZoneDistMinVal } = require("%rGui/radarState.nut")
let { compassWrap, generateCompassMarkSU145 } = require("ilsCompasses.nut")

let isAAMMode = Computed(@() GuidanceLockState.value > GuidanceLockResult.RESULT_STANDBY)
let isCCIPMode = Computed(@() RocketMode.value || BombCCIPMode.value || CannonMode.value)
let speedValue = Computed(@() (Speed.value * mpsToKnots).tointeger())
let function speed(width, height) {
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
            translate = [0, ((Speed.value * mpsToKnots) % 50.0) * height * 0.001]
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
        watch = speedValue
        size = [pw(70), SIZE_TO_CONTENT]
        pos = [0, ph(46)]
        rendObj = ROBJ_TEXT
        padding = [0, 5]
        halign= ALIGN_RIGHT
        color = IlsColor.value
        font = Fonts.mirage_ils
        fontSize = 40
        text = speedValue.value.tostring()
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

let function altitude(height, generateFunc) {
  let children = []
  for (local i = 65000; i >= 0;) {
    children.append(generateFunc(i))
    i -= i > 500 ? 250 : 100
  }

  let getOffset = @() ((65000 - max(BarAltitude.value * metrToFeet, 500)) * 0.0008 + (BarAltitude.value * metrToFeet >= 500 ? 0.0 : ((500 - BarAltitude.value * metrToFeet) * 0.002)) - 0.37) * height
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

let altValueThousand = Computed(@() (Altitude.value * metrToFeet / 1000.0).tointeger())
let altValueMod = Computed(@() (Altitude.value * metrToFeet % 1000.0).tointeger())
let altCompressed = {
  size = flex()
  children = [
    {
      pos = [0, ph(45)]
      size = flex()
      flow = FLOW_HORIZONTAL
      children = [
        @(){
          watch = altValueThousand
          size = SIZE_TO_CONTENT
          rendObj = ROBJ_TEXT
          color = IlsColor.value
          padding = [0, 5]
          font = Fonts.mirage_ils
          fontSize = 45
          text = altValueThousand.value.tostring()
        }
        @(){
          watch = altValueMod
          pos = [0, 10]
          rendObj = ROBJ_TEXT
          valign = ALIGN_BOTTOM
          color = IlsColor.value
          font = Fonts.mirage_ils
          fontSize = 30
          text = string.format("%03d", altValueMod.value)
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

let function altWrap(width, height, generateFunc) {
  return @(){
    watch = isAAMMode
    size = [width * 0.17, height * 0.4]
    pos = [width * 0.75, height * 0.3]
    clipChildren = true
    children = !isAAMMode.value ? [
      altitude(height * 0.4, generateFunc)
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
    ] : altCompressed
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
    [VECTOR_ELLIPSE, 0, 0, 5.55, 5.55],//80
    [VECTOR_ELLIPSE, 0, 0, 11.11, 11.11],//70
    [VECTOR_ELLIPSE, 0, 0, 16.67, 16.67],//60
    [VECTOR_ELLIPSE, 0, 0, 22.22, 22.22],//50
    [VECTOR_ELLIPSE, 0, 0, 27.78, 27.78],//40
    [VECTOR_ELLIPSE, 0, 0, 33.33, 33.33],//30
    [VECTOR_ELLIPSE, 0, -38.89, 77.78, 77.78],//20
    [VECTOR_LINE, -100, 44.44, 100, 44.44],//10
    [VECTOR_LINE, -100, 50, -3, 50],//0
    [VECTOR_LINE, 3, 50, 100, 50],//0
    [VECTOR_LINE, -2.5, 50, -2.5, 50],//0
    [VECTOR_LINE, -2, 50, -2, 50],//0
    [VECTOR_LINE, -1.5, 50, -1.5, 50],//0
    [VECTOR_LINE, -1, 50, -1, 50],//0
    [VECTOR_LINE, -0.5, 50, -0.5, 50],//0
    [VECTOR_LINE, 0.5, 50, 0.5, 50],//0
    [VECTOR_LINE, 1, 50, 1, 50],//0
    [VECTOR_LINE, 1.5, 50, 1.5, 50],//0
    [VECTOR_LINE, 2, 50, 2, 50],//0
    [VECTOR_LINE, 2.5, 50, 2.5, 50],//0
    [VECTOR_LINE, -30, 55.56, -5.4, 55.56],//10
    [VECTOR_LINE, -5, 55.56, -5.2, 54.91],//10
    [VECTOR_LINE, -5.4, 55.56, -5.2, 54.91],//10
    [VECTOR_LINE, -5, 55.56, 2.3, 55.56],//10
    [VECTOR_LINE, 2.3, 55.56, 2.525, 54.91],//10
    [VECTOR_LINE, 2.75, 55.56, 2.525, 54.91],//10
    [VECTOR_LINE, 2.75, 55.56, 30, 55.56],//10
    [VECTOR_SECTOR, 0, 138.89, 77.78, 77.78, 210, 266],//20
    [VECTOR_SECTOR, 0, 138.89, 77.78, 77.78, 266.3, 271.7],//20
    [VECTOR_SECTOR, 0, 138.89, 77.78, 77.78, -88, -40],//20
    [VECTOR_LINE, 2.3, 61.11, 2.525, 60.5],//20
    [VECTOR_LINE, 2.75, 61.15, 2.525, 60.5],//20
    [VECTOR_LINE, -5, 61.25, -5.22, 60.65],//20
    [VECTOR_LINE, -5.4, 61.3, -5.22, 60.65],//20
    [VECTOR_SECTOR, 0, 100, 33.33, 33.33, 261, 277],//30
    [VECTOR_SECTOR, 0, 100, 33.33, 33.33, -82.2, -20],//30
    [VECTOR_SECTOR, 0, 100, 33.33, 33.33, 210, 260.2],//30
    [VECTOR_LINE, 4.05, 66.9, 4.35, 66.35],//30
    [VECTOR_LINE, 4.55, 67, 4.35, 66.35],//30
    [VECTOR_LINE, -5.25, 67.1, -5.6, 66.45],//30
    [VECTOR_LINE, -5.70, 67.15, -5.6, 66.45],//30
    [VECTOR_SECTOR, 0, 100, 27.78, 27.78, 259, 279],//40
    [VECTOR_SECTOR, 0, 100, 27.78, 27.78, -80, -20],//40
    [VECTOR_SECTOR, 0, 100, 27.78, 27.78, 210, 258.2],//40
    [VECTOR_LINE, 4.35, 72.55, 4.7, 71.95],//40
    [VECTOR_LINE, 4.85, 72.6, 4.7, 71.95],//40
    [VECTOR_LINE, -5.3, 72.7, -5.6, 72.15],//40
    [VECTOR_LINE, -5.7, 72.8, -5.6, 72.15],//40
    [VECTOR_SECTOR, 0, 100, 22.22, 22.22, 256, 281],//50
    [VECTOR_SECTOR, 0, 100, 22.22, 22.22, -77.8, -20],//50
    [VECTOR_SECTOR, 0, 100, 22.22, 22.22, 200, 255],//50
    [VECTOR_LINE, 4.25, 78.2, 4.6, 77.65],//50
    [VECTOR_LINE, 4.7, 78.27, 4.6, 77.65],//50
    [VECTOR_LINE, -5.35, 78.45, -5.7, 77.9],//50
    [VECTOR_LINE, -5.75, 78.52, -5.7, 77.9],//50
    [VECTOR_SECTOR, 0, 100, 16.67, 16.67, 254, 286],//60
    [VECTOR_SECTOR, 0, 100, 16.67, 16.67, -72.5, -20],//60
    [VECTOR_SECTOR, 0, 100, 16.67, 16.67, 200, 252.5],//60
    [VECTOR_LINE, 4.6, 84, 4.95, 83.45],//60
    [VECTOR_LINE, 5.0, 84.1, 4.95, 83.45],//60
    [VECTOR_LINE, -4.6, 83.95, -5.0, 83.45],//60
    [VECTOR_LINE, -5.0, 84.1, -5.0, 83.45],//60
    [VECTOR_SECTOR, 0, 100, 11.11, 11.11, 254, 286],//70
    [VECTOR_SECTOR, 0, 100, 11.11, 11.11, -71.5, 0],//70
    [VECTOR_SECTOR, 0, 100, 11.11, 11.11, 180, 251.5],//70
    [VECTOR_LINE, 3.05, 89.3, 3.45, 88.7],//70
    [VECTOR_LINE, 3.55, 89.45, 3.45, 88.7],//70
    [VECTOR_LINE, -3.05, 89.3, -3.5, 88.7],//70
    [VECTOR_LINE, -3.55, 89.45, -3.5, 88.7],//70
    [VECTOR_SECTOR, 0, 100, 5.55, 5.55, -88, -62],//80
    [VECTOR_SECTOR, 0, 100, 5.55, 5.55, -58, -32],//80
    [VECTOR_SECTOR, 0, 100, 5.55, 5.55, -28, -2],//80
    [VECTOR_SECTOR, 0, 100, 5.55, 5.55, 2, 28],//80
    [VECTOR_SECTOR, 0, 100, 5.55, 5.55, 32, 58],//80
    [VECTOR_SECTOR, 0, 100, 5.55, 5.55, 62, 88],//80
    [VECTOR_SECTOR, 0, 100, 5.55, 5.55, 92, 118],//80
    [VECTOR_SECTOR, 0, 100, 5.55, 5.55, 122, 148],//80
    [VECTOR_SECTOR, 0, 100, 5.55, 5.55, 152, 178],//80
    [VECTOR_SECTOR, 0, 100, 5.55, 5.55, 242, 268],//80
    [VECTOR_SECTOR, 0, 100, 5.55, 5.55, 212, 238],//80
    [VECTOR_SECTOR, 0, 100, 5.55, 5.55, 182, 208],//80
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
    [VECTOR_SECTOR, 0, 100, 2, 2, -85, -5],//90
    [VECTOR_SECTOR, 0, 100, 2, 2, 5, 85],//90
    [VECTOR_SECTOR, 0, 100, 2, 2, 95, 175],//90
    [VECTOR_SECTOR, 0, 100, 2, 2, 185, 265],//90
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
    //pitchWrap(IlsPosSize[2], IlsPosSize[3])
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
  children = needDistReticle.value ? [
    {
      size = [pw(8), ph(8)]
      pos = [pw(50), ph(50)]
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
      pos = [pw(42), ph(60)]
      rendObj = ROBJ_TEXT
      color = IlsColor.value
      halign = ALIGN_CENTER
      font = Fonts.mirage_ils
      fontSize = 35
      text = radarDistWatched.value <= 0.0 ? "" : string.format("%.1f", radarDistWatched.value * 0.1)
    }
  ] : null
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
  text = string.format("A %d", AoaWatched.value)
}

let function EP17(width, height) {
  return {
    size = [width, height]
    children = [
      speed(width, height)
      mach
      altWrap(width, height, generateAltMark)
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
    ]
  }
}

return EP17