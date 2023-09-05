from "%rGui/globals/ui_library.nut" import *

let { IlsColor, IlsLineScale, TvvMark, RadarTargetPosValid, RadarTargetDist,
  RocketMode, CannonMode, BombCCIPMode, BombingMode,
  RadarTargetPos, TargetPos, TargetPosValid, DistToTarget,
  GunfireSolution, RadarTargetAngle } = require("%rGui/planeState/planeToolsState.nut")
let { baseLineWidth, mpsToKnots, metrToFeet, feetToNavMile } = require("ilsConstants.nut")
let { GuidanceLockResult } = require("%rGui/guidanceConstants.nut")
let { AdlPoint, CurWeaponName, ShellCnt } = require("%rGui/planeState/planeWeaponState.nut")
let { Tangage, Overload, BarAltitude, Altitude, Speed, Roll, Mach, MaxOverload } = require("%rGui/planeState/planeFlyState.nut")
let string = require("string")
let { floor, round } = require("%sqstd/math.nut")
let { IlsTrackerVisible, IlsTrackerX, IlsTrackerY, GuidanceLockState } = require("%rGui/rocketAamAimState.nut")
let { sin, cos, abs } = require("math")
let { degToRad } = require("%sqstd/math_ex.nut")
let { cvt } = require("dagor.math")
let { compassWrap, generateCompassMarkElbit } = require("ilsCompasses.nut")
let { bulletsImpactLine } = require("commonElements.nut")


let isAAMMode = Computed(@() GuidanceLockState.value > GuidanceLockResult.RESULT_STANDBY)
let CCIPMode = Computed(@() RocketMode.value || CannonMode.value || BombCCIPMode.value)

let generateSpdMark = function(num) {
  let ofs = num < 10 ? pw(-15) : pw(-30)
  return {
    size = [pw(100), ph(7.5)]
    pos = [pw(30), 0]
    children = [
      (num % 5 > 0 ? null :
        @() {
          watch = IlsColor
          size = flex()
          pos = [ofs, 0]
          rendObj = ROBJ_TEXT
          color = IlsColor.value
          vplace = ALIGN_CENTER
          fontSize = 40
          font = Fonts.hud
          text = num.tostring()
        }
      ),
      @() {
        watch = IlsColor
        pos = [baseLineWidth * (num % 5 > 0 ? 3 : 0), ph(25)]
        size = [baseLineWidth * (num % 5 > 0 ? 4 : 7), baseLineWidth * IlsLineScale.value]
        rendObj = ROBJ_SOLID
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
      }
    ]
  }
}

let function speed(height, generateFunc) {
  let children = []

  for (local i = 1000; i >= 0; i -= 10) {
    children.append(generateFunc(i / 10))
  }

  let getOffset = @() ((1000.0 - Speed.value * mpsToKnots) * 0.00745 - 0.5) * height
  return {
    size = [pw(100), ph(100)]
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

let SpeedValue = Computed(@() round(Speed.value * mpsToKnots).tointeger())
let function speedWrap(width, height, generateFunc) {
  return {
    size = [width * 0.17, height * 0.5]
    pos = [width * 0.1, height * 0.2]
    clipChildren = true
    children = [
      speed(height * 0.5, generateFunc),
      @() {
        watch = IlsColor
        size = [pw(25), baseLineWidth * IlsLineScale.value]
        pos = [pw(70), ph(50)]
        rendObj = ROBJ_SOLID
        color = IlsColor.value
      },
      @() {
        watch = IlsColor
        size = SIZE_TO_CONTENT
        pos = [pw(75), ph(42)]
        rendObj = ROBJ_TEXT
        color = IlsColor.value
        fontSize = 40
        text = "C"
      }
    ]
  }
}

let speedVal = @() {
  size = [pw(10), ph(4)]
  pos = [pw(5), ph(43)]
  halign = ALIGN_RIGHT
  children = [
    @() {
      watch = IlsColor
      size = flex()
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.value
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.value
      commands = [
        [VECTOR_POLY, 0, 0, 80, 0, 100, 50, 80, 100, 0, 100]
      ]
    },
    @() {
      watch = [SpeedValue, IlsColor]
      size = SIZE_TO_CONTENT
      padding = [0, 20]
      rendObj = ROBJ_TEXT
      color = IlsColor.value
      fontSize = 40
      text = SpeedValue.value.tostring()
    }
  ]
}

let BarAltitudeValue = Computed(@() (BarAltitude.value * metrToFeet).tointeger())
let AltVal = @() {
  size = [pw(15), ph(4)]
  pos = [pw(82), ph(43)]
  halign = ALIGN_RIGHT
  children = [
    @() {
      watch = IlsColor
      size = flex()
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.value
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.value
      commands = [
        [VECTOR_POLY, 0, 50, 15, 0, 100, 0, 100, 100, 15, 100]
      ]
    },
    @() {
      watch = [BarAltitudeValue, IlsColor]
      size = SIZE_TO_CONTENT
      padding = [0, 5]
      rendObj = ROBJ_TEXT
      color = IlsColor.value
      fontSize = 40
      text = BarAltitudeValue.value < 1000 ? string.format(",%03d", BarAltitudeValue.value % 1000) : string.format("%d,%03d", BarAltitudeValue.value / 1000, BarAltitudeValue.value % 1000)
    }
  ]
}

let generateAltMark = function(num) {
  return {
    size = [pw(100), ph(7.5)]
    pos = [pw(15), 0]
    flow = FLOW_HORIZONTAL
    children = [
      @() {
        watch = IlsColor
        size = [baseLineWidth * (num % 5 > 0 ? 3 : 5), baseLineWidth * IlsLineScale.value]
        rendObj = ROBJ_SOLID
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
        vplace = ALIGN_CENTER
      },
      (num % 5 > 0 ? null :
        @() {
          watch = IlsColor
          size = flex()
          rendObj = ROBJ_TEXT
          color = IlsColor.value
          vplace = ALIGN_CENTER
          fontSize = 40
          font = Fonts.hud
          text = string.format("%02d.%d", num / 10.0, num % 10)
        }
      )
    ]
  }
}

let function altitude(height, generateFunc) {
  let children = []

  for (local i = 650; i >= 0; i -= 1) {
    children.append(generateFunc(i))
  }

  let getOffset = @() ((65000 - BarAltitude.value * metrToFeet) * 0.0007425 - 0.48) * height
  return {
    size = [pw(100), ph(100)]
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

let function altWrap(width, height, generateFunc) {
  return {
    size = [width * 0.17, height * 0.5]
    pos = [width * 0.75, height * 0.2]
    clipChildren = true
    children = [
      altitude(height * 0.5, generateFunc)
    ]
  }
}

let OverloadWatch = Computed(@() (floor(Overload.value * 10)).tointeger())
let overload = @() {
  watch = [OverloadWatch, IlsColor]
  size = flex()
  pos = [pw(20), ph(17)]
  rendObj = ROBJ_TEXT
  color = IlsColor.value
  fontSize = 40
  text = string.format("%.1f", OverloadWatch.value / 10.0)
}

let MaxOverloadWatch = Computed(@() (floor(MaxOverload.value * 10)).tointeger())
let maxOverload = @() {
  watch = [MaxOverloadWatch, IlsColor]
  size = flex()
  pos = [pw(10), ph(78)]
  rendObj = ROBJ_TEXT
  color = IlsColor.value
  fontSize = 40
  text = string.format("%.1f", MaxOverloadWatch.value / 10.0)
}

let armLabel = @() {
  watch = IlsColor
  size = flex()
  pos = [pw(20), ph(70)]
  rendObj = ROBJ_TEXT
  color = IlsColor.value
  fontSize = 40
  text = "ARM"
}

let MachWatch = Computed(@() (floor(Mach.value * 100)).tointeger())
let mach = @() {
  watch = [MachWatch, IlsColor]
  size = flex()
  pos = [pw(20), ph(74)]
  rendObj = ROBJ_TEXT
  color = IlsColor.value
  fontSize = 40
  text = string.format("%.2f", MachWatch.value / 100.0)
}

let AltitudeValue = Computed(@() (Altitude.value * metrToFeet / 10).tointeger())
let radioAlt = @() {
  watch = IlsColor
  size = [pw(12), ph(4)]
  pos = [pw(80), ph(74)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.value
  fillColor = Color(0, 0, 0, 0)
  lineWidth = baseLineWidth * IlsLineScale.value
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
      color = IlsColor.value
      fontSize = 40
      text = "R"
    },
    @() {
      watch = [AltitudeValue, IlsColor]
      size = SIZE_TO_CONTENT
      padding = [0, 5]
      rendObj = ROBJ_TEXT
      color = IlsColor.value
      fontSize = 40
      text = AltitudeValue.value < 100 ? string.format(",%02d0", AltitudeValue.value % 100) : string.format("%d,%02d0", AltitudeValue.value / 100, AltitudeValue.value % 100)
    }
  ]
}

let adlMarker = @() {
  watch = IlsColor
  rendObj = ROBJ_VECTOR_CANVAS
  size = [pw(3), ph(3)]
  color = IlsColor.value
  lineWidth = baseLineWidth * IlsLineScale.value
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
  size = [pw(70), ph(70)]
  pos = [pw(15), ph(30)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.value
  lineWidth = baseLineWidth * IlsLineScale.value
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
      color = IlsColor.value
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.value * 0.7
      commands = [
        [VECTOR_POLY, 50, 90, 48.5, 93, 51.5, 93]
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          rotate = clamp(Roll.value, -45, 45)
        }
      }
    }
  ]
}

let ilsMode = @() {
  watch = [IlsColor, isAAMMode, CCIPMode, BombingMode, ShellCnt, CurWeaponName]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(10), ph(82)]
  color = IlsColor.value
  fontSize = 40
  text = isAAMMode.value ? string.format("%d SRM", ShellCnt.value) : (BombingMode.value ? "CCRP" : (CannonMode.value ? "STRF" : (CCIPMode.value ? "CCIP" : "EEGS")))
}

let TargetAngle = Computed(@() cvt(RadarTargetAngle.value, -1.0, 1.0, 0, 180).tointeger())
let function aamReticle(width, height) {
  return @() {
    watch = isAAMMode
    size = flex()
    children = isAAMMode.value ? [
      @() {
        watch = IlsColor
        size = [pw(15), ph(15)]
        pos = [pw(50), ph(50)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth * IlsLineScale.value
        commands = [
          [VECTOR_ELLIPSE, 0, 0, 100, 100]
        ]
      },
      @() {
        watch = IlsColor
        size = [pw(5), ph(5)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth * IlsLineScale.value
        commands = [
          [VECTOR_POLY, -100, 0, 0, -100, 100, 0, 0, 100]
        ]
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            translate = IlsTrackerVisible.value ? [IlsTrackerX.value, IlsTrackerY.value] : [width * 0.5, height * 0.5]
          }
        }
      },
      @() {
        watch = IlsColor
        size = [pw(15), ph(15)]
        pos = [pw(50), ph(50)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth * IlsLineScale.value
        commands = [
          [VECTOR_POLY, 0, -100, -5, -110, 5, -110]
        ]
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            rotate = TargetAngle.value
            pivot = [0, 0]
          }
        }
      }
    ] : null
  }
}

let TargetDist = Computed(@() ((CCIPMode.value || BombingMode.value ? DistToTarget.value : (RadarTargetDist.value > 0 ? RadarTargetDist.value : -1)) * metrToFeet * 0.1).tointeger())
let dist = @() {
  watch = [TargetDist, isAAMMode, IlsColor]
  size = SIZE_TO_CONTENT
  pos = [pw(77), ph(83)]
  rendObj = ROBJ_TEXT
  color = IlsColor.value
  fontSize = 40
  text = isAAMMode.value && TargetDist.value <= 0 ? "XXX" : string.format("F%03d.%d", TargetDist.value <= 607 ? (TargetDist.value / 10) : (TargetDist.value * 10.0 * feetToNavMile), TargetDist.value <= 607 ? (TargetDist.value % 10) : (TargetDist.value * feetToNavMile * 100.0 % 10.0))
}

let DistMarkAngle = Computed(@() cvt(DistToTarget.value, 0, 3657.6, -90, 279).tointeger())
let function ccipGun(width, height) {
  return @() {
    watch = [CannonMode, TargetPosValid]
    size = flex()
    children = CannonMode.value && TargetPosValid.value ? [
      @() {
        watch = IlsColor
        size = [pw(10), ph(10)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth * IlsLineScale.value
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
            color = IlsColor.value
            fillColor = Color(0, 0, 0, 0)
            lineWidth = baseLineWidth * IlsLineScale.value
            commands = [
              [VECTOR_LINE, -60, -15, -60, 15],
              [VECTOR_LINE, 60, -15, 60, 15]
            ]
            behavior = Behaviors.RtPropUpdate
            update = @() {
              transform = {
                rotate = -Roll.value
                pivot = [0, 0]
              }
            }
          },
          @() {
            watch = [DistMarkAngle, IlsColor]
            size = flex()
            rendObj = ROBJ_VECTOR_CANVAS
            color = IlsColor.value
            fillColor = Color(0, 0, 0, 0)
            lineWidth = baseLineWidth * IlsLineScale.value
            commands = [
              [VECTOR_LINE, 100 * cos(degToRad(DistMarkAngle.value)), 100 * sin(degToRad(DistMarkAngle.value)), 80 * cos(degToRad(DistMarkAngle.value)), 80 * sin(degToRad(DistMarkAngle.value))],
              [VECTOR_SECTOR, 0, 0, 80, 80, -90, DistMarkAngle.value]
            ]
          }
        ]
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            translate = [TargetPos.value[0], TargetPos.value[1]]
          }
        }
      },
      @() {
        watch = [TargetPos, IlsColor]
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
        commands = [
          [VECTOR_LINE, AdlPoint[0] / width * 100, AdlPoint[1] / height * 100,
           TargetPos.value[0] / width * 100,
           TargetPos.value[1] / height * 100]
        ]
      }
    ] : null
  }
}


let function ccipShell(width, height) {
  return @() {
    watch = [RocketMode, BombCCIPMode, TargetPosValid]
    size = flex()
    children = (RocketMode.value || BombCCIPMode.value) && TargetPosValid.value ? [
      @() {
        watch = IlsColor
        size = [pw(3), ph(3)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth * IlsLineScale.value
        commands = [
          [VECTOR_ELLIPSE, 0, 0, 100, 100],
          [VECTOR_LINE, 0, 0, 0, 0],
        ]
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            translate = [TargetPos.value[0], TargetPos.value[1]]
          }
        }
      },
      (BombCCIPMode.value ? @() {
        watch = [TargetPos, IlsColor]
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
        commands = [
          [VECTOR_LINE, TvvMark[0] / width * 100, TvvMark[1] / height * 100,
          TargetPos.value[0] / width * 100,
          TargetPos.value[1] / height * 100]
        ]
      } : null)
    ] : null
  }
}

let gunfireSolution = @() {
  watch = [RadarTargetPosValid, CCIPMode, isAAMMode]
  size = flex()
  children = RadarTargetPosValid.value && !CCIPMode.value && !isAAMMode.value ? [
    @() {
      watch = IlsColor
      rendObj = ROBJ_VECTOR_CANVAS
      size = [pw(1), ph(1)]
      color = IlsColor.value
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.value
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

let HasRadarTarget = Computed(@() RadarTargetDist.value > 0)
let OrientationSector = Computed(@() cvt(Tangage.value, -45.0, 45.0, 160, 20).tointeger())
let orientation = @() {
  watch = [HasRadarTarget, CCIPMode, isAAMMode]
  size = flex()
  children = HasRadarTarget.value && !CCIPMode.value && !isAAMMode.value ? [
    @() {
      watch = [OrientationSector, IlsColor]
      rendObj = ROBJ_VECTOR_CANVAS
      size = [pw(20), ph(20)]
      pos = [pw(50), ph(50)]
      color = IlsColor.value
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.value
      commands = [
        [VECTOR_SECTOR, 0, 0, 100, 100, 90 - OrientationSector.value, 90 + OrientationSector.value],
        [VECTOR_LINE, 100 * cos(degToRad(90 - OrientationSector.value)), 100 * sin(degToRad(90 - OrientationSector.value)),
         110 * cos(degToRad(90 - OrientationSector.value)), 110 * sin(degToRad(90 - OrientationSector.value))],
        [VECTOR_LINE, 100 * cos(degToRad(90 + OrientationSector.value)), 100 * sin(degToRad(90 + OrientationSector.value)),
         110 * cos(degToRad(90 + OrientationSector.value)), 110 * sin(degToRad(90 + OrientationSector.value))]
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          rotate = -Roll.value
          pivot = [0, 0]
        }
      }
    }
  ] : null
}

let RadarDistMarkAngle = Computed(@() cvt(RadarTargetDist.value, 0, 3657.6, 0.0, 360.0).tointeger())
let radarMark = @() {
  watch = [RadarTargetPosValid, isAAMMode]
  size = flex()
  children = RadarTargetPosValid.value ? [
    (isAAMMode.value ? @() {
      watch = IlsColor
      size = [pw(5), ph(5)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.value
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.value
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
      size = [pw(5), ph(5)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.value
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.value
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
          size = [baseLineWidth * IlsLineScale.value, ph(30)]
          pos = [-baseLineWidth * IlsLineScale.value * 0.5, ph(-100)]
          rendObj = ROBJ_SOLID
          color = IlsColor.value
          behavior = Behaviors.RtPropUpdate
          update = @() {
            transform = {
              rotate = RadarDistMarkAngle.value
              pivot = [0.5, 3.33]
            }
          }
        },
        @() {
          watch = [RadarDistMarkAngle, IlsColor]
          size = flex()
          rendObj = ROBJ_VECTOR_CANVAS
          color = IlsColor.value
          fillColor = Color(0, 0, 0, 0)
          lineWidth = baseLineWidth * IlsLineScale.value
          commands = [
            [VECTOR_SECTOR, 0, 0, 100, 100, -90, RadarDistMarkAngle.value - 90]
          ]
        },
        @() {
          watch = IlsColor
          size = flex()
          rendObj = ROBJ_VECTOR_CANVAS
          color = IlsColor.value
          fillColor = Color(0, 0, 0, 0)
          lineWidth = baseLineWidth * IlsLineScale.value * 0.5
          commands = [
            [VECTOR_POLY, 0, -100, -15, -130, 15, -130]
          ]
          behavior = Behaviors.RtPropUpdate
          update = @() {
            transform = {
              rotate = TargetAngle.value
              pivot = [0, 0]
            }
          }
        }
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = [RadarTargetPos[0], RadarTargetPos[1]]
        }
      }
    })
  ] : null
}

let function angleTxt(num, isLeft, invVPlace = 1, x = 0, y = 0) {
  return @() {
    watch = IlsColor
    pos = [x, y]
    rendObj = ROBJ_TEXT
    vplace = (num * invVPlace) < 0 ? ALIGN_BOTTOM : ALIGN_TOP
    hplace = isLeft ? ALIGN_LEFT : ALIGN_RIGHT
    color = IlsColor.value
    fontSize = 40
    font = Fonts.hud
    text = abs(num).tostring()
  }
}

let function generatePitchLine(num) {
  let sign = num > 0 ? 1 : -1
  let newNum = num >= 0 ? num : (num - 5)
  let lineAngle =  num > 0 ? 0 : degToRad(min(20, newNum / 4))
  let offset = num > 0 ? 0 : (30.0 * sin(degToRad(min(20, newNum / 4))))
  return {
    size = [pw(60), ph(50)]
    pos = [pw(20), 0]
    flow = FLOW_VERTICAL
    children = num == 0 ? [
      @() {
        watch = IlsColor
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.value
        color = IlsColor.value
        padding = [0, 10]
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
        lineWidth = baseLineWidth * IlsLineScale.value
        color = IlsColor.value
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


let function pitch(width, height, generateFunc) {
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
        translate = [0, -height * (90.0 - Tangage.value) * 0.05]
        rotate = -Roll.value
        pivot = [0.5, (90.0 - Tangage.value) * 0.1]
      }
    }
  }
}

let function TvvLinked(width, height) {
  return @() {
    watch = [HasRadarTarget, isAAMMode, CCIPMode, BombingMode]
    size = flex()
    children = [
      @() {
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        size = [pw(6), ph(6)]
        color = IlsColor.value
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth * IlsLineScale.value
        commands = [
          [VECTOR_ELLIPSE, 0, 0, 30, 30],
          [VECTOR_LINE, -30, 0, -100, 0],
          [VECTOR_LINE, 30, 0, 100, 0],
          [VECTOR_LINE, 0, -30, 0, -70]
        ]
      },
      (!HasRadarTarget.value || isAAMMode.value || CCIPMode.value || BombingMode.value ? pitch(width, height, generatePitchLine) : null)
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [TvvMark[0], TvvMark[1]]
      }
    }
  }
}

let function Elbit967(width, height) {
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
      radarMark,
      gunfireSolution,
      compassWrap(width, height, 0.05, generateCompassMarkElbit, 1.0),
      @() {
        watch = IlsColor
        rendObj = ROBJ_SOLID
        size = [baseLineWidth * IlsLineScale.value, ph(5)]
        pos = [pw(50), 0]
        color = IlsColor.value
      },
      orientation
    ]
  }
}

return Elbit967