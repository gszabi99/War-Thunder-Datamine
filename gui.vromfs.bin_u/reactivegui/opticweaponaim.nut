from "%rGui/globals/ui_library.nut" import *
let { GuidanceLockResult } = require("guidanceConstants")
let { HudColor } = require("%rGui/airState.nut")






let cornersLinesCommands = function(width, height, cornerScale = 0.28) {
  let w = 0.5 * width
  let h = 0.5 * height
  let lX = width * cornerScale
  let lY = height * cornerScale
  return [
    [VECTOR_LINE, -w, h, -w + lX, h],   
    [VECTOR_LINE, -w, h, -w, h - lY],

    [VECTOR_LINE, w, h, w - lX, h],   
    [VECTOR_LINE, w, h, w, h - lY],

    [VECTOR_LINE, -w, -h, -w + lX, -h],   
    [VECTOR_LINE, -w, -h, -w, -h + lY],

    [VECTOR_LINE, w, -h, w - lX, -h],   
    [VECTOR_LINE, w, -h, w, -h + lY],
  ]
}

let cornersLines = @(width, height, colorTracker, cornerScale = 0.28) function() {
  return {
    lineWidth = hdpx(LINE_WIDTH * 1.75)
    size = const [sw(100), sh(100)]
    rendObj = ROBJ_VECTOR_CANVAS
    fillColor = Color(0, 0, 0, 0)
    color = colorTracker
    commands = cornersLinesCommands(width, height, cornerScale)
  }
}



let opticWeaponAim = @(
  TrackerSize, TrackerX, TrackerY, GuidanceLockState, GuidanceLockStateBlinked, TrackerVisible, IsAntiRadiation,
  TrackedTargetName, IsTrackerLoosingIcon,
  color_watched, alert_color_watched, show_tps_sight, IsPointTrack,
)
function() {
  let aimTracker = @() function() {
    if (!TrackerVisible.get())
      return {
        watch = TrackerVisible
      }

    let minMarkWidth = hdpx(20) / sw(1);
    local width = TrackerSize.get() / sw(1)
    local height = TrackerSize.get() / sh(1)

    if (width < minMarkWidth) {
      height = minMarkWidth / sh(1) * sw(1)
      width = minMarkWidth
    }

    let squareMark = IsTrackerLoosingIcon.get() ? cornersLinesCommands(width, height) :
       [[VECTOR_RECTANGLE, -width * 0.5, -height * 0.5, width, height],]
    let trackingMark = [
      [VECTOR_RECTANGLE, -0.5 * width, -0.5 * height, width, height],
      [VECTOR_LINE, 0, -0.165 * height, 0, -0.5*height],
      [VECTOR_LINE, 0, 0.165 * height, 0, 0.5*height],
      [VECTOR_LINE, -0.165 * width, 0, -0.5*width, 0],
      [VECTOR_LINE, 0.165 * width, 0, 0.5*width, 0]
    ]

    let colorTracker = IsAntiRadiation.get() ? HudColor.get() : color_watched.get()
    let gs = GuidanceLockState.get()
    let gsb = GuidanceLockStateBlinked.get()

    let isTrack = (gs == GuidanceLockResult.RESULT_TRACKING)
    let hasSquare = show_tps_sight && (gs == GuidanceLockResult.RESULT_WARMING_UP || gs == GuidanceLockResult.RESULT_LOCKING
      || gs == GuidanceLockResult.RESULT_LOCK_AFTER_LAUNCH)
    let isSquareBlink = (gsb != gs && gsb == GuidanceLockResult.RESULT_INVALID)

    return {
      halign = ALIGN_LEFT
      valign = ALIGN_TOP
      size = const [sw(100), sh(100)]
      pos = [TrackerX.get(), TrackerY.get()]

      watch = [color_watched, alert_color_watched, HudColor, GuidanceLockState, GuidanceLockStateBlinked, TrackerVisible, TrackerSize, TrackerX, TrackerY, TrackedTargetName,
         IsAntiRadiation, IsTrackerLoosingIcon]
      rendObj = ROBJ_VECTOR_CANVAS
      color = colorTracker
      fillColor = Color(0, 0, 0, 0)
      lineWidth = hdpx(LINE_WIDTH * 0.25)
      commands = isTrack ? (IsPointTrack.get() ? squareMark : trackingMark) : (hasSquare && !isSquareBlink ? squareMark : null)
      children = [
        {
          children = (!IsAntiRadiation.get() && !isTrack && show_tps_sight) ? [cornersLines(3 * width, 3 * height, colorTracker)] : null
        }
        {
          pos = [0, 0 - height * sh(0.5) - hdpx(20)]
          halign = ALIGN_CENTER
          size = [0, SIZE_TO_CONTENT]
          children = {
            rendObj = ROBJ_TEXT
            text = TrackedTargetName.get() != "" ? loc($"{TrackedTargetName.get()}_1") : ""
            color = colorTracker
            font = Fonts.hud
            fontSize = hdpx(20)
          }
        }
      ]
    }
  }


  return {
    children = [
      aimTracker()
    ]
  }
}



let opticWeaponSight = @(
  SightSize, SightX, SightY, SightVisible,
  GuidanceLockState, show_tps_sight,
)
function() {
  let sightTracker = @() function() {
    if (!SightVisible.get())
      return {
        watch = SightVisible
      }

    let colorSight = HudColor.get()
    let gs = GuidanceLockState.get()
    let isTrack = (gs == GuidanceLockResult.RESULT_TRACKING)

    let isSightVisible = !isTrack && show_tps_sight
    local sightWidth = SightSize.get() / sw(1)
    local sightHeight = SightSize.get() / sh(1)

    return {
      watch = [HudColor, GuidanceLockState, SightSize, SightX, SightY, SightVisible]
      children = [
        {
          halign = ALIGN_LEFT
          valign = ALIGN_TOP
          size = const [sw(100), sh(100)]
          pos = [SightX.get(), SightY.get()]
          rendObj = ROBJ_VECTOR_CANVAS
          color = colorSight
          fillColor = Color(0, 0, 0, 0)
          lineWidth = hdpx(LINE_WIDTH * 0.25)
          children = isSightVisible ? [cornersLines(sightWidth, sightHeight, colorSight, 0.056)] : null
        }
      ]
    }
  }

  return {
    children = [
      sightTracker()
    ]
  }
}

return {
  opticWeaponAim
  opticWeaponSight
}
