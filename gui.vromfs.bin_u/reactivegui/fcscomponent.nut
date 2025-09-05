from "%rGui/globals/ui_library.nut" import *

let cross_call = require("%rGui/globals/cross_call.nut")
let { PI, floor, cos, sin, fabs } = require("%sqstd/math.nut")
let { cvt } = require("dagor.math")
let { shuffle } = require("%sqStdLibs/helpers/u.nut")
let { maxLabelHeight, maxMeasuresCompWidth } = require("%rGui/radarComponent.nut")
let { isInitializedMeasureUnits, measureUnitsNames } = require("%rGui/options/optionsMeasureUnits.nut")
let { IsTargetDataAvailable, aimAngle, TargetAzimuthAngle, HeroAzimuthAngle, HeadingAngle, TargetSpeed,
  IsTargetSelected, IsTargetDead } = require("%rGui/fcsState.nut")
let { fcsShotState, showNewStateFromQueue, clearCurrentShotState } = require("%rGui/fcsStateQueue.nut")
let { sightAngle } = require("%rGui/shipState.nut")

let backgroundColor = Color(0, 0, 0, 60)
let transparentColor = Color(0, 0, 0, 0)
let greenColor = Color(10, 120, 10, 100)
let greenColorShip = Color(10, 250, 10, 165)
let blackColor = Color(0, 0, 0, 130)
let whiteColor = Color(255, 255, 255, 10)
let redColor = Color(255, 0, 0, 180)

let fontSize = hdpxi(10)

let bulletsOverPositions = [[0.3, 0.18], [0.5, 0.133], [0.7, 0.18]]
let bulletsShortPositions = [[0.3, 0.82], [0.5, 0.866], [0.7, 0.82]]
let bulletsHitPositions = [[0.3, 0.5], [0.5, 0.5], [0.7, 0.5]]
let imageSuffixes = ["", "over", "short", "stradle", "hit"]
let transitionDuration = 1.2
let showDurationOnDeath = 6.5

let deathEasing = function(x) {
  let wait = showDurationOnDeath / (showDurationOnDeath + transitionDuration)
  return x < wait ? 0 : sin(PI * 0.5 * cvt(x, wait, 1, 0, 1))
}

let isShotResultVisible = Computed(@() fcsShotState.get().shotState != FCSShotState.SHOT_NONE && (IsTargetDataAvailable.get() || IsTargetDead.get()))

IsTargetDataAvailable.subscribe(@(_) clearCurrentShotState())

function mkTargetShipComponent(size) {
  let compSize = [0.486 * size[0], 0.486 * size[1]]
  let compCenter = [0.5 * size[0], 0.286 * size[1]]
  let pos = [compCenter[0] - compSize[0] / 2, compCenter[1] - compSize[1] / 2]
  let shipWidth = floor(0.192 * compSize[0])
  let shipHeight = floor(0.685 * compSize[1])

  return @() {
    watch = [IsTargetDataAvailable, IsTargetSelected, IsTargetDead]
    size = compSize
    pos
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    opacity = IsTargetDataAvailable.get() ? 1 : 0
    transitions = IsTargetDead.get()
      ? [{prop = AnimProp.opacity, duration = transitionDuration + showDurationOnDeath, easing = deathEasing }]
      : [{prop = AnimProp.opacity, duration = transitionDuration, easing = InOutQuad }]
    children = !IsTargetSelected.get() || IsTargetDataAvailable.get() ? [
      @(){
        rendObj = ROBJ_IMAGE
        watch = TargetAzimuthAngle
        size = [shipWidth, shipHeight]
        color = redColor
        image = Picture($"!ui/gameuiskin#fcs_ship_enemy.svg:{shipWidth}:{shipHeight}")
        transform = {
          pivot = [0.5, 0.5]
          rotate = TargetAzimuthAngle.get()
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
          rotate = aimAngle.get() + 180
        }
      }
    ] : null
  }
}

function mkHeroShipComponent(size) {
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
        color = greenColorShip
        transform = {
          pivot = [0.5, 0.5]
          rotate = HeroAzimuthAngle.get()
        }
      }
      @() {
        rendObj = ROBJ_IMAGE
        watch = sightAngle
        size = coneSize
        color = Color(150, 150, 150, 100)
        image = Picture("+ui/gameuiskin#map_camera")
        transform = {
          pivot = [0.5, 0.5]
          rotate = sightAngle.get()
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
        commands = IsTargetSelected.get() ? [[VECTOR_ELLIPSE, 50, 7, 2, 2]] : null
        transform = {
          rotate = aimAngle.get()
        }
        key = {}
        animations = [{ prop = AnimProp.opacity, from = 0, to = 1, duration = transitionDuration, play = true, easing = InQuad }]
      }
    ]
  }
}

function mkBullet(bulletWidth, pos, delay, icon_type = "wrong") {
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

function convertBulletPos(pos, size, bulletWidth) {
  return [pos[0] * size[0] - bulletWidth / 2, pos[1] * size[1] - bulletWidth / 2]
}

function mkShotResultBullets(size, shotState) {
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

function mkShotResultComponent(size) {
  let compSize = [floor(0.486 * size[0]), floor(0.486 * size[1])]
  let center = [0.5 * size[0], 0.286 * size[1]]
  let pos = [center[0] - compSize[0] / 2, center[1] - compSize[1] / 2]
  return function(){
    if (!isShotResultVisible.get())
      return { watch = [isShotResultVisible, fcsShotState] }

    let imageSuff = fcsShotState.get().shotState != FCSShotState.SHOT_HIT ? FCSShotState.SHOT_OVER : FCSShotState.SHOT_HIT
    return {
      watch = [isShotResultVisible, fcsShotState]
      size = compSize
      pos
      children = {
        rendObj = ROBJ_IMAGE
        size = compSize
        image = Picture($"!ui/gameuiskin#fcs_shot_result_{imageSuffixes[imageSuff]}.svg:{compSize[0]}:{compSize[1]}")
        transform = {
          pivot = [0.5, 0.5]
          rotate = fcsShotState.get().shotDirection
        }
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

function mkShotResultBulletsComponent(size) {
  let compSize = [floor(0.486 * size[0]), floor(0.486 * size[1])]
  let center = [0.5 * size[0], 0.286 * size[1]]
  let pos = [center[0] - compSize[0] / 2, center[1] - compSize[1] / 2]
  return @(){
    watch = isShotResultVisible
    size = compSize
    pos
    children = isShotResultVisible.get() ? mkShotResultBullets(compSize, fcsShotState.get().shotState) : null
  }
}

function mkShotResultText(fcsShotStateValue) {
  if(fcsShotStateValue.shotState == FCSShotState.SHOT_NONE)
    return null

  local resultText = loc($"fcs/{imageSuffixes[fcsShotState.get().shotState]}")

  if(fcsShotStateValue.shotDiscrepancy != 0
    && [FCSShotState.SHOT_SHORT, FCSShotState.SHOT_OVER].contains(fcsShotStateValue.shotState)) {
      let valueString = $"{cross_call.measureTypes.DISTANCE.getMeasureUnitsText(fcsShotStateValue.shotDiscrepancy)}"
      resultText = $"{resultText}: {valueString}"
  }
  return {
    rendObj = ROBJ_TEXT
    color = fcsShotStateValue.shotState == FCSShotState.SHOT_HIT ? blackColor : whiteColor
    font = Fonts.very_tiny_text_hud
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

function mkShotResultBack(fillColor) {
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
        duration = 0.5, onFinish = clearCurrentShotState
      }
    ]
  }
}

function mkShotResultTextComponent(size) {
  return function() {
    let minCompWidth = 0.413 * size[0]
    let compHeight = 0.067 * size[1]
    let shotResultText = mkShotResultText(fcsShotState.get())
    let textSize = calc_comp_size(shotResultText)
    let compWidth = max(minCompWidth, textSize[0] + hdpx(10))
    let pos = [size[0] / 2 - compWidth / 2, 0.583 * size[1] - compHeight / 2]
    let fillColor = fcsShotState.get().shotState == FCSShotState.SHOT_NONE ? backgroundColor
      : fcsShotState.get().shotState == FCSShotState.SHOT_HIT ? greenColor
      : redColor
    return {
      watch = isShotResultVisible
      size = [compWidth, compHeight]
      pos
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      children = [
        isShotResultVisible.get() ? mkShotResultBack(fillColor) : null
        isShotResultVisible.get() ? shotResultText : null
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

function mkHeroShipPlace(size) {
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

function mkTargetShipPlace(size) {
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
    children = mkNorthLable({pos = [0, hdpx(4)], font = Fonts.very_tiny_text_hud})
  }
}

function mkBackground(size) {
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

  return {
    children = [
      back,
      backTop
    ]
  }
}

let headingAngleLabel = {
  rendObj = ROBJ_TEXT
  color = greenColor
  pos = [pw(4), ph(48)]
  font = Fonts.very_tiny_text_hud
  fontSize
  text = loc("fcs/heading_angle")
}

function mkHeadingAngleValue() {
  return @() {
    watch = HeadingAngle
    rendObj = ROBJ_TEXT
    color = greenColor
    pos = [pw(4), ph(40)]
    font = Fonts.very_tiny_text_hud
    text = "".concat($"{floor(HeadingAngle.get())}", loc("measureUnits/deg"))
  }
}

let mkTargetSpeedLabel = @() {
  rendObj = ROBJ_TEXT
  color = greenColor
  font = Fonts.very_tiny_text_hud
  halign = ALIGN_RIGHT
  size = static [pw(96), ph(100)]
  pos = [0, ph(48)]
  text = loc("fcs/target_speed")
  fontSize
}

let targetSpeedValueComp = {
  halign = ALIGN_RIGHT
  valign = ALIGN_BOTTOM
  flow = FLOW_HORIZONTAL
  size = static [pw(96), SIZE_TO_CONTENT]
  pos = [0, ph(40)]
  children = [
    @(){
      watch = TargetSpeed
      rendObj = ROBJ_TEXT
      color = greenColor
      font = Fonts.very_tiny_text_hud
      text = cross_call.measureTypes.SPEED.getMeasureUnitsText(TargetSpeed.get(), false)
    },
    @(){
      watch = [isInitializedMeasureUnits, measureUnitsNames]
      rendObj = ROBJ_TEXT
      color = greenColor
      font = Fonts.very_tiny_text_hud
      fontSize
      margin = static [0, 0, hdpx(3), 0]
      text = isInitializedMeasureUnits.get() ? loc(measureUnitsNames.get().speed) : ""
    }
  ]
}

function mkFCSComponent(posWatched, size) {
  let gap = sh(3)

  return @(){
    watch = [posWatched, IsTargetDataAvailable]
    size
    pos = [posWatched.value[0] + maxMeasuresCompWidth() - sh(6), posWatched.value[1] + maxLabelHeight + gap]
    children = [
      mkBackground(size)
      mkShotResultComponent(size)
      mkHeroShipPlace(size)
      mkHeroShipComponent(size)
      mkTargetShipPlace(size)
      mkTargetShipComponent(size)
      IsTargetDataAvailable.get() ? mkHeadingAngleValue() : null
      IsTargetDataAvailable.get() ? targetSpeedValueComp : null
      headingAngleLabel
      mkTargetSpeedLabel()
      mkShotResultBulletsComponent(size)
      mkShotResultTextComponent(size)
    ]
    onAttach = showNewStateFromQueue
    onDetach = clearCurrentShotState
  }
}

function drawArrow(x, y, dirX, dirY, color, fill = false, scale = 1) {
  let arrowSize = sh(2)
  local arrowCommands = []

  if (fill) {
    arrowCommands = dirX == 0
      ? [[VECTOR_POLY, 0, 0, 25, dirY * 50, -25, dirY * 50]]
      : [[VECTOR_POLY, 0, 0, -dirX * 50, 25, -dirX * 50, -25]]
  }
  else {
    arrowCommands = dirX == 0 ? [
        [VECTOR_LINE, 0, dirY * 5, 35,  dirY * 55],
        [VECTOR_LINE, 0, dirY * 5, -35, dirY * 55]
      ] : [
        [VECTOR_LINE, -dirX * 5, 0, -dirX * 55, 25],
        [VECTOR_LINE, -dirX * 5, 0, -dirX * 55, -25]
      ]
  }

  return {
    rendObj = ROBJ_VECTOR_CANVAS
    size = [arrowSize, arrowSize]
    pos = [x, y]
    lineWidth = hdpx(2 * scale)
    color = color
    fillColor = fill ? color : Color(0, 0, 0, 0)
    commands = arrowCommands
  }
}

return {
  mkFCSComponent
  drawArrow
}