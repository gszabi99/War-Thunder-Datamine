from "%rGui/globals/ui_library.nut" import *

let { IlsColor, IlsLineScale, TvvMark, RadarTargetPosValid, RadarTargetDist,
  RocketMode, CannonMode, BombCCIPMode, BombingMode, RadarTargetDistRate,
  RadarTargetPos, TargetPos, TargetPosValid, DistToTarget,
  GunfireSolution, RadarTargetAngle, TimeBeforeBombRelease,
  AimLockPos, AimLockValid, IlsPosSize } = require("%rGui/planeState/planeToolsState.nut")
let { baseLineWidth, mpsToKnots, metrToFeet, metrToNavMile, feetToNavMile } = require("%rGui/planeIlses/ilsConstants.nut")
let { GuidanceLockResult } = require("guidanceConstants")
let { AdlPoint, CurWeaponName, ShellCnt, BulletImpactPoints1, BulletImpactPoints2, BulletImpactLineEnable } = require("%rGui/planeState/planeWeaponState.nut")
let { Tangage, Overload, BarAltitude, Altitude, Speed, Roll, Mach, MaxOverload, HorizonX, HorizonY } = require("%rGui/planeState/planeFlyState.nut")
let string = require("string")
let { floor, round } = require("%sqstd/math.nut")
let { IlsTrackerVisible, IlsTrackerX, IlsTrackerY, GuidanceLockState } = require("%rGui/rocketAamAimState.nut")
let { sin, cos, abs } = require("math")
let { degToRad } = require("%sqstd/math_ex.nut")
let { cvt } = require("dagor.math")
let { compassWrap, generateCompassMarkElbit } = require("%rGui/planeIlses/ilsCompasses.nut")
let { setInterval, clearTimer } = require("dagor.workcycle")
let { DistanceMax, AamLaunchZoneDistMax, AamLaunchZoneDistMin, AamLaunchZoneDistDgftMin, AamLaunchZoneDistDgftMax,
 AamLaunchZoneDistMaxVal, AamLaunchZoneDistMinVal, AamLaunchZoneDist } = require("%rGui/radarState.nut")


let isAAMMode = Computed(@() GuidanceLockState.get() > GuidanceLockResult.RESULT_STANDBY)
let CCIPMode = Computed(@() RocketMode.get() || CannonMode.get() || BombCCIPMode.get())
let isDGFTMode = Computed(@() isAAMMode.get() && RadarTargetPosValid.get())

function getBulletImpactLineCommand() {
  let commands = []
  for (local i = 0; i < BulletImpactPoints1.get().len() - 2; ++i) {
    let point1 = BulletImpactPoints1.get()[i]
    let point2 = BulletImpactPoints1.get()[i + 1]
    if (point1.x == -1 && point1.y == -1)
      continue
    if (point2.x == -1 && point2.y == -1)
      continue
    commands.append([VECTOR_LINE, point1.x, point1.y, point2.x, point2.y])
  }
  for (local i = 0; i < BulletImpactPoints2.get().len() - 2; ++i) {
    let point1 = BulletImpactPoints2.get()[i]
    let point2 = BulletImpactPoints2.get()[i + 1]
    if (point1.x == -1 && point1.y == -1)
      continue
    if (point2.x == -1 && point2.y == -1)
      continue
    commands.append([VECTOR_LINE, point1.x, point1.y, point2.x, point2.y])
  }
  return commands
}

let bulletsImpactLine = @() {
  watch = [CCIPMode, isAAMMode, BulletImpactLineEnable, isDGFTMode]
  size = flex()
  children = BulletImpactLineEnable.get() && !CCIPMode.get() && (!isAAMMode.get() || isDGFTMode.get()) ? @() {
    watch = [BulletImpactPoints1, BulletImpactPoints2, IlsColor]
    rendObj = ROBJ_VECTOR_CANVAS
    size = flex()
    color = IlsColor.get()
    lineWidth = baseLineWidth * IlsLineScale.get()
    commands = getBulletImpactLineCommand()
  } : null
}

let generateSpdMark = function(num) {
  let ofs = num < 10 ? pw(-15) : pw(-30)
  return {
    size = static [pw(100), ph(7.5)]
    pos = [pw(30), 0]
    children = [
      (num % 5 > 0 ? null :
        @() {
          watch = IlsColor
          size = flex()
          pos = [ofs, 0]
          rendObj = ROBJ_TEXT
          color = IlsColor.get()
          vplace = ALIGN_CENTER
          fontSize = 40
          font = Fonts.hud
          text = num.tostring()
        }
      ),
      @() {
        watch = IlsColor
        pos = [baseLineWidth * (num % 5 > 0 ? 3 : 0), ph(25)]
        size = [baseLineWidth * (num % 5 > 0 ? 4 : 7), baseLineWidth * IlsLineScale.get()]
        rendObj = ROBJ_SOLID
        color = IlsColor.get()
        lineWidth = baseLineWidth * IlsLineScale.get()
      }
    ]
  }
}

function speed(height, generateFunc) {
  let children = []

  for (local i = 1000; i >= 0; i -= 10) {
    children.append(generateFunc(i / 10))
  }

  let getOffset = @() ((1000.0 - Speed.get() * mpsToKnots) * 0.00745 - 0.5) * height
  return {
    size = static [pw(100), ph(100)]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, -getOffset()]
      }
    }
    flow = FLOW_VERTICAL
    children = children
  }
}

let SpeedValue = Computed(@() round(Speed.get() * mpsToKnots).tointeger())
function speedWrap(width, height, generateFunc) {
  return @(){
    watch = isDGFTMode
    size = [width * 0.17, height * 0.5]
    pos = [width * 0.1, height * 0.2]
    clipChildren = true
    children = [
      (!isDGFTMode.get() ? speed(height * 0.5, generateFunc) : null),
      @() {
        watch = IlsColor
        size = [pw(25), baseLineWidth * IlsLineScale.get()]
        pos = [pw(70), ph(50)]
        rendObj = ROBJ_SOLID
        color = IlsColor.get()
      },
      @() {
        watch = IlsColor
        size = SIZE_TO_CONTENT
        pos = [pw(75), ph(42)]
        rendObj = ROBJ_TEXT
        color = IlsColor.get()
        fontSize = 40
        text = "C"
      }
    ]
  }
}

let speedVal = @() {
  size = static [pw(10), ph(4)]
  pos = [pw(5), ph(43)]
  halign = ALIGN_RIGHT
  children = [
    @() {
      watch = IlsColor
      size = flex()
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.get()
      commands = [
        [VECTOR_POLY, 0, 0, 80, 0, 100, 50, 80, 100, 0, 100]
      ]
    },
    @() {
      watch = [SpeedValue, IlsColor]
      size = SIZE_TO_CONTENT
      padding = static [0, 20]
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      fontSize = 40
      text = SpeedValue.get().tostring()
    }
  ]
}

let BarAltitudeValue = Computed(@() (BarAltitude.get() * metrToFeet).tointeger())
let AltVal = @() {
  size = static [pw(15), ph(4)]
  pos = [pw(82), ph(43)]
  halign = ALIGN_RIGHT
  children = [
    @() {
      watch = IlsColor
      size = flex()
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.get()
      commands = [
        [VECTOR_POLY, 0, 50, 15, 0, 100, 0, 100, 100, 15, 100]
      ]
    },
    @() {
      watch = [BarAltitudeValue, IlsColor]
      size = SIZE_TO_CONTENT
      padding = static [0, 5]
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      fontSize = 40
      text = BarAltitudeValue.get() < 1000 ? string.format(",%03d", BarAltitudeValue.get() % 1000) : string.format("%d,%03d", BarAltitudeValue.get() / 1000, BarAltitudeValue.get() % 1000)
    }
  ]
}

let generateAltMark = function(num) {
  return {
    size = static [pw(100), ph(7.5)]
    pos = [pw(15), 0]
    flow = FLOW_HORIZONTAL
    children = [
      @() {
        watch = IlsColor
        size = [baseLineWidth * (num % 5 > 0 ? 3 : 5), baseLineWidth * IlsLineScale.get()]
        rendObj = ROBJ_SOLID
        color = IlsColor.get()
        lineWidth = baseLineWidth * IlsLineScale.get()
        vplace = ALIGN_CENTER
      },
      (num % 5 > 0 ? null :
        @() {
          watch = IlsColor
          size = flex()
          rendObj = ROBJ_TEXT
          color = IlsColor.get()
          vplace = ALIGN_CENTER
          fontSize = 40
          font = Fonts.hud
          text = string.format("%02d.%d", num / 10.0, num % 10)
        }
      )
    ]
  }
}

function altitude(height, generateFunc) {
  let children = []

  for (local i = 650; i >= 0; i -= 1) {
    children.append(generateFunc(i))
  }

  let getOffset = @() ((65000 - BarAltitude.get() * metrToFeet) * 0.0007425 - 0.48) * height
  return {
    size = static [pw(100), ph(100)]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, -getOffset()]
      }
    }
    flow = FLOW_VERTICAL
    children = children
  }
}

function altWrap(width, height, generateFunc) {
  return @(){
    watch = isDGFTMode
    size = [width * 0.17, height * 0.5]
    pos = [width * 0.75, height * 0.2]
    clipChildren = true
    children = !isDGFTMode.get() ? [
      altitude(height * 0.5, generateFunc)
    ] : null
  }
}

let OverloadWatch = Computed(@() (floor(Overload.get() * 10)).tointeger())
let overload = @() {
  watch = [OverloadWatch, IlsColor]
  size = flex()
  pos = [pw(20), ph(17)]
  rendObj = ROBJ_TEXT
  color = IlsColor.get()
  fontSize = 40
  text = string.format("%.1f", OverloadWatch.get() / 10.0)
}

let MaxOverloadWatch = Computed(@() (floor(MaxOverload.get() * 10)).tointeger())
let maxOverload = @() {
  watch = [MaxOverloadWatch, IlsColor]
  size = flex()
  pos = [pw(10), ph(78)]
  rendObj = ROBJ_TEXT
  color = IlsColor.get()
  fontSize = 40
  text = string.format("%.1f", MaxOverloadWatch.get() / 10.0)
}

let armLabel = @() {
  watch = IlsColor
  size = flex()
  pos = [pw(20), ph(70)]
  rendObj = ROBJ_TEXT
  color = IlsColor.get()
  fontSize = 40
  text = "ARM"
}

let MachWatch = Computed(@() (floor(Mach.get() * 100)).tointeger())
let mach = @() {
  watch = [MachWatch, IlsColor]
  size = flex()
  pos = [pw(20), ph(74)]
  rendObj = ROBJ_TEXT
  color = IlsColor.get()
  fontSize = 40
  text = string.format("%.2f", MachWatch.get() / 100.0)
}

let AltitudeValue = Computed(@() (Altitude.get() * metrToFeet / 10).tointeger())
let radioAlt = @() {
  watch = IlsColor
  size = static [pw(12), ph(4)]
  pos = [pw(80), ph(74)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.get()
  fillColor = Color(0, 0, 0, 0)
  lineWidth = baseLineWidth * IlsLineScale.get()
  commands = [
    [VECTOR_POLY, 0, 0, 100, 0, 100, 100, 0, 100]
  ]
  halign = ALIGN_RIGHT
  children = [
    @() {
      watch = IlsColor
      size = SIZE_TO_CONTENT
      pos = [pw(-105), 0]
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      fontSize = 40
      text = "R"
    },
    @() {
      watch = [AltitudeValue, IlsColor]
      size = SIZE_TO_CONTENT
      padding = static [0, 5]
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      fontSize = 40
      text = AltitudeValue.get() < 100 ? string.format(",%02d0", AltitudeValue.get() % 100) : string.format("%d,%02d0", AltitudeValue.get() / 100, AltitudeValue.get() % 100)
    }
  ]
}

let adlMarker = @() {
  watch = IlsColor
  rendObj = ROBJ_VECTOR_CANVAS
  size = static [pw(3), ph(3)]
  color = IlsColor.get()
  lineWidth = baseLineWidth * IlsLineScale.get()
  commands = [
    [VECTOR_LINE, -100, 0, -40, 0],
    [VECTOR_LINE, 0, -100, 0, -40],
    [VECTOR_LINE, 100, 0, 40, 0],
    [VECTOR_LINE, 0, 100, 0, 40]
  ]
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      translate = [AdlPoint[0], AdlPoint[1]]
    }
  }
}

let roll = @() {
  watch = IlsColor
  size = static [pw(70), ph(70)]
  pos = [pw(15), ph(30)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.get()
  lineWidth = baseLineWidth * IlsLineScale.get()
  commands = [
    [VECTOR_LINE, 50, 89, 50, 86],
    [VECTOR_LINE, 30.5, 83.775, 32, 81.18],
    [VECTOR_LINE, 69.5, 83.775, 68, 81.18],
    [VECTOR_LINE, 22.42, 77.58, 24.54, 75.46],
    [VECTOR_LINE, 77.58, 77.58, 75.46, 75.46],
    [VECTOR_LINE, 36.66, 86.65, 37.69, 83.83],
    [VECTOR_LINE, 43.23, 88.41, 43.75, 85.45],
    [VECTOR_LINE, 56.77, 88.41, 56.25, 85.45],
    [VECTOR_LINE, 63.34, 86.65, 62.31, 83.83]
  ]
  children = [
    @() {
      watch = IlsColor
      size = flex()
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.get() * 0.7
      commands = [
        [VECTOR_POLY, 50, 90, 48.5, 93, 51.5, 93]
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          rotate = clamp(Roll.get(), -45, 45)
        }
      }
    }
  ]
}

let ilsMode = @() {
  watch = [IlsColor, isAAMMode, CCIPMode, BombingMode, ShellCnt, CurWeaponName, isDGFTMode]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(10), ph(82)]
  color = IlsColor.get()
  fontSize = 40
  text = isDGFTMode.get() ? "DGFT" : isAAMMode.get() ? string.format("%d SRM", ShellCnt.get()) : (BombingMode.get() ? "CCRP" : (CannonMode.get() ? "STRF" : (CCIPMode.get() ? "CCIP" : "EEGS")))
}

let TargetAngle = Computed(@() RadarTargetAngle.get().tointeger())
function aamReticle(width, height) {
  return @() {
    watch = isAAMMode
    size = flex()
    children = isAAMMode.get() ? [
      @() {
        watch = IlsColor
        size = static [pw(10), ph(10)]
        pos = [pw(50), ph(50)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.get()
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth * IlsLineScale.get()
        commands = [
          [VECTOR_ELLIPSE, 0, 0, 100, 100]
        ]
        animations = [
          { prop = AnimProp.opacity, from = 1, to = -1, duration = 0.5, loop = true, easing = InOutSine, trigger = "in_dgft_launch_zone" }
        ]
        behavior = Behaviors.RtPropUpdate
        update = function() {
          let distRel = DistanceMax.get() > 0.0 ? RadarTargetDist.get() / (DistanceMax.get() * 1000.0) : 0.0
          if (AamLaunchZoneDistDgftMax.get() > 0.0 && distRel <= AamLaunchZoneDistDgftMax.get() && distRel >= AamLaunchZoneDistDgftMin.get())
            anim_start("in_dgft_launch_zone")
          else
            anim_request_stop("in_dgft_launch_zone")
          return {}
        }
      },
      @() {
        watch = IlsColor
        size = static [pw(2), ph(2)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.get()
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth * IlsLineScale.get()
        commands = [
          [VECTOR_POLY, -100, 0, 0, -100, 100, 0, 0, 100]
        ]
        animations = [
          { prop = AnimProp.opacity, from = 1, to = -1, duration = 0.5, loop = true, easing = InOutSine, trigger = "in_launch_zone" }
        ]
        behavior = Behaviors.RtPropUpdate
        update = function() {
          if (AamLaunchZoneDistMaxVal.get() > 0.0 && RadarTargetDist.get() <= AamLaunchZoneDistMaxVal.get() && RadarTargetDist.get() >= AamLaunchZoneDistMinVal.get())
            anim_start("in_launch_zone")
          else
            anim_request_stop("in_launch_zone")
          return {
            transform = {
              translate = IlsTrackerVisible.get() ? [IlsTrackerX.get(), IlsTrackerY.get()] : [width * 0.5, height * 0.5]
            }
          }
        }
      },
      @() {
        watch = IlsColor
        size = static [pw(10), ph(10)]
        pos = [pw(50), ph(50)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.get()
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth * IlsLineScale.get()
        commands = [
          [VECTOR_POLY, 0, -100, -5, -115, 5, -115]
        ]
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            rotate = TargetAngle.get()
            pivot = [0, 0]
          }
        }
      }
    ] : null
  }
}

let TargetDist = Computed(@() ((CCIPMode.get() || BombingMode.get() ? DistToTarget.get() : (RadarTargetDist.get() > 0 ? RadarTargetDist.get() : -1)) * metrToFeet * 0.1).tointeger())
let dist = @() {
  watch = [TargetDist, isAAMMode, IlsColor]
  size = SIZE_TO_CONTENT
  pos = [pw(77), ph(83)]
  rendObj = ROBJ_TEXT
  color = IlsColor.get()
  fontSize = 40
  text = isAAMMode.get() && TargetDist.get() <= 0 ? "XXX" : string.format("F%03d.%d", TargetDist.get() <= 607 ? (TargetDist.get() / 10) : (TargetDist.get() * 10.0 * feetToNavMile), TargetDist.get() <= 607 ? (TargetDist.get() % 10) : (TargetDist.get() * feetToNavMile * 100.0 % 10.0))
}

let DistMarkAngle = Computed(@() cvt(DistToTarget.get(), 0, 3657.6, -90, 279).tointeger())
function ccipGun(width, height) {
  return @() {
    watch = [CannonMode, TargetPosValid]
    size = flex()
    children = CannonMode.get() && TargetPosValid.get() ? [
      @() {
        watch = IlsColor
        size = static [pw(10), ph(10)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.get()
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth * IlsLineScale.get()
        commands = [
          [VECTOR_ELLIPSE, 0, 0, 100, 100],
          [VECTOR_ELLIPSE, 0, 0, 5, 5],
          [VECTOR_ELLIPSE, -40, 110, 5, 5],
          [VECTOR_LINE, -100, 0, -120, 0],
          [VECTOR_LINE, 100, 0, 120, 0],
          [VECTOR_LINE, 0, 100, 0, 120],
          [VECTOR_LINE, 0, -80, 0, -120]
        ]
        children = [
          @() {
            watch = IlsColor
            size = flex()
            rendObj = ROBJ_VECTOR_CANVAS
            color = IlsColor.get()
            fillColor = Color(0, 0, 0, 0)
            lineWidth = baseLineWidth * IlsLineScale.get()
            commands = [
              [VECTOR_LINE, -60, -15, -60, 15],
              [VECTOR_LINE, 60, -15, 60, 15]
            ]
            behavior = Behaviors.RtPropUpdate
            update = @() {
              transform = {
                rotate = -Roll.get()
                pivot = [0, 0]
              }
            }
          },
          @() {
            watch = [DistMarkAngle, IlsColor]
            size = flex()
            rendObj = ROBJ_VECTOR_CANVAS
            color = IlsColor.get()
            fillColor = Color(0, 0, 0, 0)
            lineWidth = baseLineWidth * IlsLineScale.get()
            commands = [
              [VECTOR_LINE, 100 * cos(degToRad(DistMarkAngle.get())), 100 * sin(degToRad(DistMarkAngle.get())), 80 * cos(degToRad(DistMarkAngle.get())), 80 * sin(degToRad(DistMarkAngle.get()))],
              [VECTOR_SECTOR, 0, 0, 80, 80, -90, DistMarkAngle.get()]
            ]
          }
        ]
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            translate = [TargetPos.get()[0], TargetPos.get()[1]]
          }
        }
      },
      @() {
        watch = [TargetPos, IlsColor]
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.get()
        lineWidth = baseLineWidth * IlsLineScale.get()
        commands = [
          [VECTOR_LINE, AdlPoint[0] / width * 100, AdlPoint[1] / height * 100,
           TargetPos.get()[0] / width * 100,
           TargetPos.get()[1] / height * 100]
        ]
      }
    ] : null
  }
}

let IsTargetPosLimited = Computed(@() TargetPos.get()[0] < IlsPosSize[2] * 0.06 || TargetPos.get()[0] > IlsPosSize[2] * 0.94 ||
 TargetPos.get()[1] < IlsPosSize[3] * 0.06 || TargetPos.get()[1] > IlsPosSize[3] * 0.94)
let TargetPosLimited = Computed(@() [clamp(TargetPos.get()[0], IlsPosSize[2] * 0.06, IlsPosSize[2] * 0.94).tointeger(),
 clamp(TargetPos.get()[1], IlsPosSize[3] * 0.06, IlsPosSize[3] * 0.94).tointeger()])
function ccipShell(width, height) {
  return @() {
    watch = [RocketMode, BombCCIPMode, BombingMode, TargetPosValid]
    size = flex()
    children = (RocketMode.get() || BombCCIPMode.get()) && TargetPosValid.get() ? [
      @() {
        watch = IlsColor
        size = static [pw(3), ph(3)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.get()
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth * IlsLineScale.get()
        commands = [
          [VECTOR_ELLIPSE, 0, 0, 100, 100],
          [VECTOR_LINE, 0, 0, 0, 0],
        ]
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            translate = [TargetPosLimited.get()[0], TargetPosLimited.get()[1]]
          }
        }
      },
      (BombCCIPMode.get() ? @() {
        watch = [TargetPosLimited, IlsColor]
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.get()
        lineWidth = baseLineWidth * IlsLineScale.get()
        commands = [
          [VECTOR_LINE, TvvMark[0] / width * 100, TvvMark[1] / height * 100,
          TargetPosLimited.get()[0] / width * 100,
          TargetPosLimited.get()[1] / height * 100]
        ]
      } : null),
      @() {
        watch = IsTargetPosLimited
        size = flex()
        children = IsTargetPosLimited.get() ? [
          @() {
            watch = TargetPosLimited
            size = [pw(5), baseLineWidth * IlsLineScale.get()]
            pos = [(2.0 * TvvMark[0] + TargetPosLimited.get()[0]) * 0.33 - 0.02 * IlsPosSize[2], (2.0 * TvvMark[1] + TargetPosLimited.get()[1]) * 0.33]
            rendObj = ROBJ_SOLID
            color = IlsColor.get()
          }
        ] : null
      }
    ] : null
  }
}

let gunfireSolution = @() {
  watch = [RadarTargetPosValid, CCIPMode, isAAMMode]
  size = flex()
  children = RadarTargetPosValid.get() && !CCIPMode.get() && !isAAMMode.get() ? [
    @() {
      watch = IlsColor
      rendObj = ROBJ_VECTOR_CANVAS
      size = static [pw(1), ph(1)]
      color = IlsColor.get()
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.get()
      commands = [
        [VECTOR_ELLIPSE, 0, 0, 100, 100]
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = [GunfireSolution[0], GunfireSolution[1]]
        }
      }
    }
  ] : null
}

let HasRadarTarget = Computed(@() RadarTargetDist.get() > 0)
let OrientationSector = Computed(@() cvt(Tangage.get(), -45.0, 45.0, 160, 20).tointeger())
let orientation = @() {
  watch = [HasRadarTarget, CCIPMode, BombingMode]
  size = flex()
  children = HasRadarTarget.get() && !CCIPMode.get() && !BombingMode.get() ? [
    @() {
      watch = [OrientationSector, IlsColor]
      rendObj = ROBJ_VECTOR_CANVAS
      size = static [pw(20), ph(20)]
      pos = [pw(50), ph(50)]
      color = IlsColor.get()
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.get()
      commands = [
        [VECTOR_SECTOR, 0, 0, 100, 100, 90 - OrientationSector.get(), 90 + OrientationSector.get()],
        [VECTOR_LINE, 100 * cos(degToRad(90 - OrientationSector.get())), 100 * sin(degToRad(90 - OrientationSector.get())),
         110 * cos(degToRad(90 - OrientationSector.get())), 110 * sin(degToRad(90 - OrientationSector.get()))],
        [VECTOR_LINE, 100 * cos(degToRad(90 + OrientationSector.get())), 100 * sin(degToRad(90 + OrientationSector.get())),
         110 * cos(degToRad(90 + OrientationSector.get())), 110 * sin(degToRad(90 + OrientationSector.get()))]
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          rotate = -Roll.get()
          pivot = [0, 0]
        }
      }
    }
  ] : null
}

let RadarDistMarkAngle = Computed(@() cvt(RadarTargetDist.get(), 0, 3657.6, 0.0, 360.0).tointeger())
function radarMark(width, height) {
  return @() {
    watch = [RadarTargetPosValid, isAAMMode, BombingMode, isDGFTMode]
    size = flex()
    children = RadarTargetPosValid.get() && !BombingMode.get() && !isDGFTMode.get() ? [
      (isAAMMode.get() ? @() {
        watch = IlsColor
        size = static [pw(5), ph(5)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.get()
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth * IlsLineScale.get()
        commands = [
          [VECTOR_POLY, -100, -100, 100, -100, 100, 100, -100, 100]
        ]
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            translate = [RadarTargetPos[0], RadarTargetPos[1]]
          }
        }
      } :
      @() {
        watch = IlsColor
        size = static [pw(5), ph(5)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.get()
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth * IlsLineScale.get()
        commands = [
          [VECTOR_SECTOR, 0, 0, 100, 100, 0, 10],
          [VECTOR_SECTOR, 0, 0, 100, 100, 20, 30],
          [VECTOR_SECTOR, 0, 0, 100, 100, 40, 50],
          [VECTOR_SECTOR, 0, 0, 100, 100, 60, 70],
          [VECTOR_SECTOR, 0, 0, 100, 100, 80, 90],
          [VECTOR_SECTOR, 0, 0, 100, 100, 100, 110],
          [VECTOR_SECTOR, 0, 0, 100, 100, 120, 130],
          [VECTOR_SECTOR, 0, 0, 100, 100, 140, 150],
          [VECTOR_SECTOR, 0, 0, 100, 100, 160, 170],
          [VECTOR_SECTOR, 0, 0, 100, 100, 180, 190],
          [VECTOR_SECTOR, 0, 0, 100, 100, 200, 210],
          [VECTOR_SECTOR, 0, 0, 100, 100, 220, 230],
          [VECTOR_SECTOR, 0, 0, 100, 100, 240, 250],
          [VECTOR_SECTOR, 0, 0, 100, 100, 260, 270],
          [VECTOR_SECTOR, 0, 0, 100, 100, 280, 290],
          [VECTOR_SECTOR, 0, 0, 100, 100, 300, 310],
          [VECTOR_SECTOR, 0, 0, 100, 100, 320, 330],
          [VECTOR_SECTOR, 0, 0, 100, 100, 340, 350]
        ]
        children = [
          @() {
            watch = IlsColor
            size = [baseLineWidth * IlsLineScale.get(), ph(30)]
            pos = [-baseLineWidth * IlsLineScale.get() * 0.5, ph(-100)]
            rendObj = ROBJ_SOLID
            color = IlsColor.get()
            behavior = Behaviors.RtPropUpdate
            update = @() {
              transform = {
                rotate = RadarDistMarkAngle.get()
                pivot = [0.5, 3.33]
              }
            }
          },
          @() {
            watch = [RadarDistMarkAngle, IlsColor]
            size = flex()
            rendObj = ROBJ_VECTOR_CANVAS
            color = IlsColor.get()
            fillColor = Color(0, 0, 0, 0)
            lineWidth = baseLineWidth * IlsLineScale.get()
            commands = [
              [VECTOR_SECTOR, 0, 0, 100, 100, -90, RadarDistMarkAngle.get() - 90]
            ]
          },
          @() {
            watch = IlsColor
            size = flex()
            rendObj = ROBJ_VECTOR_CANVAS
            color = IlsColor.get()
            fillColor = Color(0, 0, 0, 0)
            lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
            commands = [
              [VECTOR_POLY, 0, -100, -15, -130, 15, -130]
            ]
            behavior = Behaviors.RtPropUpdate
            update = @() {
              transform = {
                rotate = TargetAngle.get()
                pivot = [0, 0]
              }
            }
          }
        ]
        animations = [
          { prop = AnimProp.opacity, from = -1, to = 1, duration = 0.5, loop = true, trigger = "radar_target_out_of_limit" }
        ]
        behavior = Behaviors.RtPropUpdate
        update = function() {
          let reticleLim = [0.45 * width, 0.45 * height]
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
      })
    ] : null
  }
}

function angleTxt(num, isLeft, invVPlace = 1, x = 0, y = 0) {
  return @() {
    watch = IlsColor
    pos = [x, y]
    rendObj = ROBJ_TEXT
    vplace = (num * invVPlace) < 0 ? ALIGN_BOTTOM : ALIGN_TOP
    hplace = isLeft ? ALIGN_LEFT : ALIGN_RIGHT
    color = IlsColor.get()
    fontSize = 40
    font = Fonts.hud
    text = abs(num).tostring()
  }
}

function generatePitchLine(num) {
  let sign = num > 0 ? 1 : -1
  let newNum = num >= 0 ? num : (num - 5)
  let lineAngle =  num > 0 ? 0 : degToRad(min(20, newNum / 4))
  let offset = num > 0 ? 0 : (30.0 * sin(degToRad(min(20, newNum / 4))))
  return {
    size = static [pw(60), ph(50)]
    pos = [pw(20), 0]
    flow = FLOW_VERTICAL
    children = num == 0 ? [
      @() {
        watch = IlsColor
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.get()
        color = IlsColor.get()
        padding = static [0, 10]
        commands = [
          [VECTOR_LINE, 30, 5, 30, 0],
          [VECTOR_LINE, -20, 0, 30, 0],
          [VECTOR_LINE, 70, 5, 70, 0],
          [VECTOR_LINE, 120, 0, 70, 0]
        ]
        children = [angleTxt(-5, true, 1, pw(-20)), angleTxt(-5, false, 1, pw(20))]
      }
    ] :
    [
      @() {
        watch = IlsColor
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.get()
        color = IlsColor.get()
        commands = [
          [VECTOR_LINE, 30, 10 * sign + offset, 30, offset],
          [VECTOR_LINE, 0, 0, num > 0 ? 30 : 5, sin(lineAngle) * (num > 0 ? 30 : 5) ],
          (num < 0 ? [VECTOR_LINE, 10, sin(lineAngle) * 10, 17, sin(lineAngle) * 17 ] : []),
          (num < 0 ? [VECTOR_LINE, 23, sin(lineAngle) * 23, 30, sin(lineAngle) * 30 ] : []),
          [VECTOR_LINE, 70, 10 * sign + offset, 70, offset],
          [VECTOR_LINE, 100, 0, num > 0 ? 70 : 95, sin(lineAngle) * (num > 0 ? 30 : 5)],
          (num < 0 ? [VECTOR_LINE, 90, sin(lineAngle) * 10, 83, sin(lineAngle) * 17] : []),
          (num < 0 ? [VECTOR_LINE, 77, sin(lineAngle) * 23, 70, sin(lineAngle) * 30] : [])
        ]
        children = newNum <= 90 ? [angleTxt(newNum, true, 1, pw(-15)), angleTxt(newNum, false, 1, pw(15))] : null
      }
    ]
  }
}


function pitch(width, height, generateFunc) {
  const step = 5.0
  let children = []

  for (local i = 90.0 / step; i >= -90.0 / step; --i) {
    let num = (i * step).tointeger()

    children.append(generateFunc(num))
  }

  return {
    size = [width * 0.6, height * 0.5]
    pos = [width * -0.3, 0]
    flow = FLOW_VERTICAL
    children = children
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [HorizonX.get() - width * 0.5, HorizonY.get() - height * 5]
        rotate = -Roll.get()
        pivot = [0.5, 9]
      }
    }
  }
}


function TvvLinked(width, height) {
  let picthElem = pitch(width, height, generatePitchLine)
  let hasPitchElem = Computed(@() !HasRadarTarget.get() || isAAMMode.get() || CCIPMode.get() || BombingMode.get())
  return @() {
    watch = [hasPitchElem, isDGFTMode]
    size = flex()
    children = !isDGFTMode.get() ? [
      @() {
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        size = static [pw(6), ph(6)]
        color = IlsColor.get()
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth * IlsLineScale.get()
        commands = [
          [VECTOR_ELLIPSE, 0, 0, 30, 30],
          [VECTOR_LINE, -30, 0, -100, 0],
          [VECTOR_LINE, 30, 0, 100, 0],
          [VECTOR_LINE, 0, -30, 0, -70]
        ]
      },
      (hasPitchElem.get() ? picthElem : null)
    ] : null
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [TvvMark[0], TvvMark[1]]
      }
    }
  }
}

let SecondsToRelease = Computed(@() TimeBeforeBombRelease.get().tointeger())
let timeToRelease = @() {
  watch = SecondsToRelease
  rendObj = ROBJ_TEXT
  size = SIZE_TO_CONTENT
  color = IlsColor.get()
  pos = [pw(77), ph(86.5)]
  fontSize = 40
  text = string.format("%03d:%02d", SecondsToRelease.get() / 60, SecondsToRelease.get() % 60)
}

let AimLockLimited = Watched(false)
function updAimLockLimited() {
  AimLockLimited.set(AimLockPos[0] < IlsPosSize[2] * 0.03 || AimLockPos[0] > IlsPosSize[2] * 0.97 || AimLockPos[1] < IlsPosSize[3] * 0.03 || AimLockPos[1] > IlsPosSize[3] * 0.97)
}
let aimLockMark = @(){
  watch = AimLockValid
  size = flex()
  children = AimLockValid.get() ? [
    @(){
      watch = AimLockLimited
      size = static [pw(3), ph(3)]
      rendObj = ROBJ_VECTOR_CANVAS
      function onAttach() {
        updAimLockLimited()
        setInterval(0.5, updAimLockLimited)
      }
      onDetach = @() clearTimer(updAimLockLimited)
      color = IlsColor.get()
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.get()
      commands = [
        [VECTOR_RECTANGLE, -50, -50, 100, 100],
        (AimLockLimited.get() ? [VECTOR_LINE, -50, -50, 50, 50] : [VECTOR_LINE, 0, 0, 0, 0]),
        (AimLockLimited.get() ? [VECTOR_LINE, -50, 50, 50, -50] : [])
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = [clamp(AimLockPos[0], IlsPosSize[2] * 0.03, IlsPosSize[2] * 0.97), clamp(AimLockPos[1], IlsPosSize[3] * 0.03, IlsPosSize[3] * 0.97)]
        }
      }
    }
  ] : null
}

let lowerSolutionCue = @(){
  watch = IlsColor
  size = [pw(10), baseLineWidth * IlsLineScale.get()]
  rendObj = ROBJ_SOLID
  color = IlsColor.get()
  lineWidth = baseLineWidth * IlsLineScale.get()
  behavior = Behaviors.RtPropUpdate
  update = function() {
    let cuePos = TimeBeforeBombRelease.get() <= 0.0 ? 0.4 : cvt(TimeBeforeBombRelease.get(), 0.0, 10.0, 0, 0.4)
    return {
      transform = {
        translate = [IlsPosSize[2] * - 0.05, TvvMark[1] - cuePos * IlsPosSize[3]]
      }
    }
  }
}

function rotatedBombReleaseReticle() {
  return {
    size = flex()
    children = [
      lowerSolutionCue,
      {
        size = flex()
        children = [
          @() {
            watch = IlsColor
            size = [baseLineWidth * IlsLineScale.get(), flex()]
            rendObj = ROBJ_SOLID
            color = IlsColor.get()
            lineWidth = baseLineWidth * IlsLineScale.get()
          }
        ]
      }
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [TargetPos.get()[0], 0]
        rotate = -Roll.get()
        pivot = [0, TargetPos.get()[1] / IlsPosSize[3]]
      }
    }
  }
}

let ccrpMarks = @() {
  watch = BombingMode
  size = flex()
  children = BombingMode.get() ? [
    timeToRelease
    aimLockMark
    rotatedBombReleaseReticle()
  ] : null
}

let IsLaunchZoneVisible = Computed(@() isDGFTMode.get() && AamLaunchZoneDistMax.get() > 0.0)
let MaxDistLaunch = Computed(@() (DistanceMax.get() * 1000.0 * metrToNavMile).tointeger())
let MaxLaunchPos = Computed(@() ((1.0 - AamLaunchZoneDistMax.get()) * 100.0).tointeger())
let MinLaunchPos = Computed(@() ((1.0 - AamLaunchZoneDistMin.get()) * 100.0).tointeger())
let IsDgftLaunchZoneVisible = Computed(@() AamLaunchZoneDistDgftMax.get() > 0.0)
let MaxLaunchDgftPos = Computed(@() ((1.0 - AamLaunchZoneDistDgftMax.get()) * 100.0).tointeger())
let MinLaunchDgftPos = Computed(@() ((1.0 - AamLaunchZoneDistDgftMin.get()) * 100.0).tointeger())
let RadarClosureSpeed = Computed(@() (RadarTargetDistRate.get() * mpsToKnots * -1.0).tointeger())
let launchZone = @() {
  watch = IsLaunchZoneVisible
  size = static [pw(8), ph(30)]
  pos = [pw(75), ph(30)]
  children = IsLaunchZoneVisible.get() ? [
    @(){
      watch = AamLaunchZoneDist
      size = flex()
      pos = [pw(-100), ph((1.0 - AamLaunchZoneDist.get()) * 100.0)]
      flow = FLOW_HORIZONTAL
      halign = ALIGN_RIGHT
      children = [
        @(){
          watch = RadarClosureSpeed
          rendObj = ROBJ_TEXT
          size = SIZE_TO_CONTENT
          color = IlsColor.get()
          fontSize = 35
          text = RadarClosureSpeed.get().tostring()
        },
        {
          rendObj = ROBJ_VECTOR_CANVAS
          size = static [pw(30), ph(7)]
          color = IlsColor.get()
          lineWidth = baseLineWidth * IlsLineScale.get()
          commands = [
            [VECTOR_LINE, 0, 0, 100, 50],
            [VECTOR_LINE, 0, 100, 100, 50]
          ]
        }
      ]
    },
    {
      size = static [pw(25), flex()]
      flow = FLOW_VERTICAL
      children = [
        @(){
          watch = MaxDistLaunch
          rendObj = ROBJ_TEXT
          size = SIZE_TO_CONTENT
          color = IlsColor.get()
          fontSize = 35
          text = MaxDistLaunch.get().tostring()
        },
        {
          size = flex()
          children = [
            {
              rendObj = ROBJ_SOLID
              color = IlsColor.get()
              size = [flex(), baseLineWidth * IlsLineScale.get()]
            },
            {
              rendObj = ROBJ_SOLID
              color = IlsColor.get()
              size = [flex(), baseLineWidth * IlsLineScale.get()]
              pos = [0, ph(100)]
            },
            @() {
              watch = [MaxLaunchPos, MinLaunchPos]
              rendObj = ROBJ_VECTOR_CANVAS
              size = flex()
              color = IlsColor.get()
              lineWidth = baseLineWidth * IlsLineScale.get()
              commands = [
                [VECTOR_LINE, 0, MaxLaunchPos.get(), 100, MaxLaunchPos.get()],
                [VECTOR_LINE, 0, MinLaunchPos.get(), 100, MinLaunchPos.get()],
                [VECTOR_LINE, 0, MaxLaunchPos.get(), 0, MinLaunchPos.get()]
              ]
            },
            @(){
              watch = IsDgftLaunchZoneVisible
              size = flex()
              children = IsDgftLaunchZoneVisible.get() ? [
                @(){
                  watch = [MaxLaunchDgftPos, MinLaunchDgftPos]
                  rendObj = ROBJ_VECTOR_CANVAS
                  size = flex()
                  color = IlsColor.get()
                  lineWidth = baseLineWidth * IlsLineScale.get()
                  commands = [
                    [VECTOR_LINE, 0, MaxLaunchDgftPos.get(), 100, MaxLaunchDgftPos.get()],
                    [VECTOR_LINE, 0, MinLaunchDgftPos.get(), 100, MinLaunchDgftPos.get()],
                    [VECTOR_LINE, 100, MaxLaunchDgftPos.get(), 100, MinLaunchDgftPos.get()]
                  ]
                }
              ] : null
            }
          ]
        }
      ]
    }
  ] : null
}

function Elbit967(width, height) {
  return {
    size = [width, height]
    children = [
      TvvLinked(width, height),
      speedWrap(width, height, generateSpdMark),
      altWrap(width, height, generateAltMark),
      speedVal,
      AltVal,
      overload,
      maxOverload,
      armLabel,
      mach,
      radioAlt,
      adlMarker,
      roll,
      ilsMode,
      aamReticle(width, height),
      dist,
      ccipGun(width, height),
      ccipShell(width, height),
      bulletsImpactLine,
      radarMark(width, height),
      gunfireSolution,
      compassWrap(width, height, 0.05, generateCompassMarkElbit, 1.0),
      @() {
        watch = IlsColor
        rendObj = ROBJ_SOLID
        size = [baseLineWidth * IlsLineScale.get(), ph(5)]
        pos = [pw(50), 0]
        color = IlsColor.get()
      },
      orientation,
      ccrpMarks,
      launchZone
    ]
  }
}

return Elbit967