let {IlsColor, IlsLineScale, BombingMode, BombCCIPMode, DistToSafety,
      TimeBeforeBombRelease, AimLocked, TargetPos, TargetPosValid,
      RocketMode, CannonMode} = require("%rGui/planeState/planeToolsState.nut")
let {baseLineWidth} = require("ilsConstants.nut")
let {Aos, Tangage, Roll, BarAltitude} = require("%rGui/planeState/planeFlyState.nut")

let function flyDirection(width, height, isLockedFlyPath = false) {
  return @() {
    watch = IlsColor
    size = [width * 0.1, height * 0.1]
    pos = [width * 0.5, height * (BombCCIPMode.value || BombingMode.value || isLockedFlyPath ? 0.5 : 0.3)]
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.value
    fillColor = Color(0, 0, 0, 0)
    lineWidth = baseLineWidth * IlsLineScale.value
    commands = [
      [VECTOR_ELLIPSE, 0, 0, 20, 20],
      [VECTOR_LINE, -50, 0, -20, 0],
      [VECTOR_LINE, 20, 0, 50, 0],
      [VECTOR_LINE, 0, -20, 0, -40]
    ]
  }
}

let function angleTxt(num, isLeft, textFont, invVPlace = 1, font_size = 60, x = 0, y = 0) {
  return @() {
    watch = IlsColor
    pos = [x, y]
    rendObj = ROBJ_TEXT
    vplace = (num * invVPlace) < 0 ? ALIGN_BOTTOM : ALIGN_TOP
    hplace = isLeft ? ALIGN_LEFT : ALIGN_RIGHT
    color = IlsColor.value
    fontSize = font_size
    font = textFont
    text = num.tostring()
  }
}

let aosOffset = Computed(@() Aos.value.tointeger())
let yawIndicator = @() {
  size = [pw(3), ph(3)]
  pos = [pw(50), ph(80)]
  watch = [IlsColor, aosOffset]
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = baseLineWidth * IlsLineScale.value
  color = IlsColor.value
  fillColor = Color(0, 0, 0, 0)
  commands = [
    [VECTOR_ELLIPSE, aosOffset.value * 10, 0, 50, 50],
    [VECTOR_LINE, 0, -100, 0, 100],
  ]
}

let cancelBombVisible = Computed(@() DistToSafety.value <= 0.0)
let function cancelBombing(posY, size) {
  return @() {
    watch = cancelBombVisible
    size = flex()
    children = cancelBombVisible.value ?
      @() {
        watch = IlsColor
        size = [pw(size), ph(size)]
        pos = [pw(50), ph(posY)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
        commands = [
          [VECTOR_LINE, -50, -50, 50, 50],
          [VECTOR_LINE, -50, 50, 50, -50]
        ]
        animations = [
          { prop = AnimProp.opacity, from = -1, to = 1, duration = 0.5, play = true, loop = true }
        ]
      }
    : null
  }
}


let function bombFallingLine() {
  return @() {
    watch = IlsColor
    size = [baseLineWidth * IlsLineScale.value, ph(65)]
    rendObj = ROBJ_SOLID
    color = IlsColor.value
    lineWidth = baseLineWidth * IlsLineScale.value
  }
}

let lowerCuePos = Computed(@() clamp(0.4 - TimeBeforeBombRelease.value * 0.05, 0.1, 0.5))
let lowerCueShow = Computed(@() AimLocked.value && TimeBeforeBombRelease.value > 0.0)
let function lowerSolutionCue(height, posX) {
  return @() {
    watch = lowerCueShow
    size = flex()
    children = lowerCueShow.value ?
      @() {
        watch = [IlsColor, lowerCuePos]
        size = [pw(10), baseLineWidth * IlsLineScale.value]
        pos = [pw(posX), lowerCuePos.value * height - baseLineWidth * 0.5 * IlsLineScale.value]
        rendObj = ROBJ_SOLID
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
      }
    : null
  }
}

let shimadzuRoll = @(width) {
  size = [pw(15), ph(5)]
  pos = [pw(42.5), ph(width)]
  children =
  {
    size = flex()
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.value
    lineWidth = baseLineWidth * IlsLineScale.value
    commands = [
      [VECTOR_LINE, 0, 0, 10, 0],
      [VECTOR_LINE, 10, 0, 30, 100],
      [VECTOR_LINE, 30, 100, 50, 0],
      [VECTOR_LINE, 50, 0, 70, 100],
      [VECTOR_LINE, 70, 100, 90, 0],
      [VECTOR_LINE, 90, 0, 100, 0]
    ]
  }
  behavior = Behaviors.RtPropUpdate
  update = @() {
      transform = {
        rotate = -Roll.value
      }
    }
}

let function ShimadzuPitch(width, height, generateFunc) {
  const step = 5.0
  let children = []

  for (local i = 90.0 / step; i >= -90.0 / step; --i) {
    let num = (i * step).tointeger()

    children.append(generateFunc(num))
  }

  return {
    size = [width * 0.5, height * 0.7]
    pos = [width * 0.25, height * 0.5]
    flow = FLOW_VERTICAL
    children = children
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, -height * (90.0 - Tangage.value) * 0.07]
      }
    }
  }
}

let function ShimadzuAlt(height, generateFunc) {
  let children = []

  for (local i = 2000; i >= 0; i -= 10) {
    children.append(generateFunc(i))
  }

  let getOffset = @() ((20000 - BarAltitude.value) * 0.0007425 - 0.4625) * height
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

let CCIPMode = Computed(@() RocketMode.value || CannonMode.value || BombCCIPMode.value)
let aimMark = @() {
  watch = [TargetPosValid, CCIPMode]
  size = flex()
  children = TargetPosValid.value ?
    @() {
      watch = IlsColor
      size = [pw(5), ph(5)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.value
      lineWidth = baseLineWidth * IlsLineScale.value
      commands = [
        [VECTOR_LINE, 0, 0, 0, 0],
        [VECTOR_LINE, 0, 50, 50, 0],
        [VECTOR_LINE, 50, 0, 0, -50],
        [VECTOR_LINE, 0, -50, -50, 0],
        [VECTOR_LINE, -50, 0, 0, 50],
        (CCIPMode.value ? [VECTOR_LINE, -50, -50, 50, -50] : [])
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = [TargetPos.value[0], TargetPos.value[1]]
        }
      }
    }
  : null
}

return {
  flyDirection
  angleTxt,
  yawIndicator,
  cancelBombing,
  bombFallingLine,
  lowerSolutionCue,
  shimadzuRoll,
  ShimadzuPitch,
  ShimadzuAlt,
  aimMark
}