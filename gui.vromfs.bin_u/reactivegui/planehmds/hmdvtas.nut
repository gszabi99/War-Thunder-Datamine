from "%rGui/planeState/planeToolsState.nut" import IlsColor, IlsLineScale
from "%rGui/rocketAamAimState.nut" import GuidanceLockState
from "%rGui/radarState.nut" import IsRadarVisible
from "%rGui/style/screenState.nut" import isInVr
from "%rGui/planeState/planeWeaponState.nut" import CurWeaponGidanceType
from "%rGui/planeHmds/hmdConstants.nut" import baseLineWidth
from "guidanceConstants" import GuidanceLockResult, GuidanceType
from "%rGui/globals/ui_library.nut" import *

const dotR = 3

function crosshair(width, _height) {
  return function() {
    let guidanceType = CurWeaponGidanceType.get()
    let isOptical = guidanceType == GuidanceType.TYPE_OPTICAL
    let isRadarGuidance = guidanceType == GuidanceType.TYPE_SARH || guidanceType == GuidanceType.TYPE_ARH
    let isLocked = GuidanceLockState.get() >= GuidanceLockResult.RESULT_TRACKING

    let swModeLight = isOptical
    let radarModeLight = IsRadarVisible.get()
    let opticalLockLight = isLocked && isOptical
    let radarLockLight = isLocked && isRadarGuidance

    return {
      watch = [IsRadarVisible, GuidanceLockState, IlsColor, CurWeaponGidanceType]
      size = [width * 0.05, width * 0.05]
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      rendObj = ROBJ_VECTOR_CANVAS
      color = isInVr ? Color(202, 30, 10, 120) : Color(202, 30, 10, 100)
      lineWidth = (baseLineWidth - 2) * IlsLineScale.get()
      fillColor = Color(0, 0, 0, 0)
      commands = [
          [VECTOR_ELLIPSE, 0, 0, 50, 50],
          [VECTOR_ELLIPSE, 0, 0, 17, 17]
        ]
        .append(swModeLight ? [VECTOR_ELLIPSE, -46, -46, dotR, dotR] : [])
        .append(radarModeLight ? [VECTOR_ELLIPSE, 46, -46, dotR, dotR] : [])
        .append(opticalLockLight ? [VECTOR_ELLIPSE, -46, 46, dotR, dotR] : [])
        .append(radarLockLight ? [VECTOR_ELLIPSE, 46, 46, dotR, dotR] : [])
    }
  }
}

function vtas(width, height) {
  return {
    size = [width, height]
    pos = [0.5 * width, 0.5 * height]
    children = crosshair(width, height)
  }
}

return vtas