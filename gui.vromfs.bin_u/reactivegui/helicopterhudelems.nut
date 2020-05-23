local math = require("std/math.nut")
local helicopterState = require("helicopterState.nut")
local aamAimState = require("rocketAamAimState.nut")
local compass = require("compass.nut")

local backgroundColor = Color(0, 0, 0, 150)

const NUM_ENGINES_MAX = 3
const NUM_TRANSMISSIONS_MAX = 6

local getColor = function(isBackground, line_style){
  return isBackground ? backgroundColor : line_style.color
}

enum GuidanceLockResult {
  RESULT_INVALID = -1
  RESULT_STANDBY = 0
  RESULT_WARMING_UP = 1
  RESULT_LOCKING = 2
  RESULT_TRACKING = 3
  RESULT_LOCK_AFTER_LAUNCH = 4
}

local verticalSpeedInd = function(line_style, height, isBackground) {
  return @() line_style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [height, height]
    pos = [0, -height*0.25]
    commands = [
      [VECTOR_LINE, 0, 25, 100, 50, 100, 0, 0, 25],
    ]
  })
}

local verticalSpeedScale = function(line_style, width, height, isBackground) {
  local part1_16 = 0.0625 * 100
  local lineStart = 70

  return @() line_style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [width, height]
    halign = ALIGN_RIGHT
    commands = [
      [VECTOR_LINE, 0,         0,           100, 0],
      [VECTOR_LINE, lineStart, part1_16,    100, part1_16],
      [VECTOR_LINE, lineStart, 2*part1_16,  100, 2*part1_16],
      [VECTOR_LINE, lineStart, 3*part1_16,  100, 3*part1_16],
      [VECTOR_LINE, 0,         25,          100, 25],
      [VECTOR_LINE, lineStart, 5*part1_16,  100, 5*part1_16],
      [VECTOR_LINE, lineStart, 6*part1_16,  100, 6*part1_16],
      [VECTOR_LINE, lineStart, 7*part1_16,  100, 7*part1_16],
      [VECTOR_LINE, 0,         50,          100, 50],
      [VECTOR_LINE, lineStart, 9*part1_16,  100, 9*part1_16],
      [VECTOR_LINE, lineStart, 10*part1_16, 100, 10*part1_16],
      [VECTOR_LINE, lineStart, 11*part1_16, 100, 11*part1_16],
      [VECTOR_LINE, 0,         75,          100, 75],
      [VECTOR_LINE, lineStart, 13*part1_16, 100, 13*part1_16],
      [VECTOR_LINE, lineStart, 14*part1_16, 100, 14*part1_16],
      [VECTOR_LINE, lineStart, 15*part1_16, 100, 15*part1_16],
      [VECTOR_LINE, 0,         100,         100, 100],
    ]
  })
}

local HelicopterVertSpeed = function(elemStyle, scaleWidth, height, posX, posY, isBackground) {

  local getRelativeHeight = @() ::clamp(helicopterState.DistanceToGround.value * 2.0, 0, 100)

  return {
    pos = [posX, posY]
    children = [
      {
        children = verticalSpeedScale(elemStyle, scaleWidth, height, isBackground)
      }
      {
        valign = ALIGN_BOTTOM
        halign = ALIGN_RIGHT
        size = [scaleWidth, height]
        children = @() elemStyle.__merge({
          rendObj = ROBJ_VECTOR_CANVAS
          pos = [LINE_WIDTH, 0]
          size = [LINE_WIDTH, height]
          tmpHeight = 0
          watch = helicopterState.DistanceToGround
          opacity = helicopterState.DistanceToGround.value > 50.0 ? 0 : 100
          commands = [[VECTOR_RECTANGLE, 0, 100 - getRelativeHeight(), 100, getRelativeHeight()]]
        })
      }
      {
        halign = ALIGN_RIGHT
        valign = ALIGN_CENTER
        size = [-0.5*scaleWidth, height]
        children = @() elemStyle.__merge({
          rendObj = ROBJ_DTEXT
          halign = ALIGN_RIGHT
          size = [scaleWidth*4,SIZE_TO_CONTENT]
          watch = helicopterState.DistanceToGround
          text = helicopterState.IsMfdEnabled.value ? ::math.floor(helicopterState.DistanceToGround.value).tostring() :
            ::cross_call.measureTypes.ALTITUDE.getMeasureUnitsText(helicopterState.DistanceToGround.value)
        })
      }
      @(){
        watch = helicopterState.VerticalSpeed
        pos = [scaleWidth + sh(0.5), 0]
        transform = {
          translate = [0, height * 0.01 * clamp(50 - helicopterState.VerticalSpeed.value * 5.0, 0, 100)]
        }
        children = [
          verticalSpeedInd(elemStyle, hdpx(25), isBackground),
          {
            pos = [scaleWidth + hdpx(10), hdpx(-10)]
            children = @() elemStyle.__merge({
              rendObj = ROBJ_DTEXT
              size = [scaleWidth*4,SIZE_TO_CONTENT]
              watch = helicopterState.VerticalSpeed
              text = helicopterState.IsMfdEnabled.value ?
                math.round_by_value(helicopterState.VerticalSpeed.value, 1).tostring() :
                ::cross_call.measureTypes.CLIMBSPEED.getMeasureUnitsText(helicopterState.VerticalSpeed.value)
            })
          }
        ]
      }
    ]
  }
}

local generateBulletsTextFunction = function(countWatched, secondsWatched) {
  return function() {
    local str = ""
    if (secondsWatched.value >= 0)
    {
      str = ::string.format("%d:%02d", ::math.floor(secondsWatched.value / 60), secondsWatched.value % 60)
      if (countWatched.value > 0)
        str += " (" + countWatched.value + ")"
      return str
    }
    else if (countWatched.value >= 0)
      str = countWatched.value
    return str
  }
}

local generateAgmBulletsTextFunction = function(countWatched, secondsWatched, timeToHit, timeToWarning) {
  return function() {
    local str = ""
    if (secondsWatched.value >= 0)
    {
      str = ::string.format("%d:%02d", ::math.floor(secondsWatched.value / 60), secondsWatched.value % 60)
      if (countWatched.value > 0)
        str += " (" + countWatched.value + ")"
      return str
    }
    else if (countWatched.value >= 0)
      str = countWatched.value

    if (timeToHit.value > 0)
      str = str + ::string.format("[%d]", timeToHit.value)
    return str
  }
}

local generateTemperatureTextFunction = function(temperatureWatched, stateWatched) {
  return function() {
    if (stateWatched.value == TemperatureState.OVERHEAT)
      return temperatureWatched.value + ::cross_call.measureTypes.TEMPERATURE.getMeasureUnitsName()
    else if (stateWatched.value == TemperatureState.EMPTY_TANK)
      return ::loc("HUD_TANK_IS_EMPTY")
    else if (stateWatched.value == TemperatureState.FUEL_LEAK)
      return ::loc("HUD_FUEL_LEAK")
    else if (stateWatched.value == TemperatureState.BLANK)
      return ""

    return ""
  }
}

local generateTransmissionStateTextFunction = function(oilWatched) {
  return function() {
    if(oilWatched.value > 0.01)
      return ::loc("HUD_FUEL_LEAK")
    else
    return ::loc("HUD_TANK_IS_EMPTY")

    return ""
  }
}

local getThrottleText = function() {

  if ( helicopterState.TrtMode.value == HelicopterThrottleMode.DEFAULT_MODE
    || helicopterState.TrtMode.value == HelicopterThrottleMode.CLIMB)
    return helicopterState.Trt.value + "%"
  else if (helicopterState.TrtMode.value == HelicopterThrottleMode.BRAKE)
    return ::loc("HUD/BRAKE_SHORT")
  else if (helicopterState.TrtMode.value == HelicopterThrottleMode.WEP)
    return ::loc("HUD/WEP_SHORT")

  return ""
}


local getThrottleCaption = function() {
  return (helicopterState.TrtMode.value == HelicopterThrottleMode.CLIMB)
    ? ::loc("HUD/CLIMB_SHORT")
    : ::loc("HUD/PROP_PITCH_SHORT")
}

local getAGCaption = function() {
  local text = ""
  if (helicopterState.AgmGuidanceLockState.value == GuidanceLockResult.RESULT_INVALID)
    text = ::loc("HUD/TXT_AGM_SHORT")
  else if (helicopterState.AgmGuidanceLockState.value == GuidanceLockResult.RESULT_STANDBY)
    text = ::loc("HUD/TXT_AGM_STANDBY")
  else if (helicopterState.AgmGuidanceLockState.value == GuidanceLockResult.RESULT_WARMING_UP)
    text = ::loc("HUD/TXT_AGM_WARM_UP")
  else if (helicopterState.AgmGuidanceLockState.value == GuidanceLockResult.RESULT_LOCKING)
    text = ::loc("HUD/TXT_AGM_LOCK")
  else if (helicopterState.AgmGuidanceLockState.value == GuidanceLockResult.RESULT_TRACKING)
    text = ::loc("HUD/TXT_AGM_TRACK")
  else if (helicopterState.AgmGuidanceLockState.value == GuidanceLockResult.RESULT_LOCK_AFTER_LAUNCH)
    text = ::loc("HUD/TXT_AGM_LOCK_AFTER_LAUNCH")
  return text
}

local getAACaption = function() {
  local text = ""
  if (aamAimState.GuidanceLockState.value == GuidanceLockResult.RESULT_INVALID)
    text = ::loc("HUD/TXT_AAM_SHORT")
  else if (aamAimState.GuidanceLockState.value == GuidanceLockResult.RESULT_STANDBY)
    text = ::loc("HUD/TXT_AAM_STANDBY")
  else if (aamAimState.GuidanceLockState.value == GuidanceLockResult.RESULT_WARMING_UP)
    text = ::loc("HUD/TXT_AAM_WARM_UP")
  else if (aamAimState.GuidanceLockState.value == GuidanceLockResult.RESULT_LOCKING)
    text = ::loc("HUD/TXT_AAM_LOCK")
  else if (aamAimState.GuidanceLockState.value == GuidanceLockResult.RESULT_TRACKING)
    text = ::loc("HUD/TXT_AAM_TRACK")
  else if (aamAimState.GuidanceLockState.value == GuidanceLockResult.RESULT_LOCK_AFTER_LAUNCH)
    text = ::loc("HUD/TXT_AAM_LOCK_AFTER_LAUNCH")
  return text
}

local getFlaresCaption = function() {
  local text = ::loc("HUD/FLARES_SHORT")
  if (helicopterState.Flares.mode.value & FlaresMode.PERIODIC_FLARES)
    text += " " + ::loc("HUD/FLARE_PERIODIC")
  if (helicopterState.Flares.mode.value == (FlaresMode.PERIODIC_FLARES | FlaresMode.MLWS_SLAVED_FLARES))
    text += ::loc("HUD/FLARE_MODE_SEPARATION")
  if (helicopterState.Flares.mode.value & FlaresMode.MLWS_SLAVED_FLARES)
    text += " " + ::loc("HUD/FLARE_MLWS")
  return text
}

local function isInsideAgmLaunchAngularRange() {
  return helicopterState.IsInsideLaunchZoneYawPitch.value
}

local function isInsideAgmLaunchDistanceRange() {
  return helicopterState.IsInsideLaunchZoneDist.value
}

local getAGBlink = function()
{
  if (helicopterState.IsSightHudVisible.value && helicopterState.IsAgmLaunchZoneVisible.value &&
       (
         !isInsideAgmLaunchAngularRange() || (helicopterState.IsRangefinderEnabled.value && !isInsideAgmLaunchDistanceRange())
       ) )
    return math.round(helicopterState.CurrentTime.value * 4) % 2 == 0 ? 100 : 0
  else
    return 100
}

local getTurretBlink = function()
{
  return !helicopterState.GunInDeadZone.value ? 100 : math.round(helicopterState.CurrentTime.value * 4) % 2 == 0 ? 100 : 0
}

local getAGBulletsBlink = function()
{
  if (helicopterState.Agm.timeToHit.value > 0 && helicopterState.Agm.timeToWarning.value <= 0)
    return math.round(helicopterState.CurrentTime.value * 4) % 2 == 0 ? 100 : 0
  else
    return 100
}

local getAGBullets = generateAgmBulletsTextFunction(helicopterState.Agm.count, helicopterState.Agm.seconds, helicopterState.Agm.timeToHit, helicopterState.Agm.timeToWarning)

local getAABullets = generateBulletsTextFunction(helicopterState.Aam.count, helicopterState.Aam.seconds)

local createHelicopterParam = function(param, width, line_style, isBackground, needCaption = true, for_ils = false)
{
  local rowHeight = for_ils ? 50 : hdpx(28)

  local selectColor = function(){
    return param?.alertWatched && param.alertWatched[0].value && !isBackground
      ? helicopterState.AlertColor.value
      : getColor(isBackground, line_style)
  }

  local captionComponent = @() line_style.__merge({
    rendObj = ROBJ_DTEXT
    size = [0.4*width, rowHeight]
    text = param.title()
    watch = (param?.alertWatched ? param.alertWatched : []).extend(param?.titleWatched ? param.titleWatched : [])
    color = selectColor()
  })

  return function() {
    return {
      size = SIZE_TO_CONTENT
      flow = FLOW_HORIZONTAL
      behavior = param?.blink ? Behaviors.RtPropUpdate : null
      update = function() {
        return {
          opacity = param.blink() ? 100 : 0
        }
      }
      children = [
        (needCaption ? captionComponent : null)
        @() line_style.__merge({
          color = selectColor()
          rendObj = ROBJ_DTEXT
          size = [0.6*width, rowHeight]
          text = param.value()
          watch = param.valuesWatched
          behavior = param?.valueBlink ? Behaviors.RtPropUpdate : null
          update = function() {
            return {
              opacity = param.valueBlink() ? 100 : 0
            }
          }
        })
      ]
    }
  }
}

local textParamsMap = {
  [HelicopterParams.RPM] = {
    title = @() ::loc("HUD/PROP_RPM_SHORT")
    value = @() helicopterState.Rpm.value + "%"
    valuesWatched = [helicopterState.Rpm, helicopterState.IsRpmCritical]
    alertWatched = [helicopterState.IsRpmCritical]
  },
  [HelicopterParams.THROTTLE] = {
    title = @() getThrottleCaption()
    value = @() getThrottleText()
    titleWatched = [helicopterState.TrtMode]
    valuesWatched = [helicopterState.Trt, helicopterState.TrtMode]
  },
  [HelicopterParams.SPEED] = {
    title = @() ::loc("HUD/REAL_SPEED_SHORT")
    value = @() helicopterState.Spd.value + " " + ::cross_call.measureTypes.SPEED.getMeasureUnitsName()
    valuesWatched = helicopterState.Spd
  },
  [HelicopterParams.MACHINE_GUN] = {
    title = @() ::loc("HUD/MACHINE_GUNS_SHORT")
    value = generateBulletsTextFunction(helicopterState.MachineGuns.count, helicopterState.MachineGuns.seconds)
    valuesWatched = [helicopterState.MachineGuns.count, helicopterState.MachineGuns.seconds, helicopterState.IsMachineGunEmpty]
    alertWatched = [helicopterState.IsMachineGunEmpty]
  },
  [HelicopterParams.CANNON_ADDITIONAL] = {
    title = @() ::loc("HUD/ADDITIONAL_GUNS_SHORT")
    value = generateBulletsTextFunction(helicopterState.CannonsAdditional.count, helicopterState.CannonsAdditional.seconds)
    valuesWatched = [
      helicopterState.CannonsAdditional.count,
      helicopterState.CannonsAdditional.seconds,
      helicopterState.IsCanAdditionalEmpty
    ]
    alertWatched = [helicopterState.IsCanAdditionalEmpty]
  },
  [HelicopterParams.ROCKET] = {
    title = @() ::loc("HUD/RKT")
    value = generateBulletsTextFunction(helicopterState.Rockets.count, helicopterState.Rockets.seconds)
    valuesWatched = [helicopterState.Rockets.count, helicopterState.Rockets.seconds, helicopterState.IsRktEmpty]
    alertWatched = [helicopterState.IsRktEmpty]
  },
  [HelicopterParams.AGM] = {
    title = @() getAGCaption()
    value = @() getAGBullets()
    blink = @() getAGBlink()
    titleWatched = [
      helicopterState.AgmGuidanceLockState,
      helicopterState.IsSightHudVisible, helicopterState.IsAgmLaunchZoneVisible, helicopterState.IsAgmLaunchZoneVisible,
      helicopterState.IsInsideLaunchZoneYawPitch, helicopterState.IsInsideLaunchZoneDist
    ]
    valueBlink = @() getAGBulletsBlink()
    valuesWatched = [
      helicopterState.IsSightHudVisible, helicopterState.IsAgmLaunchZoneVisible, helicopterState.IsAgmLaunchZoneVisible,
      helicopterState.Agm.count, helicopterState.Agm.seconds, helicopterState.Agm.timeToHit, helicopterState.Agm.timeToWarning,
      helicopterState.IsAgmEmpty, helicopterState.AgmGuidanceLockState
    ]
    alertWatched = [helicopterState.IsAgmEmpty]
  },
  [HelicopterParams.BOMBS] = {
    title = @() ::loc("HUD/BOMBS_SHORT")
    value = generateBulletsTextFunction(helicopterState.Bombs.count, helicopterState.Bombs.seconds)
    valuesWatched = [helicopterState.Bombs.count, helicopterState.Bombs.seconds, helicopterState.IsBmbEmpty]
    alertWatched = [helicopterState.IsBmbEmpty]
  },
  [HelicopterParams.RATE_OF_FIRE] = {
    title = @() ::loc("HUD/RATE_OF_FIRE_SHORT")
    value = @() helicopterState.IsHighRateOfFire.value ? ::loc("HUD/HIGHFREQ_SHORT") : ::loc("HUD/LOWFREQ_SHORT")
    valuesWatched = helicopterState.IsHighRateOfFire
  },
  [HelicopterParams.AAM] = {
    title = @() helicopterState.Aam.count.value <= 0 ? ::loc("HUD/TXT_AAM_SHORT") : getAACaption()
    value = @() aamAimState.GuidanceLockState.value != GuidanceLockResult.RESULT_INVALID ? getAABullets() : ""
    titleWatched = [helicopterState.Aam.count, aamAimState.GuidanceLockState]
    valuesWatched = [helicopterState.Aam.count, helicopterState.Aam.seconds, helicopterState.IsAamEmpty,
      aamAimState.GuidanceLockState]
    alertWatched = [helicopterState.IsAamEmpty]
  },
  [HelicopterParams.FLARES] = {
    title = @() helicopterState.Flares.count.value <= 0 ? ::loc("HUD/FLARES_SHORT") : getFlaresCaption()
    value = generateBulletsTextFunction(helicopterState.Flares.count, helicopterState.Flares.seconds)
    titleWatched = [helicopterState.Flares.count, helicopterState.Flares.mode]
    valuesWatched = [helicopterState.Flares.count, helicopterState.Flares.seconds, helicopterState.IsFlrEmpty]
    alertWatched = [helicopterState.IsFlrEmpty]
  },
}

foreach (i, value in helicopterState.IsCannonEmpty) {
  textParamsMap[HelicopterParams.CANNON_1 + i] <- {
    title = @() ::loc("HUD/CANNONS_SHORT")
    value = generateBulletsTextFunction(helicopterState.CannonCount[i], helicopterState.CannonReloadTime[i])
    blink = @() getTurretBlink()
    valuesWatched = [
      helicopterState.CannonCount[i],
      helicopterState.CannonReloadTime[i],
      helicopterState.IsCannonEmpty[i]
    ]
    alertWatched = [helicopterState.IsCannonEmpty[i]]
  }
}

for (local i = 0; i < NUM_ENGINES_MAX; ++i)
{
  local indexStr = (i+1).tostring()

  textParamsMap[HelicopterParams.OIL_1 + i] <- {
    title = @() ::loc("HUD/OIL_TEMPERATURE_SHORT" + indexStr)
    value = generateTemperatureTextFunction(helicopterState.OilTemperature[i], helicopterState.OilState[i])
    valuesWatched = [
      helicopterState.OilTemperature[i],
      helicopterState.OilState[i],
      helicopterState.IsOilAlert[i]
    ]
    alertWatched = [helicopterState.IsOilAlert[i]]
  }

  textParamsMap[HelicopterParams.WATER_1 + i] <- {
    title = @() ::loc("HUD/WATER_TEMPERATURE_SHORT" + indexStr)
    value = generateTemperatureTextFunction(helicopterState.WaterTemperature[i], helicopterState.WaterState[i])
    valuesWatched = [
      helicopterState.WaterTemperature[i],
      helicopterState.WaterState[i],
      helicopterState.IsWaterAlert[i]
    ]
    alertWatched = [helicopterState.IsWaterAlert[i]]
  }

  textParamsMap[HelicopterParams.ENGINE_1 + i] <- {
    title = @() ::loc("HUD/ENGINE_TEMPERATURE_SHORT" + indexStr)
    value = generateTemperatureTextFunction(helicopterState.EngineTemperature[i], helicopterState.EngineState[i])
    valuesWatched = [
      helicopterState.EngineTemperature[i],
      helicopterState.EngineState[i],
      helicopterState.IsEngineAlert[i]
    ]
    alertWatched = [helicopterState.IsEngineAlert[i]]
  }
}


for (local i = 0; i < NUM_TRANSMISSIONS_MAX; ++i)
{
  local indexStr = (i+1).tostring();

  textParamsMap[HelicopterParams.TRANSMISSION_1 + i] <- {
    title = @() ::loc("HUD/TRANSMISSION_OIL_SHORT" + indexStr)
    value = generateTransmissionStateTextFunction(helicopterState.TransmissionOilState[i])
    valuesWatched = [
      helicopterState.TransmissionOilState[i],
      helicopterState.IsTransmissionOilAlert[i]
    ]
    alertWatched = [helicopterState.IsTransmissionOilAlert[i]]
  }
}

textParamsMap[HelicopterParams.FUEL] <- {
  title = @() ::loc("HUD/FUEL_SHORT")
  value = @() ::string.format("%d:%02d", ::math.floor(helicopterState.Fuel.value / 60), helicopterState.Fuel.value % 60)
  valuesWatched = [helicopterState.Fuel, helicopterState.IsFuelCritical]
  alertWatched = [helicopterState.IsFuelCritical]
}

local generateParamsTable = function(mask, width, pos, gap, needCaption = true, forIls = false) {
  local getChildren = function(line_style, isBackground)
  {
    local children = []
    foreach(key, param in textParamsMap)
    {
      if ((1 << key) & mask.value)
        children.append(createHelicopterParam(param, width, line_style, isBackground, needCaption, forIls))
    }
    return children
  }

  return function(line_style, isBackground){
    return {
      children = @() line_style.__merge({
        watch = mask
        pos = pos
        size = [width, SIZE_TO_CONTENT]
        flow = FLOW_VERTICAL
        gap = gap
        children = getChildren(line_style, isBackground)
      })
    }
  }
}

local function compassComponent(elemStyle, isBackground, w, h, x, y) {
  local getChildren = @() helicopterState.IsCompassVisible.value ? compass(elemStyle, w, h, elemStyle.color) : null
  return @()
  {
    size = SIZE_TO_CONTENT
    pos = [x, y]
    watch = helicopterState.IsCompassVisible
    children = getChildren()
  }
}

local airHorizonZeroLevel = function(line_style, height, isBackground) {
  return @() line_style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [4*height, height]
    commands = [
      [VECTOR_LINE, 0, 50, 15, 50],
      [VECTOR_LINE, 85, 50, 100, 50],
    ]
  })
}


local airHorizon = function(line_style, height, isBackground) {
  return @() line_style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [4*height, height]
    commands = [
      [VECTOR_LINE, 20, 50,  32, 50,  41, 100,  50, 50,  59, 100,  68, 50,  80, 50],
    ]
    watch = helicopterState.HorAngle
    transform = {
      pivot = [0.5, 0.5]
      rotate = helicopterState.HorAngle.value
    }
  })
}


local horizontalSpeedVector = function(line_style, height, isBackground) {
  return @() line_style.__merge({
    rendObj = ROBJ_HELICOPTER_HORIZONTAL_SPEED
    size = [height, height]
    minLengthArrowVisibleSq = 200
    velocityScale = 5
  })
}

local HelicopterHorizontalSpeedComponent = function(elemStyle, isBackground, posX = sw(50), posY = sh(50), height = hdpx(40)) {
  return function() {
    return {
      pos = [posX - 2* height, posY - height*0.5]
      size = [4*height, height]
      children = [
        airHorizonZeroLevel(elemStyle, height, isBackground)
        airHorizon(elemStyle, height, isBackground)
        {
          pos = [height, -0.5*height]
          children = [
            horizontalSpeedVector(elemStyle, 2 * height, isBackground)
          ]
        }
      ]
    }
  }
}

local hl = 20
local vl = 20

const fullRangeMultInv = 0.7
const outOfZoneLaunchShowTimeOut = 2.

local function turretAngles(line_style, width, height, aspect, isBackground) {

  local offset = 1.3
  local crossL = 2

  local getTurretCommands = function() {
    local px = helicopterState.TurretYaw.value * 100.0
    local py = 100 - helicopterState.TurretPitch.value * 100.0
    return [
      [VECTOR_LINE, px - crossL - offset, py, px - offset, py],
      [VECTOR_LINE, px + offset, py, px + crossL + offset, py],
      [VECTOR_LINE, px, py - crossL * aspect - offset * aspect, px, py - offset * aspect],
      [VECTOR_LINE, px, py + crossL * aspect + offset * aspect, px, py + offset * aspect]
    ]
  }

  local getAgmLaunchAngularRangeCommands = function() {
    if (helicopterState.IsAgmLaunchZoneVisible.value &&
        (helicopterState.AgmLaunchZoneYawMin.value > 0.0 || helicopterState.AgmLaunchZoneYawMax.value < 1.0 ||
         helicopterState.AgmLaunchZonePitchMin.value > 0.0 || helicopterState.AgmLaunchZonePitchMax.value < 1.0))
    {
      local left  = max(0.0, helicopterState.AgmLaunchZoneYawMin.value) * 100.0
      local right = min(1.0, helicopterState.AgmLaunchZoneYawMax.value) * 100.0
      local lower = 100.0 - max(0.0, helicopterState.AgmLaunchZonePitchMin.value) * 100.0
      local upper = 100.0 - min(1.0, helicopterState.AgmLaunchZonePitchMax.value) * 100.0
      return [
        [VECTOR_LINE, left,  upper, right, upper],
        [VECTOR_LINE, right, upper, right, lower],
        [VECTOR_LINE, right, lower, left,  lower],
        [VECTOR_LINE, left,  lower, left,  upper]
      ]
    }
    else
      return []
  }

  local getAgmLaunchDistanceRangeCommands = function() {

    if (helicopterState.IsAgmLaunchZoneVisible.value)
    {
      local distanceRangeInv = fullRangeMultInv * 1.0 / (helicopterState.AgmLaunchZoneDistMax.value - 0.0 + 1.0)
      local distanceMinRel = (helicopterState.AgmLaunchZoneDistMin.value - 0.0) * distanceRangeInv
      local commands = [
        [VECTOR_LINE, 120, 0,   120, 100],
        [VECTOR_LINE, 120, 100, 125, 100],
        [VECTOR_LINE, 120, 0,   125, 0],
        [VECTOR_LINE, 120, 100 * (1.0 - fullRangeMultInv),  127, 100 * (1.0 - fullRangeMultInv)],
        [VECTOR_LINE, 120, 100 - (distanceMinRel * 100 - 1), 127, 100 - (distanceMinRel * 100 - 1)]
      ]
      if (helicopterState.IsRangefinderEnabled.value)
      {
        local distanceRel = min((helicopterState.RangefinderDist.value - 0.0) * distanceRangeInv, 1.0)
        commands.append([VECTOR_RECTANGLE, 120, 100 - (distanceRel * 100 - 1),  10, 2])
      }
      return commands
    }
    else
      return []
  }

  return @() line_style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [aspect * width, height]
    commands = [
      [VECTOR_LINE, 0, 100 - vl, 0, 100, hl, 100],
      [VECTOR_LINE, 100 - hl, 100, 100, 100, 100, 100 - vl],
      [VECTOR_LINE, 100, vl, 100, 0, 100 - hl, 0],
      [VECTOR_LINE, hl, 0, 0, 0, 0, vl]
    ]
    children = [
      @() line_style.__merge({
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = hdpx(LINE_WIDTH + 1)
        size = [aspect * width, height]
        watch = [helicopterState.TurretYaw, helicopterState.TurretPitch, helicopterState.FovYaw, helicopterState.FovPitch]
        commands = getTurretCommands()
      }),
      @() line_style.__merge({
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = hdpx(LINE_WIDTH + 0)
        size = [aspect * width, height]
        watch = [
          helicopterState.IsAgmLaunchZoneVisible,
          helicopterState.IsInsideLaunchZoneYawPitch,
          helicopterState.TurretYaw, helicopterState.TurretPitch,
          helicopterState.AgmLaunchZoneYawMin, helicopterState.AgmLaunchZoneYawMax,
          helicopterState.AgmLaunchZonePitchMin, helicopterState.AgmLaunchZonePitchMax
        ]
        commands = getAgmLaunchAngularRangeCommands()
        behavior = Behaviors.RtPropUpdate
        update = function() {
          return {
            opacity = isInsideAgmLaunchAngularRange() ? 100 :
              math.round(helicopterState.CurrentTime.value * 4) % 2 == 0 ? 100 : 0
          }
        }
      }),
      @() line_style.__merge({
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = hdpx(LINE_WIDTH + 1)
        size = [aspect * width, height]
        watch = [
          helicopterState.IsAgmLaunchZoneVisible,
          helicopterState.IsRangefinderEnabled, helicopterState.RangefinderDist,
          helicopterState.AgmLaunchZoneDistMin, helicopterState.AgmLaunchZoneDistMax
        ]
        commands = getAgmLaunchDistanceRangeCommands()
        behavior = Behaviors.RtPropUpdate
        update = function() {
          return {
            opacity = !(helicopterState.IsRangefinderEnabled.value && !isInsideAgmLaunchDistanceRange()) ||
                      math.round(helicopterState.CurrentTime.value * 4) % 2 == 0 ? 100 : 0
          }
        }
      })
    ]
  })
}

local lockSight = function(line_style, width, height, isBackground) {
  return @() line_style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [width, height]
    watch = [ helicopterState.IsAgmEmpty, helicopterState.IsSightLocked, helicopterState.IsTargetTracked ]
    color = !isBackground && helicopterState.IsAgmEmpty.value ? helicopterState.AlertColor.value : getColor(isBackground, line_style)
    commands = helicopterState.IsSightLocked.value ?
     ( helicopterState.IsTargetTracked.value ?
        [] :
        [
          [VECTOR_LINE, 0, 0, hl, vl],
          [VECTOR_LINE, 0, 100, vl, 100 - vl],
          [VECTOR_LINE, 100, 100, 100 - hl, 100 - vl],
          [VECTOR_LINE, 100, 0, 100 - hl, vl]
        ]
        ) : []
  })
}

local lockSightComponent = function(elemStyle, width, height, posX, posY, isBackground) {
  return @() {
    pos = [posX - width * 0.5, posY - height * 0.5]
    size = SIZE_TO_CONTENT
    children = lockSight(elemStyle, width, height, isBackground)
  }
}

local helicopterRocketSightMode = function(sightMode){

    if (sightMode == 0)
    {
      return [
        [VECTOR_LINE, -100, -100, 100, -100],
        [VECTOR_LINE, -100, 100, 100, 100],
        [VECTOR_LINE, -20, -100, -20, 100],
        [VECTOR_LINE, 20, -100, 20, 100],
      ]
    }
    else if (sightMode == 1)
    {
      return [
            [VECTOR_LINE, -100, -100, 100, -100],
            [VECTOR_LINE, -100, 100, 100, 100],
            [VECTOR_LINE, -20, -100, -20, 100],
            [VECTOR_LINE, 20, -100, 20, 100],
            [VECTOR_LINE, 60, 50, 80, 60],
            [VECTOR_LINE, -60, 50, -80, 60],
            [VECTOR_LINE, 60, -50, 80, -60],
            [VECTOR_LINE, -60, -50, -80, -60],
      ]
    }

  return [
        [VECTOR_LINE, -100, -100, 100, -100],
        [VECTOR_LINE, -100, 100, 100, 100],
        [VECTOR_LINE, -20, -100, -20, 100],
        [VECTOR_LINE, 20, -100, 20, 100],
        [VECTOR_LINE, 40, 40, -40, 40],
        [VECTOR_LINE, 40, -40, -40, -40],
        [VECTOR_LINE, 60, 20, 60, -20],
        [VECTOR_LINE, -60, 20, -60, -20],
      ]
}

local helicopterRocketAim = function(line_style, width, height, isBackground) {

  local lines = @() line_style.__merge({
      rendObj = ROBJ_VECTOR_CANVAS
      size = [width, height]
      commands = helicopterRocketSightMode(helicopterState.RocketSightMode.value)
    })

  return @(){
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    size = SIZE_TO_CONTENT
    watch = [helicopterState.RocketAimX, helicopterState.RocketAimY, helicopterState.RocketAimVisible, helicopterState.RocketSightMode]
    opacity = helicopterState.RocketAimVisible.value ? 100 : 0
    transform = {
      translate = [helicopterState.RocketAimX.value, helicopterState.RocketAimY.value]
    }
    children = [lines]
  }
}

local turretAnglesAspect = 2.0
local turretAnglesComponent = function(elemStyle, width, height, posX, posY, isBackground) {
  return {
    pos = [posX - turretAnglesAspect * width * 0.5, posY - height]
    size = SIZE_TO_CONTENT
    children = turretAngles(elemStyle, width, height, turretAnglesAspect, isBackground)
  }
}

local sight = function(line_style, height, isBackground) {
  local longL = 22
  local shortL = 10
  local dash = 0.8
  local centerOffset = 3

  return @() line_style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [height, height]
    commands = [
      [VECTOR_LINE, 0, 50, longL, 50],
      [VECTOR_LINE, 100 - longL, 50, 100, 50],
      [VECTOR_LINE, 50, 100, 50, 100 - longL],
      [VECTOR_LINE, 50, 0, 50, longL],

      [VECTOR_LINE, 50 - shortL - centerOffset, 50, 50 - centerOffset, 50],
      [VECTOR_LINE, 50 + centerOffset, 50, 50 + centerOffset + shortL, 50],
      [VECTOR_LINE, 50, 50 + centerOffset, 50, 50 + centerOffset + shortL],
      [VECTOR_LINE, 50, 50 - shortL - centerOffset, 50, 50 - centerOffset],

      [VECTOR_LINE, 50 - centerOffset, 50 - dash , 50 - centerOffset, 50 + dash],
      [VECTOR_LINE, 50 + centerOffset, 50 - dash , 50 + centerOffset, 50 + dash],
      [VECTOR_LINE, 50 - dash , 50 - centerOffset, 50 + dash, 50 - centerOffset],
      [VECTOR_LINE, 50 - dash , 50 + centerOffset, 50 + dash, 50 + centerOffset],
    ]
  })
}

local sightComponent = function(elemStyle, centerX, centerY, height, isBackground) {
  return {
    pos = [centerX - height * 0.5, centerY - height * 0.5]
    size = SIZE_TO_CONTENT
    children = sight(elemStyle, height, isBackground)
  }
}

local function launchDistanceMaxComponent(elemStyle, width, height, posX, posY, isBackground) {

  local getAgmLaunchDistanceMax = function() {
    return helicopterState.IsAgmLaunchZoneVisible.value ?
      ::cross_call.measureTypes.DISTANCE_SHORT.getMeasureUnitsText(helicopterState.AgmLaunchZoneDistMax.value) : ""
  }

  local launchDistanceMax = @() elemStyle.__merge({
    rendObj = ROBJ_DTEXT
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    text = getAgmLaunchDistanceMax()
    watch = [
      helicopterState.IsAgmLaunchZoneVisible,
      helicopterState.AgmLaunchZoneDistMax
    ]
  })

  local resCompoment = @() {
    rendObj = ROBJ_VECTOR_CANVAS
    pos = [posX + 1.6 * turretAnglesAspect * width * 0.5, posY - height * fullRangeMultInv]
    halign = ALIGN_LEFT
    valign = ALIGN_CENTER
    size = [0, 0]
    children = launchDistanceMax
  }

  return resCompoment
}

local function rangeFinderComponent(elemStyle, posX, posY, isBackground) {
  local rangefinder = @() elemStyle.__merge({
    rendObj = ROBJ_DTEXT
    halign = ALIGN_CENTER
    text = ::cross_call.measureTypes.DISTANCE_SHORT.getMeasureUnitsText(helicopterState.RangefinderDist.value)
    opacity = helicopterState.IsRangefinderEnabled.value ? 100 : 0
    watch = [helicopterState.RangefinderDist, helicopterState.IsRangefinderEnabled]
  })

  local resCompoment = @() {
    pos = [posX, posY]
    halign = ALIGN_CENTER
    size = [0, 0]
    children = rangefinder
  }

  return resCompoment
}

local HelicopterTATarget = function(line_style, w, h, isBackground) {
  local border = @() line_style.__merge({
      rendObj = ROBJ_VECTOR_CANVAS
      size = [w, h]
      color = helicopterState.AlertColor.value
      commands =
      [
        [VECTOR_LINE, -10, -10, 10, -10],
        [VECTOR_LINE, 10, -10, 10, 10],
        [VECTOR_LINE, 10, 10, -10, 10],
        [VECTOR_LINE, -10, 10, -10, -10]
      ]
  })

  local target = @() line_style.__merge({
      rendObj = ROBJ_VECTOR_CANVAS
      size = [w, h]
      color = helicopterState.AlertColor.value
      watch = helicopterState.IsTargetTracked
      commands = helicopterState.IsTargetTracked.value ?
      [
        [VECTOR_LINE, -5, 0, -10, 0],
        [VECTOR_LINE, 5, 0, 10, 0],
        [VECTOR_LINE, 0, -5, 0, -10],
        [VECTOR_LINE, 0, 5, 0, 10]
      ] : []
  })

  local laser = @() line_style.__merge({
      rendObj = ROBJ_VECTOR_CANVAS
      size = [w, h]
      color = helicopterState.AlertColor.value
      watch = helicopterState.IsLaserDesignatorEnabled
      commands = helicopterState.IsLaserDesignatorEnabled.value ?
      [
        [VECTOR_LINE, -2, -2, 2, -2],
        [VECTOR_LINE, 2, -2, 2, 2],
        [VECTOR_LINE, 2, 2, -2, 2],
        [VECTOR_LINE, -2, 2, -2, -2]
      ] : []
  })

  return @(){
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    size = SIZE_TO_CONTENT
    watch = [helicopterState.TATargetVisible, helicopterState.TATargetX, helicopterState.TATargetY, helicopterState.IsTargetTracked,
      helicopterState.TargetAge, helicopterState.CurrentTime]
    transform = {
      translate = [helicopterState.TATargetX.value, helicopterState.TATargetY.value]
    }
    behavior = Behaviors.RtPropUpdate
    update = function() {
      return {
        opacity = helicopterState.TATargetVisible.value &&
                  (helicopterState.TargetAge.value < 0.2 ||
                   math.round(helicopterState.CurrentTime.value * 4) % 2 == 0) ? 100 : 0
      }
    }
    children = [border, target, laser]
  }
}

local targetSize = function(line_style, width, height, isBackground) {
  local hd = 5
  local vd = 5
  local posX = helicopterState.IsMfdEnabled.value ? 50 : (helicopterState.TATargetX.value / sw(100) * 100)
  local posY = helicopterState.IsMfdEnabled.value ? 50 : (helicopterState.TATargetY.value / sh(100) * 100)
  return @() line_style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [width, height]
    fillColor = Color(0, 0, 0, 0)
    watch = [ helicopterState.HasTargetTracker, helicopterState.IsTargetTracked, helicopterState.TargetRadius ]
    commands = helicopterState.HasTargetTracker.value && helicopterState.TargetRadius.value > 0.0 ?
      ( helicopterState.IsTargetTracked.value ? (
        helicopterState.AimCorrectionEnabled.value ?
        [
          [ VECTOR_RECTANGLE,
            posX - helicopterState.TargetRadius.value / width * 100,
            posY - helicopterState.TargetRadius.value / height * 100,
            2.0 * helicopterState.TargetRadius.value / width * 100,
            2.0 * helicopterState.TargetRadius.value / height * 100
          ],
          [ VECTOR_ELLIPSE, 50, 50,
            helicopterState.TargetRadius.value / width * 100,
            helicopterState.TargetRadius.value / height * 100
          ]
        ] :
        [
          [ VECTOR_RECTANGLE,
            posX - helicopterState.TargetRadius.value / width * 100,
            posY - helicopterState.TargetRadius.value / height * 100,
            2.0 * helicopterState.TargetRadius.value / width * 100,
            2.0 * helicopterState.TargetRadius.value / height * 100
          ]
        ]
        ) :
        [
          [VECTOR_LINE,
            posX - helicopterState.TargetRadius.value / width * 100,
            posY - helicopterState.TargetRadius.value / height * 100,
            posX - (helicopterState.TargetRadius.value - hd) / width * 100,
            posY - helicopterState.TargetRadius.value / height * 100],
          [VECTOR_LINE,
            posX - helicopterState.TargetRadius.value / width  * 100,
            posY - helicopterState.TargetRadius.value / height * 100,
            posX - helicopterState.TargetRadius.value / width  * 100,
            posY - (helicopterState.TargetRadius.value - vd) / height * 100],

          [VECTOR_LINE,
            posX + helicopterState.TargetRadius.value / width  * 100,
            posY - helicopterState.TargetRadius.value / height * 100,
            posX + (helicopterState.TargetRadius.value - hd) / width  * 100,
            posY - helicopterState.TargetRadius.value / height * 100],
          [VECTOR_LINE,
            posX + helicopterState.TargetRadius.value / width  * 100,
            posY - helicopterState.TargetRadius.value / height * 100,
            posX + helicopterState.TargetRadius.value / width  * 100,
            posY - (helicopterState.TargetRadius.value - vd) / height * 100],

          [VECTOR_LINE,
            posX + helicopterState.TargetRadius.value / width  * 100,
            posY + helicopterState.TargetRadius.value / height * 100,
            posX + (helicopterState.TargetRadius.value - hd) / width  * 100,
            posY + helicopterState.TargetRadius.value / height * 100],
          [VECTOR_LINE,
            posX + helicopterState.TargetRadius.value / width  * 100,
            posY + helicopterState.TargetRadius.value / height * 100,
            posX + helicopterState.TargetRadius.value / width  * 100,
            posY + (helicopterState.TargetRadius.value - vd) / height * 100],

          [VECTOR_LINE,
            posX - helicopterState.TargetRadius.value / width  * 100,
            posY + helicopterState.TargetRadius.value / height * 100,
            posX - (helicopterState.TargetRadius.value - hd) / width  * 100,
            posY + helicopterState.TargetRadius.value / height * 100],
          [VECTOR_LINE,
            posX - helicopterState.TargetRadius.value / width  * 100,
            posY + helicopterState.TargetRadius.value / height * 100,
            posX - helicopterState.TargetRadius.value / width  * 100,
            posY + (helicopterState.TargetRadius.value - vd) / height * 100]
        ]) : []
  })
}

local targetSizeComponent = function(elemStyle, width, height, isBackground) {
  return @() {
    pos = [0, 0]
    size = SIZE_TO_CONTENT
    watch = [helicopterState.TATargetX, helicopterState.TATargetY]
    behavior = Behaviors.RtPropUpdate
    update = function() {
      return {
        opacity = helicopterState.TargetAge.value < 0.2 ||
                  math.round(helicopterState.CurrentTime.value * 4) % 2 == 0 ? 100 : 0
      }
    }
    children = targetSize(elemStyle, width, height, isBackground)
  }
}

local detectAllyComponent = function(elemStyle, posX, posY, isBackground) {
  return @() {
    pos = [posX, posY]
    size = SIZE_TO_CONTENT
    watch = [helicopterState.DetectAllyProgress, helicopterState.DetectAllyState]
    children = helicopterState.DetectAllyProgress.value != -1 ?
      [@() elemStyle.__merge({
          rendObj = ROBJ_DTEXT
          text = helicopterState.DetectAllyProgress.value < 1.0 ? ::loc("detect_ally_progress") :
           (helicopterState.DetectAllyState.value ? ::loc("detect_ally_success") : ::loc("detect_ally_fail"))
      })] : null
  }
}

return {
  vertSpeed = HelicopterVertSpeed
  paramsTable = generateParamsTable
  compassElem = compassComponent
  horSpeed = HelicopterHorizontalSpeedComponent
  turretAngles = turretAnglesComponent
  sight = sightComponent
  launchDistanceMax = launchDistanceMaxComponent
  rangeFinder = rangeFinderComponent
  taTarget = HelicopterTATarget
  targetSize = targetSizeComponent
  lockSight = lockSightComponent
  rocketAim = helicopterRocketAim
  detectAlly = detectAllyComponent
}