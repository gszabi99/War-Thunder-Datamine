local {rwrTargetsTriggers, lwsTargetsTriggers, mlwsTargetsTriggers, mlwsTargets, lwsTargets, rwrTargets, IsMlwsLwsHudVisible, MlwsLwsSignalHoldTimeInv, RwrSignalHoldTimeInv, IsRwrHudVisible, LastTargetAge, CurrentTime} = require("twsState.nut")
local {MlwsLwsForMfd, RwrForMfd} = require("airState.nut");
local {isColorOrWhite} = require("style/airHudStyle.nut")

local backgroundColor = Color(0, 0, 0, 50)

local indicatorRadius = 70.0
local trackRadarsRadius = 0.04
local azimuthMarkLength = 50 * 3 * trackRadarsRadius

local styleLineBackground = {
  fillColor = Color(0, 0, 0, 0)
  lineWidth = hdpx(LINE_WIDTH + 1.5)
}

local centeredAircraftIcon = ::kwarg(function(colorWatched, pos = [0, 0], size = flex()) {
  local tailW = 25
  local tailH = 10
  local tailOffset1 = 10
  local tailOffset2 = 5
  local tailOffset3 = 25
  local fuselageWHalf = 10
  local wingOffset1 = 45
  local wingOffset2 = 30
  local wingW = 32
  local wingH = 18
  local wingOffset3 = 30
  local noseOffset = 5


  local aircraftIcon = @() styleLineBackground.__merge({
    watch = colorWatched
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(2)
    fillColor = Color(0, 0, 0, 0)
    color = colorWatched.value
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    size = [pw(33), ph(33)]
    pos = [0, 0]
    opacity = 0.42
    commands = [
      [VECTOR_POLY,
        // tail left
        50, 100 - tailOffset1,
        50 - tailW, 100 - tailOffset2,
        50 - tailW, 100 - tailOffset2 - tailH,
        50 - fuselageWHalf, 100 - tailOffset3,
        // wing left
        50 - fuselageWHalf, 100 - wingOffset1,
        50 - fuselageWHalf - wingW, 100 - wingOffset2,
        50 - fuselageWHalf - wingW, 100 - wingOffset2 - wingH,
        50 - fuselageWHalf, wingOffset3,
        // nose
        50, noseOffset,
        // wing rigth
        50 + fuselageWHalf, wingOffset3,
        50 + fuselageWHalf + wingW, 100 - wingOffset2 - wingH,
        50 + fuselageWHalf + wingW, 100 - wingOffset2,
        50 + fuselageWHalf, 100 - wingOffset1,
        // tail right
        50 + fuselageWHalf, 100 - tailOffset3,
        50 + tailW, 100 - tailOffset2 - tailH,
        50 + tailW, 100 - tailOffset2
      ]
    ]
  })

  return {
    size = flex()
    children = [
      @() styleLineBackground.__merge({
        rendObj = ROBJ_VECTOR_CANVAS
        size = flex()
        fillColor = Color(0,0,0,0)
        color = colorWatched.value
        watch = colorWatched
        lineWidth = hdpx(LINE_WIDTH)
        commands = [
          [VECTOR_ELLIPSE, 50, 50, indicatorRadius * 0.25, indicatorRadius * 0.25]
        ]
      }),
      aircraftIcon
    ]
  }
})

local targetOpacityMult = Computed(@() math.floor((math.sin(CurrentTime.value * 10.0))))
local targetOpacity = Computed(@() max(0.0, 1.0 - min(LastTargetAge.value * MlwsLwsSignalHoldTimeInv.value, 1.0)) * targetOpacityMult.value)

local createCircle = @(colorWatched, backGroundColorEnabled, scale = 1.0, isForTank = false) function() {

  return styleLineBackground.__merge({
    watch = [targetOpacity, colorWatched]
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(LINE_WIDTH)
    fillColor = backGroundColorEnabled ? backgroundColor : Color(0,0,0,0)
    color = colorWatched.value
    opacity = !isForTank ? 1.0 : targetOpacity.value
    size = flex()
    commands =
      [
        [VECTOR_ELLIPSE, 50, 50, indicatorRadius * scale, indicatorRadius * scale]
      ]
  })
}

local function createAzimuthMark(colorWatch, scale = 1.0, isForTank = false){
  const angleGrad = 30.0
  local angle = math.PI * angleGrad / 180.0
  local dashCount = 360.0 / angleGrad
  local innerMarkRadius = indicatorRadius * scale - azimuthMarkLength

  local azimuthMarksCommands = array(dashCount).map(@(_, i) [
    VECTOR_LINE,
    50 + math.cos(i * angle) * innerMarkRadius,
    50 + math.sin(i * angle) * innerMarkRadius,
    50 + math.cos(i * angle) * indicatorRadius * scale,
    50 + math.sin(i * angle) * indicatorRadius * scale
  ])

  return @() styleLineBackground.__merge({
    watch = [targetOpacity, colorWatch]
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(1)
    fillColor = Color(0, 0, 0, 0)
    size = flex()
    color = colorWatch.value
    opacity = !isForTank ? 0.42 : targetOpacity.value * 0.42
    commands = azimuthMarksCommands
  })
}

local twsBackground = @(colorWatched, isForTank = false) function() {

  local res = { watch = [IsMlwsLwsHudVisible, MlwsLwsForMfd] }

  if (!IsMlwsLwsHudVisible.value && !MlwsLwsForMfd.value)
    return res

  return res.__update({
    size = flex()
    children = [
      createCircle(colorWatched, true, 1, isForTank),
      createAzimuthMark(colorWatched, 1, isForTank)
    ]
  })
}

local rwrBackground = @(colorWatched, scale) function() {

  local res = { watch = [IsRwrHudVisible, IsMlwsLwsHudVisible, RwrForMfd] }

  if (!IsRwrHudVisible.value && !RwrForMfd.value)
    return res

  return res.__update({
    size = [pw(75), ph(75)]
    pos = [pw(12), ph(12)]
    children = [
      createCircle(colorWatched, !IsMlwsLwsHudVisible.value, scale)
      createAzimuthMark(colorWatched, scale)
    ]
  })
}

local rocketVector =
  [
    //right stab
    [VECTOR_LINE, -15, -40, -15, -30],
    [VECTOR_LINE, -15, -40, -5, -35],
    [VECTOR_LINE, -15, -30, -5, -25],
    //left stab
    [VECTOR_LINE, 15, -40, 15, -30],
    [VECTOR_LINE, 15, -40, 5, -35],
    [VECTOR_LINE, 15, -30, 5, -25],
    //right stab 2
    [VECTOR_LINE, -15, 0, -15, 10],
    [VECTOR_LINE, -15, 0, -5, 5],
    [VECTOR_LINE, -15, 10, -5, 15],
    //left stab 2
    [VECTOR_LINE, 15, 0, 15, 10],
    [VECTOR_LINE, 15, 0, 5, 5],
    [VECTOR_LINE, 15, 10, 5, 15],
    //rocket tank
    [VECTOR_LINE, -5, -25, -5, 0],
    [VECTOR_LINE, 5, -25, 5, 0],
    [VECTOR_LINE, -5, -35, 5, -35],
    //rocket tank 2
    [VECTOR_LINE, -5, 15, -5, 30],
    [VECTOR_LINE, 5, 15, 5, 30],
    //warhead
    [VECTOR_LINE, -5, 30, 0, 40],
    [VECTOR_LINE, 5, 30, 0, 40]
  ]

local function createMlwsTarget(index, colorWatch) {
  local target = mlwsTargets[index]

  local targetComponent = @() {
    watch = [targetOpacity, colorWatch]
    color = isColorOrWhite(colorWatch.value)
    rendObj = ROBJ_VECTOR_CANVAS
    pos = [pw(100), ph(100)]
    size = [pw(50), ph(50)]
    lineWidth = hdpx(1)
    fillColor = Color(0, 0, 0, 0)
    opacity = targetOpacity.value
    transform = {
      pivot = [0.0, 0.0]
      rotate = 135 //toward center
    }
    commands = rocketVector
    children = target.enemy ? null
      : {
          color = isColorOrWhite(colorWatch.value)
          rendObj = ROBJ_VECTOR_CANVAS
          lineWidth = hdpx(1)
          fillColor = backgroundColor
          opacity = targetOpacity.value
          size = flex()
          commands = [[VECTOR_ELLIPSE, 0, 0, 45, 45]]
        }
  }

  return {
    size = flex()
    pos = [pw(50), ph(50)]
    transform = {
      pivot = [0.0, 0.0]
      rotate = math.atan2(target.y, target.x) * (180.0 / math.PI) - 45
    }
    children = [
      targetComponent
    ]
  }
}

local function createLwsTarget(index, colorWatched, isForTank = false) {
  local target = lwsTargets[index]
  local targetComponent = @() {
    watch = [targetOpacity, colorWatched]
    color = isColorOrWhite(colorWatched.value)
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(1)
    fillColor = Color(0, 0, 0, 0)
    opacity = targetOpacity.value
    size = [pw(50), ph(50)]
    pos = [pw(100), ph(100)]
    commands = isForTank ?
      [
        [VECTOR_LINE, 15, 0, 0, 50],
        [VECTOR_LINE, -15, 0, 0, 50],
        [VECTOR_LINE, 15, 0, -15, 0],
      ]
      :
      [
        [VECTOR_LINE, 0, -25, 0, 5],
        [VECTOR_LINE, 0, 13, 0, 27],
        [VECTOR_LINE, 5, 13, 11, 22],
        [VECTOR_LINE, -5, 13, -11, 22],
        [VECTOR_LINE, -6, 10, -15, 10],
        [VECTOR_LINE, 6, 10, 15, 10]
      ]

    transform = {
      pivot = [0.0, 0.0]
      rotate = 135.0 //toward center
    }

    children = target.enemy ? null
      : {
          color = isColorOrWhite(colorWatched.value)
          rendObj = ROBJ_VECTOR_CANVAS
          lineWidth = hdpx(1)
          fillColor = backgroundColor
          opacity = targetOpacity.value
          size = flex()
          commands = [[VECTOR_ELLIPSE, 0, 0, 45, 45]]
        }
  }

  return {
    size = flex()
    pos = [pw(50), ph(50)]
    transform = {
      pivot = [0.0, 0.0]
      rotate = math.atan2(target.y, target.x) * (180.0 / math.PI) - 45
    }
    children = [
      targetComponent
    ]
  }
}

local function createRwrTarget(index, colorWatched) {
  local target = rwrTargets[index]
  local targetOpacityRwr = Computed(@() max(0.0, 1.0 - min(target.age * RwrSignalHoldTimeInv.value, 1.0)))

  local trackLine = null

  if (target.track) {
    trackLine = @() {
      watch = [targetOpacityRwr, colorWatched]
      color = isColorOrWhite(colorWatched.value)
      rendObj = ROBJ_VECTOR_CANVAS
      size = [pw(50), ph(50)]
      pos = [pw(100), ph(100)]
      lineWidth = hdpx(1)
      opacity = targetOpacityRwr.value
      commands = [
        [VECTOR_LINE_DASHED, -135, -135, -80, -80, hdpx(5), hdpx(3)]
      ]
    }
  }

  local targetComponent = @() {
    watch = [targetOpacityRwr, colorWatched]
    color = isColorOrWhite(colorWatched.value)
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(1)
    fillColor = Color(0, 0, 0, 0)
    opacity = targetOpacityRwr.value
    size = [pw(50), ph(50)]
    pos = [pw(85), ph(85)]
    commands = [
      [VECTOR_SECTOR, -0, -0, 35, 25, -230, 230],
      [VECTOR_SECTOR, -0, -0, 45, 35, -240, 240],
      [VECTOR_SECTOR, -0, -0, 55, 45, -250, 250]
    ]

    transform = {
      pivot = [0.0, 0.0]
      rotate = 45.0 //toward center
    }

    children = target.enemy ? null
      : {
          color = isColorOrWhite(colorWatched.value)
          rendObj = ROBJ_VECTOR_CANVAS
          lineWidth = hdpx(1)
          opacity = targetOpacityRwr.value
          size = flex()
          commands = [[VECTOR_LINE, -20, -40, -20, 40]]
        }
    }

  return {
    size = flex()
    pos = [pw(50), ph(50)]
    transform = {
      pivot = [0.0, 0.0]
      rotate = math.atan2(target.y, target.x) * (180.0 / math.PI) - 45
    }
    children = [
      targetComponent,
      trackLine
    ]
  }
}

local function mlwsTargetsComponent(colorWatch) {

  return @() {
    watch = mlwsTargetsTriggers
    size = flex()
    children = mlwsTargets.filter(@(t) t != null).map(@(_, i) createMlwsTarget(i, colorWatch))
  }
}

local function lwsTargetsComponent(colorWatched, isForTank = false) {

  return @() {
    watch = lwsTargetsTriggers
    size = flex()
    children = lwsTargets.filter(@(t) t != null).map(@(_, i) createLwsTarget(i, colorWatched, isForTank))
  }
}

local rwrTargetsComponent = function(colorWatched) {

  return @() {
    watch = rwrTargetsTriggers
    size = flex()
    children = rwrTargets.filter(@(t) t != null).map(@(_, i) createRwrTarget(i, colorWatched))
  }
}

local function displayAircraftIcon(colorWatched) {
    return centeredAircraftIcon({colorWatched = colorWatched, pos = [0, 0], size = [pw(35), ph(35)] })
}

local function scope(colorWatched, relativCircleRadius, needDrawCentralIcon, scale){
  return {
    size = flex()
    children = [
      twsBackground(colorWatched, !needDrawCentralIcon),
      rwrBackground(colorWatched, scale),
      needDrawCentralIcon ? displayAircraftIcon(colorWatched) : null,
      {
        size = [pw(relativCircleRadius * scale), ph(relativCircleRadius * scale)]
        vplace = ALIGN_CENTER
        hplace = ALIGN_CENTER
        children = [
          mlwsTargetsComponent(colorWatched)
          lwsTargetsComponent(colorWatched, !needDrawCentralIcon)
          rwrTargetsComponent(colorWatched)
        ]
      }
    ]
  }
}

local tws = ::kwarg(function(colorWatched, posWatched, sizeWatched, relativCircleSize = 0, needDrawCentralIcon = true, scale = 1.0) {
  return @() {
    watch = [posWatched, sizeWatched]
    size = sizeWatched.value
    pos = posWatched.value
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = scope(colorWatched, relativCircleSize, needDrawCentralIcon, scale)
  }
})

return tws