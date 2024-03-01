from "%rGui/globals/ui_library.nut" import *

let { hudFontHgt, fontOutlineColor, fontOutlineFxFactor } = require("style/airHudStyle.nut")
let { fabs } = require("math")
let { CompassValue } = require("compassState.nut")
let { LwsDirections } = require("lwsState.nut")
let { aircraftsPositionsMessage } = require("aircraftVoiceMessagesState.nut")

let styleLineForeground = {
  fillColor = Color(0, 0, 0, 0)
  lineWidth = hdpx(LINE_WIDTH)
  font = Fonts.hud
  fontFxColor = fontOutlineColor
  fontFxFactor = fontOutlineFxFactor
  fontFx = FFT_GLOW
  fontSize = hudFontHgt
}

let imageSize = [evenPx(28), evenPx(26)]

function generateCompassNumber(line_style, num, width, height, color) {
  return {
    size = [width, height]
    flow = FLOW_VERTICAL
    children = [
      line_style.__merge({
        rendObj = ROBJ_TEXT
        size = [width, 0.5 * height]
        halign = ALIGN_CENTER
        text = num
        color
      })
      line_style.__merge({
        rendObj = ROBJ_VECTOR_CANVAS
        size = [width, 0.5 * height]
        color
        commands = [
          [VECTOR_LINE, 50, 0, 50, 100]
        ]
      })
    ]
  }
}


let generateCompassDash = @(line_style, width, height, color)
  line_style.__merge({
    size = [width, height]
    rendObj = ROBJ_VECTOR_CANVAS
    color
    commands = [
      [VECTOR_LINE, 50, 70, 50, 100]
    ]
  })

function compassLine(line_style, total_width, width, height, color) {
  const step = 5.0
  let children = []

  for (local i = 0; i <= 2.0 * 360.0 / step; ++i) {

    local num = (i * step) % 360

    if (num == 0)
      num = "N"
    else if (num == 90)
      num = "E"
    else if (num == 180)
      num = "S"
    else if (num == 270)
      num = "W"
    else
      num = num.tointeger()

    children.append(generateCompassNumber(line_style, num, width, height, color))
    children.append(generateCompassDash(line_style, width, height, color))
  }

  let getOffset = @() 0.5 * (total_width - width) + CompassValue.value * width * 2.0 / step - 2.0 * 360.0 * width / step

  return {
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [getOffset(), 0]
      }
    }
    size = [SIZE_TO_CONTENT, height]
    flow = FLOW_HORIZONTAL
    children = children
  }
}

let mkLwsMark = @(lwsDirection, size, color) function(){
  let compassAngle = (CompassValue.value > 0 ? 360 : 0) - CompassValue.value

  local delta = lwsDirection - compassAngle
  let sign = (delta > 0) ? 1 : -1
  delta = fabs(delta) > 180 ? delta - sign * 360 : delta

  let offset = delta * hdpx(16)
  let halfImageSize = imageSize[0] / 2
  let posX = min(max(size[0] / 2 + offset, -halfImageSize), size[0]) - halfImageSize

  return {
    watch = CompassValue
    rendObj = ROBJ_IMAGE
    color = color
    size = imageSize
    pos = [posX, 0]
    image = Picture($"ui/gameuiskin#laser_alert_azimut.svg:{imageSize[0]}:{imageSize[1]}:P")
  }
}

let mkAircraftMark = @(aircraftDirection, size, color) function(){
  let compassAngle = (CompassValue.value > 0 ? 360 : 0) - CompassValue.value
  let step = 5.0;

  local delta = aircraftDirection - compassAngle
  let sign = (delta > 0) ? 1 : -1
  delta = fabs(delta) > 180 ? delta - sign * 360 : delta

  let offset = 2 * delta * size[1] / step
  let halfImageSize = imageSize[0] / 2
  let posX = min(max(size[0] / 2 + offset, -halfImageSize), size[0]) - halfImageSize

  return {
    watch = CompassValue
    rendObj = ROBJ_IMAGE
    color = color
    size = imageSize
    pos = [posX, 0]
    image = Picture($"ui/gameuiskin#army_fighter.svg:{imageSize[0]}:{imageSize[1]}:P")
  }
}

let lwsComponent = @(size, pos, color) function() {
  let children = []
  foreach(lwsDirection in LwsDirections.value)
    children.append(mkLwsMark(lwsDirection, size, color))

  return {
    watch = LwsDirections
    size
    pos = [0, pos]
    children = children
  }
}

let mkAircraftVoiceMessageComponent = @(size, pos, color) @() {
  watch = aircraftsPositionsMessage
  size
  pos = [0, pos]
  children = aircraftsPositionsMessage.value.map(@(v) mkAircraftMark(v, size, color))
}

let compassArrow = {
    rendObj = ROBJ_VECTOR_CANVAS
    commands = [
      [VECTOR_LINE, 0, 100, 50, 0],
      [VECTOR_LINE, 50, 0, 100, 100]
    ]
  }

function compass(elemStyle, size, color) {
  let oneElementWidth = size[1]
  return {
    size
    clipChildren = true
    children = [
      compassLine(elemStyle, size[0], oneElementWidth, size[1], color)
    ]
  }
}

function compassComponent(size, color, elemStyle = styleLineForeground) {
  let top = size[1] + hdpx(5)
  return {
    halign = ALIGN_CENTER
    gap = hdpx(5)
    children = [
      compass(elemStyle, size, color)
      elemStyle.__merge(compassArrow, { pos = [0, top], size = array(2, 0.3 * size[1]), color })
      lwsComponent(size, top, color)
      mkAircraftVoiceMessageComponent(size, top, color)
    ]
  }
}

return compassComponent
