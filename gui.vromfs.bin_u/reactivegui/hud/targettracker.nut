local { round } = require("std/math.nut")
local {
  HasTargetTracker,
  IsSightLocked,
  IsTargetTracked,
  AimCorrectionEnabled,
  TargetRadius,
  TargetAge,
  TargetX,
  TargetY } = require("reactiveGui/hud/targetTrackerState.nut")


local hl = 20
local vl = 20

local lockSight = function(line_style, color, width, height) {
  return @() line_style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [width, height]
    watch = [IsSightLocked, IsTargetTracked]
    color = color
    commands = IsSightLocked.value && !IsTargetTracked.value
      ? [
          [VECTOR_LINE, 0, 0, hl, vl],
          [VECTOR_LINE, 0, 100, vl, 100 - vl],
          [VECTOR_LINE, 100, 100, 100 - hl, 100 - vl],
          [VECTOR_LINE, 100, 0, 100 - hl, vl]
        ]
      : []
  })
}

local lockSightComponent = function(line_style, color, width, height, posX, posY) {
  return @() {
    pos = [posX - width * 0.5, posY - height * 0.5]
    size = SIZE_TO_CONTENT
    children = lockSight(line_style, color, width, height)
  }
}


local targetSize = function(line_style, width, height, is_static_pos) {
  local hd = 5
  local vd = 5
  local posX = is_static_pos ? 50 : (TargetX.value / sw(100) * 100)
  local posY = is_static_pos ? 50 : (TargetY.value / sh(100) * 100)

  local getAimCorrectionCommands = function(target_radius) {
    return [
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
  }

  local getTargetTrackedCommands = function(target_radius) {
    return [
      [
        VECTOR_RECTANGLE,
        posX - target_radius / width * 100,
        posY - target_radius / height * 100,
        2.0 * target_radius / width * 100,
        2.0 * target_radius / height * 100
      ]
    ]
  }

  local getTargetUntrackedCommands = function(target_radius) {
    return [
      [
        VECTOR_LINE,
        posX - target_radius / width * 100,
        posY - target_radius / height * 100,
        posX - (target_radius - hd) / width * 100,
        posY - target_radius / height * 100
      ],
      [
        VECTOR_LINE,
        posX - target_radius / width * 100,
        posY - target_radius / height * 100,
        posX - target_radius / width * 100,
        posY - (target_radius - vd) / height * 100
      ],
      [
        VECTOR_LINE,
        posX + target_radius / width * 100,
        posY - target_radius / height * 100,
        posX + (target_radius - hd) / width * 100,
        posY - target_radius / height * 100
      ],
      [
        VECTOR_LINE,
        posX + target_radius / width * 100,
        posY - target_radius / height * 100,
        posX + target_radius / width * 100,
        posY - (target_radius - vd) / height * 100
      ],
      [
        VECTOR_LINE,
        posX + target_radius / width * 100,
        posY + target_radius / height * 100,
        posX + (target_radius - hd) / width * 100,
        posY + target_radius / height * 100
      ],
      [
        VECTOR_LINE,
        posX + target_radius / width * 100,
        posY + target_radius / height * 100,
        posX + target_radius / width * 100,
        posY + (target_radius - vd) / height * 100],

      [
        VECTOR_LINE,
        posX - target_radius / width * 100,
        posY + target_radius / height * 100,
        posX - (target_radius - hd) / width * 100,
        posY + target_radius / height * 100
      ],
      [
        VECTOR_LINE,
        posX - target_radius / width * 100,
        posY + target_radius / height * 100,
        posX - target_radius / width * 100,
        posY + (target_radius - vd) / height * 100
      ]
    ]
  }

  return @() line_style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [width, height]
    fillColor = Color(0, 0, 0, 0)
    watch = [ IsTargetTracked, AimCorrectionEnabled, HasTargetTracker, TargetRadius ]
    commands = HasTargetTracker.value && TargetRadius.value > 0.0
      ? (IsTargetTracked.value
        ? (AimCorrectionEnabled.value
          ? getAimCorrectionCommands(TargetRadius.value)
          : getTargetTrackedCommands(TargetRadius.value))
        : getTargetUntrackedCommands(TargetRadius.value))
      : []
  })
}

local targetSizeComponent = function(
  line_style,
  width,
  height,
  is_static_pos,
  current_time) {

  return @() {
    pos = [0, 0]
    size = SIZE_TO_CONTENT
    watch = [TargetX, TargetY, current_time]
    behavior = Behaviors.RtPropUpdate
    update = function() {
      return {
        opacity = TargetAge.value < 0.2
          || round(current_time.value * 4) % 2 == 0 ? 100 : 0
      }
    }
    children = targetSize(line_style, width, height, is_static_pos)
  }
}

return {
  lockSight = lockSightComponent
  targetSize = targetSizeComponent
}
