from "%rGui/globals/ui_library.nut" import *

let { IlsColor, TargetPosValid, TargetPos, IlsLineScale,
       RocketMode, CannonMode, BombCCIPMode, RadarTargetPos, RadarTargetPosValid } = require("%rGui/planeState/planeToolsState.nut")
let { Roll, Tangage, BarAltitude } = require("%rGui/planeState/planeFlyState.nut");
let { baseLineWidth } = require("ilsConstants.nut")
let { compassWrap, generateCompassTCSFMark } = require("ilsCompasses.nut")
let { fabs } = require("math")

let CCIPMode = Computed(@() RocketMode.value || CannonMode.value || BombCCIPMode.value)
let tcsfAimMark = @() {
  watch = [TargetPosValid, CCIPMode]
  size = flex()
  children = TargetPosValid.value ? (
    !CCIPMode.value ?
    {
      size = const [pw(13), ph(13)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = Color(255, 70, 10)
      fillColor = Color(255, 70, 10)
      lineWidth = baseLineWidth * IlsLineScale.value
      commands = [
        [VECTOR_POLY, 0, -100, -2, -92.5, 0, -85, 2, -92.5],
        [VECTOR_POLY, 0, 100, -2, 92.5, 0, 85, 2, 92.5],
        [VECTOR_POLY, -85.5, -50, -80, -44.75, -72.5, -42.5, -78, -47.75],
        [VECTOR_POLY, 85.5, -50, 80, -44.75, 72.5, -42.5, 78, -47.75],
        [VECTOR_POLY, 85.5, 50, 80, 44.75, 72.5, 42.5, 78, 47.75],
        [VECTOR_POLY, -85.5, 50, -80, 44.75, -72.5, 42.5, -78, 47.75],
        [VECTOR_WIDTH, baseLineWidth * IlsLineScale.value * 3.0],
        [VECTOR_LINE, 0, 0, 0, 0]
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = [TargetPos.value[0], TargetPos.value[1]]
        }
      }
    } :
    @() {
      watch = IlsColor
      size = [baseLineWidth * IlsLineScale.value * 3, baseLineWidth * IlsLineScale.value * 3]
      rendObj = ROBJ_SOLID
      color = IlsColor.value
      lineWidth = baseLineWidth * IlsLineScale.value
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = [TargetPos.value[0] - baseLineWidth * IlsLineScale.value * 1.5, TargetPos.value[1] - baseLineWidth * IlsLineScale.value * 1.5]
        }
      }
    })
  : null
}

let tcsfRadarAimMark = @() {
  watch = RadarTargetPosValid
  size = flex()
  children = RadarTargetPosValid.value ? (
    {
      size = const [pw(8), ph(8)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = Color(255, 70, 10)
      fillColor = Color(255, 70, 10)
      lineWidth = baseLineWidth * IlsLineScale.value
      commands = [
        [VECTOR_LINE, -100, 0, -70, -30],
        [VECTOR_LINE, -50, -50, -50, -50],
        [VECTOR_LINE, -30, -70, 0, -100],
        [VECTOR_LINE, 100, 0, 70, -30],
        [VECTOR_LINE, 50, -50, 50, -50],
        [VECTOR_LINE, 30, -70, 0, -100],
        [VECTOR_LINE, -100, 0, -70, 30],
        [VECTOR_LINE, -50, 50, -50, 50],
        [VECTOR_LINE, -30, 70, 0, 100],
        [VECTOR_LINE, 100, 0, 70, 30],
        [VECTOR_LINE, 50, 50, 50, 50],
        [VECTOR_LINE, 30, 70, 0, 100]
      ]
      children = @() {
        watch = IlsColor
        pos = [-baseLineWidth * IlsLineScale.value * 1.5, -baseLineWidth * IlsLineScale.value * 1.5]
        size = [baseLineWidth * IlsLineScale.value * 3, baseLineWidth * IlsLineScale.value * 3]
        rendObj = ROBJ_SOLID
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
      }
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = [RadarTargetPos[0], RadarTargetPos[1]]
        }
      }
    })
  : null
}


let tcsfAirSymbol = {
  size = flex()
  color = Color(255, 70, 10)
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = baseLineWidth * IlsLineScale.value * 1.5
  commands = [
    [VECTOR_LINE, 42, 50, 48, 50],
    [VECTOR_LINE, 52, 50, 58, 50],
    [VECTOR_WIDTH, baseLineWidth * IlsLineScale.value * 1.2],
    [VECTOR_LINE, 50, 49, 50, 47],
    [VECTOR_LINE, 50, 11, 50, 13]
  ]
}

function altitude(height, generateFunc) {
  let children = []

  for (local i = 200; i >= 0; i -= 5) {
    children.append(generateFunc(i))
  }

  let getOffset = @() (max(2000.0 - BarAltitude.value, 0.0) * 0.00202 - 0.45) * height
  return {
    size = const [pw(100), ph(100)]
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

function altWrap(width, height, generateFunc) {
  return {
    size = [width * 0.17, height * 0.3]
    pos = [width * 0.75, height * 0.35]
    clipChildren = true
    children = [
      altitude(height * 0.3, generateFunc),
    ]
  }
}

let generateAltMark = function(num) {
  return {
    size = const [pw(100), ph(10)]
    pos = [pw(15), 0]
    flow = FLOW_HORIZONTAL
    children = [
      @() {
        watch = IlsColor
        size = [baseLineWidth * (num % 10 > 0 ? 3 : 5), baseLineWidth * IlsLineScale.value]
        rendObj = ROBJ_SOLID
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
        vplace = ALIGN_CENTER
      },
      (num % 10 > 0 ? null :
        @() {
          watch = IlsColor
          size = flex()
          rendObj = ROBJ_TEXT
          color = IlsColor.value
          vplace = ALIGN_CENTER
          fontSize = 40
          font = Fonts.hud
          text = (num * 10).tostring()
        }
      )
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
    size = [width * 0.6, height * 0.5]
    pos = [width * 0.2, height * 0.5]
    flow = FLOW_VERTICAL
    children = children
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, -height * (90.0 - Tangage.value) * 0.015]
        rotate = -Roll.value
        pivot = [0.5, (90.0 - Tangage.value) * 0.03]
      }
    }
  }
}

function generatePitchLine(num) {
  return {
    size = const [pw(100), ph(15)]
    flow = FLOW_VERTICAL
    children = (num == 0) ? @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.value
        color = IlsColor.value
        fillColor = Color(0, 0, 0, 0)
        commands = [
          [VECTOR_LINE, 0, 0, 30, 0],
          [VECTOR_LINE, 7.5, 10, 22.5, 10],
          [VECTOR_LINE, 11.25, 20, 18.75, 20],
          [VECTOR_LINE, 70, 0, 100, 0],
          [VECTOR_LINE, 77.5, 10, 92.5, 10],
          [VECTOR_LINE, 88.75, 20, 81.75, 20],
          [VECTOR_ELLIPSE, 50, 0, 1, 8]
        ]
      }
      : (num % 10 == 0) ? @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.value
        color = IlsColor.value
        commands = [
          (fabs(num) == 10 ? [VECTOR_LINE, 15, 0, 30, 0] : []),
          (fabs(num) == 10 ? [VECTOR_LINE, 70, 0, 85, 0] : []),
          (fabs(num) == 10 ? [VECTOR_LINE, 21.5, 10, 23.5, 10] : []),
          (fabs(num) == 10 ? [VECTOR_LINE, 78.5, 10, 76.5, 10] : []),
          (fabs(num) == 20 ? [VECTOR_LINE, 25, 0, 30, 0] : []),
          (fabs(num) == 20 ? [VECTOR_LINE, 70, 0, 75, 0] : []),
          (fabs(num) == 20 ? [VECTOR_LINE, 73.25, 10, 71.75, 10] : []),
          (fabs(num) == 20 ? [VECTOR_LINE, 28.25, 10, 26.75, 10] : []),
          (fabs(num) == 30 ? [VECTOR_LINE, 32.5, 0, 37.5, 0] : []),
          (fabs(num) == 30 ? [VECTOR_LINE, 62.5, 0, 67.5, 0] : []),
          (fabs(num) == 30 ? [VECTOR_LINE, 65.75, 10, 64.25, 10] : []),
          (fabs(num) == 30 ? [VECTOR_LINE, 34.25, 10, 35.75, 10] : []),
          (fabs(num) > 30 ? [VECTOR_LINE, 42.5, 0, 37.5, 0] : []),
          (fabs(num) > 30 ? [VECTOR_LINE, 62.5, 0, 57.5, 0] : []),
          (fabs(num) > 30 ? [VECTOR_LINE, 60.75, 10, 59.25, 10] : []),
          (fabs(num) > 30 ? [VECTOR_LINE, 39.25, 10, 40.75, 10] : []),
        ]
        children = {
          rendObj = ROBJ_TEXT
          pos = [pw(47), pw(-2.5)]
          size = flex()
          color = IlsColor.value
          fontSize = 30
          font = Fonts.hud
          text = num.tostring()
        }
      }
      : @() {
        watch = IlsColor
        size = [pw(3), baseLineWidth * IlsLineScale.value]
        pos = [pw(48.5), 0]
        rendObj = ROBJ_SOLID
        color = IlsColor.value
      }
  }
}

function TCSF196(width, height) {
  return {
    size = [width, height]
    children = [
      tcsfAirSymbol,
      compassWrap(width, height, -0.1, generateCompassTCSFMark, 0.4, 2.0, true),
      tcsfAimMark,
      tcsfRadarAimMark,
      altWrap(width, height, generateAltMark),
      pitch(width, height, generatePitchLine),
      @() {
        watch = IlsColor
        rendObj = ROBJ_SOLID
        pos = [pw(74), (height - baseLineWidth * IlsLineScale.value) * 0.5]
        size = [pw(3), baseLineWidth * IlsLineScale.value]
        color = IlsColor.value
      }
    ]
  }
}

return TCSF196