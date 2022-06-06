let {IlsColor, IlsLineScale, TvvMark, IlsAtgmTrackerVisible,
      IlsAtgmTargetPos, IlsAtgmLocked, AtgmTargetDist, TargetPosValid,
      TargetPos, RocketMode, CannonMode, BombCCIPMode, DistToTarget,
      BombingMode } = require("%rGui/planeState/planeToolsState.nut")
let {baseLineWidth, metrToFeet, mpsToKnots, metrToMile, GuidanceLockResult} = require("ilsConstants.nut")
let {compassWrap, generateCompassMarkShim} = require("ilsCompasses.nut")
let {Tangage, BarAltitude, Altitude, Speed, Roll} = require("%rGui/planeState/planeFlyState.nut");
let {round, cos, sin, PI} = require("%sqstd/math.nut")
let {cvt} = require("dagor.math")
let {GuidanceLockState, IlsTrackerX, IlsTrackerY} = require("%rGui/rocketAamAimState.nut")
let {ShellCnt}  = require("%rGui/planeState/planeWeaponState.nut");

let SpeedValue = Computed(@() (Speed.value * mpsToKnots).tointeger())
let a10Speed = @() {
  watch = [SpeedValue, IlsColor]
  rendObj = ROBJ_DTEXT
  pos = [pw(10), ph(50)]
  size = flex()
  color = IlsColor.value
  fontSize = 40
  font = Fonts.hud
  text = (SpeedValue.value).tostring()
}

let a10AltValue = Computed(@() clamp(Altitude.value * metrToFeet * 0.1, -200, 3800).tointeger())
let a10Altitude = @() {
  watch = [a10AltValue, IlsColor]
  rendObj = ROBJ_DTEXT
  pos = [pw(80), ph(50)]
  size = flex()
  color = IlsColor.value
  fontSize = 40
  font = Fonts.hud
  text = $"{a10AltValue.value}0"
}

let a10TangageValue = Computed(@() round(Tangage.value))
let a10Tangage = @() {
  watch = [a10TangageValue, IlsColor]
  rendObj = ROBJ_DTEXT
  pos = [pw(80), ph(55)]
  size = flex()
  color = IlsColor.value
  fontSize = 40
  font = Fonts.hud
  text = $"{a10TangageValue.value}"
}

let a10BarAltValue = Computed(@() clamp(BarAltitude.value * metrToFeet * 0.1, 0, 500).tointeger())
let a10BarAltitude = @() {
  watch = [a10AltValue, IlsColor]
  rendObj = ROBJ_DTEXT
  pos = [pw(80), ph(70)]
  size = flex()
  color = IlsColor.value
  fontSize = 35
  font = Fonts.hud
  text = $"{a10BarAltValue.value}0R"
}

let function pitch(width, height, generateFunc) {
  const step = 5.0
  let children = []

  for (local i = 90.0 / step; i >= -90.0 / step; --i) {
    let num = (i * step).tointeger()

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
        translate = [0, -height * (90.0 - Tangage.value) * 0.05]
        rotate = -Roll.value
        pivot=[0.5, (90.0 - Tangage.value) * 0.1]
      }
    }
  }
}

let function angleTxt(num, isLeft, invVPlace = 1, x = 0, y = 0) {
  return @() {
    watch = IlsColor
    pos = [x, y]
    rendObj = ROBJ_DTEXT
    vplace = (num * invVPlace) < 0 ? ALIGN_BOTTOM : ALIGN_TOP
    hplace = isLeft ? ALIGN_LEFT : ALIGN_RIGHT
    color = IlsColor.value
    fontSize = 45
    font = Fonts.hud
    text = string.format(num == -5 ? "-05" : "%02d", num)
  }
}

let function generatePitchLine(num) {
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
        children = [angleTxt(-5, true, 1, pw(-30)), angleTxt(-5, false, 1, pw(30))]
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
        children = newNum <= 90 ? [angleTxt(newNum, true, 1, pw(-25)), angleTxt(newNum, false, 1, pw(25))] : null
      }
    ]
  }
}

let maverickDist = Computed( @() (AtgmTargetDist.value < 0 ? -1 : AtgmTargetDist.value * metrToMile * 10.0).tointeger())
let maverickAimMark = @() {
  watch = IlsAtgmLocked
  rendObj = ROBJ_VECTOR_CANVAS
  size = [pw(4), ph(4)]
  color = IlsColor.value
  fillColor = Color(0, 0, 0, 0)
  lineWidth = baseLineWidth * IlsLineScale.value
  commands = [
    [VECTOR_ELLIPSE, 0, 0, 100, 100],
    [VECTOR_LINE, 0, 0, 0, 0],
    (IlsAtgmLocked.value ? [VECTOR_LINE, -100, 0, -50, 0] : []),
    (IlsAtgmLocked.value ? [VECTOR_LINE, 50, 0, 100, 0] : []),
    (IlsAtgmLocked.value ? [VECTOR_LINE, 0, -50, 0, -100] : []),
    (IlsAtgmLocked.value ? [VECTOR_LINE, 0, 50, 0, 100] : [])
  ]
  children = [
    @() {
      watch = maverickDist
      rendObj = ROBJ_DTEXT
      color = IlsColor.value
      pos = [pw(-50), ph(120)]
      font = Fonts.hud
      fontSize = 30
      hplace = ALIGN_CENTER
      text = maverickDist.value < 0 ? "" : string.format("%.1f", maverickDist.value * 0.1)
    }
  ]
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      translate = [IlsAtgmTargetPos[0], IlsAtgmTargetPos[1]]
    }
  }
}

let CCIPMode = Computed(@() RocketMode.value || CannonMode.value || BombCCIPMode.value)
let ccipDistF = Computed( @() cvt(clamp(DistToTarget.value * metrToFeet * 0.01, 0, 120), 0, 120, -90, 270).tointeger())
let ccipDistM = Computed( @() (DistToTarget.value < 0 || DistToTarget.value >= 10000 ? -1 : DistToTarget.value * metrToMile * 10.0).tointeger())
let gunAimMark = @() {
  watch = [TargetPosValid, CCIPMode]
  size = flex()
  children = TargetPosValid.value ?
    @() {
      watch = [IlsColor, ccipDistF]
      size = [pw(8), ph(8)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.value
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.value
      commands = [
        [VECTOR_LINE, 0, 0, 0, 0],
        [VECTOR_ELLIPSE, 0, 0, 100, 100],
        [VECTOR_LINE, -120, 0, -100, 0],
        [VECTOR_LINE, 120, 0, 100, 0],
        [VECTOR_LINE, 0, -120, 0, -100],
        [VECTOR_LINE, 0, 120, 0, 100],
        (DistToTarget.value < 10000 ? [VECTOR_SECTOR, 0, 0, 90, 90, -90, ccipDistF.value] : []),
        (DistToTarget.value < 10000 ?
         [VECTOR_LINE, 90 * cos(PI * ccipDistF.value / 180), 90 * sin(PI * ccipDistF.value / 180), 75 * cos(PI * ccipDistF.value / 180), 75 * sin(PI * ccipDistF.value / 180)] : [])
      ]
      children = [
        @() {
          watch = ccipDistM
          rendObj = ROBJ_DTEXT
          color = IlsColor.value
          pos = [pw(-50), ph(120)]
          font = Fonts.hud
          fontSize = 30
          hplace = ALIGN_CENTER
          text = ccipDistM.value < 0 ? "" : string.format("%.1f", ccipDistM.value * 0.1)
        }
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = [TargetPos.value[0], TargetPos.value[1]]
        }
      }
    }
  : null
}

let maverickAim = @() {
  watch = [IlsAtgmTrackerVisible, CannonMode]
  size = flex()
  children = IlsAtgmTrackerVisible.value && !CannonMode.value ? [maverickAimMark] : []
}

let function impactLine(width, height) {
  return @() {
    watch = [TargetPosValid, BombCCIPMode, BombingMode, RocketMode]
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth * 0.8 * IlsLineScale.value
    size = flex()
    color = IlsColor.value
    commands = [
      (TargetPosValid.value && (BombCCIPMode.value || BombingMode.value || RocketMode.value) ? [VECTOR_LINE, 0, 0, 0, -100] : [])
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = TargetPosValid.value ? [TargetPos.value[0], clamp(TargetPos.value[1], 0, height)] : [TargetPos.value[0], height]
        rotate = -Roll.value
        pivot = [0, 0]
      }
    }
  }
}

let function KaiserTvvLinked(width, height) {
  return {
    size = flex()
    children = [
      @(){
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        size = [pw(4), ph(4)]
        color = IlsColor.value
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth * IlsLineScale.value
        commands = [
          [VECTOR_ELLIPSE, 0, 0, 50, 50],
          [VECTOR_LINE, -50, 0, -100, 0],
          [VECTOR_LINE, 50, 0, 100, 0],
          [VECTOR_LINE, 0, -50, 0, -80]
        ]
      },
      pitch(width, height, generatePitchLine)
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [TvvMark[0], TvvMark[1]]
      }
    }
  }
}

let smallGunCrosshair = @() {
  watch = IlsColor
  size = [pw(1), ph(1)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.value
  lineWidth = baseLineWidth * IlsLineScale.value
  commands = [
    [VECTOR_LINE, -100, 0, 100, 0],
    [VECTOR_LINE, 0, -100, 0, 100]
  ]
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      translate = [TargetPos.value[0], TargetPos.value[1]]
    }
  }
}

let modeTxt = @() {
  watch = [CannonMode, IlsColor, RocketMode, BombCCIPMode, BombingMode, GuidanceLockState]
  rendObj = ROBJ_DTEXT
  pos = [pw(10), ph(80)]
  size = flex()
  color = IlsColor.value
  fontSize = 30
  font = Fonts.hud
  text = GuidanceLockState.value <= GuidanceLockResult.RESULT_STANDBY ?
   (BombingMode.value ? "CCRP" : (RocketMode.value || BombCCIPMode.value ? "CCIP" : (CannonMode.value ? "GUNS" : ""))) : "AIR-TO-AIR"
}

let shellCntText = @() {
  watch = [CannonMode, ShellCnt]
  rendObj = ROBJ_DTEXT
  pos = [pw(10), ph(77)]
  size = flex()
  color = IlsColor.value
  fontSize = 30
  font = Fonts.hud
  text = CannonMode.value ? string.format("HEI/%d", ShellCnt.value) : ""
}

let aamTargetMarker = @() {
  watch = IlsColor
  size = [pw(10), ph(10)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.value
  fillColor = Color(0, 0, 0, 0)
  lineWidth = IlsLineScale.value * baseLineWidth
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

let function KaiserA10(width, height) {
  return {
    size = [width, height]
    children = [
      a10Speed,
      a10Altitude,
      a10Tangage,
      a10BarAltitude,
      compassWrap(width, height, 0.85, generateCompassMarkShim, 1.0, 5.0, false, 20),
      {
        rendObj = ROBJ_VECTOR_CANVAS
        size = flex()
        color = IlsColor.value
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth * IlsLineScale.value
        commands = [
          [VECTOR_POLY, 50, 92, 53, 93, 47, 93]
        ]
      },
      KaiserTvvLinked(width, height),
      modeTxt,
      shellCntText,
      @() {
        watch = GuidanceLockState
        size = flex()
        children = GuidanceLockState.value <= GuidanceLockResult.RESULT_STANDBY ? [
          maverickAim,
          gunAimMark,
          impactLine(width, height)
        ] : [
          aamTargetMarker,
          smallGunCrosshair
        ]
      }
    ]
  }
}

return KaiserA10