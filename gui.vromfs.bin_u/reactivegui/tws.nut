local {rw} = require("style/screenState.nut")
local {rwrTargetsTriggers, lwsTargetsTriggers, mlwsTargetsTriggers, mlwsTargets, lwsTargets, rwrTargets, IsMlwsLwsHudVisible, MlwsLwsSignalHoldTimeInv, RwrSignalHoldTimeInv, IsRwrHudVisible, LastTargetAge, CurrentTime} = require("twsState.nut")
local {MlwsLwsForMfd, RwrForMfd} = require("helicopterState.nut");

local backgroundColor = Color(0, 0, 0, 50)

local indicatorRadius = 70.0
local trackRadarsRadius = 0.04
local azimuthMarkLength = 50 * 3 * trackRadarsRadius

local centeredAircraftIcon = ::kwarg(function(colorStyle, pos = [0, 0], size = flex()) {
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


  local aircraftIcon = colorStyle.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(1) * 2.0
    fillColor = Color(0, 0, 0, 0)
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

  local function getChildren() {
    return [
      colorStyle.__merge({
        rendObj = ROBJ_VECTOR_CANVAS
        size = flex()
        fillColor = Color(0,0,0,0)
        lineWidth = hdpx(1) * LINE_WIDTH
        commands = [
          [VECTOR_ELLIPSE, 50, 50, indicatorRadius * 0.25, indicatorRadius * 0.25]
        ]
      }),
      aircraftIcon
    ]
  }

  return @()
  {
    size = flex()
    children = getChildren()
  }
})

local function createCircle(colorStyle, backGroundColorEnabled, scale = 1.0, isForTank = false) {
  local targetOpacityMult = isForTank ? math.floor((math.sin(CurrentTime.value * 10.0))) : 1.0
  local targetOpacity = max(0.0, 1.0 - min(LastTargetAge.value * MlwsLwsSignalHoldTimeInv.value, 1.0)) * targetOpacityMult
  local targetComponent = colorStyle.__merge({
    rendObj = ROBJ_VECTOR_CANVAS

    lineWidth = hdpx(1) * LINE_WIDTH
    fillColor = backGroundColorEnabled ? backgroundColor : Color(0,0,0,0)
    opacity = targetOpacity
    size = flex()
    commands =
    [
      [VECTOR_ELLIPSE, 50, 50, indicatorRadius * scale, indicatorRadius * scale]
    ]
    })

  return targetComponent
}

local function createAzimuthMark(colorStyle, scale = 1.0, isForTank = false) {
  local targetOpacityMult = isForTank ? math.floor((math.sin(CurrentTime.value * 10.0))) : 1.0
  local targetOpacity = max(0.0, 1.0 - min(LastTargetAge.value * MlwsLwsSignalHoldTimeInv.value, 1.0)) * targetOpacityMult
  local azimuthMarksCommands = []
  const angleGrad = 30.0
  local angle = math.PI * angleGrad / 180.0
  local dashCount = 360.0 / angleGrad
  local innerMarkRadius = indicatorRadius * scale - azimuthMarkLength
  for(local i = 0; i < dashCount; ++i) {
    azimuthMarksCommands.append([
      VECTOR_LINE,
      50 + math.cos(i * angle) * innerMarkRadius,
      50 + math.sin(i * angle) * innerMarkRadius,
      50 + math.cos(i * angle) * indicatorRadius * scale,
      50 + math.sin(i * angle) * indicatorRadius * scale
    ])
  }

  local targetComponent = colorStyle.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(1)
    fillColor = Color(0, 0, 0, 0)
    size = flex()
    opacity = 0.42 * targetOpacity
    commands = azimuthMarksCommands
    })

  return {
    size = flex()
    children = [
      targetComponent
    ]
  }
}

local function twsBackground(colorStyle, isForTank = false) {
  local getTargets = function() {
    local backgroundTargets = []
    backgroundTargets.append(createCircle(colorStyle, true, 1, isForTank))
    backgroundTargets.append(createAzimuthMark(colorStyle, 1, isForTank))
    return backgroundTargets
  }

  return @()
  {
    size = flex()
    watch = [LastTargetAge, IsMlwsLwsHudVisible, MlwsLwsForMfd]
    children = (IsMlwsLwsHudVisible.value || MlwsLwsForMfd.value) ? getTargets() : null
  }
}

local rwrBackground = function(colorStyle, scale) {
  local getTargets = function() {
    local backgroundTargets = []
    backgroundTargets.append(createCircle(colorStyle, !IsMlwsLwsHudVisible.value, scale))
    backgroundTargets.append(createAzimuthMark(colorStyle, scale))
     return backgroundTargets
  }

  return @()
  {
    size = [pw(75), ph(75)]
    pos = [pw(12), ph(12)]
    watch = [LastTargetAge, IsRwrHudVisible,
             RwrForMfd]
    children = (IsRwrHudVisible.value || RwrForMfd.value) ? getTargets() : null
  }
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

local function createMlwsTarget(index, colorStyle) {
  local target = mlwsTargets[index]
  local targetOpacity = max(0.0, 1.0 - min(target.age * MlwsLwsSignalHoldTimeInv.value, 1.0))

  local targetComponent = colorStyle.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    pos = [pw(100), ph(100)]
    size = [pw(50), ph(50)]
    lineWidth = hdpx(1)
    fillColor = Color(0, 0, 0, 0)
    opacity = targetOpacity
    transform = {
      pivot = [0.0, 0.0]
      rotate = 135 //toward center
    }
    commands = rocketVector
    children = colorStyle.__merge({
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = hdpx(1)
      fillColor = backgroundColor
      opacity = targetOpacity
      size = flex()
      commands = target.enemy ? null :
        [[VECTOR_ELLIPSE, 0, 0, 45, 45]]
      })
    })

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

local function createLwsTarget(index, colorStyle, isForTank = false) {
  local target = lwsTargets[index]
  local targetOpacity = max(0.0, 1.0 - min(target.age * MlwsLwsSignalHoldTimeInv.value, 1.0))
  local targetComponent = colorStyle.__merge({
    rendObj = ROBJ_VECTOR_CANVAS

    lineWidth = hdpx(1)
    fillColor = Color(0, 0, 0, 0)
    opacity = targetOpacity
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

    children = colorStyle.__merge({
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = hdpx(1)
      fillColor = backgroundColor
      opacity = targetOpacity
      size = flex()
      commands = target.enemy ? null :
      [[VECTOR_ELLIPSE, 0, 0, 45, 45]]
      })
    })

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

local function createRwrTarget(index, colorStyle) {
  local target = rwrTargets[index]

  local targetOpacity = max(0.0, 1.0 - min(target.age * RwrSignalHoldTimeInv.value, 1.0))

  local trackLine = null

  if (target.track) {
    trackLine = colorStyle.__merge({
      rendObj = ROBJ_VECTOR_CANVAS
      size = [pw(50), ph(50)]
      pos = [pw(100), ph(100)]
      lineWidth = hdpx(1)
      opacity = targetOpacity
      commands = [
        [VECTOR_LINE_DASHED, -135, -135, -80, -80, hdpx(5), hdpx(3)]
      ]
    })
  }

  local targetComponent = colorStyle.__merge({
    rendObj = ROBJ_VECTOR_CANVAS

    lineWidth = hdpx(1)
    fillColor = Color(0, 0, 0, 0)
    opacity = targetOpacity
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

    children = colorStyle.__merge({
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = hdpx(1)
      opacity = targetOpacity
      size = flex()
      commands = target.enemy ? null :
      [[VECTOR_LINE, -20, -40, -20, 40]]
      })
    })

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

local function mlwsTargetsComponent(colorStyle) {
  local function getTargets() {
    local mlwsTargetsRes = []
    for (local i = 0; i < mlwsTargets.len(); ++i) {
      if (!mlwsTargets[i])
        continue
      mlwsTargetsRes.append(createMlwsTarget(i, colorStyle))
    }
    return mlwsTargetsRes
  }

  return @() {
    size = flex()
    children = getTargets()
    watch = mlwsTargetsTriggers
  }
}

local function lwsTargetsComponent(colorStyle, isForTank = false) {
  local function getTargets() {
    local lwsTargetsRes = []
    for (local i = 0; i < lwsTargets.len(); ++i) {
      if (!lwsTargets[i])
        continue
      lwsTargetsRes.append(createLwsTarget(i, colorStyle, isForTank))
    }
    return lwsTargetsRes
  }

  return @() {
    size = flex()
    children = getTargets()
    watch = lwsTargetsTriggers
  }
}

local rwrTargetsComponent = function(colorStyle) {
  local getTargets = function() {
    local targets = []
    for (local i = 0; i < rwrTargets.len(); ++i) {
      if (!rwrTargets[i])
        continue
      targets.append(createRwrTarget(i, colorStyle))
    }
    return targets
  }

  return @() {
    size = flex()
    children = getTargets()
    watch = rwrTargetsTriggers
  }
}

local function displayAircraftIcon(colorStyle) {
  if (IsMlwsLwsHudVisible || IsRwrHudVisible)
    return centeredAircraftIcon({colorStyle = colorStyle, pos = [0, 0], size = [pw(35), ph(35)] })
  return null
}

local function scope(colorStyle, relativCircleRadius, needDrawCentralIcon, scale) {
  return @() {
    size = flex()
    children = [
      twsBackground(colorStyle, !needDrawCentralIcon),
      rwrBackground(colorStyle, scale),
      needDrawCentralIcon ? displayAircraftIcon(colorStyle) : null,
      {
        size = [pw(relativCircleRadius * scale), ph(relativCircleRadius * scale)]
        vplace = ALIGN_CENTER
        hplace = ALIGN_CENTER
        children = [
          mlwsTargetsComponent(colorStyle)
          lwsTargetsComponent(colorStyle, !needDrawCentralIcon)
          rwrTargetsComponent(colorStyle)
        ]
      }
    ]
  }
}

local tws = ::kwarg(function(colorStyle, pos = [rw(75), sh(70)], size = flex(), relativCircleSize = 0, needDrawCentralIcon = true, scale = 1.0) {
  return {
    size = size
    pos = pos
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = scope(colorStyle, relativCircleSize, needDrawCentralIcon, scale)
  }
})

return tws