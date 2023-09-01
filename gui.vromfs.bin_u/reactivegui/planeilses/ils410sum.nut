from "%rGui/globals/ui_library.nut" import *

let { IlsColor, TargetPosValid, TargetPos, IlsLineScale, TimeBeforeBombRelease,
       AimLocked, RocketMode, CannonMode, BombCCIPMode, DistToSafety } = require("%rGui/planeState/planeToolsState.nut")
let { Speed, Roll, Aoa, ClimbSpeed, Tangage } = require("%rGui/planeState/planeFlyState.nut");
let { mpsToKnots, mpsToFpm, baseLineWidth } = require("ilsConstants.nut")
let { GuidanceLockResult } = require("%rGui/guidanceConstants.nut")
let { GuidanceLockState } = require("%rGui/rocketAamAimState.nut")
let { cvt } = require("dagor.math")
let { compassWrap, generateCompassMarkSUM } = require("ilsCompasses.nut")
let { yawIndicator, angleTxt, bombFallingLine, SUMAltitude } = require("commonElements.nut")

let CCIPMode = Computed(@() RocketMode.value || CannonMode.value || BombCCIPMode.value)

let SUMAoaMarkH = Computed(@() cvt(Aoa.value, -5, 20, 100, 0).tointeger())
let SUMAoa = @() {
  watch = [SUMAoaMarkH, IlsColor]
  rendObj = ROBJ_VECTOR_CANVAS
  size = [pw(3), ph(40)]
  pos = [pw(15), ph(30)]
  color = IlsColor.value
  lineWidth = baseLineWidth * 3 * IlsLineScale.value
  commands = [
    [VECTOR_LINE, 0, 16, 0, 16],
    [VECTOR_LINE, 0, 32, 0, 32],
    [VECTOR_LINE, 0, 48, 0, 48],
    [VECTOR_LINE, 0, 100, 0, 100],
    [VECTOR_WIDTH, baseLineWidth * IlsLineScale.value],
    [VECTOR_LINE, 0, 80, 100, 80],
    [VECTOR_LINE, 5, SUMAoaMarkH.value, 100, SUMAoaMarkH.value - 5],
    [VECTOR_LINE, 5, SUMAoaMarkH.value, 100, SUMAoaMarkH.value + 5],
    (SUMAoaMarkH.value < 76 || SUMAoaMarkH.value > 84 ? [VECTOR_LINE, 80, 80, 80, SUMAoaMarkH.value + (Aoa.value > 0 ? 4 : -4)] : [])
  ]
}

let SUMVSMarkH = Computed(@() cvt(ClimbSpeed.value * mpsToFpm, 1000, -2000, 0, 100).tointeger())
let SUMVerticalSpeed = @() {
  watch = [SUMVSMarkH, IlsColor]
  rendObj = ROBJ_VECTOR_CANVAS
  size = [pw(3), ph(40)]
  pos = [pw(85), ph(30)]
  color = IlsColor.value
  lineWidth = baseLineWidth * 3 * IlsLineScale.value
  commands = [
    [VECTOR_LINE, 0, 0, 0, 0],
    [VECTOR_LINE, 0, 16, 0, 16],
    [VECTOR_LINE, 0, 52, 0, 52],
    [VECTOR_LINE, 0, 68, 0, 68],
    [VECTOR_LINE, 0, 84, 0, 84],
    [VECTOR_LINE, 0, 100, 0, 100],
    [VECTOR_WIDTH, baseLineWidth * IlsLineScale.value],
    [VECTOR_LINE, 0, 34, 100, 34],
    [VECTOR_LINE, 5, SUMVSMarkH.value, 100, SUMVSMarkH.value - 5],
    [VECTOR_LINE, 5, SUMVSMarkH.value, 100, SUMVSMarkH.value + 5],
    (SUMVSMarkH.value < 30 || SUMVSMarkH.value > 38 ? [VECTOR_LINE, 80, 34, 80, SUMVSMarkH.value + (ClimbSpeed.value > 0.0 ? 4 : -4)] : [])
  ]
}

let flyDirectionSUM = @() {
  watch = IlsColor
  size = [pw(10), ph(10)]
  pos = [pw(50), ph(40)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.value
  fillColor = Color(0, 0, 0, 0)
  lineWidth = baseLineWidth * IlsLineScale.value
  commands = [
    [VECTOR_ELLIPSE, 0, 0, 20, 20],
    [VECTOR_LINE, -50, 0, -20, 0],
    [VECTOR_LINE, 20, 0, 50, 0]
  ]
}

let SUMSpeedValue = Computed(@() (Speed.value * mpsToKnots).tointeger())
let SUMSpeed = @() {
  watch = [SUMSpeedValue, IlsColor]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(27), ph(25)]
  color = IlsColor.value
  fontSize = 60
  font = Fonts.hud
  text = $"{SUMSpeedValue.value}T"
}

let function generatePitchLineSum(num) {
  let sign = num > 0 ? 1 : -1
  let newNum = num < 0 ? (num / -10) : ((num - 30) / 10)
  return {
    size = [pw(100), ph(100)]
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
          [VECTOR_LINE, 0, 0, 35, 0],
          [VECTOR_LINE, 35, 0, 35, 5],
          [VECTOR_LINE, 65, 0, 100, 0],
          [VECTOR_LINE, 65, 0, 65, 5]
        ]
      }
    ] : (num == 90 || num == -90 ? [
        @() {
          size = flex()
          watch = IlsColor
          rendObj = ROBJ_VECTOR_CANVAS
          lineWidth = baseLineWidth * IlsLineScale.value
          color = IlsColor.value
          commands = [
            [VECTOR_LINE, 50, sign > 0 ? 0 : 100, 50, sign > 0 ? 30 : 70],
            [VECTOR_LINE, 35, sign > 0 ? 10 : 92, 65, sign > 0 ? 10 : 92],
            (sign < 0 ? [VECTOR_LINE, 40, 85, 60, 85] : [])
          ]
          children = num == 90 ? [angleTxt(6, true, Fonts.hud, -1), angleTxt(6, false, Fonts.hud, -1)] : []
        }
      ] :
      [
        @() {
          watch = IlsColor
          size = flex()
          rendObj = ROBJ_VECTOR_CANVAS
          lineWidth = baseLineWidth * IlsLineScale.value
          color = IlsColor.value
          padding = [10, 10]
          commands = sign > 0 ? [
            [VECTOR_LINE, 0, 0, 5, 0],
            [VECTOR_LINE, 10, 0, 15, 0],
            [VECTOR_LINE, 20, 0, 25, 0],
            [VECTOR_LINE, 30, 0, 35, 0],
            [VECTOR_LINE, 35, 0, 35, 5],
            [VECTOR_LINE, 100, 0, 95, 0],
            [VECTOR_LINE, 90, 0, 85, 0],
            [VECTOR_LINE, 80, 0, 75, 0],
            [VECTOR_LINE, 70, 0, 65, 0],
            [VECTOR_LINE, 65, 0, 65, 5]
          ] : [
            [VECTOR_LINE, 0, 0, 12, 0],
            [VECTOR_LINE, 22, 0, 35, 0],
            [VECTOR_LINE, 35, 0, 35, 5],
            [VECTOR_LINE, 100, 0, 88, 0],
            [VECTOR_LINE, 78, 0, 65, 0],
            [VECTOR_LINE, 65, 0, 65, 5]
          ]
          children = newNum != 0 ? [angleTxt(newNum, true, Fonts.hud, -sign), angleTxt(newNum, false, Fonts.hud, -sign)] : null
        }
    ])
  }
}

let function pitchSum(height) {
  const step = 30.0
  let children = []

  for (local i = 90.0 / step; i >= -90.0 / step; --i) {
    let num = (i * step).tointeger()

    children.append(generatePitchLineSum(num))
  }

  return {
    size = [pw(40), ph(50)]
    pos = [pw(30), ph(40)]
    flow = FLOW_VERTICAL
    children = children
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, -height * (90.0 - Tangage.value) * 0.016666667]
        rotate = -Roll.value
        pivot = [0.5, (90.0 - Tangage.value) * 0.0333333]
      }
    }
  }
}

let function basic410SUM(width, height) {
  return @() {
    watch = CCIPMode
    size = [width, height]
    children = [
      SUMAoa,
      compassWrap(width, height, 0.85, generateCompassMarkSUM),
      pitchSum(height),
      (!CCIPMode.value ? flyDirectionSUM : null),
      SUMVerticalSpeed,
      SUMAltitude(60),
      SUMSpeed,
      yawIndicator
    ]
  }
}

let function SUMGunReticle(width, height) {
  return @() {
    watch = IlsColor
    size = [width * 0.1, height * 0.1]
    color = IlsColor.value
    lineWidth = baseLineWidth * IlsLineScale.value
    rendObj = ROBJ_VECTOR_CANVAS
    commands = [
      [VECTOR_LINE, 0, 0, 0, 0],
      [VECTOR_LINE, 0, -70, 0, -100],
      [VECTOR_LINE, 0, 70, 0, 100],
      [VECTOR_LINE, 70, 0, 100, 0],
      [VECTOR_LINE, -100, 0, -70, 0],
      [VECTOR_LINE, 35, 60.6, 50, 86.6],
      [VECTOR_LINE, 60.6, 35, 86.6, 50],
      [VECTOR_LINE, -35, -60.6, -50, -86.6],
      [VECTOR_LINE, -60.6, -35, -86.6, -50],
      [VECTOR_LINE, -35, 60.6, -50, 86.6],
      [VECTOR_LINE, -60.6, 35, -86.6, 50],
      [VECTOR_LINE, 35, -60.6, 50, -86.6],
      [VECTOR_LINE, 60.6, -35, 86.6, -50],
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [TargetPos.value[0], TargetPos.value[1]]
      }
    }
  }
}

let SUMCCIPReticle = @() {
  watch = IlsColor
  size = [pw(10), ph(10)]
  color = IlsColor.value
  lineWidth = baseLineWidth * IlsLineScale.value
  rendObj = ROBJ_VECTOR_CANVAS
  fillColor = Color(0, 0, 0, 0)
  commands = [
    [VECTOR_ELLIPSE, 0, 0, 20, 20],
    [VECTOR_LINE, -50, 0, -20, 0],
    [VECTOR_LINE, 20, 0, 50, 0],
    [VECTOR_LINE, 10, 17.3, 25, 43.3],
    [VECTOR_LINE, -10, 17.3, -25, 43.3]
  ]
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      translate = [TargetPos.value[0], TargetPos.value[1]]
    }
  }
}

let function SUMCCIPMode(width, height) {
  return @() {
    watch = TargetPosValid
    size = [width, height]
    children = [
      (TargetPosValid.value ? SUMCCIPReticle : null),
      @() {
        watch = [BombCCIPMode, IlsColor]
        size = [pw(3), ph(3)]
        pos = [pw(50), ph(BombCCIPMode.value ? 50 : 30)]
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
        rendObj = ROBJ_VECTOR_CANVAS
        commands = [
          [VECTOR_LINE, -100, 0, 100, 0],
          [VECTOR_LINE, 0, -100, 0, 100],
        ]
      }
    ]
  }
}

let function SumAAMCrosshair(position, anim) {
  return @() {
    watch = IlsColor
    size = [pw(2), ph(2)]
    pos = position
    color = IlsColor.value
    lineWidth = baseLineWidth * IlsLineScale.value
    rendObj = ROBJ_VECTOR_CANVAS
    commands = [
      [VECTOR_LINE, -100, -100, -50, -50],
      [VECTOR_LINE, 100, 100, 50, 50],
      [VECTOR_LINE, -100, 100, -50, 50],
      [VECTOR_LINE, 50, -50, 100, -100]
    ]
    transform = {}
    animations = [
      { prop = AnimProp.rotate, from = 0, to = 360, duration = 2.5, play = anim, loop = true }
    ]
  }
}

let function SumAAMMode(width, height) {
  return @() {
    watch = GuidanceLockState
    size = [width, height]
    children = [
      SumAAMCrosshair([width * 0.5, height * 0.5], false),
      (GuidanceLockState.value != GuidanceLockResult.RESULT_TRACKING ?
      {
        size = flex()
        children = [SumAAMCrosshair([width * 0.5, height * 0.25], true)]
        transform = {}
        animations = [
          { prop = AnimProp.rotate, from = 360, to = 0, duration = 2.5, play = true, loop = true }
        ]
      }
      : null)
    ]
  }
}

let function SUMCcrpTarget(width, height) {
  return @() {
    watch = AimLocked
    size = flex()
    children = AimLocked.value ?
      @() {
        watch = IlsColor
        size = [pw(10), baseLineWidth * IlsLineScale.value]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
        commands = [
          [VECTOR_LINE, 0, 0, 40, 0],
          [VECTOR_LINE, 60, 0, 100, 0]
        ]
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            translate = [width * 0.05, TargetPos.value[1] - height * 0.4]
          }
        }
      }
    : null
  }
}

let function rotatedBombReleaseSUM(width, height) {
  return @() {
    watch = TargetPosValid
    size = flex()
    children = TargetPosValid.value ? [
      SUMCcrpTarget(width, height),
      {
        size = [pw(20), flex()]
        flow = FLOW_VERTICAL
        halign = ALIGN_CENTER
        children = [bombFallingLine()]
      }
    ] : null
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [TargetPos.value[0] - width * 0.1, height * 0.4]
        rotate = -Roll.value
        pivot = [0.1, TargetPos.value[1] / height - 0.4]
      }
    }
  }
}

let cancelBombVisible = Computed(@() DistToSafety.value <= 0.0)
let cancelBombingSUM = @() {
  watch = cancelBombVisible
  size = flex()
  children = cancelBombVisible.value ?
    @() {
      watch = IlsColor
      size = [pw(7), ph(7)]
      pos = [pw(50), ph(30)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.value
      lineWidth = baseLineWidth * IlsLineScale.value
      commands = [
        [VECTOR_LINE, -40, -50, 40, 50],
        [VECTOR_LINE, -40, 50, 40, -50]
      ]
    }
  : null
}

let releaseMarkSector = Computed (@() cvt(TimeBeforeBombRelease.value, 10.0, 0, 260, -90).tointeger())
let timeToRelease = @() {
  watch = [releaseMarkSector, IlsColor]
  rendObj = ROBJ_VECTOR_CANVAS
  size = [pw(8), ph(8)]
  pos = [pw(50), ph(30)]
  color = IlsColor.value
  fillColor = Color(0, 0, 0, 0)
  lineWidth = baseLineWidth * IlsLineScale.value
  commands = [
    [VECTOR_SECTOR, 0, 0, 80, 80, -90, releaseMarkSector.value],
    [VECTOR_LINE, 0, -80, 0, -100]
  ]
}

let function SumBombingSight(width, height) {
  return {
    size = [width, height]
    children = [
      rotatedBombReleaseSUM(width, height),
      timeToRelease,
      cancelBombingSUM
    ]
  }
}

return {
  basic410SUM
  SUMCCIPMode
  SumAAMMode
  SumBombingSight
  SUMGunReticle
}