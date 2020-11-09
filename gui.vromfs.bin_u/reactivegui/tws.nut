local screenState = require("style/screenState.nut")
local warningSystemState = require("twsState.nut")
local helicopterElem = require("helicopterHudElems.nut");

local backgroundColor = Color(0, 0, 0, 50)

local indicatorRadius = 70.0
local trackRadarsRadius = 0.04
local azimuthMarkLength = 50 * 3 * trackRadarsRadius

local function createCircle(colorStyle)
{
  local targetOpacity = max(0.0, 1.0 - min(warningSystemState.LastTargetAge.value * warningSystemState.SignalHoldTimeInv.value, 1.0))
  local targetComponent = colorStyle.__merge({
    rendObj = ROBJ_VECTOR_CANVAS

    lineWidth = hdpx(1) * LINE_WIDTH
    fillColor = backgroundColor
    opacity = targetOpacity
    size = flex()
    commands =
    [
      [VECTOR_ELLIPSE, 50, 50, indicatorRadius, indicatorRadius]
    ]
    })

  return targetComponent
}

local function createAzimuthMark(colorStyle)
{
  local targetOpacity = max(0.0, 1.0 - min(warningSystemState.LastTargetAge.value * warningSystemState.SignalHoldTimeInv.value, 1.0))
  local azimuthMarksCommands = []
  const angleGrad = 30.0
  local angle = math.PI * angleGrad / 180.0
  local dashCount = 360.0 / angleGrad
  local innerMarkRadius = indicatorRadius - azimuthMarkLength
  for(local i = 0; i < dashCount; ++i)
  {
    azimuthMarksCommands.append([
      VECTOR_LINE,
      50 + math.cos(i * angle) * innerMarkRadius,
      50 + math.sin(i * angle) * innerMarkRadius,
      50 + math.cos(i * angle) * indicatorRadius,
      50 + math.sin(i * angle) * indicatorRadius
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

local function background(colorStyle) {
  local getTargets = function() {
    local backgroundTargets = []
    backgroundTargets.append(createCircle(colorStyle))
    backgroundTargets.append(createAzimuthMark(colorStyle))
    backgroundTargets.append(helicopterElem.aircraftIcon({
      colorStyle = colorStyle,
      pos = [0, 0],
      size = [pw(33), ph(33)]
    }))
     return backgroundTargets
  }

  return @()
  {
    size = flex()
    watch = warningSystemState.LastTargetAge
    children = getTargets()
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

local function createMlwsTarget(index, colorStyle)
{
  local target = warningSystemState.mlwsTargets[index]
  local targetOpacity = max(0.0, 1.0 - min(target.age * warningSystemState.SignalHoldTimeInv.value, 1.0))

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

local function createLwsTarget(index, colorStyle)
{
  local target = warningSystemState.lwsTargets[index]
  local targetOpacity = max(0.0, 1.0 - min(target.age * warningSystemState.SignalHoldTimeInv.value, 1.0))
  local targetComponent = colorStyle.__merge({
    rendObj = ROBJ_VECTOR_CANVAS

    lineWidth = hdpx(1)
    fillColor = Color(0, 0, 0, 0)
    opacity = targetOpacity
    size = [pw(50), ph(50)]
    pos = [pw(100), ph(100)]
    commands =
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

local function mlwsTargetsComponent(colorStyle)
{
  local function getTargets() {
    local mlwsTargets = []
    for (local i = 0; i < warningSystemState.mlwsTargets.len(); ++i)
    {
      if (!warningSystemState.mlwsTargets[i])
        continue
      mlwsTargets.append(createMlwsTarget(i, colorStyle))
    }
    return mlwsTargets
  }

  return @()
  {
    size = flex()
    children = getTargets()
    watch = warningSystemState.mlwsTargetsTriggers
  }
}

local function lwsTargetsComponent(colorStyle)
{
  local function getTargets() {
    local lwsTargets = []
    for (local i = 0; i < warningSystemState.lwsTargets.len(); ++i)
    {
      if (!warningSystemState.lwsTargets[i])
        continue
      lwsTargets.append(createLwsTarget(i, colorStyle))
    }
    return lwsTargets
  }

  return @()
  {
    size = flex()
    children = getTargets()
    watch = warningSystemState.lwsTargetsTriggers
  }
}


local function scope(colorStyle, relativCircleRadius)
{
  return {
    size = flex()
    children = [
      background(colorStyle)
      {
        size = [pw(relativCircleRadius), ph(relativCircleRadius)]
        vplace = ALIGN_CENTER
        hplace = ALIGN_CENTER
        children = [
          mlwsTargetsComponent(colorStyle)
          lwsTargetsComponent(colorStyle)
        ]
      }
    ]
  }
}

local tws = ::kwarg(function(colorStyle, pos = [screenState.rw(75), sh(70)], size = flex(), relativCircleSize = 0)
{
  return {
    size = size
    pos = pos
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = scope(colorStyle, relativCircleSize)
  }
})

return tws