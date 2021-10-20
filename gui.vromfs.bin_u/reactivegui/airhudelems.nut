local {floor, round_by_value} = require("std/math.nut")

local {CannonMode, CannonSelected, CannonReloadTime, CannonCount,
  OilTemperature, OilState, WaterTemperature, WaterState, EngineTemperature, EngineState,
  EngineAlert, TransmissionOilState, IsTransmissionOilAlert, Fuel, FuelState, IsCompassVisible,
  MachineGuns, IsMachineGunEmpty, CannonsAdditional, IsCanAdditionalEmpty, Rockets,
  IsRktEmpty, IsSightHudVisible, Agm, IsAgmEmpty,
  DetectAllyProgress, DetectAllyState, Bombs, IsBmbEmpty,
  IsHighRateOfFire, Aam, IsAamEmpty, GuidedBombs, IsGuidedBmbEmpty,
  IsInsideLaunchZoneYawPitch, AgmLaunchZoneYawMin,
  AgmLaunchZonePitchMin, AgmLaunchZonePitchMax, AgmLaunchZoneYawMax, AgmRotatedLaunchZoneYawMin, AgmRotatedLaunchZoneYawMax,
  AgmRotatedLaunchZonePitchMax, AgmRotatedLaunchZonePitchMin, TurretPitch, TurretYaw, IsZoomedAgmLaunchZoneVisible,
  IsAgmLaunchZoneVisible, AgmLaunchZoneDistMax, IsRangefinderEnabled, RangefinderDist,
  Rpm, IsRpmCritical, TrtMode, Trt, Spd, WaterAlert, HorAngle, AgmLaunchZoneDistMin,
  AlertColorLow, AlertColorMedium, AlertColorHigh, OilAlert,
  PassivColor, IsLaserDesignatorEnabled, IsInsideLaunchZoneDist, GunInDeadZone,
  RocketSightMode, RocketAimVisible, StaminaValue, StaminaState,
  RocketAimX, RocketAimY, TATargetVisible, IRCMState, IsCannonEmpty,
  Mach, CritMach, Ias, CritIas, InstructorState, InstructorForced,IsEnginesControled, ThrottleState, isEngineControled,
  IsFlrEmpty, IsChaffsEmpty, Flares, Chaffs, DistanceToGround, IsMfdEnabled, VerticalSpeed, HudColor, HudParamColor, MfdColor
} = require("airState.nut")

local {hudFontHgt, backgroundColor, fontOutlineColor, fontOutlineFxFactor, isColorOrWhite} = require("style/airHudStyle.nut")

local { IsTargetTracked, TargetAge, TargetX, TargetY } = require("reactiveGui/hud/targetTrackerState.nut")
local { lockSight, targetSize } = require("reactiveGui/hud/targetTracker.nut")

local { isInitializedMeasureUnits } = require("options/optionsMeasureUnits.nut")

local aamGuidanceLockState = require("rocketAamAimState.nut").GuidanceLockState
local agmGuidanceLockState =  require("agmAimState.nut").GuidanceLockState
local guidedBombsGuidanceLockState =  require("guidedBombsAimState.nut").GuidanceLockState
local compass = require("compass.nut")

const NUM_ENGINES_MAX = 6
const NUM_TRANSMISSIONS_MAX = 6
const NUM_CANNONS_MAX = 3

local styleText = {
  fillColor = Color(0, 0, 0, 0)
  lineWidth = max(1.5, hdpx(1) * (LINE_WIDTH + 1.5))
  font = Fonts.hud
  fontFxColor = fontOutlineColor
  fontFxFactor = fontOutlineFxFactor
  fontFx = FFT_GLOW
  fontSize = hudFontHgt
}

local styleLineForeground = {
  fillColor = Color(0, 0, 0, 0)
  lineWidth = hdpx(LINE_WIDTH)
  font = Fonts.hud
  fontFxColor = fontOutlineColor
  fontFxFactor = fontOutlineFxFactor
  fontFx = FFT_GLOW
  fontSize = hudFontHgt
}

enum GuidanceLockResult {
  RESULT_INVALID = -1
  RESULT_STANDBY = 0
  RESULT_WARMING_UP = 1
  RESULT_LOCKING = 2
  RESULT_TRACKING = 3
  RESULT_LOCK_AFTER_LAUNCH = 4
}

local verticalSpeedInd = function(height, isBackground, style, color) {
  return style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    color
    size = [height, height]
    pos = [0, -height*0.25]
    commands = [
      [VECTOR_LINE, 0, 25, 100, 50, 100, 0, 0, 25],
    ]
  })
}

local verticalSpeedScale = function(width, height, isBackground, style, color) {
  local part1_16 = 0.0625 * 100
  local lineStart = 70

  return style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [width, height]
    color
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

local HelicopterVertSpeed = function(scaleWidth, height, posX, posY, color, isBackground, elemStyle = styleText) {

  local relativeHeight = Computed( @() ::clamp(DistanceToGround.value * 2.0, 0, 100))

  return {
    pos = [posX, posY]
    children = [
      {
        children = verticalSpeedScale(scaleWidth, height, isBackground, elemStyle, color)
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
          watch = [DistanceToGround, relativeHeight]
          color = color
          opacity = DistanceToGround.value > 50.0 ? 0 : 100
          commands = [[VECTOR_RECTANGLE, 0, 100 - relativeHeight.value, 100, relativeHeight.value]]
        })
      }
      {
        halign = ALIGN_RIGHT
        valign = ALIGN_CENTER
        size = [-0.5*scaleWidth, height]
        children = @() elemStyle.__merge({
          rendObj = ROBJ_DTEXT
          halign = ALIGN_RIGHT
          color
          size = [scaleWidth*4,SIZE_TO_CONTENT]
          watch = [DistanceToGround, IsMfdEnabled]
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
          verticalSpeedInd(hdpx(25), isBackground, elemStyle, color),
          {
            pos = [scaleWidth + hdpx(10), hdpx(-10)]
            children = @() elemStyle.__merge({
              rendObj = ROBJ_DTEXT
              color
              size = [scaleWidth*4,SIZE_TO_CONTENT]
              watch = [VerticalSpeed, IsMfdEnabled]
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

local function generateBulletsTextFunction(count, seconds, salvo = 0, actualCount = 0) {
  local txts = []
  if (seconds >= 0) {
    txts = [::string.format("%d:%02d", floor(seconds / 60), seconds % 60)]
    if (count > 0)
      txts.append(" (", count, ")  ")
    return "".join(txts)
  }
  else if (count >= 0) {
    txts = [count]
    if (actualCount > 0)
      txts.append("/", actualCount)
    if (salvo > 0)
      txts.append(" [", salvo, "]  ")
    else if (salvo == -1)
      txts.append(" [S]  ")
  }
  return "".join(txts)
}

local generateRpmTitleFunction = function(trtMode) {
  local txts = []
  if (trtMode < AirThrottleMode.AIRCRAFT_DEFAULT_MODE)
    txts = [::loc("HUD/PROP_RPM_SHORT")]

  return "".join(txts)
}


local generateRpmTextFunction = function(trtMode, rpmValue) {
  local txts = []
  if (trtMode < AirThrottleMode.AIRCRAFT_DEFAULT_MODE)
    txts = [::string.format("%d %%", rpmValue)]

  return "".join(txts)
}

local generateAgmBulletsTextFunction = function(count, seconds, timeToHit, timeToWarning, actualCount = 0) {
  local txts = []
  if (seconds >= 0) {
    txts = [::string.format("%d:%02d", floor(seconds / 60), seconds % 60)]
    if (count > 0)
      txts.append(" (", count, ")")
    return "".join(txts)
  }
  else if (count >= 0)
    txts = [count]
  if (actualCount > 0)
    txts.append("/", actualCount)
  if (timeToHit > 0)
    txts.append(::string.format("[%d]", timeToHit))
  return "".join(txts)
}

local generateTemperatureTextFunction = function(temperature, state) {
  if (state == TemperatureState.OVERHEAT)
    return (temperature + ::cross_call.measureTypes.TEMPERATURE.getMeasureUnitsName())
  else if (state == TemperatureState.EMPTY_TANK)
    return (::loc("HUD_TANK_IS_EMPTY"))
  else if (state == TemperatureState.FUEL_LEAK)
    return (::loc("HUD_FUEL_LEAK"))
  else if (state == TemperatureState.FUEL_SEALING)
    return  (::loc("HUD_TANK_IS_SEALING"))
  else if (state == TemperatureState.BLANK)
    return ""

  return ""
}

local generateTransmissionStateTextFunction = function(oilState) {
  if(oilState > 0.01)
    return ::loc("HUD_FUEL_LEAK")
  else
  return ::loc("HUD_TANK_IS_EMPTY")
  return ""
}

local function getThrottleText(mode, trt) {
  if ( mode == AirThrottleMode.DEFAULT_MODE
    || mode == AirThrottleMode.CLIMB
    || mode == AirThrottleMode.AIRCRAFT_DEFAULT_MODE)
    return ::string.format("%d %%", trt)
  else if (mode == AirThrottleMode.BRAKE
    || mode == AirThrottleMode.AIRCRAFT_BRAKE)
    return ::loc("HUD/BRAKE_SHORT")
  else if (mode == AirThrottleMode.WEP
    || mode == AirThrottleMode.AIRCRAFT_WEP)
    return ::loc("HUD/WEP_SHORT")
  return ""
}


local function getThrottleCaption(mode, isControled, idx) {
  local texts = []
  if (mode == AirThrottleMode.AIRCRAFT_DEFAULT_MODE
  || mode == AirThrottleMode.AIRCRAFT_WEP
  || mode == AirThrottleMode.AIRCRAFT_BRAKE)
    texts.append( ::loc("HUD/THROTTLE_SHORT"))
  else if (mode == AirThrottleMode.CLIMB)
    texts.append(::loc("HUD/CLIMB_SHORT"))
  else
    texts.append(::loc("HUD/PROP_PITCH_SHORT"))
  if (isControled == true)
    texts.append(::string.format("_%d", (idx + 1)))
  return "".join(texts)
}

local function getAGCaption(guidanceLockState) {
  local texts = []
  if (guidanceLockState == GuidanceLockResult.RESULT_INVALID)
    texts.append(::loc("HUD/TXT_AGM_SHORT"))
  else if (guidanceLockState == GuidanceLockResult.RESULT_STANDBY)
    texts.append(::loc("HUD/TXT_AGM_STANDBY"))
  else if (guidanceLockState == GuidanceLockResult.RESULT_WARMING_UP)
    texts.append(::loc("HUD/TXT_AGM_WARM_UP"))
  else if (guidanceLockState == GuidanceLockResult.RESULT_LOCKING)
    texts.append(::loc("HUD/TXT_AGM_LOCK"))
  else if (guidanceLockState == GuidanceLockResult.RESULT_TRACKING)
    texts.append(::loc("HUD/TXT_AGM_TRACK"))
  else if (guidanceLockState == GuidanceLockResult.RESULT_LOCK_AFTER_LAUNCH)
    texts.append(::loc("HUD/TXT_AGM_LOCK_AFTER_LAUNCH"))
  return "".join(texts)
}

local function getAACaption(guidanceLockState) {
  local texts = []
  if (guidanceLockState == GuidanceLockResult.RESULT_INVALID)
    texts.append(::loc("HUD/TXT_AAM_SHORT"))
  else if (guidanceLockState == GuidanceLockResult.RESULT_STANDBY)
    texts.append(::loc("HUD/TXT_AAM_STANDBY"))
  else if (guidanceLockState == GuidanceLockResult.RESULT_WARMING_UP)
    texts.append(::loc("HUD/TXT_AAM_WARM_UP"))
  else if (guidanceLockState == GuidanceLockResult.RESULT_LOCKING)
    texts.append(::loc("HUD/TXT_AAM_LOCK"))
  else if (guidanceLockState == GuidanceLockResult.RESULT_TRACKING)
    texts.append(::loc("HUD/TXT_AAM_TRACK"))
  else if (guidanceLockState == GuidanceLockResult.RESULT_LOCK_AFTER_LAUNCH)
    texts.append(::loc("HUD/TXT_AAM_LOCK_AFTER_LAUNCH"))
  return "".join(texts)
}

local function getGBCaption(guidanceLockState) {
  local texts = []
  if (guidanceLockState == GuidanceLockResult.RESULT_INVALID)
    texts.append(::loc("HUD/TXT_GUIDED_BOMBS_SHORT"))
  else if (guidanceLockState == GuidanceLockResult.RESULT_STANDBY)
    texts.append(::loc("HUD/TXT_GUIDED_BOMBS_STANDBY"))
  else if (guidanceLockState == GuidanceLockResult.RESULT_WARMING_UP)
    texts.append(::loc("HUD/TXT_GUIDED_BOMBS_WARM_UP"))
  else if (guidanceLockState == GuidanceLockResult.RESULT_LOCKING)
    texts.append(::loc("HUD/TXT_GUIDED_BOMBS_LOCK"))
  else if (guidanceLockState == GuidanceLockResult.RESULT_TRACKING)
    texts.append(::loc("HUD/TXT_GUIDED_BOMBS_TRACK"))
  else if (guidanceLockState == GuidanceLockResult.RESULT_LOCK_AFTER_LAUNCH)
    texts.append(::loc("HUD/TXT_GUIDED_BOMBS_LOCK_AFTER_LAUNCH"))
  return "".join(texts)
}

local function getCountermeasuresCaption(isFlare ,mode) {
  local texts = isFlare ? [::loc("HUD/FLARES_SHORT")," "] : [::loc("HUD/CHAFFS_SHORT")," "]
  if (mode & CountermeasureMode.PERIODIC_COUNTERMEASURE)
    texts.append(::loc("HUD/COUNTERMEASURE_PERIODIC"))
  if (mode == (CountermeasureMode.PERIODIC_COUNTERMEASURE | CountermeasureMode.MLWS_SLAVED_COUNTERMEASURE))
    texts.append(::loc("HUD/INDICATION_MODE_SEPARATION"))
  if (mode & CountermeasureMode.MLWS_SLAVED_COUNTERMEASURE)
    texts.append(::loc("HUD/COUNTERMEASURE_MLWS"))
  return "".join(texts)
}

local function getModeCaption(mode) {
  local texts = []
  if ((mode & (1 << WeaponMode.CCIP_MODE)) && (mode & (1 << WeaponMode.CCRP_MODE)))
    texts.append(::loc("HUD/WEAPON_MODE_CCIP_CCRP"))
  else if (mode & (1 << WeaponMode.CCIP_MODE))
    texts.append(::loc("HUD/WEAPON_MODE_CCIP"))
  else if (mode & (1 << WeaponMode.CCRP_MODE))
    texts.append(::loc("HUD/WEAPON_MODE_CCRP"))
  return "".join(texts)
}

local function getMachineGunCaption(mode){
  local texts = [::loc("HUD/MACHINE_GUNS_SHORT")," "]
  texts.append(getModeCaption(mode))
  return "".join(texts)
}

local function getAdditionalCannonCaption(mode){
  local texts = [::loc("HUD/ADDITIONAL_GUNS_SHORT")," "]
  texts.append(getModeCaption(mode))
  return "".join(texts)
}

local function getRocketCaption(mode){
  local texts = [::loc("HUD/RKT")," "]
  texts.append(getModeCaption(mode))
  return "".join(texts)
}

local function getBombCaption(mode){
  local texts = [::loc("HUD/BOMBS_SHORT")," "]
  if ((mode & (1 << WeaponMode.CCIP_MODE)) && (mode & (1 << WeaponMode.CCRP_MODE)))
    texts.append(::loc("HUD/WEAPON_MODE_CCIP_CCRP"))
  else if (mode & (1 << WeaponMode.CCIP_MODE))
    texts.append(::loc("HUD/WEAPON_MODE_CCIP"))
  else if (mode & (1 << WeaponMode.CCRP_MODE))
    texts.append(::loc("HUD/WEAPON_MODE_CCRP"))

  //check both ccip/rp and bombBay
  local ballisticModeBits = mode & (1 << (WeaponMode.CCRP_MODE + 1))
  if (ballisticModeBits > 0 && (mode ^ ballisticModeBits) > 0)
    texts.append("  ")

  if (mode & (1 << WeaponMode.BOMB_BAY_OPEN))
    texts.append(::loc("HUD/BAY_DOOR_IS_OPEN_INDICATION"))
  if (mode & (1 << WeaponMode.BOMB_BAY_CLOSED))
    texts.append(::loc("HUD/BAY_DOOR_IS_CLOSED_INDICATION"))
  if (mode & (1 << WeaponMode.BOMB_BAY_OPENING))
    texts.append(::loc("HUD/BAY_DOOR_IS_OPENING_INDICATION"))
  if (mode & (1 << WeaponMode.BOMB_BAY_CLOSING))
    texts.append(::loc("HUD/BAY_DOOR_IS_CLOSING_INDICATION"))
  return "".join(texts)
}

local function getCannonsCaption(mode){
  local texts = [::loc("HUD/CANNONS_SHORT"), " "]
  texts.append(getModeCaption(mode))
  return "".join(texts)
}

local function getIRCMCaption(state){
  local texts = []
  if (state == IRCMMode.IRCM_ENABLED)
    texts.append(::loc("controls/on"))
  else if (state == IRCMMode.IRCM_DAMAGED)
    texts.append(::loc("controls/dmg"))
  else if (state == IRCMMode.IRCM_DISABLED)
    texts.append(::loc("controls/off"))
  return "".join(texts)
}

local function getInstructorCaption(isInstructorForced){
  return isInstructorForced ? ::loc("HUD_INSTRUCTOR_FORCED") : ::loc("HUD_INSTRUCTOR")
}

local function getThrottleValueState(state, controled){
  return controled ? state : HudColorState.PASSIV
}

local function getThrottleState(controled){
  return controled ? HudColorState.ACTIV : HudColorState.PASSIV
}

local function getStaminaValue(stamina) {
  return ::string.format("%d %%", stamina)
}

local function getFuelState(fuel, fuelState){
  local texts = []
  if (fuelState == TemperatureState.DEFAULT_TEMPERATURE ||
      fuelState == TemperatureState.OVERHEAT)
    texts.append(::string.format("%d:%02d", floor(fuel / 60), fuel % 60))
  else if (fuelState == TemperatureState.FUEL_LEAK)
    texts.append(::loc("HUD_FUEL_LEAK"))
  else if (fuelState == TemperatureState.FUEL_SEALING)
    texts.append(::loc("HUD_TANK_IS_SEALING"))
  else if (fuelState == TemperatureState.EMPTY_TANK)
    texts.append(::loc("HUD_TANK_IS_EMPTY"))
  return "".join(texts)
}

local function getFuelAlertState(fuelState){
  return fuelState >= TemperatureState.FUEL_LEAK ? HudColorState.HIGH_ALERT :
         fuelState == TemperatureState.OVERHEAT ? HudColorState.PASSIV :
         fuelState == TemperatureState.EMPTY_TANK ? HudColorState.PASSIV : HudColorState.ACTIV
}

local function createParam(param, width, height, isBackground, style, needCaption = true, for_ils = false, isBomberView = false) {
  local {blinkComputed=null, blinkTrigger=null, valueComputed, selectedComputed,
    additionalComputed, titleComputed, alertStateCaptionComputed, alertValueStateComputed} = param

  local selectColor = function(state, activeColor, passivColor, lowAlertColor, mediumAlertColor, highAlertColor) {
    return (state == HudColorState.PASSIV) ? passivColor
      : (state == HudColorState.LOW_ALERT) ? lowAlertColor
      : (state == HudColorState.MEDIUM_ALERT) ? mediumAlertColor
      : (state == HudColorState.HIGH_ALERT) ? highAlertColor
      : isBackground ? backgroundColor
      : isBomberView ? isColorOrWhite(activeColor)
      : activeColor
  }

  local captionSizeX = @() ::calc_comp_size({rendObj = ROBJ_DTEXT, size = SIZE_TO_CONTENT, text = titleComputed.value, watch = titleComputed})[0]
  local finalTitleSizeX = ::max(captionSizeX() + 0.1 * width, 0.4 * width)

  local colorAlertCaptionW = Computed(@() selectColor(alertStateCaptionComputed.value, HudParamColor.value, PassivColor.value,
    AlertColorLow.value, AlertColorMedium.value, AlertColorHigh.value))

  local captionComponent = @() style.__merge({
    rendObj = ROBJ_DTEXT
    size = [finalTitleSizeX, height]
    watch = [titleComputed, colorAlertCaptionW]
    text = titleComputed.value
    color = colorAlertCaptionW.value
  })

  local selectedComponent = @() style.__merge({
    rendObj = ROBJ_DTEXT
    size = [0.05*width, height]
    watch = [selectedComputed, colorAlertCaptionW]
    text = selectedComputed.value
    color = colorAlertCaptionW.value
  })

  local valueSizeX = @() ::calc_comp_size({rendObj = ROBJ_DTEXT, size = SIZE_TO_CONTENT, text = valueComputed.value, watch = valueComputed})[0]

  local valueComponent = @() style.__merge({
    color = for_ils ? MfdColor.value : selectColor(alertValueStateComputed.value, HudParamColor.value, PassivColor.value,
      AlertColorLow.value, AlertColorMedium.value, AlertColorHigh.value)
    rendObj = ROBJ_DTEXT
    size = [valueSizeX() + 0.075 * width, height]
    watch = [valueComputed, alertValueStateComputed, HudParamColor, PassivColor,
      AlertColorLow, AlertColorMedium, AlertColorHigh]
    text = valueComputed.value
  })

  local additionalComponent = @() style.__merge({
    color = isBackground ? backgroundColor
      : HudParamColor.value
    rendObj = ROBJ_DTEXT
    size = [0.7 * width, height]
    text = additionalComputed.value
    watch = [additionalComputed, HudParamColor]
  })

  return {
    flow = FLOW_HORIZONTAL
    animations = [{ prop = AnimProp.opacity, from = 0, to = 1, duration = 0.5, play = blinkComputed?.value, loop = true, easing = InOutCubic, trigger = blinkTrigger}]
    children = [
      selectedComponent,
      (needCaption ? captionComponent : null),
      valueComponent,
      additionalComponent
    ]
  }
}

//thoses local values are used for direct subscription
//Rpm
local TrtModeForRpm = TrtMode[0]

//MachineGuns
local MachineGunsCount = MachineGuns.count
local MachineGunsMode = MachineGuns.mode
local MachineGunsSeconds = MachineGuns.seconds
local MachineGunsSelected = MachineGuns.selected

//additionalComputed Cannons
local CannonsAdditionalCount = CannonsAdditional.count
local CannonsAdditionalSeconds = CannonsAdditional.seconds
local CannonsAdditionalMode = CannonsAdditional.mode
local CannonsAdditionalSelected = CannonsAdditional.selected

//Rockets
local RocketsCount = Rockets.count
local RocketsSeconds = Rockets.seconds
local RocketsActualCount = Rockets.actualCount
local RocketsSalvo = Rockets.salvo
local RocketsMode = Rockets.mode
local RocketsName = Rockets.name
local RocketsSelected = Rockets.selected

// Agm
local AgmCount = Agm.count
local AgmSeconds = Agm.seconds
local AgmTimeToHit = Agm.timeToHit
local AgmTimeToWarning = Agm.timeToWarning
local AgmActualCount = Agm.actualCount
local AgmName = Agm.name
local AgmSelected = Agm.selected

// Aam
local AamCount = Aam.count
local AamSeconds = Aam.seconds
local AamActualCount = Aam.actualCount
local AamName = Aam.name
local AamSelected = Aam.selected

//Guided Bombs
local GuidedBombsCount = GuidedBombs.count
local GuidedBombsSeconds = GuidedBombs.seconds
local GuidedBombsActualCount = GuidedBombs.actualCount
local GuidedBombsName = GuidedBombs.name
local GuidedBombsSelected = GuidedBombs.selected

//Bombs
local BombsCount = Bombs.count
local BombsSeconds = Bombs.seconds
local BombsActualCount = Bombs.actualCount
local BombsSalvo = Bombs.salvo
local BombsMode = Bombs.mode
local BombsName = Bombs.name
local BombsSelected = Bombs.selected

//Flares
local FlaresCount = Flares.count
local FlaresSeconds = Flares.seconds
local FlaresMode = Flares.mode

//Chaffs
local ChaffsCount = Chaffs.count
local ChaffsSeconds = Chaffs.seconds
local ChaffsMode = Chaffs.mode

local agmBlinkComputed = Computed(@() (IsSightHudVisible.value && IsAgmLaunchZoneVisible.value &&
  (!IsInsideLaunchZoneYawPitch.value || (IsRangefinderEnabled.value && !IsInsideLaunchZoneDist.value))))
local agmBlinkTrigger = {}
agmBlinkComputed.subscribe(@(v) v ? ::anim_start(agmBlinkTrigger) : ::anim_request_stop(agmBlinkTrigger))

local textParamsMapMain = {
  [AirParamsMain.RPM] = {
    titleComputed = Computed (@() generateRpmTitleFunction(TrtModeForRpm.value))
    valueComputed = Computed (@() generateRpmTextFunction(TrtModeForRpm.value, Rpm.value))
    selectedComputed = Computed (@() "")
    additionalComputed = Computed (@() "")
    alertStateCaptionComputed = Computed(@() IsRpmCritical.value ? HudColorState.HIGH_ALERT : HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() IsRpmCritical.value ? HudColorState.HIGH_ALERT : HudColorState.ACTIV)
  },
  [AirParamsMain.IAS_HUD] = {
    titleComputed = Computed (@() ::loc("HUD/INDICATED_AIR_SPEED_SHORT"))
    valueComputed = Computed (@()  !isInitializedMeasureUnits.value ? "" : " ".concat(Ias.value, ::cross_call.measureTypes.SPEED.getMeasureUnitsName()))
    selectedComputed = Computed (@() "")
    additionalComputed = Computed (@() "")
    alertStateCaptionComputed = Computed(@() CritIas.value ? HudColorState.HIGH_ALERT : HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() CritIas.value ? HudColorState.HIGH_ALERT : HudColorState.ACTIV)
  },
  [AirParamsMain.SPEED] = {
    titleComputed = Computed (@() ::loc("HUD/REAL_SPEED_SHORT"))
    valueComputed = Computed (@() !isInitializedMeasureUnits.value ? "" : " ".concat(Spd.value, ::cross_call.measureTypes.SPEED.getMeasureUnitsName()))
    selectedComputed = Computed (@() "")
    additionalComputed = Computed (@() "")
    alertStateCaptionComputed = Computed(@() HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() HudColorState.ACTIV)
  },
  [AirParamsMain.MACH] = {
    titleComputed = Computed(@() ::loc("HUD/TXT_MACH_SHORT"))
    valueComputed = Computed (@() ::string.format("%.2f", Mach.value))
    selectedComputed = Computed (@() "")
    additionalComputed = Computed (@() "")
    alertStateCaptionComputed = Computed(@() CritMach.value ? HudColorState.HIGH_ALERT : HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() CritMach.value ? HudColorState.HIGH_ALERT : HudColorState.ACTIV)
  },
  [AirParamsMain.ALTITUDE] = {
    titleComputed = Computed(@() ::loc("HUD/ALTITUDE_SHORT"))
    valueComputed = Computed (@() !isInitializedMeasureUnits.value ? "" : " ".concat(floor(DistanceToGround.value), ::cross_call.measureTypes.ALTITUDE.getMeasureUnitsName()))
    selectedComputed = Computed (@() "")
    additionalComputed = Computed (@() "")
    alertStateCaptionComputed = Computed(@() HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() HudColorState.ACTIV)
  },
  [AirParamsMain.MACHINE_GUN] = {
    titleComputed = Computed(@() getMachineGunCaption(MachineGunsMode.value))
    valueComputed = Computed(@() generateBulletsTextFunction(MachineGunsCount.value, MachineGunsSeconds.value))
    selectedComputed = Computed(@() MachineGunsSelected.value ? ">" : "")
    additionalComputed = Computed (@() "")
    alertStateCaptionComputed = Computed(@() IsMachineGunEmpty.value ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() IsMachineGunEmpty.value ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
  },
  [AirParamsMain.CANNON_ADDITIONAL] = {
    titleComputed = Computed(@() getAdditionalCannonCaption(CannonsAdditionalMode.value))
    valueComputed = Computed(@() generateBulletsTextFunction(CannonsAdditionalCount.value, CannonsAdditionalSeconds.value))
    selectedComputed = Computed(@() CannonsAdditionalSelected.value ? ">" : "")
    additionalComputed = Computed (@() "")
    alertStateCaptionComputed = Computed(@() IsCanAdditionalEmpty.value ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() IsCanAdditionalEmpty.value ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
  },
  [AirParamsMain.ROCKET] = {
    titleComputed = Computed(@() getRocketCaption(RocketsMode.value))
    valueComputed = Computed(@() generateBulletsTextFunction(RocketsCount.value, RocketsSeconds.value,
      RocketsSalvo.value, RocketsActualCount.value))
    selectedComputed = Computed(@() RocketsSelected.value ? ">" : "")
    additionalComputed = Computed(@() ::loc(RocketsName.value))
    alertStateCaptionComputed = Computed(@() IsRktEmpty.value ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() IsRktEmpty.value ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
  },
  [AirParamsMain.AGM] = {
    titleComputed = Computed(@() AgmCount.value <= 0 ? ::loc("HUD/TXT_AGM_SHORT") :
      getAGCaption(agmGuidanceLockState.value))
    valueComputed = Computed(@() generateAgmBulletsTextFunction(AgmCount.value, AgmSeconds.value,
       AgmTimeToHit.value, AgmTimeToWarning.value, AgmActualCount.value))
    selectedComputed = Computed(@() AgmSelected.value ? ">" : "")
    additionalComputed = Computed(@() ::loc(AgmName.value))
    alertStateCaptionComputed = Computed(@() IsAgmEmpty.value ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() IsAgmEmpty.value ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
    blinkComputed = agmBlinkComputed
    blinkTrigger = agmBlinkTrigger
  },
  [AirParamsMain.BOMBS] = {
    titleComputed = Computed(@() getBombCaption(BombsMode.value))
    valueComputed = Computed(@() generateBulletsTextFunction(BombsCount.value, BombsSeconds.value,
      BombsSalvo.value, BombsActualCount.value))
    selectedComputed = Computed(@() BombsSelected.value ? ">" : "")
    additionalComputed = Computed(@() ::loc(BombsName.value))
    alertStateCaptionComputed = Computed(@() IsBmbEmpty.value ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() IsBmbEmpty.value ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
  },
  [AirParamsMain.RATE_OF_FIRE] = {
    titleComputed = Computed(@() ::loc("HUD/RATE_OF_FIRE_SHORT"))
    valueComputed = Computed(@() IsHighRateOfFire.value ? ::loc("HUD/HIGHFREQ_SHORT") : ::loc("HUD/LOWFREQ_SHORT"))
    selectedComputed = Computed (@() "")
    additionalComputed = Computed (@() "")
    alertStateCaptionComputed = Computed(@() HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() HudColorState.ACTIV)
  },
  [AirParamsMain.AAM] = {
    titleComputed = Computed(@() AamCount.value <= 0 ? ::loc("HUD/TXT_AAM_SHORT") : getAACaption(aamGuidanceLockState.value))
    valueComputed = Computed(@() generateBulletsTextFunction(AamCount.value, AamSeconds.value, 0, AamActualCount.value))
    selectedComputed = Computed(@() AamSelected.value ? ">" : "")
    additionalComputed = Computed(@() ::loc(AamName.value))
    alertStateCaptionComputed = Computed(@() IsAamEmpty.value ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() IsAamEmpty.value ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
  },
  [AirParamsMain.GUIDED_BOMBS] = {
    titleComputed = Computed(@() GuidedBombsCount.value <= 0 ? ::loc("HUD/TXT_GUIDED_BOMBS_SHORT") :
      getGBCaption(guidedBombsGuidanceLockState.value))
    valueComputed = Computed(@() generateBulletsTextFunction(GuidedBombsCount.value, GuidedBombsSeconds.value, 0, GuidedBombsActualCount.value))
    selectedComputed = Computed(@() GuidedBombsSelected.value ? ">" : "")
    additionalComputed = Computed(@() ::loc(GuidedBombsName.value))
    alertStateCaptionComputed = Computed(@() IsGuidedBmbEmpty.value ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() IsGuidedBmbEmpty.value ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
  },
  [AirParamsMain.FLARES] = {
    titleComputed = Computed(@() FlaresCount.value <= 0 ? ::loc("HUD/FLARES_SHORT") : getCountermeasuresCaption(true, FlaresMode.value))
    valueComputed = Computed(@() generateBulletsTextFunction(FlaresCount.value, FlaresSeconds.value))
    selectedComputed = Computed (@() "")
    additionalComputed = Computed (@() "")
    alertStateCaptionComputed = Computed(@() IsFlrEmpty.value ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() IsFlrEmpty.value ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
  },
  [AirParamsMain.CHAFFS] = {
    titleComputed = Computed(@() ChaffsCount.value <= 0 ? ::loc("HUD/CHAFFS_SHORT") : getCountermeasuresCaption(false, ChaffsMode.value))
    valueComputed = Computed(@() generateBulletsTextFunction(ChaffsCount.value, ChaffsSeconds.value))
    selectedComputed = Computed (@() "")
    additionalComputed = Computed (@() "")
    alertStateCaptionComputed = Computed(@() IsChaffsEmpty.value ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() IsChaffsEmpty.value ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
  },
  [AirParamsMain.IRCM] = {
    titleComputed = Computed(@() ::loc("HUD/IRCM_SHORT"))
    valueComputed = Computed(@() getIRCMCaption(IRCMState.value))
    selectedComputed = Computed (@() "")
    additionalComputed = Computed (@() "")
    alertStateCaptionComputed = Computed(@() HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() HudColorState.ACTIV)
    valuesWatched = IRCMState
  },
}

foreach (i,value in isEngineControled) {
  local trtModeComputed = TrtMode[i]
  local trtComputed = Trt[i]
  local isEngineControledComputed = isEngineControled[i]
  local throttleStateComputed = ThrottleState[i]
  local index = i
  textParamsMapMain[AirParamsMain.THROTTLE_1 + i] <- {
    titleComputed = Computed(@() getThrottleCaption(trtModeComputed.value, IsEnginesControled.value, index))
    valueComputed = Computed(@() getThrottleText(trtModeComputed.value, trtComputed.value))
    selectedComputed = Computed (@() "")
    additionalComputed = Computed (@() "")
    alertStateCaptionComputed = Computed( @() getThrottleState(isEngineControledComputed.value))
    alertValueStateComputed = Computed (@() getThrottleValueState(throttleStateComputed.value, isEngineControledComputed.value))
  }
}

for (local i = 0; i < NUM_CANNONS_MAX; ++i) {
  local idx = i
  local CannonAmmoCount = CannonCount[idx]
  local CannonAmmoReloadTime = CannonReloadTime[idx]
  local blinkComputed = Computed(@() GunInDeadZone.value)
  local blinkTrigger = {}
  blinkComputed.subscribe(@(v) v ? ::anim_start(blinkTrigger) : ::anim_request_stop(blinkTrigger))
  textParamsMapMain[AirParamsMain.CANNON_1 + idx] <- {
    titleComputed = Computed(@() getCannonsCaption(CannonMode.value))
    valueComputed = Computed(@() generateBulletsTextFunction(CannonAmmoCount.value, CannonAmmoReloadTime.value))
    selectedComputed = Computed(@() CannonSelected.value ? ">" : "")
    additionalComputed = Computed (@() "")
    alertStateCaptionComputed = Computed(@() IsCannonEmpty.value?[idx] ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() IsCannonEmpty.value?[idx] ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
    blinkComputed
    blinkTrigger
  }
}

local numParamPerEngine = 3
local textParamsMapSecondary = {}

for (local i = 0; i < NUM_ENGINES_MAX; ++i) {

  local indexStr = (i+1).tostring()
  local oilStateComputed = OilState[i]
  local oilTemperatureComputed = OilTemperature[i]
  local oilAlertComputed = OilAlert[i]
  textParamsMapSecondary[AirParamsSecondary.OIL_1 + (i * numParamPerEngine)] <- {
    titleComputed = Computed(@() ::loc($"HUD/OIL_TEMPERATURE_SHORT{indexStr}"))
    valueComputed = Computed(@() !isInitializedMeasureUnits.value ? "" : generateTemperatureTextFunction(oilTemperatureComputed.value, oilStateComputed.value))
    selectedComputed = Computed (@() "")
    additionalComputed = Computed (@() "")
    alertStateCaptionComputed = Computed (@() oilAlertComputed.value)
    alertValueStateComputed = Computed (@() oilAlertComputed.value)
  }

  local waterStateComputed = WaterState[i]
  local waterTemperatureComputed = WaterTemperature[i]
  local waterAlertComputed = WaterAlert[i]
  textParamsMapSecondary[AirParamsSecondary.WATER_1 + (i * numParamPerEngine)] <- {
    titleComputed = Computed(@() ::loc($"HUD/WATER_TEMPERATURE_SHORT{indexStr}"))
    valueComputed = Computed(@() !isInitializedMeasureUnits.value ? "" : generateTemperatureTextFunction(waterTemperatureComputed.value, waterStateComputed.value))
    selectedComputed = Computed (@() "")
    additionalComputed = Computed (@() "")
    alertStateCaptionComputed = Computed (@() waterAlertComputed.value)
    alertValueStateComputed = Computed (@() waterAlertComputed.value)
  }

  local engineStateComputed = EngineState[i]
  local engineTemperatureComputed = EngineTemperature[i]
  local engineAlertComputed = EngineAlert[i]
  textParamsMapSecondary[AirParamsSecondary.ENGINE_1 + (i * numParamPerEngine)] <- {
    titleComputed = Computed(@() ::loc($"HUD/ENGINE_TEMPERATURE_SHORT{indexStr}"))
    valueComputed = Computed(@() !isInitializedMeasureUnits.value ? "" : generateTemperatureTextFunction(engineTemperatureComputed.value, engineStateComputed.value))
    selectedComputed = Computed (@() "")
    additionalComputed = Computed (@() "")
    alertStateCaptionComputed = Computed (@() engineAlertComputed.value)
    alertValueStateComputed = Computed (@() engineAlertComputed.value)
  }
}

for (local i = 0; i < NUM_TRANSMISSIONS_MAX; ++i) {

  local indexStr = (i+1).tostring();
  local transmissionOilStateComputed = TransmissionOilState[i]
  local isTransmissionAlertComputed = IsTransmissionOilAlert[i]
  textParamsMapSecondary[AirParamsSecondary.TRANSMISSION_1 + i] <- {
    titleComputed = Computed(@() ::loc($"HUD/TRANSMISSION_OIL_SHORT{indexStr}"))
   valueComputed = Computed(@() generateTransmissionStateTextFunction(transmissionOilStateComputed.value))
    selectedComputed = Computed (@() "")
    additionalComputed = Computed (@() "")
    alertStateCaptionComputed = Computed(@() isTransmissionAlertComputed.value ?  HudColorState.HIGH_ALERT : HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() isTransmissionAlertComputed.value ?  HudColorState.HIGH_ALERT : HudColorState.ACTIV)
  }
}

textParamsMapSecondary[AirParamsSecondary.FUEL] <- {
  titleComputed = Computed(@() ::loc("HUD/FUEL_SHORT"))
  valueComputed = Computed(@() getFuelState(Fuel.value, FuelState.value))
  selectedComputed = Computed (@() "")
  additionalComputed = Computed (@() "")
  alertStateCaptionComputed = Computed(@() getFuelAlertState(FuelState.value))
  alertValueStateComputed = Computed(@() getFuelAlertState(FuelState.value))
}

textParamsMapSecondary[AirParamsSecondary.STAMINA] <- {
  titleComputed = Computed(@() ::loc("HUD/TXT_STAMINA_SHORT"))
  valueComputed = Computed(@() getStaminaValue(StaminaValue.value))
  selectedComputed = Computed (@() "")
  additionalComputed = Computed (@() "")
  alertStateCaptionComputed = Computed(@() StaminaState.value)
  alertValueStateComputed = Computed(@() StaminaState.value)
}

textParamsMapSecondary[AirParamsSecondary.INSTRUCTOR] <- {
  titleComputed = Computed(@() getInstructorCaption(InstructorForced.value))
  valueComputed = Computed(@() "")
  selectedComputed = Computed (@() "")
  additionalComputed = Computed (@() "")
  alertStateCaptionComputed = Computed(@() InstructorState.value)
  alertValueStateComputed = Computed(@() InstructorState.value)
}

local fuelKeyId = AirParamsSecondary.FUEL

local function generateParamsTable(mainMask, secondaryMask, width, height, posWatched, gap, needCaption = true, forIls = false, is_aircraft = false, style = styleText) {
  local function getChildren(isBackground, style, isBomberView = false) {
    local children = []

    foreach(key, param in textParamsMapMain) {
      if ((1 << key) & mainMask.value)
        children.append(createParam(param, width, height, isBackground, style, needCaption, forIls, isBomberView))
      if (key == AirParamsMain.ALTITUDE && is_aircraft) {
        children.append(@() style.__merge({
          rendObj = ROBJ_DTEXT
          size = [0, hdpx(12)]
          text = @() ""
        }))
      }
    }
    local secondaryMaskValue = secondaryMask.value
    if (is_aircraft) {
      if ((1 << fuelKeyId) & secondaryMaskValue) {
        children.append(createParam(textParamsMapSecondary[fuelKeyId], width, height, isBackground, style, needCaption, forIls, isBomberView))
        secondaryMaskValue = secondaryMaskValue - (1 << fuelKeyId)
      }
    }

    if (is_aircraft) {
      children.append(@() style.__merge({
        rendObj = ROBJ_DTEXT
        size = [ 0, hdpx(12)]
        text = @() ""
      }))
    }

    foreach(key, param in textParamsMapSecondary) {
      if ((1 << key) & secondaryMaskValue)
        children.append(createParam(param, width, height, isBackground, style, needCaption, forIls, isBomberView))
    }

    return children
  }

  return function(isBackground, style = styleText, isBomberView = false ) {
    return {
      children = @() style.__merge({
        watch = [mainMask, secondaryMask, posWatched]
        pos = posWatched.value
        size = [width, SIZE_TO_CONTENT]
        flow = FLOW_VERTICAL
        gap = gap
        children = getChildren(isBackground, style, isBomberView)
      })
    }
  }
}

local function compassComponent(isBackground, size, pos) {
  return @() {
    pos
    watch = [IsCompassVisible, HudColor]
    children = IsCompassVisible.value ? compass(size, HudColor.value) : null
  }
}

local airHorizonZeroLevel = function(elemStyle, height, isBackground, color) {
  return elemStyle.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    color
    size = [4*height, height]
    commands = [
      [VECTOR_LINE, 0, 50, 15, 50],
      [VECTOR_LINE, 85, 50, 100, 50],
    ]
  })
}


local airHorizon = function(elemStyle, height, isBackground, color) {
  return @() elemStyle.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [4*height, height]
    color
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


local horizontalSpeedVector = function(elemStyle, height, isBackground, color) {
  return elemStyle.__merge({
    rendObj = ROBJ_HELICOPTER_HORIZONTAL_SPEED
    size = [height, height]
    minLengthArrowVisibleSq = 200
    velocityScale = 5
    color
  })
}

local HelicopterHorizontalSpeedComponent = function(isBackground, color, posX = sw(50), posY = sh(50), height = hdpx(40), elemStyle = styleLineForeground) {
  return function() {
    return {
      pos = [posX - 2* height, posY - height*0.5]
      size = [4*height, height]
      children = [
        airHorizonZeroLevel(elemStyle, height, isBackground, color)
        airHorizon(elemStyle, height, isBackground, color)
        {
          pos = [height, -0.5*height]
          children = [
            horizontalSpeedVector(elemStyle, 2 * height, isBackground, color)
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

local function getAgmLaunchAngularRangeCommands(visible, yawMin, yawMax, pitchMin, pitchMax) {

  local left  = max(0.0, yawMin) * 100.0
  local right = min(1.0, yawMax) * 100.0
  local lower = 100.0 - max(0.0, pitchMin) * 100.0
  local upper = 100.0 - min(1.0, pitchMax) * 100.0
  return [
    [VECTOR_LINE, left,  upper, right, upper],
    [VECTOR_LINE, right, upper, right, lower],
    [VECTOR_LINE, right, lower, left,  lower],
    [VECTOR_LINE, left,  lower, left,  upper]
  ]
}

local function getAgmGuidanceRangeCommands(visible, yawMin, yawMax, pitchMin, pitchMax) {

  local left  = max(0.0, yawMin) * 100.0
  local right = min(1.0, yawMax) * 100.0
  local lower = 100.0 - max(0.0, pitchMin) * 100.0
  local upper = 100.0 - min(1.0, pitchMax) * 100.0
  return [
    [VECTOR_LINE, left, lower, right, lower],
    [VECTOR_LINE, left, upper, right, upper],
    [VECTOR_LINE, left, lower, left, upper],
    [VECTOR_LINE, right, lower, right, upper]
  ]
}

local function getAgmLaunchDistanceRangeCommands(visible, enabled, distMin, distMax, dist) {

  local distanceRangeInv = fullRangeMultInv * 1.0 / (distMax - 0.0 + 1.0)
  local distanceMinRel = (distMin - 0.0) * distanceRangeInv
  local commands = [
    [VECTOR_LINE, 120, 0,   120, 100],
    [VECTOR_LINE, 120, 100, 125, 100],
    [VECTOR_LINE, 120, 0,   125, 0],
    [VECTOR_LINE, 120, 100 * (1.0 - fullRangeMultInv),  127, 100 * (1.0 - fullRangeMultInv)],
    [VECTOR_LINE, 120, 100 - (distanceMinRel * 100 - 1), 127, 100 - (distanceMinRel * 100 - 1)]
  ]
  if (enabled) {
    local distanceRel = min((dist - 0.0) * distanceRangeInv, 1.0)
    commands.append([VECTOR_RECTANGLE, 120, 100 - (distanceRel * 100 - 1),  10, 2])
  }
  return commands
}



local function turretAngles(colorWatch, width, height, aspect, isBackground) {

  local offset = 1.3
  local crossL = 2

  local getTurretCommands = function(yaw, pitch) {
    local px = yaw * 100.0
    local py = 100 - pitch * 100.0
    return [
      [VECTOR_LINE, px - crossL - offset, py, px - offset, py],
      [VECTOR_LINE, px + offset, py, px + crossL + offset, py],
      [VECTOR_LINE, px, py - crossL * aspect - offset * aspect, px, py - offset * aspect],
      [VECTOR_LINE, px, py + crossL * aspect + offset * aspect, px, py + offset * aspect]
    ]
  }
  local isAtgmGuidanceRangeVisible = Computed(@() IsAgmLaunchZoneVisible.value)
  local isAtgmAngularRangeVisible = Computed(@() (IsAgmLaunchZoneVisible.value && AgmLaunchZoneYawMin.value > 0.0 && AgmLaunchZoneYawMax.value < 1.0 && AgmLaunchZonePitchMin.value > 0.0 && AgmLaunchZonePitchMax.value < 1.0))
  local atgmLaunchZoneBlinking = Computed(@() !IsInsideLaunchZoneYawPitch.value)
  local atgmLaunchZoneTrigger = {}
  atgmLaunchZoneBlinking.subscribe(@(v) v ? ::anim_start(atgmLaunchZoneTrigger) : ::anim_request_stop(atgmLaunchZoneTrigger))
  local atgmLaunchDistanceblinking = Computed(@() IsRangefinderEnabled.value && !IsInsideLaunchZoneDist.value)
  local atgmLaunchDistanceTrigger = {}
  atgmLaunchDistanceblinking.subscribe(@(v) v ? ::anim_start(atgmLaunchDistanceTrigger) : ::anim_request_stop(atgmLaunchDistanceTrigger))

  return @() styleLineForeground.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [aspect * width, height]
    color = colorWatch.value
    watch = [colorWatch, atgmLaunchZoneBlinking, isAtgmGuidanceRangeVisible]
    commands = [
      [VECTOR_LINE, 0, 100 - vl, 0, 100, hl, 100],
      [VECTOR_LINE, 100 - hl, 100, 100, 100, 100, 100 - vl],
      [VECTOR_LINE, 100, vl, 100, 0, 100 - hl, 0],
      [VECTOR_LINE, hl, 0, 0, 0, 0, vl]
    ]
    children = [
      @() styleLineForeground.__merge({
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = hdpx(LINE_WIDTH + 1)
        size = [aspect * width, height]
        watch = [TurretYaw, TurretPitch, colorWatch]
        commands = getTurretCommands(TurretYaw.value, TurretPitch.value)
        color = colorWatch.value
      }),
      isAtgmAngularRangeVisible.value
        ? @() styleLineForeground.__merge({
            rendObj = ROBJ_VECTOR_CANVAS
            lineWidth = hdpx(LINE_WIDTH)
            size = [aspect * width, height]
            color = colorWatch.value
            watch = [
              IsAgmLaunchZoneVisible,
              AgmLaunchZoneYawMin, AgmLaunchZoneYawMax,
              AgmLaunchZonePitchMin, AgmLaunchZonePitchMax,
              colorWatch
            ]
            commands = getAgmLaunchAngularRangeCommands(IsAgmLaunchZoneVisible.value, AgmLaunchZoneYawMin.value, AgmLaunchZoneYawMax.value,
              AgmLaunchZonePitchMin.value, AgmLaunchZonePitchMax.value)
            animations = [{ prop = AnimProp.opacity, from = 1, to = 0, duration = 0.5, play = atgmLaunchZoneBlinking.value,
              loop = true, easing = InOutSine, trigger = atgmLaunchZoneTrigger}]
          }) : null,
      isAtgmGuidanceRangeVisible.value
        ? @() styleLineForeground.__merge({
            rendObj = ROBJ_VECTOR_CANVAS
            lineWidth = hdpx(LINE_WIDTH)
            size = [aspect * width, height]
            watch = [
              IsAgmLaunchZoneVisible,
              AgmRotatedLaunchZoneYawMax, AgmRotatedLaunchZoneYawMin,
              AgmRotatedLaunchZonePitchMax, AgmRotatedLaunchZonePitchMin,
              colorWatch
            ]
            color = colorWatch.value
            commands = getAgmGuidanceRangeCommands(IsAgmLaunchZoneVisible.value, AgmRotatedLaunchZoneYawMin.value, AgmRotatedLaunchZoneYawMax.value,
              AgmRotatedLaunchZonePitchMin.value, AgmRotatedLaunchZonePitchMax.value)
            animations = [{ prop = AnimProp.opacity, from = 1, to = 0, duration = 0.5, play = atgmLaunchZoneBlinking.value,
              loop = true, easing = InOutSine, trigger = atgmLaunchZoneTrigger}]
          }) : null,
        isAtgmGuidanceRangeVisible.value
          ? @() styleLineForeground.__merge({
              rendObj = ROBJ_VECTOR_CANVAS
              lineWidth = hdpx(LINE_WIDTH + 1)
              size = [aspect * width, height]
              color = colorWatch.value
              watch = [
                IsAgmLaunchZoneVisible,
                IsRangefinderEnabled, RangefinderDist,
                AgmLaunchZoneDistMin, AgmLaunchZoneDistMax,
                colorWatch
              ]
              commands = getAgmLaunchDistanceRangeCommands(IsAgmLaunchZoneVisible.value, IsRangefinderEnabled.value,
                AgmLaunchZoneDistMin.value, AgmLaunchZoneDistMax.value, RangefinderDist.value)
              animations = [{ prop = AnimProp.opacity, from = 1, to = 0, duration = 0.5, play = atgmLaunchDistanceblinking.value,
                loop = true, easing = InOutSine, trigger = atgmLaunchDistanceTrigger}]
            }) : null
    ]
  })
}

local lockSightComponent = function(colorWatch, width, height, posX, posY, is_background) {
  local color = Computed(@() !is_background && IsAgmEmpty.value ? AlertColorHigh.value
    : is_background ? backgroundColor
    : colorWatch.value)
  return lockSight(color, width, height, posX, posY)
}

local function helicopterRocketSightMode(sightMode){

  if (sightMode == 0) {
    return [
      [VECTOR_LINE, -100, 0, 100, 0],
      [VECTOR_LINE, -100, 200, 100, 200],
      [VECTOR_LINE, -20, 0, -20, 200],
      [VECTOR_LINE, 20, 0, 20, 200],
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

local helicopterRocketAim = @(width, height, isBackground, color, style = styleLineForeground) function() {

  local lines = helicopterRocketSightMode(RocketSightMode.value)

  return style.__merge({
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    rendObj = ROBJ_VECTOR_CANVAS
    size = [width, height]
    color
    watch = [RocketAimX, RocketAimY, RocketAimVisible, RocketSightMode]
    opacity = RocketAimVisible.value ? 100 : 0
    transform = {
      translate = [RocketAimX.value, RocketAimY.value]
    }
    commands = lines
  })
}

local turretAnglesAspect = 2.0
local turretAnglesComponent = function(colorWatch, width, height, posX, posY, isBackground) {
  return {
    pos = [posX - turretAnglesAspect * width * 0.5, posY - height]
    size = SIZE_TO_CONTENT
    children = turretAngles(colorWatch, width, height, turretAnglesAspect, isBackground)
  }
}

local function agmLaunchZone(w, h, isBackground)  {

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

  return @() styleLineForeground.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    size = flex()
    color = HudColor.value
    watch = [ IsAgmLaunchZoneVisible,
      AgmLaunchZoneYawMin, AgmLaunchZoneYawMax,
      AgmLaunchZonePitchMin, AgmLaunchZonePitchMax,
      TurretYaw, TurretPitch, IsZoomedAgmLaunchZoneVisible,
      HudColor
    ]
    commands = IsZoomedAgmLaunchZoneVisible.value ? maxAngleBorder() : []
  })
}

local sight = function(colorWatch, height, isBackground) {
  local longL = 22
  local shortL = 10
  local dash = 0.8
  local centerOffset = 3

  return @() styleLineForeground.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [height, height]
    color = colorWatch.value
    watch = colorWatch
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

local sightComponent = function(colorWatch, centerX, centerY, height, isBackground) {
  return {
    pos = [centerX - height * 0.5, centerY - height * 0.5]
    size = SIZE_TO_CONTENT
    children = sight(colorWatch, height, isBackground)
  }
}

local function launchDistanceMaxComponent(colorWatch, width, height, posX, posY, isBackground) {

  local getAgmLaunchDistanceMax = function() {
    return IsAgmLaunchZoneVisible.value ?
      ::cross_call.measureTypes.DISTANCE_SHORT.getMeasureUnitsText(AgmLaunchZoneDistMax.value) : ""
  }

  local launchDistanceMax = @() styleText.__merge({
    rendObj = ROBJ_DTEXT
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    color = colorWatch.value
    text = getAgmLaunchDistanceMax()
    watch = [
      IsAgmLaunchZoneVisible,
      AgmLaunchZoneDistMax,
      colorWatch
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

local function rangeFinderComponent(colorWatch, posX, posY, isBackground) {
  local rangefinder = @() styleText.__merge({
    rendObj = ROBJ_DTEXT
    halign = ALIGN_CENTER
    text = ::cross_call.measureTypes.DISTANCE_SHORT.getMeasureUnitsText(RangefinderDist.value)
    opacity = IsRangefinderEnabled.value ? 100 : 0
    color = colorWatch.value
    watch = [RangefinderDist, IsRangefinderEnabled, colorWatch]
  })

  local resCompoment = @() {
    pos = [posX, posY]
    halign = ALIGN_CENTER
    size = [0, 0]
    children = rangefinder
  }

  return resCompoment
}

local triggerTATarget = {}
TargetAge.subscribe(@(v) v < 0.2 ? ::anim_request_stop(triggerTATarget) : ::anim_start(triggerTATarget))
local HelicopterTATarget = @(w, h, isBackground) function() {

  local res = {
    watch = [TATargetVisible, TargetX, TargetY, IsTargetTracked,
      TargetAge, AlertColorHigh, IsLaserDesignatorEnabled]
    animations = [{ prop = AnimProp.opacity, from = 0, to = 1, duration = 0.5, play = TargetAge.value > 0.2, loop = true, easing = InOutSine, trigger = triggerTATarget}]
    key = TargetAge
  }

  if (!TATargetVisible.value && TargetAge.value < 0.2)
    return res

  // border
  local taTargetcommands = [
    [VECTOR_LINE, -10, -10, 10, -10],
    [VECTOR_LINE, 10, -10, 10, 10],
    [VECTOR_LINE, 10, 10, -10, 10],
    [VECTOR_LINE, -10, 10, -10, -10]
  ]

  if (IsTargetTracked.value) {
    taTargetcommands.append([VECTOR_LINE, -5, 0, -10, 0])
    taTargetcommands.append([VECTOR_LINE, 5, 0, 10, 0])
    taTargetcommands.append([VECTOR_LINE, 0, -5, 0, -10])
    taTargetcommands.append([VECTOR_LINE, 0, 5, 0, 10])
  }

  if (IsLaserDesignatorEnabled.value) {
    taTargetcommands.append([VECTOR_LINE, -2, -2, 2, -2])
    taTargetcommands.append([VECTOR_LINE, 2, -2, 2, 2])
    taTargetcommands.append([VECTOR_LINE, 2, 2, -2, 2])
    taTargetcommands.append([VECTOR_LINE, -2, 2, -2, -2])
  }

  return res.__update({
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    rendObj = ROBJ_VECTOR_CANVAS
    size = [w, h]
    color = AlertColorHigh.value
    transform = {
      translate = [TargetX.value, TargetY.value]
    }
    commands = taTargetcommands
  })
}

local targetSizeComponent = function(colorWatch, width, height) {
  return @() {
    pos = [0, 0]
    size = SIZE_TO_CONTENT
    watch = IsMfdEnabled
    children = targetSize(colorWatch, width, height, IsMfdEnabled.value)
  }
}

local detectAllyComponent = @(posX, posY, isBackground) function(){

  local res = {watch = [DetectAllyProgress, DetectAllyState]}
  if (DetectAllyProgress.value < 1.0)
    return res

  return res.__update(styleText.__merge({
    rendObj = ROBJ_DTEXT
    text = DetectAllyProgress.value < 1.0 ? ::loc("detect_ally_progress")
      : (DetectAllyState.value ? ::loc("detect_ally_success")
      : ::loc("detect_ally_fail"))
    pos = [posX, posY]
    size = SIZE_TO_CONTENT
  }))
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