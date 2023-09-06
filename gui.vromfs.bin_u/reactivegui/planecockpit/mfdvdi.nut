from "%rGui/globals/ui_library.nut" import *

let { VdiColor } = require("%rGui/planeState/planeToolsState.nut")
let baseLineWidth = hdpx(2 * LINE_WIDTH)
let { compassWrap } = require("%rGui/planeIlses/ilsCompasses.nut")
let { Tangage, Roll } = require("%rGui/planeState/planeFlyState.nut")

local airSymbol = @() {
  watch = VdiColor
  size = flex()
  rendObj = ROBJ_VECTOR_CANVAS
  color = VdiColor.value
  fillColor = VdiColor.value
  lineWidth = baseLineWidth * 2
  commands = [
    [VECTOR_ELLIPSE, 50, 50, 1, 1],
    [VECTOR_LINE, 0, 50, 13, 50],
    [VECTOR_LINE, 32, 50, 42, 50],
    [VECTOR_LINE, 42, 50, 42, 53],
    [VECTOR_LINE, 58, 50, 68, 50],
    [VECTOR_LINE, 58, 50, 58, 53],
    [VECTOR_LINE, 87, 50, 100, 50]
  ]
}

let generateCompassMark = function(num, _elemWidth, _font) {
  return {
    size = [pw(7.5), ph(100)]
    flow = FLOW_VERTICAL
    children = [
      @() {
        watch = VdiColor
        size = [baseLineWidth * 2, baseLineWidth * ((num % 10 == 0) ? 7 : 4)]
        rendObj = ROBJ_SOLID
        color = VdiColor.value
        lineWidth = baseLineWidth
        hplace = ALIGN_CENTER
      },
      (num % 10 == 0 ? @() {
        watch = VdiColor
        rendObj = ROBJ_TEXT
        color = VdiColor.value
        hplace = ALIGN_CENTER
        fontSize = 35
        font = Fonts.usa_ils
        text = num % 10 == 0 ? (num / 10).tostring() : ""
      } : null)
    ]
  }
}

let compass = function(width, height) {
  return @() {
    size = flex()
    children = [
      compassWrap(width, height * 0.5, 0.1, generateCompassMark, 1.2, 5.0, false, 7.5),
      {
        size = [pw(1), ph(2)]
        pos = [pw(50), ph(3)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = VdiColor.value
        lineWidth = baseLineWidth
        commands = [
          [VECTOR_LINE, 0, 100, -100, 0],
          [VECTOR_LINE, 0, 100, 100, 0]
        ]
      }
    ]
  }
}

let function generatePitchLine(num, width) {
  let sign = num > 0 ? 1 : -1
  return {
    size = [pw(100), ph(100)]
    children = num == 0 ?
    [
      {
        size = [pw(400), ph(10)]
        pos = [pw(-150), 0]
        rendObj = ROBJ_SOLID
        lineWidth = baseLineWidth
        color = Color(0, 0, 0, 255)
      }
    ] :
    [
      @() {
        size = flex()
        watch = VdiColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth
        color = VdiColor.value
        commands = [
          sign > 0 && num % 30 != 0 ? [VECTOR_LINE, 25, 0, 75, 0] : [],
          sign > 0 && num % 30 == 0 ? [VECTOR_LINE, -20, 0, 35, 0] : [],
          sign > 0 && num % 30 == 0 ? [VECTOR_LINE, 65, 0, 120, 0] : [],
          sign < 0 && num % 30 != 0 ? [VECTOR_LINE_DASHED, 25, 0, 75, 0, width * 0.06, width * 0.01] : [],
          sign < 0 && num % 30 == 0 ? [VECTOR_LINE_DASHED, -20, 0, 35, 0, width * 0.10, width * 0.02] : [],
          sign < 0 && num % 30 == 0 ? [VECTOR_LINE_DASHED, 65, 0, 120, 0, width * 0.10, width * 0.02] : [],
        ]
        children = num % 30 == 0 ? [
          @() {
            watch = VdiColor
            pos = [0, ph(-25)]
            rendObj = ROBJ_TEXT
            vplace = ALIGN_TOP
            hplace = ALIGN_CENTER
            color = VdiColor.value
            fontSize = 45
            font = Fonts.usa_ils
            text = (num / 10).tostring()
          }
        ] : null
      }
    ]
  }
}

let function pitch(width, height) {
  const step = 10.0
  let children = []

  for (local i = 90.0 / step; i >= -90.0 / step; --i) {
    let num = (i * step).tointeger()

    children.append(generatePitchLine(num, width))
  }

  return {
    size = [width * 0.4, height * 0.15]
    pos = [width * 0.3, height * 0.5]
    flow = FLOW_VERTICAL
    children = children
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, -height * (90.0 - Tangage.value) * 0.015]
        rotate = -Roll.value
        pivot = [0.5, (90.0 - Tangage.value) * 0.1]
      }
    }
  }
}

let function Root(width, height, posX = 0, posY = 0) {
  return {
    pos = [posX, posY]
    size = [width, height]
    children = [
      compass(width, height)
      pitch(width, height)
      airSymbol
    ]
    clipChildren = true
  }
}

return Root