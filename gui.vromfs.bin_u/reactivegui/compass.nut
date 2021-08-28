local {hudFontHgt, fontOutlineColor, fontOutlineFxFactor} = require("style/airHudStyle.nut")
local compassState = require("compassState.nut")

local styleLineForeground = {
  fillColor = Color(0, 0, 0, 0)
  lineWidth = hdpx(LINE_WIDTH)
  ont = Fonts.hud
  fontFxColor = fontOutlineColor
  fontFxFactor = fontOutlineFxFactor
  fontFx = FFT_GLOW
  fontSize = hudFontHgt
}

local function generateCompassNumber(num, width, height, color) {
  return {
    size = [width, height]
    flow = FLOW_VERTICAL
    children = [
      styleLineForeground.__merge({
        rendObj = ROBJ_DTEXT
        fontSize = hdpx(20)
        size = [width, 0.5 * height]
        halign = ALIGN_CENTER
        text = num
        color
      })
      styleLineForeground.__merge({
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


local generateCompassDash = @(width, height, color)
  styleLineForeground.__merge({
    size = [width, height]
    rendObj = ROBJ_VECTOR_CANVAS
    color
    commands = [
      [VECTOR_LINE, 50, 70, 50, 100]
    ]
  })


local function compassLine(total_width, width, height, color){
  const step = 5.0
  local children = []

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

    children.append(generateCompassNumber(num, width, height, color))
    children.append(generateCompassDash(width, height, color))
  }

  local getOffset = @() 0.5 * (total_width - width) + compassState.CompassValue.value * width * 2.0 / step - 2.0 * 360.0 * width / step

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


local function compassArrow(height, color) {
  return styleLineForeground.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [height, height]
    color
    commands = [
      [VECTOR_LINE, 0, 100, 50, 0],
      [VECTOR_LINE, 50, 0, 100, 100]
    ]
  })
}


local function compass(size, color) {
  local oneElementWidth = size[1]
  return {
    size
    clipChildren = true
    children = [
      compassLine(size[0], oneElementWidth, size[1], color)
    ]
  }
}


local function compassComponent(size, color) {
  return {
    flow = FLOW_VERTICAL
    halign = ALIGN_CENTER
    gap = hdpx(5)
    children = [
      compass(size, color)
      compassArrow(0.3 * size[1], color)
    ]
  }
}


return compassComponent
