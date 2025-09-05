from "%rGui/globals/ui_library.nut" import *

let string = require("string")
let { Speed, Altitude, Roll, Tangage, Mach } = require("%rGui/planeState/planeFlyState.nut");
let { IlsColor,  BombingMode, TargetPosValid, TargetPos, BombCCIPMode,
        IlsLineScale, RocketMode, CannonMode, AamAccelLock, RadarTargetPos, IlsPosSize, RadarTargetDist} = require("%rGui/planeState/planeToolsState.nut")
let { mpsToKmh, baseLineWidth } = require("%rGui/planeIlses/ilsConstants.nut")
let { GuidanceLockResult } = require("guidanceConstants")
let { compassWrap, generateCompassMarkEP, generateCompassMarkEP08 } = require("%rGui/planeIlses/ilsCompasses.nut")
let { IlsTrackerVisible, GuidanceLockState } = require("%rGui/rocketAamAimState.nut")
let { flyDirection } = require("%rGui/planeIlses/commonElements.nut")
let { ShellCnt, BulletImpactPoints, BulletImpactLineEnable }  = require("%rGui/planeState/planeWeaponState.nut");

let CCIPMode = Computed(@() RocketMode.get() || CannonMode.get() || BombCCIPMode.get())

function angleTxtEP(num, isLeft, textFont) {
  return @() {
    watch = IlsColor
    rendObj = ROBJ_TEXT
    vplace = ALIGN_BOTTOM
    hplace = isLeft ? ALIGN_LEFT : ALIGN_RIGHT
    color = IlsColor.get()
    fontSize = 60
    font = textFont
    text = num.tostring()
  }
}

let EPAltCCIPWatched = Computed(@() string.format(Altitude.get() < 1000 ? "%d" : "%.1f", Altitude.get() < 1000 ? Altitude.get() : Altitude.get() / 1000))
let EPAltCCIP = @() {
  watch = [EPAltCCIPWatched, IlsColor]
  rendObj = ROBJ_TEXT
  pos = [pw(-150), ph(-20)]
  size = flex()
  color = IlsColor.get()
  fontSize = 50
  text = EPAltCCIPWatched.get()
  vplace = ALIGN_CENTER
}

function generatePitchLineEP(num, isEP12, textPad) {
  let newNum = num - 5
  return {
    size = static [pw(100), ph(100)]
    flow = FLOW_VERTICAL
    children = num >= 0 ? [
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.get()
        color = IlsColor.get()
        padding = [0, textPad]
        commands = [
          [VECTOR_LINE, 0, 0, !isEP12 && num == 0 ? 45 : 34, 0],
          (isEP12 && num != 0 ? [VECTOR_LINE, 66, 0, 100, 0] : [VECTOR_LINE, 66, 0, 74, 0]),
          (isEP12 && num == 0 ? [VECTOR_LINE, 90, 0, 100,  0] : []),
          (!isEP12 ? [VECTOR_LINE, num == 0 ? 55 : 66, 0, 100, 0] : []),
          [VECTOR_WIDTH, baseLineWidth * 2 * IlsLineScale.get()],
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
        lineWidth = baseLineWidth * IlsLineScale.get()
        color = IlsColor.get()
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
        translate = [0, -height * (90.0 - Tangage.get()) * 0.1]
      }
    }
  }
}

let EP12SpeedValue = Computed(@() Mach.get() < 0.5 ? (Speed.get() * mpsToKmh).tointeger() : Mach.get())
let EP12SpeedVis = Computed(@() Speed.get() > 20.8)
let EP12Speed = @() {
  watch = EP12SpeedVis
  size = flex()
  children = EP12SpeedVis.get() ?
  @() {
    watch = [EP12SpeedValue, IlsColor]
    size = SIZE_TO_CONTENT
    rendObj = ROBJ_TEXT
    pos = [pw(46), ph(80)]
    color = IlsColor.get()
    fontSize = 50
    font = Fonts.hud
    text = string.format(Mach.get() < 0.5 ? "%d" : "%.2f", EP12SpeedValue.get())
  } : null
}

let EP12RadarTargetVisible = Computed(@() RadarTargetDist.get() > 0.0 && !BombingMode.get())
let EP12RadarTargetMark = @(){
  watch = EP12RadarTargetVisible
  size = flex()
  children = EP12RadarTargetVisible.get() ? [
    {
      size = static [pw(3), ph(3)]
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
    size = static [pw(100), ph(10)]
    pos = [pw(10), 0]
    flow = FLOW_HORIZONTAL
    children = [
      @() {
        watch = IlsColor
        size = [baseLineWidth * (small ? 2 : 4), baseLineWidth * IlsLineScale.get()]
        rendObj = ROBJ_SOLID
        color = IlsColor.get()
        lineWidth = baseLineWidth * IlsLineScale.get()
        vplace = ALIGN_CENTER
      },
      (num % 20 > 0 ? null :
        @() {
          watch = IlsColor
          rendObj = ROBJ_TEXT
          color = IlsColor.get()
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

  let getOffset = @() (20.0 - Altitude.get() * 0.001 - 0.25 + 0.05) * height * 2.0
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
        lineWidth = baseLineWidth * IlsLineScale.get()
        color = IlsColor.get()
        commands = [
          [VECTOR_LINE, 0, 45, 10, 50],
          [VECTOR_LINE, 0, 55, 10, 50]
        ]
      }
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, Tangage.get() * height * 0.07]
      }
    }
  }
}

function EP08Alt(width, height) {
  return {
    size = static [pw(15), ph(10)]
    children = [EPAltCCIP]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [width * 0.5, (Tangage.get() * 0.07 + 0.47) * height]
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
        rotate = -Roll.get()
      }
    }
  }
}

function getBulletImpactLineCommand() {
  let commands = []
  for (local i = 0; i < BulletImpactPoints.get().len() - 2; ++i) {
    let point1 = BulletImpactPoints.get()[i]
    let point2 = BulletImpactPoints.get()[i + 1]
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
  children = BulletImpactLineEnable.get() && !CCIPMode.get() ? [
    @() {
      watch = [BulletImpactPoints, IlsColor]
      rendObj = ROBJ_VECTOR_CANVAS
      size = flex()
      color = IlsColor.get()
      lineWidth = baseLineWidth * IlsLineScale.get()
      commands = getBulletImpactLineCommand()
    }
  ] : null
}

let haveShell = Computed(@() ShellCnt.get() > 0)
function EPAimMark(width, height, is_need_gun_ret) {
  return @() {
    watch = [CCIPMode, BombingMode]
    size = flex()
    children = CCIPMode.get() || BombingMode.get() ?
      @() {
        watch = [IlsColor, TargetPosValid, haveShell]
        size = static [pw(20), ph(10)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.get()
        fillColor = IlsColor.get()
        lineWidth = baseLineWidth * IlsLineScale.get()
        commands = [
          [VECTOR_ELLIPSE, 0, 0, 3, 6],
          [VECTOR_LINE, -100, -100, -100, 100],
          [VECTOR_LINE, 100, -100, 100, 100],
          [VECTOR_FILL_COLOR, Color(0, 0, 0, 0)],
          (haveShell.get() ? [VECTOR_ELLIPSE, 60, -80, 10, 20] : []),
          (TargetPosValid.get() ? [VECTOR_LINE, -50, 90, 50, 90] : []),
          (TargetPosValid.get() ? [VECTOR_LINE, -30, 90, -30, 70] : []),
          (TargetPosValid.get() ? [VECTOR_LINE, 0, 90, 0, 70] : []),
          (TargetPosValid.get() ? [VECTOR_LINE, 30, 90, 30, 70] : [])
        ]
        children = EPAltCCIP
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            translate = TargetPosValid.get() && CCIPMode.get() ? TargetPos.get() : [width * 0.5, height * 0.5]
          }
        }
      } :
      ( is_need_gun_ret ? @() {
        watch = [IlsColor, TargetPosValid]
        size = static [pw(7), ph(7)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.get()
        fillColor = IlsColor.get()
        lineWidth = baseLineWidth * IlsLineScale.get() * 2.0
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
            translate = TargetPosValid.get() ? TargetPos.get() : [width * 0.5, height * 0.5]
          }
        }
      } : null)
  }
}

function EPCCRPTargetMark(width, height) {
  return @() {
    watch = [TargetPosValid, BombCCIPMode]
    size = flex()
    children = BombCCIPMode.get() || BombingMode.get() ?
      @() {
        watch = IlsColor
        size = static [pw(2), ph(2)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.get()
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth * IlsLineScale.get()
        commands = [
          [VECTOR_ELLIPSE, 0, 0, 100, 100],
        ]
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            translate = TargetPosValid.get() && BombingMode.get() ? TargetPos.get() : [width * 0.5, height * 0.5]
          }
        }
      } : null
  }
}

let EP08AAMMarker = @() {
  watch = IlsTrackerVisible
  size = flex()
  children = IlsTrackerVisible.get() ?
  @() {
    watch = [GuidanceLockState, IlsColor]
    size = flex()
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.get()
    fillColor = IlsColor.get()
    lineWidth = baseLineWidth * IlsLineScale.get()
    commands = [
      (GuidanceLockState.get() == GuidanceLockResult.RESULT_TRACKING ? [VECTOR_ELLIPSE, 50, 50, 0.5, 0.5] : []),
      (GuidanceLockState.get() != GuidanceLockResult.RESULT_TRACKING ? [VECTOR_LINE, 60, 47, 60, 53] : []),
      (GuidanceLockState.get() != GuidanceLockResult.RESULT_TRACKING ? [VECTOR_LINE, 40, 47, 40, 53] : []),
      (GuidanceLockState.get() == GuidanceLockResult.RESULT_TRACKING ? [VECTOR_LINE, 65, 45, 65, 55] : []),
      (GuidanceLockState.get() == GuidanceLockResult.RESULT_TRACKING ? [VECTOR_LINE, 35, 45, 35, 55] : []),
      (GuidanceLockState.get() == GuidanceLockResult.RESULT_TRACKING ? [VECTOR_LINE, 42, 55, 57, 55] : []),
      (GuidanceLockState.get() == GuidanceLockResult.RESULT_TRACKING ? [VECTOR_LINE, 55, 55, 55, 53] : []),
      (GuidanceLockState.get() == GuidanceLockResult.RESULT_TRACKING ? [VECTOR_LINE, 50, 55, 50, 53] : []),
      (GuidanceLockState.get() == GuidanceLockResult.RESULT_TRACKING ? [VECTOR_LINE, 45, 55, 45, 53] : [])
    ]
    children =
      @() {
        watch = AamAccelLock
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.get()
        lineWidth = baseLineWidth * IlsLineScale.get()
        commands = [
          (AamAccelLock.get() ? [VECTOR_LINE, 42, 50, 48, 50] : []),
          (AamAccelLock.get() ? [VECTOR_LINE, 52, 50, 58, 50] : [])
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
      (!CCIPMode.get() && !BombingMode.get() && !IlsTrackerVisible.get() ? flyDirection(width, height, true) : null),
      (!CCIPMode.get() && !BombingMode.get() ? navigationInfo(width, height, is_ep08) : null),
      EPAimMark(width, height, !is_ep08),
      EP08AAMMarker,
      (is_ep08 ? EPCCRPTargetMark(width, height) : null),
      (!is_ep08 ? bulletsImpactLine : null),
      (!is_ep08 ? EP12RadarTargetMark : null)
    ]
  }
}

return swedishEPIls