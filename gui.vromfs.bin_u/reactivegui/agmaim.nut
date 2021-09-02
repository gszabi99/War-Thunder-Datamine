local agmAimState = require("agmAimState.nut")

enum GuidanceLockResult {
  RESULT_TRACKING = 3
}

local agmAimTracker = function(line_style, color_func) {
  local circle = @() line_style.__merge({
      rendObj = ROBJ_VECTOR_CANVAS
      size = [sh(14.0), sh(14.0)]
      color = color_func()
      fillColor = Color(0, 0, 0, 0)
      commands = agmAimState.GuidanceLockState.value == GuidanceLockResult.RESULT_TRACKING ? [
        [VECTOR_RECTANGLE, -agmAimState.TrackerSize.value, -agmAimState.TrackerSize.value,
          2.0 * agmAimState.TrackerSize.value, 2.0 * agmAimState.TrackerSize.value],
        [VECTOR_LINE, 0, -0.33 * agmAimState.TrackerSize.value, 0, -agmAimState.TrackerSize.value],
        [VECTOR_LINE, 0 , 0.33 * agmAimState.TrackerSize.value, 0,  agmAimState.TrackerSize.value],
        [VECTOR_LINE, -0.33 * agmAimState.TrackerSize.value, 0, -agmAimState.TrackerSize.value, 0],
        [VECTOR_LINE,  0.33 * agmAimState.TrackerSize.value, 0,  agmAimState.TrackerSize.value, 0]
      ] :
      [
        [VECTOR_RECTANGLE, -agmAimState.TrackerSize.value, -agmAimState.TrackerSize.value,
          2.0 * agmAimState.TrackerSize.value, 2.0 * agmAimState.TrackerSize.value]
      ]
    })

  return @(){
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    size = SIZE_TO_CONTENT
    watch = [agmAimState.TrackerX, agmAimState.TrackerY, agmAimState.TrackerVisible, agmAimState.GuidanceLockState]
    transform = {
      translate = [agmAimState.TrackerX.value, agmAimState.TrackerY.value]
    }
    children = agmAimState.TrackerVisible.value ? [circle] : null
  }
}


return function(line_style, color_func) {
  return {
    children = [
      agmAimTracker(line_style, color_func)
    ]
  }
}
