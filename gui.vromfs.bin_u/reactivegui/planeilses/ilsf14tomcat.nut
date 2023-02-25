from "%rGui/globals/ui_library.nut" import *

let { IlsColor, IlsLineScale, RadarTargetPosValid, RadarTargetPos, RadarTargetDist,
  BombingMode, BombCCIPMode, RocketMode, CannonMode,
  TargetPosValid, TargetPos } = require("%rGui/planeState/planeToolsState.nut")
let { baseLineWidth, metrToNavMile } = require("ilsConstants.nut")
let { GuidanceLockResult } = require("%rGui/guidanceConstants.nut")
let { AdlPoint, CurWeaponName, ShellCnt } = require("%rGui/planeState/planeWeaponState.nut")
let { Roll, Tangage, Altitude } = require("%rGui/planeState/planeFlyState.nut")
let { GuidanceLockState } = require("%rGui/rocketAamAimState.nut")
let { compassWrap, generateCompassMarkF14 } = require("ilsCompasses.nut")
let { flyDirection } = require("commonElements.nut")
let { AVQ7CCRP } = require("ilsAVQ7.nut")

let adlMarker = @() {
  watch = IlsColor
  rendObj = ROBJ_VECTOR_CANVAS
  size = [pw(3), ph(3)]
  color = IlsColor.value
  lineWidth = baseLineWidth * IlsLineScale.value
  commands = [
    [VECTOR_LINE, -100, 0, 100, 0],
    [VECTOR_LINE, 0, -100, 0, 100]
  ]
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      translate = [AdlPoint[0], AdlPoint[1]]
    }
  }
}

let planeMarker = @() {
  watch = IlsColor
  rendObj = ROBJ_VECTOR_CANVAS
  size = [pw(10), ph(3)]
  pos = [pw(50), ph(70)]
  color = IlsColor.value
  lineWidth = baseLineWidth * IlsLineScale.value
  commands = [
    [VECTOR_LINE, 0, 0, 0, 0],
    [VECTOR_LINE, 40, 0, 100, 0],
    [VECTOR_LINE, -100, 0, -40, 0],
    [VECTOR_LINE, 40, 0, 40, 100],
    [VECTOR_LINE, -40, 0, -40, 100]
  ]
}

let function targetMark(watchVar, is_radar) {
  return @() {
    watch = [IlsColor, watchVar]
    rendObj = ROBJ_VECTOR_CANVAS
    size = [pw(3), ph(3)]
    color = IlsColor.value
    fillColor = Color(0, 0, 0, 0)
    lineWidth = baseLineWidth * IlsLineScale.value
    commands = watchVar.value ? [
      [VECTOR_LINE, -100, 0, 0, -100],
      [VECTOR_LINE, 0, -100, 100, 0],
      [VECTOR_LINE, 100, 0, 0, 100],
      [VECTOR_LINE, 0, 100, -100, 0]
    ] : null
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = watchVar.value ? (is_radar ? RadarTargetPos : TargetPos.value) : [0, 0]
      }
    }
  }
}

let dist = Computed(@() RadarTargetDist.value * metrToNavMile)
let maxDist = Computed(@() dist.value < 1.0 ? 1.0 : (dist.value < 5.0 ? 5.0 : 10.0))
let distPos = Computed(@() (100 - min(dist.value / maxDist.value * 100.0, 100)).tointeger())
let targetDist = @() {
  watch = [IlsColor, RadarTargetPosValid, maxDist]
  rendObj = ROBJ_VECTOR_CANVAS
  size = [pw(20), ph(60)]
  pos = [pw(80), ph(20)]
  color = IlsColor.value
  lineWidth = 2 * baseLineWidth * IlsLineScale.value
  commands = RadarTargetPosValid.value ? ([
    [VECTOR_LINE, 0, 0, 0, 0],
    [VECTOR_LINE, 0, 20, 0, 20],
    [VECTOR_LINE, 0, 40, 0, 40],
    [VECTOR_LINE, 0, 60, 0, 60],
    [VECTOR_LINE, 0, 80, 0, 80]
  ]) : null
  children = RadarTargetPosValid.value ? [
    @() {
      watch = maxDist
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      pos = [pw(20), ph(-4)]
      color = IlsColor.value
      fontSize = 60
      font = Fonts.f14_ils
      text = maxDist.value.tostring()
    },
    @() {
      watch = distPos
      size = [pw(20), ph(100)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.value
      lineWidth = baseLineWidth * IlsLineScale.value
      commands = [
        [VECTOR_LINE, -30, distPos.value, -100, distPos.value - 3],
        [VECTOR_LINE, -30, distPos.value, -100, distPos.value + 3]
      ]
    }
  ] : null
}

let altPos = Computed(@() (100 - min(Altitude.value / 48.768,  100)).tointeger())
let altmetr = @() {
  watch = IlsColor
  rendObj = ROBJ_VECTOR_CANVAS
  size = [pw(20), ph(50)]
  pos = [pw(82), ph(40)]
  color = IlsColor.value
  lineWidth = 2 * baseLineWidth * IlsLineScale.value
  commands = [
    [VECTOR_LINE, 0, 12.5, 0, 12.5],
    [VECTOR_LINE, 0, 25, 0, 25],
    [VECTOR_LINE, 0, 37.5, 0, 37.5],
    [VECTOR_LINE, 0, 50, 0, 50],
    [VECTOR_LINE, 0, 62.5, 0, 62.5],
    [VECTOR_LINE, 0, 75, 0, 75],
    [VECTOR_LINE, 0, 87.5, 0, 87.5],
    [VECTOR_LINE, 0, 100, 0, 100]
  ]
  children = [
    {
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      pos = [pw(10), ph(33.5)]
      color = IlsColor.value
      fontSize = 60
      font = Fonts.f14_ils
      text = "10"
    },
    {
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      pos = [pw(10), ph(96)]
      color = IlsColor.value
      fontSize = 60
      font = Fonts.f14_ils
      text = "0"
    },
    @() {
      watch = altPos
      size = [pw(20), ph(100)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.value
      lineWidth = baseLineWidth * IlsLineScale.value
      commands = [
        [VECTOR_LINE, -30, altPos.value, -100, altPos.value - 3],
        [VECTOR_LINE, -30, altPos.value, -100, altPos.value + 3]
      ]
    }
  ]
}


let closureRate = @() {
  watch = [IlsColor, RadarTargetPosValid]
  rendObj = ROBJ_VECTOR_CANVAS
  size = [pw(20), ph(40)]
  pos = [pw(20), ph(20)]
  color = IlsColor.value
  lineWidth = 2 * baseLineWidth * IlsLineScale.value
  commands = RadarTargetPosValid.value ? ([
    [VECTOR_LINE, 0, 0, 0, 0],
    [VECTOR_LINE, 0, 16.6, 0, 16.6],
    [VECTOR_LINE, 0, 33.3, 0, 33.3],
    [VECTOR_LINE, 0, 50, 0, 50],
    [VECTOR_LINE, 0, 66.6, 0, 66.6],
    [VECTOR_LINE, 0, 83.3, 0, 83.3],
    [VECTOR_LINE, 0, 100, 0, 100]
  ]) : null
  children = RadarTargetPosValid.value ? [
    {
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      pos = [pw(-40), ph(-5)]
      color = IlsColor.value
      fontSize = 60
      font = Fonts.f14_ils
      text = "10"
    },
    {
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      pos = [pw(-25), ph(78)]
      color = IlsColor.value
      fontSize = 60
      font = Fonts.f14_ils
      text = "0"
    },
    {
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      pos = [pw(-40), ph(95)]
      color = IlsColor.value
      fontSize = 60
      font = Fonts.f14_ils
      text = "-2"
    }
  ] : null
}

let ShellMode = Computed(@() RocketMode.value || BombCCIPMode.value || BombingMode.value)
let isAAMMode = Computed(@() GuidanceLockState.value > GuidanceLockResult.RESULT_STANDBY)
let shellName = @() {
  watch = [IlsColor, CurWeaponName, ShellMode, isAAMMode]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [ShellMode.value ? pw(43.5) : (isAAMMode.value ? pw(46) : pw(48)), ph(80)]
  color = IlsColor.value
  fontSize = 80
  font = Fonts.f14_ils
  text = ShellMode.value ? "ORD" : (isAAMMode.value && !CannonMode.value ? loc(CurWeaponName.value) :  "G")
}

let shellValue = Computed(@() !isAAMMode.value ? ShellCnt.value / 100 : ShellCnt.value)
let shellCount = @() {
  watch = [IlsColor, shellValue]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(48), ph(88)]
  color = IlsColor.value
  fontSize = 80
  font = Fonts.f14_ils
  text = ShellMode.value ? "" : shellValue.value.tointeger()
}

let aimMark = @() {
  watch = [IlsColor, TargetPosValid]
  size = [pw(10), ph(10)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.value
  lineWidth = baseLineWidth * IlsLineScale.value
  commands = [
    [VECTOR_LINE, 0, 0, 0, 0],
    [VECTOR_LINE, -100, 0, -40, 0],
    [VECTOR_LINE, 100, 0, 40, 0],
    [VECTOR_LINE, 0, -100, 0, -40],
    [VECTOR_LINE, 0, 100, 0, 40],
    (!TargetPosValid.value ? [VECTOR_LINE, -40, 0, 0, -40] : []),
    (!TargetPosValid.value ? [VECTOR_LINE, 40, 0, 0, 40] : []),
    (!TargetPosValid.value ? [VECTOR_LINE, 0, -40, 40, 0] : []),
    (!TargetPosValid.value ? [VECTOR_LINE, 0, 40, -40, 0] : [])
  ]
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      translate = TargetPos.value
    }
  }
}

let compass = function(width, height) {
  return @() {
    watch = [ShellMode, CannonMode]
    size = flex()
    children = ShellMode.value || CannonMode.value ?
    [
      compassWrap(width, height, 0.2, generateCompassMarkF14, 1.2),
      {
        size = [pw(2), ph(4)]
        pos = [pw(50), ph(30)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
        commands = [
          [VECTOR_LINE, 0, 0, -100, 100],
          [VECTOR_LINE, 0, 0, 100, 100]
        ]
      }
    ]
    : null
  }
}

let function generatePitchLine(num) {
  return {
    size = [pw(100), ph(100)]
    flow = FLOW_VERTICAL
    children = num >= 0 ? [
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.value
        color = IlsColor.value
        padding = [10, 0]
        commands = [
          [VECTOR_LINE, 0, 0, 34, 0],
          [VECTOR_LINE, 66, 0, 100, 0]
        ]
        children = num != 0 ? [
          {
            rendObj = ROBJ_TEXT
            size = SIZE_TO_CONTENT
            color = IlsColor.value
            fontSize = 40
            font = Fonts.f14_ils
            text = num.tostring()
          }
        ] : null
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
          [VECTOR_LINE, 0, 0, 7, 0],
          [VECTOR_LINE, 15, 0, 21, 0],
          [VECTOR_LINE, 28, 0, 34, 0],
          [VECTOR_LINE, 100, 0, 93, 0],
          [VECTOR_LINE, 85, 0, 79, 0],
          [VECTOR_LINE, 72, 0, 66, 0]
        ]
        children = [
          {
            rendObj = ROBJ_TEXT
            size = SIZE_TO_CONTENT
            color = IlsColor.value
            fontSize = 40
            font = Fonts.f14_ils
            text = num.tostring()
          }
        ]
      }
    ]
  }
}

let function pitchAir(width, height) {
  const step = 30.0
  let children = []

  for (local i = 90.0 / step; i >= -90.0 / step; --i) {
    let num = (i * step).tointeger()

    children.append(generatePitchLine(num))
  }

  return {
    size = [width * 0.5, height * 0.5]
    pos = [width * 0.25, height * 0.7]
    flow = FLOW_VERTICAL
    children = children
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, -height * (90.0 - Tangage.value) / 60]
        rotate = -Roll.value
        pivot = [0.5, (90.0 - Tangage.value) / 30]
      }
    }
  }
}

let function pitchGround(width, height) {
  const step = 5.0
  let children = []

  for (local i = 90.0 / step; i >= -90.0 / step; --i) {
    let num = (i * step).tointeger()

    children.append(generatePitchLine(num))
  }

  return {
    size = [width * 0.5, height * 0.5]
    pos = [width * 0.25, height * 0.7]
    flow = FLOW_VERTICAL
    children = children
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, -height * (90.0 - Tangage.value) * 0.1]
        rotate = -Roll.value
        pivot = [0.5, (90.0 - Tangage.value) * 0.2]
      }
    }
  }
}

let function ccip(width, height) {
  return @() {
    watch = [ShellMode, CannonMode]
    size = flex()
    children = ShellMode.value || CannonMode.value ?
      [
       pitchGround(width, height),
       altmetr
      ] :
      [
        pitchAir(width, height),
        targetDist,
        closureRate,
      ]
  }
}

let function ccrp(width, height) {
  return @() {
    watch = BombingMode
    size = flex()
    children = BombingMode.value ?
    [
      flyDirection(width, height, false),
      targetMark(TargetPosValid, false),
      AVQ7CCRP(width, height)
    ] : [aimMark]
  }
}

let function ilsF14(width, height) {
  return {
    size = [width, height]
    children = [
      adlMarker,
      ccip(width, height),
      planeMarker,
      targetMark(RadarTargetPosValid, true),
      shellName,
      shellCount,
      compass(width, height),
      ccrp(width, height)
    ]
  }
}

return ilsF14