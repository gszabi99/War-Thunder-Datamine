local {floor, round_by_value, round} = require("std/math.nut")

local {CannonMode, IsCannonEmpty, CannonSelected, CannonReloadTime, CannonCount,
        OilTemperature, OilState, WaterTemperature, WaterState, EngineTemperature, EngineState,
        IsEngineAlert, TransmissionOilState, IsTransmissionOilAlert, Fuel, IsFuelCritical, IsCompassVisible,
        MachineGuns, IsMachineGunEmpty, CannonsAdditional, IsCanAdditionalEmpty, Rockets,
        IsRktEmpty, IsSightHudVisible, Agm, IsAgmEmpty, IsTargetTracked, AimCorrectionEnabled,
        TargetRadius, TATargetX, TATargetY, DetectAllyProgress, DetectAllyState, Bombs, IsBmbEmpty,
        IsHighRateOfFire, Aam, IsAamEmpty, IsInsideLaunchZoneYawPitch, AgmLaunchZoneYawMin,
        AgmLaunchZonePitchMin, AgmLaunchZonePitchMax, AgmLaunchZoneYawMax, AgmRotatedLaunchZoneYawMin, AgmRotatedLaunchZoneYawMax,
        AgmRotatedLaunchZonePitchMax, AgmRotatedLaunchZonePitchMin, TurretPitch, TurretYaw, IsZoomedAgmLaunchZoneVisible,
        IsAgmLaunchZoneVisible, AgmLaunchZoneDistMax, IsRangefinderEnabled, RangefinderDist,
        Rpm, IsRpmCritical, TrtMode, Trt, Spd, IsOilAlert, IsWaterAlert, HorAngle, AgmLaunchZoneDistMin,
        AlertColor, IsLaserDesignatorEnabled, TargetAge, IsInsideLaunchZoneDist, GunInDeadZone,
        FovYaw, FovPitch, IsSightLocked, RocketSightMode, RocketAimVisible,
        RocketAimX, RocketAimY, TATargetVisible, HasTargetTracker, IRCMState,
        IsFlrEmpty, Flares, DistanceToGround, CurrentTime, IsMfdEnabled, VerticalSpeed
} = require("helicopterState.nut")

local aamGuidanceLockState = require("rocketAamAimState.nut").GuidanceLockState
local agmGuidanceLockState =  require("agmAimState.nut").GuidanceLockState
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

  local getRelativeHeight = @() ::clamp(DistanceToGround.value * 2.0, 0, 100)

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
          watch = DistanceToGround
          opacity = DistanceToGround.value > 50.0 ? 0 : 100
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
          watch = DistanceToGround
          text = IsMfdEnabled.value ? floor(DistanceToGround.value).tostring() :
            ::cross_call.measureTypes.ALTITUDE.getMeasureUnitsText(DistanceToGround.value)
        })
      }
      @(){
        watch = VerticalSpeed
        pos = [scaleWidth + sh(0.5), 0]
        transform = {
          translate = [0, height * 0.01 * clamp(50 - VerticalSpeed.value * 5.0, 0, 100)]
        }
        children = [
          verticalSpeedInd(elemStyle, hdpx(25), isBackground),
          {
            pos = [scaleWidth + hdpx(10), hdpx(-10)]
            children = @() elemStyle.__merge({
              rendObj = ROBJ_DTEXT
              size = [scaleWidth*4,SIZE_TO_CONTENT]
              watch = VerticalSpeed
              text = IsMfdEnabled.value ?
                round_by_value(VerticalSpeed.value, 1).tostring() :
                ::cross_call.measureTypes.CLIMBSPEED.getMeasureUnitsText(VerticalSpeed.value)
            })
          }
        ]
      }
    ]
  }
}

local function generateBulletsTextFunction(countWatched, secondsWatched, salvoWatched = null) {
  return function() {
    local txts = []
    if (secondsWatched.value >= 0) {

      txts = [::string.format("%d:%02d", floor(secondsWatched.value / 60), secondsWatched.value % 60)]

      if (countWatched.value > 0)
        txts.append(" (", countWatched.value, ")")
      return "".join(txts)
    }
    else if (countWatched.value >= 0) {

      txts = [countWatched.value]
      if (salvoWatched != null && salvoWatched.value > 0)
        txts.append(" [", salvoWatched.value, "]")
    }
    return "".join(txts)
  }
}

local generateAgmBulletsTextFunction = function(countWatched, secondsWatched, timeToHit, timeToWarning) {
  return function() {
    local txts = []
    if (secondsWatched.value >= 0) {

      txts = [::string.format("%d:%02d", floor(secondsWatched.value / 60), secondsWatched.value % 60)]
      if (countWatched.value > 0)
        txts.append(" (", countWatched.value, ")")
      return "".join(txts)
    }
    else if (countWatched.value >= 0)
      txts = [countWatched.value]

    if (timeToHit.value > 0)
      txts.append(::string.format("[%d]", timeToHit.value))
    return "".join(txts)
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

  if ( TrtMode.value == HelicopterThrottleMode.DEFAULT_MODE
    || TrtMode.value == HelicopterThrottleMode.CLIMB
    || TrtMode.value == HelicopterThrottleMode.AIRCRAFT_DEFAULT_MODE)
    return ::string.format("%d %%", Trt.value)
  else if (TrtMode.value == HelicopterThrottleMode.BRAKE
    || TrtMode.value == HelicopterThrottleMode.AIRCRAFT_BRAKE)
    return ::loc("HUD/BRAKE_SHORT")
  else if (TrtMode.value == HelicopterThrottleMode.WEP
    || TrtMode.value == HelicopterThrottleMode.AIRCRAFT_WEP)
    return ::loc("HUD/WEP_SHORT")

  return ""
}


local getThrottleCaption = function() {
  return (TrtMode.value == HelicopterThrottleMode.AIRCRAFT_DEFAULT_MODE
  || TrtMode.value == HelicopterThrottleMode.AIRCRAFT_WEP
  || TrtMode.value == HelicopterThrottleMode.AIRCRAFT_BRAKE)
  ? ::loc("HUD/THROTTLE_SHORT")
  :(TrtMode.value == HelicopterThrottleMode.CLIMB)
  ? ::loc("HUD/CLIMB_SHORT")
  : ::loc("HUD/PROP_PITCH_SHORT")
}

local function getAGCaption() {
  local texts = []
  if (agmGuidanceLockState.value == GuidanceLockResult.RESULT_INVALID)
    texts.append(::loc("HUD/TXT_AGM_SHORT"))
  else if (agmGuidanceLockState.value == GuidanceLockResult.RESULT_STANDBY)
    texts.append(::loc("HUD/TXT_AGM_STANDBY"))
  else if (agmGuidanceLockState.value == GuidanceLockResult.RESULT_WARMING_UP)
    texts.append(::loc("HUD/TXT_AGM_WARM_UP"))
  else if (agmGuidanceLockState.value == GuidanceLockResult.RESULT_LOCKING)
    texts.append(::loc("HUD/TXT_AGM_LOCK"))
  else if (agmGuidanceLockState.value == GuidanceLockResult.RESULT_TRACKING)
    texts.append(::loc("HUD/TXT_AGM_TRACK"))
  else if (agmGuidanceLockState.value == GuidanceLockResult.RESULT_LOCK_AFTER_LAUNCH)
    texts.append(::loc("HUD/TXT_AGM_LOCK_AFTER_LAUNCH"))
  return "".join(texts)
}

local function getAACaption() {
  local texts = []
  if (aamGuidanceLockState.value == GuidanceLockResult.RESULT_INVALID)
    texts.append(::loc("HUD/TXT_AAM_SHORT"))
  else if (aamGuidanceLockState.value == GuidanceLockResult.RESULT_STANDBY)
    texts.append(::loc("HUD/TXT_AAM_STANDBY"))
  else if (aamGuidanceLockState.value == GuidanceLockResult.RESULT_WARMING_UP)
    texts.append(::loc("HUD/TXT_AAM_WARM_UP"))
  else if (aamGuidanceLockState.value == GuidanceLockResult.RESULT_LOCKING)
    texts.append(::loc("HUD/TXT_AAM_LOCK"))
  else if (aamGuidanceLockState.value == GuidanceLockResult.RESULT_TRACKING)
    texts.append(::loc("HUD/TXT_AAM_TRACK"))
  else if (aamGuidanceLockState.value == GuidanceLockResult.RESULT_LOCK_AFTER_LAUNCH)
    texts.append(::loc("HUD/TXT_AAM_LOCK_AFTER_LAUNCH"))
  return "".join(texts)
}

local function getFlaresCaption() {
  local texts = [::loc("HUD/FLARES_SHORT")," "]
  if (Flares.mode.value & FlaresMode.PERIODIC_FLARES)
    texts.append(::loc("HUD/FLARE_PERIODIC"))
  if (Flares.mode.value == (FlaresMode.PERIODIC_FLARES | FlaresMode.MLWS_SLAVED_FLARES))
    texts.append(::loc("HUD/INDICATION_MODE_SEPARATION"))
  if (Flares.mode.value & FlaresMode.MLWS_SLAVED_FLARES)
    texts.append(::loc("HUD/FLARE_MLWS"))
  return "".join(texts)
}

local function getMachineGunCaption(){
  local texts = [::loc("HUD/MACHINE_GUNS_SHORT")," "]
  if (MachineGuns.mode.value & WeaponMode.CCIP_MODE)
    texts.append(::loc("HUD/WEAPON_MODE_CCIP"))
  if (MachineGuns.mode.value == (WeaponMode.CCIP_MODE | WeaponMode.CCRP_MODE))
    texts.append(::loc("HUD/INDICATION_MODE_SEPARATION"))
  if (MachineGuns.mode.value & WeaponMode.CCRP_MODE)
    texts.append(::loc("HUD/WEAPON_MODE_CCRP"))
  return "".join(texts)
}

local function getAdditionalCannonCaption(){
  local texts = [::loc("HUD/ADDITIONAL_GUNS_SHORT")," "]
  if (CannonsAdditional.mode.value & WeaponMode.CCIP_MODE)
    texts.append(::loc("HUD/WEAPON_MODE_CCIP"))
  if (CannonsAdditional.mode.value == (WeaponMode.CCIP_MODE | WeaponMode.CCRP_MODE))
    texts.append(::loc("HUD/INDICATION_MODE_SEPARATION"))
  if (CannonsAdditional.mode.value & WeaponMode.CCRP_MODE)
    texts.append(::loc("HUD/WEAPON_MODE_CCRP"))
  return "".join(texts)
}

local function getRocketCaption(){
  local texts = [::loc("HUD/RKT")," "]
  if (Rockets.mode.value & WeaponMode.CCIP_MODE)
    texts.append(::loc("HUD/WEAPON_MODE_CCIP"))
  if (Rockets.mode.value == (WeaponMode.CCIP_MODE | WeaponMode.CCRP_MODE))
    texts.append(::loc("HUD/INDICATION_MODE_SEPARATION"))
  if (Rockets.mode.value & WeaponMode.CCRP_MODE)
    texts.append(::loc("HUD/WEAPON_MODE_CCRP"))
  return "".join(texts)
}

local function getBombCaption(){
  local texts = [::loc("HUD/BOMBS_SHORT")," "]
  if (Bombs.mode.value & WeaponMode.CCIP_MODE)
    texts.append(::loc("HUD/WEAPON_MODE_CCIP"))
  if (Bombs.mode.value == (WeaponMode.CCIP_MODE | WeaponMode.CCRP_MODE))
    texts.append(::loc("HUD/INDICATION_MODE_SEPARATION"))
  if (Bombs.mode.value & WeaponMode.CCRP_MODE)
    texts.append(::loc("HUD/WEAPON_MODE_CCRP"))
  return "".join(texts)
}

local function getCannonsCaption(cannonMode){
  local texts = [::loc("HUD/CANNONS_SHORT"), " "]
  if (cannonMode.value & WeaponMode.CCIP_MODE)
    texts.append(::loc("HUD/WEAPON_MODE_CCIP"))
  if (cannonMode.value == (WeaponMode.CCIP_MODE | WeaponMode.CCRP_MODE))
    texts.append(::loc("HUD/INDICATION_MODE_SEPARATION"))
  if (cannonMode.value & WeaponMode.CCRP_MODE)
    texts.append(::loc("HUD/WEAPON_MODE_CCRP"))
  return "".join(texts)
}

local function getIRCMCaption(){
  local texts = []
  if (IRCMState.value == IRCMMode.IRCM_ENABLED)
    texts.append(::loc("controls/on"))
  else if (IRCMState.value == IRCMMode.IRCM_DAMAGED)
    texts.append(::loc("controls/dmg"))
  else if (IRCMState.value == IRCMMode.IRCM_DISABLED)
    texts.append(::loc("controls/off"))
  return "".join(texts)
}

local function isInsideAgmLaunchAngularRange() {
  return IsInsideLaunchZoneYawPitch.value
}

local function isInsideAgmLaunchDistanceRange() {
  return IsInsideLaunchZoneDist.value
}

local function getAGBlink() {
  if (IsSightHudVisible.value && IsAgmLaunchZoneVisible.value &&
       (
         !isInsideAgmLaunchAngularRange() || (IsRangefinderEnabled.value && !isInsideAgmLaunchDistanceRange())
       ) )
    return round(CurrentTime.value * 4) % 2 == 0 ? 100 : 0
  else
    return 100
}

local function getTurretBlink() {
  return !GunInDeadZone.value ? 100 : round(CurrentTime.value * 4) % 2 == 0 ? 100 : 0
}

local function getAGBulletsBlink() {
  if (Agm.timeToHit.value > 0 && Agm.timeToWarning.value <= 0)
    return round(CurrentTime.value * 4) % 2 == 0 ? 100 : 0
  else
    return 100
}

local getAGBullets = generateAgmBulletsTextFunction(Agm.count, Agm.seconds, Agm.timeToHit, Agm.timeToWarning)

local getAABullets = generateBulletsTextFunction(Aam.count, Aam.seconds)

local function createHelicopterParam(param, width, line_style, isBackground, needCaption = true, for_ils = false) {
  local rowHeight = for_ils ? 50 : hdpx(28)
  local {titleWatched=null, valuesWatched=null, alertWatched=null, selectedWatched=null, blink=null, valueBlink=null, value,  selected, title} = param

  local selectColor = function(){
    return alertWatched && alertWatched[0].value && !isBackground
      ? AlertColor.value
      : getColor(isBackground, line_style)
  }

  local captionComponent = @() line_style.__merge({
    rendObj = ROBJ_DTEXT
    size = [0.4*width, rowHeight]
    text = title()
    watch = (alertWatched ? alertWatched : []).extend(titleWatched ? titleWatched : [])
    color = selectColor()
  })

  local selectedComponent = @() line_style.__merge({
    color = selectColor()
    rendObj = ROBJ_DTEXT
    size = [0.05*width, rowHeight]
    text = selected()
    watch = selectedWatched ? selectedWatched : []
  })

  return function() {
    return {
      size = SIZE_TO_CONTENT
      flow = FLOW_HORIZONTAL
      behavior = blink ? Behaviors.RtPropUpdate : null
      update = function() {
        return {
          opacity = blink?() ? 100 : 0
        }
      }
      children = [
        selectedComponent,
        (needCaption ? captionComponent : null),
        @() line_style.__merge({
          color = selectColor()
          rendObj = ROBJ_DTEXT
          size = [0.6*width, rowHeight]
          text = value()
          watch = valuesWatched
          behavior = valueBlink ? Behaviors.RtPropUpdate : null
          update = function() {
            return {
              opacity = valueBlink() ? 100 : 0
            }
          }
        })
      ]
    }
  }
}

local textParamsMap = {
  [HelicopterParams.RPM] = {
    title = @() TrtMode.value < HelicopterThrottleMode.AIRCRAFT_DEFAULT_MODE
    ? ::loc("HUD/PROP_RPM_SHORT")
    : ""
    value = @() TrtMode.value < HelicopterThrottleMode.AIRCRAFT_DEFAULT_MODE
    ? ::string.format("%d %%", Rpm.value)
    : ""
    selected = @() ""
    valuesWatched = [Rpm, IsRpmCritical]
    alertWatched = [IsRpmCritical]
  },
  [HelicopterParams.THROTTLE] = {
    title = @() getThrottleCaption()
    value = @() getThrottleText()
    selected = @() ""
    titleWatched = [TrtMode]
    valuesWatched = [Trt, TrtMode]
  },
  [HelicopterParams.SPEED] = {
    title = @() ::loc("HUD/REAL_SPEED_SHORT")
    value = @() " ".concat(Spd.value, ::cross_call.measureTypes.SPEED.getMeasureUnitsName())
    selected = @() ""
    valuesWatched = Spd
  },
  [HelicopterParams.MACHINE_GUN] = {
    title = @() getMachineGunCaption()
    value = generateBulletsTextFunction(MachineGuns.count, MachineGuns.seconds)
    selected = @() MachineGuns.selected.value ? ">" : ""
    titleWatched = [MachineGuns.mode]
    valuesWatched = [MachineGuns.count, MachineGuns.seconds,
      IsMachineGunEmpty, MachineGuns.selected]
    selectedWatched = [MachineGuns.selected]
    alertWatched = [IsMachineGunEmpty]
  },
  [HelicopterParams.CANNON_ADDITIONAL] = {
    title = @() getAdditionalCannonCaption()
    value = generateBulletsTextFunction(CannonsAdditional.count, CannonsAdditional.seconds)
    selected = @() CannonsAdditional.selected.value ? ">" : ""
    titleWatched = [CannonsAdditional.mode]
    valuesWatched = [
      CannonsAdditional.count,
      CannonsAdditional.seconds,
      IsCanAdditionalEmpty
    ]
    selectedWatched = [CannonsAdditional.selected]
    alertWatched = [IsCanAdditionalEmpty]
  },
  [HelicopterParams.ROCKET] = {
    title = @() getRocketCaption()
    value = generateBulletsTextFunction(Rockets.count, Rockets.seconds,
      Rockets.salvo)
    selected = @() Rockets.selected.value ? ">" : ""
    titleWatched = [Rockets.mode]
    valuesWatched = [Rockets.count, Rockets.seconds, IsRktEmpty,
      Rockets.selected, Rockets.salvo]
    selectedWatched = [Rockets.selected]
    alertWatched = [IsRktEmpty]
  },
  [HelicopterParams.AGM] = {
    title = @() Agm.count.value <= 0 ? ::loc("HUD/TXT_AGM_SHORT") :
      getAGCaption()
    value = @() getAGBullets()
    selected = @() Agm.selected.value ? ">" : ""
    blink = @() getAGBlink()
    titleWatched = [
      agmGuidanceLockState,
      IsSightHudVisible, IsAgmLaunchZoneVisible, IsAgmLaunchZoneVisible,
      IsInsideLaunchZoneYawPitch, IsInsideLaunchZoneDist
    ]
    valueBlink = @() getAGBulletsBlink()
    valuesWatched = [
      IsSightHudVisible, IsAgmLaunchZoneVisible, IsAgmLaunchZoneVisible,
      Agm.count, Agm.seconds, Agm.timeToHit, Agm.timeToWarning,
      IsAgmEmpty, agmGuidanceLockState
    ]
    selectedWatched = [Agm.selected]
    alertWatched = [IsAgmEmpty]
  },
  [HelicopterParams.BOMBS] = {
    title = @() getBombCaption()
    value = generateBulletsTextFunction(Bombs.count, Bombs.seconds,
      Bombs.salvo)
    selected = @() Bombs.selected.value ? ">" : ""
    titleWatched = [Bombs.mode]
    valuesWatched = [Bombs.count, Bombs.seconds,
      IsBmbEmpty, Bombs.salvo]
    selectedWatched = [Bombs.selected]
    alertWatched = [IsBmbEmpty]
  },
  [HelicopterParams.RATE_OF_FIRE] = {
    title = @() ::loc("HUD/RATE_OF_FIRE_SHORT")
    value = @() IsHighRateOfFire.value ? ::loc("HUD/HIGHFREQ_SHORT") : ::loc("HUD/LOWFREQ_SHORT")
    selected = @() ""
    valuesWatched = IsHighRateOfFire
  },
  [HelicopterParams.AAM] = {
    title = @() Aam.count.value <= 0 ? ::loc("HUD/TXT_AAM_SHORT") : getAACaption()
    value = @() getAABullets()
    selected = @() Aam.selected.value ? ">" : ""
    titleWatched = [Aam.count, aamGuidanceLockState]
    valuesWatched = [Aam.count, Aam.seconds, IsAamEmpty,
      aamGuidanceLockState]
    selectedWatched = [Aam.selected]
    alertWatched = [IsAamEmpty]
  },
  [HelicopterParams.FLARES] = {
    title = @() Flares.count.value <= 0 ? ::loc("HUD/FLARES_SHORT") : getFlaresCaption()
    value = generateBulletsTextFunction(Flares.count, Flares.seconds)
    selected = @() ""
    titleWatched = [Flares.count, Flares.mode]
    valuesWatched = [Flares.count, Flares.seconds,
      IsFlrEmpty]
    alertWatched = [IsFlrEmpty]
  },
  [HelicopterParams.IRCM] = {
    title = @() ::loc("HUD/IRCM_SHORT")
    value = @() getIRCMCaption()
    selected = @() ""
    valuesWatched = IRCMState
  },
}

foreach (i, value in IsCannonEmpty) {
  textParamsMap[HelicopterParams.CANNON_1 + i] <- {
    title = @() getCannonsCaption(CannonMode)
    value = generateBulletsTextFunction(CannonCount[i], CannonReloadTime[i])
    selected = @() CannonSelected.value ? ">" : ""
    titleWatched = [CannonMode]
    blink = @() getTurretBlink()
    valuesWatched = [
      CannonCount[i],
      CannonReloadTime[i],
      IsCannonEmpty[i],
      CannonMode
    ]
    selectedWatched = [CannonSelected]
    alertWatched = [IsCannonEmpty[i]]
  }
}

for (local i = 0; i < NUM_ENGINES_MAX; ++i) {

  local indexStr = (i+1).tostring()

  textParamsMap[HelicopterParams.OIL_1 + i] <- {
    title = @() ::loc($"HUD/OIL_TEMPERATURE_SHORT{indexStr}")
    value = generateTemperatureTextFunction(OilTemperature[i], OilState[i])
    selected = @() ""
    valuesWatched = [
      OilTemperature[i],
      OilState[i],
      IsOilAlert[i]
    ]
    alertWatched = [IsOilAlert[i]]
  }

  textParamsMap[HelicopterParams.WATER_1 + i] <- {
    title = @() ::loc($"HUD/WATER_TEMPERATURE_SHORT{indexStr}")
    value = generateTemperatureTextFunction(WaterTemperature[i], WaterState[i])
    selected = @() ""
    valuesWatched = [
      WaterTemperature[i],
      WaterState[i],
      IsWaterAlert[i]
    ]
    alertWatched = [IsWaterAlert[i]]
  }

  textParamsMap[HelicopterParams.ENGINE_1 + i] <- {
    title = @() ::loc($"HUD/ENGINE_TEMPERATURE_SHORT{indexStr}")
    value = generateTemperatureTextFunction(EngineTemperature[i], EngineState[i])
    selected = @() ""
    valuesWatched = [
      EngineTemperature[i],
      EngineState[i],
      IsEngineAlert[i]
    ]
    alertWatched = [IsEngineAlert[i]]
  }
}

for (local i = 0; i < NUM_TRANSMISSIONS_MAX; ++i) {

  local indexStr = (i+1).tostring();

  textParamsMap[HelicopterParams.TRANSMISSION_1 + i] <- {
    title = @() ::loc($"HUD/TRANSMISSION_OIL_SHORT{indexStr}")
    value = generateTransmissionStateTextFunction(TransmissionOilState[i])
    selected = @() ""
    valuesWatched = [
      TransmissionOilState[i],
      IsTransmissionOilAlert[i]
    ]
    alertWatched = [IsTransmissionOilAlert[i]]
  }
}

textParamsMap[HelicopterParams.FUEL] <- {
  title = @() ::loc("HUD/FUEL_SHORT")
  value = @() ::string.format("%d:%02d", floor(Fuel.value / 60), Fuel.value % 60)
  selected = @() ""
  valuesWatched = [Fuel, IsFuelCritical]
  alertWatched = [IsFuelCritical]
}

local function generateParamsTable(mask, width, pos, gap, needCaption = true, forIls = false) {
  local function getChildren(line_style, isBackground) {
    local children = []
    foreach(key, param in textParamsMap) {
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
  local getChildren = @() IsCompassVisible.value ? compass(elemStyle, w, h, elemStyle.color) : null
  return @() {
    size = SIZE_TO_CONTENT
    pos = [x, y]
    watch = IsCompassVisible
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
    watch = HorAngle
    transform = {
      pivot = [0.5, 0.5]
      rotate = HorAngle.value
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
    local px = TurretYaw.value * 100.0
    local py = 100 - TurretPitch.value * 100.0
    return [
      [VECTOR_LINE, px - crossL - offset, py, px - offset, py],
      [VECTOR_LINE, px + offset, py, px + crossL + offset, py],
      [VECTOR_LINE, px, py - crossL * aspect - offset * aspect, px, py - offset * aspect],
      [VECTOR_LINE, px, py + crossL * aspect + offset * aspect, px, py + offset * aspect]
    ]
  }

  local getAgmLaunchAngularRangeCommands = function() {
    if (IsAgmLaunchZoneVisible.value &&
        (AgmLaunchZoneYawMin.value > 0.0 || AgmLaunchZoneYawMax.value < 1.0 ||
         AgmLaunchZonePitchMin.value > 0.0 || AgmLaunchZonePitchMax.value < 1.0)) {

      local left  = max(0.0, AgmLaunchZoneYawMin.value) * 100.0
      local right = min(1.0, AgmLaunchZoneYawMax.value) * 100.0
      local lower = 100.0 - max(0.0, AgmLaunchZonePitchMin.value) * 100.0
      local upper = 100.0 - min(1.0, AgmLaunchZonePitchMax.value) * 100.0
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

  local function getAgmGuidanceRangeCommands() {
    if (IsAgmLaunchZoneVisible.value) {

      local left  = max(0.0, AgmRotatedLaunchZoneYawMin.value) * 100.0
      local right = min(1.0, AgmRotatedLaunchZoneYawMax.value) * 100.0
      local lower = 100.0 - max(0.0, AgmRotatedLaunchZonePitchMin.value) * 100.0
      local upper = 100.0 - min(1.0, AgmRotatedLaunchZonePitchMax.value) * 100.0
      return [
        [VECTOR_LINE, left, lower, right, lower],
        [VECTOR_LINE, left, upper, right, upper],
        [VECTOR_LINE, left, lower, left, upper],
        [VECTOR_LINE, right, lower, right, upper]
      ]
    }
    else
      return []
  }

  local function getAgmLaunchDistanceRangeCommands() {

    if (IsAgmLaunchZoneVisible.value) {
      local distanceRangeInv = fullRangeMultInv * 1.0 / (AgmLaunchZoneDistMax.value - 0.0 + 1.0)
      local distanceMinRel = (AgmLaunchZoneDistMin.value - 0.0) * distanceRangeInv
      local commands = [
        [VECTOR_LINE, 120, 0,   120, 100],
        [VECTOR_LINE, 120, 100, 125, 100],
        [VECTOR_LINE, 120, 0,   125, 0],
        [VECTOR_LINE, 120, 100 * (1.0 - fullRangeMultInv),  127, 100 * (1.0 - fullRangeMultInv)],
        [VECTOR_LINE, 120, 100 - (distanceMinRel * 100 - 1), 127, 100 - (distanceMinRel * 100 - 1)]
      ]
      if (IsRangefinderEnabled.value) {
        local distanceRel = min((RangefinderDist.value - 0.0) * distanceRangeInv, 1.0)
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
        lineWidth = max(LINE_WIDTH + 1, hdpx(LINE_WIDTH + 1))
        size = [aspect * width, height]
        watch = [TurretYaw, TurretPitch, FovYaw, FovPitch]
        commands = getTurretCommands()
      }),
      @() line_style.__merge({
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = max(LINE_WIDTH, hdpx(LINE_WIDTH + 0))
        size = [aspect * width, height]
        watch = [
          IsAgmLaunchZoneVisible,
          IsInsideLaunchZoneYawPitch,
          TurretYaw, TurretPitch,
          AgmLaunchZoneYawMin, AgmLaunchZoneYawMax,
          AgmLaunchZonePitchMin, AgmLaunchZonePitchMax
        ]
        commands = getAgmLaunchAngularRangeCommands()
        behavior = Behaviors.RtPropUpdate
        update = function() {
          return {
            opacity = isInsideAgmLaunchAngularRange() ? 100 :
              round(CurrentTime.value * 4) % 2 == 0 ? 100 : 0
          }
        }
      }),
      @() line_style.__merge({
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = max(LINE_WIDTH, hdpx(LINE_WIDTH + 0))
        size = [aspect * width, height]
        watch = [
          IsAgmLaunchZoneVisible,
          IsInsideLaunchZoneYawPitch,
          AgmRotatedLaunchZoneYawMax, AgmRotatedLaunchZoneYawMin,
          AgmRotatedLaunchZonePitchMax, AgmRotatedLaunchZonePitchMin
        ]
        commands = getAgmGuidanceRangeCommands()
        behavior = Behaviors.RtPropUpdate
        update = function() {
          return {
            opacity = isInsideAgmLaunchAngularRange() ? 100 :
              round(CurrentTime.value * 4) % 2 == 0 ? 100 : 0
          }
        }
      }),
      @() line_style.__merge({
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = max(LINE_WIDTH + 1, hdpx(LINE_WIDTH + 1))
        size = [aspect * width, height]
        watch = [
          IsAgmLaunchZoneVisible,
          IsRangefinderEnabled, RangefinderDist,
          AgmLaunchZoneDistMin, AgmLaunchZoneDistMax
        ]
        commands = getAgmLaunchDistanceRangeCommands()
        behavior = Behaviors.RtPropUpdate
        update = function() {
          return {
            opacity = !(IsRangefinderEnabled.value && !isInsideAgmLaunchDistanceRange()) ||
                      round(CurrentTime.value * 4) % 2 == 0 ? 100 : 0
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
    watch = [ IsAgmEmpty, IsSightLocked, IsTargetTracked ]
    color = !isBackground && IsAgmEmpty.value ? AlertColor.value : getColor(isBackground, line_style)
    commands = IsSightLocked.value ?
     ( IsTargetTracked.value ?
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

local function helicopterRocketSightMode(sightMode){

    if (sightMode == 0) {
      return [
        [VECTOR_LINE, -100, -100, 100, -100],
        [VECTOR_LINE, -100, 100, 100, 100],
        [VECTOR_LINE, -20, -100, -20, 100],
        [VECTOR_LINE, 20, -100, 20, 100],
      ]
    }
    else if (sightMode == 1) {
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

local function helicopterRocketAim(line_style, width, height, isBackground) {

  local lines = @() line_style.__merge({
      rendObj = ROBJ_VECTOR_CANVAS
      size = [width, height]
      commands = helicopterRocketSightMode(RocketSightMode.value)
    })

  return @(){
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    size = SIZE_TO_CONTENT
    watch = [RocketAimX, RocketAimY, RocketAimVisible, RocketSightMode]
    opacity = RocketAimVisible.value ? 100 : 0
    transform = {
      translate = [RocketAimX.value, RocketAimY.value]
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

local function agmLaunchZone(elemStyle, w, h, isBackground)  {

  local function maxAngleBorder(){
    local px = TurretYaw.value
    local py = TurretPitch.value
    local left  = max(0.0, AgmLaunchZoneYawMin.value) * 100.0 - px * 100.0 + 50.0
    local right = min(1.0, AgmLaunchZoneYawMax.value) * 100.0 - px * 100.0 + 50.0
    local lower = 100.0 - max(0.0, AgmLaunchZonePitchMin.value) * 100.0 + py * 100.0 - 50
    local upper = 100.0 - min(1.0, AgmLaunchZonePitchMax.value) * 100.0 + py * 100.0 - 50
    if (IsAgmLaunchZoneVisible.value) {
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

  return @() elemStyle.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    size = flex()
    watch = [ IsAgmLaunchZoneVisible,
      AgmLaunchZoneYawMin, AgmLaunchZoneYawMax,
      AgmLaunchZonePitchMin, AgmLaunchZonePitchMax,
      TurretYaw, TurretPitch, IsZoomedAgmLaunchZoneVisible
    ]
    commands = IsZoomedAgmLaunchZoneVisible.value ? maxAngleBorder() : []
  })
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
    return IsAgmLaunchZoneVisible.value ?
      ::cross_call.measureTypes.DISTANCE_SHORT.getMeasureUnitsText(AgmLaunchZoneDistMax.value) : ""
  }

  local launchDistanceMax = @() elemStyle.__merge({
    rendObj = ROBJ_DTEXT
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    text = getAgmLaunchDistanceMax()
    watch = [
      IsAgmLaunchZoneVisible,
      AgmLaunchZoneDistMax
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
    text = ::cross_call.measureTypes.DISTANCE_SHORT.getMeasureUnitsText(RangefinderDist.value)
    opacity = IsRangefinderEnabled.value ? 100 : 0
    watch = [RangefinderDist, IsRangefinderEnabled]
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
      color = AlertColor.value
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
      color = AlertColor.value
      watch = IsTargetTracked
      commands = IsTargetTracked.value ?
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
      color = AlertColor.value
      watch = IsLaserDesignatorEnabled
      commands = IsLaserDesignatorEnabled.value ?
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
    watch = [TATargetVisible, TATargetX, TATargetY, IsTargetTracked,
      TargetAge, CurrentTime]
    transform = {
      translate = [TATargetX.value, TATargetY.value]
    }
    behavior = Behaviors.RtPropUpdate
    update = function() {
      return {
        opacity = TATargetVisible.value &&
                  (TargetAge.value < 0.2 ||
                   round(CurrentTime.value * 4) % 2 == 0) ? 100 : 0
      }
    }
    children = [border, target, laser]
  }
}

local targetSize = function(line_style, width, height, isBackground) {
  local hd = 5
  local vd = 5
  local posX = IsMfdEnabled.value ? 50 : (TATargetX.value / sw(100) * 100)
  local posY = IsMfdEnabled.value ? 50 : (TATargetY.value / sh(100) * 100)
  return @() line_style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [width, height]
    fillColor = Color(0, 0, 0, 0)
    watch = [ HasTargetTracker, IsTargetTracked, TargetRadius ]
    commands = HasTargetTracker.value && TargetRadius.value > 0.0 ?
      ( IsTargetTracked.value ? (
        AimCorrectionEnabled.value ?
        [
          [ VECTOR_RECTANGLE,
            posX - TargetRadius.value / width * 100,
            posY - TargetRadius.value / height * 100,
            2.0 * TargetRadius.value / width * 100,
            2.0 * TargetRadius.value / height * 100
          ],
          [ VECTOR_ELLIPSE, 50, 50,
            TargetRadius.value / width * 100,
            TargetRadius.value / height * 100
          ]
        ] :
        [
          [ VECTOR_RECTANGLE,
            posX - TargetRadius.value / width * 100,
            posY - TargetRadius.value / height * 100,
            2.0 * TargetRadius.value / width * 100,
            2.0 * TargetRadius.value / height * 100
          ]
        ]
        ) :
        [
          [VECTOR_LINE,
            posX - TargetRadius.value / width * 100,
            posY - TargetRadius.value / height * 100,
            posX - (TargetRadius.value - hd) / width * 100,
            posY - TargetRadius.value / height * 100],
          [VECTOR_LINE,
            posX - TargetRadius.value / width  * 100,
            posY - TargetRadius.value / height * 100,
            posX - TargetRadius.value / width  * 100,
            posY - (TargetRadius.value - vd) / height * 100],

          [VECTOR_LINE,
            posX + TargetRadius.value / width  * 100,
            posY - TargetRadius.value / height * 100,
            posX + (TargetRadius.value - hd) / width  * 100,
            posY - TargetRadius.value / height * 100],
          [VECTOR_LINE,
            posX + TargetRadius.value / width  * 100,
            posY - TargetRadius.value / height * 100,
            posX + TargetRadius.value / width  * 100,
            posY - (TargetRadius.value - vd) / height * 100],

          [VECTOR_LINE,
            posX + TargetRadius.value / width  * 100,
            posY + TargetRadius.value / height * 100,
            posX + (TargetRadius.value - hd) / width  * 100,
            posY + TargetRadius.value / height * 100],
          [VECTOR_LINE,
            posX + TargetRadius.value / width  * 100,
            posY + TargetRadius.value / height * 100,
            posX + TargetRadius.value / width  * 100,
            posY + (TargetRadius.value - vd) / height * 100],

          [VECTOR_LINE,
            posX - TargetRadius.value / width  * 100,
            posY + TargetRadius.value / height * 100,
            posX - (TargetRadius.value - hd) / width  * 100,
            posY + TargetRadius.value / height * 100],
          [VECTOR_LINE,
            posX - TargetRadius.value / width  * 100,
            posY + TargetRadius.value / height * 100,
            posX - TargetRadius.value / width  * 100,
            posY + (TargetRadius.value - vd) / height * 100]
        ]) : []
  })
}

local targetSizeComponent = function(elemStyle, width, height, isBackground) {
  return @() {
    pos = [0, 0]
    size = SIZE_TO_CONTENT
    watch = [TATargetX, TATargetY]
    behavior = Behaviors.RtPropUpdate
    update = function() {
      return {
        opacity = TargetAge.value < 0.2 ||
                  round(CurrentTime.value * 4) % 2 == 0 ? 100 : 0
      }
    }
    children = targetSize(elemStyle, width, height, isBackground)
  }
}

local detectAllyComponent = function(elemStyle, posX, posY, isBackground) {
  return @() {
    pos = [posX, posY]
    size = SIZE_TO_CONTENT
    watch = [DetectAllyProgress, DetectAllyState]
    children = DetectAllyProgress.value != -1 ?
      [@() elemStyle.__merge({
          rendObj = ROBJ_DTEXT
          text = DetectAllyProgress.value < 1.0 ? ::loc("detect_ally_progress") :
           (DetectAllyState.value ? ::loc("detect_ally_success") : ::loc("detect_ally_fail"))
      })] : null
  }
}

return {
  vertSpeed = HelicopterVertSpeed
  paramsTable = generateParamsTable
  compassElem = compassComponent
  horSpeed = HelicopterHorizontalSpeedComponent
  turretAngles = turretAnglesComponent
  agmLaunchZone = agmLaunchZone
  sight = sightComponent
  launchDistanceMax = launchDistanceMaxComponent
  rangeFinder = rangeFinderComponent
  taTarget = HelicopterTATarget
  targetSize = targetSizeComponent
  lockSight = lockSightComponent
  rocketAim = helicopterRocketAim
  detectAlly = detectAllyComponent
}