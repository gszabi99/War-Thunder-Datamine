from "%rGui/globals/ui_library.nut" import *

enum GuidanceLockResult {
  RESULT_TRACKING = 3
}

let opticWeaponAim = @(tracker_size, tracker_x, tracker_y, guidance_lock_state, tracker_visible, color_watched) function() {
  let tSize = tracker_size.value

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
      translate = [tracker_x.value, tracker_y.value]
    }
    watch = [color_watched, guidance_lock_state, tracker_visible, tracker_size, tracker_x, tracker_y]
    rendObj = ROBJ_VECTOR_CANVAS
    size = [sh(14.0), sh(14.0)]
    color = color_watched.value
    fillColor = Color(0, 0, 0, 0)
    commands = !tracker_visible.value ? null
      : guidance_lock_state.value == GuidanceLockResult.RESULT_TRACKING ? circleTracking
      : circle
  }
}

return opticWeaponAim