import "DataBlock" as DataBlock
from "%rGui/planeState/planeFlyState.nut" import Accel, Tangage
from "%rGui/planeState/planeToolsState.nut" import IlsColor, IlsLineScale, BlkFileName, RadarTargetDist, RadarTargetPosValid, TargetPosValid, TargetPos
  , DistToTarget, AimLockDist, AimLockValid, BombHorFlyDistance, BombHorDistToTarget, RadarTargetIsHelicopter, RadarTargetIsPlane
  , RocketMode, CannonMode, BombCCIPMode, BombingMode
from "%rGui/planeState/planeWeaponState.nut" import SelectedTrigger
from "%rGui/airState.nut" import TurretPitch, TurretYaw, IsInsideLaunchZoneYawPitch, IsInsideLaunchZoneDist, IsAgmLaunchZoneVisible, IlsAtgmLaunchEdge1X, IlsAtgmLaunchEdge1Y
  , IlsAtgmLaunchEdge2X, IlsAtgmLaunchEdge2Y, IlsAtgmLaunchEdge3X, IlsAtgmLaunchEdge3Y, IlsAtgmLaunchEdge4X, IlsAtgmLaunchEdge4Y, AgmLaunchZoneDistMin
  , AgmLaunchZoneDistMax
from "%rGui/hud/targetTrackerState.nut" import IsTargetTracked
from "%rGui/rocketAamAimState.nut" import GuidanceLockState
from "%rGui/radarState.nut" import TimeToMissileHit, AamLaunchZoneDistMinVal, AamLaunchZoneDistMaxVal
from "%sqstd/math.nut" import abs, round_by_value
from "guidanceConstants" import GuidanceLockResult
from "%rGui/globals/ui_library.nut" import *

let { IlsPosSize } = require("%rGui/planeState/planeToolsState.nut")
let { mpsToKmh, baseLineWidth, weaponTriggerName } = require("ilsConstants.nut")

let CCIPMode = Computed(@() RocketMode.get() || CannonMode.get() || BombCCIPMode.get())
let AtgmMode = Computed(@() SelectedTrigger.get() == weaponTriggerName.AGM_TRIGGER)
let AamMode = Computed(@() SelectedTrigger.get() == weaponTriggerName.AAM_TRIGGER)

let enableSu25tAddons = Computed(
  function isAddonsEnabled() {
    if (BlkFileName.get() == "")
      return false
    let blk = DataBlock()
    let fileName = $"gameData/flightModels/{BlkFileName.get()}.blk"
    if (!blk.tryLoad(fileName))
      return false
    return blk.getBool("ilsSu25t", false)
  }
)

let radarHudDisabled = Computed(@() enableSu25tAddons.get() && (AamMode.get() || RocketMode.get() || BombingMode.get()))

let pitchText = @() {
  watch = [Tangage, IlsColor]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = const [pw(0), ph(0)]
  color = IlsColor.get()
  fontSize = 22
  font = Fonts.ils31
  text = Tangage.get().tointeger().tostring()
}

let pitchBlock = @() {
  watch = [IlsColor]
  size = const [pw(13), ph(13)]
  rendObj = ROBJ_VECTOR_CANVAS
  halign = ALIGN_CENTER
  pos = const [pw(-15), ph(-6)]
  color = IlsColor.get()
  commands = [
    [VECTOR_LINE, 0, 0, 100, 0],
    [VECTOR_LINE, 100, 0, 100, 100],
    [VECTOR_LINE, 100, 100, 0, 100],
    [VECTOR_LINE, 0, 100, 0, 0],
  ]
  children = [pitchText]
}

let AccelWatch = Computed(@() clamp((50.0 - Accel.get() * mpsToKmh), 0, 100).tointeger())
let accelerationSu25t = @() {
  watch = IlsColor
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = baseLineWidth * 0.8 * IlsLineScale.get()
  size = const [pw(10), ph(2)]
  pos = const [pw(17), ph(26)]
  color = IlsColor.get()
  commands = [
    [VECTOR_LINE, 50, -30, 50, 30]
  ]
  children = @() {
    watch = AccelWatch
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth * 0.8 * IlsLineScale.get()
    size = flex()
    color = IlsColor.get()
    commands = abs(50 - AccelWatch.get()) > 10 ? [
      [VECTOR_LINE, 50, 0, 100 - AccelWatch.get(), 0],
      [VECTOR_LINE, 100 - AccelWatch.get(), 0, 100 - AccelWatch.get() + (AccelWatch.get() > 50 ? 10 : -10), 0],
      [VECTOR_LINE, 100 - AccelWatch.get(), 0, 100 - AccelWatch.get() + (AccelWatch.get() > 50 ? 10 : -10), 30],
      [VECTOR_LINE, 100 - AccelWatch.get(), 0, 100 - AccelWatch.get() + (AccelWatch.get() > 50 ? 10 : -10), -30],
    ] : null
  }
}

let targetDistanceText = @() {
  watch = [RadarTargetPosValid, RadarTargetDist, IlsColor]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = const [pw(30), ph(30)]
  color = IlsColor.get()
  fontSize = 25
  font = Fonts.ils31
  text = RadarTargetPosValid.get() ? $"{round_by_value(RadarTargetDist.get() / 1000.0, 0.1)}КМ" : ""
}

let targetDistanceRocket = @() {
  watch = [RocketMode, TargetPosValid]
  size = flex()
  children = RocketMode.get() && TargetPosValid.get() ? @() {
    watch = [DistToTarget, IlsColor]
    size = SIZE_TO_CONTENT
    rendObj = ROBJ_TEXT
    color = IlsColor.get()
    fontSize = 35
    font = Fonts.ils31
    text = round_by_value(DistToTarget.get() / 1000.0, 0.1).tostring()
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [TargetPos.get()[0] - IlsPosSize[3] * 0.09, TargetPos.get()[1] - IlsPosSize[3] * 0.03]
      }
    }
  } : null
}

function drawArrow(x, y) {
  const RotCoef = 0.70710678118
  return [
    [VECTOR_LINE, 0, 0, x * 100, y * 100],
    [VECTOR_LINE, (x - 0.3 * (RotCoef * x - RotCoef * y)) * 100, (y - 0.3 * (RotCoef * x + RotCoef * y)) * 100, x * 100, y * 100],
    [VECTOR_LINE, (x - 0.3 * (RotCoef * x + RotCoef * y)) * 100, (y - 0.3 * (-RotCoef * x + RotCoef * y)) * 100, x * 100, y * 100],
  ]
}

function getArrowsForTurret(x, y) {
  let commands = []
  if (x < 0.05) {
    let arrow = drawArrow(-1, 0)
    for (local i = 0; i < arrow.len(); i++) {
      commands.append(arrow[i])
    }
  }
  if (y < 0.05) {
    let arrow = drawArrow(0, 1)
    for (local i = 0; i < arrow.len(); i++) {
      commands.append(arrow[i])
    }
  }
  if (x > 0.95) {
    let arrow = drawArrow(1, 0)
    for (local i = 0; i < arrow.len(); i++) {
      commands.append(arrow[i])
    }
  }
  if (y > 0.95) {
    let arrow = drawArrow(0, -1)
    for (local i = 0; i < arrow.len(); i++) {
      commands.append(arrow[i])
    }
  }
  return commands
}

let opticsLimitWarning = @() {
  watch = [TurretPitch, TurretYaw]
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = baseLineWidth * 0.8 * IlsLineScale.get()
  color = IlsColor.get()
  size = const [pw(4), ph(4)]
  pos = const [pw(65), ph(73)]
  commands = getArrowsForTurret(TurretYaw.get(), TurretPitch.get())
}

let opticsReadyIndicator = @() {
  watch = [IsTargetTracked, IlsColor]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [IsTargetTracked.get() ? pw(60) : pw(40), ph(33)]
  color = IlsColor.get()
  fontSize = 35
  font = Fonts.ils31
  text = IsTargetTracked.get() ? "ТА" : "ТГ"
}

let lauchPermitedIndicator = @() {
  watch = [IsInsideLaunchZoneYawPitch, IsInsideLaunchZoneDist]
  size = flex()
  children = IsInsideLaunchZoneYawPitch.get() && IsInsideLaunchZoneDist.get() ?
    @() {
      watch = IlsColor
      size = const [pw(4), ph(4)]
      rendObj = ROBJ_VECTOR_CANVAS
      pos = const [pw(70), ph(85)]
      color = IlsColor.get()
      commands =  [
        [VECTOR_LINE, 0, 0, 0, 100],
        [VECTOR_LINE, 0, 0, 50, 0],
        [VECTOR_LINE, 0, 100, 50, 100],
      ]
    }
  : null
}

let aamLaunchPermitted = @() {
  watch = GuidanceLockState
  size = flex()
  children = (GuidanceLockState.get() >= GuidanceLockResult.RESULT_TRACKING ?
    @() {
      watch = IlsColor
      size = const [pw(4), ph(4)]
      rendObj = ROBJ_VECTOR_CANVAS
      pos =  const [pw(70), ph(85)]
      color = IlsColor.get()
      commands = [
        [VECTOR_LINE, 0, 0, 0, 100],
        [VECTOR_LINE, 0, 0, 50, 0],
        [VECTOR_LINE, 0, 100, 50, 100],
      ]
    }
  : null)
}

let rocketFlightTime = @() {
  watch = TimeToMissileHit
  size = flex()
  children = (TimeToMissileHit.get() > 0.0 ?
    @() {
      watch = [TimeToMissileHit, IlsColor]
      size = flex()
      rendObj = ROBJ_TEXT
      pos = const [pw(72), ph(84.5)]
      color = IlsColor.get()
      fontSize = 40
      font = Fonts.ils31
      text = $"{TimeToMissileHit.get().tointeger()}с"
    }
    : null)
}

let BombAnyMode = Computed(@() BombingMode.get() || BombCCIPMode.get())

let bombFlightDistance = @() {
  watch = [BombAnyMode, TargetPosValid]
  size = flex()
  children = BombAnyMode.get() && TargetPosValid.get() ? @() {
    watch = [BombHorFlyDistance, IlsColor]
    size = SIZE_TO_CONTENT
    rendObj = ROBJ_TEXT
    pos = const [pw(32), ph(52)]
    color = IlsColor.get()
    fontSize = 35
    font = Fonts.ils31
    text = round_by_value(BombHorFlyDistance.get() / 1000.0, 0.1).tostring()
  } : null
}

let bombTargetHorDistance = @() {
  watch = [BombAnyMode, TargetPosValid]
  size = flex()
  children = BombAnyMode.get() && TargetPosValid.get() ? @() {
    watch = [BombHorDistToTarget, IlsColor]
    size = SIZE_TO_CONTENT
    rendObj = ROBJ_TEXT
    pos = const [pw(32), ph(57)]
    color = IlsColor.get()
    fontSize = 35
    font = Fonts.ils31
    text = round_by_value(BombHorDistToTarget.get() / 1000.0, 0.1).tostring()
  } : null
}

function getRadarTargetTypeSymbol() {
  if (RadarTargetIsHelicopter.get()) {
    return [
      [VECTOR_LINE, 0, 0, 40, 0],
      [VECTOR_LINE, 40, 0, 50, -10],
      [VECTOR_LINE, 0, 0, 10, -15],
      [VECTOR_LINE, 10, -15, 20, 0],
      [VECTOR_LINE, 0, -15, 20, -15],
    ]
  }
  if (RadarTargetIsPlane.get()) {
    return [
      [VECTOR_LINE, 0, 0, 10, 10],
      [VECTOR_LINE, 10, 10, 50, 10],
      [VECTOR_LINE, 50, 10, 40, 20],
      [VECTOR_LINE, 50, 10, 40, 0],
    ]
  }
  return []
}

let radarTargetType = @() {
  watch = [IlsColor, RadarTargetIsHelicopter, RadarTargetIsPlane]
  size = const [pw(10), ph(10)]
  rendObj = ROBJ_VECTOR_CANVAS
  pos = const [pw(40), ph(65)]
  color = IlsColor.get()
  commands = getRadarTargetTypeSymbol()
}

let CCIPLine = @() {
  watch = [TargetPosValid, BombCCIPMode]
  size = flex()
  children = BombCCIPMode.get() && TargetPosValid.get() ? {
    size = [baseLineWidth * IlsLineScale.get(), ph(39.5)]
    rendObj = ROBJ_SOLID
    color = IlsColor.get()
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [TargetPos.get()[0], TargetPos.get()[1] - IlsPosSize[3] * 0.425]
      }
    }
  } : null
}

const distGridMaxDist = 12000.0

let distToGridPos = @(dist) clamp((distGridMaxDist - dist) / distGridMaxDist * 100.0, 0.0, 100.0)

let weaponMinMaxDist = Computed(function() {
  if (AtgmMode.get())
    return [AgmLaunchZoneDistMin.get(), AgmLaunchZoneDistMax.get()]
  if (AamMode.get())
    return [AamLaunchZoneDistMinVal.get(), AamLaunchZoneDistMaxVal.get()]
  return [0.0, 0.0]
})

let launchZoneDistMark = @(dist_idx) @() {
  watch = [weaponMinMaxDist, IlsColor]
  size = const [pw(180), ph(1)]
  pos = [pw(100), ph(distToGridPos(weaponMinMaxDist.get()[dist_idx]) - 2)]
  rendObj = ROBJ_SOLID
  color = IlsColor.get()
}

let launchZoneDistMarks = @() {
  watch = weaponMinMaxDist
  size = flex()
  children = weaponMinMaxDist.get()[1] > 0.0 ? [
    launchZoneDistMark(0),
    launchZoneDistMark(1)
  ] : null
}

let isDistanceToTargetValid = Computed(@() (AtgmMode.get() && AimLockValid.get()) || RadarTargetPosValid.get() || (CCIPMode.get() && TargetPosValid.get()) || (GuidanceLockState.get() >= GuidanceLockResult.RESULT_TRACKING))
let distValue = Computed(function() {
  if (AtgmMode.get())
    return AimLockDist.get()
  if (AamMode.get())
    return RadarTargetDist.get()
  return DistToTarget.get()
})

let curDistArrow = @() {
  watch = [distValue, isDistanceToTargetValid]
  size = const [pw(200), ph(5)]
  pos = [pw(100), ph(distToGridPos(distValue.get()))]
  children = isDistanceToTargetValid.get() ? @() {
    watch = IlsColor
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth * 0.8 * IlsLineScale.get()
    size = flex()
    color = IlsColor.get()
    commands = [
      [VECTOR_LINE, 0, 0, 40, -100],
      [VECTOR_LINE, 0, 0, 40, 100],
      [VECTOR_LINE, 40, -100, 40, -50],
      [VECTOR_LINE, 40, -50, 100, -50],
      [VECTOR_LINE, 40, 100, 40, 50],
      [VECTOR_LINE, 40, 50, 100, 50],
    ]
  } : null
}

function drawTextPos(x, y, text) {
  return @() {
    watch = [IlsColor]
    size = SIZE_TO_CONTENT
    rendObj = ROBJ_TEXT
    pos = [pw(x), ph(y)]
    color = IlsColor.get()
    fontSize = 36
    font = Fonts.ils31
    text = text
  }
}

let weaponDistanceGrid = @() {
  watch = IlsColor
  size = const [pw(1.5), ph(40)]
  pos = const [pw(24), ph(30)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.get()
  lineWidth = baseLineWidth * IlsLineScale.get()
  commands = [
    [VECTOR_LINE, 100, 0, 100, 100],
    [VECTOR_LINE, 0, 0, 100, 0],
    [VECTOR_LINE, 0, 16, 100, 16],
    [VECTOR_LINE, 0, 33, 100, 33],
    [VECTOR_LINE, 0, 50, 100, 50],
    [VECTOR_LINE, 0, 66, 100, 66],
    [VECTOR_LINE, 0, 83, 100, 83],
    [VECTOR_LINE, 0, 100, 100, 100]
  ]
  children = [
    curDistArrow,
    launchZoneDistMarks,
    drawTextPos(-300, -3, "12"),
    drawTextPos(-300, 13, "10"),
    drawTextPos(-200, 30, "8"),
    drawTextPos(-200, 47, "6"),
    drawTextPos(-200, 63, "4"),
    drawTextPos(-200, 80, "2"),
    drawTextPos(-200, 97, "0")
  ]
}

function agmLaunchZoneSu25T(width, height) {
  return @() {
    watch = [IsAgmLaunchZoneVisible, IlsColor]
    size = flex()
    children = IsAgmLaunchZoneVisible.get() ? function() {
      let edgesX = [IlsAtgmLaunchEdge1X.get(), IlsAtgmLaunchEdge2X.get(), IlsAtgmLaunchEdge3X.get(), IlsAtgmLaunchEdge4X.get()]
      let edgesY = [IlsAtgmLaunchEdge1Y.get(), IlsAtgmLaunchEdge2Y.get(), IlsAtgmLaunchEdge3Y.get(), IlsAtgmLaunchEdge4Y.get()]
      let minX = edgesX.reduce(@(a, b) min(a, b))
      let maxX = edgesX.reduce(@(a, b) max(a, b))
      let minY = edgesY.reduce(@(a, b) min(a, b))
      let maxY = edgesY.reduce(@(a, b) max(a, b))
      return {
        watch = [IlsAtgmLaunchEdge1X, IlsAtgmLaunchEdge1Y, IlsAtgmLaunchEdge2X, IlsAtgmLaunchEdge2Y,
          IlsAtgmLaunchEdge3X, IlsAtgmLaunchEdge3Y, IlsAtgmLaunchEdge4X, IlsAtgmLaunchEdge4Y, IlsColor]
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.get()
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth * IlsLineScale.get()
        commands = [
          [VECTOR_ELLIPSE, (minX + maxX) * 0.5 / width * 100.0, (minY + maxY) * 0.5 / height * 100.0,
            (maxX - minX) * 0.5 / width * 100.0, (maxY - minY) * 0.5 / height * 100.0]
        ]
      }
    } : null
  }
}

return {
  pitchBlock,
  accelerationSu25t,
  opticsLimitWarning,
  targetDistanceText,
  enableSu25tAddons,
  aamLaunchPermitted,
  rocketFlightTime,
  radarHudDisabled,
  opticsReadyIndicator,
  CCIPLine,
  radarTargetType,
  lauchPermitedIndicator,
  targetDistanceRocket,
  agmLaunchZoneSu25T,
  weaponDistanceGrid,
  bombFlightDistance,
  bombTargetHorDistance,
}