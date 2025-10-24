from "%rGui/globals/ui_library.nut" import *

let { IlsColor, TargetPosValid, TargetPos, IlsLineScale, DistToTarget, AimLockPos, AimLockValid, AirTargetMode } = require("%rGui/planeState/planeToolsState.nut")
let { SelectedTrigger } = require("%rGui/planeState/planeWeaponState.nut")
let { baseLineWidth, weaponTriggerName } = require("%rGui/planeIlses/ilsConstants.nut")
let { cvt } = require("dagor.math")
let { Roll } = require("%rGui/planeState/planeFlyState.nut");
let hudUnitType = require("%rGui/hudUnitType.nut")

let ASP17crosshair = @() {
  watch = IlsColor
  size = const [pw(20), ph(20)]
  pos = [pw(50), ph(50)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.get()
  lineWidth = baseLineWidth * IlsLineScale.get()
  commands = [
    [VECTOR_LINE, 0, 0, 0, 0],
    [VECTOR_LINE, -10, 0, -60, 0],
    [VECTOR_LINE, 0, -10, 0, -60],
    [VECTOR_LINE, 10, 0, 60, 0],
    [VECTOR_LINE, 0, 10, 0, 60],
  ]
}

let ASP17Roll = @() {
  watch = IlsColor
  size = const [pw(20), ph(20)]
  pos = [pw(50), ph(50)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.get()
  lineWidth = baseLineWidth * IlsLineScale.get()
  fillColor = IlsColor.get()
  behavior = Behaviors.RtPropUpdate
  commands = [
    [VECTOR_POLY, -2, -70, 0, -77, 2, -70]
  ]
  update = @() {
    transform = {
      rotate = clamp(Roll.get(), -30, 30).tointeger()
      pivot = [0, 0]
    }
  }
}

let DistToTargetWatch = Computed(@() cvt(DistToTarget.get(), 450, 3000, -90, 15).tointeger())
let ASP17Distances = @() {
  watch = [IlsColor, DistToTargetWatch]
  size = const [pw(20), ph(20)]
  pos = [pw(50), ph(50)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.get()
  lineWidth = baseLineWidth * IlsLineScale.get()
  fillColor = Color(0, 0, 0, 0)
  commands = [
    [VECTOR_SECTOR, 0, 0, 93, 93, -80, max(-80, min(DistToTargetWatch.get(), -3))],
    [VECTOR_SECTOR, 0, 0, 90, 90, -90, DistToTargetWatch.get()],
    [VECTOR_WIDTH, baseLineWidth * 1.5 * IlsLineScale.get()],
    [VECTOR_LINE, 0, -90, 0, -82], 
    (DistToTargetWatch.get() > -30 ? [VECTOR_LINE, 78, -45, 71, -41] : []),  
    (DistToTargetWatch.get() > -60 ? [VECTOR_LINE, 45, -78, 41, -71] : []), 
    (DistToTargetWatch.get() > 0 ? [VECTOR_LINE, 82, 0, 90, 0] : []), 
    [VECTOR_WIDTH, baseLineWidth * IlsLineScale.get()],
    (DistToTargetWatch.get() >= 15 ? [VECTOR_LINE, 82.1, 22, 86.9, 23.3] : []),  
    (DistToTargetWatch.get() > -15 ? [VECTOR_LINE, 82.1, -22, 86.9, -23.3] : []),  
    (DistToTargetWatch.get() > -37.5 ? [VECTOR_LINE, 67.4, -51.7, 71.4, -54.8] : []),  
    (DistToTargetWatch.get() > -45 ? [VECTOR_LINE, 60.1, -60.1, 63.6, -63.6] : []),  
    (DistToTargetWatch.get() > -52.5 ? [VECTOR_LINE, 51.7, -67.4, 54.8, -71.4] : []),  
    (DistToTargetWatch.get() > -67.5 ? [VECTOR_LINE, 32.5, -78.5, 34.4, -83.2] : []),  
    (DistToTargetWatch.get() > -75 ? [VECTOR_LINE, 22, -82.1, 23.3, -86.9] : []),  
    (DistToTargetWatch.get() > -82.5 ? [VECTOR_LINE, 11, -84.3, 11.7, -89.2] : [])  
  ]
}

let lockedReticle = {
  size = const [pw(50), ph(50)]
  pos = [pw(50), ph(50)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = Color(20, 10, 1, 0)
  lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
  fillColor = Color(0, 0, 0, 0)
  commands = [
    [VECTOR_ELLIPSE, 0, 0, 15, 15],
    [VECTOR_ELLIPSE, 0, 0, 40, 40],
    [VECTOR_LINE, 10, 0, 75, 0],
    [VECTOR_LINE, -10, 0, -75, 0],
    [VECTOR_LINE, 0, 10, 0, 100],
    [VECTOR_LINE, 0, -10, 0, -50],
    [VECTOR_LINE, 20, -5, 20, 5],
    [VECTOR_LINE, 30, -5, 30, 5],
    [VECTOR_LINE, 40, -5, 40, 5],
    [VECTOR_LINE, 50, -5, 50, 5],
    [VECTOR_LINE, 60, -5, 60, 5],
    [VECTOR_LINE, 70, -5, 70, 5],
    [VECTOR_LINE, -20, -5, -20, 5],
    [VECTOR_LINE, -30, -5, -30, 5],
    [VECTOR_LINE, -40, -5, -40, 5],
    [VECTOR_LINE, -50, -5, -50, 5],
    [VECTOR_LINE, -60, -5, -60, 5],
    [VECTOR_LINE, -70, -5, -70, 5],
    [VECTOR_LINE, -5, 20, 5, 20],
    [VECTOR_LINE, -5, 30, 5, 30],
    [VECTOR_LINE, -5, 40, 5, 40],
    [VECTOR_LINE, -5, 50, 5, 50],
    [VECTOR_LINE, -5, 60, 5, 60],
    [VECTOR_LINE, -5, 70, 5, 70],
    [VECTOR_LINE, -5, 80, 5, 80],
    [VECTOR_LINE, -5, 90, 5, 90],
    [VECTOR_LINE, -5, 100, 5, 100],
    [VECTOR_LINE, -5, -20, 5, -20],
    [VECTOR_LINE, -5, -30, 5, -30],
    [VECTOR_LINE, -5, -40, 5, -40],
    [VECTOR_WIDTH, baseLineWidth * IlsLineScale.get() * 2.0],
    [VECTOR_LINE, 0, 0, 0, 0]
  ]
}

let NeedShowAimLock = Computed(@() SelectedTrigger.get() == weaponTriggerName.AGM_TRIGGER || SelectedTrigger.get() == -1)
function mainReticle(width, height) {
return {
    size = flex()
    children = [
      ASP17Distances,
      ASP17crosshair,
      ASP17Roll
    ]
    behavior = Behaviors.RtPropUpdate
    update = function() {
      if (hudUnitType.isHelicopter()) {
        local lockPos = AimLockPos
        if (lockPos[0] - width * 0.5 > width * 0.4)
          lockPos[0] = width * 0.9
        if (lockPos[0] - width * 0.5 < -width * 0.4)
          lockPos[0] = width * 0.1
        if (lockPos[1] - height * 0.5 > height * 0.4)
          lockPos[1] = height * 0.9
        if (lockPos[1] - height * 0.5 < -height * 0.4)
          lockPos[1] = height * 0.1
        return {
          transform = {
            translate = AimLockValid.get() && NeedShowAimLock.get() ? [lockPos[0] - width * 0.5, lockPos[1] - height * 0.5] :
            (TargetPosValid.get() ? [TargetPos.get()[0] - width * 0.5, TargetPos.get()[1] - height * 0.5] : [0, 0])
          }
        }
      }
      return {
        transform = {
          translate = TargetPosValid.get() && !AirTargetMode.get() ? [TargetPos.get()[0] - width * 0.5, TargetPos.get()[1] - height * 0.5] :
          (AimLockValid.get() ? [AimLockPos[0] - width * 0.5, AimLockPos[1] - height * 0.5] : [0, 0])
        }
      }
    }
  }
}

function ASP17(width, height) {
  return {
    size = [width, height]
    children = [
      mainReticle(width, height)
      hudUnitType.isHelicopter() ? lockedReticle : null
    ]
  }
}

return ASP17