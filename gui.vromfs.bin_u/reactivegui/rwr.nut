local screenState = require("style/screenState.nut")
local interopGen = require("daRg/helpers/interopGen.nut")
local helicopterState = require("helicopterState.nut");

local backgroundColor = Color(0, 0, 0, 50)

local aircraftWidthFactor = 0.20
local aircraftHeightFactor = 0.25
local aircraftRadiusFactor = 0.3

local function getFontScale()
{
  return sh(100) / 1080
}

local rwrState = {
  IsRwrHudVisible = Watched(false),
  CurrentTime = Watched(0.0),
  targets = [],
  TargetsTrigger = Watched(0),
  trackingTargetAgeMin = 1000.0,
  SignalHoldTimeInv = Watched(0.0),
  EnableBackGroundColor = Watched(false)
}

::interop.clearRwrTargets <- function() {
  local needUpdateTargets = false
  for(local i = 0; i < rwrState.targets.len(); ++i)
  {
    if (rwrState.targets[i] != null)
    {
      rwrState.targets[i] = null
      needUpdateTargets = true
    }
  }

  if (needUpdateTargets)
  {
    rwrState.trackingTargetAgeMin = 1000.0
    rwrState.TargetsTrigger.trigger()
  }
}

::interop.updateRwrTarget <- function(index, x, y, age, track, enemy) {
  if (index >= rwrState.targets.len())
    rwrState.targets.resize(index + 1)
  rwrState.targets[index] = {
    x = x,
    y = y,
    age = age,
    track = track,
    enemy = enemy
  }
  rwrState.TargetsTrigger.trigger()
  if (track)
    rwrState.trackingTargetAgeMin = min(rwrState.trackingTargetAgeMin, age)
}

interopGen({
  stateTable = rwrState
  prefix = "rwr"
  postfix = "Update"
})

local trackRadarsRadius = 0.04
local trackRadarsDistMargin = 6 * trackRadarsRadius

local background = function(colorStyle, width, height) {

  local aircraftW = width * aircraftRadiusFactor
  local aircraftH = height * aircraftRadiusFactor

  local getAircraftCircleOpacity = function() {
    local opacity = 0.42
    if (rwrState.trackingTargetAgeMin * rwrState.SignalHoldTimeInv.value < 1.0)
      opacity = math.round(rwrState.CurrentTime.value * 4) % 2 == 0 ? 1.0 : 0.42
    return opacity
  }

  local aircraftCircle = @() colorStyle.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(1) * 2.0
    fillColor = Color(0, 0, 0, 0)
    size = [aircraftW, aircraftH]
    pos = [0.5 * width - 0.5 * aircraftW,  0.5 * height - 0.5 * aircraftH]
    commands = [
      [VECTOR_ELLIPSE, 50, 50, 50, 50]
    ]
    behavior = Behaviors.RtPropUpdate
    update = function() {
      return {
        opacity = getAircraftCircleOpacity()
      }
    }
  })

  local aircraftWidth = width * aircraftWidthFactor
  local aircraftHeight = height * aircraftHeightFactor

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
    size = [aircraftWidth, aircraftHeight]
    pos = [0.5 * width - 0.5 * aircraftWidth,  0.5 * height - 0.5 * aircraftHeight]
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

  local azimuthMarksCommands = []
  const angleGrad = 30.0
  local angle = math.PI * angleGrad / 180.0
  local dashCount = 360.0 / angleGrad
  local outerRadius = 50 * (1.0 - trackRadarsDistMargin + 3 * trackRadarsRadius)
  for(local i = 0; i < dashCount; ++i)
  {
    azimuthMarksCommands.append([
      VECTOR_LINE,
      50 + math.cos(i * angle) * outerRadius,
      50 + math.sin(i * angle) * outerRadius,
      50 + math.cos(i * angle) * 50.0,
      50 + math.sin(i * angle) * 50.0
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

  local getChildren = function() {
    return [
      colorStyle.__merge({
        rendObj = ROBJ_VECTOR_CANVAS
        size = [width, height]
        fillColor = rwrState.EnableBackGroundColor.value ? backgroundColor : Color(0, 0, 0, 0)
        lineWidth = hdpx(1) * LINE_WIDTH
        commands = [
          [VECTOR_ELLIPSE, 50, 50, 50, 50]
        ]
      }),
      aircraftCircle,
      aircraftIcon,
      azimuthMarks
    ]
  }

  return @()
  {
    children = getChildren()
    watch = rwrState.EnableBackGroundColor
  }
}

local function getTrackLineCoords(aircraftRectWidth, aircraftRectHeight, targetX, targetY, targetRadius)
{
  local p1 = {
    x = 50
    y = 50
  }

  local p2 = {
    x = targetX
    y = targetY
  }

  local resPoint1 = {
    x = 0
    y = 0
  }

  local resPoint2 = {
    x = 0
    y = 0
  }

  local x0 = p1.x
  local y0 = p1.y
  local kx = p2.x - p1.x
  local ky = p2.y - p1.y

  local t = 0

  while (t == 0)
  {
    if (ky != 0)
    {
      // up
      local Y = 50 - aircraftRectHeight * 0.5
      t = (Y - y0) / ky
      local X = kx * t + x0
      if (t > 0 && t < 1
        && X >= 50 - aircraftRectWidth * 0.5
        && X <= 50 + aircraftRectWidth * 0.5)
        break
      // down
      Y = 50 + aircraftRectHeight * 0.5
      t = (Y - y0) / ky
      X = kx * t + x0
      if (t > 0 && t < 1
        && X >= 50 - aircraftRectWidth * 0.5
        && X <= 50 + aircraftRectWidth * 0.5)
        break
    }
    if (kx != 0)
    {
      // left
      local X = 50 - aircraftRectWidth * 0.5
      t = (X - x0) / kx
      if (t > 0 && t < 1)
        break
      // right
      X = 50 + aircraftRectWidth * 0.5
      t = (X - x0) / kx
      if (t > 0 && t < 1)
        break
    }

    t = 0.5
  }

  resPoint1.x = kx * t + x0
  resPoint1.y = ky * t + y0

  local vecDx = p2.x - resPoint1.x
  local vecDy = p2.y - resPoint1.y
  local vecLength = math.sqrt(vecDx * vecDx + vecDy * vecDy)
  local vecNorm = {
    x = vecLength > 0 ? vecDx / vecLength : 0
    y = vecLength > 0 ? vecDy / vecLength : 0
  }

  resPoint2.x = resPoint1.x + vecNorm.x * (vecLength - targetRadius)
  resPoint2.y = resPoint1.y + vecNorm.y * (vecLength - targetRadius)

  return [resPoint1, resPoint2]
}


local function createTarget(index, colorStyle, width, height)
{
  local target = rwrState.targets[index]
  local radiusRel =  0.06
  local distMargin = 4.5 * radiusRel
  local radius = radiusRel * width
  local distance = 1.0 - distMargin

  local targetOffsetX = 0.5 + 0.5 * target.x * distance
  local targetOffsetY = 0.5 + 0.5 * target.y * distance
  local targetOpacity = max(0.0, 1.0 - min(target.age * rwrState.SignalHoldTimeInv.value, 1.0))

  local trackLine = null

  if (target.track)
  {
    local trackLineCoords = getTrackLineCoords(
      aircraftRadiusFactor * 100.0, aircraftRadiusFactor * 100.0,
      targetOffsetX * 100.0, targetOffsetY * 100.0,
      radiusRel * 100.0)

    trackLine = colorStyle.__merge({
      rendObj = ROBJ_VECTOR_CANVAS
      size = [width, height]
      lineWidth = hdpx(1)
      opacity = targetOpacity
      commands = [
        [VECTOR_LINE_DASHED, trackLineCoords[0].x, trackLineCoords[0].y, trackLineCoords[1].x, trackLineCoords[1].y, hdpx(10), hdpx(5)]
      ]
    })
  }

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
        targetOffsetY * height - radius
      ]
    }
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = [
      colorStyle.__merge({
        rendObj = ROBJ_STEXT
        size = [0.8 * radius, 0.9 * radius]
        opacity = 0.42
        text = ::loc("hud/radarEmitting")
        font = Fonts.hud
        fontScale = helicopterState.RwrForMfd.value ? 1.5 : getFontScale() * 0.8
      })
    ]
  })

  return {
    size = [width, height]
    children = [
      targetComponent,
      trackLine
    ]
  }
}

local targetsComponent = function(colorStyle, width, height)
{
  local getTargets = function() {
    local targets = []
    for (local i = 0; i < rwrState.targets.len(); ++i)
    {
      if (!rwrState.targets[i])
        continue
      targets.append(createTarget(i, colorStyle, width, height))
    }
    return targets
  }

  return @()
  {
    size = [width, height]
    children = getTargets()
    watch = rwrState.TargetsTrigger
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

local rwr = function(colorStyle, posX = screenState.rw(75), posY = sh(70), w = sh(20), h = sh(20), for_mfd = false)
{
  local getChildren = function() {
    return (!for_mfd && rwrState.IsRwrHudVisible.value) || (for_mfd && helicopterState.RwrForMfd.value) ? [
      scope(colorStyle, w, h)
    ] : null
  }
  return @(){
    pos = [(for_mfd ? 0 : screenState.safeAreaSizeHud.value.borders[1]) + posX, posY]
    size = SIZE_TO_CONTENT
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    watch = rwrState.IsRwrHudVisible
    children = getChildren()
  }
}

return rwr