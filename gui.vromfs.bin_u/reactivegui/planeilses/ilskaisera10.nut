from "%rGui/globals/ui_library.nut" import *
from "%globalScripts/loc_helpers.nut" import loc_checked

let string = require("string")
let { IlsColor, IlsLineScale, TvvIlsMark, IsTVVIlsMarkValid, IlsAtgmTrackerVisible,
      IlsAtgmTargetPos, IlsAtgmLocked, AtgmTargetDist, TargetPosValid,
      TargetPos, RocketMode, CannonMode, BombCCIPMode, DistToTarget,
      BombingMode, AimLockPos, AimLockValid, IlsPosSize, AimLockDist,
      AirCannonMode, TimeBeforeBombRelease, TVVPitch } = require("%rGui/planeState/planeToolsState.nut")
let { baseLineWidth, metrToFeet, mpsToKnots, metrToNavMile } = require("ilsConstants.nut")
let { GuidanceLockResult } = require("guidanceConstants")
let { compassWrap, generateCompassMarkShim } = require("ilsCompasses.nut")
let { Tangage, BarAltitude, Altitude, Speed, Roll, Overload } = require("%rGui/planeState/planeFlyState.nut");
let { round, cos, sin, PI, lerp } = require("%sqstd/math.nut")
let { cvt } = require("dagor.math")
let { GuidanceLockState, IlsTrackerX, IlsTrackerY } = require("%rGui/rocketAamAimState.nut")
let { ShellCnt, CurWeaponName, FwdPoint }  = require("%rGui/planeState/planeWeaponState.nut");
let { get_local_unixtime, unixtime_to_local_timetbl } = require("dagor.time")
let { bulletsImpactLine } = require("commonElements.nut")

let SpeedValue = Computed(@() round(Speed.value * mpsToKnots).tointeger())
let a10Speed = @() {
  watch = [SpeedValue, IlsColor]
  rendObj = ROBJ_TEXT
  pos = [pw(14), ph(50)]
  size = flex()
  color = IlsColor.value
  fontSize = 40
  font = Fonts.hud
  text = (SpeedValue.value).tostring()
}

let a10BarAltValue = Computed(@() clamp(BarAltitude.value * metrToFeet * 0.1, -200, 3800).tointeger())
let a10BarAltitude = @() {
  watch = [a10BarAltValue, IlsColor]
  rendObj = ROBJ_TEXT
  pos = [pw(80), ph(50)]
  size = flex()
  color = IlsColor.value
  fontSize = 40
  font = Fonts.hud
  text = $"{a10BarAltValue.value}0"
}

let a10TangageValue = Computed(@() round(Tangage.value))
let a10Tangage = @() {
  watch = [a10TangageValue, IlsColor]
  rendObj = ROBJ_TEXT
  pos = [pw(80), ph(55)]
  size = flex()
  color = IlsColor.value
  fontSize = 40
  font = Fonts.hud
  text = $"{a10TangageValue.value}"
}

let a10AltValue = Computed(@() clamp(Altitude.value * metrToFeet * 0.1, 0, 500).tointeger())
let a10Altitude = @() {
  watch = [a10AltValue, IlsColor]
  rendObj = ROBJ_TEXT
  pos = [pw(80), ph(70)]
  size = flex()
  color = IlsColor.value
  fontSize = 35
  font = Fonts.hud
  text = $"{a10AltValue.value}0R"
}

function getTVVLerpT() {
  let speedToUseTVV = 10
  return IsTVVIlsMarkValid.value ? min(Speed.value / speedToUseTVV, 1) : 0.0
}

function pitch(width, height, generateFunc) {
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
    transform = { 
      rotate = -Roll.value
    }
    update = function() {
      let angle = 90.0 - lerp(0.0, 1.0, Tangage.value, TVVPitch.value, getTVVLerpT())
      return {
        transform = {
          translate = [0, -height * angle * 0.05]
          rotate = -Roll.value
          pivot = [0.5, angle * 0.1]
        }
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
    color = IlsColor.value
    fontSize = 45
    font = Fonts.hud
    text = string.format(num == -5 ? "-05" : "%02d", num)
  }
}

function generatePitchLine(num) {
  let sign = num > 0 ? 1 : -1
  let newNum = num >= 0 ? num : (num - 5)
  return {
    size = const [pw(60), ph(50)]
    pos = [pw(20), 0]
    flow = FLOW_VERTICAL
    children = num == 0 ? [
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.value
        color = IlsColor.value
        padding = const [0, 10]
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

let maverickDist = Computed(@() (AtgmTargetDist.value < 0 ? -1 : AtgmTargetDist.value * metrToNavMile * 10.0).tointeger())
let maverickAimMark = @() {
  watch = [IlsAtgmLocked, IlsColor]
  rendObj = ROBJ_VECTOR_CANVAS
  size = const [pw(4), ph(4)]
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
      rendObj = ROBJ_TEXT
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
let ccipDistF = Computed(@() BombingMode.get() ? cvt(TimeBeforeBombRelease.get(), 0, 15, -90, 270).tointeger() :
 cvt(clamp(DistToTarget.value * metrToFeet * 0.01, 0, 120), 0, 120, -90, 270).tointeger())
let ccipDistM = Computed(@() (DistToTarget.value * metrToNavMile * 10.0).tointeger())
let isDistanceValid = Computed(@() BombingMode.get() || (DistToTarget.get() >= 0 && DistToTarget.get() < 10000))
let gunAimMark = @() {
  watch = [TargetPosValid, CCIPMode, AirCannonMode]
  size = flex()
  transform = {} 
  children = !TargetPosValid.value || AirCannonMode.get() ? null :
    @() {
      watch = [IlsColor, isDistanceValid]
      size = const [pw(8), ph(8)]
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
      ]
      children = !isDistanceValid.get() ? null :[
        @() {
          watch = ccipDistM
          rendObj = ROBJ_TEXT
          color = IlsColor.value
          pos = [pw(-50), ph(120)]
          font = Fonts.hud
          fontSize = 30
          hplace = ALIGN_CENTER
          text = string.format("%.1f", ccipDistM.value * 0.1)
        },
        @() {
          watch = ccipDistF
          size = flex()
          rendObj = ROBJ_VECTOR_CANVAS
          color = IlsColor.value
          fillColor = Color(0, 0, 0, 0)
          lineWidth = baseLineWidth * IlsLineScale.value
          commands = [
            ([VECTOR_SECTOR, 0, 0, 90, 90, -90, ccipDistF.value]),
            ([VECTOR_LINE, 90 * cos(PI * ccipDistF.value / 180), 90 * sin(PI * ccipDistF.value / 180), 75 * cos(PI * ccipDistF.value / 180), 75 * sin(PI * ccipDistF.value / 180)])
          ]
        }
      ]
    }
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      translate = BombingMode.get() ? [IlsPosSize[2] * 0.5, IlsPosSize[3] * 0.5] : [TargetPos.value[0], TargetPos.value[1]]
    }
  }
}

let maverickAim = @() {
  watch = [IlsAtgmTrackerVisible, CannonMode]
  size = flex()
  children = IlsAtgmTrackerVisible.value && !CannonMode.value ? [maverickAimMark] : []
}

function impactLine(_width, height, c_version) {
  let line = c_version ? [VECTOR_LINE_DASHED, 0, 0, 0, -100, 25, 30] : [VECTOR_LINE, 0, 0, 0, -100]
  return @() {
    watch = [TargetPosValid, BombCCIPMode, BombingMode, RocketMode, IlsColor]
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth * 0.8 * IlsLineScale.value
    size = flex()
    color = IlsColor.value
    commands = [
      (TargetPosValid.value && (BombCCIPMode.value || BombingMode.value || RocketMode.value) ? line : [])
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

function KaiserTvvLinked(width, height) {
  return {
    size = flex()
    transform = {} 
    children = [
      @() {
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        size = const [pw(4), ph(4)]
        color = IlsColor.value
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth * IlsLineScale.value
        commands = [
          [VECTOR_ELLIPSE, 0, 0, 50, 50],
          [VECTOR_LINE, -50, 0, -100, 0],
          [VECTOR_LINE, 50, 0, 100, 0],
          [VECTOR_LINE, 0, -50, 0, -80]
        ]
        animations = [
          { prop = AnimProp.opacity, from = 1, to = -1, duration = 0.5, loop = true, easing = InOutSine, trigger = "TVV_limit" }
        ]
      },
      pitch(width, height, generatePitchLine)
    ]
    behavior = Behaviors.RtPropUpdate
    update = function() {
      let t = getTVVLerpT()
      local x = lerp(0.0, 1.0, FwdPoint[0], TvvIlsMark[0], t)
      local y = lerp(0.0, 1.0, FwdPoint[1], TvvIlsMark[1], t)

      let maxOffset = 0.4

      let xDelta = width * (1.0 - 2.0 * maxOffset)
      let minX = xDelta
      let maxX = width - xDelta

      let yDelta = height * (1.0 - 2.0 * maxOffset)
      let minY = yDelta
      let maxY = height - yDelta

      local offLimits = false
      if (x < minX || x > maxX) {
        x = clamp(x, minX, maxX)
        offLimits = true
      }
      if (y < minY || y > maxY) {
        y = clamp(y, minY, maxY)
        offLimits = true
      }

      if (offLimits)
        anim_start("TVV_limit")
      else
        anim_request_stop("TVV_limit")

      return {
        transform = {
          translate = [x, y]
        }
      }
    }
  }
}

let smallGunCrosshair = @() {
  watch = IlsColor
  size = const [pw(1), ph(1)]
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

function modeTxt(c_version) {
  return @() {
    watch = [CannonMode, IlsColor, RocketMode, BombCCIPMode, BombingMode, GuidanceLockState]
    rendObj = ROBJ_TEXT
    pos = c_version ? [pw(38), ph(40)] : [pw(10), ph(80)]
    size = c_version ? [pw(24), flex()] : flex()
    color = IlsColor.value
    fontSize = c_version ? 40 : 30
    font = Fonts.hud
    halign = c_version ? ALIGN_CENTER : ALIGN_LEFT
    text = GuidanceLockState.value <= GuidanceLockResult.RESULT_STANDBY ?
    (BombingMode.value ? "CCRP" : (RocketMode.value || BombCCIPMode.value ? "CCIP" : (CannonMode.value ? "GUNS" : ""))) : "AIR-TO-AIR"
  }
}

function shellCntText(c_version) {
  return @() {
    watch = [CannonMode, ShellCnt, IlsColor, AirCannonMode]
    rendObj = ROBJ_TEXT
    pos = [0, c_version ? ph(65) : ph(77)]
    size = c_version ? [pw(20), SIZE_TO_CONTENT] : SIZE_TO_CONTENT
    color = IlsColor.value
    fontSize = 30
    font = Fonts.hud
    text = CannonMode.get() || AirCannonMode.get() ? string.format(c_version ? (AirCannonMode.get() ? "MIG-29/%d" : "CM/%d") : "HEI/%d", ShellCnt.value) : ""
    halign = ALIGN_RIGHT
  }
}

let aamTargetMarker = @() {
  watch = IlsColor
  size = const [pw(10), ph(10)]
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

let OverloadVal = Computed(@() (Overload.get() * 10.0).tointeger())
let overload = @(){
  watch = [OverloadVal, IlsColor]
  rendObj = ROBJ_TEXT
  size = SIZE_TO_CONTENT
  pos = [pw(14), ph(20)]
  color = IlsColor.get()
  lineWidth = baseLineWidth * IlsLineScale.get()
  font = Fonts.hud
  fontSize = 35
  text = string.format("%.1f", OverloadVal.get() * 0.1)
}

let localTime = @() {
  watch = IlsColor
  rendObj = ROBJ_TEXT
  size = SIZE_TO_CONTENT
  pos = [pw(80), ph(90)]
  color = IlsColor.value
  fontSize = 35
  font = Fonts.hud
  text = "11:22:33"
  behavior = Behaviors.RtPropUpdate
  function update() {
    let time = unixtime_to_local_timetbl(get_local_unixtime())
    return {
      text = string.format("%02d:%02d:%02d", time.hour, time.min, time.sec)
    }
  }
}

let toiDistVisible = Watched(false)
let aimLockDistVal = Computed(@() (AimLockDist.get() * metrToNavMile * 10.).tointeger())
let toi = @(){
  watch = [AimLockValid, IlsAtgmTrackerVisible]
  size = flex()
  children = AimLockValid.get() && !IlsAtgmTrackerVisible.get() ? @(){
    watch = toiDistVisible
    size = const [pw(4), ph(4)]
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.get()
    fillColor = Color(0, 0, 0, 0)
    lineWidth = baseLineWidth * IlsLineScale.get()
    commands = [
      [VECTOR_RECTANGLE, -50, -50, 100, 100],
      [VECTOR_LINE, 0, 0, 0, 0]
    ]
    children = toiDistVisible.get() ? @(){
      watch = aimLockDistVal
      rendObj = ROBJ_TEXT
      pos = [pw(-100), ph(80)]
      size = const [pw(200), SIZE_TO_CONTENT]
      color = IlsColor.get()
      font = Fonts.hud
      fontSize = 35
      text = string.format("%.1f", aimLockDistVal.get() * 0.1)
      halign = ALIGN_CENTER
    } : null
    behavior = Behaviors.RtPropUpdate
    update = function() {
      local target = AimLockPos
      let leftBorder = IlsPosSize[2] * 0.03
      let rightBorder = IlsPosSize[2] * 0.97
      let topBorder = IlsPosSize[3] * 0.04
      let bottomBorder = IlsPosSize[3] * 0.93
      if (target[0] < leftBorder || target[0] > rightBorder || target[1] < topBorder || target[1] > bottomBorder)
        toiDistVisible.set(true)
      else
        toiDistVisible.set(false)
      target = [clamp(target[0], leftBorder, rightBorder), clamp(target[1], topBorder, bottomBorder)]
      return {
        transform = {
          translate = target
        }
      }
    }
  } : null
}

let stpt = @(){
  watch = IlsColor
  rendObj = ROBJ_TEXT
  size = SIZE_TO_CONTENT
  pos = [pw(12), ph(90)]
  color = IlsColor.get()
  font = Fonts.hud
  fontSize = 35
  text = "STPT"
}

let arm = @(){
  watch = IlsColor
  rendObj = ROBJ_TEXT
  size = SIZE_TO_CONTENT
  pos = [pw(14), ph(80)]
  color = IlsColor.get()
  font = Fonts.hud
  fontSize = 35
  text = "ARM"
}

let secondaryWeaponName = @(){
  watch = [CannonMode, CurWeaponName, AirCannonMode]
  size = flex()
  children = !CannonMode.get() && !AirCannonMode.get() && CurWeaponName.get() != "" ? @(){
    watch = CurWeaponName
    rendObj = ROBJ_TEXT
    size = const [pw(20), SIZE_TO_CONTENT]
    pos = [pw(0), ph(65)]
    color = IlsColor.get()
    font = Fonts.hud
    fontSize  = 35
    text = loc_checked(string.format("%s/a_10c", CurWeaponName.value))
    halign = ALIGN_RIGHT
  } : null
}

let bulletsImpactLines = @(){
  watch = AirCannonMode
  size = flex()
  children = AirCannonMode.get() ? bulletsImpactLine : null
}

let isCcrpInvalid = Computed(@() BombingMode.get() && TimeBeforeBombRelease.get() <= 0.0)
let ccrpInvalid = @(){
  watch = isCcrpInvalid
  rendObj = ROBJ_TEXT
  pos = [pw(38), ph(45)]
  size = const [pw(24), flex()]
  color = IlsColor.get()
  font = Fonts.hud
  fontSize = 40
  text = isCcrpInvalid.get() ? "INVALID" : null
  halign = ALIGN_CENTER
}

function KaiserA10(width, height, c_version) {
  return {
    size = [width, height]
    children = [
      a10Speed,
      a10Altitude,
      a10Tangage,
      a10BarAltitude,
      compassWrap(width, height, 0.85, generateCompassMarkShim, c_version ? 0.6 : 1.0, 5.0, false, 20),
      @() {
        watch = IlsColor
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
      modeTxt(c_version),
      shellCntText(c_version),
      @() {
        watch = GuidanceLockState
        size = flex()
        children = GuidanceLockState.value <= GuidanceLockResult.RESULT_STANDBY ? [
          maverickAim,
          gunAimMark,
          impactLine(width, height, c_version)
        ] : [
          aamTargetMarker,
          smallGunCrosshair
        ]
      },
      (c_version ? overload : null),
      (c_version ? localTime : null),
      (c_version ? toi : null),
      (c_version ? stpt : null),
      (c_version ? arm : null),
      (c_version ? secondaryWeaponName : null),
      (c_version ? bulletsImpactLines : null),
      (c_version ? ccrpInvalid : null)
    ]
  }
}

return KaiserA10