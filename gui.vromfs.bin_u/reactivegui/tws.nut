local screenState = require("style/screenState.nut")
local interopGen = require("daRg/helpers/interopGen.nut")
local helicopterState = require("helicopterState.nut");

local backgroundColor = Color(0, 0, 0, 50)

local function getFontScale()
{
  return sh(100) / 1080
}

local warningSystemState = {
  IsTwsHudVisible = Watched(false),
  CurrentTime = Watched(0.0),
  mlwsTargets = [],
  mlwsTargetsTriggers = Watched(0),
  SignalHoldTimeInv = Watched(0.0),
  lwsTargets = [],
  lwsTargetsTriggers = Watched(0)
}


::interop.clearMlwsTargets <- function() {
  local needUpdateTargets = false
  for(local i = 0; i < warningSystemState.mlwsTargets.len(); ++i)
  {
    if (warningSystemState.mlwsTargets[i] != null)
    {
      warningSystemState.mlwsTargets[i] = null
      needUpdateTargets = true
    }
  }
  if (needUpdateTargets)
  {
    warningSystemState.mlwsTargetsTriggers.trigger()
  }
}

::interop.clearLwsTargets <- function() {
  local needUpdateTargets = false
  for(local i = 0; i < warningSystemState.lwsTargets.len(); ++i)
  {
    if (warningSystemState.lwsTargets[i] != null)
    {
      warningSystemState.lwsTargets[i] = null
      needUpdateTargets = true
    }
  }
  if (needUpdateTargets)
  {
    warningSystemState.lwsTargetsTriggers.trigger()
  }
}

::interop.updateMlwsTarget <- function(index, x, y, age, enemy) {
  if (index >= warningSystemState.mlwsTargets.len())
    warningSystemState.mlwsTargets.resize(index + 1)
  warningSystemState.mlwsTargets[index] = {
    x = x,
    y = y,
    age = age,
    enemy = enemy
  }
  warningSystemState.mlwsTargetsTriggers.trigger()
}

::interop.updateLwsTarget <- function(index, x, y, age, enemy) {
  if (index >= warningSystemState.lwsTargets.len())
   warningSystemState.lwsTargets.resize(index + 1)
  warningSystemState.lwsTargets[index] = {
    x = x,
    y = y,
    age = age,
    enemy = enemy
  }
  warningSystemState.lwsTargetsTriggers.trigger()
}

interopGen({
  stateTable = warningSystemState
  prefix = "tws"
  postfix = "Update"
})

local indicatorRadius = 70.0
local smallIndicatorRadius = 35.0
local trackRadarsRadius = 0.04
local azimuthMarkLength = 50 * 3 * trackRadarsRadius

local background = function(colorStyle, width, height, is_ground_model) {

  local circle = colorStyle.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [width, height]
    fillColor = backgroundColor
    lineWidth = hdpx(1) * LINE_WIDTH
    commands = [
      [VECTOR_ELLIPSE, 50, 50, indicatorRadius, indicatorRadius]
    ]
  })

  local smallCircle = colorStyle.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [width, height]
    pos = [0,0]
    fillColor = backgroundColor
    lineWidth = hdpx(1) * LINE_WIDTH
    commands = [
      [VECTOR_ELLIPSE, 50, 50, smallIndicatorRadius, smallIndicatorRadius]
    ]
  })

  local tankComponent = colorStyle.__merge({
    rendObj = ROBJ_VECTOR_CANVAS

    lineWidth = hdpx(1)
    fillColor = backgroundColor
    pos = [90,100]
    size = [width * 0.5, height * 0.5]
    commands =
    [
      [VECTOR_LINE, 30, 30, -30, 30],
      [VECTOR_LINE, 30, 30, 30, -25],
      [VECTOR_LINE, -30, 30, -30, -25],
      [VECTOR_LINE, 30, -25, 2.5, -35],
      [VECTOR_LINE, -30, -25, -2.5, -35],
      [VECTOR_LINE, 2.5, -15, 2.5, -60],
      [VECTOR_LINE, -2.5, -15, -2.5, -60],
      [VECTOR_LINE, 2.5, -60, -2.5, -60]
    ]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    })

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

  local azimuthMarks = colorStyle.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(1)
    fillColor = Color(0, 0, 0, 0)
    size = [width, height]
    opacity = 0.42
    commands = azimuthMarksCommands
  })

  return {
    children = is_ground_model ?
    [
      circle
      smallCircle
      azimuthMarks
      tankComponent
    ]
    :
    [
      circle
      azimuthMarks
    ]
  }
}

local function createMlwsTarget(index, colorStyle, width, height)
{
  local target = warningSystemState.mlwsTargets[index]
  local radiusRel =  0.06
  local distMargin = 2.5 * radiusRel
  local radius = radiusRel * width
  local distance = 1.0 - distMargin

  local targetOffsetX = 0.5 + indicatorRadius * 0.01 * target.x * distance
  local targetOffsetY = 0.5 + indicatorRadius * 0.01 * target.y * distance
  local targetOpacity = max(0.0, 1.0 - min(target.age * warningSystemState.SignalHoldTimeInv.value, 1.0))

  local targetComponent = colorStyle.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [2 * radius, 2 * radius]
    lineWidth = hdpx(1)
    fillColor = Color(0, 0, 0, 0)
    opacity = targetOpacity
    commands = target.enemy ?
      [
        [ VECTOR_ELLIPSE, 50, 50, 50, 50 ]
      ]
      :
      [
        [ VECTOR_ELLIPSE, 50, 50, 50, 50 ],
        [ VECTOR_ELLIPSE, 50, 50, 60, 60 ]
      ]
    transform = {
      pivot = [0.5, 0.5]
      translate = [
        targetOffsetX * width - radius,
        targetOffsetY * width - radius
      ]
    }
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = [
      colorStyle.__merge({
        rendObj = ROBJ_STEXT
        size = [0.8 * radius, 0.9 * radius]
        opacity = 0.42
        text = "x"
        font = Fonts.hud
        fontScale = helicopterState.TwsForMfd.value ? 1.5 : getFontScale() * 0.8
      })
    ]
  })

  return {
    size = [width, height]
    children = [
      targetComponent
    ]
  }
}

local function createLwsTarget(index, colorStyle, width, height)
{
  local target = warningSystemState.lwsTargets[index]
  local radiusRel =  0.06
  local distMargin = 2.5 * radiusRel
  local distance = 1.0 - distMargin

  local targetOffsetX = 0.5 + indicatorRadius * 0.01 * target.x * distance
  local targetOffsetY = 0.5 + indicatorRadius * 0.01 * target.y * distance
  local targetOpacity = max(0.0, 1.0 - min(target.age * warningSystemState.SignalHoldTimeInv.value, 1.0))
  
  local targetComponent = colorStyle.__merge({
    rendObj = ROBJ_VECTOR_CANVAS

    lineWidth = hdpx(1)
    fillColor = Color(0, 0, 0, 0)
    opacity = targetOpacity
    size = [width * 0.09, height * 0.09]
    commands = 
    [
      [VECTOR_LINE, -50, 2, 25, 2],
      [VECTOR_LINE, -50, -2, 25, -2],
      [VECTOR_LINE, -50, 2, -50, -2],
      [VECTOR_LINE, 25, 2, 25, -2],
      [VECTOR_LINE, 45, 15, 55, 50],
      [VECTOR_LINE, 45, -15, 55, -50],
      [VECTOR_LINE, 60, 10, 85, 30],
      [VECTOR_LINE, 60, -10, 85, -30],
      [VECTOR_LINE, 35, 15, 25, 50],
      [VECTOR_LINE, 35, -15, 25, -50],
      [VECTOR_LINE, 25, 12, 0, 40],
      [VECTOR_LINE, 25, -12, 0, -40],
      [VECTOR_LINE, 70, 0, 95, 0]
    ]

    transform = {
      pivot = [0.0, 0.0]
      rotate = math.atan2(target.y, target.x) * (180.0 / math.PI) - 180.0
      translate = [
        targetOffsetX * width,
        targetOffsetY * width
      ]
    }
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    })

  return {
    size = [width, height]
    children = [
      targetComponent
    ]
  }
}

local mlwsTargetsComponent = function(colorStyle, width, height)
{
  local getTargets = function() {
    local mlwsTargets = []
    for (local i = 0; i < warningSystemState.mlwsTargets.len(); ++i)
    {
      if (!warningSystemState.mlwsTargets[i])
        continue
      mlwsTargets.append(createMlwsTarget(i, colorStyle, width, height))
    }
    return mlwsTargets
  }

  return @()
  {
    size = [width, height]
    children = getTargets()
    watch = warningSystemState.mlwsTargetsTriggers
  }
}

local lwsTargetsComponent = function(colorStyle, width, height)
{
  local getTargets = function() {
    local lwsTargets = []
    for (local i = 0; i < warningSystemState.lwsTargets.len(); ++i)
    {
      if (!warningSystemState.lwsTargets[i])
        continue
      lwsTargets.append(createLwsTarget(i, colorStyle, width, height))
    }
    return lwsTargets
  }

  return @()
  {
    size = [width, height]
    children = getTargets()
    watch = warningSystemState.lwsTargetsTriggers
  }
}


local scope = function(colorStyle, width, height, is_ground_model)
{
  return {
    children = [
      {
        size = SIZE_TO_CONTENT
        children = [
          background(colorStyle, width, height, is_ground_model)
          mlwsTargetsComponent(colorStyle, width, height)
          lwsTargetsComponent(colorStyle, width, height)
        ]
      }
    ]
  }
}

local tws = function(colorStyle, posX = screenState.rw(75), posY = sh(70), w = sh(20), h = sh(20), for_mfd = false, is_ground_model = false)
{
  local getChildren = function() {
    return (!for_mfd && warningSystemState.IsTwsHudVisible.value) || (for_mfd && helicopterState.TwsForMfd.value) ? [
      scope(colorStyle, w, h, is_ground_model)
    ] : null
  }
  return @(){
    pos = [(for_mfd ? 0 : screenState.safeAreaSizeHud.value.borders[1]) + posX, posY]
    size = SIZE_TO_CONTENT
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    watch = warningSystemState.IsTwsHudVisible
    children = getChildren()
  }
}

return tws