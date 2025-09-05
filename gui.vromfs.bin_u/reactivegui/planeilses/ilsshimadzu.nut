from "%rGui/globals/ui_library.nut" import *

let string = require("string")
let { Speed, Roll, Mach, Overload, Aos } = require("%rGui/planeState/planeFlyState.nut");
let { IlsColor,  BombingMode, TargetPosValid, TargetPos, BombCCIPMode,
        IlsLineScale, RocketMode, CannonMode } = require("%rGui/planeState/planeToolsState.nut")
let { baseLineWidth, mpsToKnots } = require("%rGui/planeIlses/ilsConstants.nut")
let { compassWrap, generateCompassMarkShim } = require("%rGui/planeIlses/ilsCompasses.nut")
let { flyDirection, angleTxt, cancelBombing, lowerSolutionCue,
      bombFallingLine, shimadzuRoll, ShimadzuPitch, ShimadzuAlt } = require("%rGui/planeIlses/commonElements.nut")
let { floor } = require("%sqstd/math.nut")

let CCIPMode = Computed(@() RocketMode.get() || CannonMode.get() || BombCCIPMode.get())

let generateSpdMarkShimadzu = function(num) {
  let ofs = num == 0 ? pw(-20) : (num < 100 ? pw(-30) : pw(-40))
  return {
    size = static [pw(100), ph(7.5)]
    pos = [pw(40), 0]
    children = [
      (num % 50 > 0 ? null :
        @() {
          watch = IlsColor
          size = flex()
          pos = [ofs, 0]
          rendObj = ROBJ_TEXT
          color = IlsColor.get()
          vplace = ALIGN_CENTER
          fontSize = 40
          font = Fonts.hud
          text = num.tostring()
        }
      ),
      @() {
        watch = IlsColor
        pos = [0, ph(25)]
        size = [baseLineWidth * 5, baseLineWidth * IlsLineScale.get()]
        rendObj = ROBJ_SOLID
        color = IlsColor.get()
        lineWidth = baseLineWidth * IlsLineScale.get()
      }
    ]
  }
}

function ShimadzuSpeed(height, generateFunc) {
  let children = []

  for (local i = 0; i <= 1000; i += 10) {
    children.append(generateFunc(i))
  }

  let getOffset = @() (Speed.get() * mpsToKnots * 0.0075 - 0.5) * height
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

function ShimadzuSpeedWrap(width, height, generateFunc) {
  return {
    size = [width * 0.17, height * 0.5]
    pos = [width * 0.1, height * 0.2]
    clipChildren = true
    children = [
      ShimadzuSpeed(height * 0.5, generateFunc),
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.get()
        color = IlsColor.get()
        commands = [
          [VECTOR_LINE, 80, 45, 68, 50],
          [VECTOR_LINE, 80, 55, 68, 50]
        ]
      }
    ]
  }
}

let generateAltMarkShimadzu = function(num) {
  return {
    size = static [pw(100), ph(7.5)]
    pos = [pw(15), 0]
    flow = FLOW_HORIZONTAL
    children = [
      @() {
        watch = IlsColor
        size = [baseLineWidth * 5, baseLineWidth * IlsLineScale.get()]
        rendObj = ROBJ_SOLID
        color = IlsColor.get()
        lineWidth = baseLineWidth * IlsLineScale.get()
        vplace = ALIGN_CENTER
      },
      (num % 50 > 0 ? null :
        @() {
          watch = IlsColor
          size = flex()
          rendObj = ROBJ_TEXT
          color = IlsColor.get()
          vplace = ALIGN_CENTER
          fontSize = 40
          font = Fonts.hud
          text = string.format("%.1f", num / 100.0)
        }
      )
    ]
  }
}

function ShimadzuAltWrap(width, height, generateFunc) {
  return {
    size = [width * 0.17, height * 0.5]
    pos = [width * 0.75, height * 0.2]
    clipChildren = true
    children = [
      ShimadzuAlt(height * 0.5, generateFunc),
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
  }
}

let MachWatch = Computed(@() (floor(Mach.get() * 100)).tointeger())
let ShimadzuMach = @() {
  watch = [MachWatch, IlsColor]
  size = flex()
  pos = [pw(12), ph(72)]
  rendObj = ROBJ_TEXT
  color = IlsColor.get()
  fontSize = 50
  text = string.format(MachWatch.get() < 100 ? ".%02d" : "%.2f", MachWatch.get() < 100 ? MachWatch.get() : MachWatch.get() / 100.0)
}

let OverloadWatch = Computed(@() (floor(Overload.get() * 10)).tointeger())
let ShimadzuOverload = @() {
  watch = [OverloadWatch, IlsColor]
  size = flex()
  pos = [pw(12), ph(77)]
  rendObj = ROBJ_TEXT
  color = IlsColor.get()
  fontSize = 50
  text = string.format("%.1fG", OverloadWatch.get() / 10.0)
}

function generatePitchLineShim(num) {
  let sign = num > 0 ? 1 : -1
  let newNum = num >= 0 ? num : (num - 5)
  return {
    size = static [pw(100), ph(50)]
    flow = FLOW_VERTICAL
    children = num == 0 ? [
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.get()
        color = IlsColor.get()
        padding = static [0, 10]
        commands = [
          [VECTOR_LINE, 0, 0, 34, 0],
          [VECTOR_LINE, 66, 0, 100, 0]
        ]
        children = [angleTxt(-5, true, Fonts.hud), angleTxt(-5, false, Fonts.hud)]
      }
    ] :
    [
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.get()
        color = IlsColor.get()
        padding = 10
        commands = [
          [VECTOR_LINE, 0, 5 * sign, 0, 0],
          [VECTOR_LINE, 0, 0, num > 0 ? 34 : 7, 0],
          (num < 0 ? [VECTOR_LINE, 15, 0, 21, 0] : []),
          (num < 0 ? [VECTOR_LINE, 28, 0, 34, 0] : []),
          [VECTOR_LINE, 100, 5 * sign, 100, 0],
          [VECTOR_LINE, 100, 0, num > 0 ? 66 : 93, 0],
          (num < 0 ? [VECTOR_LINE, 85, 0, 79, 0] : []),
          (num < 0 ? [VECTOR_LINE, 72, 0, 66, 0] : [])
        ]
        children = newNum <= 90 ? [angleTxt(newNum, true, Fonts.hud), angleTxt(newNum, false, Fonts.hud)] : null
      }
    ]
  }
}

function f16CcipMark(width, height) {
  return @() {
    watch = [IlsColor, TargetPosValid]
    size = static [pw(3), ph(3)]
    color = IlsColor.get()
    lineWidth = baseLineWidth * IlsLineScale.get()
    rendObj = ROBJ_VECTOR_CANVAS
    fillColor = Color(0, 0, 0, 0)
    commands = [
      [VECTOR_ELLIPSE, 0, 0, 100, 100],
      (TargetPosValid.get() ? [VECTOR_LINE, -100, -100, 100, -100] : []),
      [VECTOR_WIDTH, baseLineWidth * 2 * IlsLineScale.get()],
      [VECTOR_ELLIPSE, 0, 0, 0, 0],
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = TargetPosValid.get() ? TargetPos.get() : [width * 0.5, height * 0.6]
      }
    }
  }
}

function f16CcrpMark(_width, height) {
  return {
    size = flex()
    children = [
      {
        size = flex()
        children = [
          lowerSolutionCue(height, -5),
          bombFallingLine()
        ]
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            translate = [TargetPos.get()[0], height * 0.1]
            rotate = -Roll.get()
            pivot = [0.1, TargetPos.get()[1] / height - 0.1]
          }
        }
      },
      @() {
        watch = IlsColor
        size = static [pw(3), ph(3)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.get()
        lineWidth = baseLineWidth * IlsLineScale.get()
        commands = [
          [VECTOR_LINE, -100, -100, 100, -100],
          [VECTOR_LINE, -100, -100, -100, 100],
          [VECTOR_LINE, -100, 100, 100, 100],
          [VECTOR_LINE, 100, -100, 100, 100],
          [VECTOR_WIDTH, baseLineWidth * IlsLineScale.get() * 2],
          [VECTOR_LINE, 0, 0, 0, 0]
        ]
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            translate = TargetPos.get()
          }
        }
      },
      cancelBombing(50, 40)
    ]
  }
}

let ShimadzuMode = @() {
  watch = [CCIPMode, BombingMode, IlsColor]
  size = flex()
  pos = [pw(78), ph(77)]
  rendObj = ROBJ_TEXT
  color = IlsColor.get()
  fontSize = 50
  font = Fonts.hud
  text = CCIPMode.get() ? "CCIP" : (BombingMode.get() ? "CCRP" : "NAV")
}

function ShimadzuIls(width, height) {
  return {
    size = [width, height]
    children = [
      flyDirection(width, height, true),
      shimadzuRoll(15),
      ShimadzuSpeedWrap(width, height, generateSpdMarkShimadzu),
      ShimadzuMach,
      ShimadzuAltWrap(width, height, generateAltMarkShimadzu),
      ShimadzuPitch(width, height, generatePitchLineShim),
      ShimadzuOverload,
      ShimadzuMode,
      compassWrap(width, height, 0.85, generateCompassMarkShim, 1.0, 2.0),
      @() {
        watch = IlsColor
        size = static [pw(2), ph(3)]
        pos = [pw(50), ph(92)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.get()
        lineWidth = baseLineWidth * IlsLineScale.get()
        commands = [
          [VECTOR_LINE, 0, 0, -100, 100],
          [VECTOR_LINE, 0, 0, 100, 100]
        ]
      },
      @() {
        watch = IlsColor
        size = static [pw(2), ph(10)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.get()
        lineWidth = baseLineWidth * IlsLineScale.get()
        commands = [[VECTOR_LINE, 0, 0, 0, 100]]
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            translate = [Aos.get() * width * 0.02 + 0.5 * width, 0.4 * height]
          }
        }
      },
      @() {
        watch = CCIPMode
        size = flex()
        children = [
          (CCIPMode.get() ? f16CcipMark(width, height) : null),
          (CCIPMode.get() ? cancelBombing(50, 40) : null)
        ]
      },
      @() {
        watch = BombingMode
        size = flex()
        children = [BombingMode.get() ? f16CcrpMark(width, height) : null]
      }
    ]
  }
}

return ShimadzuIls