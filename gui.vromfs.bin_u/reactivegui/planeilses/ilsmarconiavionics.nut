from "%rGui/globals/ui_library.nut" import *
let {floor} = require("%sqstd/math.nut")
let {IlsColor, IlsLineScale, TvvMark, RadarTargetPosValid, RadarTargetDist,
  RadarTargetDistRate, RocketMode, CannonMode, BombCCIPMode, BombingMode,
  RadarTargetPos, TargetPos, TargetPosValid, TimeBeforeBombRelease, DistToTarget } = require("%rGui/planeState/planeToolsState.nut")
let {baseLineWidth, mpsToKnots, metrToFeet, metrToNavMile} = require("ilsConstants.nut")
let {GuidanceLockResult} = require("%rGui/guidanceConstants.nut")
let {Tangage, Overload, Altitude, Speed, Roll, Mach} = require("%rGui/planeState/planeFlyState.nut")
let string = require("string")
let { AdlPoint } = require("%rGui/planeState/planeWeaponState.nut")
let {compassWrap, generateCompassMarkSU145} = require("ilsCompasses.nut")
let {IlsTrackerVisible, IlsTrackerX, IlsTrackerY, GuidanceLockState} = require("%rGui/rocketAamAimState.nut")

let isAAMMode = Computed(@() GuidanceLockState.value > GuidanceLockResult.RESULT_STANDBY)
let CCIPMode = Computed(@() RocketMode.value || CannonMode.value || BombCCIPMode.value)


let function pitch(width, height, generateFunc) {
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
        translate = [0, -height * (90.0 - Tangage.value) * 0.08]
        rotate = -Roll.value
        pivot=[0.5, (90.0 - Tangage.value) * 0.16]
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
    fontSize = 45
    font = Fonts.hud
    text = string.format("%d", num)
  }
}

let function generatePitchLine(num) {
  let sign = num > 0 ? 1 : -1
  let newNum = num >= 0 ? num : (num - 2.5)
  return {
    size = [pw(60), ph(40)]
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
        children = newNum <= 90 && newNum % 5 == 0 ? [angleTxt(newNum, true, 1, pw(-25)), angleTxt(newNum, false, 1, pw(25))] : null
      }
    ]
  }
}

let function KaiserTvvLinked(width, height) {
  return @(){
    watch = isAAMMode
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
      (!isAAMMode.value ? pitch(width, height, generatePitchLine) : null)
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

let generateSpdMark = function(num) {
  let ofs = num < 10 ? pw(-15) : pw(-30)
  return {
    size = [pw(100), ph(7.5)]
    pos = [pw(30), 0]
    children = [
      ( num % 5 > 0 ? null :
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
    children.append(generateFunc(i/10))
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

let function speedWrap(width, height, generateFunc) {
  return {
    size = [width * 0.17, height * 0.5]
    pos = [width * 0.1, height * 0.2]
    clipChildren = true
    children = [
      speed(height * 0.5, generateFunc),
      {
        size = [pw(25), baseLineWidth * IlsLineScale.value]
        pos = [pw(70), ph(50)]
        watch = IlsColor
        rendObj = ROBJ_SOLID
        color = IlsColor.value
      },
      {
        size = SIZE_TO_CONTENT
        pos = [pw(75), ph(42)]
        rendObj = ROBJ_TEXT
        color = IlsColor.value
        fontSize = 40
        text = "G"
      }
    ]
  }
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
      ( num % 5 > 0 ? null :
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

  let getOffset = @() ((65000 - Altitude.value * metrToFeet) * 0.0007425 - 0.48) * height
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
  pos = [pw(20), ph(20)]
  rendObj = ROBJ_TEXT
  color = IlsColor.value
  fontSize = 40
  text = string.format("%.1f", OverloadWatch.value / 10.0)
}

let armLabel = @(){
  watch = IlsColor
  size = flex()
  pos = [pw(22), ph(70)]
  rendObj = ROBJ_TEXT
  color = IlsColor.value
  fontSize = 35
  text = "ARM"
}

let MachWatch = Computed(@() (floor(Mach.value * 100)).tointeger())
let mach = @() {
  watch = [MachWatch, IlsColor]
  size = flex()
  pos = [pw(22), ph(74)]
  rendObj = ROBJ_TEXT
  color = IlsColor.value
  fontSize = 35
  text = string.format("%.2f", MachWatch.value / 100.0)
}

let radarTarget = @(){
  size = [pw(8), ph(8)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.value
  fillColor = Color(0, 0, 0, 0)
  lineWidth = baseLineWidth * IlsLineScale.value
  commands = [
    [VECTOR_RECTANGLE, -50, -50, 100, 100]
  ]
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      translate = RadarTargetPos
    }
  }
}

let radarDist = Computed(@() (RadarTargetDist.value * metrToNavMile * 10).tointeger())
let raderClosureSpeed = Computed(@() (RadarTargetDistRate.value * mpsToKnots * -1.0).tointeger())
let radarTargetDist = @() {
  watch = [RadarTargetPosValid, BombingMode]
  size = flex()
  children = RadarTargetPosValid.value && !BombingMode.value ?
  [
    {
      size = flex()
      children = [
        @() {
          watch = [IlsColor, radarDist]
          size = SIZE_TO_CONTENT
          rendObj = ROBJ_TEXT
          pos = [pw(72), ph(70)]
          color = IlsColor.value
          fontSize = 35
          text = string.format("%02d.%d", radarDist.value / 10, radarDist.value % 10)
        },
        @() {
          watch = [IlsColor, raderClosureSpeed]
          pos = [pw(72), ph(74)]
          size = SIZE_TO_CONTENT
          rendObj = ROBJ_TEXT
          color = IlsColor.value
          fontSize = 35
          text = raderClosureSpeed.value.tostring()
        }
      ]
    },
    radarTarget
  ] : null
}

let ilsMode = @(){
  watch = [IlsColor, isAAMMode, CCIPMode, BombingMode]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(15), ph(82)]
  color = IlsColor.value
  fontSize = 35
  text = isAAMMode.value ? "MSLS" : (BombingMode.value ? "CCRP" : (CCIPMode.value ? "CCIP" : "LCOS"))
}

let AamIsReady = Computed(@() GuidanceLockState.value == GuidanceLockResult.RESULT_TRACKING)
let aamCircle = @(){
  watch = IlsTrackerVisible
  size = flex()
  children = IlsTrackerVisible.value ? [
    @(){
      watch = AamIsReady
      size = [pw(10), ph(10)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.value
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.value
      commands = [
        [VECTOR_LINE, -10, 0, 0, -10],
        [VECTOR_LINE, 10, 0, 0, 10],
        [VECTOR_LINE, 0, -10, 10, 0],
        [VECTOR_LINE, 0, 10, -10, 0],
      ]
      children = AamIsReady.value ? [
        {
          key = $"AamIlsAnim_1"
          size = flex()
          rendObj = ROBJ_VECTOR_CANVAS
          color = IlsColor.value
          fillColor = Color(0, 0, 0, 0)
          lineWidth = baseLineWidth * IlsLineScale.value
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
        {
          key = $"AamIlsAnim_0"
          size = flex()
          rendObj = ROBJ_VECTOR_CANVAS
          color = IlsColor.value
          fillColor = Color(0, 0, 0, 0)
          lineWidth = baseLineWidth * IlsLineScale.value
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
          translate = [IlsTrackerX.value, IlsTrackerY.value]
        }
      }
    }
  ] : null
}

let LCOSwatch = Computed(@() !isAAMMode.value && !CCIPMode.value && !BombingMode.value)
let lcos = @() {
  watch = LCOSwatch
  size = flex()
  children = LCOSwatch.value ? [
    {
      size = [pw(10), ph(10)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.value
      lineWidth = baseLineWidth * IlsLineScale.value
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
          translate = TargetPos.value
        }
      }
    }
  ] : null
}

let function ccip(width, height){
  return @() {
    watch = [CCIPMode, TargetPosValid]
    size = flex()
    children = CCIPMode.value && TargetPosValid.value ?
    [
      {
        size = [pw(3), pw(3)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
        fillColor = Color(0, 0, 0, 0)
        commands = [
          [VECTOR_ELLIPSE, 0, 0, 100, 100],
          [VECTOR_LINE, 0, 0, 0, 0]
        ]
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            translate = TargetPos.value
          }
        }
      },
      @() {
        watch = TargetPos
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
        commands = [
          [VECTOR_LINE, TvvMark[0] / width * 100, TvvMark[1] / height * 100,
           TargetPos.value[0] / width * 100,
           TargetPos.value[1] / height * 100]
        ]
      }
    ] : null
  }
}

let TimeToRelease = Computed(@() TimeBeforeBombRelease.value < 100.0 ? TimeBeforeBombRelease.value.tointeger() : 999)
let DistToTargetCcrp = Computed(@() (DistToTarget.value * metrToNavMile * 10.0).tointeger())
let function ccrp(height) {
  return @() {
    watch = [BombingMode, TargetPosValid]
    size = flex()
    children = BombingMode.value && TargetPosValid.value ? [
      {
        size = [pw(4), ph(4)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth * IlsLineScale.value
        commands = [
          [VECTOR_LINE, 0, 0, 0, 0],
          [VECTOR_WIDTH, baseLineWidth * IlsLineScale.value * 0.8],
          [VECTOR_RECTANGLE, -50, -50, 100, 100]
        ]
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            translate = TargetPos.value
          }
        }
      },
      @() {
        watch = TargetPosValid
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * 0.8 * IlsLineScale.value
        size = flex()
        color = IlsColor.value
        commands = [
          (TargetPosValid.value ? [VECTOR_LINE, 0, 100, 0, -100] : [])
        ]
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            translate = TargetPosValid.value ? [TargetPos.value[0], clamp(TargetPos.value[1], 0, height)] : [TargetPos.value[0], height]
            rotate = -Roll.value
            pivot = [0, 0]
          }
        }
      },
      @() {
        watch = [IlsColor, DistToTargetCcrp]
        size = SIZE_TO_CONTENT
        rendObj = ROBJ_TEXT
        pos = [pw(72), ph(70)]
        color = IlsColor.value
        fontSize = 35
        text = string.format("%02d.%dNM", DistToTargetCcrp.value / 10, DistToTargetCcrp.value % 10)
      },
      @() {
        watch = [IlsColor, TimeToRelease]
        pos = [pw(72), ph(74)]
        size = SIZE_TO_CONTENT
        rendObj = ROBJ_TEXT
        color = IlsColor.value
        fontSize = 35
        text = string.format("%dSEC", TimeToRelease.value)
      }
    ] : null
  }
}

let function MarconiAvionics(width, height) {
  return {
    size = [width, height]
    children = [
      KaiserTvvLinked(width, height),
      adlMarker,
      speedWrap(width, height, generateSpdMark),
      altWrap(width, height, generateAltMark),
      {
        size = [pw(4), baseLineWidth * IlsLineScale.value]
        pos = [pw(72), ph(45)]
        watch = IlsColor
        rendObj = ROBJ_SOLID
        color = IlsColor.value
      },
      overload,
      compassWrap(width, height, 0.86, generateCompassMarkSU145, 0.8, 5.0, false, 12),
      {
        size = [baseLineWidth * IlsLineScale.value, ph(4)]
        pos = [pw(50), ph(95)]
        watch = IlsColor
        rendObj = ROBJ_SOLID
        color = IlsColor.value
      },
      armLabel,
      mach,
      radarTargetDist,
      ilsMode,
      aamCircle,
      lcos,
      ccip(width, height),
      ccrp(height)
    ]
  }
}

return MarconiAvionics