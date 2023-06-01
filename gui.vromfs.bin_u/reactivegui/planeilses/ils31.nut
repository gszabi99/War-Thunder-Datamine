from "%rGui/globals/ui_library.nut" import *
let { Speed, BarAltitude, Tangage, Accel } = require("%rGui/planeState/planeFlyState.nut")
let { mpsToKmh, baseLineWidth, radToDeg, weaponTriggerName } = require("ilsConstants.nut")
let { IlsColor, IlsLineScale, RadarTargetPosValid, RadarTargetDist, DistToTarget,
  BombCCIPMode, RocketMode, CannonMode, TargetPosValid, TargetPos, RadarTargetPos,
  AirCannonMode, AimLockPos, AimLockValid, AimLockDist } = require("%rGui/planeState/planeToolsState.nut")
let { compassWrap, generateCompassMarkASP } = require("ilsCompasses.nut")
let { ASPAirSymbolWrap, ASPLaunchPermitted, targetsComponent, ASPAzimuthMark, bulletsImpactLine } = require("commonElements.nut")
let { IsAamLaunchZoneVisible, AamLaunchZoneDistMinVal, AamLaunchZoneDistMaxVal,
  IsRadarVisible, RadarModeNameId, modeNames, ScanElevationMax, ScanElevationMin, Elevation,
  HasAzimuthScale, IsCScopeVisible, HasDistanceScale, targets, Irst, DistanceMax } = require("%rGui/radarState.nut")
let { CurWeaponName, ShellCnt, WeaponSlots, WeaponSlotActive, SelectedTrigger } = require("%rGui/planeState/planeWeaponState.nut")
let string = require("string")
let { floor, ceil } = require("%sqstd/math.nut")
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

let SpeedValue = Computed(@() (Speed.value * mpsToKmh).tointeger())
let speed = @() {
  watch = SpeedValue
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
  watch = AltValue
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

let AtgmMode = Computed(@() !AirCannonMode.value && SelectedTrigger.value == weaponTriggerName.AGM_TRIGGER)
let CCIPMode = Computed(@() !AtgmMode.value && (RocketMode.value || CannonMode.value || BombCCIPMode.value))
let RollVisible = Computed(@() CCIPMode.value || !IsRadarVisible.value)
let rollIndicator = @() {
  watch = [RollVisible, AirTargetCannonMode]
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

let function getWeaponSlotCnt() {
  local cnt = 0
  for (local i = 0; i < WeaponSlots.value.len(); ++i) {
    if (WeaponSlots.value[i] != null && WeaponSlots.value[i] > cnt)
      cnt = WeaponSlots.value[i]
  }
  return cnt
}

let function getWeaponSlotCommands() {
  let commands = []
  for (local i = 0; i < WeaponSlots.value.len(); ++i) {
    if (WeaponSlots.value[i] != null)
      commands.append([VECTOR_LINE, 15 * (WeaponSlots.value[i] - 1), 100, 15 * (WeaponSlots.value[i] - 1) + 8, 100])
  }
  return commands
}

let function getWeaponSlotNumber() {
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
  watch = WeaponSlots
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

let function generatePitchLine(num) {
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

let function pitch(width, height, generateFunc) {
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

let function pitchWrap(width, height) {
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
let function basicInfo(width, height) {
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
  watch = RadarDistanceMax
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
  watch = MaxElevation
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
  children = [RadarTargetPosValid.value ?
    {
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
    } : null]
}

let minAamDistMarkPos = Computed(@() DistanceMax.value > 0 ? ((DistanceMax.value * 1000.0 - AamLaunchZoneDistMinVal.value) * 0.1 / DistanceMax.value).tointeger() : 0)
let maxAamDistMarkPos = Computed(@() DistanceMax.value > 0 ? ((DistanceMax.value * 1000.0 - AamLaunchZoneDistMaxVal.value) * 0.1 / DistanceMax.value).tointeger() : 0)
let maxMinLaunchDist = @() {
  watch = [IsAamLaunchZoneVisible, AirTargetCannonMode]
  size = flex()
  children = IsAamLaunchZoneVisible.value && !AirTargetCannonMode.value ?
   [
     @() {
       watch = minAamDistMarkPos
       size = [pw(180), ph(4)]
       pos = [pw(100), ph(minAamDistMarkPos.value - 2)]
       rendObj = ROBJ_SOLID
       color = IlsColor.value
     },
     @() {
       watch = maxAamDistMarkPos
       size = [pw(180), ph(4)]
       pos = [pw(100), ph(maxAamDistMarkPos.value - 2)]
       rendObj = ROBJ_SOLID
       color = IlsColor.value
     }
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
       watch = maxAgmDistMarkPos
       size = [pw(180), ph(4)]
       pos = [pw(100), ph(maxAgmDistMarkPos.value - 2)]
       rendObj = ROBJ_SOLID
       color = IlsColor.value
     }
   ] :
   []
}

let radarDistGrid = @() {
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

let ccipGridMaxDist = Computed(@() AtgmMode.value ? 10000.0 : 5000.0)
let ccipDistMarkPos = Computed(@() clamp((ccipGridMaxDist.value - (AtgmMode.value ? AimLockDist : DistToTarget).value) / (ccipGridMaxDist.value / 100), 0, 100).tointeger())
let curCCIPDist = @() {
  watch = [RadarTargetPosValid, ccipDistMarkPos]
  size = [pw(200), ph(5)]
  pos = [pw(100), ph(ccipDistMarkPos.value)]
  children = [
    {
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
  ]
}

let ccipDistGrid = @() {
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
      watch = ccipGridMaxDist
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

let radarType = @() {
  watch = Irst
  size = SIZE_TO_CONTENT
  pos = [pw(18), ph(35.5)]
  rendObj = ROBJ_TEXT
  color = IlsColor.value
  fontSize = 50
  font = Fonts.ils31
  text = Irst.value ? "ТП" : "РЛ"
}

let elevationMark = @() {
  watch = Elevation
  size = [baseLineWidth * 0.8 * IlsLineScale.value, ph(10)]
  pos = [pw(103), ph(Elevation.value * 100 - 5)]
  rendObj = ROBJ_SOLID
  color = IlsColor.value
  lineWidth = baseLineWidth * IlsLineScale.value
}


let function createTargetDist(index) {
  let target = targets[index]
  let dist = HasDistanceScale.value ? target.distanceRel : 0.9;
  let distanceRel = IsCScopeVisible.value ? target.elevationRel : dist

  let angleRel = HasAzimuthScale.value ? target.azimuthRel : 0.5
  let angularWidthRel = HasAzimuthScale.value ? target.azimuthWidthRel : 1.0
  let angleLeft = angleRel - 0.5 * angularWidthRel
  let angleRight = angleRel + 0.5 * angularWidthRel

  return {
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

let radar = @() {
  watch = [Irst, IsRadarVisible, RadarTargetValid, CCIPMode, AirNoTargetCannonMode, BVBMode]
  size = flex()
  children = IsRadarVisible.value && !CCIPMode.value && !AirNoTargetCannonMode.value ? [
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
    {
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
    radarType,
    radarReticle,
  ] : null
}

let function getRadarMode() {
  if (RadarModeNameId.value >= 0) {
    let mode = modeNames[RadarModeNameId.value]
    if (mode == "hud/track" || mode == "hud/PD track" || mode == "hud/MTI track" || mode == "hud/IRST track")
      return "АТК"
    if (mode == "hud/ACM" || mode == "hud/LD ACM" || mode == "hud/PD ACM" || mode == "hud/PD VS ACM" || mode == "hud/MTI ACM" || mode == "hud/TWS ACM" ||  mode == "hud/IRST ACM")
      return "БВБ"
    if (mode == "hud/GTM track" || mode == "hud/TWS GTM search" || mode == "hud/GTM search" || mode == "hud/GTM acquisition" || mode == "hud/TWS GTM acquisition")
      return "ЗМЛ"
  }
  return "ДВБ"
}


let function getRadarSubMode() {
  if (AirCannonMode.value)
    return ""
  if (Irst.value || CCIPMode.value)
    return "ОПТ"
  if (RadarModeNameId.value >= 0) {
    let mode = modeNames[RadarModeNameId.value]
    if (mode == "hud/track" || mode == "hud/PD track" || mode == "hud/MTI track" || mode == "hud/GTM track")
      return "А"
    if (mode == "hud/TWS standby" || mode == "hud/TWS search" || mode == "hud/TWS HDN search")
      return "СНП"
  }
  return "ОБЗ"
}

let currentMode = @() {
  watch = [CCIPMode, IsRadarVisible, RadarModeNameId, AirCannonMode, AtgmMode]
  size = SIZE_TO_CONTENT
  pos = [pw(15), ph(72)]
  rendObj = ROBJ_TEXT
  color = IlsColor.value
  fontSize = 50
  font = Fonts.ils31
  text = AirCannonMode.value ? "ВПУ" : (CCIPMode.value || AtgmMode.value ? "ЗМЛ" : (IsRadarVisible.value ? getRadarMode() : "ФИ0"))
}

let currentSubMode = @() {
  watch = [CCIPMode, RadarModeNameId, IsRadarVisible, Irst, AirCannonMode]
  size = SIZE_TO_CONTENT
  pos = [pw(15), ph(66)]
  rendObj = ROBJ_TEXT
  color = IlsColor.value
  fontSize = 50
  font = Fonts.ils31
  text = getRadarSubMode()
}

let mkCcipReticle = @(ovr = {}) {
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
      watch = TargetDistAngle
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
  watch = CCIPMode
  size = flex()
  children = CCIPMode.value ? [
    ccipDistGrid,
    @() {
      watch = TargetPosValid
      size = flex()
      children = TargetPosValid.value ? mkCcipReticle() : null
    }
  ] : []
}

let shellName = @() {
  watch = [IlsColor, CurWeaponName, CannonMode, AirCannonMode]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(75), ph(72)]
  color = IlsColor.value
  fontSize = 35
  font = Fonts.ils31
  text = !CannonMode.value && !AirCannonMode.value ? loc(CurWeaponName.value) : ""
}

let aamReticle = @() {
  watch = IlsTrackerVisible
  size = flex()
  children = IlsTrackerVisible.value ?
  [
    @() {
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
    {
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      pos = [pw(49), ph(22)]
      color = IlsColor.value
      fontSize = 40
      font = Fonts.ils31
      text = "11"
    },
    {
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
      watch = ShellPart
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

let function agmLaunchZone(width, height) {
  return @() {
    watch = IsAgmLaunchZoneVisible
    size = flex()
    children = IsAgmLaunchZoneVisible.value ? [@(){
      watch = [IlsAtgmLaunchEdge1X, IlsAtgmLaunchEdge2X]
      size = flex()
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.value
      commands = [
        [VECTOR_LINE, IlsAtgmLaunchEdge1X.value / width * 100.0, IlsAtgmLaunchEdge1Y.value / height * 100.0, IlsAtgmLaunchEdge2X.value / width * 100.0, IlsAtgmLaunchEdge2Y.value / height * 100.0],
        [VECTOR_LINE, IlsAtgmLaunchEdge2X.value / width * 100.0, IlsAtgmLaunchEdge2Y.value / height * 100.0, IlsAtgmLaunchEdge4X.value / width * 100.0, IlsAtgmLaunchEdge4Y.value / height * 100.0],
        [VECTOR_LINE, IlsAtgmLaunchEdge3X.value / width * 100.0, IlsAtgmLaunchEdge3Y.value / height * 100.0, IlsAtgmLaunchEdge4X.value / width * 100.0, IlsAtgmLaunchEdge4Y.value / height * 100.0],
        [VECTOR_LINE, IlsAtgmLaunchEdge3X.value / width * 100.0, IlsAtgmLaunchEdge3Y.value / height * 100.0, IlsAtgmLaunchEdge1X.value / width * 100.0, IlsAtgmLaunchEdge1Y.value / height * 100.0]
      ]
    }] : null
  }
}

let tvMode = @(){
  size = SIZE_TO_CONTENT
  pos = [pw(18), ph(55)]
  rendObj = ROBJ_TEXT
  color = IlsColor.value
  fontSize = 50
  font = Fonts.ils31
  text = "ТВ"
}

let laserMode = @(){
  watch = AimLockValid
  size = flex()
  children = AimLockValid.value ? [{
    size = SIZE_TO_CONTENT
    pos = [pw(18), ph(60)]
    rendObj = ROBJ_TEXT
    color = IlsColor.value
    fontSize = 50
    font = Fonts.ils31
    text = "ИД"
  }] : null
}

let atgmLaunchPermitted = @() {
  watch = [IsInsideLaunchZoneYawPitch, IsInsideLaunchZoneDist]
  size = flex()
  children = IsInsideLaunchZoneYawPitch.value && IsInsideLaunchZoneDist.value ?
    @() {
      size = flex()
      rendObj = ROBJ_TEXT
      pos = [pw(48), ph(85)]
      color = IlsColor.value
      fontSize = 40
      font = Fonts.hud
      text = "ПР"
    }
  : null
}

let function atgmGrid(width, height) {
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
      atgmLaunchPermitted
    ] : []
  }
}

let function Ils31(width, height) {
  return {
    size = [width, height]
    children = [
      basicInfo(width, height),
      radar,
      ASPLaunchPermitted(true, 48, 85),
      currentMode,
      currentSubMode,
      ccip,
      shellName,
      aamReticle,
      impactLine,
      airGunCcrpMark,
      atgmGrid(width, height),
      (HasTargetTracker.value ? tvMode : null),
      laserMode
    ]
  }
}

return Ils31