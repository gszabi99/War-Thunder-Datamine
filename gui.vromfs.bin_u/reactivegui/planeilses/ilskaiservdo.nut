from "%rGui/globals/ui_library.nut" import *
let { IlsColor, IlsLineScale, TvvMark, RocketMode, BombCCIPMode,
 DistToTarget, TargetPos, TargetPosValid, BombingMode } = require("%rGui/planeState/planeToolsState.nut")
let { baseLineWidth, metrToFeet, mpsToKnots, metrToNavMile } = require("%rGui/planeIlses/ilsConstants.nut")
let { Tangage, BarAltitude, Altitude, Speed, Roll, ClimbSpeed,
 Aoa, VertOverload } = require("%rGui/planeState/planeFlyState.nut");
let string = require("string")
let { round, cos, sin, PI, floor } = require("%sqstd/math.nut")
let { cvt } = require("dagor.math")
let { compassWrap } = require("%rGui/planeIlses/ilsCompasses.nut")

function angleTxt(num, isLeft, invVPlace = 1, x = 0) {
  return @() {
    watch = IlsColor
    pos = [x, num > 0 ? 10 : 0]
    rendObj = ROBJ_TEXT
    vplace = (num * invVPlace) < 0 ? ALIGN_BOTTOM : ALIGN_TOP
    hplace = isLeft ? ALIGN_LEFT : ALIGN_RIGHT
    color = IlsColor.get()
    fontSize = 45
    font = Fonts.hud
    text = num.tostring()
  }
}

function generatePitchLine(num) {
  let sign = num > 0 ? 1 : -1
  let newNum = num >= 0 ? num : (num - 5)
  return {
    size = const [pw(80), ph(50)]
    pos = [pw(10), 0]
    flow = FLOW_VERTICAL
    children = num == 0 ? [
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.get()
        color = IlsColor.get()
        padding = const [0, 10]
        commands = [
          [VECTOR_LINE, -10, 0, 30, 0],
          [VECTOR_LINE, 70, 0, 110, 0]
        ]
        children = [angleTxt(-5, true, 1, pw(16)), angleTxt(-5, false, 1, pw(-18))]
      }
    ] :
    [
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.get()
        color = IlsColor.get()
        commands = [
          [VECTOR_LINE, 30, 5 * sign, 30, 0],
          [VECTOR_LINE, 0, 0, num < 0 ? 30 : 5, 0],
          (num > 0 ? [VECTOR_LINE, 10, 0, 17, 0] : []),
          (num > 0 ? [VECTOR_LINE, 23, 0, 30, 0] : []),
          [VECTOR_LINE, 70, 5 * sign, 70, 0],
          [VECTOR_LINE, 100, 0, num < 0 ? 70 : 95, 0],
          (num > 0 ? [VECTOR_LINE, 90, 0, 83, 0] : []),
          (num > 0 ? [VECTOR_LINE, 77, 0, 70, 0] : [])
        ]
        children = newNum <= 90 ? [angleTxt(newNum, true, 1, newNum == 5 ? pw(24) : pw(17)), angleTxt(newNum, false, 1, newNum == 5 ? pw(-24) : pw(-18))] : null
      }
    ]
  }
}

function pitch(width, height, generateFunc) {
  const step = 5.0
  let children = []

  for (local i = 90.0 / step; i >= -90.0 / step; --i) {
    let num = (i * step).tointeger()

    children.append(generateFunc(num))
  }

  return {
    size = [width * 0.6, height * 0.5]
    pos = [-width * 0.3, 0]
    flow = FLOW_VERTICAL
    children = children
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, -height * (90.0 - Tangage.get()) * 0.05]
        rotate = -Roll.get()
        pivot = [0.5, (90.0 - Tangage.get()) * 0.1]
      }
    }
  }
}

function KaiserTvvLinked(width, height) {
  return {
    size = flex()
    children = [
      @() {
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        size = const [pw(4), ph(4)]
        color = IlsColor.get()
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth * IlsLineScale.get()
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

let isRadioAlt = Computed(@() Altitude.get() * metrToFeet <= 4800.0)
let altValue = Computed(@() ((isRadioAlt.get() ? Altitude.get() : BarAltitude.get()) * metrToFeet).tointeger())
let altitude = @() {
  watch = [altValue, IlsColor]
  rendObj = ROBJ_TEXT
  pos = [pw(78), ph(30)]
  size = SIZE_TO_CONTENT
  color = IlsColor.get()
  fontSize = 40
  font = Fonts.hud
  text = altValue.get().tostring()
  children = isRadioAlt.get() ? {
    rendObj = ROBJ_TEXT
    pos = [0, ph(100)]
    size = flex()
    halign = ALIGN_CENTER
    color = IlsColor.get()
    fontSize = 40
    font = Fonts.hud
    text = "R"
  } : null
}

let speedValue = Computed(@() round(Speed.get() * mpsToKnots).tointeger())
let a10Speed = @() {
  watch = [speedValue, IlsColor]
  rendObj = ROBJ_TEXT
  pos = [pw(8), ph(30)]
  size = flex()
  color = IlsColor.get()
  fontSize = 40
  font = Fonts.hud
  text = string.format("GS %d", speedValue.get())
}

function climbSpeed(height){
  return @(){
    watch = IlsColor
    size = const [pw(4), ph(30)]
    pos = [pw(85), ph(40)]
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.get()
    lineWidth = baseLineWidth * IlsLineScale.get()
    commands = [
      [VECTOR_LINE, 0, 0, 50, 0],
      [VECTOR_LINE, 0, 33.3, 100, 33.3],
      [VECTOR_LINE, 0, 66.67, 50, 66.67],
      [VECTOR_LINE, 0, 100, 50, 100],
      [VECTOR_WIDTH, baseLineWidth * IlsLineScale.get() * 2.0],
      [VECTOR_LINE, 40, 16.7, 40, 16.7],
      [VECTOR_LINE, 40, 50, 40, 50],
      [VECTOR_LINE, 40, 83.3, 40, 83.3]
    ]
    children = {
      rendObj = ROBJ_VECTOR_CANVAS
      size = const [pw(50), pw(25)]
      pos = [pw(100), 0]
      color = IlsColor.get()
      fillColor = IlsColor.get()
      lineWidth = 1
      commands = [
        [VECTOR_POLY, 0, 0, 100, -100, 100, 100]
      ]
      behavior = Behaviors.RtPropUpdate
      update = function() {
        let pos = cvt(ClimbSpeed.get(), 5.08, -10.16, 0.0, 0.3)
        return {
          transform = {
            translate = [0, pos * height]
          }
        }
      }
    }
  }
}

let generateCompassMarkSU145 = function(num, _elemWidth, font) {
  return {
    size = const [pw(12), ph(100)]
    flow = FLOW_VERTICAL
    children = [
      @() {
        watch = IlsColor
        rendObj = ROBJ_TEXT
        color = IlsColor.get()
        hplace = ALIGN_CENTER
        fontSize = 45
        font = font
        text = num % 10 == 0 ? string.format("%02d", num / 10) : ""
      },
      (num % 10 == 0 ? @() {
        watch = IlsColor
        size = [baseLineWidth * IlsLineScale.get(), baseLineWidth * 4]
        rendObj = ROBJ_SOLID
        color = IlsColor.get()
        lineWidth = baseLineWidth * IlsLineScale.get()
        hplace = ALIGN_CENTER
      } : @(){
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        size = [baseLineWidth * IlsLineScale.get(), baseLineWidth * 4]
        color = IlsColor.get()
        lineWidth = baseLineWidth * IlsLineScale.get() * 2.0
        hplace = ALIGN_CENTER
        commands = [
          [VECTOR_LINE, 0, 90, 0, 90]
        ]
      })
    ]
  }
}

let ccipDistF = Computed(@() cvt(clamp(DistToTarget.get() * metrToFeet * 0.01, 0, 120), 0, 120, -90, 270).tointeger())
let ccipDistM = Computed(@() (DistToTarget.get() < 0 || DistToTarget.get() >= 10000 ? -1 : DistToTarget.get() * metrToNavMile * 10.0).tointeger())
let gunAimMark = @() {
  watch = TargetPosValid
  size = flex()
  children = TargetPosValid.get() ?
    @() {
      watch = IlsColor
      size = const [pw(8), ph(8)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.get()
      commands = [
        [VECTOR_LINE, 0, 0, 0, 0],
        [VECTOR_ELLIPSE, 0, 0, 100, 100],
        [VECTOR_LINE, -120, 0, -100, 0],
        [VECTOR_LINE, 120, 0, 100, 0],
        [VECTOR_LINE, 0, -120, 0, -100],
        [VECTOR_LINE, 0, 120, 0, 100]
      ]
      transform = {
        translate = [TargetPos.get()[0], TargetPos.get()[1]]
      }
      children = [
        @() {
          watch = [ccipDistM, IlsColor]
          rendObj = ROBJ_TEXT
          color = IlsColor.get()
          pos = [pw(-50), ph(120)]
          font = Fonts.hud
          fontSize = 30
          hplace = ALIGN_CENTER
          text = ccipDistM.get() < 0 ? "" : string.format("%.1f", ccipDistM.get() * 0.1)
        }
        @(){
          watch = [ccipDistF, IlsColor]
          size = flex()
          rendObj = ROBJ_VECTOR_CANVAS
          color = IlsColor.get()
          fillColor = Color(0, 0, 0, 0)
          lineWidth = baseLineWidth * IlsLineScale.get()
          commands = [
            (DistToTarget.get() < 10000 ? [VECTOR_SECTOR, 0, 0, 90, 90, -90, ccipDistF.get()] : []),
            (DistToTarget.get() < 10000 ?
              [VECTOR_LINE, 90 * cos(PI * ccipDistF.get() / 180), 90 * sin(PI * ccipDistF.get() / 180), 75 * cos(PI * ccipDistF.get() / 180), 75 * sin(PI * ccipDistF.get() / 180)] : [])
          ]
        }
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = [TargetPos.get()[0], TargetPos.get()[1]]
        }
      }
    }
  : null
}

function impactLine(_width, height) {
  return @() {
    watch = [TargetPosValid, BombCCIPMode, BombingMode, RocketMode, IlsColor]
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth * 0.8 * IlsLineScale.get()
    size = flex()
    color = IlsColor.get()
    commands = [
      (TargetPosValid.get() && (BombCCIPMode.get() || BombingMode.get() || RocketMode.get()) ? [VECTOR_LINE, 0, 0, 0, -100] : [])
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = TargetPosValid.get() ? [TargetPos.get()[0], clamp(TargetPos.get()[1], 0, height)] : [TargetPos.get()[0], height]
        rotate = -Roll.get()
        pivot = [0, 0]
      }
    }
  }
}

let aoaValue = Computed(@() (Aoa.get() * 10.0).tointeger())
let aoa = @() {
  watch = [aoaValue, IlsColor]
  rendObj = ROBJ_TEXT
  pos = [pw(10), ph(85)]
  size = flex()
  color = IlsColor.get()
  fontSize = 40
  font = Fonts.hud
  text = string.format("%.1f", aoaValue.get() * 0.1)
}

let OverloadWatch = Computed(@() (floor(VertOverload.get() * 10.0)).tointeger())
let overload = @() {
  watch = [OverloadWatch, IlsColor]
  size = flex()
  pos = [pw(10), ph(81)]
  rendObj = ROBJ_TEXT
  color = IlsColor.get()
  fontSize = 40
  font = Fonts.hud
  text = string.format("%.1f", OverloadWatch.get() * 0.1)
}

function KaiserVDO(width, height) {
  return {
    size = [width, height]
    children = [
      KaiserTvvLinked(width, height)
      altitude
      a10Speed
      climbSpeed(height)
      compassWrap(width, height, 0.18, generateCompassMarkSU145, 0.8, 5.0, false, 12)
      @(){
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        size = pw(1)
        pos = [pw(50), ph(26)]
        color = IlsColor.get()
        lineWidth = 1
        fillColor = IlsColor.get()
        commands = [
          [VECTOR_POLY, 0, 0, 100, 100, -100, 100]
        ]
      }
      gunAimMark
      impactLine(width, height)
      aoa
      overload
    ]
  }
}
return KaiserVDO