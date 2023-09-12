from "%rGui/globals/ui_library.nut" import *

let string = require("string")
let { Speed, ClimbSpeed, Mach, Tas, Aoa, Overload, Altitude } = require("%rGui/planeState/planeFlyState.nut");
let { IlsColor, TargetPosValid, TargetPos, CannonMode,
        BombCCIPMode, RocketMode, IlsLineScale } = require("%rGui/planeState/planeToolsState.nut")
let { mpsToKmh, baseLineWidth } = require("ilsConstants.nut")
let { GuidanceLockResult } = require("%rGui/guidanceConstants.nut")
let { compassWrap, generateCompassMarkJ8 } = require("ilsCompasses.nut")
let { TrackerVisible, GuidanceLockState, IlsTrackerX, IlsTrackerY } = require("%rGui/rocketAamAimState.nut")
let { flyDirection, angleTxt, shimadzuRoll, ShimadzuPitch, ShimadzuAlt, aimMark } = require("commonElements.nut")
let { floor, abs } = require("%sqstd/math.nut")

let CCIPMode = Computed(@() RocketMode.value || CannonMode.value || BombCCIPMode.value)
let OverloadWatch = Computed(@() (floor(Overload.value * 10)).tointeger())

let generateSpdMarkJ8 = function(num) {
  return {
    size = [pw(100), ph(7.5)]
    pos = [pw(40), 0]
    children = [
      (num % 5 > 0 ? null :
        @() {
          watch = IlsColor
          size = flex()
          pos = [pw(-40), 0]
          rendObj = ROBJ_TEXT
          color = IlsColor.value
          vplace = ALIGN_CENTER
          fontSize = 40
          font = Fonts.hud
          text = string.format("%03d", num)
        }
      ),
      @() {
        watch = IlsColor
        pos = [(num % 5 > 0 ? baseLineWidth * 2 : 0), ph(25)]
        size = [baseLineWidth * (num % 5 > 0 ? 5 : 7), baseLineWidth * IlsLineScale.value]
        rendObj = ROBJ_SOLID
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
      }
    ]
  }
}

let function J8Speed(height, generateFunc) {
  let children = []

  for (local i = 250; i >= 0; --i) {
    children.append(generateFunc(i))
  }

  let getOffset = @() ((2500 - Speed.value * mpsToKmh) * 0.007425 - 0.5) * height
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

let function J8SpeedWrap(width, height, generateFunc) {
  return {
    size = [width * 0.17, height * 0.5]
    pos = [width * 0.08, height * 0.25]
    clipChildren = true
    children = [
      J8Speed(height * 0.5, generateFunc)
    ]
  }
}

let MachWatchJ8 = Computed(@() (floor(Mach.value * 10)).tointeger())
let TasWatch = Computed(@() (Tas.value * mpsToKmh).tointeger())
let J8FlyInfo = @() {
  size = SIZE_TO_CONTENT
  pos = [pw(11), ph(12)]
  flow = FLOW_VERTICAL
  children = [
    @() {
      watch = [OverloadWatch, IlsColor]
      rendObj = ROBJ_TEXT
      color = IlsColor.value
      fontSize = 40
      font = Fonts.hud
      text = string.format("G%.1f", OverloadWatch.value / 10.0)
    },
    @() {
      watch = [MachWatchJ8, IlsColor]
      rendObj = ROBJ_TEXT
      color = IlsColor.value
      fontSize = 40
      font = Fonts.hud
      text = string.format("M%.1f0", Mach.value)
    },
    @() {
      watch = [TasWatch, IlsColor]
      rendObj = ROBJ_TEXT
      color = IlsColor.value
      fontSize = 40
      font = Fonts.hud
      text = string.format("TS%d", TasWatch.value)
    }
  ]
}

let AoaWatch = Computed(@() Aoa.value.tointeger())
let J8AoaInfo = @() {
  size = SIZE_TO_CONTENT
  pos = [pw(20), ph(46)]
  flow = FLOW_VERTICAL
  children = [
    @() {
      watch = [AoaWatch, IlsColor]
      rendObj = ROBJ_TEXT
      color = IlsColor.value
      fontSize = 40
      font = Fonts.hud
      text = string.format(AoaWatch.value >= 0 ? "+%02d" : "-%02d", abs(AoaWatch.value))
    },
    @() {
      watch = IlsColor
      rendObj = ROBJ_SOLID
      size = [baseLineWidth * 12, baseLineWidth * IlsLineScale.value]
      color = IlsColor.value
    },
    @() {
      watch = IlsColor
      rendObj = ROBJ_TEXT
      color = IlsColor.value
      fontSize = 40
      font = Fonts.hud
      text = "A"
      hplace = ALIGN_CENTER
    }
  ]
}

let ClimbJ8Watch = Computed(@() clamp(ClimbSpeed.value, -99.0, 99.0).tointeger())
let J8ClimbInfo = @() {
  size = SIZE_TO_CONTENT
  pos = [pw(75), ph(46)]
  flow = FLOW_VERTICAL
  children = [
    @() {
      watch = [ClimbJ8Watch, IlsColor]
      rendObj = ROBJ_TEXT
      color = IlsColor.value
      fontSize = 40
      font = Fonts.hud
      text = string.format(ClimbJ8Watch.value >= 0 ? "+%02d" : "-%02d", abs(ClimbJ8Watch.value))
    },
    @() {
      watch = IlsColor
      rendObj = ROBJ_SOLID
      size = [baseLineWidth * 12, baseLineWidth * IlsLineScale.value]
      color = IlsColor.value
    },
    @() {
      watch = IlsColor
      rendObj = ROBJ_TEXT
      color = IlsColor.value
      fontSize = 40
      font = Fonts.hud
      text = "H"
      hplace = ALIGN_CENTER
    }
  ]
}

let function generatePitchLineJ8(num) {
  let sign = num > 0 ? 1 : -1
  let newNum = num >= 0 ? num : (num - 5)
  return {
    size = [pw(60), ph(50)]
    pos = [pw(20), 0]
    flow = FLOW_VERTICAL
    children = num == 0 ? [
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.value
        color = IlsColor.value
        padding = [0, 10]
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
        lineWidth = baseLineWidth * IlsLineScale.value
        color = IlsColor.value
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
    size = [pw(100), ph(7.5)]
    flow = FLOW_HORIZONTAL
    children = [
      @() {
        watch = IlsColor
        size = [baseLineWidth * (num % 50 > 0 ? 5 : 7), baseLineWidth * IlsLineScale.value]
        rendObj = ROBJ_SOLID
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
        vplace = ALIGN_CENTER
      },
      (num % 50 > 0 ? null :
        @() {
          watch = IlsColor
          size = flex()
          rendObj = ROBJ_TEXT
          color = IlsColor.value
          vplace = ALIGN_CENTER
          fontSize = 40
          font = Fonts.hud
          text = string.format(num < 1000 ? "0%.1f" : "%.1f", num / 100.0)
        }
      )
    ]
  }
}

let function J8AltWrap(width, height, generateFunc) {
  return {
    size = [width * 0.17, height * 0.5]
    pos = [width * 0.83, height * 0.25]
    clipChildren = true
    children = [
      ShimadzuAlt(height * 0.5, generateFunc)
    ]
  }
}

let altValue = Computed(@() (Altitude.value).tointeger())
let J8AltInfo = @() {
  size = SIZE_TO_CONTENT
  pos = [pw(81), ph(16)]
  flow = FLOW_VERTICAL
  children = [
    @() {
      watch = [altValue, IlsColor]
      rendObj = ROBJ_TEXT
      color = IlsColor.value
      fontSize = 40
      font = Fonts.hud
      text = string.format("H%d", altValue.value)
    },
    @() {
      watch = IlsColor
      rendObj = ROBJ_TEXT
      color = IlsColor.value
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
      size = [pw(4), ph(3)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.value
      lineWidth = baseLineWidth * IlsLineScale.value
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
          translate = [TargetPos.value[0], TargetPos.value[1]]
        }
      }
    }
}

let J8AamMode = @() {
  watch = GuidanceLockState
  size = flex()
  children = [
    @() {
      watch = IlsColor
      size = [pw(10), ph(10)]
      pos = [pw(50), ph(50)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.value
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.value
      commands = [
        [VECTOR_ELLIPSE, 0, 0, 100, 100]
      ]
    },
    (GuidanceLockState.value == GuidanceLockResult.RESULT_TRACKING ?
    @() {
      watch = IlsColor
      size = [pw(5), ph(5)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.value
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.value
      commands = [
        [VECTOR_LINE, 0, -100, 100, 0],
        [VECTOR_LINE, 100, 0, 0, 100],
        [VECTOR_LINE, 0, 100, -100, 0],
        [VECTOR_LINE, 0, -100, -100, 0]
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = [IlsTrackerX.value, IlsTrackerY.value]
        }
      }
    } : null)
  ]
}

let TP0 = Computed(@() TargetPos.value[0].tointeger())
let TP1 = Computed(@() TargetPos.value[1].tointeger())
let function J8BombImpactLine(width, height) {
  return @() {
    watch = [TargetPosValid, BombCCIPMode, TP0, TP1, IlsColor]
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth * 0.8 * IlsLineScale.value
    size = flex()
    color = IlsColor.value
    commands = [
      (TargetPosValid.value && BombCCIPMode.value ? [VECTOR_LINE, 50, 50, TP0.value / width * 100, TP1.value / height * 100] : [])
    ]
  }
}

let function J8IIHK(width, height) {
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
      @() {
        watch = IlsColor
        pos = [pw(15), ph(75)]
        rendObj = ROBJ_TEXT
        color = IlsColor.value
        fontSize = 40
        font = Fonts.hud
        text = "IS"
      },
      @() {
        watch = IlsColor
        pos = [pw(85), ph(75)]
        rendObj = ROBJ_TEXT
        color = IlsColor.value
        fontSize = 40
        font = Fonts.hud
        text = "B"
      },
      @() {
        watch = IlsColor
        pos = [width * 0.5 - baseLineWidth * IlsLineScale.value * 0.5, ph(13)]
        size = [baseLineWidth * IlsLineScale.value, baseLineWidth * 5]
        rendObj = ROBJ_SOLID
        color = IlsColor.value
      },
      (CCIPMode.value ? aimMark : J8AirAimMark),
      (TrackerVisible.value ? J8AamMode : null),
      J8BombImpactLine(width, height)
    ]
  }
}

return J8IIHK