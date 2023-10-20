from "%rGui/globals/ui_library.nut" import *
let { floor, round, atan2, PI } = require("%sqstd/math.nut")
let { Speed, BarAltitude, Overload, CompassValue } = require("%rGui/planeState/planeFlyState.nut")
let { mpsToKnots, metrToFeet } = require("%rGui/planeIlses/ilsConstants.nut")
let { hudFontHgt } = require("%rGui/style/airHudStyle.nut")
let string = require("string")
let { IsTwsActivated, rwrTargetsTriggers, rwrTargets } = require("%rGui/twsState.nut")
let rwrSetting = require("%rGui/rwrSetting.nut")
let { HmdYaw } = require("%rGui/planeState/planeToolsState.nut")
let { TrackerVisible, TrackerX, TrackerY, GuidanceLockState } = require("%rGui/rocketAamAimState.nut")
let { GuidanceLockResult } = require("%rGui/guidanceConstants.nut")

let baseLineWidth = floor(LINE_WIDTH + 0.5)
let baseColor = Color(30, 255, 10, 10)

let crosshair = {
  pos = [pw(50), ph(50)]
  size = [ph(2), ph(2)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = baseColor
  lineWidth = baseLineWidth
  commands = [
    [VECTOR_LINE, 20, 0, 100, 0],
    [VECTOR_LINE, -20, 0, -100, 0],
    [VECTOR_LINE, 0, 20, 0, 100],
    [VECTOR_LINE, 0, -20, 0, -100]
  ]
}

let SpeedValue = Computed(@() round(Speed.value * mpsToKnots).tointeger())
let speedVal = @() {
  size = [pw(3.5), ph(2.3)]
  pos = [pw(38), ph(49)]
  halign = ALIGN_RIGHT
  children = [
    {
      size = flex()
      rendObj = ROBJ_VECTOR_CANVAS
      color = baseColor
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth
      commands = [
        [VECTOR_RECTANGLE, 0, 0, 100, 100]
      ]
    },
    @() {
      watch = SpeedValue
      size = SIZE_TO_CONTENT
      padding = [0, 5]
      rendObj = ROBJ_TEXT
      color = baseColor
      fontSize = hudFontHgt * 1.2
      text = SpeedValue.value.tostring()
    }
  ]
}

let BarAltitudeValue = Computed(@() (BarAltitude.value * metrToFeet).tointeger())
let AltVal = @() {
  size = [pw(5), ph(2.3)]
  pos = [pw(60), ph(49)]
  halign = ALIGN_RIGHT
  children = [
    {
      size = flex()
      rendObj = ROBJ_VECTOR_CANVAS
      color = baseColor
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth
      commands = [
        [VECTOR_RECTANGLE, 0, 0, 100, 100]
      ]
    },
    @() {
      watch = BarAltitudeValue
      size = SIZE_TO_CONTENT
      padding = [0, 5]
      rendObj = ROBJ_TEXT
      color = baseColor
      fontSize = hudFontHgt * 1.2
      text = BarAltitudeValue.value < 1000 ? string.format(",%03d", BarAltitudeValue.value % 1000) : string.format("%d,%03d", BarAltitudeValue.value / 1000, BarAltitudeValue.value % 1000)
    }
  ]
}

let armLabel = {
  size = flex()
  pos = [pw(41), ph(55)]
  rendObj = ROBJ_TEXT
  color = baseColor
  fontSize = hudFontHgt * 1.2
  text = "ARM"
}

let OverloadWatch = Computed(@() (floor(Overload.value * 10)).tointeger())
let overload = @() {
  watch = OverloadWatch
  size = flex()
  pos = [pw(41), ph(45)]
  rendObj = ROBJ_TEXT
  color = baseColor
  fontSize = hudFontHgt * 1.2
  text = string.format("%.1f", OverloadWatch.value / 10.0)
}

let rwr = @() {
  watch = IsTwsActivated
  size = [ph(7), ph(7)]
  pos = [pw(38), ph(35)]
  children = IsTwsActivated.value ? [
    @() {
      watch = rwrTargetsTriggers
      size = flex()
      children = [
        {
          rendObj = ROBJ_VECTOR_CANVAS
          color = baseColor
          size = flex()
          lineWidth = baseLineWidth
          fillColor = Color(0, 0, 0, 0)
          commands = [
            [VECTOR_SECTOR, 50, 50, 35, 35, 10, 350]
          ]
          behavior = Behaviors.RtPropUpdate
          update = @() {
            transform = {
              rotate = HmdYaw.value - 90.0
            }
          }
        }
        {
          rendObj = ROBJ_TEXT
          size = flex()
          color = baseColor
          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
          fontSize = hudFontHgt * 1.2
          text = rwrTargets[0].groupId >= 0 && rwrTargets[0].groupId < rwrSetting.value.direction.len() ? rwrSetting.value.direction[rwrTargets[0].groupId].text : "?"
        }
        {
          size = flex()
          rendObj = ROBJ_VECTOR_CANVAS
          color = baseColor
          lineWidth = baseLineWidth
          fillColor = Color(0,0,0,0)
          commands = [
            [VECTOR_POLY, 42.5, 7.5, 50, 0, 58.5, 7.55, 50, 15]
          ]
          behavior = Behaviors.RtPropUpdate
          update = @() {
            transform = {
              pivot = [0.5, 0.5]
              rotate = atan2(rwrTargets[0].y, rwrTargets[0].x) * (180.0 / PI) + 90
            }
          }
        }
      ]
    }
  ] : null
}

let generateCompassMark = function(num, width) {
  return {
    size = [width * 0.15, ph(100)]
    flow = FLOW_VERTICAL
    children = [
      {
        size = [baseLineWidth * 0.8, baseLineWidth * (num % 10 == 0 ? 6 : 4)]
        rendObj = ROBJ_SOLID
        color = baseColor
        lineWidth = baseLineWidth
        hplace = ALIGN_CENTER
      }
      {
        size = SIZE_TO_CONTENT
        rendObj = ROBJ_TEXT
        color = baseColor
        hplace = ALIGN_CENTER
        fontSize = hudFontHgt * 1.2
        font = Fonts.hud
        text = num % 10 == 0 ? (num / 10).tostring() : ""
      }
    ]
  }
}

let function compass(width, generateFunc) {
  let children = []
  let step = 5.0

  for (local i = 0; i <= 2.0 * 360.0 / step; ++i) {

    let num = (i * step) % 360

    children.append(generateFunc(num, width))
  }
  let getOffset = @() (360.0 + CompassValue.value + HmdYaw.value) * 0.03 * width
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

let function compassWrap(width, height, generateFunc) {
  return {
    size = [width * 0.2, height]
    pos = [width * 0.4, height * 0.65]
    clipChildren = true
    children = [
      compass(width * 0.2, generateFunc)
    ]
  }
}

let CompassInt = Computed(@() ((360.0 + CompassValue.value + HmdYaw.value) % 360.0).tointeger())
let compassVal = {
  size = [pw(4), ph(3)]
  pos = [pw(48), ph(66)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = baseColor
  lineWidth = baseLineWidth
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
      color = baseColor
      lineWidth = baseLineWidth
      font = Fonts.hud
      fontSize = hudFontHgt * 1.4
      text = CompassInt.value.tostring()
    }
  ]
}

let isAAMMode = Computed(@() GuidanceLockState.value > GuidanceLockResult.RESULT_STANDBY)
let AamCancel = Computed(@() TrackerX.value < sw(37) || TrackerX.value > sw(65) || TrackerY.value < sh(35) || TrackerY.value > sh(70))
let function aamReticle(width, height) {
  return @() {
    watch = isAAMMode
    size = [ph(1.2), ph(1.2)]
    children = isAAMMode.value ? [
      {
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        color = baseColor
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth
        commands = [
          [VECTOR_POLY, -100, 0, 0, -100, 100, 0, 0, 100]
        ]
      }
      @(){
        watch = AamCancel
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        color = baseColor
        lineWidth = baseLineWidth
        commands = AamCancel.value ? [
          [VECTOR_LINE, -100, -100, 100, 100],
          [VECTOR_LINE, -100, 100, 100, -100]
        ] : []
      }
    ] : null
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = TrackerVisible.value ? [clamp(TrackerX.value, 0.37 * width, 0.63 * width), clamp(TrackerY.value, 0.35 * height, 0.7 * height)] : [width * 0.5, height * 0.5]
      }
    }
  }
}

let function hmd(width, height) {
  return {
    size = [width, height]
    children = [
      crosshair
      speedVal
      AltVal
      armLabel
      overload
      rwr
      compassWrap(width, height, generateCompassMark)
      compassVal
      aamReticle(width, height)
    ]
  }
}

return hmd