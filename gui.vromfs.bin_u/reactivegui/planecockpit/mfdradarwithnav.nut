from "%rGui/globals/ui_library.nut" import *

let string = require("string")
let { Altitude, Roll } = require("%rGui/planeState/planeFlyState.nut")
let { DistanceMax, MfdRadarColor, targets, Irst, TargetsTrigger,
  HasDistanceScale, HasAzimuthScale, Distance } = require("%rGui/radarState.nut")
let compass = require("%rGui/compass.nut")

let baseLineWidth = hdpx(2 * LINE_WIDTH)

let AltWatched = Computed(@() ((20.0 - Altitude.value * 0.001) * 5).tointeger())
let altitude = @() {
  size = [pw(10), ph(70)]
  pos = [pw(85), ph(15)]
  children = [
    {
      size = [pw(50), flex()]
      rendObj = ROBJ_VECTOR_CANVAS
      color = MfdRadarColor.value
      lineWidth = baseLineWidth
      commands = [
        [VECTOR_LINE, 0, 0, 100, 0],
        [VECTOR_LINE, 0, 5, 50, 5],
        [VECTOR_LINE, 0, 10, 50, 10],
        [VECTOR_LINE, 0, 15, 50, 15],
        [VECTOR_LINE, 0, 20, 50, 20],
        [VECTOR_LINE, 0, 25, 100, 25],
        [VECTOR_LINE, 0, 30, 50, 30],
        [VECTOR_LINE, 0, 35, 50, 35],
        [VECTOR_LINE, 0, 40, 50, 40],
        [VECTOR_LINE, 0, 45, 50, 45],
        [VECTOR_LINE, 0, 50, 100, 50],
        [VECTOR_LINE, 0, 55, 50, 55],
        [VECTOR_LINE, 0, 60, 50, 60],
        [VECTOR_LINE, 0, 65, 50, 65],
        [VECTOR_LINE, 0, 70, 50, 70],
        [VECTOR_LINE, 0, 75, 100, 75],
        [VECTOR_LINE, 0, 80, 50, 80],
        [VECTOR_LINE, 0, 85, 50, 85],
        [VECTOR_LINE, 0, 90, 50, 90],
        [VECTOR_LINE, 0, 95, 50, 95],
        [VECTOR_LINE, 0, 100, 100, 100],
      ]
    },
    {
      rendObj = ROBJ_TEXT
      pos = [pw(50), ph(69)]
      size = flex()
      color = MfdRadarColor.value
      fontSize = 25
      text = "5"
    },
    {
      rendObj = ROBJ_TEXT
      pos = [pw(50), ph(44)]
      size = flex()
      color = MfdRadarColor.value
      fontSize = 25
      text = "10"
    },
    {
      rendObj = ROBJ_TEXT
      pos = [pw(50), ph(19)]
      size = flex()
      color = MfdRadarColor.value
      fontSize = 25
      text = "15"
    },
    {
      rendObj = ROBJ_TEXT
      pos = [pw(50), ph(-6)]
      size = flex()
      color = MfdRadarColor.value
      fontSize = 25
      text = "20"
    },
    @() {
      watch = AltWatched
      size = flex()
      color = MfdRadarColor.value
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = baseLineWidth
      commands = [
        [VECTOR_LINE, 0, AltWatched.value, -50, AltWatched.value],
        [VECTOR_LINE, 0, AltWatched.value, -30, AltWatched.value - 5],
        [VECTOR_LINE, 0, AltWatched.value, -30, AltWatched.value + 5]
      ]
    }
  ]
}

let flyDirection = @() {
    size = [pw(10), ph(10)]
    pos = [pw(50), ph(50)]
    rendObj = ROBJ_VECTOR_CANVAS
    color = MfdRadarColor.value
    fillColor = Color(0, 0, 0, 0)
    lineWidth = baseLineWidth * 0.5
    commands = [
      [VECTOR_ELLIPSE, 0, 0, 20, 20],
      [VECTOR_LINE, -100, 9, -20, 9],
      [VECTOR_LINE, -100, 0, -20, 0],
      [VECTOR_LINE, -100, -9, -20, -9],
      [VECTOR_LINE, 20, 9, 100, 9],
      [VECTOR_LINE, 20, 0, 100, 0],
      [VECTOR_LINE, 20, -9, 100, -9],
      [VECTOR_LINE, 5, -20, 5, -60],
      [VECTOR_LINE, -5, -20, -5, -60]
    ]
}

let digitalAlt = Computed(@() string.format(Altitude.value < 1000 ? "%d0" : "%.1f", Altitude.value < 1000 ? Altitude.value / 10 : Altitude.value / 1000.0))
let roll = @() {
  size = flex()
  children = [
    {
      size = flex()
      rendObj = ROBJ_VECTOR_CANVAS
      color = MfdRadarColor.value
      lineWidth = baseLineWidth * 0.7
      commands = [
        [VECTOR_LINE, 0, 53, 100, 53],
        [VECTOR_LINE, 0, 54.5, 100, 54.5],
        [VECTOR_LINE, 20, 55, 20, 70],
        [VECTOR_LINE, 21, 55, 21, 70],
        [VECTOR_LINE, 22, 55, 22, 70],
        [VECTOR_LINE, 80, 55, 80, 70],
        [VECTOR_LINE, 79, 55, 79, 70],
        [VECTOR_LINE, 78, 55, 78, 70],
      ]
      children = [
        @() {
          watch = digitalAlt
          rendObj = ROBJ_TEXT
          pos = [pw(20), ph(47)]
          size = flex()
          color = MfdRadarColor.value
          fontSize = 25
          text = digitalAlt.value
        }
      ]
    }
  ]
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      rotate = -Roll.value
    }
  }
}

let distance = @() {
  watch = DistanceMax
  size = [pw(10), ph(70)]
  pos = [pw(10), ph(15)]
  children = [
    {
      size = [pw(50), flex()]
      rendObj = ROBJ_VECTOR_CANVAS
      color = MfdRadarColor.value
      lineWidth = baseLineWidth
      commands = [
        [VECTOR_LINE, 0, 0, 100, 0],
        [VECTOR_LINE, 0, 16.5, 100, 16.5],
        [VECTOR_LINE, 0, 33, 100, 33],
        [VECTOR_LINE, 0, 50, 100, 50],
        [VECTOR_LINE, 0, 66, 100, 66],
        [VECTOR_LINE, 0, 82.5, 100, 82.5],
        [VECTOR_LINE, 0, 100, 100, 100],
        [VECTOR_LINE, 100, 0, 100, 100]
      ]
    },
    {
      rendObj = ROBJ_TEXT
      pos = [pw(0), ph(60)]
      size = flex()
      color = MfdRadarColor.value
      fontSize = 25
      text = (DistanceMax.value * 0.33).tointeger()
    },
    {
      rendObj = ROBJ_TEXT
      pos = [pw(0), ph(27)]
      size = flex()
      color = MfdRadarColor.value
      fontSize = 25
      text = (DistanceMax.value * 0.66).tointeger()
    },
    {
      rendObj = ROBJ_TEXT
      pos = [pw(50), ph(-6)]
      size = flex()
      color = MfdRadarColor.value
      fontSize = 25
      text = DistanceMax.value.tointeger()
    }
  ]
}

let function compassElem(width, height) {
  return {
    size = flex()
    pos = [pw(15), ph(3)]
    children = [
      compass([width * 0.7, height * 0.1], MfdRadarColor.value)
    ]
  }
}

let createTarget = @(index) function() {
  let target = targets[index]
  let distanceRel = HasDistanceScale.value ? target.distanceRel : 0.9

  let angleRel = HasAzimuthScale.value ? target.azimuthRel : 0.5

  return {
    watch = [HasAzimuthScale, HasDistanceScale, Distance]
    rendObj = ROBJ_VECTOR_CANVAS
    size = [pw(80), ph(70)]
    pos = [pw(10), ph(15)]
    lineWidth = baseLineWidth
    color = MfdRadarColor.value
    fillColor = MfdRadarColor.value
    commands = Distance.value == 1.0 ? [
      [VECTOR_ELLIPSE, 100 * angleRel, 100 * (1 - distanceRel), 1.5, 1.5],
      (target.isDetected || target.isSelected ? [VECTOR_LINE, 100 * angleRel - 3, 100 * (1 - distanceRel) - 2, 100 * angleRel - 3, 100 * (1 - distanceRel) + 2] : []),
      (target.isDetected || target.isSelected ? [VECTOR_LINE, 100 * angleRel + 3, 100 * (1 - distanceRel) - 2, 100 * angleRel + 3, 100 * (1 - distanceRel) + 2] : []),
      (!target.isEnemy ? [VECTOR_LINE, 100 * angleRel - 3, 100 * (1 - distanceRel) - 3, 100 * angleRel + 3, 100 * (1 - distanceRel) - 3] : [])
    ] : [
      [VECTOR_ELLIPSE, 10, 100 * (1 - distanceRel), 1, 1],
      [VECTOR_LINE, 100 * angleRel - 1.5, 100 * (1 - distanceRel) - 2, 100 * angleRel - 1.5, 100 * (1 - distanceRel) + 2],
      [VECTOR_LINE, 100 * angleRel + 1.5, 100 * (1 - distanceRel) - 2, 100 * angleRel + 1.5, 100 * (1 - distanceRel) + 2],
      [VECTOR_LINE, 100 * angleRel - 3, 100 * (1 - distanceRel) - 1, 100 * angleRel + 3, 100 * (1 - distanceRel) - 1],
      [VECTOR_LINE, 100 * angleRel - 3, 100 * (1 - distanceRel) + 1, 100 * angleRel + 3, 100 * (1 - distanceRel) + 1],
      (!target.isEnemy ? [VECTOR_LINE, 100 * angleRel - 3, 100 * (1 - distanceRel) - 3, 100 * angleRel + 3, 100 * (1 - distanceRel) - 3] : [])
    ]
  }
}

let targetsComponent = function(createTargetDistFunc) {
  let getTargets = function() {
    let targetsRes = []
    for (local i = 0; i < targets.len(); ++i) {
      if (!targets[i])
        continue
      else if (targets[i].signalRel < 0.1)
        continue
      targetsRes.append(createTargetDistFunc(i))
    }
    return targetsRes
  }

  return @() {
    size = flex()
    children = Irst.value ? null : getTargets()
    watch = TargetsTrigger
  }
}

let function Root(width, height, posX = 0, posY = 0) {
  return {
    pos = [posX, posY]
    size = [width, height]
    children = [
      altitude,
      flyDirection,
      roll,
      distance,
      compassElem(width, height),
      targetsComponent(createTarget)
    ]
  }
}

return Root