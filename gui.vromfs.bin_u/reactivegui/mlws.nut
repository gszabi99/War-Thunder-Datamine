local screenState = require("style/screenState.nut")
local interopGen = require("daRg/helpers/interopGen.nut")
local helicopterState = require("helicopterState.nut");

local backgroundColor = Color(0, 0, 0, 50)

local function getFontScale()
{
  return sh(100) / 1080
}

local mlwsState = {
  IsMlwsHudVisible = Watched(false),
  CurrentTime = Watched(0.0),
  targets = [],
  TargetsTrigger = Watched(0),
  SignalHoldTimeInv = Watched(0.0)
}

::interop.clearMlwsTargets <- function() {
  local needUpdateTargets = false
  for(local i = 0; i < mlwsState.targets.len(); ++i)
  {
    if (mlwsState.targets[i] != null)
    {
      mlwsState.targets[i] = null
      needUpdateTargets = true
    }
  }
  if (needUpdateTargets)
  {
    mlwsState.TargetsTrigger.trigger()
  }
}

::interop.updateMlwsTarget <- function(index, x, y, age, enemy) {
  if (index >= mlwsState.targets.len())
    mlwsState.targets.resize(index + 1)
  mlwsState.targets[index] = {
    x = x,
    y = y,
    age = age,
    enemy = enemy
  }
  mlwsState.TargetsTrigger.trigger()
}

interopGen({
  stateTable = mlwsState
  prefix = "mlws"
  postfix = "Update"
})

local indicatorRadius = 70.0
local trackRadarsRadius = 0.04
local azimuthMarkLength = 50 * 3 * trackRadarsRadius

local background = function(colorStyle, width, height) {

  local circle = colorStyle.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [width, height]
    fillColor = backgroundColor
    lineWidth = hdpx(1) * LINE_WIDTH
    commands = [
      [VECTOR_ELLIPSE, 50, 50, indicatorRadius, indicatorRadius]
    ]
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
    children = [
      circle
      azimuthMarks
    ]
  }
}

local function createTarget(index, colorStyle, width, height)
{
  local target = mlwsState.targets[index]
  local radiusRel =  0.06
  local distMargin = 2.5 * radiusRel
  local radius = radiusRel * width
  local distance = 1.0 - distMargin

  local targetOffsetX = 0.5 + indicatorRadius * 0.01 * target.x * distance
  local targetOffsetY = 0.5 + indicatorRadius * 0.01 * target.y * distance
  local targetOpacity = max(0.0, 1.0 - min(target.age * mlwsState.SignalHoldTimeInv.value, 1.0))

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
        fontScale = helicopterState.MlwsForMfd.value ? 1.5 : getFontScale() * 0.8
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

local targetsComponent = function(colorStyle, width, height)
{
  local getTargets = function() {
    local targets = []
    for (local i = 0; i < mlwsState.targets.len(); ++i)
    {
      if (!mlwsState.targets[i])
        continue
      targets.append(createTarget(i, colorStyle, width, height))
    }
    return targets
  }

  return @()
  {
    size = [width, height]
    children = getTargets()
    watch = mlwsState.TargetsTrigger
  }
}

local scope = function(colorStyle, width, height)
{
  return {
    children = [
      {
        size = SIZE_TO_CONTENT
        children = [
          background(colorStyle, width, height)
          targetsComponent(colorStyle, width, height)
        ]
      }
    ]
  }
}

local mlws = function(colorStyle, posX = screenState.rw(75), posY = sh(70), w = sh(20), h = sh(20), for_mfd = false)
{
  local getChildren = function() {
    return (!for_mfd && mlwsState.IsMlwsHudVisible.value) || (for_mfd && helicopterState.MlwsForMfd.value) ? [
      scope(colorStyle, w, h)
    ] : null
  }
  return @(){
    pos = [(for_mfd ? 0 : screenState.safeAreaSizeHud.value.borders[1]) + posX, posY]
    size = SIZE_TO_CONTENT
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    watch = mlwsState.IsMlwsHudVisible
    children = getChildren()
  }
}

return mlws