let interopGen = require("interopGen.nut")

let NUM_ENGINES_MAX = 16   //!!!FIX ME: Need get this const from native code
const NUM_TRANSMISSIONS_MAX = 6
const NUM_CANNONS_MAX = 3
const NUM_TURRETS_MAX = 10

const NUM_BOMB_RELEASE_POINT = 80

local IndicatorsVisible = Watched(false)
local CurrentTime = Watched(false)

let DistanceToGround = Watched(0.0)
let VerticalSpeed = Watched(0.0)

let RocketAimX = Watched(0.0)
let RocketAimY = Watched(0.0)
let RocketAimVisible = Watched(false)
let RocketSightMode = Watched(0) //Sight shape need to change in function of CCIP/CCRP
let RocketSightSizeFactor = Watched(0.0)

let TATargetVisible = Watched(false)

let GunDirectionX = Watched(0.0)
let GunDirectionY = Watched(0.0)
let GunDirectionVisible = Watched(false)
let GunInDeadZone = Watched(false)
let GunSightMode = Watched(0)

let HorAngle = Watched(0.0)

let TurretYaw   = Watched(0.0)
let TurretPitch = Watched(0.0)
let FovYaw    = Watched(0.0)
let FovPitch  = Watched(0.0)

let IsAgmLaunchZoneVisible       = Watched(false)
let IsZoomedAgmLaunchZoneVisible = Watched(false)
let AgmLaunchZoneYawMin          = Watched(0.0)
let AgmLaunchZoneYawMax          = Watched(0.0)
let AgmLaunchZonePitchMin        = Watched(0.0)
let AgmLaunchZonePitchMax        = Watched(0.0)
let AgmRotatedLaunchZoneYawMax   = Watched(0.0)
let AgmRotatedLaunchZoneYawMin   = Watched(0.0)
let AgmRotatedLaunchZonePitchMax = Watched(0.0)
let AgmRotatedLaunchZonePitchMin = Watched(0.0)
let AgmLaunchZoneDistMin         = Watched(0.0)
let AgmLaunchZoneDistMax         = Watched(0.0)

let IRCMState                    = Watched(0)

let IsInsideLaunchZoneYawPitch = Watched(false)
let IsInsideLaunchZoneDist = Watched(false)

let IsLaserDesignatorEnabled = Watched(false)
let IsATGMOutOfTrackerSector = Watched(false)
let NoLosToATGM = Watched(false)
let AtgmTrackerRadius = Watched(0.0)

let MainMask = Watched(0)
let SecondaryMask = Watched(0)
let SightMask = Watched(0)
let IlsMask = Watched(0)
let MfdSightMask = Watched(0)
let EmptyMask = Watched(0)
let TargetPodMask = Watched(0)

let HudColor = Watched(Color(71, 232, 39, 240))
let HudParamColor = Watched(Color(240, 240, 240, 240))
let AlertColorLow = Watched(Color(220, 220, 220, 240))
let AlertColorMedium = Watched(Color(220, 120, 120, 240))
let AlertColorHigh = Watched(Color(230, 0, 0, 240))
let MfdColor = Watched(Color(71, 232, 39, 240))
let PassivColor = Watched(Color(160, 160, 160, 240))
let TargetPodHudColor = Watched(Color(71, 232, 39, 240))

let TrtMode = []
let Trt = []
let IsEnginesControled = Watched(false)
let isEngineControled = []
let ThrottleState = []

let Rpm = Watched(0)
let Spd = Watched(0)
let Mach = Watched(0)
let CritMach = Watched(false)
let Ias = Watched(0)
let CritIas = Watched(false)

let CannonCount = []
let CannonReloadTime = []
let IsCannonEmpty = Watched(array(NUM_CANNONS_MAX, false))
let isAllCannonsEmpty = Computed(@() !IsCannonEmpty.value.contains(false))
let CannonMode = Watched(0)
let CannonSelected = Watched(false)

let InstructorState = Watched(0)
let InstructorForced = Watched(false)

let StaminaValue  = Watched(0.0)
let StaminaState = Watched(0)

local BombReleaseVisible = Watched(false)
local BombReleaseDirX = Watched(0)
local BombReleaseDirY = Watched(0)
local BombReleaseOpacity = Watched(0.0)
local BombReleaseRelativToTarget = Watched(0.0)

local BombReleasePoints = Watched(array(NUM_BOMB_RELEASE_POINT, 0.0))

let CanonSightOpacity = Watched(1.0)
let RocketSightOpacity = Watched(1.0)
let ParamTableOpacity = Watched(1.0)

let CanonSightShadowOpacity = Watched(1.0)
let RocketSightShadowOpacity = Watched(1.0)
let ParamTableShadowOpacity = Watched(1.0)
let BombSightShadowOpacity = Watched(1.0)

let CanonSightLineWidthFactor = Watched(1.0)
let RocketSightLineWidthFactor = Watched(1.0)
let BombSightLineWidthFactor = Watched(1.0)
let ParamTableShadowFactor = Watched(1.0)

let CanonSightShadowLineWidthFactor = Watched(1.0)
let RocketSightShadowLineWidthFactor = Watched(1.0)
let BombSightShadowLineWidthFactor = Watched(1.0)

let TurretSightOpacity = Watched(1.0)
let TurretSightLineWidthFactor = Watched(1.0)

local MachineGuns = {
  count = Watched(0)
  seconds = Watched(-1)
  mode = Watched(0)
  selected = Watched(false)
}

let CannonsAdditional = {
  count = Watched(0)
  seconds = Watched(-1)
  mode = Watched(0)
  selected = Watched(false)
}

let Rockets = {
  count = Watched(0)
  seconds = Watched(-1)
  mode = Watched(0)
  selected = Watched(false)
  salvo = Watched(0)
  name = Watched("")
  actualCount = Watched(-1)
}

let Agm = {
  count = Watched(0)
  seconds = Watched(-1)
  timeToHit = Watched(-1)
  timeToWarning = Watched(-1)
  selected = Watched(false)
  name = Watched("")
  actualCount = Watched(-1)
}

let Aam = {
  count = Watched(0)
  seconds = Watched(-1)
  selected = Watched(false)
  name = Watched("")
  actualCount = Watched(-1)
}

let GuidedBombs = {
  seconds = Watched(-1)
  count = Watched(0)
  mode = Watched(0)
  selected = Watched(false)
  name = Watched("")
  actualCount = Watched(-1)
}

let Bombs = {
  seconds = Watched(-1)
  count = Watched(0)
  mode = Watched(0)
  selected = Watched(false)
  salvo = Watched(0)
  name = Watched("")
  actualCount = Watched(-1)
}

let Flares = {
  count = Watched(0)
  seconds = Watched(-1)
  mode = Watched(0)
  selected = Watched(false)
}

let Chaffs = {
  count = Watched(0)
  seconds = Watched(-1)
  mode = Watched(0)
  selected = Watched(false)
}

let IsMachineGunEmpty = Watched(false)
let IsCanAdditionalEmpty = Watched(false)
let IsRktEmpty = Watched(false)
let IsAgmEmpty = Watched(false)
let IsAamEmpty = Watched(false)
let IsGuidedBmbEmpty = Watched(false)
let IsBmbEmpty = Watched(false)
let IsFlrEmpty = Watched(false)
let IsChaffsEmpty = Watched(false)

let IsHighRateOfFire = Watched(false)

let IsRpmVisible = Watched(false)
let IsRpmCritical = Watched(false)

let FixedGunDirectionX = Watched(-100)
let FixedGunDirectionY = Watched(-100)
let FixedGunDirectionVisible = Watched(false)
let FixedGunSightMode = Watched(0)
let FixedGunOverheat = Watched(0.0)

let IsRangefinderEnabled = Watched(false)
let RangefinderDist = Watched(0)

let TurretsDirectionX = []
let TurretsDirectionY = []
let TurretsOverheat= []
let TurretsReloading = []
let TurretsEmpty = []
let TurretsVisible = []

let OilTemperature = []
let WaterTemperature = []
let EngineTemperature = []

let OilState = []
let WaterState = []
let EngineState = []
let TransmissionOilState = []
let Fuel = Watched(-1)
let FuelState = Watched(0)

let OilAlert = []
let WaterAlert = []
let EngineAlert = []
let IsTransmissionOilAlert = []

let IsMainHudVisible = Watched(false)
let IsSightHudVisible = Watched(false)
let IsPilotHudVisible = Watched(false)
let IsWeaponHudVisible = Watched(false)
let IsGunnerHudVisible = Watched(false)
let IsBomberViewHudVisible = Watched(false)
let IsArbiterHudVisible = Watched(false)
let IsMfdEnabled = Watched(false)
let IsIlsEnabled = Watched(false)
let IsMfdSightHudVisible = Watched(false)
let RwrForMfd = Watched(false)
let RwrPosSize = Watched([0, 0, 20, 20])
let MlwsLwsForMfd = Watched(false)
let MfdSightPosSize = [0, 0, 0, 0]
let IlsPosSize = [0, 0, 0, 0]
let DetectAllyProgress = Watched(-1)
let DetectAllyState = Watched(false)

let GunOverheatState = Watched(0)

let IsCompassVisible = Watched(false)

//reactivHud Activation
let isBombSightActivated = Watched(false)
let isAAMSightActivated = Watched(false)
let isRocketSightActivated = Watched(false)
let isCanonSightActivated = Watched(false)
let isTurretSightActivated = Watched(false)
let isParamTableActivated = Watched(false)

let helicopterState = {

  IndicatorsVisible,
  CurrentTime,

  DistanceToGround,
  VerticalSpeed,

  RocketAimX,
  RocketAimY,
  RocketAimVisible,
  RocketSightMode,
  RocketSightSizeFactor,

  TATargetVisible,

  GunDirectionX,
  GunDirectionY,
  GunDirectionVisible,
  GunInDeadZone,
  GunSightMode,

  HorAngle,

  isAllCannonsEmpty,

  TurretYaw,
  TurretPitch,
  FovYaw,
  FovPitch,

  IsAgmLaunchZoneVisible,
  IsZoomedAgmLaunchZoneVisible,
  AgmLaunchZoneYawMin,
  AgmLaunchZoneYawMax,
  AgmLaunchZonePitchMin,
  AgmLaunchZonePitchMax,
  AgmRotatedLaunchZoneYawMax,
  AgmRotatedLaunchZoneYawMin,
  AgmRotatedLaunchZonePitchMax,
  AgmRotatedLaunchZonePitchMin,
  AgmLaunchZoneDistMin,
  AgmLaunchZoneDistMax,

  IRCMState,

  IsInsideLaunchZoneYawPitch,
  IsInsideLaunchZoneDist,

  IsLaserDesignatorEnabled,
  IsATGMOutOfTrackerSector,
  NoLosToATGM,
  AtgmTrackerRadius,

  MainMask,
  SecondaryMask,
  SightMask,
  IlsMask,
  MfdSightMask,
  EmptyMask,
  TargetPodMask,

  HudColor,
  HudParamColor,
  AlertColorLow,
  AlertColorMedium,
  AlertColorHigh,
  MfdColor,
  PassivColor,
  TargetPodHudColor,

  TrtMode,
  Trt,
  IsEnginesControled,
  isEngineControled,
  ThrottleState,

  Rpm,
  Spd,
  Mach,
  CritMach,
  Ias,
  CritIas,

  CannonCount,
  CannonReloadTime,
  IsCannonEmpty,
  CannonMode,
  CannonSelected,

  InstructorState,
  InstructorForced,

  StaminaValue,
  StaminaState

  MachineGuns,
  CannonsAdditional,
  Rockets, Agm, Aam, GuidedBombs, Bombs, Flares, Chaffs

  IsMachineGunEmpty,
  IsCanAdditionalEmpty,
  IsRktEmpty,
  IsAgmEmpty,
  IsAamEmpty,
  IsGuidedBmbEmpty,
  IsBmbEmpty,
  IsFlrEmpty,
  IsChaffsEmpty,

  IsHighRateOfFire,

  IsRpmVisible,
  IsRpmCritical,

  FixedGunDirectionX,
  FixedGunDirectionY,
  FixedGunDirectionVisible,
  FixedGunSightMode,
  FixedGunOverheat,

  IsRangefinderEnabled,
  RangefinderDist,

  TurretsDirectionX,
  TurretsDirectionY,
  TurretsOverheat,
  TurretsReloading,
  TurretsEmpty,
  TurretsVisible,

  OilTemperature,
  WaterTemperature,
  EngineTemperature,

  OilState,
  WaterState,
  EngineState,
  TransmissionOilState,
  Fuel,
  FuelState,

  OilAlert,
  WaterAlert,
  EngineAlert,
  IsTransmissionOilAlert,

  IsMainHudVisible,
  IsSightHudVisible,
  IsPilotHudVisible,
  IsWeaponHudVisible,
  IsGunnerHudVisible,
  IsBomberViewHudVisible,
  IsArbiterHudVisible,
  IsMfdEnabled,
  IsIlsEnabled,
  IsMfdSightHudVisible,
  RwrForMfd,
  RwrPosSize,
  MlwsLwsForMfd,
  MfdSightPosSize,
  IlsPosSize,
  DetectAllyProgress,
  DetectAllyState,

  GunOverheatState,

  IsCompassVisible,

  BombReleaseVisible,
  BombReleaseDirX,
  BombReleaseDirY,
  BombReleaseOpacity,
  BombReleaseRelativToTarget,

  BombReleasePoints,

  isBombSightActivated,
  isAAMSightActivated,
  isRocketSightActivated,
  isCanonSightActivated,
  isTurretSightActivated,
  isParamTableActivated,

  CanonSightOpacity,
  RocketSightOpacity,
  ParamTableOpacity,
  CanonSightShadowOpacity,
  RocketSightShadowOpacity,
  ParamTableShadowOpacity,
  BombSightShadowOpacity,
  CanonSightLineWidthFactor,
  RocketSightLineWidthFactor,
  BombSightLineWidthFactor,
  CanonSightShadowLineWidthFactor,
  RocketSightShadowLineWidthFactor,
  BombSightShadowLineWidthFactor,
  ParamTableShadowFactor,
  TurretSightOpacity,
  TurretSightLineWidthFactor,

  NUM_ENGINES_MAX,
}

::interop.updateCannons <- function(index, count, sec = -1) {
  CannonCount[index](count)
  CannonReloadTime[index](sec)
}

::interop.updateIsCannonEmpty <- function(index, is_empty) {
  if (is_empty != IsCannonEmpty.value[index])
    IsCannonEmpty.mutate(@(v) v[index] = is_empty)
}

::interop.updateRwrPosSize <- @(x, y, w, h = null) RwrPosSize([x, y, w, h ?? w])

::interop.updateMfdSightPosSize <- function(x, y, w, h) {
  MfdSightPosSize[0] = x
  MfdSightPosSize[1] = y
  MfdSightPosSize[2] = w
  MfdSightPosSize[3] = h
}

::interop.updateIlsPosSize <- function(x, y, w, h) {
  IlsPosSize[0] = x
  IlsPosSize[1] = y
  IlsPosSize[2] = w
  IlsPosSize[3] = h
}

::interop.updateMachineGuns <- function(count, sec = -1, mode = 0, selected = false) {
  MachineGuns.count.update(count)
  MachineGuns.mode.update(mode)
  MachineGuns.seconds.update(sec)
  MachineGuns.selected.update(selected)
}

::interop.updateAdditionalCannons <- function(count, sec = -1, mode = 0, selected = false) {
  CannonsAdditional.count.update(count)
  CannonsAdditional.seconds.update(sec)
  CannonsAdditional.mode.update(mode)
  CannonsAdditional.selected.update(selected)
}

::interop.updateRockets <- function(count, sec = -1, mode = 0, selected = false, salvo = 0, name = "", actualCount = -1) {
  Rockets.count.update(count)
  Rockets.mode.update(mode)
  Rockets.seconds.update(sec)
  Rockets.selected.update(selected)
  Rockets.salvo.update(salvo)
  Rockets.name.update(name)
  Rockets.actualCount.update(actualCount)
}

::interop.updateAgm <- function(count, sec, timeToHit, timeToWarning, selected = false, name = "", actualCount = -1) {
  Agm.count.update(count)
  Agm.seconds.update(sec)
  Agm.timeToHit.update(timeToHit)
  Agm.timeToWarning.update(timeToWarning)
  Agm.selected.update(selected)
  Agm.name.update(name)
  Agm.actualCount.update(actualCount)
}

::interop.updateAam <- function(count, sec = -1, selected = -1, name = "", actualCount = -1) {
  Aam.count.update(count)
  Aam.seconds.update(sec)
  Aam.selected.update(selected)
  Aam.name.update(name)
  Aam.actualCount.update(actualCount)
}

::interop.updateBombs <- function(count, sec = -1,  mode = 0, selected = false, salvo = 0, name = "", actualCount = -1) {
  Bombs.count.update(count)
  Bombs.mode.update(mode)
  Bombs.seconds.update(sec)
  Bombs.selected.update(selected)
  Bombs.salvo.update(salvo)
  Bombs.name.update(name)
  Bombs.actualCount.update(actualCount)
}

::interop.updateGuidedBombs <- function(count, sec = -1,  mode = 0, selected = false, name = "", actualCount = -1) {
  GuidedBombs.count.update(count)
  GuidedBombs.mode.update(mode)
  GuidedBombs.seconds.update(sec)
  GuidedBombs.selected.update(selected)
  GuidedBombs.name.update(name)
  GuidedBombs.actualCount.update(actualCount)
}

::interop.updateFlares <- function(count, mode = 0, sec = -1) {
  Flares.count.update(count)
  Flares.mode.update(mode)
  Flares.seconds.update(sec)
}

::interop.updateChaffs <- function(count, mode = 0, sec = -1) {
  Chaffs.count.update(count)
  Chaffs.mode.update(mode)
  Chaffs.seconds.update(sec)
}

for (local i = 0; i < NUM_CANNONS_MAX; ++i) {
  CannonCount.append(Watched(0))
  CannonReloadTime.append(Watched(-1))
}

for (local i = 0; i < NUM_ENGINES_MAX; ++i) {
  TrtMode.append(Watched(0))
  Trt.append(Watched(0))
  isEngineControled.append(Watched(false))
  ThrottleState.append(Watched(1))
}

for (local i = 0; i < NUM_TURRETS_MAX; ++i) {
  TurretsDirectionX.append(Watched(0.0))
  TurretsDirectionY.append(Watched(0.0))
  TurretsOverheat.append(Watched(0.0))
  TurretsReloading.append(Watched(false))
  TurretsEmpty.append(Watched(false))
  TurretsVisible.append(Watched(false))
}

for (local i = 0; i < NUM_ENGINES_MAX; ++i){
  OilTemperature.append(Watched(0))
  WaterTemperature.append(Watched(0))
  EngineTemperature.append(Watched(0))

  OilState.append(Watched(0))
  WaterState.append(Watched(0))
  EngineState.append(Watched(0))

  OilAlert.append(Watched(0))
  WaterAlert.append(Watched(0))
  EngineAlert.append(Watched(0))
}

for (local i = 0; i < NUM_TRANSMISSIONS_MAX; ++i) {
  TransmissionOilState.append(Watched(0))
  IsTransmissionOilAlert.append(Watched(false))
}

interopGen({
  stateTable = helicopterState
  prefix = "air"
  postfix = "Update"
})

::interop.updateTurretsVisibility <- function (visible, index) {
  TurretsVisible[index](visible)
}

::interop.updateTurrets <- function (X, Y, overheat, isReloading, empty, visible, index) {
  TurretsDirectionX[index](X)
  TurretsDirectionY[index](Y)
  TurretsOverheat[index](overheat)
  TurretsReloading[index](isReloading)
  TurretsEmpty[index](empty)
  TurretsVisible[index](visible)
}

::interop.updateOilTemperature <- function (temperature, state, index) {
  OilTemperature[index](temperature)
  OilState[index](state)
}

::interop.updateWaterTemperature <- function (temperature, state, index) {
  WaterTemperature[index](temperature)
  WaterState[index](state)
}

::interop.updateEngineTemperature <- function (temperature, state, index) {
  EngineTemperature[index](temperature)
  EngineState[index](state)
}

::interop.updateTransmissionOilState <- function (state, index) {
  TransmissionOilState[index](state)
}

::interop.updateOilAlert <- function (value, index) {
  OilAlert[index](value)
}

::interop.updateTransmissionOilAlert <- function (value, index) {
  IsTransmissionOilAlert[index](value)
}

::interop.updateWaterAlert <- function (value, index) {
  WaterAlert[index](value)
}

::interop.updateEngineAlert <- function (value, index) {
  EngineAlert[index](value)
}

::interop.updateEnginesThrottle <- function(mode, trt, state, index) {
  TrtMode[index](mode)
  Trt[index](trt)
  ThrottleState[index](state)
}

::interop.updateEngineControl <- function(index, is_controlled) {
  isEngineControled[index](is_controlled)
}

return helicopterState