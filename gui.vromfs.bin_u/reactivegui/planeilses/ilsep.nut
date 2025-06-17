from "%rGui/globals/ui_library.nut" import *

let string = require("string")
let { Speed, Altitude, Roll, Tangage, Mach } = require("%rGui/planeState/planeFlyState.nut");
let { IlsColor,  BombingMode, TargetPosValid, TargetPos, BombCCIPMode,
        IlsLineScale, RocketMode, CannonMode, AamAccelLock, RadarTargetPos, IlsPosSize, RadarTargetDist} = require("%rGui/planeState/planeToolsState.nut")
let { mpsToKmh, baseLineWidth } = require("ilsConstants.nut")
let { GuidanceLockResult } = require("guidanceConstants")
let { compassWrap, generateCompassMarkEP, generateCompassMarkEP08 } = require("ilsCompasses.nut")
let { IlsTrackerVisible, GuidanceLockState } = require("%rGui/rocketAamAimState.nut")
let { flyDirection } = require("commonElements.nut")
let { ShellCnt, BulletImpactPoints, BulletImpactLineEnable }  = require("%rGui/planeState/planeWeaponState.nut");

let CCIPMode = Computed(@() RocketMode.value || CannonMode.value || BombCCIPMode.value)

function angleTxtEP(num, isLeft, textFont) {
  return @() {
    watch = IlsColor
    rendObj = ROBJ_TEXT
    vplace = ALIGN_BOTTOM
    hplace = isLeft ? ALIGN_LEFT : ALIGN_RIGHT
    color = IlsColor.value
    fontSize = 60
    font = textFont
    text = num.tostring()
  }
}

let EPAltCCIPWatched = Computed(@() string.format(Altitude.value < 1000 ? "%d" : "%.1f", Altitude.value < 1000 ? Altitude.value : Altitude.value / 1000))
let EPAltCCIP = @() {
  watch = [EPAltCCIPWatched, IlsColor]
  rendObj = ROBJ_TEXT
  pos = [pw(-150), ph(-20)]
  size = flex()
  color = IlsColor.value
  fontSize = 50
  text = EPAltCCIPWatched.value
  vplace = ALIGN_CENTER
}

function generatePitchLineEP(num, isEP12, textPad) {
  let newNum = num - 5
  return {
    size = const [pw(100), ph(100)]
    flow = FLOW_VERTICAL
    children = num >= 0 ? [
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.value
        color = IlsColor.value
        padding = [0, textPad]
        commands = [
          [VECTOR_LINE, 0, 0, !isEP12 && num == 0 ? 45 : 34, 0],
          (isEP12 && num != 0 ? [VECTOR_LINE, 66, 0, 100, 0] : [VECTOR_LINE, 66, 0, 74, 0]),
          (isEP12 && num == 0 ? [VECTOR_LINE, 90, 0, 100,  0] : []),
          (!isEP12 ? [VECTOR_LINE, num == 0 ? 55 : 66, 0, 100, 0] : []),
          [VECTOR_WIDTH, baseLineWidth * 2 * IlsLineScale.value],
          (!isEP12 && num == 0 ? [VECTOR_LINE, 50, 0, 50, 0] : []),
          (isEP12 && num == 0 ? [VECTOR_LINE, 37, 0, 37,  0] : []),
          (isEP12 && num == 0 ? [VECTOR_LINE, 42, 0, 42, 0] : []),
          (isEP12 && num == 0 ? [VECTOR_LINE, 47, 0, 47, 0] : []),
          (isEP12 && num == 0 ? [VECTOR_LINE, 53, 0, 53, 0] : []),
          (isEP12 && num == 0 ? [VECTOR_LINE, 58, 0, 58, 0] : []),
          (isEP12 && num == 0 ? [VECTOR_LINE, 63, 0, 63, 0] : [])
        ]
        children =
        [
          isEP12 || newNum != 0 ? angleTxtEP(newNum, true, Fonts.hud) : null,
          !isEP12 && newNum != 0 ? angleTxtEP(newNum, false, Fonts.hud) : null
        ]
      }
    ] :
    [
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.value
        color = IlsColor.value
        padding = [10, textPad]
        commands = [
          (isEP12 ? [VECTOR_LINE, 0, 0, 7, 0] : [VECTOR_LINE, 0, 0, 34, 0]),
          (isEP12 ? [VECTOR_LINE, 15, 0, 21, 0] : []),
          (isEP12 ? [VECTOR_LINE, 28, 0, 34, 0] : []),
          (isEP12 ? [VECTOR_LINE, 100, 0, 93, 0] : [VECTOR_LINE, 100, 0, 66, 0]),
          (isEP12 ? [VECTOR_LINE, 85, 0, 79, 0] : []),
          (isEP12 ? [VECTOR_LINE, 72, 0, 66, 0] : [])
        ]
        children = newNum >= -90 ?
        [
          angleTxtEP(newNum, true, Fonts.hud),
          !isEP12 ? angleTxtEP(newNum, false, Fonts.hud) : null
        ] : null
      }
    ]
  }
}

function pitchEP(width, height, isEP12) {
  const step = 5.0
  let children = []

  for (local i = 90.0 / step; i >= -90.0 / step; --i) {
    let num = (i * step).tointeger()

    children.append(generatePitchLineEP(num, isEP12, width * 0.17))
  }

  return {
    size = [width * 0.8, height * 0.5]
    pos = [width * 0.1, pw(50)]
    flow = FLOW_VERTICAL
    children = children
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, -height * (90.0 - Tangage.value) * 0.1]
      }
    }
  }
}

let EP12SpeedValue = Computed(@() Mach.value < 0.5 ? (Speed.value * mpsToKmh).tointeger() : Mach.value)
let EP12SpeedVis = Computed(@() Speed.value > 20.8)
let EP12Speed = @() {
  watch = EP12SpeedVis
  size = flex()
  children = EP12SpeedVis.value ?
  @() {
    watch = [EP12SpeedValue, IlsColor]
    size = SIZE_TO_CONTENT
    rendObj = ROBJ_TEXT
    pos = [pw(46), ph(80)]
    color = IlsColor.value
    fontSize = 50
    font = Fonts.hud
    text = string.format(Mach.value < 0.5 ? "%d" : "%.2f", EP12SpeedValue.value)
  } : null
}

let EP12RadarTargetVisible = Computed(@() RadarTargetDist.get() > 0.0 && !BombingMode.get())
let EP12RadarTargetMark = @(){
  watch = EP12RadarTargetVisible
  size = flex()
  children = EP12RadarTargetVisible.get() ? [
    {
      size = const [pw(3), ph(3)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.get()
      commands = [
        [VECTOR_SECTOR, 0, 0, 100, 100, 180, 0]
      ]
      animations = [
        { prop = AnimProp.opacity, from = -1, to = 1, duration = 0.5, loop = true , trigger = "outside_hud_zone"}
      ]
      behavior = Behaviors.RtPropUpdate
      update = function() {
        let shouldClamp = RadarTargetPos[0] < IlsPosSize[2] * 0.04 || RadarTargetPos[0] > IlsPosSize[2] * 0.96 || RadarTargetPos[1] < IlsPosSize[3] * 0.04 || RadarTargetPos[1] > IlsPosSize[3] * 0.96
        local pos = RadarTargetPos
        if(shouldClamp) {
          anim_start("outside_hud_zone")
          pos = [clamp(RadarTargetPos[0], IlsPosSize[2] * 0.04, IlsPosSize[2] * 0.96),
            clamp(RadarTargetPos[1], IlsPosSize[3] * 0.04, IlsPosSize[3] * 0.96)]
        }
        else
          anim_request_stop("outside_hud_zone")
        return {
          transform = {
            translate = pos
          }
        }
      }
    }
  ] : null
}

let generateAltMarkEP = function(num) {
  let val = num < 100 ? (num * 10) : (num * 0.01)
  let small = num % 10 > 0
  return {
    size = const [pw(100), ph(10)]
    pos = [pw(10), 0]
    flow = FLOW_HORIZONTAL
    children = [
      @() {
        watch = IlsColor
        size = [baseLineWidth * (small ? 2 : 4), baseLineWidth * IlsLineScale.value]
        rendObj = ROBJ_SOLID
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
        vplace = ALIGN_CENTER
      },
      (num % 20 > 0 ? null :
        @() {
          watch = IlsColor
          rendObj = ROBJ_TEXT
          color = IlsColor.value
          vplace = ALIGN_CENTER
          fontSize = 40
          font = Fonts.hud
          text = string.format(num < 100 ? "%d" : "%.1f", val)
        }
      )
    ]
  }
}

function EPAltitude(height, generateFunc) {
  let children = []

  for (local i = 2000; i >= 0;) {
    children.append(generateFunc(i))
    i -= 5
  }

  let getOffset = @() (20.0 - Altitude.value * 0.001 - 0.25 + 0.05) * height * 2.0
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

function EPAltitudeWrap(width, height, generateFunc) {
  return {
    size = [width * 0.2, height * 0.4]
    pos = [width * 0.7, height * 0.3]
    clipChildren = true
    children = [
      EPAltitude(height * 0.4, generateFunc)
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.value
        color = IlsColor.value
        commands = [
          [VECTOR_LINE, 0, 45, 10, 50],
          [VECTOR_LINE, 0, 55, 10, 50]
        ]
      }
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, Tangage.value * height * 0.07]
      }
    }
  }
}

function EP08Alt(width, height) {
  return {
    size = const [pw(15), ph(10)]
    children = [EPAltCCIP]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [width * 0.5, (Tangage.value * 0.07 + 0.47) * height]
      }
    }
  }
}

function navigationInfo(width, height, isEP08) {
  return @() {
    size = flex()
    children = [
      pitchEP(width, height * 0.7, !isEP08),
      !isEP08 ? EP12Speed : EP08Alt(width, height),
      !isEP08 ? compassWrap(width, height, 0.3, generateCompassMarkEP, 0.4) : compassWrap(width, height, 0.85, generateCompassMarkEP08, 1.4),
      !isEP08 ? EPAltitudeWrap(width, height, generateAltMarkEP) : null
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        rotate = -Roll.value
      }
    }
  }
}

function getBulletImpactLineCommand() {
  let commands = []
  for (local i = 0; i < BulletImpactPoints.value.len() - 2; ++i) {
    let point1 = BulletImpactPoints.value[i]
    let point2 = BulletImpactPoints.value[i + 1]
    if (point1.x == -1 && point1.y == -1)
      continue
    if (point2.x == -1 && point2.y == -1)
      continue
    commands.append([VECTOR_LINE, point1.x, point1.y, point2.x, point2.y])
  }
  return commands
}

let bulletsImpactLine = @() {
  watch = [CCIPMode, BulletImpactLineEnable]
  size = flex()
  children = BulletImpactLineEnable.value && !CCIPMode.value ? [
    @() {
      watch = [BulletImpactPoints, IlsColor]
      rendObj = ROBJ_VECTOR_CANVAS
      size = flex()
      color = IlsColor.value
      lineWidth = baseLineWidth * IlsLineScale.value
      commands = getBulletImpactLineCommand()
    }
  ] : null
}

let haveShell = Computed(@() ShellCnt.value > 0)
function EPAimMark(width, height, is_need_gun_ret) {
  return @() {
    watch = [CCIPMode, BombingMode]
    size = flex()
    children = CCIPMode.value || BombingMode.value ?
      @() {
        watch = [IlsColor, TargetPosValid, haveShell]
        size = const [pw(20), ph(10)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        fillColor = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
        commands = [
          [VECTOR_ELLIPSE, 0, 0, 3, 6],
          [VECTOR_LINE, -100, -100, -100, 100],
          [VECTOR_LINE, 100, -100, 100, 100],
          [VECTOR_FILL_COLOR, Color(0, 0, 0, 0)],
          (haveShell.value ? [VECTOR_ELLIPSE, 60, -80, 10, 20] : []),
          (TargetPosValid.value ? [VECTOR_LINE, -50, 90, 50, 90] : []),
          (TargetPosValid.value ? [VECTOR_LINE, -30, 90, -30, 70] : []),
          (TargetPosValid.value ? [VECTOR_LINE, 0, 90, 0, 70] : []),
          (TargetPosValid.value ? [VECTOR_LINE, 30, 90, 30, 70] : [])
        ]
        children = EPAltCCIP
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            translate = TargetPosValid.value && CCIPMode.value ? TargetPos.value : [width * 0.5, height * 0.5]
          }
        }
      } :
      ( is_need_gun_ret ? @() {
        watch = [IlsColor, TargetPosValid]
        size = const [pw(7), ph(7)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        fillColor = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value * 2.0
        commands = [
          [VECTOR_LINE, 0, 0, 0, 0],
          [VECTOR_LINE, 0, 100, 0, 100],
          [VECTOR_LINE, 0, -100, 0, -100],
          [VECTOR_LINE, 100, 0, 100, 0],
          [VECTOR_LINE, -100, 0, -100, 0],
          [VECTOR_LINE, -70.7, 70.7, -70.7, 70.7],
          [VECTOR_LINE, -70.7, -70.7, -70.7, -70.7],
          [VECTOR_LINE, 70.7, 70.7, 70.7, 70.7],
          [VECTOR_LINE, 70.7, -70.7, 70.7, -70.7]
        ]
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            translate = TargetPosValid.value ? TargetPos.value : [width * 0.5, height * 0.5]
          }
        }
      } : null)
  }
}

function EPCCRPTargetMark(width, height) {
  return @() {
    watch = [TargetPosValid, BombCCIPMode]
    size = flex()
    children = BombCCIPMode.value || BombingMode.value ?
      @() {
        watch = IlsColor
        size = const [pw(2), ph(2)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth * IlsLineScale.value
        commands = [
          [VECTOR_ELLIPSE, 0, 0, 100, 100],
        ]
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            translate = TargetPosValid.value && BombingMode.value ? TargetPos.value : [width * 0.5, height * 0.5]
          }
        }
      } : null
  }
}

let EP08AAMMarker = @() {
  watch = IlsTrackerVisible
  size = flex()
  children = IlsTrackerVisible.value ?
  @() {
    watch = [GuidanceLockState, IlsColor]
    size = flex()
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.value
    fillColor = IlsColor.value
    lineWidth = baseLineWidth * IlsLineScale.value
    commands = [
      (GuidanceLockState.value == GuidanceLockResult.RESULT_TRACKING ? [VECTOR_ELLIPSE, 50, 50, 0.5, 0.5] : []),
      (GuidanceLockState.value != GuidanceLockResult.RESULT_TRACKING ? [VECTOR_LINE, 60, 47, 60, 53] : []),
      (GuidanceLockState.value != GuidanceLockResult.RESULT_TRACKING ? [VECTOR_LINE, 40, 47, 40, 53] : []),
      (GuidanceLockState.value == GuidanceLockResult.RESULT_TRACKING ? [VECTOR_LINE, 65, 45, 65, 55] : []),
      (GuidanceLockState.value == GuidanceLockResult.RESULT_TRACKING ? [VECTOR_LINE, 35, 45, 35, 55] : []),
      (GuidanceLockState.value == GuidanceLockResult.RESULT_TRACKING ? [VECTOR_LINE, 42, 55, 57, 55] : []),
      (GuidanceLockState.value == GuidanceLockResult.RESULT_TRACKING ? [VECTOR_LINE, 55, 55, 55, 53] : []),
      (GuidanceLockState.value == GuidanceLockResult.RESULT_TRACKING ? [VECTOR_LINE, 50, 55, 50, 53] : []),
      (GuidanceLockState.value == GuidanceLockResult.RESULT_TRACKING ? [VECTOR_LINE, 45, 55, 45, 53] : [])
    ]
    children =
      @() {
        watch = AamAccelLock
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
        commands = [
          (AamAccelLock.value ? [VECTOR_LINE, 42, 50, 48, 50] : []),
          (AamAccelLock.value ? [VECTOR_LINE, 52, 50, 58, 50] : [])
        ]
        animations = [
          { prop = AnimProp.opacity, from = -1, to = 1, duration = 0.5, play = true, loop = true }
        ]
      }
  } : null
}

function swedishEPIls(width, height, is_ep08) {
  return @() {
    watch = [CCIPMode, BombingMode, IlsTrackerVisible]
    size = [width, height]
    children = [
      (!CCIPMode.value && !BombingMode.value && !IlsTrackerVisible.value ? flyDirection(width, height, true) : null),
      (!CCIPMode.value && !BombingMode.value ? navigationInfo(width, height, is_ep08) : null),
      EPAimMark(width, height, !is_ep08),
      EP08AAMMarker,
      (is_ep08 ? EPCCRPTargetMark(width, height) : null),
      (!is_ep08 ? bulletsImpactLine : null),
      (!is_ep08 ? EP12RadarTargetMark : null)
    ]
  }
}

return swedishEPIls