from "%rGui/globals/ui_library.nut" import *
let { Aoa, ClimbSpeed, Altitude, Speed, Tangage, Roll } = require("%rGui/planeState/planeFlyState.nut")
let {baseLineWidth, mpsToFpm, metrToFeet, mpsToKnots, GuidanceLockResult} = require("ilsConstants.nut")
let {IlsColor, IlsLineScale, TargetPos, RocketMode, CannonMode, BombCCIPMode, BombingMode,
  TargetPosValid, DistToTarget, RadarTargetDist, TimeBeforeBombRelease, TvvMark} = require("%rGui/planeState/planeToolsState.nut")
let {cvt} = require("dagor.math")
let string = require("string")
let {SUMAltitude} = require("commonElements.nut")
let { AdlPoint } = require("%rGui/planeState/planeWeaponState.nut")
let {sin, cos} = require("math")
let { degToRad } = require("%sqstd/math_ex.nut")
let {IlsTrackerVisible, IlsTrackerX, IlsTrackerY, GuidanceLockState} = require("%rGui/rocketAamAimState.nut")

let SUMAoaMarkH = Computed(@() cvt(Aoa.value, 0, 25, 100, 0).tointeger())
let SUMAoa = @() {
  watch = SUMAoaMarkH
  rendObj = ROBJ_VECTOR_CANVAS
  size = [pw(3), ph(30)]
  pos = [pw(15), ph(30)]
  color = IlsColor.value
  lineWidth = baseLineWidth * 2 * IlsLineScale.value
  commands = [
    [VECTOR_LINE, 0, 0, 0, 0],
    [VECTOR_LINE, -60, 20, -60, 20],
    [VECTOR_LINE, 0, 20, 0, 20],
    [VECTOR_LINE, 0, 40, 0, 40],
    [VECTOR_LINE, -60, 60, -60, 60],
    [VECTOR_LINE, 0, 60, 0, 60],
    [VECTOR_LINE, 0, 80, 0, 80],
    [VECTOR_WIDTH, baseLineWidth * IlsLineScale.value],
    [VECTOR_LINE, 5, SUMAoaMarkH.value, 100, SUMAoaMarkH.value - 5],
    [VECTOR_LINE, 5, SUMAoaMarkH.value, 100, SUMAoaMarkH.value + 5],
    (SUMAoaMarkH.value < 96 ? [VECTOR_LINE, 80, 100, 80, SUMAoaMarkH.value + (Aoa.value > 0 ? 4 : -4)] : []),
    [VECTOR_LINE, 0, 100, 80, 100],
  ]
}

let SUMVSMarkH = Computed(@() cvt(ClimbSpeed.value * mpsToFpm, 2000, -3000, -33, 133).tointeger())
let SUMVerticalSpeed = @() {
  watch = SUMVSMarkH
  rendObj = ROBJ_VECTOR_CANVAS
  size = [pw(3), ph(40)]
  pos = [pw(85), ph(30)]
  color = IlsColor.value
  lineWidth = baseLineWidth * 2 * IlsLineScale.value
  commands = [
    [VECTOR_LINE, 0, 0, 0, 0],
    [VECTOR_LINE, -60, 0, -60, 0],
    [VECTOR_LINE, 0, 16, 0, 16],
    [VECTOR_LINE, 0, 34, 0, 34],
    [VECTOR_LINE, 0, 52, 0, 52],
    [VECTOR_LINE, 0, 68, 0, 68],
    [VECTOR_LINE, -60, 68, -60, 68],
    [VECTOR_LINE, 0, 84, 0, 84],
    [VECTOR_LINE, 0, 100, 0, 100],
    [VECTOR_LINE, -60, 100, -60, 100],
    [VECTOR_WIDTH, baseLineWidth * IlsLineScale.value],
    [VECTOR_LINE, 0, 34, 100, 34],
    [VECTOR_LINE, 5, SUMVSMarkH.value, 100, SUMVSMarkH.value - 5],
    [VECTOR_LINE, 5, SUMVSMarkH.value, 100, SUMVSMarkH.value + 5],
    (SUMVSMarkH.value < 30 || SUMVSMarkH.value > 38 ? [VECTOR_LINE, 80, 34, 80, SUMVSMarkH.value + (ClimbSpeed.value > 0.0 ? 4 : -4)] : [])
  ]
}

let CCIPMode = Computed(@() RocketMode.value || CannonMode.value || BombCCIPMode.value)

let SpeedWatch = Computed(@() (Speed.value * mpsToKnots).tointeger())
let speed = @() {
  watch = Speed
  rendObj = ROBJ_TEXT
  size = SIZE_TO_CONTENT
  pos = [pw(25), ph(25)]
  color = IlsColor.value
  fontSize = 40
  font = Fonts.hud
  text = SpeedWatch.value.tostring()
}

let mainReticle = @() {
  watch = IlsColor
  rendObj = ROBJ_VECTOR_CANVAS
  size = [pw(2), ph(2)]
  color = IlsColor.value
  lineWidth = baseLineWidth * IlsLineScale.value
  commands = [
    [VECTOR_LINE, -100, 0, -40, 0],
    [VECTOR_LINE, 0, -100, 0, -40],
    [VECTOR_LINE, 100, 0, 40, 0],
    [VECTOR_LINE, 0, 100, 0, 40]
  ]
}

let CcipReticleSector = Computed(@() cvt(DistToTarget.value, 0.0, 4000.0, -90.0, 269.0).tointeger())
let adlMarker = @() {
  watch = [BombingMode, TargetPosValid]
  size = flex()
  children = TargetPosValid.value ? [
    mainReticle,
    (CCIPMode.value ? @(){
      watch = CcipReticleSector
      size = [pw(5), pw(5)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.value
      fillColor = Color(0, 0, 0, 0  )
      lineWidth = baseLineWidth * IlsLineScale.value
      commands = [
        [VECTOR_SECTOR, 0, 0, 95, 95, -90, CcipReticleSector.value],
        [VECTOR_LINE, 0, -95, 0, -115],
        [VECTOR_LINE, 95 * cos(degToRad(CcipReticleSector.value)), 95 * sin(degToRad(CcipReticleSector.value)),
         115 * cos(degToRad(CcipReticleSector.value)), 115 * sin(degToRad(CcipReticleSector.value))]
      ]
    } : null)
  ] : null
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      translate = CCIPMode.value || BombingMode.value ? TargetPos.value : [AdlPoint[0], AdlPoint[1]]
    }
  }
}

let function pitch(width, height, generateFunc) {
  const step = 5.0
  let children = []

  for (local i = 90.0 / step; i >= -90.0 / step; --i) {
    let num = i * step

    children.append(generateFunc(num))
  }

  return {
    size = [width * 0.5, height * 0.5]
    pos = [width * 0.2, height * 0.5]
    flow = FLOW_VERTICAL
    children = children
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, -height * (90.0 - Tangage.value) * 0.06]
        rotate = -Roll.value
        pivot=[0.5, (90.0 - Tangage.value) * 0.12]
      }
    }
  }
}

let function angleTxt(num, isLeft, invVPlace = 1, x = 0, y = 0) {
  return @() {
    watch = IlsColor
    pos = [x, y]
    rendObj = ROBJ_TEXT
    vplace = (num * invVPlace) < 0 ? ALIGN_BOTTOM : ALIGN_TOP
    hplace = isLeft ? ALIGN_LEFT : ALIGN_RIGHT
    color = IlsColor.value
    fontSize = 35
    font = Fonts.hud
    text = string.format("%d", num)
  }
}

let function generatePitchLine(num) {
  let newNum = num <= 0 ? num : (num - 5)
  return {
    size = [pw(80), ph(60)]
    pos = [pw(20), 0]
    flow = FLOW_VERTICAL
    children = num == 0 ? [
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.value
        color = IlsColor.value
        commands = [
          [VECTOR_LINE, -10, 0, 25, 0],
          [VECTOR_LINE, 75, 0, 110, 0]
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
        padding = [10, 0]
        commands = [
          [VECTOR_LINE, 21, 4, 21, 0],
          [VECTOR_LINE, 0, 0, num > 0 ? 21 : 3, 0],
          (num < 0 ? [VECTOR_LINE, 6, 0, 9, 0] : []),
          (num < 0 ? [VECTOR_LINE, 12, 0, 15, 0] : []),
          (num < 0 ? [VECTOR_LINE, 18, 0, 21, 0] : []),
          [VECTOR_LINE, 79, 4, 79, 0],
          [VECTOR_LINE, 100, 0, num > 0 ? 79 : 97, 0],
          (num < 0 ? [VECTOR_LINE, 94, 0, 91, 0] : []),
          (num < 0 ? [VECTOR_LINE, 88, 0, 85, 0] : []),
          (num < 0 ? [VECTOR_LINE, 82, 0, 79, 0] : [])
        ]
        children = newNum <= 90 && newNum != 0 ? [angleTxt(newNum, false, -1, 0)] : null
      }
    ]
  }
}

let ReticleSector = Computed(@() cvt(RadarTargetDist.value, 0.0, 4000.0, -90.0, 269.0).tointeger())
let TargetByRadar = Computed(@() RadarTargetDist.value >= 0.0 )
let gunReticle = @(){
  watch = [TargetByRadar, CCIPMode, BombingMode]
  size = flex()
  children = CCIPMode.value || BombingMode.value ? null : (TargetByRadar.value ? [
    @(){
      watch = ReticleSector
      size = [pw(5), pw(5)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.value
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.value
      commands = [
        [VECTOR_SECTOR, 0, 0, 95, 95, -90, ReticleSector.value],
        [VECTOR_LINE, -80, 0, -20, 0],
        [VECTOR_LINE, 80, 0, 20, 0],
        [VECTOR_LINE, 0, 80, 0, 20],
        [VECTOR_LINE, 0, -80, 0, -20],
        [VECTOR_LINE, 0, -115, 0, -95]
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = TargetPos.value
        }
      }
    }
  ] : [
    {
      size = [pw(5), pw(5)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.value
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.value
      commands = [
        [VECTOR_ELLIPSE, 0, 0, 35, 35],
        [VECTOR_LINE, 0, 0, 0, 0],
        [VECTOR_LINE, -100, 0, -35, 0],
        [VECTOR_LINE, 100, 0, 35, 0],
        [VECTOR_LINE, 0, -100, 0, -35],
        [VECTOR_LINE, 0, 100, 0, 35]
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = TargetPos.value
        }
      }
    }
  ])
}

let AltThousandAngle = Computed(@() (Altitude.value * metrToFeet % 1000 / 2.7777 - 90.0).tointeger())
let altCircle = @(){
  watch = [CCIPMode, BombingMode]
  size = [pw(16), pw(16)]
  pos = [pw(58.5), ph(18.5)]
  children = CCIPMode.value || BombingMode.value ? [
    {
      size = flex()
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.value
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.value * 2
      commands = [
        [VECTOR_LINE, 50, 0, 50, 0],
        [VECTOR_LINE, 50, 100, 50, 100],
        [VECTOR_LINE, 20.6, 9.5, 20.6, 9.5],
        [VECTOR_LINE, 2.4, 34.5, 2.4, 34.5],
        [VECTOR_LINE, 2.4, 65.5, 2.4, 65.5],
        [VECTOR_LINE, 20.6, 90.5, 20.6, 90.5],
        [VECTOR_LINE, 80.6, 90.5, 80.6, 90.5],
        [VECTOR_LINE, 97.6, 65.5, 97.6, 65.5],
        [VECTOR_LINE, 97.6, 34.5, 97.6, 34.5],
        [VECTOR_LINE, 80.6, 9.5, 80.6, 9.5]
      ]
      children = [
        @(){
          watch = AltThousandAngle
          rendObj = ROBJ_VECTOR_CANVAS
          size = [pw(50), ph(50)]
          pos = [pw(50), ph(50)]
          color = IlsColor.value
          fillColor = Color(0, 0, 0, 0)
          lineWidth = baseLineWidth * IlsLineScale.value * 1.5
          commands = [
            [VECTOR_LINE, 80 * cos(degToRad(AltThousandAngle.value)), 80 * sin(degToRad(AltThousandAngle.value)),
             50 * cos(degToRad(AltThousandAngle.value)), 50 * sin(degToRad(AltThousandAngle.value))]
          ]
        }
      ]
    }
  ] : null
}

let isAAMMode = Computed(@() GuidanceLockState.value > GuidanceLockResult.RESULT_STANDBY)
let ReticleSectorAam = Computed(@() cvt(RadarTargetDist.value, 0.0, 10000.0, -90.0, 269.0).tointeger())
let aamReticle = @(){
  watch = [isAAMMode, IlsTrackerVisible]
  size = [pw(8), ph(8)]
  children = isAAMMode.value && IlsTrackerVisible.value ? [
    @(){
      watch = TargetByRadar
      rendObj = ROBJ_VECTOR_CANVAS
      size = flex()
      color = IlsColor.value
      lineWidth = baseLineWidth * IlsLineScale.value
      commands = [
        [VECTOR_LINE, -70, 0, 0, -70],
        [VECTOR_LINE, 0, -70, 70, 0],
        [VECTOR_LINE, 70, 0, 0, 70],
        [VECTOR_LINE, 0, 70, -70, 0],
        [VECTOR_LINE, -30, 0, TargetByRadar.value ? -100 : -70, 0],
        [VECTOR_LINE, 30, 0, TargetByRadar.value ? 100 : 70, 0],
        [VECTOR_LINE, 0, -30, 0, TargetByRadar.value ? -100 : -70],
        [VECTOR_LINE, 0, 30, 0, TargetByRadar.value ? 100 : 70]
      ]
      children = TargetByRadar.value ? [
        @() {
          watch = ReticleSectorAam
          size = flex()
          rendObj = ROBJ_VECTOR_CANVAS
          color = IlsColor.value
          fillColor = Color(0, 0, 0, 0)
          lineWidth = baseLineWidth * IlsLineScale.value
          commands = [
            [VECTOR_SECTOR, 0, 0, 100, 100, -90, ReticleSectorAam.value],
            [VECTOR_LINE, 0, -100, 0, -120],
            [VECTOR_LINE, 100 * cos(degToRad(ReticleSectorAam.value)), 100 * sin(degToRad(ReticleSectorAam.value)),
            120 * cos(degToRad(ReticleSectorAam.value)), 120 * sin(degToRad(ReticleSectorAam.value))]
          ]
        }
      ] : null
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = [IlsTrackerX.value, IlsTrackerY.value]
        }
      }
    }
  ] : null
}

let ccrpTimeAngle = Computed(@() cvt(TimeBeforeBombRelease.value, 0.0, 60.0, -90.0, 269.0).tointeger())
let ccrp = @(){
  watch = BombingMode
  size = flex()
  children = BombingMode.value ? [
    {
      rendObj = ROBJ_VECTOR_CANVAS
      size = [pw(5), ph(5)]
      color = IlsColor.value
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.value
      commands = [
        [VECTOR_ELLIPSE, 0, 0, 30, 30],
        [VECTOR_LINE, -100, 0, -30, 0],
        [VECTOR_LINE, 30, 0, 100, 0]
      ]
    },
    {
      rendObj = ROBJ_SOLID
      size = [baseLineWidth * IlsLineScale.value, ph(100)]
      color = IlsColor.value
      pos = [-baseLineWidth * IlsLineScale.value * 0.5, 0]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          rotate = -Roll.value
          pivot = [0, 0]
        }
      }
    },
    @() {
      watch = ccrpTimeAngle
      size = [pw(7), ph(7)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.value
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.value
      commands = [
        [VECTOR_SECTOR, 0, 0, 100, 100, -90, ccrpTimeAngle.value],
        [VECTOR_LINE, 0, -100, 0, -120],
        [VECTOR_LINE, 100 * cos(degToRad(ccrpTimeAngle.value)), 100 * sin(degToRad(ccrpTimeAngle.value)),
          120 * cos(degToRad(ccrpTimeAngle.value)), 120 * sin(degToRad(ccrpTimeAngle.value))]
      ]
    }
  ] : null
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      translate = [TvvMark[0], TvvMark[1]]
    }
  }
}

let function IlsTornado(width, height) {
  return {
    size = [width, height]
    children = [
      SUMAoa,
      SUMVerticalSpeed,
      SUMAltitude(40),
      speed,
      adlMarker,
      pitch(width, height, generatePitchLine),
      gunReticle,
      altCircle,
      aamReticle,
      ccrp
    ]
  }
}

return IlsTornado