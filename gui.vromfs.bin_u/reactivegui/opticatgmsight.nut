from "%rGui/globals/ui_library.nut" import *
let { pow, ceil } = require("%sqstd/math.nut")
let { Roll } = require("planeState/planeFlyState.nut")
let { GuidanceLockResult } = require("guidanceConstants")
let { turretAngles } = require("airHudElems.nut")
let agmAimState = require("agmAimState.nut")
let gbuAimState = require("guidedBombsAimState.nut")
let { IsMfdSightHudVisible, MfdSightPosSize } = require("%rGui/airState.nut")


let opticalSight = @(width, height,
  TrackerVisible, TrackerSize, GuidanceLockState, GuidanceLockStateBlinked, PointIsTarget,
  ReleaseTargetCursorX, ReleaseTargetCursorY, LockReleaseRadiusH, LockReleaseRadiusW, MinSightFovScrSize
) function() {
  let opticColor = Color(255, 255, 255)
  let opticColorWatch = Watched(opticColor)

  let aspectX = height / width
  let pxToVec = 0.1
  let isMfdVis = IsMfdSightHudVisible.get()
  let sightSh = @(h) isMfdVis ? ceil(h * MfdSightPosSize.value[3] / 100.0) : sh(h)
  let sightSw = @(w) isMfdVis ? ceil(w * MfdSightPosSize.value[2] / 100) : sw(w)
  let sightHdpx = @(px) isMfdVis ? ceil(px * MfdSightPosSize.value[3] / 1024) : hdpx(px)
  let lineWidth = sightHdpx(LINE_WIDTH) * (isMfdVis ? 2.0 : 1.0)


  let minMarkSize = 5
  local hSize = max(TrackerSize.get(), minMarkSize) * pxToVec
  if (GuidanceLockState.get() == GuidanceLockResult.RESULT_TRACKING)
    hSize = PointIsTarget.get() ? hdpx(1) : hdpx(4)
  let hSizeX = hSize * aspectX
  let hSizeY = hSize


// Main fullscreen Сrosshair
  let fullscreenCrosshair = @() {
    watch = [ TrackerVisible ]
    size = [width, height]
    rendObj = ROBJ_VECTOR_CANVAS
    color = opticColor
    lineWidth = lineWidth * 2
    commands = [
      [VECTOR_LINE, 50, 0, 50, 50 - hSizeY],
      [VECTOR_LINE, 0, 50, 50 - hSizeX, 50],
      [VECTOR_LINE, 50 + hSizeX, 50, 100, 50],
      [VECTOR_LINE, 50, 50 + hSizeY, 50, 76],
    ]
  }


// Small FOV indication
//  __   __
// |       |
//
// |__   __|
//
  let fovSquareBracketsCommands = function() {
    if (MinSightFovScrSize.get() <= 0)
      return null
    let gs = GuidanceLockStateBlinked.get()
    if (gs == GuidanceLockResult.RESULT_TRACKING)
      return null
    let sx = MinSightFovScrSize.get() * pxToVec
    let sy = MinSightFovScrSize.get() * pxToVec

    let kx = 0.28 * sx * aspectX
    let ky = 0.28 * sy
    let ox = 50 - sx * 0.5
    let oy = 50 - sy * 0.5
    return [
      [VECTOR_LINE, ox, oy, ox + kx, oy],
      [VECTOR_LINE, ox, oy, ox, oy + ky],
      [VECTOR_LINE, ox + sx, oy, ox + sx - kx, oy],
      [VECTOR_LINE, ox + sx, oy, ox + sx, oy + ky],

      [VECTOR_LINE, ox, oy + sy, ox + kx, oy + sy],
      [VECTOR_LINE, ox, oy + sy, ox, oy + sy - ky],
      [VECTOR_LINE, ox + sx, oy + sy, ox + sx - kx, oy + sy],
      [VECTOR_LINE, ox + sx, oy + sy, ox + sx, oy + sy - ky],
    ]
  }

  let fovLimits = @() {
    watch = [ MinSightFovScrSize, GuidanceLockStateBlinked ]
    size = [width, height]
    rendObj = ROBJ_VECTOR_CANVAS
    color = opticColor
    fillColor = 0
    lineWidth = lineWidth * 0.5
    commands = fovSquareBracketsCommands()
  }


  // left lower corner
  let rollIndicator = @() {
    size = [ph(15), ph(15)]
    pos = [0, ph(85)]
    children = [
      {
        size = flex()
        rendObj = ROBJ_SOLID
        color = Color(0, 0, 0)
      },
      @() {
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        color = opticColor
        fillColor = Color(0, 0, 0)
        lineWidth = lineWidth * 3
        commands = [
          [VECTOR_SECTOR, 50, 50, 42, 42, 0, 180],
          [VECTOR_LINE, 1, 50, 8, 50],
          [VECTOR_LINE, 92, 50, 99, 50]
        ]
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            rotate = -Roll.value.tointeger()
            pivot = [0.5, 0.5]
          }
        }
      },
      {
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        color = opticColor
        fillColor = Color(0, 0, 0)
        lineWidth = lineWidth * 3
        commands = [
          [VECTOR_ELLIPSE, 50, 50, 5, 5],
          [VECTOR_LINE, 15, 50, 45, 50],
          [VECTOR_LINE, 55, 50, 85, 50],
          [VECTOR_LINE, 50, 45, 50, 35]
        ]
      }
    ]
  }


  let isLockReleaseAreaVisible = Computed(@() GuidanceLockState.get() == GuidanceLockResult.RESULT_TRACKING)

  let cursorOutAreaPosPercent = Computed(function() {
    let sqrW = @(val) val.get() * val.get()
    let sqRadUnsafe = LockReleaseRadiusW.get() * LockReleaseRadiusH.get();
    let sqRad = sqRadUnsafe > 0 ? sqRadUnsafe : 1;
    let d = ((sqrW(ReleaseTargetCursorX) + sqrW(ReleaseTargetCursorX)) / sqRad);
    return pow(d, 0.5)
  })

  let releaseTargetLockArea = @() {
    watch = [isLockReleaseAreaVisible, ReleaseTargetCursorX, ReleaseTargetCursorY, LockReleaseRadiusW, LockReleaseRadiusH]
    size = [LockReleaseRadiusW.get() * 2.0, LockReleaseRadiusH.get() * 2.0]
    rendObj = ROBJ_VECTOR_CANVAS
    color = opticColor
    opacity = 1.0 - 0.7 * cursorOutAreaPosPercent.get()
    lineWidth = lineWidth * 2
    fillColor = 0
    pos = [sw(50), sh(50)]
    commands = isLockReleaseAreaVisible.get() ? [[VECTOR_RECTANGLE, -50, -50, 100, 100]] : null
  }

  let releaseTargetLockCursor = @() {
    watch = [ReleaseTargetCursorX, ReleaseTargetCursorY, isLockReleaseAreaVisible ]
    size = [ph(1), ph(1)]
    rendObj = ROBJ_VECTOR_CANVAS
    color = opticColor
    lineWidth = lineWidth
    pos = [
      sw(50) + ReleaseTargetCursorX.get(), sh(50) + ReleaseTargetCursorY.get()
    ]
    commands = isLockReleaseAreaVisible.get() ? [[VECTOR_LINE, -100, 0, 100, 0], [VECTOR_LINE, 0, -100, 0, 100]] : null
  }

  return {
    pos = [0, 0]
    size = [width, height]
    watch = [TrackerVisible]
    children = [fullscreenCrosshair, rollIndicator, releaseTargetLockArea, releaseTargetLockCursor, fovLimits,
      turretAngles(opticColorWatch, sightHdpx(150), sightHdpx(150), sightSw(50), sightSh(90))
    ]
  }
}


function Root(width, height, posX = 0, posY = 0) {
  return @() {
    pos = [posX, posY]
    size = [width, height]
    watch = [agmAimState.TrackerVisible, gbuAimState.TrackerVisible, agmAimState.GuidanceLockState, gbuAimState.GuidanceLockState]

    children = (agmAimState.TrackerVisible.get() || gbuAimState.GuidanceLockState.get() == GuidanceLockResult.RESULT_INVALID) ? [
      opticalSight(width, height,
        agmAimState.TrackerVisible, agmAimState.TrackerSize, agmAimState.GuidanceLockState,
        agmAimState.GuidanceLockStateBlinked, agmAimState.PointIsTarget, agmAimState.ReleaseTargetCursorX,
        agmAimState.ReleaseTargetCursorY, agmAimState.LockReleaseRadiusH, agmAimState.LockReleaseRadiusW,
        agmAimState.MinSightFovScrSize
      )] : [
      opticalSight(width, height,
        gbuAimState.TrackerVisible, gbuAimState.TrackerSize, gbuAimState.GuidanceLockState,
        gbuAimState.GuidanceLockStateBlinked, gbuAimState.PointIsTarget, gbuAimState.ReleaseTargetCursorX,
        gbuAimState.ReleaseTargetCursorY, gbuAimState.LockReleaseRadiusH, gbuAimState.LockReleaseRadiusW,
        gbuAimState.MinSightFovScrSize
      )]
  }
}
return Root