from "%rGui/globals/ui_library.nut" import *

let string = require("string")
let { Speed, ClimbSpeed, Mach, Tas, Aoa, Overload, Altitude } = require("%rGui/planeState/planeFlyState.nut");
let { IlsColor, TargetPosValid, TargetPos, CannonMode, RadarTargetPos, RadarTargetPosValid,
        BombCCIPMode, RocketMode, IlsLineScale } = require("%rGui/planeState/planeToolsState.nut")
let { mpsToKmh, baseLineWidth } = require("%rGui/planeIlses/ilsConstants.nut")
let { GuidanceLockResult } = require("guidanceConstants")
let { compassWrap, generateCompassMarkJ8 } = require("%rGui/planeIlses/ilsCompasses.nut")
let { TrackerVisible, GuidanceLockState, IlsTrackerX, IlsTrackerY } = require("%rGui/rocketAamAimState.nut")
let { flyDirection, angleTxt, shimadzuRoll, ShimadzuPitch, ShimadzuAlt, aimMark } = require("%rGui/planeIlses/commonElements.nut")
let { floor, abs } = require("%sqstd/math.nut")

let CCIPMode = Computed(@() RocketMode.get() || CannonMode.get() || BombCCIPMode.get())
let OverloadWatch = Computed(@() (floor(Overload.get() * 10)).tointeger())

let generateSpdMarkJ8 = function(num) {
  return {
    size = static [pw(100), ph(7.5)]
    pos = [pw(40), 0]
    children = [
      (num % 5 > 0 ? null :
        @() {
          watch = IlsColor
          size = flex()
          pos = [pw(-40), 0]
          rendObj = ROBJ_TEXT
          color = IlsColor.get()
          vplace = ALIGN_CENTER
          fontSize = 40
          font = Fonts.hud
          text = string.format("%03d", num)
        }
      ),
      @() {
        watch = IlsColor
        pos = [(num % 5 > 0 ? baseLineWidth * 2 : 0), ph(25)]
        size = [baseLineWidth * (num % 5 > 0 ? 5 : 7), baseLineWidth * IlsLineScale.get()]
        rendObj = ROBJ_SOLID
        color = IlsColor.get()
        lineWidth = baseLineWidth * IlsLineScale.get()
      }
    ]
  }
}

function J8Speed(height, generateFunc) {
  let children = []

  for (local i = 250; i >= 0; --i) {
    children.append(generateFunc(i))
  }

  let getOffset = @() ((2500 - Speed.get() * mpsToKmh) * 0.007425 - 0.5) * height
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

function J8SpeedWrap(width, height, generateFunc) {
  return {
    size = [width * 0.17, height * 0.5]
    pos = [width * 0.08, height * 0.25]
    clipChildren = true
    children = [
      J8Speed(height * 0.5, generateFunc)
    ]
  }
}

let MachWatchJ8 = Computed(@() (floor(Mach.get() * 10)).tointeger())
let TasWatch = Computed(@() (Tas.get() * mpsToKmh).tointeger())
let J8FlyInfo = @() {
  size = SIZE_TO_CONTENT
  pos = [pw(11), ph(12)]
  flow = FLOW_VERTICAL
  children = [
    @() {
      watch = [OverloadWatch, IlsColor]
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      fontSize = 40
      font = Fonts.hud
      text = string.format("G%.1f", OverloadWatch.get() / 10.0)
    },
    @() {
      watch = [MachWatchJ8, IlsColor]
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      fontSize = 40
      font = Fonts.hud
      text = string.format("M%.1f0", Mach.get())
    },
    @() {
      watch = [TasWatch, IlsColor]
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      fontSize = 40
      font = Fonts.hud
      text = string.format("TS%d", TasWatch.get())
    }
  ]
}

let AoaWatch = Computed(@() Aoa.get().tointeger())
let J8AoaInfo = @() {
  size = SIZE_TO_CONTENT
  pos = [pw(20), ph(46)]
  flow = FLOW_VERTICAL
  children = [
    @() {
      watch = [AoaWatch, IlsColor]
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      fontSize = 40
      font = Fonts.hud
      text = string.format(AoaWatch.get() >= 0 ? "+%02d" : "-%02d", abs(AoaWatch.get()))
    },
    @() {
      watch = IlsColor
      rendObj = ROBJ_SOLID
      size = [baseLineWidth * 12, baseLineWidth * IlsLineScale.get()]
      color = IlsColor.get()
    },
    @() {
      watch = IlsColor
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      fontSize = 40
      font = Fonts.hud
      text = "A"
      hplace = ALIGN_CENTER
    }
  ]
}

let ClimbJ8Watch = Computed(@() clamp(ClimbSpeed.get(), -99.0, 99.0).tointeger())
let J8ClimbInfo = @() {
  size = SIZE_TO_CONTENT
  pos = [pw(75), ph(46)]
  flow = FLOW_VERTICAL
  children = [
    @() {
      watch = [ClimbJ8Watch, IlsColor]
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      fontSize = 40
      font = Fonts.hud
      text = string.format(ClimbJ8Watch.get() >= 0 ? "+%02d" : "-%02d", abs(ClimbJ8Watch.get()))
    },
    @() {
      watch = IlsColor
      rendObj = ROBJ_SOLID
      size = [baseLineWidth * 12, baseLineWidth * IlsLineScale.get()]
      color = IlsColor.get()
    },
    @() {
      watch = IlsColor
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      fontSize = 40
      font = Fonts.hud
      text = "H"
      hplace = ALIGN_CENTER
    }
  ]
}

function generatePitchLineJ8(num) {
  let sign = num > 0 ? 1 : -1
  let newNum = num >= 0 ? num : (num - 5)
  return {
    size = static [pw(60), ph(50)]
    pos = [pw(20), 0]
    flow = FLOW_VERTICAL
    children = num == 0 ? [
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.get()
        color = IlsColor.get()
        padding = static [0, 10]
        commands = [
          [VECTOR_LINE, -20, 0, 30, 0],
          [VECTOR_LINE, 70, 0, 120, 0]
        ]
        children = [angleTxt(-5, true, Fonts.hud, 1, 45, pw(-25)), angleTxt(-5, false, Fonts.hud, 1, 45, pw(25))]
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
        children = newNum <= 90 ? [angleTxt(newNum, true, Fonts.hud, 1, 45, pw(-25)), angleTxt(newNum, false, Fonts.hud, 1, 45, pw(25))] : null
      }
    ]
  }
}

let generateAltMarkJ8 = function(num) {
  return {
    size = static [pw(100), ph(7.5)]
    flow = FLOW_HORIZONTAL
    children = [
      @() {
        watch = IlsColor
        size = [baseLineWidth * (num % 50 > 0 ? 5 : 7), baseLineWidth * IlsLineScale.get()]
        rendObj = ROBJ_SOLID
        color = IlsColor.get()
        lineWidth = baseLineWidth * IlsLineScale.get()
        vplace = ALIGN_CENTER
      },
      (num % 50 > 0 ? null :
        @() {
          watch = IlsColor
          size = flex()
          rendObj = ROBJ_TEXT
          color = IlsColor.get()
          vplace = ALIGN_CENTER
          fontSize = 40
          font = Fonts.hud
          text = string.format(num < 1000 ? "0%.1f" : "%.1f", num / 100.0)
        }
      )
    ]
  }
}

function J8AltWrap(width, height, generateFunc) {
  return {
    size = [width * 0.17, height * 0.5]
    pos = [width * 0.83, height * 0.25]
    clipChildren = true
    children = [
      ShimadzuAlt(height * 0.5, generateFunc)
    ]
  }
}

let altValue = Computed(@() (Altitude.get()).tointeger())
let J8AltInfo = @() {
  size = SIZE_TO_CONTENT
  pos = [pw(81), ph(16)]
  flow = FLOW_VERTICAL
  children = [
    @() {
      watch = [altValue, IlsColor]
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      fontSize = 40
      font = Fonts.hud
      text = string.format("H%d", altValue.get())
    },
    @() {
      watch = IlsColor
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      fontSize = 40
      font = Fonts.hud
      text = "760.0"
    }
  ]
}

let J8AirAimMark = {
  size = flex()
  children =
    @() {
      watch = IlsColor
      size = static [pw(4), ph(3)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      lineWidth = baseLineWidth * IlsLineScale.get()
      commands = [
        [VECTOR_LINE, 0, -20, 0, -100],
        [VECTOR_LINE, 0, 20, 0, 100],
        [VECTOR_LINE, 20, 0, 50, 0],
        [VECTOR_LINE, 70, 0, 100, 0],
        [VECTOR_LINE, -20, 0, -50, 0],
        [VECTOR_LINE, -70, 0, -100, 0]
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = [TargetPos.get()[0], TargetPos.get()[1]]
        }
      }
    }
}

function radarTarget(width, height) {
  return @() {
    watch = RadarTargetPosValid
    size = flex()
    children = RadarTargetPosValid.get() ?
      @() {
        watch = IlsColor
        size = static [pw(8), ph(8)]
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
      } : null
  }
}

let J8AamMode = @() {
  watch = GuidanceLockState
  size = flex()
  children = [
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
    },
    (GuidanceLockState.value == GuidanceLockResult.RESULT_TRACKING ?
    @() {
      watch = IlsColor
      size = static [pw(5), ph(5)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.get()
      commands = [
        [VECTOR_LINE, 0, -100, 100, 0],
        [VECTOR_LINE, 100, 0, 0, 100],
        [VECTOR_LINE, 0, 100, -100, 0],
        [VECTOR_LINE, 0, -100, -100, 0]
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = [IlsTrackerX.get(), IlsTrackerY.get()]
        }
      }
    } : null)
  ]
}

let TP0 = Computed(@() TargetPos.get()[0].tointeger())
let TP1 = Computed(@() TargetPos.get()[1].tointeger())
function J8BombImpactLine(width, height) {
  return @() {
    watch = [TargetPosValid, BombCCIPMode, TP0, TP1, IlsColor]
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth * 0.8 * IlsLineScale.get()
    size = flex()
    color = IlsColor.get()
    commands = [
      (TargetPosValid.get() && BombCCIPMode.get() ? [VECTOR_LINE, 50, 50, TP0.get() / width * 100, TP1.get() / height * 100] : [])
    ]
  }
}

function J8IIHK(width, height) {
  return {
    size = [width, height]
    children = [
      flyDirection(width, height, true),
      shimadzuRoll(20),
      J8SpeedWrap(width, height, generateSpdMarkJ8),
      J8FlyInfo,
      J8AoaInfo,
      ShimadzuPitch(width, height, generatePitchLineJ8),
      J8AltWrap(width, height, generateAltMarkJ8),
      J8ClimbInfo,
      J8AltInfo,
      compassWrap(width, height, 0.05, generateCompassMarkJ8, 0.6),
      radarTarget(width, height),
      @() {
        watch = IlsColor
        pos = [pw(15), ph(75)]
        rendObj = ROBJ_TEXT
        color = IlsColor.get()
        fontSize = 40
        font = Fonts.hud
        text = "IS"
      },
      @() {
        watch = IlsColor
        pos = [pw(85), ph(75)]
        rendObj = ROBJ_TEXT
        color = IlsColor.get()
        fontSize = 40
        font = Fonts.hud
        text = "B"
      },
      @() {
        watch = IlsColor
        pos = [width * 0.5 - baseLineWidth * IlsLineScale.get() * 0.5, ph(13)]
        size = [baseLineWidth * IlsLineScale.get(), baseLineWidth * 5]
        rendObj = ROBJ_SOLID
        color = IlsColor.get()
      },
      (CCIPMode.get() ? aimMark : J8AirAimMark),
      (TrackerVisible.get() ? J8AamMode : null),
      J8BombImpactLine(width, height)
    ]
  }
}

return J8IIHK