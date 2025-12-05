from "%rGui/globals/ui_library.nut" import *
let cross_call = require("%rGui/globals/cross_call.nut")

let math = require("%sqstd/math.nut")
let string = require("string")

let { CannonMode, CannonSelectedArray, CannonSelected, CannonReloadTime, CannonCount, IsCannonEmpty,
  OilTemperature, OilState, WaterTemperature, WaterState, EngineTemperature, EngineState,
  EngineAlert, TransmissionOilState, IsTransmissionOilAlert, Fuel, HasExternalFuel, ExternalFuel, FuelState, IsCompassVisible,
  IsMachineGunsEmpty, MachineGunsSelectedArray, MachineGunsCount, MachineGunsReloadTime, MachineGunsMode,
  CannonsAdditionalCount, CannonsAdditionalSeconds, CannonsAdditionalMode, CannonsAdditionalSelected, IsCanAdditionalEmpty,
  AgmCount, AgmSeconds, AgmTimeToHit, AgmTimeToWarning, AgmActualCount, AgmName, AgmSelected, IsAgmEmpty, AgmWeaponIdx,
  AamCount, AamSeconds, AamTimeToHit, AamActualCount, AamName, AamSelected, IsAamEmpty, AamWeaponIdx,
  GuidedBombsCount, GuidedBombsSeconds, GuidedBombsTimeToHit, GuidedBombsMode, GuidedBombsActualCount, GuidedBombsName, GuidedBombsSelected, IsGuidedBmbEmpty,
  GuidedBombsWeaponIdx,
  FlaresCount, FlaresSeconds, FlaresMode, IsFlrEmpty,
  ChaffsCount, ChaffsSeconds, ChaffsMode, IsChaffsEmpty,
  RocketsCount, RocketsSeconds, RocketsActualCount, RocketsSalvo, RocketsMode, RocketsName, RocketsSelected, IsRktEmpty, DetectAllyProgress, DetectAllyState,
  RocketsWeaponIdx,
  BombsCount, BombsSeconds, BombsActualCount, BombsSalvo, BombsMode, BombsName, BombsSelected, IsBmbEmpty, BombsWeaponIdx,
  IsTrpEmpty, TorpedoesCount, TorpedoesSeconds, TorpedoesActualCount, TorpedoesSalvo, TorpedoesMode, TorpedoesName, TorpedoesSelected,
  IsHighRateOfFire, IsInsideLaunchZoneYawPitch, AgmLaunchZoneYawMin,
  AgmLaunchZonePitchMin, AgmLaunchZonePitchMax, AgmLaunchZoneYawMax, AgmRotatedLaunchZoneYawMin, AgmRotatedLaunchZoneYawMax,
  AgmRotatedLaunchZonePitchMax, AgmRotatedLaunchZonePitchMin, TurretPitch, TurretYaw, FovYaw, FovPitch, IsZoomedAgmLaunchZoneVisible,
  IsAgmLaunchZoneVisible, AgmLaunchZoneDistMax, IsLaunchZoneAvailable, IsOutLaunchZone, IsLaunchZoneOnTarget, LaunchZonePosX, LaunchZonePosY, LaunchZoneWatched,
  IsRangefinderEnabled, RangefinderDist,
  Rpm, IsRpmVisible, IsRpmCritical, TrtMode, Trt, Spd, WaterAlert, HorAngle, AgmLaunchZoneDistMin,
  AlertColorLow, AlertColorMedium, AlertColorHigh, OilAlert,
  PassivColor, IsLaserDesignatorEnabled, IsInsideLaunchZoneDist, GunInDeadZone,
  RocketSightMode, RocketAimVisible, StaminaValue, StaminaState,
  RocketAimX, RocketAimY, TATargetVisible, IRCMState,
  Mach, CritMach, Ias, CritIas, InstructorState, InstructorForced, IsEnginesControled, ThrottleState, isEngineControled,
  DistanceToGround, RadarAltitude, RadarAltitudeAlert, IsMfdEnabled, VerticalSpeed, MfdColor,
  ParamTableShadowFactor, ParamTableShadowOpacity, isCannonJamed
} = require("%rGui/airState.nut")

let HudStyle = require("%rGui/style/airHudStyle.nut")
let weaponUtils = require("weaponUtils")

let { AimLockPos, AimLockValid } = require("%rGui/planeState/planeToolsState.nut")

let { IsTargetTracked, TargetAge, TargetX, TargetY, TargetInZone } = require("%rGui/hud/targetTrackerState.nut")
let { lockSight, targetSize } = require("%rGui/hud/targetTracker.nut")

let { isInitializedMeasureUnits, measureUnitsNames } = require("%rGui/options/optionsMeasureUnits.nut")

let { GuidanceLockResult } = require("guidanceConstants")

let aamGuidanceLockState = require("%rGui/rocketAamAimState.nut").GuidanceLockState
let { HasTOFInHud } = require("%rGui/rocketAamAimState.nut")

let agmAimState = require("%rGui/agmAimState.nut")
let agmGuidanceLockState = agmAimState.GuidanceLockStateBlinked
let agmGuidancePointIsTarget = agmAimState.PointIsTarget
let guidedBombsAimState = require("%rGui/guidedBombsAimState.nut")
let guidedBombsGuidanceLockState = guidedBombsAimState.GuidanceLockStateBlinked
let guidedBombsGuidancePointIsTarget = guidedBombsAimState.PointIsTarget
let compass = require("%rGui/compass.nut")
let hints = require("%rGui/hints/hints.nut")
let { showConsoleButtons } = require("%rGui/ctrlsState.nut")
let { isUnitAlive, unitType, isPlayingReplay } = require("%rGui/hudState.nut")
let { isInFlight } = require("%rGui/globalState.nut")
let { clearTimer, setTimeout } = require("dagor.workcycle")
let { eventbus_subscribe } = require("eventbus")

function getAirHudElemsTable() {

const NUM_VISIBLE_ENGINES_MAX = 6
const NUM_TRANSMISSIONS_MAX = 6
const NUM_CANNONS_MAX = 3
const SH_HINTS_VISIBLE_TIME_SEC = 20
const SH_HINTS_FADE_OUT_ANIM_TIME_SEC = 0.7

let needShowShHints = Computed(@() isUnitAlive.get() && isInFlight.get() && !isPlayingReplay.get())
let shHintsColumnWidth = mkWatched(persist, "shHintsColumnWidth", 0)
let isShHintsVisible = mkWatched(persist, "isShHintsVisible", false)
let isShHintsColumnVisible = mkWatched(persist, "isShHintsColumnVisible", false)

eventbus_subscribe("controlsChanged", @(_) shHintsColumnWidth.set(0))

local hideShHintsTimer = null
local hideShHintsColumnTimer = null

function clearShHintsTimers() {
  clearTimer(hideShHintsTimer)
  clearTimer(hideShHintsColumnTimer)
}

function hideShHintsColumn() {
  isShHintsColumnVisible.set(false)
  shHintsColumnWidth.set(0)
}

function hideShHints() {
  isShHintsVisible.set(false)
  hideShHintsColumnTimer = setTimeout(SH_HINTS_FADE_OUT_ANIM_TIME_SEC, hideShHintsColumn)
}

function showShHints() {
  isShHintsVisible.set(true)
  isShHintsColumnVisible.set(true)
  clearShHintsTimers()
}

function showShHintsWithAutohide() {
  showShHints()
  hideShHintsTimer = setTimeout(SH_HINTS_VISIBLE_TIME_SEC, hideShHints)
}

function handleShowShHintsChanges(value) {
  clearShHintsTimers()
  if (value)
    return showShHintsWithAutohide()
  isShHintsVisible.set(false)
  hideShHintsColumn()
}

function verticalSpeedInd(height, style, color) {
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

function verticalSpeedScale(width, height, style, color) {
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

function HelicopterVertSpeed(scaleWidth, height, posX, posY, color, elemStyle = HudStyle.styleText) {
  let relativeHeight = Computed(@() clamp(DistanceToGround.get() * 2.0, 0, 100))
  let distToGroundText = Computed(function() {
    let val = DistanceToGround.get().tostring()
    if (IsMfdEnabled.get())
      return val
    let measureName = isInitializedMeasureUnits.get() ? loc(measureUnitsNames.get().alt) : ""
    return " ".concat(val, measureName)
  })

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
          opacity = DistanceToGround.get() > 50.0 ? 0 : 100
          commands = [[VECTOR_RECTANGLE, 0, 100 - relativeHeight.get(), 100, relativeHeight.get()]]
        })
      }
      {
        halign = ALIGN_RIGHT
        valign = ALIGN_CENTER
        size = [-0.5 * scaleWidth, height]
        children = @() elemStyle.__merge({
          watch = distToGroundText
          size = [scaleWidth * 4, SIZE_TO_CONTENT]
          rendObj = ROBJ_TEXT
          halign = ALIGN_RIGHT
          color
          text = distToGroundText.get()
        })
      }
      @() {
        watch = VerticalSpeed
        pos = [scaleWidth + sh(0.5), 0]
        transform = {
          translate = [0, height * 0.01 * clamp(50 - VerticalSpeed.get() * 5.0, 0, 100)]
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
              text = IsMfdEnabled.get() ?
                math.round_by_value(VerticalSpeed.get(), 1).tostring() :
                cross_call.measureTypes.CLIMBSPEED.getMeasureUnitsText(VerticalSpeed.get())
            })
          }
        ]
      }
    ]
  }
}

function generateBulletsTextFunction(count, seconds, salvo = 0, actualCount = -1, weaponIdx = -1) {
  local txts = []
  if (seconds >= 0) {
    txts = [string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)]
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
  if (weaponIdx >= 0) {
    let locId = weaponUtils.get_hero_weapon_slot_place_txt_key(weaponIdx)
    if (locId != "" && doesLocTextExist(locId))
      txts.append(loc(locId))
  }
  return "".join(txts)
}

function generateRpmTitleFunction(trtMode) {
  local txts = []
  if (trtMode < AirThrottleMode.AIRCRAFT_DEFAULT_MODE)
    txts = [loc("HUD/PROP_RPM_SHORT")]

  return "".join(txts)
}


function generateRpmTextFunction(trtMode, rpmValue) {
  local txts = []
  if (trtMode < AirThrottleMode.AIRCRAFT_DEFAULT_MODE)
    txts = [string.format("%d %%", rpmValue)]

  return "".join(txts)
}

function generateGuidedWeaponBulletsTextFunction(count, seconds, timeToHit, _timeToWarning, actualCount = 0, weaponIdx = -1) {
  local txts = []
  if (seconds >= 0) {
    txts = [string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)]
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
  if (weaponIdx >= 0) {
    let locId = weaponUtils.get_hero_weapon_slot_place_txt_key(weaponIdx)
    if (locId != "" && doesLocTextExist(locId))
      txts.append(loc(locId))
  }
  return "".join(txts)
}

function generateTemperatureTextFunction(temperature, state, temperatureUnits) {
  if (state == TemperatureState.OVERHEAT)
    return ("".concat(temperature, loc(temperatureUnits)))
  else if (state == TemperatureState.EMPTY_TANK)
    return (loc("HUD_TANK_IS_EMPTY"))
  else if (state == TemperatureState.FUEL_LEAK)
    return (loc("HUD_FUEL_LEAK"))
  else if (state == TemperatureState.FUEL_DUMPING)
    return (loc("HUD_FUEL_DUMPING"))
  else if (state == TemperatureState.FUEL_SEALING)
    return  (loc("HUD_TANK_IS_SEALING"))
  else if (state == TemperatureState.BLANK)
    return ""

  return ""
}

function generateTransmissionStateTextFunction(oilState) {
  if (oilState > 0.01)
    return loc("HUD_FUEL_LEAK")
  return loc("HUD_TANK_IS_EMPTY")
}

function getThrottleText(mode, trt) {
  if (mode == AirThrottleMode.DEFAULT_MODE
    || mode == AirThrottleMode.CLIMB
    || mode == AirThrottleMode.AIRCRAFT_DEFAULT_MODE)
    return string.format("%d %%", trt)
  else if (mode == AirThrottleMode.BRAKE
    || mode == AirThrottleMode.AIRCRAFT_BRAKE)
    return loc("HUD/BRAKE_SHORT")
  else if (mode == AirThrottleMode.WEP
    || mode == AirThrottleMode.AIRCRAFT_WEP)
    return string.format("%d %% %s", trt, loc("HUD/WEP_SHORT"))
  return ""
}


function getThrottleCaption(mode, isControled, idx) {
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

function getModeCaption(mode) {
  let texts = []
  if (mode & (1 << WeaponMode.CCRP_MODE))
    texts.append(loc("HUD/TXT_WEAPON_MODE_AUTO"))
  else if (mode & (1 << WeaponMode.GYRO_MODE))
    texts.append(loc("HUD/TXT_WEAPON_MODE_GYRO"))
  if (mode & (1 << WeaponMode.CCIP_MODE)) {
    if (texts.len() > 0)
      texts.append("/")
    texts.append(loc("HUD/WEAPON_MODE_CCIP"))
  }
  return "".join(texts)
}

function getBombModeCaption(mode) {
  let texts = []
  if (mode & (1 << WeaponMode.CCRP_MODE))
    texts.append(loc("HUD/WEAPON_MODE_CCRP"))
  if (mode & (1 << WeaponMode.CCIP_MODE)) {
    if (texts.len() > 0)
      texts.append("/")
    texts.append(loc("HUD/WEAPON_MODE_CCIP"))
  }

  
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

function getAGCaption(guidanceLockState, pointIsTarget) {
  let texts = []
  if (guidanceLockState == GuidanceLockResult.RESULT_INVALID)
    texts.append(loc("HUD/TXT_AGM_SHORT"))
  else if (guidanceLockState == GuidanceLockResult.RESULT_STANDBY)
    texts.append(loc("HUD/TXT_AGM_STANDBY"))
  else if (guidanceLockState == GuidanceLockResult.RESULT_WARMING_UP ||
           guidanceLockState == GuidanceLockResult.RESULT_POWER_ON)
    texts.append(loc("HUD/TXT_AGM_WARM_UP"))
  else if (guidanceLockState == GuidanceLockResult.RESULT_LOCKING)
    texts.append(loc("HUD/TXT_AGM_LOCK"))
  else if (guidanceLockState == GuidanceLockResult.RESULT_TRACKING)
    texts.append(loc(!pointIsTarget ? "HUD/TXT_AGM_TRACK" : "HUD/TXT_AGM_TRACK_POINT"))
  else if (guidanceLockState == GuidanceLockResult.RESULT_LOCK_AFTER_LAUNCH)
    texts.append(loc("HUD/TXT_AGM_LOCK_AFTER_LAUNCH"))
  return "".join(texts)
}

function getAACaption(guidanceLockState) {
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

function getGBCaption(guidanceLockState, pointIsTarget, mode) {
  let texts = []
  if (guidanceLockState == GuidanceLockResult.RESULT_INVALID)
    texts.append(loc("HUD/TXT_GUIDED_BOMBS_SHORT"))
  else if (guidanceLockState == GuidanceLockResult.RESULT_STANDBY)
    texts.append(loc("HUD/TXT_GUIDED_BOMBS_STANDBY"))
  else if (guidanceLockState == GuidanceLockResult.RESULT_WARMING_UP ||
           guidanceLockState == GuidanceLockResult.RESULT_POWER_ON)
    texts.append(loc("HUD/TXT_GUIDED_BOMBS_WARM_UP"))
  else if (guidanceLockState == GuidanceLockResult.RESULT_LOCKING)
    texts.append(loc("HUD/TXT_GUIDED_BOMBS_LOCK"))
  else if (guidanceLockState == GuidanceLockResult.RESULT_TRACKING)
    texts.append(loc(!pointIsTarget ? "HUD/TXT_GUIDED_BOMBS_TRACK" : "HUD/TXT_GUIDED_BOMBS_POINT_TRACK"))
  else if (guidanceLockState == GuidanceLockResult.RESULT_LOCK_AFTER_LAUNCH)
    texts.append(loc("HUD/TXT_GUIDED_BOMBS_LOCK_AFTER_LAUNCH"))
  texts.append(" ")
  texts.append(getBombModeCaption(mode))
  return "".join(texts)
}

function getCountermeasuresCaption(isFlare, mode) {
  let texts = isFlare ? [loc("HUD/FLARES_SHORT"), " "] : [loc("HUD/CHAFFS_SHORT"), " "]
  if (mode & CountermeasureMode.PERIODIC_COUNTERMEASURE)
    texts.append(loc("HUD/COUNTERMEASURE_PERIODIC"))
  if (mode == (CountermeasureMode.PERIODIC_COUNTERMEASURE | CountermeasureMode.MLWS_SLAVED_COUNTERMEASURE))
    texts.append(loc("HUD/INDICATION_MODE_SEPARATION"))
  if (mode & CountermeasureMode.MLWS_SLAVED_COUNTERMEASURE)
    texts.append(loc("HUD/COUNTERMEASURE_MLWS"))
  return "".join(texts)
}

function getMachineGunCaption(mode) {
  let texts = [loc("HUD/MACHINE_GUNS_SHORT"), " "]
  texts.append(getModeCaption(mode))
  return "".join(texts)
}

function getAdditionalCannonCaption(mode) {
  let texts = [loc("HUD/ADDITIONAL_GUNS_SHORT"), " "]
  texts.append(getModeCaption(mode))
  return "".join(texts)
}

function getRocketCaption(mode) {
  let texts = [loc("HUD/RKT"), " "]
  texts.append(getModeCaption(mode))
  return "".join(texts)
}

function getBombCaption(mode) {
  let texts = [loc("HUD/BOMBS_SHORT"), " "]
  texts.append(getBombModeCaption(mode))
  return "".join(texts)
}

function getTorpedoCaption(mode) {
  let texts = [loc("HUD/TORPEDOES_SHORT"), " "]
  texts.append(getModeCaption(mode))
  return "".join(texts)
}

function getCannonsCaption(mode) {
  let texts = [loc("HUD/CANNONS_SHORT"), " "]
  texts.append(getModeCaption(mode))
  return "".join(texts)
}

function getIRCMCaption(state) {
  let texts = []
  if (state == IRCMMode.IRCM_ENABLED)
    texts.append(loc("controls/on"))
  else if (state == IRCMMode.IRCM_DAMAGED)
    texts.append(loc("controls/dmg"))
  else if (state == IRCMMode.IRCM_DISABLED)
    texts.append(loc("controls/off"))
  return "".join(texts)
}

function getInstructorCaption(isInstructorForced) {
  return isInstructorForced ? loc("HUD_INSTRUCTOR_FORCED") : loc("HUD_INSTRUCTOR")
}

function getThrottleValueState(state, controled) {
  return controled ? state : HudColorState.PASSIV
}

function getThrottleState(controled) {
  return controled ? HudColorState.ACTIV : HudColorState.PASSIV
}

function getStaminaValue(stamina) {
  return string.format("%d %%", stamina)
}

function getFuelState(fuel, hasExternalFuel, externalFuel, fuelState) {
  if (fuelState == TemperatureState.FUEL_LEAK)
    return loc("HUD_FUEL_LEAK")
  if (fuelState == TemperatureState.FUEL_DUMPING)
    return (loc("HUD_FUEL_DUMPING"))
  if (fuelState == TemperatureState.FUEL_SEALING)
    return loc("HUD_TANK_IS_SEALING")
  if (fuelState == TemperatureState.EMPTY_TANK)
    return loc("HUD_TANK_IS_EMPTY")
  local val = string.format("%d:%02d", math.floor(fuel / 60), fuel % 60)
  if (hasExternalFuel)
    val = " ".concat(val, string.format(" / %d:%02d", math.floor(externalFuel / 60), externalFuel % 60))
  return val
}

function getFuelAlertState(fuelState) {
  return fuelState >= TemperatureState.FUEL_LEAK ? HudColorState.HIGH_ALERT :
         fuelState == TemperatureState.OVERHEAT ? HudColorState.PASSIV :
         fuelState == TemperatureState.EMPTY_TANK ? HudColorState.PASSIV : HudColorState.ACTIV
}

let mkShHintComponent = @(shW) @() {
  key = {}
  watch = [shW, shHintsColumnWidth, showConsoleButtons]
  minWidth = shHintsColumnWidth.get()
  halign = ALIGN_CENTER
  onAttach = @(elem) shHintsColumnWidth.set(max(shHintsColumnWidth.get(), elem.getWidth()))

  children = shW.get() != "" ? hints(shW.get(), {
    font = Fonts.tiny_text_hud
    fontSize = getFontDefHt("tiny_text_hud")
    place = "airParamsTable"
    shortCombination = !showConsoleButtons.get()
    shortCombinationMinWidth = shHintsColumnWidth.get()
  }) : null

  animations = [{ prop = AnimProp.opacity, from = 1.0, to = 0.0,
    duration = SH_HINTS_FADE_OUT_ANIM_TIME_SEC, easing = OutQuad, playFadeOut = true
  }]
}

function createParam(param, width, height, style, colorWatch, needCaption, for_ils, isBomberView, font_size) {
  let { valueComputed, titleComputed, alertStateCaptionComputed, alertValueStateComputed,
    isSelectedComputed = WatchedRo(false), additionalComputed = WatchedRo(""),
    fireSelectedShortcut = null, selectedSign = ">", blinkComputed = null, blinkTrigger = null,
    shortcutComputed = null
  } = param

  let selectColor = function(state, activeColor, passivColor, lowAlertColor, mediumAlertColor, highAlertColor) {
    return (state == HudColorState.PASSIV) ? passivColor
      : (state == HudColorState.LOW_ALERT) ? lowAlertColor
      : (state == HudColorState.MEDIUM_ALERT) ? mediumAlertColor
      : (state == HudColorState.HIGH_ALERT) ? highAlertColor
      : isBomberView ? HudStyle.isColorOrWhite(activeColor)
      : activeColor
  }

  let selectFxColor = function(state, activeColor, opacity) {
    return (state == HudColorState.ACTIV) ? HudStyle.isDarkColor(activeColor)
      ? Color(255, 255, 255, opacity * 255) : Color(0, 0, 0, opacity * 255)
      : Color(0, 0, 0, opacity * 255)
  }

  let selectFxFactor = function(state, activeColor, factor) {
    return (state == HudColorState.ACTIV) ? HudStyle.isDarkColor(activeColor)
    ? HudStyle.fontOutlineFxFactor * 0.15 * factor  : HudStyle.fontOutlineFxFactor * factor
    : HudStyle.fontOutlineFxFactor * factor
  }

  let colorAlertCaptionW = Computed(@() HudStyle.fadeColor(selectColor(alertStateCaptionComputed.get(), colorWatch.get(), PassivColor.get(),
    AlertColorLow.get(), AlertColorMedium.get(), AlertColorHigh.get()), 255))

  let colorFxCaption = Computed(@() selectFxColor(alertStateCaptionComputed.get(), colorWatch.get(), ParamTableShadowOpacity.get()))

  let factorFxCaption = Computed(@() selectFxFactor(alertStateCaptionComputed.get(), colorWatch.get(), ParamTableShadowFactor.get()))

  let captionComponent = @() style.__merge({
    watch = [titleComputed, colorAlertCaptionW, alertStateCaptionComputed, colorFxCaption, factorFxCaption]
    rendObj = ROBJ_TEXT
    size = [SIZE_TO_CONTENT, height]
    margin = const [0, 0.0, 0, 0]
    minWidth = 0.26 * width
    text = titleComputed.get()
    color = colorAlertCaptionW.get()
    fontFxColor = colorFxCaption.get()
    fontFxFactor = factorFxCaption.get()
    fontSize = font_size
    opacity =  alertStateCaptionComputed.get() >= HudColorState.LOW_ALERT ? 0.7 : 1.0
  })

  let selectedSignText = Computed(@() isSelectedComputed.get() ? selectedSign : "")
  let selectedComponent = @() style.__merge({
    watch = [selectedSignText, colorAlertCaptionW, colorFxCaption]
    rendObj = ROBJ_TEXT
    size = [0.05 * width, height]
    text = selectedSignText.get()
    color = colorAlertCaptionW.get()
    fontFxColor = colorFxCaption.get()
    fontFxFactor = factorFxCaption.get()
    fontSize = font_size
    opacity =  alertStateCaptionComputed.get() >= HudColorState.LOW_ALERT ? 0.7 : 1.0
  })

  let valueColor = Computed(@() for_ils ? MfdColor.get() : selectColor(alertValueStateComputed.get(), colorWatch.get(), PassivColor.get(),
    AlertColorLow.get(), AlertColorMedium.get(), AlertColorHigh.get()))

  let colorFxValue = Computed(@() selectFxColor(alertValueStateComputed.get(), colorWatch.get(), ParamTableShadowOpacity.get()))

  let factorFxValue = Computed(@() selectFxFactor(alertValueStateComputed.get(), colorWatch.get(), ParamTableShadowFactor.get()))

  let valueComponent = @() style.__merge({
    watch = [valueComputed, alertValueStateComputed, valueColor, colorFxValue, factorFxValue]
    size = [SIZE_TO_CONTENT, height]
    minWidth = hdpx(80)
    padding = [hdpx(2), 0, 0, 0]
    color = HudStyle.fadeColor(valueColor.get(), 255)
    rendObj = ROBJ_TEXT
    text = valueComputed.get()
    opacity =  alertValueStateComputed.get() >= HudColorState.LOW_ALERT ? 0.7 : 1.0
    fontFxFactor = factorFxValue.get()
    fontFxColor = colorFxValue.get()
    fontSize = font_size
  })

  let additionalComponent = @() style.__merge({
    watch = [additionalComputed, colorWatch, ParamTableShadowFactor, ParamTableShadowOpacity]
    size = [0.7 * width, height]
    margin = [0, 0, 0, hdpx(25)]
    rendObj = ROBJ_TEXT
    color = HudStyle.fadeColor(colorWatch.get(), 255)
    text = additionalComputed.get()
    fontFxFactor = HudStyle.isDarkColor(colorWatch.get()) ?
      HudStyle.fontOutlineFxFactor * 0.15 * ParamTableShadowFactor.get()
      : HudStyle.fontOutlineFxFactor * ParamTableShadowFactor.get()
    fontFxColor = HudStyle.isDarkColor(colorWatch.get())
      ? Color(255, 255, 255, 255 * ParamTableShadowOpacity.get())
      : Color(0, 0, 0, 255 * ParamTableShadowOpacity.get())
    fontSize = font_size
  })

  local shHintComponent = null
  if (shortcutComputed != null)
    shHintComponent = mkShHintComponent(shortcutComputed)
  else if (fireSelectedShortcut != null) {
    let fireSelectedShId = Computed(function() {
    if (!isSelectedComputed.get())
      return ""
    let shId = unitType.get() == "helicopter" ? $"{fireSelectedShortcut}_HELICOPTER"
      : fireSelectedShortcut
    return shId.concat("{{", "}}")
    })
    shHintComponent = mkShHintComponent(fireSelectedShId)
  }

  function hintCellComponent() {
    if (!isShHintsColumnVisible.get())
      return { watch = isShHintsColumnVisible }
    return {
      watch = [isShHintsColumnVisible, isShHintsVisible, shHintsColumnWidth]
      size = [shHintsColumnWidth.get(), SIZE_TO_CONTENT]
      margin = shHintsColumnWidth.get() > 0 ? [0, hdpx(25),0, 0] : 0
      children = isShHintsVisible.get() ? shHintComponent : null
    }
  }

  return {
    size = [SIZE_TO_CONTENT, height]
    flow = FLOW_HORIZONTAL
    animations = [{ prop = AnimProp.opacity, from = 0, to = 1, duration = 0.5, play = blinkComputed?.get(), loop = true, easing = InOutCubic, trigger = blinkTrigger }]
    children = [
      selectedComponent
      needCaption ? captionComponent : null
      hintCellComponent
      valueComponent
      additionalComponent
    ]
  }
}



let TrtModeForRpm = TrtMode[0]

let agmBlinkComputed = Computed(@() (IsAgmLaunchZoneVisible.get() &&
  (!IsInsideLaunchZoneYawPitch.get() || (IsRangefinderEnabled.get() && !IsInsideLaunchZoneDist.get()))))
let agmBlinkTrigger = {}
agmBlinkComputed.subscribe(@(v) v ? anim_start(agmBlinkTrigger) : anim_request_stop(agmBlinkTrigger))

let textParamsMapMain = {
  [AirParamsMain.RPM] = {
    titleComputed = Computed(@() IsRpmVisible.get() ? generateRpmTitleFunction(TrtModeForRpm.get()) : "")
    valueComputed = Computed(@() IsRpmVisible.get() ? generateRpmTextFunction(TrtModeForRpm.get(), Rpm.get()) : "")
    alertStateCaptionComputed = Computed(@() IsRpmCritical.get() ? HudColorState.HIGH_ALERT : HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() IsRpmCritical.get() ? HudColorState.HIGH_ALERT : HudColorState.ACTIV)
  },
  [AirParamsMain.IAS_HUD] = {
    titleComputed = Watched(loc("HUD/INDICATED_AIR_SPEED_SHORT"))
    valueComputed = Computed(@()  !isInitializedMeasureUnits.get() ? "" : " ".concat(Ias.get(), loc(measureUnitsNames.get().speed)))
    alertStateCaptionComputed = Computed(@() CritIas.get() ? HudColorState.HIGH_ALERT : HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() CritIas.get() ? HudColorState.HIGH_ALERT : HudColorState.ACTIV)
  },
  [AirParamsMain.SPEED] = {
    titleComputed = Watched(loc("HUD/REAL_SPEED_SHORT"))
    valueComputed = Computed(@() !isInitializedMeasureUnits.get() ? "" : " ".concat(Spd.get(), loc(measureUnitsNames.get().speed)))
    alertStateCaptionComputed = WatchedRo(HudColorState.ACTIV)
    alertValueStateComputed = WatchedRo(HudColorState.ACTIV)
  },
  [AirParamsMain.MACH] = {
    titleComputed = WatchedRo(loc("HUD/TXT_MACH_SHORT"))
    valueComputed = Computed(@() string.format("%.2f", Mach.get()))
    alertStateCaptionComputed = Computed(@() CritMach.get() ? HudColorState.HIGH_ALERT : HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() CritMach.get() ? HudColorState.HIGH_ALERT : HudColorState.ACTIV)
  },
  [AirParamsMain.ALTITUDE] = {
    titleComputed = WatchedRo(loc("HUD/ALTITUDE_SHORT"))
    valueComputed = Computed(@() !isInitializedMeasureUnits.get() ? "" : " ".concat(math.floor(DistanceToGround.get()), loc(measureUnitsNames.get().alt)))
    alertStateCaptionComputed = WatchedRo(HudColorState.ACTIV)
    alertValueStateComputed = WatchedRo(HudColorState.ACTIV)
  },
  [AirParamsMain.RADAR_ALTITUDE] = {
    titleComputed = WatchedRo(loc("HUD/RADAR_ALTITUDE_SHORT"))
    valueComputed = Computed(@() !isInitializedMeasureUnits.get() ? "" : " ".concat(math.floor(RadarAltitude.get()), loc(measureUnitsNames.get().alt)))
    alertStateCaptionComputed = Computed(@() RadarAltitude.get() < RadarAltitudeAlert.get() ? HudColorState.HIGH_ALERT : HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() RadarAltitude.get() < RadarAltitudeAlert.get() ? HudColorState.HIGH_ALERT : HudColorState.ACTIV)
  },
  [AirParamsMain.CANNON_ADDITIONAL] = {
    titleComputed = Computed(@() getAdditionalCannonCaption(CannonsAdditionalMode.get()))
    valueComputed = Computed(@() generateBulletsTextFunction(CannonsAdditionalCount.get(), CannonsAdditionalSeconds.get()))
    isSelectedComputed = Computed(@() CannonsAdditionalSelected.get())
    alertStateCaptionComputed = Computed(@() IsCanAdditionalEmpty.get() ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() IsCanAdditionalEmpty.get() ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
  },
  [AirParamsMain.ROCKET] = {
    titleComputed = Computed(@() getRocketCaption(RocketsMode.get()))
    valueComputed = Computed(@() generateBulletsTextFunction(RocketsCount.get(), RocketsSeconds.get(),
      RocketsSalvo.get(), RocketsActualCount.get(), RocketsWeaponIdx.get()))
    isSelectedComputed = Computed(@() RocketsSelected.get())
    fireSelectedShortcut = "ID_FIRE_SECONDARY"
    additionalComputed = Computed(@() loc(RocketsName.get()))
    alertStateCaptionComputed = Computed(@() IsRktEmpty.get() ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() IsRktEmpty.get() ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
  },
  [AirParamsMain.AGM] = {
    titleComputed = Computed(@() AgmCount.get() <= 0 ? loc("HUD/TXT_AGM_SHORT") :
      getAGCaption(agmGuidanceLockState.get(), agmGuidancePointIsTarget.get()))
    valueComputed = Computed(@() generateGuidedWeaponBulletsTextFunction(AgmCount.get(), AgmSeconds.get(),
       AgmTimeToHit.get(), AgmTimeToWarning.get(), AgmActualCount.get(), AgmWeaponIdx.get()))
    isSelectedComputed = Computed(@() AgmSelected.get())
    fireSelectedShortcut = "ID_FIRE_SECONDARY"
    additionalComputed = Computed(@() loc(AgmName.get()))
    alertStateCaptionComputed = Computed(@() IsAgmEmpty.get() ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() IsAgmEmpty.get() ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
    blinkComputed = agmBlinkComputed
    blinkTrigger = agmBlinkTrigger
  },
  [AirParamsMain.BOMBS] = {
    titleComputed = Computed(@() getBombCaption(BombsMode.get()))
    valueComputed = Computed(@() generateBulletsTextFunction(BombsCount.get(), BombsSeconds.get(),
      BombsSalvo.get(), BombsActualCount.get(), BombsWeaponIdx.get()))
    isSelectedComputed = Computed(@() BombsSelected.get())
    fireSelectedShortcut = "ID_FIRE_SECONDARY"
    additionalComputed = Computed(@() loc(BombsName.get()))
    alertStateCaptionComputed = Computed(@() IsBmbEmpty.get() ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() IsBmbEmpty.get() ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
  },
  [AirParamsMain.TORPEDO] = {
    titleComputed = Computed(@() getTorpedoCaption(TorpedoesMode.get()))
    valueComputed = Computed(@() generateBulletsTextFunction(TorpedoesCount.get(), TorpedoesSeconds.get(),
      TorpedoesSalvo.get(), TorpedoesActualCount.get()))
    isSelectedComputed = Computed(@() TorpedoesSelected.get())
    fireSelectedShortcut = "ID_FIRE_SECONDARY"
    additionalComputed = Computed(@() loc(TorpedoesName.get()))
    alertStateCaptionComputed = Computed(@() IsTrpEmpty.get() ? HudColorState.HIGH_ALERT : HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() IsTrpEmpty.get() ? HudColorState.HIGH_ALERT : HudColorState.ACTIV)
  },
  [AirParamsMain.RATE_OF_FIRE] = {
    titleComputed = WatchedRo(loc("HUD/RATE_OF_FIRE_SHORT"))
    valueComputed = Computed(@() IsHighRateOfFire.get() ? loc("HUD/HIGHFREQ_SHORT") : loc("HUD/LOWFREQ_SHORT"))
    alertStateCaptionComputed = WatchedRo(HudColorState.ACTIV)
    alertValueStateComputed = WatchedRo(HudColorState.ACTIV)
  },
  [AirParamsMain.AAM] = {
    titleComputed = Computed(@() AamCount.get() <= 0 ? loc("HUD/TXT_AAM_SHORT") : getAACaption(aamGuidanceLockState.get()))
    valueComputed = Computed(@() generateGuidedWeaponBulletsTextFunction(AamCount.get(), AamSeconds.get(),
      HasTOFInHud.get() ? AamTimeToHit.get() : -1.0, 0, AamActualCount.get(), AamWeaponIdx.get()))
    isSelectedComputed = Computed(@() AamSelected.get())
    fireSelectedShortcut = "ID_FIRE_SECONDARY"
    additionalComputed = Computed(@() loc(AamName.get()))
    alertStateCaptionComputed = Computed(@() (IsAamEmpty.get() || aamGuidanceLockState.get() == GuidanceLockResult.RESULT_TRACKING) ?
      HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() IsAamEmpty.get() ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
  },
  [AirParamsMain.GUIDED_BOMBS] = {
    titleComputed = Computed(@() GuidedBombsCount.get() <= 0 ? loc("HUD/TXT_GUIDED_BOMBS_SHORT") :
      getGBCaption(guidedBombsGuidanceLockState.get(), guidedBombsGuidancePointIsTarget.get(), GuidedBombsMode.get())
    )
    valueComputed = Computed(@() generateGuidedWeaponBulletsTextFunction(GuidedBombsCount.get(), GuidedBombsSeconds.get(),
      GuidedBombsTimeToHit.get(), 0.0, GuidedBombsActualCount.get(), GuidedBombsWeaponIdx.get()))
    isSelectedComputed = Computed(@() GuidedBombsSelected.get())
    fireSelectedShortcut = "ID_FIRE_SECONDARY"
    additionalComputed = Computed(@() loc(GuidedBombsName.get()))
    alertStateCaptionComputed = Computed(@() IsGuidedBmbEmpty.get() ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() IsGuidedBmbEmpty.get() ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
  },
  [AirParamsMain.FLARES] = {
    titleComputed = Computed(@() FlaresCount.get() <= 0 ? loc("HUD/FLARES_SHORT") : getCountermeasuresCaption(true, FlaresMode.get()))
    valueComputed = Computed(@() generateBulletsTextFunction(FlaresCount.get(), FlaresSeconds.get()))
    isSelectedComputed = Computed(@() (FlaresMode.get() & CountermeasureMode.FLARE_COUNTERMEASURES) != 0)
    selectedSign = "-"
    fireSelectedShortcut = "ID_FLARES"
    alertStateCaptionComputed = Computed(@() IsFlrEmpty.get() ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() IsFlrEmpty.get() ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
  },
  [AirParamsMain.CHAFFS] = {
    titleComputed = Computed(@() ChaffsCount.get() <= 0 ? loc("HUD/CHAFFS_SHORT") : getCountermeasuresCaption(false, ChaffsMode.get()))
    valueComputed = Computed(@() generateBulletsTextFunction(ChaffsCount.get(), ChaffsSeconds.get()))
    isSelectedComputed = Computed(@() (ChaffsMode.get() & CountermeasureMode.CHAFF_COUNTERMEASURES) != 0)
    selectedSign = "-"
    fireSelectedShortcut = "ID_FLARES"
    alertStateCaptionComputed = Computed(@() IsChaffsEmpty.get() ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() IsChaffsEmpty.get() ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
  },
  [AirParamsMain.IRCM] = {
    titleComputed = WatchedRo(loc("HUD/IRCM_SHORT"))
    valueComputed = Computed(@() getIRCMCaption(IRCMState.get()))
    alertStateCaptionComputed = WatchedRo(HudColorState.ACTIV)
    alertValueStateComputed = WatchedRo(HudColorState.ACTIV)
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
    titleComputed = Computed(@() getThrottleCaption(trtModeComputed.get(), IsEnginesControled.get(), index))
    valueComputed = Computed(@() getThrottleText(trtModeComputed.get(), trtComputed.get()))
    alertStateCaptionComputed = Computed(@() getThrottleState(isEngineControledComputed.get()))
    alertValueStateComputed = Computed(@() getThrottleValueState(throttleStateComputed.get(), isEngineControledComputed.get()))
  }
}

for (local i = 0; i < NUM_CANNONS_MAX; ++i) {
  let idx = i
  let MachineGunsAmmoCount = MachineGunsCount[idx]
  let MachineGunsAmmoReloadTime = MachineGunsReloadTime[idx]
  let MachineGunsModeLocal = MachineGunsMode[idx]

  textParamsMapMain[AirParamsMain.MACHINE_GUNS_1 + idx] <- {
    titleComputed = Computed(@() getMachineGunCaption(MachineGunsModeLocal.get()))
    valueComputed = Computed(@() generateBulletsTextFunction(MachineGunsAmmoCount.get(), MachineGunsAmmoReloadTime.get()))
    isSelectedComputed = Computed(@() !!MachineGunsSelectedArray.get()?[idx])
    alertStateCaptionComputed = Computed(@() IsMachineGunsEmpty.get()?[idx] ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() IsMachineGunsEmpty.get()?[idx] ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
  }
}

for (local i = 0; i < NUM_CANNONS_MAX; ++i) {
  let idx = i
  let CannonAmmoCount = CannonCount[idx]
  let CannonAmmoReloadTime = CannonReloadTime[idx]
  let CannonModeLocal = CannonMode[idx]
  let blinkComputed = Computed(@() GunInDeadZone.get())
  let blinkTrigger = {}
  blinkComputed.subscribe(@(v) v ? anim_start(blinkTrigger) : anim_request_stop(blinkTrigger))
  textParamsMapMain[AirParamsMain.CANNON_1 + idx] <- {
    titleComputed = Computed(@() getCannonsCaption(CannonModeLocal.get()))
    valueComputed = Computed(@() generateBulletsTextFunction(CannonAmmoCount.get(), CannonAmmoReloadTime.get()))
    isSelectedComputed = Computed(@() !!CannonSelectedArray.get()?[idx] || CannonSelected.get())
    alertStateCaptionComputed = Computed(@() (IsCannonEmpty.get()?[idx] || isCannonJamed.get()?[idx]) ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() (IsCannonEmpty.get()?[idx] || isCannonJamed.get()?[idx]) ? HudColorState.HIGH_ALERT :  HudColorState.ACTIV)
    blinkComputed
    blinkTrigger
  }
}

const numParamPerEngine = 3
let textParamsMapSecondary = {}

for (local i = 0; i < NUM_VISIBLE_ENGINES_MAX; ++i) {

  let indexStr = (i + 1).tostring()
  let oilStateComputed = OilState[i]
  let oilTemperatureComputed = OilTemperature[i]
  let oilAlertComputed = OilAlert[i]
  textParamsMapSecondary[AirParamsSecondary.OIL_1 + (i * numParamPerEngine)] <- {
    titleComputed = WatchedRo(loc($"HUD/OIL_TEMPERATURE_SHORT{indexStr}"))
    valueComputed = Computed(@() !isInitializedMeasureUnits.get() ? ""
      : generateTemperatureTextFunction(oilTemperatureComputed.get(), oilStateComputed.get(), measureUnitsNames.get().temperature)) 
    alertStateCaptionComputed = Computed(@() oilAlertComputed.get())
    alertValueStateComputed = Computed(@() oilAlertComputed.get())
  }

  let waterStateComputed = WaterState[i]
  let waterTemperatureComputed = WaterTemperature[i]
  let waterAlertComputed = WaterAlert[i]
  textParamsMapSecondary[AirParamsSecondary.WATER_1 + (i * numParamPerEngine)] <- {
    titleComputed = WatchedRo(loc($"HUD/WATER_TEMPERATURE_SHORT{indexStr}"))
    valueComputed = Computed(@() !isInitializedMeasureUnits.get() ? ""
      : generateTemperatureTextFunction(waterTemperatureComputed.get(), waterStateComputed.get(), measureUnitsNames.get().temperature)) 
    alertStateCaptionComputed = Computed(@() waterAlertComputed.get())
    alertValueStateComputed = Computed(@() waterAlertComputed.get())
  }

  let engineStateComputed = EngineState[i]
  let engineTemperatureComputed = EngineTemperature[i]
  let engineAlertComputed = EngineAlert[i]
  textParamsMapSecondary[AirParamsSecondary.ENGINE_1 + (i * numParamPerEngine)] <- {
    titleComputed = WatchedRo(loc($"HUD/ENGINE_TEMPERATURE_SHORT{indexStr}"))
    valueComputed = Computed(@() !isInitializedMeasureUnits.get() ? ""
      : generateTemperatureTextFunction(engineTemperatureComputed.get(), engineStateComputed.get(), measureUnitsNames.get().temperature)) 
    alertStateCaptionComputed = Computed(@() engineAlertComputed.get())
    alertValueStateComputed = Computed(@() engineAlertComputed.get())
  }
}

for (local i = 0; i < NUM_TRANSMISSIONS_MAX; ++i) {

  let indexStr = (i + 1).tostring();
  let transmissionOilStateComputed = TransmissionOilState[i]
  let isTransmissionAlertComputed = IsTransmissionOilAlert[i]
  textParamsMapSecondary[AirParamsSecondary.TRANSMISSION_1 + i] <- {
    titleComputed = WatchedRo(loc($"HUD/TRANSMISSION_OIL_SHORT{indexStr}"))
   valueComputed = Computed(@() generateTransmissionStateTextFunction(transmissionOilStateComputed.get()))
    alertStateCaptionComputed = Computed(@() isTransmissionAlertComputed.get() ?  HudColorState.HIGH_ALERT : HudColorState.ACTIV)
    alertValueStateComputed = Computed(@() isTransmissionAlertComputed.get() ?  HudColorState.HIGH_ALERT : HudColorState.ACTIV)
  }
}

textParamsMapSecondary[AirParamsSecondary.FUEL] <- {
  titleComputed = WatchedRo(loc("HUD/FUEL_SHORT"))
  valueComputed = Computed(@() getFuelState(Fuel.get(), HasExternalFuel.get(), ExternalFuel.get(), FuelState.get()))
  alertStateCaptionComputed = Computed(@() getFuelAlertState(FuelState.get()))
  alertValueStateComputed = Computed(@() getFuelAlertState(FuelState.get()))
  shortcutComputed = Computed(@() HasExternalFuel.get() ? "{{ID_FUEL_TANKS}}" : "")
}

textParamsMapSecondary[AirParamsSecondary.STAMINA] <- {
  titleComputed = WatchedRo(loc("HUD/TXT_STAMINA_SHORT"))
  valueComputed = Computed(@() getStaminaValue(StaminaValue.get()))
  alertStateCaptionComputed = Computed(@() StaminaState.get())
  alertValueStateComputed = Computed(@() StaminaState.get())
}

textParamsMapSecondary[AirParamsSecondary.INSTRUCTOR] <- {
  titleComputed = Computed(@() getInstructorCaption(InstructorForced.get()))
  valueComputed = WatchedRo("")
  alertStateCaptionComputed = Computed(@() InstructorState.get())
  alertValueStateComputed = Computed(@() InstructorState.get())
}

let fuelKeyId = AirParamsSecondary.FUEL

function generateParamsTable(mainMask, secondaryMask, width, height, posWatched, gap, needCaption = true, forIls = false, is_aircraft = false, font_size = HudStyle.hudFontHgt) {
  function getChildren(colorWatch, style, isBomberView) {
    let children = []
    let vertIndent = { size = const [0, hdpx(12)] }

    foreach (key, param in textParamsMapMain) {
      if ((1 << key) & mainMask.get())
        children.append(createParam(param, width, height, style, colorWatch, needCaption, forIls, isBomberView, font_size))
      if (key == AirParamsMain.RADAR_ALTITUDE && is_aircraft)
        children.append(vertIndent)

    }
    local secondaryMaskValue = secondaryMask.get()
    if (is_aircraft) {
      if ((1 << fuelKeyId) & secondaryMaskValue) {
        children.append(createParam(textParamsMapSecondary[fuelKeyId], width, height, style, colorWatch, needCaption, forIls, isBomberView, font_size))
        secondaryMaskValue = secondaryMaskValue - (1 << fuelKeyId)
      }
    }

    if (is_aircraft)
      children.append(vertIndent)

    foreach (key, param in textParamsMapSecondary) {
      if ((1 << key) & secondaryMaskValue)
        children.append(createParam(param, width, height, style, colorWatch, needCaption, forIls, isBomberView, font_size))
    }

    return children
  }

  return function(colorWatch, isBomberView = false, style = HudStyle.styleText) {
    let table = @() style.__merge({
      key = {}
      watch = [mainMask, secondaryMask, posWatched]
      pos = posWatched.get()
      size = [width, SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      gap
      children = getChildren(colorWatch, style, isBomberView)
      onAttach = @() needShowShHints.subscribe(handleShowShHintsChanges)
      onDetach = @() needShowShHints.unsubscribe(handleShowShHintsChanges)
    })

    return {
      children = table
    }
  }
}

function compassComponent(colorWatch, size, pos) {
  return @() {
    pos
    watch = [IsCompassVisible, colorWatch]
    children = IsCompassVisible.get() ? compass(size, colorWatch.get()) : null
  }
}

function airHorizonZeroLevel(elemStyle, height, color) {
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


function airHorizon(elemStyle, height, color) {
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
      rotate = HorAngle.get()
    }
  })
}


function horizontalSpeedVector(elemStyle, color, height) {
  return elemStyle.__merge({
    rendObj = ROBJ_HELICOPTER_HORIZONTAL_SPEED
    size = [height, height]
    minLengthArrowVisibleSq = 200
    velocityScale = 5
    color
  })
}

function HelicopterHorizontalSpeedComponent(color, posX = sw(50), posY = sh(50), height = hdpx(40), elemStyle = HudStyle.styleLineForeground) {
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

const hl = 20
const vl = 20
const fullRangeMultInv = 0.7

function getAgmLaunchAngularRangeCommands(_visible, yawMin, yawMax, pitchMin, pitchMax) {

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

function getAgmGuidanceRangeCommands(_visible, yawMin, yawMax, pitchMin, pitchMax) {

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

function getAgmLaunchDistanceRangeCommands(_visible, enabled, distMin, distMax, dist) {

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



function turretAngles(colorWatch, width, height, aspect, blinkDuration = 0.5, isSeekerSight = false) {

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
  let isAtgmGuidanceRangeVisible = Computed(@() IsAgmLaunchZoneVisible.get())
  let isAtgmAngularRangeVisible = Computed(@() (IsAgmLaunchZoneVisible.get() && AgmLaunchZoneYawMin.get() > 0.0 && AgmLaunchZoneYawMax.get() < 1.0 && AgmLaunchZonePitchMin.get() > 0.0 && AgmLaunchZonePitchMax.get() < 1.0))
  let atgmLaunchZoneBlinking = Computed(@() !IsInsideLaunchZoneYawPitch.get())
  let atgmLaunchZoneTrigger = {}
  atgmLaunchZoneBlinking.subscribe(@(v) v ? anim_start(atgmLaunchZoneTrigger) : anim_request_stop(atgmLaunchZoneTrigger))
  let atgmLaunchDistanceblinking = Computed(@() IsRangefinderEnabled.get() && !IsInsideLaunchZoneDist.get())
  let atgmLaunchDistanceTrigger = {}
  atgmLaunchDistanceblinking.subscribe(@(v) v ? anim_start(atgmLaunchDistanceTrigger) : anim_request_stop(atgmLaunchDistanceTrigger))

  let outOfZoneTxt = @() HudStyle.styleText.__merge({
    rendObj = ROBJ_TEXT
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    color = colorWatch.get()
    opacity = isAtgmGuidanceRangeVisible.get() && atgmLaunchZoneBlinking.get() && !isSeekerSight ? 100 : 0
    watch = [atgmLaunchZoneBlinking, isAtgmGuidanceRangeVisible]
    pos = [0, sh(-1.8)]
    text = loc("HUD/AGM_OUTSIDE_LAUNCH_ZONE")
  })

  return @() HudStyle.styleLineForeground.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [aspect * width, height]
    color = colorWatch.get()
    halign = ALIGN_CENTER
    valign = ALIGN_TOP
    watch = [colorWatch, atgmLaunchZoneBlinking, isAtgmGuidanceRangeVisible]
    commands = [
      [VECTOR_LINE, 0, 100 - vl, 0, 100, hl, 100],
      [VECTOR_LINE, 100 - hl, 100, 100, 100, 100, 100 - vl],
      [VECTOR_LINE, 100, vl, 100, 0, 100 - hl, 0],
      [VECTOR_LINE, hl, 0, 0, 0, 0, vl]
    ]
    children = [
      @() HudStyle.styleLineForeground.__merge({
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = hdpx(LINE_WIDTH + 1)
        size = [aspect * width, height]
        watch = [TurretYaw, TurretPitch, colorWatch]
        commands = getTurretCommands(TurretYaw.get(), TurretPitch.get())
        color = colorWatch.get()
      }),
      outOfZoneTxt,
      isAtgmAngularRangeVisible.get()
        ? @() HudStyle.styleLineForeground.__merge({
            rendObj = ROBJ_VECTOR_CANVAS
            lineWidth = hdpx(LINE_WIDTH)
            size = [aspect * width, height]
            color = colorWatch.get()
            watch = [
              IsAgmLaunchZoneVisible,
              AgmLaunchZoneYawMin, AgmLaunchZoneYawMax,
              AgmLaunchZonePitchMin, AgmLaunchZonePitchMax,
              colorWatch
            ]
            commands = getAgmLaunchAngularRangeCommands(IsAgmLaunchZoneVisible.get(), AgmLaunchZoneYawMin.get(), AgmLaunchZoneYawMax.get(),
              AgmLaunchZonePitchMin.get(), AgmLaunchZonePitchMax.get())
            animations = [{ prop = AnimProp.opacity, from = 1, to = 0, duration = blinkDuration, play = atgmLaunchZoneBlinking.get(),
              loop = true, easing = InOutSine, trigger = atgmLaunchZoneTrigger }]
          }) : null,
      isAtgmGuidanceRangeVisible.get()
        ? @() HudStyle.styleLineForeground.__merge({
            rendObj = ROBJ_VECTOR_CANVAS
            lineWidth = hdpx(LINE_WIDTH)
            size = [aspect * width, height]
            watch = [
              IsAgmLaunchZoneVisible,
              AgmRotatedLaunchZoneYawMax, AgmRotatedLaunchZoneYawMin,
              AgmRotatedLaunchZonePitchMax, AgmRotatedLaunchZonePitchMin,
              colorWatch
            ]
            color = colorWatch.get()
            commands = getAgmGuidanceRangeCommands(IsAgmLaunchZoneVisible.get(), AgmRotatedLaunchZoneYawMin.get(), AgmRotatedLaunchZoneYawMax.get(),
              AgmRotatedLaunchZonePitchMin.get(), AgmRotatedLaunchZonePitchMax.get())
            animations = [{ prop = AnimProp.opacity, from = 1, to = 0, duration = blinkDuration, play = atgmLaunchZoneBlinking.get(),
              loop = true, easing = InOutSine, trigger = atgmLaunchZoneTrigger }]
          }) : null,
        isAtgmGuidanceRangeVisible.get()
          ? @() HudStyle.styleLineForeground.__merge({
              rendObj = ROBJ_VECTOR_CANVAS
              lineWidth = hdpx(LINE_WIDTH + 1)
              size = [aspect * width, height]
              color = colorWatch.get()
              watch = [
                IsAgmLaunchZoneVisible,
                IsRangefinderEnabled, RangefinderDist,
                AgmLaunchZoneDistMin, AgmLaunchZoneDistMax,
                colorWatch
              ]
              commands = getAgmLaunchDistanceRangeCommands(IsAgmLaunchZoneVisible.get(), IsRangefinderEnabled.get(),
                AgmLaunchZoneDistMin.get(), AgmLaunchZoneDistMax.get(), RangefinderDist.get())
              animations = [{ prop = AnimProp.opacity, from = 1, to = 0, duration = blinkDuration, play = atgmLaunchDistanceblinking.get(),
                loop = true, easing = InOutSine, trigger = atgmLaunchDistanceTrigger }]
            }) : null
    ]
  })
}

let lockSightComponent = function(colorWatch, width, height, posX, posY) {
  let color = Computed(@() IsAgmEmpty.get() ? AlertColorHigh.get() : colorWatch.get())
  return lockSight(color, width, height, posX, posY)
}

function helicopterRocketSightMode(sightMode) {

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

let helicopterRocketAim = @(width, height, color, style = HudStyle.styleLineForeground) function() {

  let lines = helicopterRocketSightMode(RocketSightMode.get())

  return style.__merge({
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    rendObj = ROBJ_VECTOR_CANVAS
    size = [width, height]
    color
    watch = [RocketAimX, RocketAimY, RocketAimVisible, RocketSightMode]
    opacity = RocketAimVisible.get() ? 100 : 0
    transform = {
      translate = [RocketAimX.get(), RocketAimY.get()]
    }
    commands = lines
  })
}

let turretAnglesAspect = 2.0
let turretAnglesComponent = function(colorWatch, width, height, posX, posY, blinkDuration = 0.5, isSeekerSight = false) {
  return {
    pos = [posX - turretAnglesAspect * width * 0.5, posY - height]
    size = SIZE_TO_CONTENT
    children = turretAngles(colorWatch, width, height, turretAnglesAspect, blinkDuration, isSeekerSight)
  }
}



function agmLaunchZone(colorWatch, _w, _h) {
  let isLaunchZoneBlinking = Computed(@() !IsInsideLaunchZoneYawPitch.get())
  let isLaunchZoneTrigger = {}
  isLaunchZoneBlinking.subscribe(@(v) v ? anim_start(isLaunchZoneTrigger) : anim_request_stop(isLaunchZoneTrigger))

  let zoneElem = function() {
    let zoneParent = HudStyle.styleLineForeground.__merge({
      rendObj = ROBJ_VECTOR_CANVAS
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      size = flex()
      color = colorWatch.get()
      watch = [ IsAgmLaunchZoneVisible,
        AgmLaunchZoneYawMin, AgmLaunchZoneYawMax,
        AgmLaunchZonePitchMin, AgmLaunchZonePitchMax,
        TurretYaw, TurretPitch, IsZoomedAgmLaunchZoneVisible,
        FovYaw, FovPitch, IsInsideLaunchZoneYawPitch,
        colorWatch
      ]
      animations = [{ prop = AnimProp.opacity, from = 0, to = 1, duration = 0.25, play = isLaunchZoneBlinking.get(),
        loop = true, easing = InOutSine, trigger = isLaunchZoneTrigger }]
    })
    local drawRectCommands = null
    if (IsAgmLaunchZoneVisible.get() && IsZoomedAgmLaunchZoneVisible.get()) {
      let left  = ((AgmLaunchZoneYawMin.get()) * 100.0 - TurretYaw.get() * 100.0) * FovYaw.get() + 50.0
      let right = ((AgmLaunchZoneYawMax.get()) * 100.0 - TurretYaw.get() * 100.0) * FovYaw.get() + 50.0
      let lower = 100.0 - ((AgmLaunchZonePitchMin.get()) * 100.0 - TurretPitch.get() * 100.0) * FovPitch.get() - 50
      let upper = 100.0 - ((AgmLaunchZonePitchMax.get()) * 100.0 - TurretPitch.get() * 100.0) * FovPitch.get() - 50

      if ((left < 100.0) && (right > 0.0) && (upper < 100.0) && (lower > 0.0)) {
        drawRectCommands = [
          [VECTOR_LINE, left,  upper, right, upper],
          [VECTOR_LINE, right, upper, right, lower],
          [VECTOR_LINE, right, lower, left,  lower],
          [VECTOR_LINE, left,  lower, left,  upper]
        ]
      } else {
        
        let ax = ((left + right) * 0.5 - 50) * 0.100
        let ay = ((lower + upper) * 0.5 - 50) * 0.100
        local x1, y1;
        let aax = math.abs(ax), aay = math.abs(ay)
        if (aax >= aay) {
          x1 = ax <= 0 ? -1 : 1
          y1 = (aax > 0.001) ? (ay / ax) * x1 : 1
        }
        else {
          y1 = ay <= 0 ? -1 : 1
          x1 = (aay > 0.001) ? (ax / ay) * y1 : 1
        }
        x1 = x1 * 50. + 50.
        y1 = y1 * 50. + 50.

        let sxh = 2.0, syh = 3.0, d = 0.5
        let drawArrowCommands = [
          [VECTOR_LINE, 0, 0,   sxh, syh,   sxh * d, syh,   sxh * d, syh * 2.0,   0, syh * 2.0 ],
          [VECTOR_LINE, 0, 0,  -sxh, syh,  -sxh * d, syh,  -sxh * d, syh * 2.0,  -0, syh * 2.0 ]
        ]
        let arrowElem = {
          rendObj = ROBJ_VECTOR_CANVAS
          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
          size = flex()
          color = colorWatch.get()
          commands = drawArrowCommands
          transform = {
            translate = [sw(x1), sh(y1)]
            pivot = [0, 0]
            rotate = math.atan2(ay, ax) * (180. / math.PI) + 90.
          }
        }
        zoneParent.children <- arrowElem
      }
    }
    zoneParent.commands <- drawRectCommands
    return zoneParent
  }

  return @() {
    rendObj = ROBJ_VECTOR_CANVAS
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    size = flex()
    color = colorWatch.get()
    children = [ zoneElem ]
    watch = [IsInsideLaunchZoneYawPitch, colorWatch]
  }
}

function targetAngleBorder(yawMin, yawMax, pitchMin, pitchMax) {
  let left  = max(0.0, yawMin) * 100.0 - 50.0
  let right = min(1.0, yawMax) * 100.0 - 50.0
  let lower = 100.0 - max(0.0, pitchMin) * 100.0 - 25.0
  let upper = 100.0 - min(1.0, pitchMax) * 100.0 - 25.0
  return [
    [VECTOR_LINE, left,  upper, right, upper],
    [VECTOR_LINE, right, upper, right, lower],
    [VECTOR_LINE, right, lower, left,  lower],
    [VECTOR_LINE, left,  lower, left,  upper]
  ]
}

function unitAngleBorder(launchZone, corner) {
  let { x0, x1, x2, x3, y0, y1, y2, y3 } = launchZone
  return [
    [VECTOR_LINE, x0, y0, x0 + (x1 - x0)*corner, y0 + (y1 - y0)*corner],
    [VECTOR_LINE, x0, y0, x0 + (x2 - x0)*corner, y0 + (y2 - y0)*corner],

    [VECTOR_LINE, x1, y1, x1 + (x0 - x1)*corner, y1 + (y0 - y1)*corner],
    [VECTOR_LINE, x1, y1, x1 + (x3 - x1)*corner, y1 + (y3 - y1)*corner],

    [VECTOR_LINE, x2, y2, x2 + (x0 - x2)*corner, y2 + (y0 - y2)*corner],
    [VECTOR_LINE, x2, y2, x2 + (x3 - x2)*corner, y2 + (y3 - y2)*corner],

    [VECTOR_LINE, x3, y3, x3 + (x1 - x3)*corner, y3 + (y1 - y3)*corner],
    [VECTOR_LINE, x3, y3, x3 + (x2 - x3)*corner, y3 + (y2 - y3)*corner],
  ]
}

let zoneStyle = HudStyle.styleLineForeground.__merge({
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = hdpx(LINE_WIDTH)
  size = const [sw(100), sh(100)]
})

let blinking = [{
  prop = AnimProp.opacity,
  from = 1,
  to = 0,
  duration = 0.33,
  loop = true,
  easing = InOutSine,
  play = true
}]

function targetLaunchZone(color) {
  return @() zoneStyle.__merge({
    color = color
    watch = [AgmLaunchZoneYawMin, AgmLaunchZoneYawMax,
      AgmLaunchZonePitchMin, AgmLaunchZonePitchMax,
      LaunchZonePosX, LaunchZonePosY]
    commands = targetAngleBorder(AgmLaunchZoneYawMin.get(), AgmLaunchZoneYawMax.get(),
      AgmLaunchZonePitchMin.get(), AgmLaunchZonePitchMax.get())
    transform = { translate = [LaunchZonePosX.get(), LaunchZonePosY.get()] }
    animations = blinking
  })
}

function unitLaunchZone(color, isBlinking) {
  return @() zoneStyle.__merge({
    color = color
    watch = [LaunchZoneWatched, IsOutLaunchZone]
    commands = unitAngleBorder(LaunchZoneWatched.get(), IsOutLaunchZone.get() ? 0.1 : 0.5)
    key = isBlinking
    animations = isBlinking ? blinking : null
  })
}

function agmLaunchZoneTps(colorWatch) {
  return @() {
    watch = [IsLaunchZoneAvailable, IsLaunchZoneOnTarget, IsOutLaunchZone]
    children = IsLaunchZoneAvailable.get() && IsLaunchZoneOnTarget.get() && IsOutLaunchZone.get()
      ? targetLaunchZone(colorWatch.get())
      : IsLaunchZoneAvailable.get() && !IsLaunchZoneOnTarget.get() ? unitLaunchZone(colorWatch.get(), IsOutLaunchZone.get())
      : null
  }
}

function sight(colorWatch, height) {
  let longL = 22
  let shortL = 10
  let dash = 0.8
  let centerOffset = 3

  return @() HudStyle.styleLineForeground.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [height, height]
    color = colorWatch.get()
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

function launchDistanceMaxComponent(colorWatch, width, height, posX, posY) {

  let getAgmLaunchDistanceMax = function() {
    return IsAgmLaunchZoneVisible.get() ?
      cross_call.measureTypes.DISTANCE_SHORT.getMeasureUnitsText(AgmLaunchZoneDistMax.get()) : ""
  }

  let launchDistanceMax = @() HudStyle.styleText.__merge({
    rendObj = ROBJ_TEXT
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    color = colorWatch.get()
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
    size = 0
    children = launchDistanceMax
  }

  return resCompoment
}

function rangeFinderComponent(colorWatch, posX, posY) {
  let rangefinder = @() HudStyle.styleText.__merge({
    rendObj = ROBJ_TEXT
    halign = ALIGN_CENTER
    text = cross_call.measureTypes.DISTANCE_SHORT.getMeasureUnitsText(RangefinderDist.get())
    opacity = IsRangefinderEnabled.get() ? 100 : 0
    color = colorWatch.get()
    watch = [RangefinderDist, IsRangefinderEnabled, colorWatch]
  })

  let resCompoment = @() {
    pos = [posX, posY]
    halign = ALIGN_CENTER
    size = 0
    children = rangefinder
  }

  return resCompoment
}

let triggerTATargetAge = {}
TargetAge.subscribe(@(v) v > 0.2 ? anim_start(triggerTATargetAge) : anim_request_stop(triggerTATargetAge))
let triggerTATargetInGimbal = {}
TargetInZone.subscribe(@(v) !v ? anim_start(triggerTATargetInGimbal) : anim_request_stop(triggerTATargetInGimbal))
let HelicopterTATarget = @(w, h, isForIls) function() {

  let VisibleWatch = isForIls ? AimLockValid : TATargetVisible
  let res = {
    watch = [VisibleWatch, TargetX, TargetY, TargetInZone, IsTargetTracked,
      TargetAge, AlertColorHigh, IsLaserDesignatorEnabled]
    animations = [
      { prop = AnimProp.opacity, from = 0, to = 1, duration = 0.50, play = TargetAge.get() > 0.2, loop = true, easing = InOutSine, trigger = triggerTATargetAge },
      { prop = AnimProp.opacity, from = 0, to = 1, duration = 0.25, play = !TargetInZone.get(), loop = true, easing = InOutSine, trigger = triggerTATargetInGimbal }
    ]
    key = [TargetAge, TargetInZone]
  }

  if (!VisibleWatch.get() && TargetAge.get() < 0.2)
    return res

  
  let taTargetcommands = [
    [VECTOR_LINE, -10, -10, 10, -10],
    [VECTOR_LINE, 10, -10, 10, 10],
    [VECTOR_LINE, 10, 10, -10, 10],
    [VECTOR_LINE, -10, 10, -10, -10]
  ]

  if (IsTargetTracked.get()) {
    taTargetcommands.append([VECTOR_LINE, -5, 0, -10, 0])
    taTargetcommands.append([VECTOR_LINE, 5, 0, 10, 0])
    taTargetcommands.append([VECTOR_LINE, 0, -5, 0, -10])
    taTargetcommands.append([VECTOR_LINE, 0, 5, 0, 10])
  }

  if (IsLaserDesignatorEnabled.get()) {
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
    color = AlertColorHigh.get()
    transform = {
      translate = [isForIls ? AimLockPos[0] : TargetX.get(), isForIls ? AimLockPos[1] : TargetY.get()]
    }
    commands = taTargetcommands
  })
}

let targetSizeComponent = function(colorWatch, width, height) {
  return @() {
    pos = [0, 0]
    size = SIZE_TO_CONTENT
    watch = IsMfdEnabled
    children = targetSize(colorWatch, width, height, IsMfdEnabled.get())
  }
}

let detectAllyComponent = @(posX, posY) function() {

  let res = { watch = [DetectAllyProgress, DetectAllyState] }
  if (DetectAllyProgress.get() < 1.0)
    return res

  return res.__update(HudStyle.styleText.__merge({
    rendObj = ROBJ_TEXT
    text = DetectAllyProgress.get() < 1.0 ? loc("detect_ally_progress")
      : (DetectAllyState.get() ? loc("detect_ally_success")
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
  agmLaunchZoneTps = agmLaunchZoneTps
  sight = sightComponent
  launchDistanceMax = launchDistanceMaxComponent
  rangeFinder = rangeFinderComponent
  taTarget = HelicopterTATarget
  targetSize = targetSizeComponent
  lockSight = lockSightComponent
  rocketAim = helicopterRocketAim
  detectAlly = detectAllyComponent
}
} 

return getAirHudElemsTable()