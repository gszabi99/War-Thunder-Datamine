from "%rGui/globals/ui_library.nut" import *
let cross_call = require("%rGui/globals/cross_call.nut")

let { floor, round_by_value } = require("%sqstd/math.nut")
let string = require("string")

let { CannonMode, CannonSelectedArray, CannonSelected, CannonReloadTime, CannonCount, IsCannonEmpty,
  OilTemperature, OilState, WaterTemperature, WaterState, EngineTemperature, EngineState,
  EngineAlert, TransmissionOilState, IsTransmissionOilAlert, Fuel, HasExternalFuel, ExternalFuel, FuelState, IsCompassVisible,
  IsMachineGunsEmpty, MachineGunsSelectedArray, MachineGunsCount, MachineGunsReloadTime, MachineGunsMode,
  CannonsAdditionalCount, CannonsAdditionalSeconds, CannonsAdditionalMode, CannonsAdditionalSelected, IsCanAdditionalEmpty,
  AgmCount, AgmSeconds, AgmTimeToHit, AgmTimeToWarning, AgmActualCount, AgmName, AgmSelected, IsAgmEmpty,
  AamCount, AamSeconds, AamActualCount, AamName, AamSelected, IsAamEmpty,
  GuidedBombsCount, GuidedBombsSeconds, GuidedBombsActualCount, GuidedBombsName, GuidedBombsSelected, IsGuidedBmbEmpty,
  FlaresCount, FlaresSeconds, FlaresMode, IsFlrEmpty,
  ChaffsCount, ChaffsSeconds, ChaffsMode, IsChaffsEmpty,
  RocketsCount, RocketsSeconds, RocketsActualCount, RocketsSalvo, RocketsMode, RocketsName, RocketsSelected, IsRktEmpty,
  IsSightHudVisible, DetectAllyProgress, DetectAllyState,
  BombsCount, BombsSeconds, BombsActualCount, BombsSalvo, BombsMode, BombsName, BombsSelected, IsBmbEmpty,
  IsTrpEmpty, TorpedoesCount, TorpedoesSeconds, TorpedoesActualCount, TorpedoesSalvo, TorpedoesMode, TorpedoesName, TorpedoesSelected,
  IsHighRateOfFire, IsInsideLaunchZoneYawPitch, AgmLaunchZoneYawMin,
  AgmLaunchZonePitchMin, AgmLaunchZonePitchMax, AgmLaunchZoneYawMax, AgmRotatedLaunchZoneYawMin, AgmRotatedLaunchZoneYawMax,
  AgmRotatedLaunchZonePitchMax, AgmRotatedLaunchZonePitchMin, TurretPitch, TurretYaw, IsZoomedAgmLaunchZoneVisible,
  IsAgmLaunchZoneVisible, AgmLaunchZoneDistMax, IsRangefinderEnabled, RangefinderDist,
  Rpm, IsRpmVisible, IsRpmCritical, TrtMode, Trt, Spd, WaterAlert, HorAngle, AgmLaunchZoneDistMin,
  AlertColorLow, AlertColorMedium, AlertColorHigh, OilAlert,
  PassivColor, IsLaserDesignatorEnabled, IsInsideLaunchZoneDist, GunInDeadZone,
  RocketSightMode, RocketAimVisible, StaminaValue, StaminaState,
  RocketAimX, RocketAimY, TATargetVisible, IRCMState,
  Mach, CritMach, Ias, CritIas, InstructorState, InstructorForced, IsEnginesControled, ThrottleState, isEngineControled,
  DistanceToGround, IsMfdEnabled, VerticalSpeed, MfdColor,
  ParamTableShadowFactor, ParamTableShadowOpacity, isCannonJamed
} = require("airState.nut")

let { isColorOrWhite, isDarkColor, styleText, styleLineForeground, fontOutlineFxFactor, fadeColor } = require("style/airHudStyle.nut")

let { IsTargetTracked, TargetAge, TargetX, TargetY } = require("%rGui/hud/targetTrackerState.nut")
let { lockSight, targetSize } = require("%rGui/hud/targetTracker.nut")

let { isInitializedMeasureUnits, measureUnitsNames } = require("options/optionsMeasureUnits.nut")

let { GuidanceLockResult } = require("%rGui/guidanceConstants.nut")

let aamGuidanceLockState = require("rocketAamAimState.nut").GuidanceLockState

let agmAimState = require("agmAimState.nut")
let agmGuidanceLockState = agmAimState.GuidanceLockState
let agmGuidancePointIsTarget = agmAimState.PointIsTarget
let guidedBombsAimState =  require("guidedBombsAimState.nut")
let guidedBombsGuidanceLockState = guidedBombsAimState.GuidanceLockState
let guidedBombsGuidancePointIsTarget = guidedBombsAimState.PointIsTarget
let compass = require("compass.nut")

const NUM_VISIBLE_ENGINES_MAX = 6
const NUM_TRANSMISSIONS_MAX = 6
const NUM_CANNONS_MAX = 3

let verticalSpeedInd = function(height, style, color) {
  return style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    color
    size = [height, height]
    pos = [0, -height * 0.25]
    commands = [
      [VECTOR_LINE, 0, 25, 100, 50, 100, 0, 0, 25],
    ]
  })
}

let verticalSpeedScale = function(width, height, style, color) {
  let part1_16 = 0.0625 * 100
  let lineStart = 70

  return style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [width, height]
    color
    halign = ALIGN_RIGHT
    commands = [
      [VECTOR_LINE, 0,         0,           100, 0],
      [VECTOR_LINE, lineStart, part1_16,    100, part1_16],
      [VECTOR_LINE, lineStart, 2 * part1_16,  100, 2 * part1_16],
      [VECTOR_LINE, lineStart, 3 * part1_16,  100, 3 * part1_16],
      [VECTOR_LINE, 0,         25,          100, 25],
      [VECTOR_LINE, lineStart, 5 * part1_16,  100, 5 * part1_16],
      [VECTOR_LINE, lineStart, 6 * part1_16,  100, 6 * part1_16],
      [VECTOR_LINE, lineStart, 7 * part1_16,  100, 7 * part1_16],
      [VECTOR_LINE, 0,         50,          100, 50],
      [VECTOR_LINE, lineStart, 9 * part1_16,  100, 9 * part1_16],
      [VECTOR_LINE, lineStart, 10 * part1_16, 100, 10 * part1_16],
      [VECTOR_LINE, lineStart, 11 * part1_16, 100, 11 * part1_16],
      [VECTOR_LINE, 0,         75,          100, 75],
      [VECTOR_LINE, lineStart, 13 * part1_16, 100, 13 * part1_16],
      [VECTOR_LINE, lineStart, 14 * part1_16, 100, 14 * part1_16],
      [VECTOR_LINE, lineStart, 15 * part1_16, 100, 15 * part1_16],
      [VECTOR_LINE, 0,         100,         100, 100],
    ]
  })
}

let function HelicopterVertSpeed(scaleWidth, height, posX, posY, color, elemStyle = styleText) {

  let relativeHeight = Computed(@() clamp(DistanceToGround.value * 2.0, 0, 100))

  return {
    pos = [posX, posY]
    children = [
      {
        children = verticalSpeedScale(scaleWidth, height, elemStyle, color)
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
        size = [-0.5 * scaleWidth, height]
        children = @() elemStyle.__merge({
          rendObj = ROBJ_TEXT
          halign = ALIGN_RIGHT
          color
          size = [scaleWidth * 4, SIZE_TO_CONTENT]
          watch = [DistanceToGround, IsMfdEnabled]
          text = IsMfdEnabled.value ? floor(DistanceToGround.value).tostring() :
            cross_call.measureTypes.ALTITUDE.getMeasureUnitsText(DistanceToGround.value)
        })
      }
      @() {
        watch = VerticalSpeed
        pos = [scaleWidth + sh(0.5), 0]
        transform = {
          translate = [0, height * 0.01 * clamp(50 - VerticalSpeed.value * 5.0, 0, 100)]
        }
        children = [
          verticalSpeedInd(hdpx(25), elemStyle, color),
          {
            pos = [scaleWidth + hdpx(10), hdpx(-10)]
            children = @() elemStyle.__merge({
              rendObj = ROBJ_TEXT
              color
              size = [scaleWidth * 4, SIZE_TO_CONTENT]
              watch = [VerticalSpeed, IsMfdEnabled]
              text = IsMfdEnabled.value ?
                round_by_value(VerticalSpeed.value, 1).tostring() :
                cross_call.measureTypes.CLIMBSPEED.getMeasureUnitsText(VerticalSpeed.value)
            })
          }
        ]
      }
    ]
  }
}

let function generateBulletsTextFunction(count, seconds, salvo = 0, actualCount = -1) {
  local txts = []
  if (seconds >= 0) {
    txts = [string.format("%d:%02d", floor(seconds / 60), seconds % 60)]
    if (count > 0)
      txts.append(" (", count, ")  ")
    return "".join(txts)
  }
  else if (count >= 0) {
    txts = [count]
    if (actualCount >= 0)
      txts.append("/", actualCount)
    if (salvo > 0)
      txts.append(" [", salvo, "]  ")
    else if (salvo == -1)
      txts.append(" [S]  ")
  }
  return "".join(txts)
}

let generateRpmTitleFunction = function(trtMode) {
  local txts = []
  if (trtMode < AirThrottleMode.AIRCRAFT_DEFAULT_MODE)
    txts = [loc("HUD/PROP_RPM_SHORT")]

  return "".join(txts)
}


let generateRpmTextFunction = function(trtMode, rpmValue) {
  local txts = []
  if (trtMode < AirThrottleMode.AIRCRAFT_DEFAULT_MODE)
    txts = [string.format("%d %%", rpmValue)]

  return "".join(txts)
}

let generateAgmBulletsTextFunction = function(count, seconds, timeToHit, _timeToWarning, actualCount = 0) {
  local txts = []
  if (seconds >= 0) {
    txts = [string.format("%d:%02d", floor(seconds / 60), seconds % 60)]
    if (count > 0)
      txts.append(" (", count, ")")
    return "".join(txts)
  }
  else if (count >= 0)
    txts = [count]
  if (actualCount >= 0)
    txts.append("/", actualCount)
  if (timeToHit > 0)
    txts.append(string.format("[%d]", timeToHit))
  return "".join(txts)
}

let generateTemperatureTextFunction = function(temperature, state, temperatureUnits) {
  if (state == TemperatureState.OVERHEAT)
    return ("".concat(temperature, loc(temperatureUnits)))
  else if (state == TemperatureState.EMPTY_TANK)
    return (loc("HUD_TANK_IS_EMPTY"))
  else if (state == TemperatureState.FUEL_LEAK)
    return (loc("HUD_FUEL_LEAK"))
  else if (state == TemperatureState.FUEL_SEALING)
    return  (loc("HUD_TANK_IS_SEALING"))
  else if (state == TemperatureState.BLANK)
    return ""

  return ""
}

let generateTransmissionStateTextFunction = function(oilState) {
  if (oilState > 0.01)
    return loc("HUD_FUEL_LEAK")
  else
  return loc("HUD_TANK_IS_EMPTY")
  return ""
}

let function getThrottleText(mode, trt) {
  if (mode == AirThrottleMode.DEFAULT_MODE
    || mode == AirThrottleMode.CLIMB
    || mode == AirThrottleMode.AIRCRAFT_DEFAULT_MODE)
    return string.format("%d %%", trt)
  else if (mode == AirThrottleMode.BRAKE
    || mode == AirThrottleMode.AIRCRAFT_BRAKE)
    return loc("HUD/BRAKE_SHORT")
  else if (mode == AirThrottleMode.WEP
    || mode == AirThrottleMode.AIRCRAFT_WEP)
    return loc("HUD/WEP_SHORT")
  return ""
}


let function getThrottleCaption(mode, isControled, idx) {
  let texts = []
  if (mode == AirThrottleMode.AIRCRAFT_DEFAULT_MODE
  || mode == AirThrottleMode.AIRCRAFT_WEP
  || mode == AirThrottleMode.AIRCRAFT_BRAKE)
    texts.append(loc("HUD/THROTTLE_SHORT"))
  else if (mode == AirThrottleMode.CLIMB)
    texts.append(loc("HUD/CLIMB_SHORT"))
  else
    texts.append(loc("HUD/PROP_PITCH_SHORT"))
  if (isControled == true)
    texts.append(string.format("_%d", (idx + 1)))
  return "".join(texts)
}

let function getAGCaption(guidanceLockState, pointIsTarget) {
  let texts = []
  if (guidanceLockState == GuidanceLockResult.RESULT_INVALID)
    texts.append(loc("HUD/TXT_AGM_SHORT"))
  else if (guidanceLockState == GuidanceLockResult.RESULT_STANDBY)
    texts.append(loc("HUD/TXT_AGM_STANDBY"))
  else if (guidanceLockState == GuidanceLockResult.RESULT_WARMING_UP)
    texts.append(loc("HUD/TXT_AGM_WARM_UP"))
  else if (guidanceLockState == GuidanceLockResult.RESULT_LOCKING)
    texts.append(loc("HUD/TXT_AGM_LOCK"))
  else if (guidanceLockState == GuidanceLockResult.RESULT_TRACKING)
    texts.append(loc(!pointIsTarget ? "HUD/TXT_AGM_TRACK" : "HUD/TXT_AGM_TRACK_POINT"))
  else if (guidanceLockState == GuidanceLockResult.RESULT_LOCK_AFTER_LAUNCH)
    texts.append(loc("HUD/TXT_AGM_LOCK_AFTER_LAUNCH"))
  return "".join(texts)
}

let function getAACaption(guidanceLockState) {
  let texts = []
  if (guidanceLockState == GuidanceLockResult.RESULT_INVALID)
    texts.append(loc("HUD/TXT_AAM_SHORT"))
  else if (guidanceLockState == GuidanceLockResult.RESULT_STANDBY)
    texts.append(loc("HUD/TXT_AAM_STANDBY"))
  else if (guidanceLockState == GuidanceLockResult.RESULT_WARMING_UP)
    texts.append(loc("HUD/TXT_AAM_WARM_UP"))
  else if (guidanceLockState == GuidanceLockResult.RESULT_LOCKING)
    texts.append(loc("HUD/TXT_AAM_LOCK"))
  else if (guidanceLockState == GuidanceLockResult.RESULT_TRACKING)
    texts.append(loc("HUD/TXT_AAM_TRACK"))
  else if (guidanceLockState == GuidanceLockResult.RESULT_LOCK_AFTER_LAUNCH)
    texts.append(loc("HUD/TXT_AAM_LOCK_AFTER_LAUNCH"))
  return "".join(texts)
}

let function getGBCaption(guidanceLockState, pointIsTarget) {
  let texts = []
  if (guidanceLockState == GuidanceLockResult.RESULT_INVALID)
    texts.append(loc("HUD/TXT_GUIDED_BOMBS_SHORT"))
  else if (guidanceLockState == GuidanceLockResult.RESULT_STANDBY)
    texts.append(loc("HUD/TXT_GUIDED_BOMBS_STANDBY"))
  else if (guidanceLockState == GuidanceLockResult.RESULT_WARMING_UP)
    texts.append(loc("HUD/TXT_GUIDED_BOMBS_WARM_UP"))
  else if (guidanceLockState == GuidanceLockResult.RESULT_LOCKING)
    texts.append(loc("HUD/TXT_GUIDED_BOMBS_LOCK"))
  else if (guidanceLockState == GuidanceLockResult.RESULT_TRACKING)
    texts.append(loc(!pointIsTarget ? "HUD/TXT_GUIDED_BOMBS_TRACK" : "HUD/TXT_GUIDED_BOMBS_POINT_TRACK"))
  else if (guidanceLockState == GuidanceLockResult.RESULT_LOCK_AFTER_LAUNCH)
    texts.append(loc("HUD/TXT_GUIDED_BOMBS_LOCK_AFTER_LAUNCH"))
  return "".join(texts)
}

let function getCountermeasuresCaption(isFlare, mode) {
  let texts = isFlare ? [loc("HUD/FLARES_SHORT"), " "] : [loc("HUD/CHAFFS_SHORT"), " "]
  if (mode & CountermeasureMode.PERIODIC_COUNTERMEASURE)
    texts.append(loc("HUD/COUNTERMEASURE_PERIODIC"))
  if (mode == (CountermeasureMode.PERIODIC_COUNTERMEASURE | CountermeasureMode.MLWS_SLAVED_COUNTERMEASURE))
    texts.append(loc("HUD/INDICATION_MODE_SEPARATION"))
  if (mode & CountermeasureMode.MLWS_SLAVED_COUNTERMEASURE)
    texts.append(loc("HUD/COUNTERMEASURE_MLWS"))
  return "".join(texts)
}

let function getModeCaption(mode) {
  let texts = []
  if ((mode & (1 << WeaponMode.CCIP_MODE)) && (mode & (1 << WeaponMode.CCRP_MODE)))
    texts.append(loc("HUD/WEAPON_MODE_CCIP_CCRP"))
  else if (mode & (1 << WeaponMode.CCIP_MODE))
    texts.append(loc("HUD/WEAPON_MODE_CCIP"))
  else if (mode & (1 << WeaponMode.CCRP_MODE))
    texts.append(loc("HUD/WEAPON_MODE_CCRP"))

  //check both ccip/rp and bombBay
  let ballisticModeBits = mode & (1 << (WeaponMode.CCRP_MODE + 1))
  if (ballisticModeBits > 0 && (mode ^ ballisticModeBits) > 0)
    texts.append("  ")

  if (mode & (1 << WeaponMode.BOMB_BAY_OPEN))
    texts.append(loc("HUD/BAY_DOOR_IS_OPEN_INDICATION"))
  if (mode & (1 << WeaponMode.BOMB_BAY_CLOSED))
    texts.append(loc("HUD/BAY_DOOR_IS_CLOSED_INDICATION"))
  if (mode & (1 << WeaponMode.BOMB_BAY_OPENING))
    texts.append(loc("HUD/BAY_DOOR_IS_OPENING_INDICATION"))
  if (mode & (1 << WeaponMode.BOMB_BAY_CLOSING))
    texts.append(loc("HUD/BAY_DOOR_IS_CLOSING_INDICATION"))

  return "".join(texts)
}

let function getMachineGunCaption(mode) {
  let texts = [loc("HUD/MACHINE_GUNS_SHORT"), " "]
  texts.append(getModeCaption(mode))
  return "".join(texts)
}

let function getAdditionalCannonCaption(mode) {
  let texts = [loc("HUD/ADDITIONAL_GUNS_SHORT"), " "]
  texts.append(getModeCaption(mode))
  return "".join(texts)
}

let function getRocketCaption(mode) {
  let texts = [loc("HUD/RKT"), " "]
  texts.append(getModeCaption(mode))
  return "".join(texts)
}

let function getBombCaption(mode) {
  let texts = [loc("HUD/BOMBS_SHORT"), " "]
  texts.append(getModeCaption(mode))
  return "".join(texts)
}

let function getTorpedoCaption(mode) {
  let texts = [loc("HUD/TORPEDOES_SHORT"), " "]
  texts.append(getModeCaption(mode))
  return "".join(texts)
}

let function getCannonsCaption(mode) {
  let texts = [loc("HUD/CANNONS_SHORT"), " "]
  texts.append(getModeCaption(mode))
  return "".join(texts)
}

let function getIRCMCaption(state) {
  let texts = []
  if (state == IRCMMode.IRCM_ENABLED)
    texts.append(loc("controls/on"))
  else if (state == IRCMMode.IRCM_DAMAGED)
    texts.append(loc("controls/dmg"))
  else if (state == IRCMMode.IRCM_DISABLED)
    texts.append(loc("controls/off"))
  return "".join(texts)
}

let function getInstructorCaption(isInstructorForced) {
  return isInstructorForced ? loc("HUD_INSTRUCTOR_FORCED") : loc("HUD_INSTRUCTOR")
}

let function getThrottleValueState(state, controled) {
  return controled ? state : HudColorState.PASSIV
}

let function getThrottleState(controled) {
  return controled ? HudColorState.ACTIV : HudColorState.PASSIV
}

let function getStaminaValue(stamina) {
  return string.format("%d %%", stamina)
}

let function getFuelState(fuel, hasExternalFuel, externalFuel, fuelState) {
  if (fuelState == TemperatureState.FUEL_LEAK)
    return loc("HUD_FUEL_LEAK")
  if (fuelState == TemperatureState.FUEL_SEALING)
    return loc("HUD_TANK_IS_SEALING")
  if (fuelState == TemperatureState.EMPTY_TANK)
    return loc("HUD_TANK_IS_EMPTY")
  local val = string.format("%d:%02d", floor(fuel / 60), fuel % 60)
  if (hasExternalFuel)
    val = " ".concat(val, string.format(" / %d:%02d", floor(externalFuel / 60), externalFuel % 60))
  return val
}

let function getFuelAlertState(fuelState) {
  return fuelState >= TemperatureState.FUEL_LEAK ? HudColorState.HIGH_ALERT :
         fuelState == TemperatureState.OVERHEAT ? HudColorState.PASSIV :
         fuelState == TemperatureState.EMPTY_TANK ? HudColorState.PASSIV : HudColorState.ACTIV
}

let function createParam(param, width, height, style, colorWatch, needCaption, for_ils, isBomberView) {
  let { blinkComputed = null, blinkTrigger = null, valueComputed, selectedComputed,
    additionalComputed, titleComputed, alertStateCaptionComputed, alertValueStateComputed } = param

  let selectColor = function(state, activeColor, passivColor, lowAlertColor, mediumAlertColor, highAlertColor) {
    return (state == HudColorState.PASSIV) ? passivColor
      : (state == HudColorState.LOW_ALERT) ? lowAlertColor
      : (state == HudColorState.MEDIUM_ALERT) ? mediumAlertColor
      : (state == HudColorState.HIGH_ALERT) ? highAlertColor
      : isBomberView ? isColorOrWhite(activeColor)
      : activeColor
  }

  let selectFxColor = function(state, activeColor, opacity) {
    return (state == HudColorState.ACTIV) ? isDarkColor(activeColor)
      ? Color(255, 255, 255, opacity * 255) : Color(0, 0, 0, opacity * 255)
      : Color(0, 0, 0, opacity * 255)
  }

  let selectFxFactor = function(state, activeColor, factor) {
    return (state == HudColorState.ACTIV) ? isDarkColor(activeColor)
    ? fontOutlineFxFactor * 0.15 * factor  : fontOutlineFxFactor * factor
    : fontOutlineFxFactor * factor
  }

  let colorAlertCaptionW = Computed(@() fadeColor(selectColor(alertStateCaptionComputed.value, colorWatch.value, PassivColor.value,
    AlertColorLow.value, AlertColorMedium.value, AlertColorHigh.value), 255))

  let colorFxCaption = Computed(@() selectFxColor(alertStateCaptionComputed.value, colorWatch.value, ParamTableShadowOpacity.value))

  let factorFxCaption = Computed(@() selectFxFactor(alertStateCaptionComputed.value, colorWatch.value, ParamTableShadowFactor.value))

  let captionComponent = @() style.__merge({
    watch = [titleComputed, colorAlertCaptionW, alertStateCaptionComputed, colorFxCaption, factorFxCaption]
    rendObj = ROBJ_TEXT
    size = [SIZE_TO_CONTENT, height]
    margin = [0, 0.06 * width, 0, 0]
    minWidth = 0.2 * width
    text = titleComputed.value
    color = colorAlertCaptionW.value
    fontFxColor = colorFxCaption.value
    fontFxFactor = factorFxCaption.value
    opacity =  alertStateCaptionComputed.value >= HudColorState.LOW_ALERT ? 0.7 : 1.0
  })

  let selectedComponent = @() style.__merge({
    watch = [selectedComputed, colorAlertCaptionW, colorFxCaption]
    rendObj = ROBJ_TEXT
    size = [0.05 * width, height]
    text = selectedComputed.value
    color = colorAlertCaptionW.value
    fontFxColor = colorFxCaption.value
    fontFxFactor = factorFxCaption.value
    opacity =  alertStateCaptionComputed.value >= HudColorState.LOW_ALERT ? 0.7 : 1.0
  })

  let valueColor = Computed(@() for_ils ? MfdColor.value : selectColor(alertValueStateComputed.value, colorWatch.value, PassivColor.value,
    AlertColorLow.value, AlertColorMedium.value, AlertColorHigh.value))

  let colorFxValue = Computed(@() selectFxColor(alertValueStateComputed.value, colorWatch.value, ParamTableShadowOpacity.value))

  let factorFxValue = Computed(@() selectFxFactor(alertValueStateComputed.value, colorWatch.value, ParamTableShadowFactor.value))

  let valueComponent = @() style.__merge({
    watch = [valueComputed, alertValueStateComputed, valueColor, colorFxValue, factorFxValue]
    color = fadeColor(valueColor.value, 255)
    rendObj = ROBJ_TEXT
    size = [SIZE_TO_CONTENT, height]
    padding = [0, 0.075 * width, 0, 0]
    text = valueComputed.value
    opacity =  alertValueStateComputed.value >= HudColorState.LOW_ALERT ? 0.7 : 1.0
    fontFxFactor = factorFxValue.value
    fontFxColor = colorFxValue.value
  })

  let additionalComponent = @() style.__merge({
    watch = [additionalComputed, colorWatch, ParamTableShadowFactor, ParamTableShadowOpacity]
    color = fadeColor(colorWatch.value, 255)
    rendObj = ROBJ_TEXT
    size = [0.7 * width, height]
    text = additionalComputed.value
    fontFxFactor = isDarkColor(colorWatch.value) ?
      fontOutlineFxFactor * 0.15 * ParamTableShadowFactor.value
      : fontOutlineFxFactor * ParamTableShadowFactor.value
    fontFxColor = isDarkColor(colorWatch.value)
      ? Color(255, 255, 255, 255 * ParamTableShadowOpacity.value)
      : Color(0, 0, 0, 255 * ParamTableShadowOpacity.value)
  })

  return {
    flow = FLOW_HORIZONTAL
    animations = [{ prop = AnimProp.opacity, from = 0, to = 1, duration = 0.5, play = blinkComputed?.value, loop = true, easing = InOutCubic, trigger = blinkTrigger }]
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
let TrtModeForRpm = TrtMode[0]

let agmBlinkComputed = Computed(@() (IsSightHudVisible.value && IsAgmLaunchZoneVisible.value &&
  (!IsInsideLaunchZoneYawPitch.value || (IsRangefinderEnabled.value && !IsInsideLaunchZoneDist.value))))
let agmBlinkTrigger = {}
agmBlinkComputed.subscribe(@(v) v ? anim_start(agmBlinkTrigger) : anim_request_stop(agmBlinkTrigger))

let textParamsMapMain = {
  [AirParamsMain.RPM] = {
    titleComputed = Computed (@() IsRpmVisible.value ? generateRpmTitleFunction(TrtModeForRpm.value) : "")
    valueComputed = Computed (@() IsRpmVisible.value ? generateRpmTextFunction(TrtModeForRpm.value, Rpm.value) : "")
    selectedComputed = Computed (@() "")
    additionalComputed = Computed (@() "")
    alertStateCaptionComputed = Computed(@() IsRpmCritical.value ? HudColorState.HIGH_ALERT : HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() IsRpmCritical.value ? HudColorState.HIGH_ALERT : HudColorState.ACTIV)
  },
  [AirParamsMain.IAS_HUD] = {
    titleComputed = Computed (@() loc("HUD/INDICATED_AIR_SPEED_SHORT"))
    valueComputed = Computed (@()  !isInitializedMeasureUnits.value ? "" : " ".concat(Ias.value, loc(measureUnitsNames.value.speed)))
    selectedComputed = Computed (@() "")
    additionalComputed = Computed (@() "")
    alertStateCaptionComputed = Computed(@() CritIas.value ? HudColorState.HIGH_ALERT : HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() CritIas.value ? HudColorState.HIGH_ALERT : HudColorState.ACTIV)
  },
  [AirParamsMain.SPEED] = {
    titleComputed = Computed (@() loc("HUD/REAL_SPEED_SHORT"))
    valueComputed = Computed (@() !isInitializedMeasureUnits.value ? "" : " ".concat(Spd.value, loc(measureUnitsNames.value.speed)))
    selectedComputed = Computed (@() "")
    additionalComputed = Computed (@() "")
    alertStateCaptionComputed = Computed(@() HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() HudColorState.ACTIV)
  },
  [AirParamsMain.MACH] = {
    titleComputed = Computed(@() loc("HUD/TXT_MACH_SHORT"))
    valueComputed = Computed (@() string.format("%.2f", Mach.value))
    selectedComputed = Computed (@() "")
    additionalComputed = Computed (@() "")
    alertStateCaptionComputed = Computed(@() CritMach.value ? HudColorState.HIGH_ALERT : HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() CritMach.value ? HudColorState.HIGH_ALERT : HudColorState.ACTIV)
  },
  [AirParamsMain.ALTITUDE] = {
    titleComputed = Computed(@() loc("HUD/ALTITUDE_SHORT"))
    valueComputed = Computed (@() !isInitializedMeasureUnits.value ? "" : " ".concat(floor(DistanceToGround.value), loc(measureUnitsNames.value.alt)))
    selectedComputed = Computed (@() "")
    additionalComputed = Computed (@() "")
    alertStateCaptionComputed = Computed(@() HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() HudColorState.ACTIV)
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
    additionalComputed = Computed(@() loc(RocketsName.value))
    alertStateCaptionComputed = Computed(@() IsRktEmpty.value ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() IsRktEmpty.value ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
  },
  [AirParamsMain.AGM] = {
    titleComputed = Computed(@() AgmCount.value <= 0 ? loc("HUD/TXT_AGM_SHORT") :
      getAGCaption(agmGuidanceLockState.value, agmGuidancePointIsTarget.value))
    valueComputed = Computed(@() generateAgmBulletsTextFunction(AgmCount.value, AgmSeconds.value,
       AgmTimeToHit.value, AgmTimeToWarning.value, AgmActualCount.value))
    selectedComputed = Computed(@() AgmSelected.value ? ">" : "")
    additionalComputed = Computed(@() loc(AgmName.value))
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
    additionalComputed = Computed(@() loc(BombsName.value))
    alertStateCaptionComputed = Computed(@() IsBmbEmpty.value ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() IsBmbEmpty.value ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
  },
  [AirParamsMain.TORPEDO] = {
    titleComputed = Computed(@() getTorpedoCaption(TorpedoesMode.value))
    valueComputed = Computed(@() generateBulletsTextFunction(TorpedoesCount.value, TorpedoesSeconds.value,
      TorpedoesSalvo.value, TorpedoesActualCount.value))
    selectedComputed = Computed(@() TorpedoesSelected.value ? ">" : "")
    additionalComputed = Computed(@() loc(TorpedoesName.value))
    alertStateCaptionComputed = Computed(@() IsTrpEmpty.value ? HudColorState.HIGH_ALERT : HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() IsTrpEmpty.value ? HudColorState.HIGH_ALERT : HudColorState.ACTIV)
  },
  [AirParamsMain.RATE_OF_FIRE] = {
    titleComputed = Computed(@() loc("HUD/RATE_OF_FIRE_SHORT"))
    valueComputed = Computed(@() IsHighRateOfFire.value ? loc("HUD/HIGHFREQ_SHORT") : loc("HUD/LOWFREQ_SHORT"))
    selectedComputed = Computed (@() "")
    additionalComputed = Computed (@() "")
    alertStateCaptionComputed = Computed(@() HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() HudColorState.ACTIV)
  },
  [AirParamsMain.AAM] = {
    titleComputed = Computed(@() AamCount.value <= 0 ? loc("HUD/TXT_AAM_SHORT") : getAACaption(aamGuidanceLockState.value))
    valueComputed = Computed(@() generateBulletsTextFunction(AamCount.value, AamSeconds.value, 0, AamActualCount.value))
    selectedComputed = Computed(@() AamSelected.value ? ">" : "")
    additionalComputed = Computed(@() loc(AamName.value))
    alertStateCaptionComputed = Computed(@() (IsAamEmpty.value || aamGuidanceLockState.value == GuidanceLockResult.RESULT_TRACKING) ?
      HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() IsAamEmpty.value ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
  },
  [AirParamsMain.GUIDED_BOMBS] = {
    titleComputed = Computed(@() GuidedBombsCount.value <= 0 ? loc("HUD/TXT_GUIDED_BOMBS_SHORT") :
      getGBCaption(guidedBombsGuidanceLockState.value, guidedBombsGuidancePointIsTarget.value))
    valueComputed = Computed(@() generateBulletsTextFunction(GuidedBombsCount.value, GuidedBombsSeconds.value, 0, GuidedBombsActualCount.value))
    selectedComputed = Computed(@() GuidedBombsSelected.value ? ">" : "")
    additionalComputed = Computed(@() loc(GuidedBombsName.value))
    alertStateCaptionComputed = Computed(@() IsGuidedBmbEmpty.value ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() IsGuidedBmbEmpty.value ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
  },
  [AirParamsMain.FLARES] = {
    titleComputed = Computed(@() FlaresCount.value <= 0 ? loc("HUD/FLARES_SHORT") : getCountermeasuresCaption(true, FlaresMode.value))
    valueComputed = Computed(@() generateBulletsTextFunction(FlaresCount.value, FlaresSeconds.value))
    selectedComputed = Computed (@() "")
    additionalComputed = Computed (@() "")
    alertStateCaptionComputed = Computed(@() IsFlrEmpty.value ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() IsFlrEmpty.value ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
  },
  [AirParamsMain.CHAFFS] = {
    titleComputed = Computed(@() ChaffsCount.value <= 0 ? loc("HUD/CHAFFS_SHORT") : getCountermeasuresCaption(false, ChaffsMode.value))
    valueComputed = Computed(@() generateBulletsTextFunction(ChaffsCount.value, ChaffsSeconds.value))
    selectedComputed = Computed (@() "")
    additionalComputed = Computed (@() "")
    alertStateCaptionComputed = Computed(@() IsChaffsEmpty.value ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() IsChaffsEmpty.value ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
  },
  [AirParamsMain.IRCM] = {
    titleComputed = Computed(@() loc("HUD/IRCM_SHORT"))
    valueComputed = Computed(@() getIRCMCaption(IRCMState.value))
    selectedComputed = Computed (@() "")
    additionalComputed = Computed (@() "")
    alertStateCaptionComputed = Computed(@() HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() HudColorState.ACTIV)
    valuesWatched = IRCMState
  },
}

for (local i = 0; i < NUM_VISIBLE_ENGINES_MAX; ++i) {
  let trtModeComputed = TrtMode[i]
  let trtComputed = Trt[i]
  let isEngineControledComputed = isEngineControled[i]
  let throttleStateComputed = ThrottleState[i]
  let index = i
  textParamsMapMain[AirParamsMain.THROTTLE_1 + i] <- {
    titleComputed = Computed(@() getThrottleCaption(trtModeComputed.value, IsEnginesControled.value, index))
    valueComputed = Computed(@() getThrottleText(trtModeComputed.value, trtComputed.value))
    selectedComputed = Computed (@() "")
    additionalComputed = Computed (@() "")
    alertStateCaptionComputed = Computed(@() getThrottleState(isEngineControledComputed.value))
    alertValueStateComputed = Computed (@() getThrottleValueState(throttleStateComputed.value, isEngineControledComputed.value))
  }
}

for (local i = 0; i < NUM_CANNONS_MAX; ++i) {
  let idx = i
  let MachineGunsAmmoCount = MachineGunsCount[idx]
  let MachineGunsAmmoReloadTime = MachineGunsReloadTime[idx]
  let MachineGunsModeLocal = MachineGunsMode[idx]

  textParamsMapMain[AirParamsMain.MACHINE_GUNS_1 + idx] <- {
    titleComputed = Computed(@() getMachineGunCaption(MachineGunsModeLocal.value))
    valueComputed = Computed(@() generateBulletsTextFunction(MachineGunsAmmoCount.value, MachineGunsAmmoReloadTime.value))
    selectedComputed = Computed(@() MachineGunsSelectedArray.value?[idx] ? ">" : "")
    additionalComputed = Computed (@() "")
    alertStateCaptionComputed = Computed(@() IsMachineGunsEmpty.value?[idx] ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() IsMachineGunsEmpty.value?[idx] ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
  }
}

for (local i = 0; i < NUM_CANNONS_MAX; ++i) {
  let idx = i
  let CannonAmmoCount = CannonCount[idx]
  let CannonAmmoReloadTime = CannonReloadTime[idx]
  let CannonModeLocal = CannonMode[idx]
  let blinkComputed = Computed(@() GunInDeadZone.value)
  let blinkTrigger = {}
  blinkComputed.subscribe(@(v) v ? anim_start(blinkTrigger) : anim_request_stop(blinkTrigger))
  textParamsMapMain[AirParamsMain.CANNON_1 + idx] <- {
    titleComputed = Computed(@() getCannonsCaption(CannonModeLocal.value))
    valueComputed = Computed(@() generateBulletsTextFunction(CannonAmmoCount.value, CannonAmmoReloadTime.value))
    selectedComputed = Computed(@() CannonSelectedArray.value?[idx] || CannonSelected.value ? ">" : "")
    additionalComputed = Computed (@() "")
    alertStateCaptionComputed = Computed(@() (IsCannonEmpty.value?[idx] || isCannonJamed.value?[idx]) ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() (IsCannonEmpty.value?[idx] || isCannonJamed.value?[idx]) ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
    blinkComputed
    blinkTrigger
  }
}

let numParamPerEngine = 3
let textParamsMapSecondary = {}

for (local i = 0; i < NUM_VISIBLE_ENGINES_MAX; ++i) {

  let indexStr = (i + 1).tostring()
  let oilStateComputed = OilState[i]
  let oilTemperatureComputed = OilTemperature[i]
  let oilAlertComputed = OilAlert[i]
  textParamsMapSecondary[AirParamsSecondary.OIL_1 + (i * numParamPerEngine)] <- {
    titleComputed = Computed(@() loc($"HUD/OIL_TEMPERATURE_SHORT{indexStr}"))
    valueComputed = Computed(@() !isInitializedMeasureUnits.value ? ""
      : generateTemperatureTextFunction(oilTemperatureComputed.value, oilStateComputed.value, measureUnitsNames.value.temperature))
    selectedComputed = Computed (@() "")
    additionalComputed = Computed (@() "")
    alertStateCaptionComputed = Computed (@() oilAlertComputed.value)
    alertValueStateComputed = Computed (@() oilAlertComputed.value)
  }

  let waterStateComputed = WaterState[i]
  let waterTemperatureComputed = WaterTemperature[i]
  let waterAlertComputed = WaterAlert[i]
  textParamsMapSecondary[AirParamsSecondary.WATER_1 + (i * numParamPerEngine)] <- {
    titleComputed = Computed(@() loc($"HUD/WATER_TEMPERATURE_SHORT{indexStr}"))
    valueComputed = Computed(@() !isInitializedMeasureUnits.value ? ""
      : generateTemperatureTextFunction(waterTemperatureComputed.value, waterStateComputed.value, measureUnitsNames.value.temperature))
    selectedComputed = Computed (@() "")
    additionalComputed = Computed (@() "")
    alertStateCaptionComputed = Computed (@() waterAlertComputed.value)
    alertValueStateComputed = Computed (@() waterAlertComputed.value)
  }

  let engineStateComputed = EngineState[i]
  let engineTemperatureComputed = EngineTemperature[i]
  let engineAlertComputed = EngineAlert[i]
  textParamsMapSecondary[AirParamsSecondary.ENGINE_1 + (i * numParamPerEngine)] <- {
    titleComputed = Computed(@() loc($"HUD/ENGINE_TEMPERATURE_SHORT{indexStr}"))
    valueComputed = Computed(@() !isInitializedMeasureUnits.value ? ""
      : generateTemperatureTextFunction(engineTemperatureComputed.value, engineStateComputed.value, measureUnitsNames.value.temperature))
    selectedComputed = Computed (@() "")
    additionalComputed = Computed (@() "")
    alertStateCaptionComputed = Computed (@() engineAlertComputed.value)
    alertValueStateComputed = Computed (@() engineAlertComputed.value)
  }
}

for (local i = 0; i < NUM_TRANSMISSIONS_MAX; ++i) {

  let indexStr = (i + 1).tostring();
  let transmissionOilStateComputed = TransmissionOilState[i]
  let isTransmissionAlertComputed = IsTransmissionOilAlert[i]
  textParamsMapSecondary[AirParamsSecondary.TRANSMISSION_1 + i] <- {
    titleComputed = Computed(@() loc($"HUD/TRANSMISSION_OIL_SHORT{indexStr}"))
   valueComputed = Computed(@() generateTransmissionStateTextFunction(transmissionOilStateComputed.value))
    selectedComputed = Computed (@() "")
    additionalComputed = Computed (@() "")
    alertStateCaptionComputed = Computed(@() isTransmissionAlertComputed.value ?  HudColorState.HIGH_ALERT : HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() isTransmissionAlertComputed.value ?  HudColorState.HIGH_ALERT : HudColorState.ACTIV)
  }
}

textParamsMapSecondary[AirParamsSecondary.FUEL] <- {
  titleComputed = Computed(@() loc("HUD/FUEL_SHORT"))
  valueComputed = Computed(@() getFuelState(Fuel.value, HasExternalFuel.value, ExternalFuel.value, FuelState.value))
  selectedComputed = Computed (@() "")
  additionalComputed = Computed (@() "")
  alertStateCaptionComputed = Computed(@() getFuelAlertState(FuelState.value))
  alertValueStateComputed = Computed(@() getFuelAlertState(FuelState.value))
}

textParamsMapSecondary[AirParamsSecondary.STAMINA] <- {
  titleComputed = Computed(@() loc("HUD/TXT_STAMINA_SHORT"))
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

let fuelKeyId = AirParamsSecondary.FUEL

let function generateParamsTable(mainMask, secondaryMask, width, height, posWatched, gap, needCaption = true, forIls = false, is_aircraft = false) {
  let function getChildren(colorWatch, style, isBomberView) {
    let children = []

    foreach (key, param in textParamsMapMain) {
      if ((1 << key) & mainMask.value)
        children.append(createParam(param, width, height, style, colorWatch, needCaption, forIls, isBomberView))
      if (key == AirParamsMain.ALTITUDE && is_aircraft) {
        children.append(@() style.__merge({
          rendObj = ROBJ_TEXT
          size = [0, hdpx(12)]
          text = @() ""
        }))
      }
    }
    local secondaryMaskValue = secondaryMask.value
    if (is_aircraft) {
      if ((1 << fuelKeyId) & secondaryMaskValue) {
        children.append(createParam(textParamsMapSecondary[fuelKeyId], width, height, style, colorWatch, needCaption, forIls, isBomberView))
        secondaryMaskValue = secondaryMaskValue - (1 << fuelKeyId)
      }
    }

    if (is_aircraft) {
      children.append(@() style.__merge({
        rendObj = ROBJ_TEXT
        size = [ 0, hdpx(12)]
        text = @() ""
      }))
    }

    foreach (key, param in textParamsMapSecondary) {
      if ((1 << key) & secondaryMaskValue)
        children.append(createParam(param, width, height, style, colorWatch, needCaption, forIls, isBomberView))
    }

    return children
  }

  return function(colorWatch, isBomberView = false, style = styleText) {
    let table = @() style.__merge({
      watch = [mainMask, secondaryMask, posWatched]
      pos = posWatched.value
      size = [width, SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      gap
      children = getChildren(colorWatch, style, isBomberView)
    })

    return {
      children = table
    }
  }
}

let function compassComponent(colorWatch, size, pos) {
  return @() {
    pos
    watch = [IsCompassVisible, colorWatch]
    children = IsCompassVisible.value ? compass(size, colorWatch.value) : null
  }
}

let airHorizonZeroLevel = function(elemStyle, height, color) {
  return elemStyle.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    color
    size = [4 * height, height]
    commands = [
      [VECTOR_LINE, 0, 50, 15, 50],
      [VECTOR_LINE, 85, 50, 100, 50],
    ]
  })
}


let airHorizon = function(elemStyle, height, color) {
  return @() elemStyle.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [4 * height, height]
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


let function horizontalSpeedVector(elemStyle, color, height) {
  return elemStyle.__merge({
    rendObj = ROBJ_HELICOPTER_HORIZONTAL_SPEED
    size = [height, height]
    minLengthArrowVisibleSq = 200
    velocityScale = 5
    color
  })
}

let function HelicopterHorizontalSpeedComponent(color, posX = sw(50), posY = sh(50), height = hdpx(40), elemStyle = styleLineForeground) {
  return function() {
    return {
      pos = [posX - 2 * height, posY - height * 0.5]
      size = [4 * height, height]
      children = [
        airHorizonZeroLevel(elemStyle, height, color)
        airHorizon(elemStyle, height, color)
        {
          pos = [height, -0.5 * height]
          children = [
            horizontalSpeedVector(elemStyle, color, 2 * height)
          ]
        }
      ]
    }
  }
}

let hl = 20
let vl = 20

const fullRangeMultInv = 0.7
const outOfZoneLaunchShowTimeOut = 2.

let function getAgmLaunchAngularRangeCommands(_visible, yawMin, yawMax, pitchMin, pitchMax) {

  let left  = max(0.0, yawMin) * 100.0
  let right = min(1.0, yawMax) * 100.0
  let lower = 100.0 - max(0.0, pitchMin) * 100.0
  let upper = 100.0 - min(1.0, pitchMax) * 100.0
  return [
    [VECTOR_LINE, left,  upper, right, upper],
    [VECTOR_LINE, right, upper, right, lower],
    [VECTOR_LINE, right, lower, left,  lower],
    [VECTOR_LINE, left,  lower, left,  upper]
  ]
}

let function getAgmGuidanceRangeCommands(_visible, yawMin, yawMax, pitchMin, pitchMax) {

  let left  = max(0.0, yawMin) * 100.0
  let right = min(1.0, yawMax) * 100.0
  let lower = 100.0 - max(0.0, pitchMin) * 100.0
  let upper = 100.0 - min(1.0, pitchMax) * 100.0
  return [
    [VECTOR_LINE, left, lower, right, lower],
    [VECTOR_LINE, left, upper, right, upper],
    [VECTOR_LINE, left, lower, left, upper],
    [VECTOR_LINE, right, lower, right, upper]
  ]
}

let function getAgmLaunchDistanceRangeCommands(_visible, enabled, distMin, distMax, dist) {

  let distanceRangeInv = fullRangeMultInv * 1.0 / (distMax - 0.0 + 1.0)
  let distanceMinRel = (distMin - 0.0) * distanceRangeInv
  let commands = [
    [VECTOR_LINE, 120, 0,   120, 100],
    [VECTOR_LINE, 120, 100, 125, 100],
    [VECTOR_LINE, 120, 0,   125, 0],
    [VECTOR_LINE, 120, 100 * (1.0 - fullRangeMultInv),  127, 100 * (1.0 - fullRangeMultInv)],
    [VECTOR_LINE, 120, 100 - (distanceMinRel * 100 - 1), 127, 100 - (distanceMinRel * 100 - 1)]
  ]
  if (enabled) {
    let distanceRel = min((dist - 0.0) * distanceRangeInv, 1.0)
    commands.append([VECTOR_RECTANGLE, 120, 100 - (distanceRel * 100 - 1),  10, 2])
  }
  return commands
}



let function turretAngles(colorWatch, width, height, aspect, blinkDuration = 0.5) {

  let offset = 1.3
  let crossL = 2

  let getTurretCommands = function(yaw, pitch) {
    let px = yaw * 100.0
    let py = 100 - pitch * 100.0
    return [
      [VECTOR_LINE, px - crossL - offset, py, px - offset, py],
      [VECTOR_LINE, px + offset, py, px + crossL + offset, py],
      [VECTOR_LINE, px, py - crossL * aspect - offset * aspect, px, py - offset * aspect],
      [VECTOR_LINE, px, py + crossL * aspect + offset * aspect, px, py + offset * aspect]
    ]
  }
  let isAtgmGuidanceRangeVisible = Computed(@() IsAgmLaunchZoneVisible.value)
  let isAtgmAngularRangeVisible = Computed(@() (IsAgmLaunchZoneVisible.value && AgmLaunchZoneYawMin.value > 0.0 && AgmLaunchZoneYawMax.value < 1.0 && AgmLaunchZonePitchMin.value > 0.0 && AgmLaunchZonePitchMax.value < 1.0))
  let atgmLaunchZoneBlinking = Computed(@() !IsInsideLaunchZoneYawPitch.value)
  let atgmLaunchZoneTrigger = {}
  atgmLaunchZoneBlinking.subscribe(@(v) v ? anim_start(atgmLaunchZoneTrigger) : anim_request_stop(atgmLaunchZoneTrigger))
  let atgmLaunchDistanceblinking = Computed(@() IsRangefinderEnabled.value && !IsInsideLaunchZoneDist.value)
  let atgmLaunchDistanceTrigger = {}
  atgmLaunchDistanceblinking.subscribe(@(v) v ? anim_start(atgmLaunchDistanceTrigger) : anim_request_stop(atgmLaunchDistanceTrigger))

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
            animations = [{ prop = AnimProp.opacity, from = 1, to = 0, duration = blinkDuration, play = atgmLaunchZoneBlinking.value,
              loop = true, easing = InOutSine, trigger = atgmLaunchZoneTrigger }]
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
            animations = [{ prop = AnimProp.opacity, from = 1, to = 0, duration = blinkDuration, play = atgmLaunchZoneBlinking.value,
              loop = true, easing = InOutSine, trigger = atgmLaunchZoneTrigger }]
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
              animations = [{ prop = AnimProp.opacity, from = 1, to = 0, duration = blinkDuration, play = atgmLaunchDistanceblinking.value,
                loop = true, easing = InOutSine, trigger = atgmLaunchDistanceTrigger }]
            }) : null
    ]
  })
}

let lockSightComponent = function(colorWatch, width, height, posX, posY) {
  let color = Computed(@() IsAgmEmpty.value ? AlertColorHigh.value : colorWatch.value)
  return lockSight(color, width, height, posX, posY)
}

let function helicopterRocketSightMode(sightMode) {

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

let helicopterRocketAim = @(width, height, color, style = styleLineForeground) function() {

  let lines = helicopterRocketSightMode(RocketSightMode.value)

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

let turretAnglesAspect = 2.0
let turretAnglesComponent = function(colorWatch, width, height, posX, posY, blinkDuration = 0.5) {
  return {
    pos = [posX - turretAnglesAspect * width * 0.5, posY - height]
    size = SIZE_TO_CONTENT
    children = turretAngles(colorWatch, width, height, turretAnglesAspect, blinkDuration)
  }
}

let function agmLaunchZone(colorWatch, _w, _h) {
  let function maxAngleBorder() {
    let px = TurretYaw.value
    let py = TurretPitch.value
    let left  = max(0.0, AgmLaunchZoneYawMin.value) * 100.0 - px * 100.0 + 50.0
    let right = min(1.0, AgmLaunchZoneYawMax.value) * 100.0 - px * 100.0 + 50.0
    let lower = 100.0 - max(0.0, AgmLaunchZonePitchMin.value) * 100.0 + py * 100.0 - 50
    let upper = 100.0 - min(1.0, AgmLaunchZonePitchMax.value) * 100.0 + py * 100.0 - 50
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
    color = colorWatch.value
    watch = [ IsAgmLaunchZoneVisible,
      AgmLaunchZoneYawMin, AgmLaunchZoneYawMax,
      AgmLaunchZonePitchMin, AgmLaunchZonePitchMax,
      TurretYaw, TurretPitch, IsZoomedAgmLaunchZoneVisible,
      colorWatch
    ]
    commands = IsZoomedAgmLaunchZoneVisible.value ? maxAngleBorder() : []
  })
}

let function sight(colorWatch, height) {
  let longL = 22
  let shortL = 10
  let dash = 0.8
  let centerOffset = 3

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

      [VECTOR_LINE, 50 - centerOffset, 50 - dash,  50 - centerOffset, 50 + dash],
      [VECTOR_LINE, 50 + centerOffset, 50 - dash,  50 + centerOffset, 50 + dash],
      [VECTOR_LINE, 50 - dash,  50 - centerOffset, 50 + dash, 50 - centerOffset],
      [VECTOR_LINE, 50 - dash,  50 + centerOffset, 50 + dash, 50 + centerOffset],
    ]
  })
}

let sightComponent = function(colorWatch, centerX, centerY, height) {
  return {
    pos = [centerX - height * 0.5, centerY - height * 0.5]
    size = SIZE_TO_CONTENT
    children = sight(colorWatch, height)
  }
}

let function launchDistanceMaxComponent(colorWatch, width, height, posX, posY) {

  let getAgmLaunchDistanceMax = function() {
    return IsAgmLaunchZoneVisible.value ?
      cross_call.measureTypes.DISTANCE_SHORT.getMeasureUnitsText(AgmLaunchZoneDistMax.value) : ""
  }

  let launchDistanceMax = @() styleText.__merge({
    rendObj = ROBJ_TEXT
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

  let resCompoment = @() {
    rendObj = ROBJ_VECTOR_CANVAS
    pos = [posX + 1.6 * turretAnglesAspect * width * 0.5, posY - height * fullRangeMultInv]
    halign = ALIGN_LEFT
    valign = ALIGN_CENTER
    size = [0, 0]
    children = launchDistanceMax
  }

  return resCompoment
}

let function rangeFinderComponent(colorWatch, posX, posY) {
  let rangefinder = @() styleText.__merge({
    rendObj = ROBJ_TEXT
    halign = ALIGN_CENTER
    text = cross_call.measureTypes.DISTANCE_SHORT.getMeasureUnitsText(RangefinderDist.value)
    opacity = IsRangefinderEnabled.value ? 100 : 0
    color = colorWatch.value
    watch = [RangefinderDist, IsRangefinderEnabled, colorWatch]
  })

  let resCompoment = @() {
    pos = [posX, posY]
    halign = ALIGN_CENTER
    size = [0, 0]
    children = rangefinder
  }

  return resCompoment
}

let triggerTATarget = {}
TargetAge.subscribe(@(v) v < 0.2 ? anim_request_stop(triggerTATarget) : anim_start(triggerTATarget))
let HelicopterTATarget = @(w, h) function() {

  let res = {
    watch = [TATargetVisible, TargetX, TargetY, IsTargetTracked,
      TargetAge, AlertColorHigh, IsLaserDesignatorEnabled]
    animations = [{ prop = AnimProp.opacity, from = 0, to = 1, duration = 0.5, play = TargetAge.value > 0.2, loop = true, easing = InOutSine, trigger = triggerTATarget }]
    key = TargetAge
  }

  if (!TATargetVisible.value && TargetAge.value < 0.2)
    return res

  // border
  let taTargetcommands = [
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

let targetSizeComponent = function(colorWatch, width, height) {
  return @() {
    pos = [0, 0]
    size = SIZE_TO_CONTENT
    watch = IsMfdEnabled
    children = targetSize(colorWatch, width, height, IsMfdEnabled.value)
  }
}

let detectAllyComponent = @(posX, posY) function() {

  let res = { watch = [DetectAllyProgress, DetectAllyState] }
  if (DetectAllyProgress.value < 1.0)
    return res

  return res.__update(styleText.__merge({
    rendObj = ROBJ_TEXT
    text = DetectAllyProgress.value < 1.0 ? loc("detect_ally_progress")
      : (DetectAllyState.value ? loc("detect_ally_success")
      : loc("detect_ally_fail"))
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