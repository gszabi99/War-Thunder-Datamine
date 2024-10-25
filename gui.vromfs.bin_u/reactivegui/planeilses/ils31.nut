from "%rGui/globals/ui_library.nut" import *
from "%globalScripts/loc_helpers.nut" import loc_checked
let { Speed, BarAltitude, Tangage, Accel } = require("%rGui/planeState/planeFlyState.nut")
let { mpsToKmh, baseLineWidth, radToDeg, weaponTriggerName } = require("ilsConstants.nut")
let { IlsColor, IlsLineScale, RadarTargetPosValid, RadarTargetDist, DistToTarget,
  BombCCIPMode, RocketMode, CannonMode, TargetPosValid, TargetPos, RadarTargetPos, IlsPosSize,
  AirCannonMode, AimLockPos, AimLockValid, AimLockDist, BombingMode, TimeBeforeBombRelease } = require("%rGui/planeState/planeToolsState.nut")
let { compassWrap, generateCompassMarkASP } = require("ilsCompasses.nut")
let { ASPAirSymbolWrap, ASPLaunchPermitted, targetsComponent, ASPAzimuthMark, bulletsImpactLine } = require("commonElements.nut")
let { IsAamLaunchZoneVisible, AamLaunchZoneDistMinVal, AamLaunchZoneDistMaxVal, AamLaunchZoneDistDgftMax,
  IsRadarVisible, RadarModeNameId, modeNames, ScanElevationMax, ScanElevationMin, Elevation,
  HasAzimuthScale, IsCScopeVisible, HasDistanceScale, targets, Irst, DistanceMax, CueVisible,
  CueAzimuth, TargetRadarAzimuthWidth, AzimuthRange, CueAzimuthHalfWidthRel, CueDist, TargetRadarDist, CueDistWidthRel } = require("%rGui/radarState.nut")
let { CurWeaponName, ShellCnt, WeaponSlots, WeaponSlotActive, SelectedTrigger } = require("%rGui/planeState/planeWeaponState.nut")
let string = require("string")
let { floor, ceil, round } = require("%sqstd/math.nut")
let { cvt } = require("dagor.math")
let { IlsTrackerVisible, IlsTrackerX, IlsTrackerY } = require("%rGui/rocketAamAimState.nut")
let { IsAgmLaunchZoneVisible, IlsAtgmLaunchEdge1X, IlsAtgmLaunchEdge1Y, IlsAtgmLaunchEdge2X, IlsAtgmLaunchEdge2Y,
 IlsAtgmLaunchEdge3X, IlsAtgmLaunchEdge3Y, IlsAtgmLaunchEdge4X, IlsAtgmLaunchEdge4Y, IsInsideLaunchZoneYawPitch,
 IsInsideLaunchZoneDist, AgmLaunchZoneDistMax } = require("%rGui/airState.nut")
let {HasTargetTracker} = require("%rGui/hud/targetTrackerState.nut");

let RadarTargetValid = Computed(@() RadarTargetDist.value > 0.0)
let AirTargetCannonMode = Computed(@() AirCannonMode.value && RadarTargetValid.value)
let AirNoTargetCannonMode = Computed(@() AirCannonMode.value && !AirTargetCannonMode.value)
let RadarDistanceMax = Computed(@() AirTargetCannonMode.value ? 5.0 : DistanceMax.value)

let SpeedValue = Computed(@() round(Speed.value * mpsToKmh).tointeger())
let speed = @() {
  watch = [SpeedValue, IlsColor]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(17), ph(20)]
  color = IlsColor.value
  fontSize = 50
  font = Fonts.ils31
  text = SpeedValue.value.tostring()
}

let AltValue = Computed(@() BarAltitude.value.tointeger())
let altitude = @() {
  watch = [AltValue, IlsColor]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(71), ph(20)]
  color = IlsColor.value
  fontSize = 50
  font = Fonts.ils31
  text = string.format("%dp", AltValue.value)
}

let AccelWatch = Computed(@() clamp((50.0 - Accel.value * mpsToKmh), 0, 100).tointeger())
let acceleration = @() {
  watch = IlsColor
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = baseLineWidth * 0.8 * IlsLineScale.value
  size = [pw(10), ph(2)]
  pos = [pw(17), ph(25)]
  color = IlsColor.value
  commands = [
    [VECTOR_LINE, 0, 0, 100, 0]
  ]
  children = @() {
    watch = AccelWatch
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth * 0.8 * IlsLineScale.value
    size = flex()
    color = IlsColor.value
    commands = [
      [VECTOR_LINE, 100 - AccelWatch.value, 5, 100 - AccelWatch.value + 10, 100],
      [VECTOR_LINE, 100 - AccelWatch.value, 5, 100 - AccelWatch.value - 10, 100],
      [VECTOR_LINE, 100 - AccelWatch.value - 10, 100, 100 - AccelWatch.value + 10, 100]
    ]
  }
}

let compassMark = @() {
  watch = IlsColor
  size = flex()
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = baseLineWidth * 0.8 * IlsLineScale.value
  color = IlsColor.value
  fillColor = Color(0, 0, 0, 0)
  commands = [
    [VECTOR_LINE, 32, 25, 68, 25],
    [VECTOR_POLY, 48, 28, 50, 25, 52, 28]
  ]
}

let CCIPMode = Computed(@() RocketMode.value || CannonMode.value || BombCCIPMode.value)
let AtgmMode = Computed(@() !CCIPMode.value && SelectedTrigger.value == weaponTriggerName.AGM_TRIGGER)
let RollVisible = Computed(@() CCIPMode.value || !IsRadarVisible.value)
let rollIndicator = @() {
  watch = [RollVisible, AirTargetCannonMode, IlsColor]
  size = [pw(15), ph(15)]
  pos = [pw(50), ph(50)]
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = baseLineWidth * IlsLineScale.value
  color = IlsColor.value
  commands = [
    [VECTOR_LINE, -100, 0, -80, 0],
    [VECTOR_LINE, 100, 0, 80, 0],
    (RollVisible.value ? [VECTOR_LINE, -86.6, 50, -69.3, 40] : []),
    (RollVisible.value ? [VECTOR_LINE, -50, 86.6, -40, 69.3] : []),
    (RollVisible.value ? [VECTOR_LINE, 50, 86.6, 40, 69.3] : []),
    (RollVisible.value ? [VECTOR_LINE, 86.6, 50, 69.3, 40] : []),
    (RollVisible.value ? [VECTOR_LINE, -86.9, 23.3, -77.3, 20.7] : []),
    (RollVisible.value ? [VECTOR_LINE, 86.9, 23.3, 77.3, 20.7] : []),
    (RollVisible.value ? [VECTOR_LINE, 63.6, 63.6, 56.6, 56.6] : []),
    (RollVisible.value ? [VECTOR_LINE, -63.6, 63.6, -56.6, 56.6] : []),
    (!AirTargetCannonMode.value ? [VECTOR_LINE, -15, 0, -5, 0] : []),
    (!AirTargetCannonMode.value ? [VECTOR_LINE, 15, 0, 5, 0] : []),
    (!AirTargetCannonMode.value ? [VECTOR_LINE, 0, -15, 0, -5] : []),
    (!AirTargetCannonMode.value ? [VECTOR_LINE, 0, 15, 0, 5] : [])
  ]
  children = ASPAirSymbolWrap
}

function getWeaponSlotCnt() {
  local cnt = 0
  for (local i = 0; i < WeaponSlots.value.len(); ++i) {
    if (WeaponSlots.value[i] != null && WeaponSlots.value[i] > cnt)
      cnt = WeaponSlots.value[i]
  }
  return cnt
}

function getWeaponSlotCommands() {
  let commands = []
  for (local i = 0; i < WeaponSlots.value.len(); ++i) {
    if (WeaponSlots.value[i] != null)
      commands.append([VECTOR_LINE, 15 * (WeaponSlots.value[i] - 1), 100, 15 * (WeaponSlots.value[i] - 1) + 8, 100])
  }
  return commands
}

function getWeaponSlotNumber() {
  let numbers = []
  for (local i = 0; i < WeaponSlots.value.len(); ++i) {
    if (WeaponSlots.value[i] != null && WeaponSlotActive.value[i] == true) {
      let pos = 15 * (WeaponSlots.value[i] - 1)
      numbers.append(
        {
          rendObj = ROBJ_TEXT
          size = SIZE_TO_CONTENT
          pos = [pw(pos), 0]
          color = IlsColor.value
          fontSize = 30
          font = Fonts.ils31
          text = (i + 1).tostring()
        }
      )
    }
  }
  return numbers
}

let connectors = @() {
  watch = [WeaponSlots, IlsColor]
  size = [pw(24), ph(3)]
  pos = [pw(50 - 12 * getWeaponSlotCnt() / 7), ph(76)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.value
  lineWidth = baseLineWidth * IlsLineScale.value
  commands = getWeaponSlotCommands()
  children = [
    @() {
      watch = WeaponSlotActive
      size = flex()
      children = getWeaponSlotNumber()
    }
  ]
}

function generatePitchLine(num) {
  return {
    size = [pw(60), ph(30)]
    pos = [pw(20), 0]
    children = [
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.value * (num == 0 ? 1.0 : 0.5)
        color = IlsColor.value
        commands = [
          (num == 0 ? [VECTOR_LINE, 0, 0, 100, 0] : [VECTOR_LINE, 95, 0, 105, 0])
        ]
      },
      @() {
        size = SIZE_TO_CONTENT
        pos = [pw(95), ph(-25)]
        watch = IlsColor
        rendObj = ROBJ_TEXT
        lineWidth = baseLineWidth * IlsLineScale.value
        color = IlsColor.value
        fontSize = 35
        font = Fonts.ils31
        text = string.format("%02d", num)
      }
    ]
  }
}

function pitch(width, height, generateFunc) {
  const step = 10.0
  let children = []

  for (local i = 90.0 / step; i >= -90.0 / step; --i) {
    let num = (i * step).tointeger()

    children.append(generateFunc(num))
  }

  return {
    size = [width * 0.6, height * 0.5]
    pos = [-width * 0.05, height * 0.25]
    flow = FLOW_VERTICAL
    children = children
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, -height * (90.0 - Tangage.value) * 0.015]
      }
    }
  }
}

function pitchWrap(width, height) {
  return @() {
    watch = AirCannonMode
    size = [pw(50), ph(50)]
    pos = [pw(25), ph(25)]
    clipChildren  = true
    children = !AirCannonMode.value ? [
      pitch(width, height, generatePitchLine)
    ] : null
  }
}

let BVBMode = Computed(@() !CCIPMode.value && !AirCannonMode.value && RadarModeNameId.value >= 0 && (modeNames[RadarModeNameId.value] == "hud/PD ACM" || modeNames[RadarModeNameId.value] == "hud/IRST ACM"))
function basicInfo(width, height) {
  return @() {
    watch = [AirCannonMode, AirNoTargetCannonMode]
    size = flex()
    children = [
      speed,
      acceleration,
      (!AirCannonMode.value ? compassWrap(width, height, 0.17, generateCompassMarkASP, 0.6, 5.0, false, -1, Fonts.ils31) : null),
      (!AirCannonMode.value ? compassMark : null),
      altitude,
      (!AirNoTargetCannonMode.value ? rollIndicator : null),
      pitchWrap(width, height),
      connectors
    ]
  }
}

let radarMaxDist = @() {
  watch = [RadarDistanceMax, IlsColor]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(18), ph(28)]
  color = IlsColor.value
  fontSize = 35
  font = Fonts.ils31
  text = RadarDistanceMax.value.tointeger()
}

let MaxElevation = Computed(@() floor((ScanElevationMax.value - ScanElevationMin.value) * radToDeg + 0.5))
let radarMaxElev = @() {
  watch = [MaxElevation, IlsColor]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(70), ph(28)]
  color = IlsColor.value
  fontSize = 35
  font = Fonts.ils31
  text = MaxElevation.value.tointeger()
}

let RdrTgtDistMarkPos = Computed(@() RadarDistanceMax.value > 0 ? ((RadarDistanceMax.value * 1000.0 - RadarTargetDist.value) * 0.1 / RadarDistanceMax.value).tointeger() : 0)
let curRadarDist = @() {
  watch = [RadarTargetPosValid, RdrTgtDistMarkPos]
  size = [pw(200), ph(5)]
  pos = [pw(100), ph(RdrTgtDistMarkPos.value)]
  children = RadarTargetPosValid.value ? @() {
    watch = IlsColor
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth * 0.8 * IlsLineScale.value
    size = flex()
    color = IlsColor.value
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

let minAamDistMarkPos = Computed(@() DistanceMax.value > 0 ? ((DistanceMax.value * 1000.0 - AamLaunchZoneDistMinVal.value) * 0.1 / DistanceMax.value).tointeger() : 0)
let maxAamDistMarkPos = Computed(@() DistanceMax.value > 0 ? ((DistanceMax.value * 1000.0 - AamLaunchZoneDistMaxVal.value) * 0.1 / DistanceMax.value).tointeger() : 0)
let maxAamDistMarkDgftPos = Computed(@() DistanceMax.value > 0 ? ((1.0 - AamLaunchZoneDistDgftMax.value) * 100.0).tointeger() : 0)
let AamDistMarkDgftVis = Computed(@() AamLaunchZoneDistDgftMax.value > 0.0)
let maxMinLaunchDist = @() {
  watch = [IsAamLaunchZoneVisible, AirTargetCannonMode, AamDistMarkDgftVis]
  size = flex()
  children = IsAamLaunchZoneVisible.value && !AirTargetCannonMode.value ?
   [
     @() {
       watch = [minAamDistMarkPos, IlsColor]
       size = [pw(180), ph(4)]
       pos = [pw(100), ph(minAamDistMarkPos.value - 2)]
       rendObj = ROBJ_SOLID
       color = IlsColor.value
     },
     @() {
       watch = [maxAamDistMarkPos, IlsColor]
       size = [pw(180), ph(4)]
       pos = [pw(100), ph(maxAamDistMarkPos.value - 2)]
       rendObj = ROBJ_SOLID
       color = IlsColor.value
     },
     (AamDistMarkDgftVis.value ? @() {
       watch = [maxAamDistMarkDgftPos, IlsColor]
       size = [pw(180), ph(4)]
       pos = [pw(100), ph(maxAamDistMarkDgftPos.value - 2)]
       rendObj = ROBJ_SOLID
       color = IlsColor.value
     } : null)
   ] :
   []
}

let maxAgmDistMarkPos = Computed(@() DistanceMax.value > 0 ? ((DistanceMax.value * 1000.0 - AgmLaunchZoneDistMax.value) * 0.1 / DistanceMax.value).tointeger() : 0)
let maxAtgmLaunchDist = @() {
  watch = [AtgmMode]
  size = flex()
  children = AtgmMode.value?
   [
     @() {
       watch = [maxAgmDistMarkPos, IlsColor]
       size = [pw(180), ph(4)]
       pos = [pw(100), ph(maxAgmDistMarkPos.value - 2)]
       rendObj = ROBJ_SOLID
       color = IlsColor.value
     }
   ] :
   []
}

let radarDistGrid = @() {
  watch = IlsColor
  size = [pw(1.5), ph(40)]
  pos = [pw(24), ph(30)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.value
  lineWidth = baseLineWidth * IlsLineScale.value
  commands = [
    [VECTOR_LINE, 100, 0, 100, 100],
    [VECTOR_LINE, 0, 0, 100, 0],
    [VECTOR_LINE, 0, 20, 100, 20],
    [VECTOR_LINE, 0, 40, 100, 40],
    [VECTOR_LINE, 0, 60, 100, 60],
    [VECTOR_LINE, 0, 80, 100, 80],
    [VECTOR_LINE, 0, 100, 100, 100]
  ]
  children = [
    curRadarDist,
    maxMinLaunchDist,
    maxAtgmLaunchDist
  ]
}

let ccipGridMaxDist = Computed(@() AtgmMode.value || BombingMode.value ? 10000.0 : 5000.0)
let ccipDistMarkPos = Computed(@() !BombingMode.value ? clamp((ccipGridMaxDist.value - (AtgmMode.value ? AimLockDist : DistToTarget).value) / (ccipGridMaxDist.value / 100), 0, 100).tointeger() :
  clamp((10.0 - TimeBeforeBombRelease.value) * 10.0, 0.0, 100.0).tointeger())
let curCCIPDist = @() {
  watch = [RadarTargetPosValid, ccipDistMarkPos]
  size = [pw(200), ph(5)]
  pos = [pw(100), ph(ccipDistMarkPos.value)]
  children = @() {
    watch = IlsColor
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth * 0.8 * IlsLineScale.value
    size = flex()
    color = IlsColor.value
    commands = [
      [VECTOR_LINE, 0, 0, 40, -100],
      [VECTOR_LINE, 0, 0, 40, 100],
      [VECTOR_LINE, 40, -100, 40, -50],
      [VECTOR_LINE, 40, -50, 100, -50],
      [VECTOR_LINE, 40, 100, 40, 50],
      [VECTOR_LINE, 40, 50, 100, 50],
    ]
  }
}

let ccipDistGrid = @() {
  watch = IlsColor
  size = [pw(1.5), ph(40)]
  pos = [pw(24), ph(30)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.value
  lineWidth = baseLineWidth * IlsLineScale.value
  commands = [
    [VECTOR_LINE, 100, 0, 100, 100],
    [VECTOR_LINE, 0, 0, 100, 0],
    [VECTOR_LINE, 0, 20, 100, 20],
    [VECTOR_LINE, 0, 40, 100, 40],
    [VECTOR_LINE, 0, 60, 100, 60],
    [VECTOR_LINE, 0, 80, 100, 80],
    [VECTOR_LINE, 0, 100, 100, 100]
  ]
  children = [
    curCCIPDist,
    @(){
      watch = [ccipGridMaxDist, IlsColor]
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      pos = [ccipGridMaxDist.value >= 10000 ? pw(-300) : pw(-150), ph(-5)]
      color = IlsColor.value
      fontSize = 36
      font = Fonts.ils31
      text = (ccipGridMaxDist.value / 1000).tointeger()
    }
  ]
}

let radarElevGrid = @() {
  watch = IlsColor
  size = [pw(1.5), ph(40)]
  pos = [pw(74), ph(30)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.value
  lineWidth = baseLineWidth * IlsLineScale.value
  commands = [
    [VECTOR_LINE, 100, 0, 100, 100],
    [VECTOR_LINE, 0, 0, 100, 0],
    [VECTOR_LINE, 0, 50, 100, 50],
    [VECTOR_LINE, 0, 100, 100, 100]
  ]
}

let radarType = @(is_cn) function() {
  return {
    watch = [Irst, IlsColor]
    size = [pw(10), SIZE_TO_CONTENT]
    pos = [pw(14), ph(35.5)]
    rendObj = ROBJ_TEXT
    color = IlsColor.value
    fontSize = 50
    font = Fonts.ils31
    text = is_cn ? (Irst.value ? "光学" : "雷达") : (Irst.value ? "ТП" : "РЛ")
    halign = ALIGN_RIGHT
  }
}

let elevationMark = @() {
  watch = [Elevation, IlsColor]
  size = [baseLineWidth * 0.8 * IlsLineScale.value, ph(10)]
  pos = [pw(103), ph((1.0 - Elevation.value) * 100 - 5)]
  rendObj = ROBJ_SOLID
  color = IlsColor.value
  lineWidth = baseLineWidth * IlsLineScale.value
}


function createTargetDist(index) {
  let target = targets[index]
  let dist = HasDistanceScale.value ? target.distanceRel : 0.9;
  let distanceRel = IsCScopeVisible.value ? target.elevationRel : dist

  let angleRel = HasAzimuthScale.value ? target.azimuthRel : 0.5
  let angularWidthRel = HasAzimuthScale.value ? target.azimuthWidthRel : 1.0
  let angleLeft = angleRel - 0.5 * angularWidthRel
  let angleRight = angleRel + 0.5 * angularWidthRel

  return @() {
    watch = IlsColor
    rendObj = ROBJ_VECTOR_CANVAS
    size = flex()
    lineWidth = baseLineWidth * 0.8 * IlsLineScale.value
    color = IlsColor.value
    commands = [
      (!RadarTargetPosValid.value ? [VECTOR_LINE_DASHED,
        100 * angleLeft,
        100 * (1 - distanceRel),
        100 * angleRight,
        100 * (1 - distanceRel),
        5, 7
      ] : []),
      ((target.isDetected || target.isSelected) && !RadarTargetPosValid.value ? [VECTOR_LINE,
        100 * angleLeft - 2,
        100 * (1 - distanceRel) - 5,
        100 * angleLeft - 2,
        100 * (1 - distanceRel) + 5
      ] : []),
      ((target.isDetected || target.isSelected) && !RadarTargetPosValid.value ? [VECTOR_LINE,
        100 * angleRight + 2,
        100 * (1 - distanceRel) - 5,
        100 * angleRight + 2,
        100 * (1 - distanceRel) + 5
      ] : []),
      ((target.isDetected || target.isSelected) && !RadarTargetPosValid.value ? [VECTOR_LINE,
        100 * angleLeft - 2,
        100 * (1 - distanceRel) - 5,
        100 * angleRight + 2,
        100 * (1 - distanceRel) - 5
      ] : []),
      ((target.isDetected || target.isSelected) && !RadarTargetPosValid.value ? [VECTOR_LINE,
        100 * angleLeft - 2,
        100 * (1 - distanceRel) + 5,
        100 * angleRight + 2,
        100 * (1 - distanceRel) + 5
      ] : []),
      (!target.isEnemy ?
        [VECTOR_LINE,
          !RadarTargetPosValid.value ? 100 * angleLeft : 10,
          100 * (1 - distanceRel) - 3,
          !RadarTargetPosValid.value ? 100 * angleRight : 15,
          100 * (1 - distanceRel) - 3
        ] : [])
    ]
  }
}
let radarReticle = @() {
  watch = RadarTargetPosValid
  size = flex()
  children = RadarTargetPosValid.value ?
  [
    @() {
      watch = IlsColor
      size = [pw(3), ph(3)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.value
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.value
      commands = [
        [VECTOR_ELLIPSE, 0, 0, 100, 100]
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = RadarTargetPos
        }
      }
    }
  ] : null
}

let cue = @() {
  watch = [CueAzimuthHalfWidthRel, CueDistWidthRel]
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = 2
  color = IlsColor.get()
  size = flex()
  commands = [
    [VECTOR_LINE, -100.0 * CueAzimuthHalfWidthRel.get(), -50.0 * CueDistWidthRel.get(), -100.0 * CueAzimuthHalfWidthRel.get(), 50.0 * CueDistWidthRel.get()],
    [VECTOR_LINE,  100.0 * CueAzimuthHalfWidthRel.get(), -50.0 * CueDistWidthRel.get(),  100.0 * CueAzimuthHalfWidthRel.get(), 50.0 * CueDistWidthRel.get()],
    [VECTOR_LINE, -100.0 * CueAzimuthHalfWidthRel.get(), -50.0 * CueDistWidthRel.get(), 100.0 * CueAzimuthHalfWidthRel.get(), -50.0 * CueDistWidthRel.get()],
    [VECTOR_LINE, -100.0 * CueAzimuthHalfWidthRel.get(), 50.0 * CueDistWidthRel.get(), 100.0 * CueAzimuthHalfWidthRel.get(), 50.0 * CueDistWidthRel.get()]
  ]
}

let cueIndicator = @(){
  watch = CueVisible
  size = [pw(50), ph(40)]
  pos = [pw(25), ph(30)]
  children = CueVisible.get() ? @(){
    watch = [CueAzimuth, TargetRadarAzimuthWidth, AzimuthRange, CueAzimuthHalfWidthRel, CueDist, TargetRadarDist, CueDistWidthRel]
    pos = [
      pw((CueAzimuth.get() * (TargetRadarAzimuthWidth.get() / AzimuthRange.get() - CueAzimuthHalfWidthRel.get()) + 0.5) * 100),
      ph((1.0 - (0.5 * CueDistWidthRel.get() + CueDist.get() * TargetRadarDist.get() * (1.0 - CueDistWidthRel.get()))) * 100)
    ]
    size = flex()
    children = cue
  } : null
}

let radar = @(is_cn) function() {
  return {
    watch = [Irst, IsRadarVisible, RadarTargetValid, CCIPMode, AirNoTargetCannonMode, BVBMode, BombingMode]
    size = flex()
    children = IsRadarVisible.value && !CCIPMode.value && !AirNoTargetCannonMode.value && !BombingMode.value ? [
      ((!Irst.value && !BVBMode.value) || RadarTargetValid.value ? radarDistGrid : null),
      ((!Irst.value && !BVBMode.value) || RadarTargetValid.value ? radarMaxDist : null),
      (!Irst.value && !RadarTargetValid.value && !BVBMode.value ? radarElevGrid : null),
      (!Irst.value && !RadarTargetValid.value && !BVBMode.value ? radarMaxElev : null),
      (!BVBMode.value ? {
        size = [pw(50), ph(40)]
        pos = [pw(25), ph(30)]
        children = [
          targetsComponent(createTargetDist),
          (!Irst.value ? ASPAzimuthMark : null),
          (!Irst.value && !RadarTargetValid.value ? elevationMark : null)
        ]
      } :
      @() {
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        size = [flex(), ph(60)]
        pos = [0, ph(35)]
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
        commands = [
          [VECTOR_LINE, 40, 0, 40, 100],
          [VECTOR_LINE, 60, 0, 60, 100]
        ]
      }),
      radarType(is_cn),
      cueIndicator
    ] : null
  }
}

let radarReticlWrap = @(){
  watch = IsRadarVisible
  size = flex()
  children = IsRadarVisible.get() ? radarReticle : null
}

function getRadarMode(is_cn) {
  if (RadarModeNameId.value >= 0) {
    let mode = modeNames[RadarModeNameId.value]
    if (mode == "hud/track" || mode == "hud/PD track" || mode == "hud/MTI track" || mode == "hud/IRST track")
      return is_cn ? "锁定" : "АТК"
    if (mode == "hud/ACM" || mode == "hud/LD ACM" || mode == "hud/PD ACM" || mode == "hud/PD VS ACM" || mode == "hud/MTI ACM" || mode == "hud/TWS ACM" ||  mode == "hud/IRST ACM")
      return is_cn ? "近距离" : "БВБ"
    if (mode == "hud/GTM track" || mode == "hud/TWS GTM search" || mode == "hud/GTM search" || mode == "hud/GTM acquisition" || mode == "hud/TWS GTM acquisition")
      return is_cn ? "空对地" : "ЗМЛ"
  }
  return is_cn ? "超视距" : "ДВБ"
}


function getRadarSubMode(is_cn) {
  if (AirCannonMode.value)
    return ""
  if (Irst.value || CCIPMode.value || BombingMode.value)
    return is_cn ? "光电" : "ОПТ"
  if (RadarModeNameId.value >= 0) {
    let mode = modeNames[RadarModeNameId.value]
    if (mode == "hud/track" || mode == "hud/PD track" || mode == "hud/MTI track" || mode == "hud/GTM track")
      return is_cn ? "" : "А"
    if (mode == "hud/TWS standby" || mode == "hud/TWS search" || mode == "hud/TWS HDN search")
      return is_cn ? "追踪" : "СНП"
  }
  return is_cn ? "扫描中" : "ОБЗ"
}

function currentMode(is_cn) {
  return @(){
    watch = [CCIPMode, IsRadarVisible, RadarModeNameId, AirCannonMode, AtgmMode, IlsColor, BombingMode]
    size = [pw(15), SIZE_TO_CONTENT]
    pos = [pw(9), ph(72)]
    rendObj = ROBJ_TEXT
    color = IlsColor.value
    halign = ALIGN_RIGHT
    fontSize = 50
    font = Fonts.ils31
    text = AirCannonMode.value ? (is_cn ? "弹道" : "ВПУ") : (CCIPMode.value || AtgmMode.value || BombingMode.value ? (is_cn ? "空对地" : "ЗМЛ") : (IsRadarVisible.value ? getRadarMode(is_cn) : (is_cn ? "目视" : "ФИ0")))
  }
}

function currentSubMode(is_cn) {
  return @(){
    watch = [CCIPMode, RadarModeNameId, IsRadarVisible, Irst, AirCannonMode, IlsColor]
    size = [pw(15), SIZE_TO_CONTENT]
    pos = [pw(9), ph(66)]
    rendObj = ROBJ_TEXT
    color = IlsColor.value
    fontSize = 50
    font = Fonts.ils31
    text = getRadarSubMode(is_cn)
    halign = ALIGN_RIGHT
  }
}

let mkCcipReticle = @(ovr = {}) @() {
  watch = IlsColor
  size = [pw(3), ph(3)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.value
  fillColor = Color(0, 0, 0, 0)
  lineWidth = baseLineWidth * IlsLineScale.value
  commands = [
    [VECTOR_ELLIPSE, 0, 0, 100, 100],
    [VECTOR_LINE, 0, 0, 0, 0]
  ]
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      translate = TargetPos.value
    }
  }
}.__merge(ovr)

let TargetDistAngle = Computed(@() cvt(RadarTargetDist.value, 0, 1200, -90, 270).tointeger())
let airGunCcrpMark = @() {
  watch = [AirTargetCannonMode, TargetPosValid]
  size = flex()
  children = [
    (AirTargetCannonMode.value && TargetPosValid.value ?
    @(){
      watch = [TargetDistAngle, IlsColor]
      rendObj = ROBJ_VECTOR_CANVAS
      size = [pw(3), ph(3)]
      color = IlsColor.value
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.value
      commands = [
        [VECTOR_SECTOR, 0, 0, 100, 100, -89, TargetDistAngle.value],
        [VECTOR_LINE, -80, 0, -30, 0],
        [VECTOR_LINE, 80, 0, 30, 0],
        [VECTOR_LINE, 0, 80, 0, 30],
        [VECTOR_LINE, 0, -80, 0, -30]
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = TargetPos.value
        }
      }
    } : null)
  ]
}

let ccip = @() {
  watch = [CCIPMode, BombingMode]
  size = flex()
  children = CCIPMode.value || BombingMode.value ? [
    ccipDistGrid,
    @() {
      watch = [TargetPosValid, BombingMode]
      size = flex()
      children = TargetPosValid.value && !BombingMode.value ? mkCcipReticle() : null
    }
  ] : []
}

function shellName(is_cn) {
  return @() {
    watch = [IlsColor, CurWeaponName, CannonMode, AirCannonMode]
    size = SIZE_TO_CONTENT
    rendObj = ROBJ_TEXT
    pos = [pw(75), ph(72)]
    color = IlsColor.value
    fontSize = 35
    font = Fonts.ils31
    text = !CannonMode.value && !AirCannonMode.value ? (!is_cn ? (CurWeaponName.value != "" ? loc_checked(CurWeaponName.value) : "") : (RocketMode.get() ? "航箭" : (BombCCIPMode.get() || BombingMode.get() ? "航弹" : loc_checked(CurWeaponName.value)))) : ""
  }
}

let aamReticle = @() {
  watch = IlsTrackerVisible
  size = flex()
  children = IlsTrackerVisible.value ?
  [
    @() {
      watch = IlsColor
      size = [pw(10), ph(10)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.value
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.value
      commands = [
        [VECTOR_ELLIPSE, 0, 0, 100, 100]
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = [IlsTrackerX.value, IlsTrackerY.value]
        }
      }
    }
  ] : null
}

let ShellPart = Computed(@() ceil(ShellCnt.value / 37.5).tointeger())
let impactLine = @() {
  watch = [AirCannonMode, AirNoTargetCannonMode]
  size = flex()
  children = AirCannonMode.value ? [
    (AirNoTargetCannonMode.value ? bulletsImpactLine : null),
    @() {
      watch = IlsColor
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      pos = [pw(49), ph(22)]
      color = IlsColor.value
      fontSize = 40
      font = Fonts.ils31
      text = "11"
    },
    @() {
      watch = IlsColor
      size = [pw(4), ph(4)]
      pos = [pw(70), ph(70)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.value
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.value * 0.5
      commands = [
        [VECTOR_RECTANGLE, 0, 0, 100, 100]
      ]
    },
    @() {
      watch = [ShellPart, IlsColor]
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      pos = [pw(71), ph(70.2)]
      color = IlsColor.value
      fontSize = 40
      font = Fonts.ils31
      text = ShellPart.value.tostring()
    }
  ] : null
}

function agmLaunchZone(width, height) {
  return @() {
    watch = [IsAgmLaunchZoneVisible, IlsColor]
    size = flex()
    children = IsAgmLaunchZoneVisible.value ? @(){
      watch = [IlsAtgmLaunchEdge1X, IlsAtgmLaunchEdge2X, IlsColor]
      size = flex()
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.value
      commands = [
        [VECTOR_LINE, IlsAtgmLaunchEdge1X.value / width * 100.0, IlsAtgmLaunchEdge1Y.value / height * 100.0, IlsAtgmLaunchEdge2X.value / width * 100.0, IlsAtgmLaunchEdge2Y.value / height * 100.0],
        [VECTOR_LINE, IlsAtgmLaunchEdge2X.value / width * 100.0, IlsAtgmLaunchEdge2Y.value / height * 100.0, IlsAtgmLaunchEdge4X.value / width * 100.0, IlsAtgmLaunchEdge4Y.value / height * 100.0],
        [VECTOR_LINE, IlsAtgmLaunchEdge3X.value / width * 100.0, IlsAtgmLaunchEdge3Y.value / height * 100.0, IlsAtgmLaunchEdge4X.value / width * 100.0, IlsAtgmLaunchEdge4Y.value / height * 100.0],
        [VECTOR_LINE, IlsAtgmLaunchEdge3X.value / width * 100.0, IlsAtgmLaunchEdge3Y.value / height * 100.0, IlsAtgmLaunchEdge1X.value / width * 100.0, IlsAtgmLaunchEdge1Y.value / height * 100.0]
      ]
    } : null
  }
}

function tvMode(is_cn) {
  return @(){
    watch = IlsColor
    size = [pw(15) , SIZE_TO_CONTENT]
    pos = [pw(10), ph(55)]
    rendObj = ROBJ_TEXT
    color = IlsColor.value
    fontSize = is_cn ? 38 : 50
    font = Fonts.ils31
    text = is_cn ? "吊舱瞄准" : "ТВ"
    halign = ALIGN_RIGHT
  }
}

let laserMode = @(is_cn) function() {
  return {
    watch = AimLockValid
    size = flex()
    children = AimLockValid.value ? @() {
      watch = IlsColor
      size = [pw(20), SIZE_TO_CONTENT]
      pos = [pw(3), ph(60)]
      rendObj = ROBJ_TEXT
      color = IlsColor.value
      fontSize = 50
      font = Fonts.ils31
      text = is_cn ? "激光照射" : "ИД"
      halign = ALIGN_RIGHT
    } : null
  }
}

let atgmLaunchPermitted = @(is_cn) function() {
  return {
    watch = [IsInsideLaunchZoneYawPitch, IsInsideLaunchZoneDist]
    size = flex()
    children = IsInsideLaunchZoneYawPitch.value && IsInsideLaunchZoneDist.value ?
      @() {
        watch = IlsColor
        size = flex()
        rendObj = ROBJ_TEXT
        pos = [pw(48), ph(85)]
        color = IlsColor.value
        fontSize = 40
        font = Fonts.hud
        text = is_cn ? "允许攻击" : "ПР"
      }
    : null
  }
}

let aimLockPosMark = @() {
  watch = AimLockValid
  size = flex()
  children = AimLockValid.value ? [
    @(){
      watch = IlsColor
      size = [pw(2), pw(2)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.value
      lineWidth = baseLineWidth * IlsLineScale.value
      commands = [
        [VECTOR_LINE, -100, -100, -30, -30],
        [VECTOR_LINE, -100, 100, -30, 30],
        [VECTOR_LINE, 100, 100, 30, 30],
        [VECTOR_LINE, 100, -100, 30, -30]
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = AimLockPos
        }
      }
    }
  ] : null
}

function atgmGrid(width, height, is_cn) {
  return @() {
    watch = [AtgmMode, IsRadarVisible]
    size = flex()
    children = AtgmMode.value ? [
      (!IsRadarVisible.value ? ccipDistGrid : null),
      @() {
        watch = AimLockValid
        size = flex()
        children = AimLockValid.value ? mkCcipReticle({ update = @() { transform = { translate  = AimLockPos } }}) : null
      },
      agmLaunchZone(width, height),
      atgmLaunchPermitted(is_cn)
    ] : [aimLockPosMark]
  }
}

let bombingStabMark = @(){
  watch = BombingMode
  size = flex()
  children = BombingMode.value ? {
    size = [pw(3), ph(3)]
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.value
    lineWidth = baseLineWidth * IlsLineScale.value
    fillColor = Color(0, 0, 0, 0)
    commands = [
      [VECTOR_ELLIPSE, 0, 0, 100, 100],
      [VECTOR_LINE, 0, 0, 0, 0]
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [AimLockPos[0], IlsPosSize[3] * 0.425]
      }
    }
  } : null
}

function Ils31(width, height, is_cn) {
  return {
    size = [width, height]
    children = [
      basicInfo(width, height),
      radar(is_cn),
      ASPLaunchPermitted(!is_cn, 48, 85, is_cn),
      currentMode(is_cn),
      currentSubMode(is_cn),
      ccip,
      shellName(is_cn),
      aamReticle,
      impactLine,
      airGunCcrpMark,
      atgmGrid(width, height, is_cn),
      (HasTargetTracker.value ? tvMode(is_cn) : null),
      laserMode(is_cn),
      bombingStabMark,
      radarReticlWrap
    ]
  }
}

return Ils31