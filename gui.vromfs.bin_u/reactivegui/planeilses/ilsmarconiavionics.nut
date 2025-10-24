from "%rGui/globals/ui_library.nut" import *
let { floor, abs } = require("%sqstd/math.nut")
let { IlsColor, IlsLineScale, TvvMark, RadarTargetPosValid, RadarTargetDist,
  RadarTargetDistRate, RocketMode, CannonMode, BombCCIPMode, BombingMode,
  RadarTargetPos, TargetPos, TargetPosValid, TimeBeforeBombRelease, DistToTarget } = require("%rGui/planeState/planeToolsState.nut")
let { baseLineWidth, mpsToKnots, metrToFeet, metrToNavMile } = require("%rGui/planeIlses/ilsConstants.nut")
let { GuidanceLockResult } = require("guidanceConstants")
let { Tangage, VertOverload, Altitude, Speed, Roll, Mach, MaxOverload } = require("%rGui/planeState/planeFlyState.nut")
let string = require("string")
let { AdlPoint } = require("%rGui/planeState/planeWeaponState.nut")
let { compassWrap, generateCompassMarkSU145 } = require("%rGui/planeIlses/ilsCompasses.nut")
let { IlsTrackerVisible, IlsTrackerX, IlsTrackerY, GuidanceLockState } = require("%rGui/rocketAamAimState.nut")

let isAAMMode = Computed(@() GuidanceLockState.get() > GuidanceLockResult.RESULT_STANDBY)
let CCIPMode = Computed(@() RocketMode.get() || CannonMode.get() || BombCCIPMode.get())


function pitch(width, height, generateFunc) {
  const step = 2.5
  let children = []

  for (local i = 90.0 / step; i >= -90.0 / step; --i) {
    let num = i * step

    children.append(generateFunc(num))
  }

  return {
    size = [width * 0.5, height * 0.5]
    pos = [-width * 0.25, 0]
    flow = FLOW_VERTICAL
    children = children
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, -height * (90.0 - Tangage.get()) * 0.08]
        rotate = -Roll.get()
        pivot = [0.5, (90.0 - Tangage.get()) * 0.16]
      }
    }
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
    fontSize = 45
    font = Fonts.hud
    text = string.format("%d", num)
  }
}

function generatePitchLine(num) {
  let sign = num > 0 ? 1 : -1
  let newNum = num >= 0 ? num : (num - 2.5)
  return {
    size = const [pw(60), ph(40)]
    pos = [pw(20), 0]
    flow = FLOW_VERTICAL
    children = num == 0 ? [
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.get()
        color = IlsColor.get()
        padding = const [0, 10]
        commands = [
          [VECTOR_LINE, -20, 0, 30, 0],
          [VECTOR_LINE, 70, 0, 120, 0]
        ]
      }
    ] :
    [
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.get()
        color = IlsColor.get()
        commands = [
          [VECTOR_LINE, 0, 5 * sign, 0, 0],
          [VECTOR_LINE, 0, 0, num > 0 ? 30 : 5, 0],
          (num < 0 ? [VECTOR_LINE, 10, 0, 17, 0] : []),
          (num < 0 ? [VECTOR_LINE, 23, 0, 30, 0] : []),
          [VECTOR_LINE, 100, 5 * sign, 100, 0],
          [VECTOR_LINE, 100, 0, num > 0 ? 70 : 95, 0],
          (num < 0 ? [VECTOR_LINE, 90, 0, 83, 0] : []),
          (num < 0 ? [VECTOR_LINE, 77, 0, 70, 0] : [])
        ]
        children = newNum <= 90 && newNum % 5 == 0 ? [angleTxt(newNum, true, 1, pw(-25)), angleTxt(newNum, false, 1, pw(25))] : null
      }
    ]
  }
}

function KaiserTvvLinked(width, height) {
  return @() {
    watch = isAAMMode
    size = flex()
    children = [
      @() {
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        size = const [pw(4), ph(4)]
        color = IlsColor.get()
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth * IlsLineScale.get()
        commands = [
          [VECTOR_ELLIPSE, 0, 0, 50, 50],
          [VECTOR_LINE, -50, 0, -100, 0],
          [VECTOR_LINE, 50, 0, 100, 0],
          [VECTOR_LINE, 0, -50, 0, -80]
        ]
      },
      (!isAAMMode.get() ? pitch(width, height, generatePitchLine) : null)
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [TvvMark[0], TvvMark[1]]
      }
    }
  }
}

let adlMarker = @() {
  watch = IlsColor
  rendObj = ROBJ_VECTOR_CANVAS
  size = const [pw(3), ph(3)]
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

let generateSpdMark = function(num) {
  let ofs = num < 10 ? pw(-15) : pw(-30)
  return {
    size = const [pw(100), ph(7.5)]
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
    size = const [pw(100), ph(100)]
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

function speedWrap(width, height, generateFunc) {
  return {
    size = [width * 0.17, height * 0.5]
    pos = [width * 0.1, height * 0.2]
    clipChildren = true
    children = [
      speed(height * 0.5, generateFunc),
      @() {
        size = [pw(25), baseLineWidth * IlsLineScale.get()]
        pos = [pw(70), ph(50)]
        watch = IlsColor
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
        text = "G"
      }
    ]
  }
}

let generateAltMark = function(num) {
  return {
    size = const [pw(100), ph(7.5)]
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

  let getOffset = @() ((65000 - Altitude.get() * metrToFeet) * 0.0007425 - 0.48) * height
  return {
    size = const [pw(100), ph(100)]
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
  return {
    size = [width * 0.17, height * 0.5]
    pos = [width * 0.75, height * 0.2]
    clipChildren = true
    children = [
      altitude(height * 0.5, generateFunc)
    ]
  }
}

let OverloadWatch = Computed(@() (floor(VertOverload.get() * 10)).tointeger())
let overload = @() {
  watch = [OverloadWatch, IlsColor]
  size = flex()
  pos = [pw(20), ph(20)]
  rendObj = ROBJ_TEXT
  color = IlsColor.get()
  fontSize = 40
  text = string.format("%.1f", OverloadWatch.get() / 10.0)
}

let MaxOverloadWatch = Computed(@() (floor(MaxOverload.get() * 10)).tointeger())
let maxOverload = @() {
  watch = [MaxOverloadWatch, IlsColor, BombingMode]
  size = flex()
  pos = [pw(15), ph(78)]
  rendObj = ROBJ_TEXT
  color = IlsColor.get()
  fontSize = 40
  text = string.format("%.1f", MaxOverloadWatch.get() / 10.0)
}

let armLabel = @() {
  watch = IlsColor
  size = flex()
  pos = [pw(22), ph(70)]
  rendObj = ROBJ_TEXT
  color = IlsColor.get()
  fontSize = 35
  text = "ARM"
}

let MachWatch = Computed(@() (floor(Mach.get() * 100)).tointeger())
let mach = @() {
  watch = [MachWatch, IlsColor]
  size = flex()
  pos = [pw(22), ph(74)]
  rendObj = ROBJ_TEXT
  color = IlsColor.get()
  fontSize = 35
  text = string.format("%.2f", MachWatch.get() / 100.0)
}

function radarTarget(width, height) {
  return @() {
    watch = IlsColor
    size = const [pw(8), ph(8)]
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.get()
    fillColor = Color(0, 0, 0, 0)
    lineWidth = baseLineWidth * IlsLineScale.get()
    commands = [
      [VECTOR_RECTANGLE, -50, -50, 100, 100]
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
  }
}

let radarDist = Computed(@() (RadarTargetDist.get() * metrToNavMile * 10).tointeger())
let raderClosureSpeed = Computed(@() (RadarTargetDistRate.get() * mpsToKnots * -1.0).tointeger())
function radarTargetDist(width, height) {
  return @() {
    watch = [RadarTargetPosValid, BombingMode]
    size = flex()
    children = RadarTargetPosValid.get() && !BombingMode.get() ?
    [
      {
        size = flex()
        children = [
          @() {
            watch = [IlsColor, radarDist]
            size = SIZE_TO_CONTENT
            rendObj = ROBJ_TEXT
            pos = [pw(72), ph(70)]
            color = IlsColor.get()
            fontSize = 35
            text = string.format("%02d.%d", radarDist.get() / 10, radarDist.get() % 10)
          },
          @() {
            watch = [IlsColor, raderClosureSpeed]
            pos = [pw(72), ph(74)]
            size = SIZE_TO_CONTENT
            rendObj = ROBJ_TEXT
            color = IlsColor.get()
            fontSize = 35
            text = raderClosureSpeed.get().tostring()
          }
        ]
      },
      radarTarget(width, height)
    ] : null
  }
}

let ilsMode = @() {
  watch = [IlsColor, isAAMMode, CCIPMode, BombingMode]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(15), ph(82)]
  color = IlsColor.get()
  fontSize = 35
  text = isAAMMode.get() ? "MSLS" : (BombingMode.get() ? "CCRP" : (CCIPMode.get() ? "CCIP" : "LCOS"))
}

let AamIsReady = Computed(@() GuidanceLockState.get() == GuidanceLockResult.RESULT_TRACKING)
let aamCircle = @() {
  watch = IlsTrackerVisible
  size = flex()
  children = IlsTrackerVisible.get() ? [
    @() {
      watch = [AamIsReady, IlsColor]
      size = const [pw(10), ph(10)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.get()
      commands = [
        [VECTOR_LINE, -10, 0, 0, -10],
        [VECTOR_LINE, 10, 0, 0, 10],
        [VECTOR_LINE, 0, -10, 10, 0],
        [VECTOR_LINE, 0, 10, -10, 0],
      ]
      children = AamIsReady.get() ? [
        @() {
          watch = IlsColor
          key = $"AamIlsAnim_1"
          size = flex()
          rendObj = ROBJ_VECTOR_CANVAS
          color = IlsColor.get()
          fillColor = Color(0, 0, 0, 0)
          lineWidth = baseLineWidth * IlsLineScale.get()
          commands = [
            [VECTOR_ELLIPSE, 0, 0, 100, 100],
            [VECTOR_LINE, -115, 0, -100, 0],
            [VECTOR_LINE, 0, -115, 0, -100]
          ]
          animations = [
            { prop = AnimProp.opacity, from = -1, to = 1, duration = 0.5, play = true, loop = true }
          ]
        }
      ] : [
        @() {
          watch = IlsColor
          key = $"AamIlsAnim_0"
          size = flex()
          rendObj = ROBJ_VECTOR_CANVAS
          color = IlsColor.get()
          fillColor = Color(0, 0, 0, 0)
          lineWidth = baseLineWidth * IlsLineScale.get()
          commands = [
            [VECTOR_ELLIPSE, 0, 0, 100, 100],
            [VECTOR_LINE, -115, 0, -100, 0],
            [VECTOR_LINE, 0, -115, 0, -100]
          ]
        }
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

let LCOSwatch = Computed(@() !isAAMMode.get() && !CCIPMode.get() && !BombingMode.get())
let lcos = @() {
  watch = LCOSwatch
  size = flex()
  children = LCOSwatch.get() ? [
    @() {
      watch = IlsColor
      size = const [pw(10), ph(10)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      lineWidth = baseLineWidth * IlsLineScale.get()
      fillColor = Color(0, 0, 0, 0)
      commands = [
        [VECTOR_ELLIPSE, 0, 0, 100, 100],
        [VECTOR_ELLIPSE, 0, 0, 10, 10],
        [VECTOR_LINE, 0, -100, 0, -110],
        [VECTOR_LINE, 100, 0, 110, 0]
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = TargetPos.get()
        }
      }
    }
  ] : null
}

function ccip(width, height) {
  return @() {
    watch = [CCIPMode, TargetPosValid]
    size = flex()
    children = CCIPMode.get() && TargetPosValid.get() ?
    [
      @() {
        watch = IlsColor
        size = pw(3)
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
            translate = TargetPos.get()
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
          [VECTOR_LINE, TvvMark[0] / width * 100, TvvMark[1] / height * 100,
           TargetPos.get()[0] / width * 100,
           TargetPos.get()[1] / height * 100]
        ]
      }
    ] : null
  }
}

let TimeToRelease = Computed(@() TimeBeforeBombRelease.get() < 100.0 ? TimeBeforeBombRelease.get().tointeger() : 999)
let DistToTargetCcrp = Computed(@() (DistToTarget.get() * metrToNavMile * 10.0).tointeger())
function ccrp(height) {
  return @() {
    watch = [BombingMode, TargetPosValid]
    size = flex()
    children = BombingMode.get() && TargetPosValid.get() ? [
      @() {
        watch = IlsColor
        size = const [pw(4), ph(4)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.get()
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth * IlsLineScale.get()
        commands = [
          [VECTOR_LINE, 0, 0, 0, 0],
          [VECTOR_WIDTH, baseLineWidth * IlsLineScale.get() * 0.8],
          [VECTOR_RECTANGLE, -50, -50, 100, 100]
        ]
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            translate = TargetPos.get()
          }
        }
      },
      @() {
        watch = [TargetPosValid, IlsColor]
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * 0.8 * IlsLineScale.get()
        size = flex()
        color = IlsColor.get()
        commands = [
          (TargetPosValid.get() ? [VECTOR_LINE, 0, 100, 0, -100] : [])
        ]
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            translate = TargetPosValid.get() ? [TargetPos.get()[0], clamp(TargetPos.get()[1], 0, height)] : [TargetPos.get()[0], height]
            rotate = -Roll.get()
            pivot = [0, 0]
          }
        }
      },
      @() {
        watch = [IlsColor, DistToTargetCcrp]
        size = SIZE_TO_CONTENT
        rendObj = ROBJ_TEXT
        pos = [pw(72), ph(70)]
        color = IlsColor.get()
        fontSize = 35
        text = string.format("%02d.%dNM", DistToTargetCcrp.get() / 10, DistToTargetCcrp.get() % 10)
      },
      @() {
        watch = [IlsColor, TimeToRelease]
        pos = [pw(72), ph(74)]
        size = SIZE_TO_CONTENT
        rendObj = ROBJ_TEXT
        color = IlsColor.get()
        fontSize = 35
        text = string.format("%dSEC", TimeToRelease.get())
      }
    ] : null
  }
}

function MarconiAvionics(width, height) {
  return {
    size = [width, height]
    children = [
      KaiserTvvLinked(width, height),
      adlMarker,
      speedWrap(width, height, generateSpdMark),
      altWrap(width, height, generateAltMark),
      @() {
        watch = IlsColor
        size = [pw(4), baseLineWidth * IlsLineScale.get()]
        pos = [pw(72), ph(45)]
        rendObj = ROBJ_SOLID
        color = IlsColor.get()
      },
      overload,
      maxOverload,
      compassWrap(width, height, 0.86, generateCompassMarkSU145, 0.8, 5.0, false, 12),
      @() {
        watch = IlsColor
        size = [baseLineWidth * IlsLineScale.get(), ph(4)]
        pos = [pw(50), ph(95)]
        rendObj = ROBJ_SOLID
        color = IlsColor.get()
      },
      armLabel,
      mach,
      radarTargetDist(width, height),
      ilsMode,
      aamCircle,
      lcos,
      ccip(width, height),
      ccrp(height)
    ]
  }
}

return MarconiAvionics