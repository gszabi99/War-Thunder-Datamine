from "%rGui/globals/ui_library.nut" import *

let {
  HasTargetTracker,
  IsSightLocked,
  IsTargetTracked,
  AimCorrectionEnabled,
  TargetRadius,
  TargetAge,
  TargetX,
  TargetY } = require("%rGui/hud/targetTrackerState.nut")


let hl = 20
let vl = 20

let styleLineForeground = {
  fillColor = Color(0, 0, 0, 0)
  lineWidth = hdpx(LINE_WIDTH)
}


function lockSight(colorWatched, width, height, _posX, _posY) {
  return @() styleLineForeground.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [width, height]
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
    color = colorWatched.value
    watch = [IsSightLocked, IsTargetTracked, colorWatched]
    commands = IsSightLocked.value && !IsTargetTracked.value
      ? [
          [VECTOR_LINE, 0, 0, hl, vl],
          [VECTOR_LINE, 0, 100, vl, 100 - vl],
          [VECTOR_LINE, 100, 100, 100 - hl, 100 - vl],
          [VECTOR_LINE, 100, 0, 100 - hl, vl]
        ]
      : null
  })
}

let targetSize = @(colorWatched, width, height, is_static_pos) function() {
  let hd = 5
  let vd = 5
  let posX = is_static_pos ? 50 : (TargetX.value / sw(100) * 100)
  let posY = is_static_pos ? 50 : (TargetY.value / sh(100) * 100)

  let target_radius = TargetRadius.value

  let getAimCorrectionCommands = [
      [
        VECTOR_RECTANGLE,
        posX - target_radius / width * 100,
        posY - target_radius / height * 100,
        2.0 * target_radius / width * 100,
        2.0 * target_radius / height * 100
      ],
      [
        VECTOR_ELLIPSE,
        50,
        50,
        target_radius / width * 100,
        target_radius / height * 100
      ]
    ]

  let getTargetTrackedCommands = [
      [
        VECTOR_RECTANGLE,
        posX - target_radius / width * 100,
        posY - target_radius / height * 100,
        2.0 * target_radius / width * 100,
        2.0 * target_radius / height * 100
      ]
    ]

  let getTargetUntrackedCommands = [
      [
        VECTOR_LINE,
        50 - target_radius / width * 100,
        50 - target_radius / height * 100,
        50 - (target_radius - hd) / width * 100,
        50 - target_radius / height * 100
      ],
      [
        VECTOR_LINE,
        50 - target_radius / width * 100,
        50 - target_radius / height * 100,
        50 - target_radius / width * 100,
        50 - (target_radius - vd) / height * 100
      ],
      [
        VECTOR_LINE,
        50 + target_radius / width * 100,
        50 - target_radius / height * 100,
        50 + (target_radius - hd) / width * 100,
        50 - target_radius / height * 100
      ],
      [
        VECTOR_LINE,
        50 + target_radius / width * 100,
        50 - target_radius / height * 100,
        50 + target_radius / width * 100,
        50 - (target_radius - vd) / height * 100
      ],
      [
        VECTOR_LINE,
        50 + target_radius / width * 100,
        50 + target_radius / height * 100,
        50 + (target_radius - hd) / width * 100,
        50 + target_radius / height * 100
      ],
      [
        VECTOR_LINE,
        50 + target_radius / width * 100,
        50 + target_radius / height * 100,
        50 + target_radius / width * 100,
        50 + (target_radius - vd) / height * 100],

      [
        VECTOR_LINE,
        50 - target_radius / width * 100,
        50 + target_radius / height * 100,
        50 - (target_radius - hd) / width * 100,
        50 + target_radius / height * 100
      ],
      [
        VECTOR_LINE,
        50 - target_radius / width * 100,
        50 + target_radius / height * 100,
        50 - target_radius / width * 100,
        50 + (target_radius - vd) / height * 100
      ]
    ]

  return styleLineForeground.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    color = colorWatched.value
    size = [width, height]
    fillColor = Color(0, 0, 0, 0)
    watch = [ IsTargetTracked, AimCorrectionEnabled, HasTargetTracker, TargetRadius, TargetX, TargetY, colorWatched ]
    commands = !HasTargetTracker.value || TargetRadius.value <= 0.0 ? null
      : !IsTargetTracked.value ? getTargetUntrackedCommands
      : AimCorrectionEnabled.value ? getAimCorrectionCommands
      : getTargetTrackedCommands
  })
}

let targetSizeTrigger = {}
TargetAge.subscribe(@(v) v >= 0.2 ? anim_start(targetSizeTrigger) : anim_request_stop(targetSizeTrigger))

function targetSizeComponent(
  colorWatched,
  width,
  height,
  is_static_pos) {

  return @() {
    pos = [0, 0]
    size = SIZE_TO_CONTENT
    watch = [TargetX, TargetY]
    animations = [{ prop = AnimProp.opacity, from = 0, to = 1, duration = 0.5, play = TargetAge.value >= 0.2, loop = true, easing = InOutSine, trigger = targetSizeTrigger }]
    children = targetSize(colorWatched, width, height, is_static_pos)
  }
}

return {
  lockSight
  targetSize = targetSizeComponent
}
