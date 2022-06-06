let {TrackerSize, TrackerX, TrackerY, GuidanceLockState, TrackerVisible} = require("agmAimState.nut")
let {backgroundColor} = require("style/airHudStyle.nut")

enum GuidanceLockResult {
  RESULT_TRACKING = 3
}

let agmAimTracker = @(is_background, color_watched) function() {

  let tSize = TrackerSize.value

  let circleTracking =
    [
      [VECTOR_RECTANGLE, -tSize, -tSize, 2.0 * tSize, 2.0 * tSize],
      [VECTOR_LINE, 0, -0.33 * tSize, 0, -tSize],
      [VECTOR_LINE, 0 , 0.33 * tSize, 0,  tSize],
      [VECTOR_LINE, -0.33 * tSize, 0, -tSize, 0],
      [VECTOR_LINE,  0.33 * tSize, 0,  tSize, 0]
    ]

  let circle =
    [
      [VECTOR_RECTANGLE, -tSize, -tSize,
        2.0 * tSize, 2.0 * tSize]
    ]

  return {
    transform = {
      translate = [TrackerX.value, TrackerY.value]
    }
    watch = [color_watched, GuidanceLockState, TrackerVisible, TrackerSize, TrackerX, TrackerX]
    rendObj = ROBJ_VECTOR_CANVAS
    size = [sh(14.0), sh(14.0)]
    color = is_background ? backgroundColor
        : color_watched.value
    fillColor = Color(0, 0, 0, 0)
    commands = !TrackerVisible.value ? null
      : GuidanceLockState.value == GuidanceLockResult.RESULT_TRACKING ? circleTracking
      : circle
  }
}

return agmAimTracker
