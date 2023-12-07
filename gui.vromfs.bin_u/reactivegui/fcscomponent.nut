from "%rGui/globals/ui_library.nut" import *

let cross_call = require("%rGui/globals/cross_call.nut")
let { PI, floor, cos, sin, fabs } = require("%sqstd/math.nut")
let { shuffle } = require("%sqStdLibs/helpers/u.nut")
let { greenColor } = require("style/airHudStyle.nut")
let { maxLabelHeight, maxMeasuresCompWidth } = require("radarComponent.nut")
let { isInitializedMeasureUnits, measureUnitsNames } = require("%rGui/options/optionsMeasureUnits.nut")
let { IsTargetSelected, aimAngle, TargetAzimuthAngle, HeroAzimuthAngle, HeadingAngle, TargetSpeed } = require("%rGui/fcsState.nut")
let { fcsShotState, showNewStateFromQueue, clearCurrentShotState } = require("%rGui/fcsStateQueue.nut")
let { sightAngle } = require("shipState.nut")

let backgroundColor = Color(0, 0, 0, 118)
let transparentColor = Color(0, 0, 0, 0)
let blackColor = Color(0, 0, 0, 255)
let whiteColor = Color(255, 255, 255, 255)
let redColor = Color(255, 0, 0, 255)

let bulletsOverPositions = [[0.3, 0.18], [0.5, 0.133], [0.7, 0.18]]
let bulletsShortPositions = [[0.3, 0.82], [0.5, 0.866], [0.7, 0.82]]
let bulletsHitPositions = [[0.3, 0.5], [0.5, 0.5], [0.7, 0.5]]
let imageSuffixes = ["", "over", "short", "stradle", "hit"]

let function mkTargetShipComponent(size) {
  let compSize = [0.486 * size[0], 0.486 * size[1]]
  let compCenter = [0.5 * size[0], 0.286 * size[1]]
  let pos = [compCenter[0] - compSize[0] / 2, compCenter[1] - compSize[1] / 2]
  let shipWidth = floor(0.192 * compSize[0])
  let shipHeight = floor(0.685 * compSize[1])

  return {
    size = compSize
    pos
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = [
      @(){
        rendObj = ROBJ_IMAGE
        watch = TargetAzimuthAngle
        size = [shipWidth, shipHeight]
        image = Picture($"!ui/gameuiskin#fcs_ship_enemy.svg:{shipWidth}:{shipHeight}")
        transform = {
          pivot = [0.5, 0.5]
          rotate = TargetAzimuthAngle.value
        }
      }
      @() {
        rendObj = ROBJ_VECTOR_CANVAS
        size = compSize
        watch = aimAngle
        color = greenColor
        fillColor = greenColor
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        commands = [[VECTOR_ELLIPSE, 50, 0, 2, 2]]
        transform = {
          rotate = aimAngle.value + 180
        }
      }
    ]
  }
}

let function mkHeroShipComponent(size) {
  let compSize = [0.313 * size[0], 0.313 * size[1]]
  let center = [0.5 * size[0], 0.79 * size[1]]
  let pos = [center[0] - compSize[0] / 2, center[1] - compSize[1] / 2]
  let shipWidth = floor(0.185 * compSize[0])
  let shipHeight = floor(0.66 * compSize[1])
  let coneSize = [size[0] * 0.5, size[1] * 0.5]

  return {
    size = compSize
    pos
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = [
      @() {
        rendObj = ROBJ_IMAGE
        watch = HeroAzimuthAngle
        size = [shipWidth, shipHeight]
        image = Picture($"!ui/gameuiskin#fcs_ship_player.svg:{shipWidth}:{shipHeight}")
        transform = {
          pivot = [0.5, 0.5]
          rotate = HeroAzimuthAngle.value
        }
      }
      @() {
        rendObj = ROBJ_IMAGE
        watch = sightAngle
        size = coneSize
        image = Picture("+ui/gameuiskin#map_camera")
        transform = {
          pivot = [0.5, 0.5]
          rotate = sightAngle.value
          scale = [sin(0.5), 1.0]
        }
      }
      @() {
        rendObj = ROBJ_VECTOR_CANVAS
        size = compSize
        watch = [aimAngle, IsTargetSelected]
        color = redColor
        fillColor = redColor
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        commands = IsTargetSelected.value ? [[VECTOR_ELLIPSE, 50, 7, 2, 2]] : null
        transform = {
          rotate = aimAngle.value
        }
      }
    ]
  }
}

let function mkBullet(bulletWidth, pos, delay, icon_type = "wrong") {
  return {
    rendObj = ROBJ_IMAGE
    size = [bulletWidth, bulletWidth]
    pos
    image = Picture($"!ui/gameuiskin#fcs_shot_{icon_type}.svg:{bulletWidth}:{bulletWidth}")
    key = {}
    opacity = 0
    animations = [
      {
        prop = AnimProp.opacity, from = 0, to = 1, play = true
        duration = 1, easing = @(x) fabs(sin(PI * x)), delay = delay
      }
    ]
  }
}

let function convertBulletPos(pos, size, bulletWidth) {
  return [pos[0] * size[0] - bulletWidth / 2, pos[1] * size[1] - bulletWidth / 2]
}

let function mkShotResultBullets(size, shotState) {
  let bulletWidth = floor(0.11 * size[0])

  if(shotState == FCSShotState.SHOT_OVER)
    return {
      size
      children = shuffle(bulletsOverPositions).map(@(pos, idx) mkBullet(bulletWidth, convertBulletPos(pos, size, bulletWidth), 0.5 + idx * 0.75))
    }

  if(shotState == FCSShotState.SHOT_SHORT)
    return {
      size
      children = shuffle(bulletsShortPositions).map(@(pos, idx) mkBullet(bulletWidth, convertBulletPos(pos, size, bulletWidth), 0.5 + idx * 0.75))
    }

  if(shotState == FCSShotState.SHOT_STRADLE)
    return {
      size
      children = shuffle([].extend(bulletsShortPositions, bulletsOverPositions)).map(@(pos, idx) mkBullet(bulletWidth, convertBulletPos(pos, size, bulletWidth), 0.5 + idx * 0.375))
    }

  return {
    size
    children = shuffle(bulletsHitPositions).map(@(pos, idx) mkBullet(bulletWidth, convertBulletPos(pos, size, bulletWidth), 0.5 + idx * 0.75, "right"))
  }
}

let function mkShotResultComponent(size) {
  let compSize = [floor(0.486 * size[0]), floor(0.486 * size[1])]
  let center = [0.5 * size[0], 0.286 * size[1]]
  let pos = [center[0] - compSize[0] / 2, center[1] - compSize[1] / 2]
  return function(){
    if(fcsShotState.value.shotState == FCSShotState.SHOT_NONE)
      return {
        watch = fcsShotState
      }
    let imageSuff = imageSuffixes[fcsShotState.value.shotState]
    return {
      watch = fcsShotState
      size = compSize
      pos
      children = {
        rendObj = ROBJ_IMAGE
        size = compSize
        image = Picture($"!ui/gameuiskin#fcs_shot_result_{imageSuff}.svg:{compSize[0]}:{compSize[1]}")
        opacity = 0
        key = {}
        animations = [
          {
            prop = AnimProp.opacity, from = 0, to = 1, play = true, duration = 0.5
          },
          {
            prop = AnimProp.opacity, from = 1, to = 1, play = true, delay = 0.5, duration = 2
          },
          {
            prop = AnimProp.opacity, from = 1, to = 0, play = true, delay = 2.5, duration = 0.5
          }
        ]
      }
    }
  }
}

let function mkShotResultBulletsComponent(size) {
  let compSize = [floor(0.486 * size[0]), floor(0.486 * size[1])]
  let center = [0.5 * size[0], 0.286 * size[1]]
  let pos = [center[0] - compSize[0] / 2, center[1] - compSize[1] / 2]
  return @(){
    watch = fcsShotState
    size = compSize
    pos
    children = fcsShotState.value.shotState != FCSShotState.SHOT_NONE
      ? mkShotResultBullets(compSize, fcsShotState.value.shotState)
      : null
  }
}

let function mkShotResultText(fcsShotStateValue) {
  if(fcsShotStateValue.shotState == FCSShotState.SHOT_NONE)
    return null

  local resultText = loc($"fcs/{imageSuffixes[fcsShotState.value.shotState]}")

  if(fcsShotStateValue.shotDiscrepancy != 0
    && [FCSShotState.SHOT_SHORT, FCSShotState.SHOT_OVER].contains(fcsShotStateValue.shotState)) {
      let sign = fcsShotStateValue.shotState == FCSShotState.SHOT_SHORT ? "-" : "+"
      let valueString = $"{sign}{cross_call.measureTypes.DISTANCE.getMeasureUnitsText(fcsShotStateValue.shotDiscrepancy)}"
      resultText = $"{resultText}: {valueString}"
  }
  return {
    rendObj = ROBJ_TEXT
    color = fcsShotStateValue.shotState == FCSShotState.SHOT_HIT ? blackColor : whiteColor
    font = Fonts.tiny_text_hud
    text = resultText
    opacity = 0
    key = {}
    animations = [
      {
        prop = AnimProp.opacity, from = 0, to = 1, play = true, duration = 0.5
      },
      {
        prop = AnimProp.opacity, from = 0, to = 1, play = true, delay = 0.5
        duration = 2, easing = @(x) 0.5* fabs(cos(2 * PI * x)) + 0.5
      },
      {
        prop = AnimProp.opacity, from = 1, to = 0, play = true, duration = 0.5, delay = 2.5
      }
    ]
  }
}

let shotResultFrame = {
  rendObj = ROBJ_FRAME
  size = flex()
  color = greenColor
  borderWidth = hdpx(1)
}

let function requestNewShotResult() {
  fcsShotState({shotState = FCSShotState.SHOT_NONE shotDiscrepancy = 0})
}

let function mkShotResultBack(fillColor) {
  return {
    rendObj = ROBJ_SOLID
    size = flex()
    color = fillColor
    opacity = 0
    key = {}
    animations = [
      {
        prop = AnimProp.opacity, from = 0, to = 1, play = true, duration = 0.5
      },
      {
        prop = AnimProp.opacity, from = 1, to = 1, play = true, delay = 0.5, duration = 2
      },
      {
        prop = AnimProp.opacity, from = 1, to = 0, play = true, delay = 2.5,
        duration = 0.5, onFinish = @() requestNewShotResult()
      }
    ]
  }
}

let function mkShotResultTextComponent(size) {
  return function() {
    let minCompWidth = 0.413 * size[0]
    let compHeight = 0.067 * size[1]
    let shotResultText = mkShotResultText(fcsShotState.value)
    let textSize = calc_comp_size(shotResultText)
    let compWidth = max(minCompWidth, textSize[0] + hdpx(10))
    let pos = [size[0] / 2 - compWidth / 2, 0.583 * size[1] - compHeight / 2]
    let fillColor = fcsShotState.value.shotState == FCSShotState.SHOT_NONE ? backgroundColor
      : fcsShotState.value.shotState == FCSShotState.SHOT_HIT ? greenColor
      : redColor
    return {
      watch = fcsShotState
      size = [compWidth, compHeight]
      pos
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      children = [
        fcsShotState.value.shotState != FCSShotState.SHOT_NONE ? mkShotResultBack(fillColor) : null
        fcsShotState.value.shotState != FCSShotState.SHOT_NONE ? shotResultText : null
        shotResultFrame
      ]
    }
  }
}

let mkNorthLable = @(ovr) {
  rendObj = ROBJ_TEXT
  color = greenColor
  text = "N"
}.__update(ovr)

let function mkHeroShipPlace(size) {
  let compSize = [0.313 * size[0], 0.313 * size[1]]
  let center = [0.5 * size[0], 0.79 * size[1]]
  let pos = [center[0] - compSize[0] / 2, center[1] - compSize[1] / 2]
  let commands = [
    [VECTOR_ELLIPSE, 50, 50, 50, 50],
    [VECTOR_ELLIPSE, 50, 50, 43, 43],
    [VECTOR_WIDTH, hdpx(2)]
  ]

  const angleGrad = 22.5
  let angle = PI * angleGrad / 180.0
  let dashCount = 360.0 / angleGrad
  for (local i = 0; i < dashCount; ++i) {
    commands.append([
      VECTOR_LINE,
      50 + cos(i * angle) * 43.0,
      50 + sin(i * angle) * 43.0,
      50 + cos(i * angle) * 50.0,
      50 + sin(i * angle) * 50.0
    ])
  }

  return {
    rendObj = ROBJ_VECTOR_CANVAS
    size = compSize
    pos
    lineWidth = hdpx(1)
    color = greenColor
    fillColor = transparentColor
    halign = ALIGN_CENTER
    commands
    children = mkNorthLable({pos = [0, hdpx(7)], font = Fonts.very_tiny_text_hud})
  }
}

let function mkTargetShipPlace(size) {
  let compSize = [0.486 * size[0], 0.486 * size[1]]
  let compCenter = [0.5 * size[0], 0.286 * size[1]]

  let pos = [compCenter[0] - compSize[0] / 2, compCenter[1] - compSize[1] / 2]
  let commands = [
    [VECTOR_ELLIPSE, 50, 50, 50, 50]
  ]

  const angleGrad = 6
  let angle = PI * angleGrad / 180.0
  let dashCount = 360.0 / angleGrad
  for (local i = 0; i < dashCount; ++i) {
    if(i % 5 == 0)
      commands.append(
        [VECTOR_WIDTH, hdpx(2)],
        [VECTOR_COLOR, greenColor],
        [VECTOR_LINE,
          50 + cos(i * angle) * 45,
          50 + sin(i * angle) * 45,
          50 + cos(i * angle) * 50.0,
          50 + sin(i * angle) * 50.0
        ])
    else
      commands.append(
        [VECTOR_WIDTH, hdpx(1)],
        [VECTOR_COLOR, greenColor],
        [VECTOR_LINE,
          50 + cos(i * angle) * 47,
          50 + sin(i * angle) * 47,
          50 + cos(i * angle) * 50.0,
          50 + sin(i * angle) * 50.0
        ])
  }

  return {
    rendObj = ROBJ_VECTOR_CANVAS
    size = compSize
    pos
    lineWidth = hdpx(1)
    color = greenColor
    fillColor = transparentColor
    halign = ALIGN_CENTER
    commands
    children = mkNorthLable({pos = [0, hdpx(4)], font = Fonts.small_text_hud})
  }
}

let function mkBackground(size) {
  let back = {
    rendObj = ROBJ_VECTOR_CANVAS
    size
    color = backgroundColor
    fillColor = backgroundColor
    lineWidth = hdpx(0)
    commands = [
      [VECTOR_ELLIPSE, 50, 50, 50, 50]
    ]
  }

  let backTop = {
    rendObj = ROBJ_IMAGE
    size = [size[0], 0.583 * size[1]]
    image = Picture($"!ui/gameuiskin#fcs_top_background.svg:{floor(size[0])}:{floor(0.583 * size[1])}")
  }

  let circleOuter = {
    rendObj = ROBJ_VECTOR_CANVAS
    size = size.map(@(v) v - hdpx(10))
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
    color = greenColor
    fillColor = transparentColor
    lineWidth = hdpx(4)
    commands = [
      [VECTOR_ELLIPSE, 50, 50, 50, 50]
    ]
  }

  return {
    children = [
      back,
      backTop,
      circleOuter
    ]
  }
}

let headingAngleLabel = {
  rendObj = ROBJ_TEXT
  color = greenColor
  font = Fonts.very_tiny_text_hud
  pos = [pw(4), ph(48)]
  text = loc("fcs/heading_angle")
}

let function mkHeadingAngleValue() {
  return @() {
    watch = HeadingAngle
    rendObj = ROBJ_TEXT
    color = greenColor
    pos = [pw(4), ph(40)]
    font = Fonts.small_text_hud
    text = "".concat($"{floor(HeadingAngle.value)}", loc("measureUnits/deg"))
  }
}

let mkTargetSpeedLabel = @() {
  rendObj = ROBJ_TEXT
  color = greenColor
  font = Fonts.very_tiny_text_hud
  halign = ALIGN_RIGHT
  size = [pw(96), ph(100)]
  pos = [0, ph(48)]
  text = loc("fcs/target_speed")
}

let targetSpeedValueComp = {
  halign = ALIGN_RIGHT
  valign = ALIGN_BOTTOM
  flow = FLOW_HORIZONTAL
  size = [pw(96), SIZE_TO_CONTENT]
  pos = [0, ph(40)]
  children = [
    @(){
      watch = TargetSpeed
      rendObj = ROBJ_TEXT
      color = greenColor
      font = Fonts.small_text_hud
      text = cross_call.measureTypes.SPEED.getMeasureUnitsText(TargetSpeed.value, false)
    },
    @(){
      watch = [isInitializedMeasureUnits, measureUnitsNames]
      rendObj = ROBJ_TEXT
      color = greenColor
      font = Fonts.very_tiny_text_hud
      margin = [0, 0, hdpx(3), 0]
      text = isInitializedMeasureUnits.value ? loc(measureUnitsNames.value.speed) : ""
    }
  ]
}

let function mkFCSComponent(posWatched, fcsSize = sh(28)) {
  let size = [fcsSize + hdpx(2), fcsSize + hdpx(2)]
  let gap = hdpx(5)

  return @(){
    watch = [posWatched, IsTargetSelected]
    size
    pos = [posWatched.value[0] + maxMeasuresCompWidth() + gap, posWatched.value[1] + maxLabelHeight]
    children = [
      mkBackground(size)
      mkShotResultComponent(size)
      mkHeroShipPlace(size)
      mkHeroShipComponent(size)
      mkTargetShipPlace(size)
      IsTargetSelected.value ? mkTargetShipComponent(size) : null
      IsTargetSelected.value ? mkHeadingAngleValue() : null
      IsTargetSelected.value ? targetSpeedValueComp : null
      headingAngleLabel
      mkTargetSpeedLabel()
      mkShotResultBulletsComponent(size)
      mkShotResultTextComponent(size)
    ]
    onAttach = @() showNewStateFromQueue()
    onDetach = @() clearCurrentShotState()
  }
}

return {
  mkFCSComponent
}