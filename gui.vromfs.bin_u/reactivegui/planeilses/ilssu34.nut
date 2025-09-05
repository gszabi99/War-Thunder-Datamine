from "%rGui/globals/ui_library.nut" import *
from "%globalScripts/loc_helpers.nut" import loc_checked

let { Speed, BarAltitude, Tangage, Roll, ClimbSpeed, Altitude, Tas,
 CompassValue } = require("%rGui/planeState/planeFlyState.nut")
let { mpsToKmh, baseLineWidth, radToDeg } = require("%rGui/planeIlses/ilsConstants.nut")
let { round, floor, abs } = require("%sqstd/math.nut")
let { cvt } = require("dagor.math")
let { format } = require("string")
let { IlsColor, IlsLineScale, TargetPos, BombCCIPMode, RocketMode, CannonMode,
 TargetPosValid, DistToTarget, IlsPosSize, BombingMode, TimeBeforeBombRelease,
 AimLockValid, AimLockPos, RadarTargetDist, AirCannonMode, RadarTargetPosValid,
 RadarTargetPos } = require("%rGui/planeState/planeToolsState.nut")
let { targetsComponent, ASPAzimuthMark } = require("%rGui/planeIlses/commonElements.nut")
let { IsRadarVisible, RadarModeNameId, modeNames, ScanElevationMax, ScanElevationMin, Elevation,
  HasAzimuthScale, IsCScopeVisible, HasDistanceScale, targets, Irst, DistanceMax, CueVisible,
  CueAzimuth, TargetRadarAzimuthWidth, AzimuthRange, CueAzimuthHalfWidthRel, CueDist,
  TargetRadarDist, CueDistWidthRel } = require("%rGui/radarState.nut")
let { CurWeaponName, WeaponSlots, WeaponSlotActive } = require("%rGui/planeState/planeWeaponState.nut")
let { IlsTrackerVisible, IlsTrackerX, IlsTrackerY } = require("%rGui/rocketAamAimState.nut")

let RadarTargetValid = Computed(@() RadarTargetDist.get() > 0.0)

let SpeedValue = Computed(@() round(Speed.get() * mpsToKmh).tointeger())
let speed = @() {
  watch = [SpeedValue, IlsColor]
  size = static [pw(12), ph(4)]
  rendObj = ROBJ_TEXT
  pos = [pw(12), ph(21)]
  color = IlsColor.get()
  fontSize = 45
  font = Fonts.ils31
  text = SpeedValue.get().tostring()
  halign = ALIGN_RIGHT
}

let TasSpeedValue = Computed(@() round(Tas.get() * mpsToKmh).tointeger())
let tas = @() {
  watch = [TasSpeedValue, IlsColor]
  size = static [pw(12), ph(4.5)]
  rendObj = ROBJ_TEXT
  pos = [pw(12), ph(16)]
  color = IlsColor.get()
  fontSize = 45
  font = Fonts.ils31
  text = TasSpeedValue.get().tostring()
  halign = ALIGN_RIGHT
  children = {
    rendObj = ROBJ_FRAME
    size = flex()
    pos = [5, -2]
    color = IlsColor.get()
    borderWidth = baseLineWidth * IlsLineScale.get()
  }
}

let CCIPMode = Computed(@() RocketMode.get() || CannonMode.get() || BombCCIPMode.get())

let airSymbol = @() {
  watch = IlsColor
  size = static [pw(80), ph(80)]
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = baseLineWidth * IlsLineScale.get()
  color = IlsColor.get()
  commands = [
    [VECTOR_LINE, -100, 0, -70, 0],
    [VECTOR_LINE, -50, 0, -30, 0],
    [VECTOR_LINE, -50, 0, -60, 20],
    [VECTOR_LINE, -70, 0, -60, 20],
    [VECTOR_LINE, 100, 0, 70, 0],
    [VECTOR_LINE, 50, 0, 30, 0],
    [VECTOR_LINE, 50, 0, 60, 20],
    [VECTOR_LINE, 70, 0, 60, 20],
    [VECTOR_LINE, 0, -35, 0, -70],
  ]
}

let cross = @(){
  watch = IlsColor
  size = static [pw(2), ph(2)]
  pos = [pw(45), ph(50)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.get()
  lineWidth = baseLineWidth * IlsLineScale.get()
  commands = [
    [VECTOR_LINE, 0, 30, 0, 100],
    [VECTOR_LINE, 0, -30, 0, -100],
    [VECTOR_LINE, 30, 0, 100, 0],
    [VECTOR_LINE, -30, 0, -100, 0]
  ]
}

let rollIndicator = @() {
  watch = IlsColor
  size = static [pw(25), ph(25)]
  pos = [pw(45), ph(50)]
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = baseLineWidth * IlsLineScale.get()
  color = IlsColor.get()
  commands = [
    [VECTOR_LINE, -100, 0, -90, 0],
    [VECTOR_LINE, 100, 0, 90, 0],
    [VECTOR_LINE, -82.27, 47.5, -77.94, 45],
    [VECTOR_LINE, -45, 77.9, -47.5, 82.27],
    [VECTOR_LINE, 45, 77.9, 47.5, 82.27],
    [VECTOR_LINE, 82.27, 47.5, 77.94, 45]
  ]
  children = {
    size = flex()
    children = airSymbol
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        rotate = Roll.get()
        pivot = [0, 0]
      }
    }
  }
}

function generatePitchLine(num) {
  return {
    size = static [pw(20), ph(10)]
    pos = [pw(80), 0]
    flow = FLOW_HORIZONTAL
    children = [
      (num % 10 != 0 ? {
        size = static [pw(15), flex()]
        rendObj = ROBJ_SOLID
        color = 0
      } : null),
      {
        size = [pw(num % 10 == 0 ? 30 : 15), flex()]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.get()
        lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
        commands = [
          (num > 0 ? [VECTOR_LINE_DASHED, 0, 30, 100, 30, 8, 8] : [VECTOR_LINE, num == 0 ? -1900 : 0, 30, 100, 30])
        ]
      },
      (num % 10 == 0 ? {
        size = SIZE_TO_CONTENT
        rendObj = ROBJ_TEXT
        color = IlsColor.get()
        fontSize = 40
        font = Fonts.ils31
        padding = static [0, 10]
        text = num.tostring()
      } : null)
    ]
  }
}

function pitch(height) {
  const step = 5.0
  let children = []

  for (local i = 90.0 / step; i >= -90.0 / step; --i) {
    let num = (i * step).tointeger()

    children.append(generatePitchLine(num))
  }

  return {
    size = flex()
    pos = [0, height * 0.2]
    flow = FLOW_VERTICAL
    children = children
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, -height * (91.5 - Tangage.get()) * 0.008]
      }
    }
  }
}

function pitchWrap(width, height) {
  return {
    size = [width * 0.75, height * 0.4]
    pos = [width * 0.15, height * 0.3]
    clipChildren = true
    children = pitch(height)
  }
}

let climbSpeedVal = Computed(@() ClimbSpeed.get().tointeger())
let climb = @(){
  watch = IlsColor
  size = ph(20)
  rendObj = ROBJ_VECTOR_CANVAS
  pos = [pw(87), ph(40)]
  color = IlsColor.get()
  fillColor = Color(0, 0, 0, 0)
  lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
  commands = [
    [VECTOR_LINE, -5, 50, 5, 50],
    [VECTOR_LINE, 6.7, 25, 8.86, 26.25],
    [VECTOR_LINE, 6.7, 75, 8.86, 73.75],
    [VECTOR_LINE, 1.7, 37.1, 4.1, 37.7],
    [VECTOR_LINE, 1.7, 62.9, 4.1, 62.3],
    [VECTOR_LINE, 14.6, 14.6, 16.4, 16.4],
    [VECTOR_LINE, 14.6, 85.4, 16.4, 83.6]
  ]
  children = [
    {
      size = flex()
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      fillColor = IlsColor.get()
      lineWidth = baseLineWidth * IlsLineScale.get() * 0.8
      commands = [
        [VECTOR_POLY, 50, 10, 47, 17, 53, 17],
        [VECTOR_LINE, 50, 17, 50, 35]
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          rotate = cvt(ClimbSpeed.get(), -30, 30, -135, -45)
          pivot = [0.5, 0.5]
        }
      }
    },
    @(){
      watch = climbSpeedVal
      size = static [pw(40), ph(20)]
      pos = [pw(20), ph(40)]
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      halign = ALIGN_RIGHT
      valign = ALIGN_CENTER
      padding = static [0, 10]
      fontSize = 35
      font = Fonts.ils31
      text = climbSpeedVal.get().tostring()
    }
  ]
}

let AltValue = Computed(@() Altitude.get().tointeger())
let altitude = @() {
  watch = [AltValue, IlsColor]
  size = static [pw(10), ph(4)]
  rendObj = ROBJ_TEXT
  pos = [pw(72), ph(21)]
  color = IlsColor.get()
  fontSize = 40
  font = Fonts.ils31
  text = format("%dp", AltValue.get())
  halign = ALIGN_RIGHT
}

let BarAltValue = Computed(@() BarAltitude.get().tointeger())
let barAltitude = @() {
  watch = [BarAltValue, IlsColor]
  size = static [pw(10), ph(4.5)]
  rendObj = ROBJ_TEXT
  pos = [pw(70), ph(16)]
  color = IlsColor.get()
  fontSize = 40
  font = Fonts.ils31
  text = BarAltValue.get().tostring()
  halign = ALIGN_RIGHT
  valign = ALIGN_CENTER
  children = {
    rendObj = ROBJ_FRAME
    size = flex()
    pos = [5, -2]
    color = IlsColor.get()
    borderWidth = baseLineWidth * IlsLineScale.get()
  }
}

let curDistance = Computed(@() CCIPMode.get() ? 10 : DistanceMax.get())
let TargetDist = Computed(@() CCIPMode.get() ? DistToTarget.get() : RadarTargetDist.get())
let TargetDistMarkPos = Computed(@() cvt(TargetDist.get(), 0., curDistance.get() * 1000, 100, 0).tointeger())
let distanceScale = @(){
  watch = IlsColor
  size = static [pw(2), ph(50)]
  pos = [pw(10), ph(30)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.get()
  lineWidth = baseLineWidth * IlsLineScale.get()
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
    @(){
      watch = curDistance
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(-200), ph(-3)]
      color = IlsColor.get()
      font = Fonts.ils31
      fontSize = 30
      text = curDistance.get()
    }
    @(){
      watch = curDistance
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(-200), ph(17)]
      color = IlsColor.get()
      font = Fonts.ils31
      fontSize = 30
      text = curDistance.get() * 0.8
    }
    @(){
      watch = curDistance
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(-200), ph(37)]
      color = IlsColor.get()
      font = Fonts.ils31
      fontSize = 30
      text = curDistance.get() * 0.6
    }
    @(){
      watch = curDistance
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(-200), ph(57)]
      color = IlsColor.get()
      font = Fonts.ils31
      fontSize = 30
      text = curDistance.get() * 0.4
    }
    @(){
      watch = curDistance
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(-200), ph(77)]
      color = IlsColor.get()
      font = Fonts.ils31
      fontSize = 30
      text = curDistance.get() * 0.2
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(-150), ph(97)]
      color = IlsColor.get()
      font = Fonts.ils31
      fontSize = 30
      text = "0"
    }
    @(){
      watch = TargetDistMarkPos
      size = static [pw(150), ph(2)]
      rendObj = ROBJ_VECTOR_CANVAS
      pos = [pw(180), ph(TargetDistMarkPos.get())]
      color = IlsColor.get()
      fillColor = 0
      lineWidth = baseLineWidth * IlsLineScale.get()
      commands = [
        [VECTOR_POLY, 0, 0, 40, 100, 40, 40, 100, 40, 100, -40, 40, -40, 40, -100],
        [VECTOR_LINE, 0, 0, -50, 0]
      ]
    }
  ]
}

let radarType = @(){
  watch = [Irst, IlsColor]
  size = static [pw(8), SIZE_TO_CONTENT]
  pos = [pw(3), ph(20)]
  rendObj = ROBJ_TEXT
  color = IlsColor.get()
  fontSize = 45
  font = Fonts.ils31
  text = Irst.get() ? "ТП" : "РЛ"
  halign = ALIGN_RIGHT
}

function createTargetDist(index) {
  let target = targets[index]
  let dist = HasDistanceScale.get() ? target.distanceRel : 0.9;
  let distanceRel = IsCScopeVisible.get() ? target.elevationRel : dist

  let angleRel = HasAzimuthScale.get() ? target.azimuthRel : 0.5
  let angularWidthRel = HasAzimuthScale.get() ? target.azimuthWidthRel : 1.0
  let angleLeft = angleRel - 0.5 * angularWidthRel
  let angleRight = angleRel + 0.5 * angularWidthRel

  return @() {
    watch = IlsColor
    rendObj = ROBJ_VECTOR_CANVAS
    size = flex()
    lineWidth = baseLineWidth * 0.8 * IlsLineScale.get()
    color = IlsColor.get()
    commands = [
      (!RadarTargetPosValid.get() ? [VECTOR_LINE_DASHED,
        100 * angleLeft,
        100 * (1 - distanceRel),
        100 * angleRight,
        100 * (1 - distanceRel),
        5, 7
      ] : []),
      ((target.isDetected || target.isSelected) && !RadarTargetPosValid.get() ? [VECTOR_LINE,
        100 * angleLeft - 2,
        100 * (1 - distanceRel) - 5,
        100 * angleLeft - 2,
        100 * (1 - distanceRel) + 5
      ] : []),
      ((target.isDetected || target.isSelected) && !RadarTargetPosValid.get() ? [VECTOR_LINE,
        100 * angleRight + 2,
        100 * (1 - distanceRel) - 5,
        100 * angleRight + 2,
        100 * (1 - distanceRel) + 5
      ] : []),
      ((target.isDetected || target.isSelected) && !RadarTargetPosValid.get() ? [VECTOR_LINE,
        100 * angleLeft - 2,
        100 * (1 - distanceRel) - 5,
        100 * angleRight + 2,
        100 * (1 - distanceRel) - 5
      ] : []),
      ((target.isDetected || target.isSelected) && !RadarTargetPosValid.get() ? [VECTOR_LINE,
        100 * angleLeft - 2,
        100 * (1 - distanceRel) + 5,
        100 * angleRight + 2,
        100 * (1 - distanceRel) + 5
      ] : []),
      (!target.isEnemy ?
        [VECTOR_LINE,
          !RadarTargetPosValid.get() ? 100 * angleLeft : 10,
          100 * (1 - distanceRel) - 3,
          !RadarTargetPosValid.get() ? 100 * angleRight : 15,
          100 * (1 - distanceRel) - 3
        ] : [])
    ]
  }
}

let elevationMark = @() {
  watch = [Elevation, IlsColor]
  size = [baseLineWidth * 0.8 * IlsLineScale.get(), ph(10)]
  pos = [pw(99), ph((1.0 - Elevation.get()) * 100 - 5)]
  rendObj = ROBJ_SOLID
  color = IlsColor.get()
  lineWidth = baseLineWidth * IlsLineScale.get()
}

let radarElevGrid = @() {
  watch = IlsColor
  size = static [pw(1.5), ph(40)]
  pos = [pw(74), ph(30)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.get()
  lineWidth = baseLineWidth * IlsLineScale.get()
  commands = [
    [VECTOR_LINE, 100, 0, 100, 100],
    [VECTOR_LINE, 0, 0, 100, 0],
    [VECTOR_LINE, 0, 50, 100, 50],
    [VECTOR_LINE, 0, 100, 100, 100]
  ]
}

let MaxElevation = Computed(@() floor((ScanElevationMax.get() - ScanElevationMin.get()) * radToDeg + 0.5))
let radarMaxElev = @() {
  watch = [MaxElevation, IlsColor]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(70), ph(28)]
  color = IlsColor.get()
  fontSize = 35
  font = Fonts.ils31
  text = MaxElevation.get().tointeger()
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
  size = static [pw(60), ph(50)]
  pos = [pw(15), ph(30)]
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

function radar() {
  let radarCompVisible = Computed(@() IsRadarVisible.get() && !CCIPMode.get() && !BombingMode.get())
  let BVBMode = Computed(@() !CCIPMode.get() && !AirCannonMode.get() && RadarModeNameId.get() >= 0 && (modeNames[RadarModeNameId.get()] == "hud/PD ACM" || modeNames[RadarModeNameId.get()] == "hud/IRST ACM"))
  return @(){
    watch = [Irst, RadarTargetValid, BVBMode, radarCompVisible]
    size = flex()
    children = radarCompVisible.get() ? [
      (!Irst.get() && !RadarTargetValid.get() && !BVBMode.get() ? radarElevGrid : null),
      (!Irst.get() && !RadarTargetValid.get() && !BVBMode.get() ? radarMaxElev : null),
      (!BVBMode.get() ? {
        size = static [pw(60), ph(50)]
        pos = [pw(15), ph(30)]
        children = [
          targetsComponent(createTargetDist),
          (!Irst.get() ? ASPAzimuthMark : null),
          (!Irst.get() && !RadarTargetValid.get() ? elevationMark : null)
        ]
      } :
      @() {
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        size = static [flex(), ph(60)]
        pos = [0, ph(35)]
        color = IlsColor.get()
        lineWidth = baseLineWidth * IlsLineScale.get()
        commands = [
          [VECTOR_LINE, 40, 0, 40, 100],
          [VECTOR_LINE, 60, 0, 60, 100]
        ]
      }),
      radarType,
      cueIndicator
    ] : null
  }
}

function radarReticle(width, height) {
  return @() {
    watch = RadarTargetPosValid
    size = flex()
    children = RadarTargetPosValid.get() ?
    [
      @() {
        watch = IlsColor
        size = static [pw(3), ph(3)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.get()
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth * IlsLineScale.get()
        commands = [
          [VECTOR_ELLIPSE, 0, 0, 100, 100]
        ]
        animations = [
          { prop = AnimProp.opacity, from = -1, to = 1, duration = 0.5, loop = true, trigger = "radar_target_out_of_limit" }
        ]
        behavior = Behaviors.RtPropUpdate
        update = function() {
          let reticleLim = [0.47 * width, 0.47 * height]
          if (abs(RadarTargetPos[0] - 0.5 * width) > reticleLim[0] || abs(RadarTargetPos[1] - 0.5 * height) > reticleLim[1])
            anim_start("radar_target_out_of_limit")
          else
            anim_request_stop("radar_target_out_of_limit")
          let RadarTargetPosLim =  [
            0.5 * width + clamp(RadarTargetPos[0] - 0.5 * width, -reticleLim[0], reticleLim[0]),
            0.5 * height + clamp(RadarTargetPos[1] - 0.5 * height, -reticleLim[1], reticleLim[1])
          ]
          return {
            transform = {
              translate = RadarTargetPosLim
            }
          }
        }
      }
    ] : null
  }
}

function radarReticlWrap(width, height) {
  return @() {
    watch = IsRadarVisible
    size = flex()
    children = IsRadarVisible.get() ? radarReticle(width, height) : null
  }
}

let generateCompassMark = function(num) {
  return {
    size = static [pw(8), ph(200)]
    children = [
      {
        pos = [pw(-50), ph(-100)]
        rendObj = ROBJ_TEXT
        color = IlsColor.get()
        hplace = ALIGN_CENTER
        fontSize = 35
        font = Fonts.ils31
        text = num % 10 == 0 ? format("%02d", num / 10) : ""
      },
      {
        pos = [pw(-50), ph(-90)]
        size = [baseLineWidth * IlsLineScale.get(), baseLineWidth * 2]
        rendObj = ROBJ_SOLID
        color = IlsColor.get()
        lineWidth = baseLineWidth * IlsLineScale.get()
        hplace = ALIGN_CENTER
      }
    ]
    transform = {
      rotate = num
      pivot = [0.0, 0.0]
    }
  }
}

function compass(generateFunc) {
  let children = []

  for (local i = 0; i <= 360.0 / 5; ++i) {

    let num = (i * 5) % 360

    children.append(generateFunc(num))
  }
  children.append({
    rendObj = ROBJ_VECTOR_CANVAS
    size = ph(174)
    color = IlsColor.get()
    fillColor = Color(0, 0, 0, 0)
    lineWidth = baseLineWidth * IlsLineScale.get()
    commands = [
      [VECTOR_ELLIPSE, 0, 0, 100, 100]
    ]
  })
  return {
    size = static [pw(100), ph(100)]
    pos = [pw(50), ph(220)]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        rotate = -CompassValue.get()
        pivot = [0.0, 0]
      }
    }
    children = children
  }
}

function compassWrap(width, height, generateFunc) {
  return {
    size = [width * 0.3, height * 0.2]
    pos = [width * 0.30, height * 0.1]
    clipChildren = true
    children = [
      compass(generateFunc)
      {
        rendObj = ROBJ_VECTOR_CANVAS
        pos = [pw(50), ph(50)]
        size = static [pw(70), ph(15)]
        lineWidth = baseLineWidth * IlsLineScale.get()
        color = IlsColor.get()
        fillColor = 0
        commands = [
          [VECTOR_POLY, 0, 10, 5, 50, 2, 50, 2, 100, -2, 100, -2, 50, -5, 50],
          [VECTOR_LINE, 0, -20, 0, 10]
        ]
      }
    ]
  }
}

function getWeaponSlotCnt(weaponSlotsV) {
  local cnt = 0
  foreach (weaponCnt in weaponSlotsV)
    if (weaponCnt != null && weaponCnt > cnt)
      cnt = weaponCnt
  return cnt
}

function getWeaponSlotCommands(weaponSlotsV) {
  let commands = []
  foreach (weaponCnt in weaponSlotsV)
    if (weaponCnt != null)
      commands.append([VECTOR_LINE, 20 * (weaponCnt - 1), 100, 20 * (weaponCnt - 1) + 10, 100])
  return commands
}

function getWeaponSlotNumber(weaponSlotsV, weaponSlotActiveV) {
  let numbers = []
  let added = {}
  foreach (i, weaponCnt in weaponSlotsV) {
    if (weaponCnt == null || !weaponSlotActiveV?[i] || (weaponCnt in added))
      continue

    let pos = 20 * (weaponCnt - 1)
    added[weaponCnt] <- true
    let text = (i + 1).tostring()
    numbers.append(
      @() {
        watch = [IlsColor, IlsLineScale]
        rendObj = ROBJ_FRAME
        color = IlsColor.get()
        pos = [pw(pos - 1), -5]
        size = static [pw(16), 40]
        borderWidth = baseLineWidth * IlsLineScale.get()
        children = @() {
          watch = IlsColor
          rendObj = ROBJ_TEXT
          halign = ALIGN_CENTER
          valign = ALIGN_BOTTOM
          pos = [pw(0),  ph(-5)]
          size = flex()
          color = IlsColor.get()
          fontSize = 30
          font = Fonts.ils31
          text
        }
      }
    )
  }
  return numbers
}

let connectors = @() {
  watch = [WeaponSlots, IlsColor, IlsLineScale]
  size = static [pw(24), ph(3)]
  pos = [pw(55 - 20 * getWeaponSlotCnt(WeaponSlots.get()) / 7), ph(90)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.get()
  lineWidth = baseLineWidth * IlsLineScale.get()
  commands = getWeaponSlotCommands(WeaponSlots.get())
  children = [
    @() {
      watch = WeaponSlotActive
      size = flex()
      children = getWeaponSlotNumber(WeaponSlots.get(), WeaponSlotActive.get())
    }
  ]
}

let mkCcipReticle = @(ovr = {}) @() {
  watch = IlsColor
  size = static [pw(3), ph(3)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.get()
  fillColor = Color(0, 0, 0, 0)
  lineWidth = baseLineWidth * IlsLineScale.get()
  commands = [
    [VECTOR_ELLIPSE, 0, 0, 100, 100],
    [VECTOR_LINE, 0, 0, 0, 0]
  ]
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      translate = TargetPosValid.get() ? TargetPos.get() : [-200, -200]
    }
  }
}.__merge(ovr)

let ccip = @() {
  watch = CCIPMode
  size = flex()
  children = CCIPMode.get() ? mkCcipReticle() : null
}

let bombingStabMark = @(){
  watch = BombingMode
  size = flex()
  children = BombingMode.get() ? {
    size = static [pw(3), ph(3)]
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.get()
    lineWidth = baseLineWidth * IlsLineScale.get()
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

let aamReticle = @() {
  watch = IlsTrackerVisible
  size = flex()
  children = IlsTrackerVisible.get() ?
  [
    @() {
      watch = IlsColor
      size = static [pw(10), ph(10)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.get()
      commands = [
        [VECTOR_ELLIPSE, 0, 0, 100, 100]
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = [IlsTrackerX.get(), IlsTrackerY.get()]
        }
      }
    }
  ] : null
}

let aimLock = @(){
  watch = AimLockValid
  size = flex()
  children = AimLockValid.get() ? {
    size = static [pw(5), ph(5)]
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.get()
    fillColor = Color(0, 0, 0, 0)
    lineWidth = baseLineWidth * IlsLineScale.get()
    commands = [
      [VECTOR_RECTANGLE, -50, -50, 100, 100],
      [VECTOR_LINE, 0, 0, 0, 0],
      [VECTOR_LINE, 0, -50, 0, -30],
      [VECTOR_LINE, -50, 0, -30, 0],
      [VECTOR_LINE, 0, 50, 0, 30],
      [VECTOR_LINE, 50, 0, 30, 0]
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = AimLockPos
      }
    }
  } : null
}

let timerValue = Computed(@() TimeBeforeBombRelease.get().tointeger())
let timerSector = Computed(@() cvt(TimeBeforeBombRelease.get(), 0.0, 60.0, -90.0, 250.0).tointeger())
let ccrpVisible = Computed(@() BombingMode.get() && TimeBeforeBombRelease.get() > 0.0)
let timerCCRP = @(){
  watch = ccrpVisible
  size = static [pw(4), ph(4)]
  pos = [pw(15), ph(88)]
  children = ccrpVisible.get() ? @(){
    watch = timerSector
    rendObj = ROBJ_VECTOR_CANVAS
    size = flex()
    color = IlsColor.get()
    fillColor = Color(0, 0, 0, 0)
    lineWidth = baseLineWidth * IlsLineScale.get()
    commands = [
      [VECTOR_SECTOR, 0, 0, 100, 100, -90, timerSector.get()],
      [VECTOR_LINE, 0, -100, 0, -110]
    ]
    children = @(){
      watch = timerValue
      rendObj = ROBJ_TEXT
      size = static [pw(200), ph(200)]
      pos = [pw(-100), ph(-100)]
      color = IlsColor.get()
      font = Fonts.ils31
      fontSize = 40
      fontFx = FFT_GLOW
      fontFxFactor = 1
      fontFxColor = IlsColor.get()
      valign = ALIGN_CENTER
      halign = ALIGN_CENTER
      text = timerValue.get().tostring()
    }
  } : null
}

function getRadarMode() {
  if (RadarModeNameId.get() >= 0) {
    let mode = modeNames[RadarModeNameId.get()]
    if (mode == "hud/track" || mode == "hud/PD track" || mode == "hud/MTI track" || mode == "hud/IRST track")
      return "АТК"
    if (mode == "hud/ACM" || mode == "hud/LD ACM" || mode == "hud/PD ACM" || mode == "hud/PD VS ACM" || mode == "hud/MTI ACM" || mode == "hud/TWS ACM" ||  mode == "hud/IRST ACM")
      return "БВБ"
    if (mode == "hud/GTM track" || mode == "hud/TWS GTM search" || mode == "hud/GTM search" || mode == "hud/GTM acquisition" || mode == "hud/TWS GTM acquisition" || mode == "hud/SEA track" || mode == "hud/TWS SEA acquisition" || mode == "hud/SEA acquisition" || mode == "hud/TWS SEA search" || mode == "hud/SEA search")
      return "ЗМЛ"
  }
  return "ДВБ"
}

let currentMode = @(){
  watch = [CCIPMode, IsRadarVisible, RadarModeNameId, IlsColor, BombingMode]
  size = static [pw(15), SIZE_TO_CONTENT]
  pos = [pw(0), ph(92)]
  rendObj = ROBJ_TEXT
  color = IlsColor.get()
  halign = ALIGN_RIGHT
  fontSize = 45
  font = Fonts.ils31
  text = CCIPMode.get() || BombingMode.get() ? "ЗМЛ" : (IsRadarVisible.get() ? getRadarMode() : "ФИ0")
}

let shellName = @() {
  watch = [IlsColor, CurWeaponName, CannonMode, AirCannonMode]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(80), ph(85)]
  color = IlsColor.get()
  fontSize = 35
  font = Fonts.ils31
  text = !CannonMode.get() && !AirCannonMode.get() ? (CurWeaponName.get() != "" ? loc_checked(CurWeaponName.get()) : "") : ""
}


function ilsSu34(width, height) {
  return {
    size = [width, height]
    children = [
      speed
      tas
      cross
      rollIndicator
      pitchWrap(width, height)
      climb
      altitude
      barAltitude
      distanceScale
      radar()
      radarReticlWrap(width, height)
      compassWrap(width, height, generateCompassMark)
      connectors
      ccip
      aamReticle
      bombingStabMark
      aimLock
      timerCCRP
      currentMode
      shellName
    ]
  }
}

return ilsSu34