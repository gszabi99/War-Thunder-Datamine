from "%rGui/globals/ui_library.nut" import *

let { GuidanceLockResult } = require("guidanceConstants")


//  __   __
// |       |
//
// |__   __|
//
let cornersLines = @(tSize, colorTracker) function() {
  let ss = tSize * 3.0
  let k = 0.28 * ss
  let o = tSize * 1.5
  return {
    lineWidth = hdpx(LINE_WIDTH * 1.75)
    size = [1, 1]
    rendObj = ROBJ_VECTOR_CANVAS
    fillColor = Color(0, 0, 0, 0)
    color = colorTracker
    commands = [
      [VECTOR_LINE, 0 - o, 0 - o, k - o, 0 - o],
      [VECTOR_LINE, 0 - o, 0 - o, 0 - o, k - o],
      [VECTOR_LINE, ss - o, 0 - o, ss - k - o, 0 - o],
      [VECTOR_LINE, ss - o, 0 - o, ss - o, k - o],

      [VECTOR_LINE, 0 - o, ss - o, k - o, ss - o],
      [VECTOR_LINE, 0 - o, ss - o, 0 - o, ss - k - o],
      [VECTOR_LINE, ss - o, ss - o, ss - k - o, ss - o],
      [VECTOR_LINE, ss - o, ss - o, ss - o, ss - k - o],
    ]
  }
}


// main agm/guidedBombs sight
let opticWeaponAim = @(
  TrackerSize, TrackerX, TrackerY, GuidanceLockState, GuidanceLockStateBlinked, TrackerVisible,
  color_watched, alert_color_watched, show_tps_sight
)
function() {
  let aimTracker = @() function() {
    if (!TrackerVisible.value)
      return {
        watch = TrackerVisible
      }

    let minMarkSize = hdpx(1100);
    let tSize = TrackerSize.value < minMarkSize ? minMarkSize : TrackerSize.value

    let ss = tSize * 0.5
    let squareMark = [
      [VECTOR_RECTANGLE, -ss, -ss, 2.0 * ss, 2.0 * ss],
    ]

    let trackingMark = [
      [VECTOR_RECTANGLE, -tSize, -tSize, 2.0 * tSize, 2.0 * tSize],
      [VECTOR_LINE, 0, -0.33 * tSize, 0, -tSize],
      [VECTOR_LINE, 0, 0.33 * tSize, 0, tSize],
      [VECTOR_LINE, -0.33 * tSize, 0, -tSize, 0],
      [VECTOR_LINE, 0.33 * tSize, 0, tSize, 0]
    ]

    let colorTracker = color_watched.value
    let gs = GuidanceLockState.get()
    let gsb = GuidanceLockStateBlinked.get()

    let isTrack = (gs == GuidanceLockResult.RESULT_TRACKING)
    let hasSquare = show_tps_sight && (gs == GuidanceLockResult.RESULT_WARMING_UP || gs == GuidanceLockResult.RESULT_LOCKING
      || gs == GuidanceLockResult.RESULT_LOCK_AFTER_LAUNCH)
    let isSquareBlink = (gsb != gs && gsb == GuidanceLockResult.RESULT_INVALID)

    return {
      halign = ALIGN_LEFT
      valign = ALIGN_TOP
      size = [1, 1]
      pos = [TrackerX.value, TrackerY.value]

      watch = [color_watched, alert_color_watched, GuidanceLockState, GuidanceLockStateBlinked, TrackerVisible, TrackerSize, TrackerX, TrackerY]
      rendObj = ROBJ_VECTOR_CANVAS
      color = colorTracker
      fillColor = Color(0, 0, 0, 0)
      lineWidth = hdpx(LINE_WIDTH * 0.25)
      commands = isTrack ? (trackingMark) : (hasSquare && !isSquareBlink ? squareMark : null)
      children = (!isTrack && show_tps_sight) ? [cornersLines(tSize, colorTracker)] : null
    }
  }


  return {
    children = [
      aimTracker()
    ]
  }
}

return opticWeaponAim