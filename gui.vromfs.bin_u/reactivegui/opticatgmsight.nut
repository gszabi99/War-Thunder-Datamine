import "%rGui/agmAimState.nut" as agmAimState
import "%rGui/guidedBombsAimState.nut" as gbuAimState
from "%rGui/planeState/planeFlyState.nut" import Roll
from "%rGui/airHudElems.nut" import turretAngles, agmOutOfLaunchZoneArrow, mkAtgmLaunchZoneBlink
from "%rGui/airState.nut" import IsMfdSightHudVisible, MfdSightPosSize
from "%sqstd/math.nut" import pow, ceil
from "guidanceConstants" import GuidanceLockResult
from "%rGui/globals/ui_library.nut" import *

const blinkDuration = 0.5
const opticColor = Color(255, 255, 255)

let opticColorWatch = Watched(opticColor)
let mkLaunchZoneBlink = @() mkAtgmLaunchZoneBlink({ duration = blinkDuration })


function opticalSight(width, height,
  TrackerSize, GuidanceLockState, GuidanceLockStateBlinked, PointIsTarget,
  ReleaseTargetCursorX, ReleaseTargetCursorY, LockReleaseRadiusH, LockReleaseRadiusW, MinSightFovScrSize
) {
  let isLockReleaseAreaVisible = Computed(@() GuidanceLockState.get() == GuidanceLockResult.RESULT_TRACKING)

  let cursorOutAreaPosPercent = Computed(function() {
    let sqrW = @(val) val.get() * val.get()
    let sqRadUnsafe = LockReleaseRadiusW.get() * LockReleaseRadiusH.get();
    let sqRad = sqRadUnsafe > 0 ? sqRadUnsafe : 1;
    let d = ((sqrW(ReleaseTargetCursorX) + sqrW(ReleaseTargetCursorY)) / sqRad);
    return pow(d, 0.5)
  })

  return function() {
    let aspectX = height / width
    const pxToVec = 0.1
    let isMfdVis = IsMfdSightHudVisible.get()
    let sightSh = @(h) isMfdVis ? ceil(h * MfdSightPosSize.get()[3] / 100.0) : sh(h)
    let sightSw = @(w) isMfdVis ? ceil(w * MfdSightPosSize.get()[2] / 100) : sw(w)
    let sightHdpx = @(px) isMfdVis ? ceil(px * MfdSightPosSize.get()[3] / 1024) : hdpx(px)
    let lineWidth = sightHdpx(LINE_WIDTH) * (isMfdVis ? 2.0 : 1.0)


    const minMarkSize = 5
    local hSize = max(TrackerSize.get(), minMarkSize) * pxToVec
    if (GuidanceLockState.get() == GuidanceLockResult.RESULT_TRACKING)
      hSize = PointIsTarget.get() ? hdpx(1) : hdpx(4)
    let hSizeX = hSize * aspectX
    let hSizeY = hSize


    
    let fullscreenCrosshair = @() {
      size = [width, height]
      rendObj = ROBJ_VECTOR_CANVAS
      color = opticColor
      lineWidth = lineWidth * 2
      animations = mkLaunchZoneBlink()
      commands = [
        [VECTOR_LINE, 50, 0, 50, 50 - hSizeY],
        [VECTOR_LINE, 0, 50, 50 - hSizeX, 50],
        [VECTOR_LINE, 50 + hSizeX, 50, 100, 50],
        [VECTOR_LINE, 50, 50 + hSizeY, 50, 76],
      ]
    }


    
    
    
    
    
    
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


    
    let rollIndicator = @() {
      size = ph(15)
      pos = const [0, ph(85)]
      children = [
        {
          size = FLEX
          rendObj = ROBJ_SOLID
          color = Color(0, 0, 0)
        },
        @() {
          size = FLEX
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
              rotate = -Roll.get().tointeger()
            }
          }
        },
        {
          size = FLEX
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

    let releaseTargetLockArea = @() {
      watch = [isLockReleaseAreaVisible, ReleaseTargetCursorX, ReleaseTargetCursorY, LockReleaseRadiusW, LockReleaseRadiusH]
      size = [LockReleaseRadiusW.get() * 2.0, LockReleaseRadiusH.get() * 2.0]
      rendObj = ROBJ_VECTOR_CANVAS
      color = opticColor
      opacity = 1.0 - 0.7 * cursorOutAreaPosPercent.get()
      lineWidth = lineWidth * 2
      fillColor = 0
      animations = mkLaunchZoneBlink()
      pos = const [sw(50), sh(50)]
      commands = isLockReleaseAreaVisible.get() ? const [[VECTOR_RECTANGLE, -50, -50, 100, 100]] : null
    }

    let releaseTargetLockCursor = @() {
      watch = [ReleaseTargetCursorX, ReleaseTargetCursorY, isLockReleaseAreaVisible ]
      size = ph(1)
      rendObj = ROBJ_VECTOR_CANVAS
      color = opticColor
      lineWidth = lineWidth
      pos = [
        sw(50) + ReleaseTargetCursorX.get(), sh(50) + ReleaseTargetCursorY.get()
      ]
      commands = isLockReleaseAreaVisible.get() ? const [[VECTOR_LINE, -100, 0, 100, 0], [VECTOR_LINE, 0, -100, 0, 100]] : null
    }

    return {
      pos = const [0, 0]
      size = [width, height]
      watch = [TrackerSize, GuidanceLockState, PointIsTarget, IsMfdSightHudVisible, MfdSightPosSize]
      children = [fullscreenCrosshair, rollIndicator, releaseTargetLockArea, releaseTargetLockCursor, fovLimits,
        turretAngles(opticColorWatch, sightHdpx(150), sightHdpx(150), sightSw(50), sightSh(90), blinkDuration),
        agmOutOfLaunchZoneArrow(opticColorWatch, width, height, {
          lineWidth = lineWidth * 2
          blinkAnimation = mkLaunchZoneBlink()
        })
      ]
    }
  }
}


function Root(width, height, posX = 0, posY = 0) {
  let mkSight = @(st) opticalSight(width, height, st.TrackerSize, st.GuidanceLockState,
    st.GuidanceLockStateBlinked, st.PointIsTarget, st.ReleaseTargetCursorX, st.ReleaseTargetCursorY,
    st.LockReleaseRadiusH, st.LockReleaseRadiusW, st.MinSightFovScrSize)
  let agmSight = mkSight(agmAimState)
  let gbuSight = mkSight(gbuAimState)
  return @() {
    pos = [posX, posY]
    size = [width, height]
    watch = [agmAimState.TrackerVisible, gbuAimState.TrackerVisible, agmAimState.GuidanceLockState, gbuAimState.GuidanceLockState]

    children = (agmAimState.TrackerVisible.get() || gbuAimState.GuidanceLockState.get() == GuidanceLockResult.RESULT_INVALID)
      ? agmSight : gbuSight
  }
}
return Root