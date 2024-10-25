from "%rGui/globals/ui_library.nut" import *
from "%globalScripts/logs.nut" import logerr

let { GuidanceLockResult } = require("guidanceConstants")


//  __   __
// |       |
//
// |__   __|
//
let cornersLines = @(width, height, colorTracker) function() {
  let w = 1.5 * width
  let h = 1.5 * height
  let lX = width * 0.84
  let lY = height * 0.84

  return {
    lineWidth = hdpx(LINE_WIDTH * 1.75)
    size = [sw(100), sh(100)]
    rendObj = ROBJ_VECTOR_CANVAS
    fillColor = Color(0, 0, 0, 0)
    color = colorTracker
    commands = [
      [VECTOR_LINE, -w, h, -w + lX, h],   // left bottom
      [VECTOR_LINE, 0- w, h, -w, h - lY],

      [VECTOR_LINE, w, h, w - lX, h],   // right bottom
      [VECTOR_LINE, w, h, w, h - lY],

      [VECTOR_LINE, -w, -h, -w + lX, -h],   // left top
      [VECTOR_LINE, -w, -h, -w, -h + lY],

      [VECTOR_LINE, w, -h, w - lX, -h],   // right top
      [VECTOR_LINE, w, -h, w, -h + lY],
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

    let minMarkWidth = hdpx(20) / sw(1);
    local width = TrackerSize.value / sw(1)
    local height = TrackerSize.value / sh(1)

    if (width < minMarkWidth) {
      height = minMarkWidth / sh(1) * sw(1)
      width = minMarkWidth
    }

    let squareMark = [
      [VECTOR_RECTANGLE, -width * 0.5, -height * 0.5, width, height],
    ]

    let trackingMark = [
      [VECTOR_RECTANGLE, -0.5 * width, -0.5 * height, width, height],
      [VECTOR_LINE, 0, -0.165 * height, 0, -0.5*height],
      [VECTOR_LINE, 0, 0.165 * height, 0, 0.5*height],
      [VECTOR_LINE, -0.165 * width, 0, -0.5*width, 0],
      [VECTOR_LINE, 0.165 * width, 0, 0.5*width, 0]
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
      size = [sw(100), sh(100)]
      pos = [TrackerX.value, TrackerY.value]

      watch = [color_watched, alert_color_watched, GuidanceLockState, GuidanceLockStateBlinked, TrackerVisible, TrackerSize, TrackerX, TrackerY]
      rendObj = ROBJ_VECTOR_CANVAS
      color = colorTracker
      fillColor = Color(0, 0, 0, 0)
      lineWidth = hdpx(LINE_WIDTH * 0.25)
      commands = isTrack ? (trackingMark) : (hasSquare && !isSquareBlink ? squareMark : null)
      children = (!isTrack && show_tps_sight) ? [cornersLines(width, height, colorTracker)] : null
    }
  }


  return {
    children = [
      aimTracker()
    ]
  }
}

return opticWeaponAim