local compassState = require("compassState.nut")


local generateCompassNumber = function(num, line_style, width, height, color){
  return {
    size = [width, height]
    flow = FLOW_VERTICAL
    children = [
      line_style.__merge({
        rendObj = ROBJ_STEXT
        size = [width, 0.5 * height]
        halign = ALIGN_CENTER
        text = num
        color = color
      })
      line_style.__merge({
        rendObj = ROBJ_VECTOR_CANVAS
        size = [width, 0.5 * height]
        color = color
        commands = [
          [VECTOR_LINE, 50, 0, 50, 100]
        ]
      })
    ]
  }
}


local generateCompassDash = function(line_style, width, height, color){
  return line_style.__merge({
    size = [width, height]
    rendObj = ROBJ_VECTOR_CANVAS
    color = color
    commands = [
      [VECTOR_LINE, 50, 70, 50, 100]
    ]
  })
}


local compassLine = function(line_style, total_width, width, height, color){
  const step = 5.0
  local children = []

  for (local i = 0; i <= 2.0 * 360.0 / step; ++i)
  {
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

    children.append(generateCompassNumber(num, line_style, width, height, color))
    children.append(generateCompassDash(line_style, width, height, color))
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


local compassArrow = function(line_style, height, color) {
  return line_style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [height, height]
    color = color
    commands = [
      [VECTOR_LINE, 0, 100, 50, 0],
      [VECTOR_LINE, 50, 0, 100, 100]
    ]
  })
}


local compass = function(line_style, width, height, color) {
  local oneElementWidth = height
  return {
    size = [width, height]
    clipChildren = true
    children = [
      compassLine(line_style, width, oneElementWidth, height, color)
    ]
  }
}


local compassComponent = function(elemStyle, width, height, color) {
  return {
    size = SIZE_TO_CONTENT
    flow = FLOW_VERTICAL
    halign = ALIGN_CENTER
    gap = hdpx(5)
    children = [
      compass(elemStyle, width, height, color)
      compassArrow(elemStyle, 0.3 * height, color)
    ]
  }
}


return compassComponent
