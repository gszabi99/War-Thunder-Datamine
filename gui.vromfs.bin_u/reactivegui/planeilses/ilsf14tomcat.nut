from "%rGui/globals/ui_library.nut" import *
from "%globalScripts/loc_helpers.nut" import loc_checked

let { abs } = require("%sqstd/math.nut")
let { IlsColor, IlsLineScale, RadarTargetPosValid, RadarTargetPos, RadarTargetDist,
  BombingMode, BombCCIPMode, RocketMode, CannonMode,
  TargetPosValid, TargetPos } = require("%rGui/planeState/planeToolsState.nut")
let { baseLineWidth, metrToNavMile } = require("%rGui/planeIlses/ilsConstants.nut")
let { GuidanceLockResult } = require("guidanceConstants")
let { AdlPoint, CurWeaponName, ShellCnt } = require("%rGui/planeState/planeWeaponState.nut")
let { Roll, Tangage, Altitude } = require("%rGui/planeState/planeFlyState.nut")
let { GuidanceLockState, IlsTrackerX, IlsTrackerY } = require("%rGui/rocketAamAimState.nut")
let { compassWrap, generateCompassMarkF14 } = require("%rGui/planeIlses/ilsCompasses.nut")
let { flyDirection } = require("%rGui/planeIlses/commonElements.nut")
let { AVQ7CCRP } = require("%rGui/planeIlses/ilsAVQ7.nut")

let adlMarker = @() {
  watch = IlsColor
  rendObj = ROBJ_VECTOR_CANVAS
  size = const [pw(3), ph(3)]
  color = IlsColor.get()
  lineWidth = baseLineWidth * IlsLineScale.get()
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
  size = const [pw(10), ph(3)]
  pos = [pw(50), ph(70)]
  color = IlsColor.get()
  lineWidth = baseLineWidth * IlsLineScale.get()
  commands = [
    [VECTOR_LINE, 0, 0, 0, 0],
    [VECTOR_LINE, 40, 0, 100, 0],
    [VECTOR_LINE, -100, 0, -40, 0],
    [VECTOR_LINE, 40, 0, 40, 100],
    [VECTOR_LINE, -40, 0, -40, 100]
  ]
}

function targetMark(width, height, watchVar, is_radar) {
  return @() {
    watch = [IlsColor, watchVar]
    rendObj = ROBJ_VECTOR_CANVAS
    size = const [pw(3), ph(3)]
    color = IlsColor.get()
    lineWidth = baseLineWidth * IlsLineScale.get()
    commands = watchVar.get() ? [
      [VECTOR_LINE, -100, 0, 0, -100],
      [VECTOR_LINE, 0, -100, 100, 0],
      [VECTOR_LINE, 100, 0, 0, 100],
      [VECTOR_LINE, 0, 100, -100, 0]
    ] : null
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
          translate = watchVar.get() ? (is_radar ? RadarTargetPosLim : TargetPos.get()) : [0, 0]
        }
      }
    }
  }
}

let dist = Computed(@() RadarTargetDist.get() * metrToNavMile)
let maxDist = Computed(@() dist.get() < 1.0 ? 1.0 : (dist.get() < 5.0 ? 5.0 : 10.0))
let distPos = Computed(@() (100 - min(dist.get() / maxDist.get() * 100.0, 100)).tointeger())
let targetDist = @() {
  watch = [IlsColor, RadarTargetPosValid, maxDist]
  rendObj = ROBJ_VECTOR_CANVAS
  size = const [pw(20), ph(60)]
  pos = [pw(80), ph(20)]
  color = IlsColor.get()
  lineWidth = 2 * baseLineWidth * IlsLineScale.get()
  commands = RadarTargetPosValid.get() ? ([
    [VECTOR_LINE, 0, 0, 0, 0],
    [VECTOR_LINE, 0, 20, 0, 20],
    [VECTOR_LINE, 0, 40, 0, 40],
    [VECTOR_LINE, 0, 60, 0, 60],
    [VECTOR_LINE, 0, 80, 0, 80]
  ]) : null
  children = RadarTargetPosValid.get() ? [
    @() {
      watch = [IlsColor, maxDist]
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      pos = [pw(20), ph(-4)]
      color = IlsColor.get()
      fontSize = 60
      font = Fonts.f14_ils
      text = maxDist.get().tostring()
    },
    @() {
      watch = [IlsColor, distPos]
      size = const [pw(20), ph(100)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      lineWidth = baseLineWidth * IlsLineScale.get()
      commands = [
        [VECTOR_LINE, -30, distPos.get(), -100, distPos.get() - 3],
        [VECTOR_LINE, -30, distPos.get(), -100, distPos.get() + 3]
      ]
    }
  ] : null
}

let altPos = Computed(@() (100 - min(Altitude.get() / 48.768,  100)).tointeger())
let altmetr = @() {
  watch = IlsColor
  rendObj = ROBJ_VECTOR_CANVAS
  size = const [pw(20), ph(50)]
  pos = [pw(82), ph(40)]
  color = IlsColor.get()
  lineWidth = 2 * baseLineWidth * IlsLineScale.get()
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
      color = IlsColor.get()
      fontSize = 60
      font = Fonts.f14_ils
      text = "10"
    },
    {
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      pos = [pw(10), ph(96)]
      color = IlsColor.get()
      fontSize = 60
      font = Fonts.f14_ils
      text = "0"
    },
    @() {
      watch = [IlsColor, altPos]
      size = const [pw(20), ph(100)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      lineWidth = baseLineWidth * IlsLineScale.get()
      commands = [
        [VECTOR_LINE, -30, altPos.get(), -100, altPos.get() - 3],
        [VECTOR_LINE, -30, altPos.get(), -100, altPos.get() + 3]
      ]
    }
  ]
}

let closureRate = @() {
  watch = [IlsColor, RadarTargetPosValid]
  rendObj = ROBJ_VECTOR_CANVAS
  size = const [pw(20), ph(40)]
  pos = [pw(20), ph(20)]
  color = IlsColor.get()
  lineWidth = 2 * baseLineWidth * IlsLineScale.get()
  commands = RadarTargetPosValid.get() ? ([
    [VECTOR_LINE, 0, 0, 0, 0],
    [VECTOR_LINE, 0, 16.6, 0, 16.6],
    [VECTOR_LINE, 0, 33.3, 0, 33.3],
    [VECTOR_LINE, 0, 50, 0, 50],
    [VECTOR_LINE, 0, 66.6, 0, 66.6],
    [VECTOR_LINE, 0, 83.3, 0, 83.3],
    [VECTOR_LINE, 0, 100, 0, 100]
  ]) : null
  children = RadarTargetPosValid.get() ? [
    {
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      pos = [pw(-40), ph(-5)]
      color = IlsColor.get()
      fontSize = 60
      font = Fonts.f14_ils
      text = "10"
    },
    {
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      pos = [pw(-25), ph(78)]
      color = IlsColor.get()
      fontSize = 60
      font = Fonts.f14_ils
      text = "0"
    },
    {
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      pos = [pw(-40), ph(95)]
      color = IlsColor.get()
      fontSize = 60
      font = Fonts.f14_ils
      text = "-2"
    }
  ] : null
}

let ShellMode = Computed(@() RocketMode.get() || BombCCIPMode.get() || BombingMode.get())
let isAAMMode = Computed(@() GuidanceLockState.get() > GuidanceLockResult.RESULT_STANDBY)
let shellName = @() {
  watch = [IlsColor, CurWeaponName, ShellMode, isAAMMode]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [ShellMode.get() ? pw(43.5) : (isAAMMode.get() ? pw(46) : pw(48)), ph(80)]
  color = IlsColor.get()
  fontSize = 80
  font = Fonts.f14_ils
  text = ShellMode.get() ? "ORD" : (isAAMMode.get() && !CannonMode.get() ? loc_checked(CurWeaponName.get()) :  "G")
}

let shellValue = Computed(@() !isAAMMode.get() ? ShellCnt.get() / 100 : ShellCnt.get())
let shellCount = @() {
  watch = [IlsColor, shellValue]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(48), ph(88)]
  color = IlsColor.get()
  fontSize = 80
  font = Fonts.f14_ils
  text = ShellMode.get() ? "" : shellValue.get().tointeger()
}

let aimMark = @() {
  watch = [IlsColor, TargetPosValid]
  size = const [pw(10), ph(10)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.get()
  lineWidth = baseLineWidth * IlsLineScale.get()
  commands = [
    [VECTOR_LINE, 0, 0, 0, 0],
    [VECTOR_LINE, -100, 0, -40, 0],
    [VECTOR_LINE, 100, 0, 40, 0],
    [VECTOR_LINE, 0, -100, 0, -40],
    [VECTOR_LINE, 0, 100, 0, 40],
    (!TargetPosValid.get() ? [VECTOR_LINE, -40, 0, 0, -40] : []),
    (!TargetPosValid.get() ? [VECTOR_LINE, 40, 0, 0, 40] : []),
    (!TargetPosValid.get() ? [VECTOR_LINE, 0, -40, 40, 0] : []),
    (!TargetPosValid.get() ? [VECTOR_LINE, 0, 40, -40, 0] : [])
  ]
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      translate = isAAMMode.get() ? [IlsTrackerX.get(), IlsTrackerY.get()] : TargetPos.get()
    }
  }
}

let compass = function(width, height) {
  return @() {
    watch = [ShellMode, CannonMode]
    size = flex()
    children = ShellMode.get() || CannonMode.get() ?
    [
      compassWrap(width, height, 0.2, generateCompassMarkF14, 1.2),
      @() {
        watch = IlsColor
        size = const [pw(2), ph(4)]
        pos = [pw(50), ph(30)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.get()
        lineWidth = baseLineWidth * IlsLineScale.get()
        commands = [
          [VECTOR_LINE, 0, 0, -100, 100],
          [VECTOR_LINE, 0, 0, 100, 100]
        ]
      }
    ]
    : null
  }
}

function generatePitchLine(num) {
  return {
    size = const [pw(100), ph(100)]
    flow = FLOW_VERTICAL
    children = num >= 0 ? [
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.get()
        color = IlsColor.get()
        padding = const [10, 0]
        commands = [
          [VECTOR_LINE, 0, 0, 34, 0],
          [VECTOR_LINE, 66, 0, 100, 0]
        ]
        children = num != 0 ? [
          {
            rendObj = ROBJ_TEXT
            size = SIZE_TO_CONTENT
            color = IlsColor.get()
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
        lineWidth = baseLineWidth * IlsLineScale.get()
        color = IlsColor.get()
        padding = const [10, 0]
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
            color = IlsColor.get()
            fontSize = 40
            font = Fonts.f14_ils
            text = num.tostring()
          }
        ]
      }
    ]
  }
}

function pitchAir(width, height) {
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
        translate = [0, -height * (90.0 - Tangage.get()) / 60]
        rotate = -Roll.get()
        pivot = [0.5, (90.0 - Tangage.get()) / 30]
      }
    }
  }
}

function pitchGround(width, height) {
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
        translate = [0, -height * (90.0 - Tangage.get()) * 0.1]
        rotate = -Roll.get()
        pivot = [0.5, (90.0 - Tangage.get()) * 0.2]
      }
    }
  }
}

function ccip(width, height) {
  return @() {
    watch = [ShellMode, CannonMode]
    size = flex()
    children = ShellMode.get() || CannonMode.get() ?
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

function ccrp(width, height) {
  return @() {
    watch = BombingMode
    size = flex()
    children = BombingMode.get() ?
    [
      flyDirection(width, height, false),
      targetMark(width, height, TargetPosValid, false),
      AVQ7CCRP(width, height)
    ] : [aimMark]
  }
}

function ilsF14(width, height) {
  return {
    size = [width, height]
    children = [
      adlMarker,
      ccip(width, height),
      planeMarker,
      targetMark(width, height, RadarTargetPosValid, true),
      shellName,
      shellCount,
      compass(width, height),
      ccrp(width, height)
    ]
  }
}

return ilsF14