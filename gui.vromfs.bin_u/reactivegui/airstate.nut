local interopGen = require("interopGen.nut")

const NUM_ENGINES_MAX = 6
const NUM_TRANSMISSIONS_MAX = 6
const NUM_CANNONS_MAX = 3
const NUM_TURRETS_MAX = 10

local IndicatorsVisible = Watched(false)
local CurrentTime = Watched(false)

local DistanceToGround = Watched(0.0)
local VerticalSpeed = Watched(0.0)

local RocketAimX = Watched(0.0)
local RocketAimY = Watched(0.0)
local RocketAimVisible = Watched(false)
local RocketSightMode = Watched(0) //Sight shape need to change in function of CCIP/CCRP

local TATargetVisible = Watched(false)

local GunDirectionX = Watched(0.0)
local GunDirectionY = Watched(0.0)
local GunDirectionVisible = Watched(false)
local GunInDeadZone = Watched(false)
local GunSightMode = Watched(0)

local HorAngle = Watched(0.0)

local TurretYaw   = Watched(0.0)
local TurretPitch = Watched(0.0)
local FovYaw    = Watched(0.0)
local FovPitch  = Watched(0.0)

local IsAgmLaunchZoneVisible       = Watched(false)
local IsZoomedAgmLaunchZoneVisible = Watched(false)
local AgmLaunchZoneYawMin          = Watched(0.0)
local AgmLaunchZoneYawMax          = Watched(0.0)
local AgmLaunchZonePitchMin        = Watched(0.0)
local AgmLaunchZonePitchMax        = Watched(0.0)
local AgmRotatedLaunchZoneYawMax   = Watched(0.0)
local AgmRotatedLaunchZoneYawMin   = Watched(0.0)
local AgmRotatedLaunchZonePitchMax = Watched(0.0)
local AgmRotatedLaunchZonePitchMin = Watched(0.0)
local AgmLaunchZoneDistMin         = Watched(0.0)
local AgmLaunchZoneDistMax         = Watched(0.0)

local IRCMState                    = Watched(0)

local IsInsideLaunchZoneYawPitch = Watched(false)
local IsInsideLaunchZoneDist = Watched(false)

local IsLaserDesignatorEnabled = Watched(false)
local IsATGMOutOfTrackerSector = Watched(false)
local NoLosToATGM = Watched(false)
local AtgmTrackerRadius = Watched(0.0)

local MainMask = Watched(0)
local SecondaryMask = Watched(0)
local SightMask = Watched(0)
local IlsMask = Watched(0)
local MfdSightMask = Watched(0)
local EmptyMask = Watched(0)
local TargetPodMask = Watched(0)

local HudColor = Watched(Color(71, 232, 39, 240))
local HudParamColor = Watched(Color(240, 240, 240, 240))
local AlertColorLow = Watched(Color(220, 220, 220, 240))
local AlertColorMedium = Watched(Color(220, 120, 120, 240))
local AlertColorHigh = Watched(Color(230, 0, 0, 240))
local MfdColor = Watched(Color(71, 232, 39, 240))
local PassivColor = Watched(Color(160, 160, 160, 240))
local TargetPodHudColor = Watched(Color(71, 232, 39, 240))

local TrtMode = []
local Trt = []
local IsEnginesControled = Watched(false)
local isEngineControled = []
local ThrottleState = []

local Rpm = Watched(0)
local Spd = Watched(0)
local Mach = Watched(0)
local CritMach = Watched(false)
local Ias = Watched(0)
local CritIas = Watched(false)

local CannonCount = []
local CannonReloadTime = []
local IsCannonEmpty = Watched(array(NUM_CANNONS_MAX, false))
local isAllCannonsEmpty = Computed(@() !IsCannonEmpty.value.contains(false))
local CannonMode = Watched(0)
local CannonSelected = Watched(false)

local InstructorState = Watched(0)
local InstructorForced = Watched(false)

local StaminaValue  = Watched(0.0)
local StaminaState = Watched(0)

local MachineGuns = {
  count = Watched(0)
  seconds = Watched(-1)
  mode = Watched(0)
  selected = Watched(false)
}

local CannonsAdditional = {
  count = Watched(0)
  seconds = Watched(-1)
  mode = Watched(0)
  selected = Watched(false)
}

local Rockets = {
  count = Watched(0)
  seconds = Watched(-1)
  mode = Watched(0)
  selected = Watched(false)
  salvo = Watched(0)
  name = Watched("")
  actualCount = Watched(-1)
}

local Agm = {
  count = Watched(0)
  seconds = Watched(-1)
  timeToHit = Watched(-1)
  timeToWarning = Watched(-1)
  selected = Watched(false)
  name = Watched("")
  actualCount = Watched(-1)
}

local Aam = {
  count = Watched(0)
  seconds = Watched(-1)
  selected = Watched(false)
  name = Watched("")
  actualCount = Watched(-1)
}

local GuidedBombs = {
  seconds = Watched(-1)
  count = Watched(0)
  mode = Watched(0)
  selected = Watched(false)
  name = Watched("")
  actualCount = Watched(-1)
}

local Bombs = {
  seconds = Watched(-1)
  count = Watched(0)
  mode = Watched(0)
  selected = Watched(false)
  salvo = Watched(0)
  name = Watched("")
  actualCount = Watched(-1)
}

local Flares = {
  count = Watched(0)
  seconds = Watched(-1)
  mode = Watched(0)
  selected = Watched(false)
}

local Chaffs = {
  count = Watched(0)
  seconds = Watched(-1)
  mode = Watched(0)
  selected = Watched(false)
}

local IsMachineGunEmpty = Watched(false)
local IsCanAdditionalEmpty = Watched(false)
local IsRktEmpty = Watched(false)
local IsAgmEmpty = Watched(false)
local IsAamEmpty = Watched(false)
local IsGuidedBmbEmpty = Watched(false)
local IsBmbEmpty = Watched(false)
local IsFlrEmpty = Watched(false)
local IsChaffsEmpty = Watched(false)

local IsHighRateOfFire = Watched(false)

local IsRpmCritical = Watched(false)

local FixedGunDirectionX = Watched(-100)
local FixedGunDirectionY = Watched(-100)
local FixedGunDirectionVisible = Watched(false)
local FixedGunSightMode = Watched(0)
local FixedGunOverheat = Watched(0.0)

local IsRangefinderEnabled = Watched(false)
local RangefinderDist = Watched(0)

local TurretsDirectionX = []
local TurretsDirectionY = []
local TurretsOverheat= []
local TurretsReloading = []
local TurretsEmpty = []
local TurretsVisible = []

local OilTemperature = []
local WaterTemperature = []
local EngineTemperature = []

local OilState = []
local WaterState = []
local EngineState = []
local TransmissionOilState = []
local Fuel = Watched(-1)
local FuelState = Watched(0)

local OilAlert = []
local WaterAlert = []
local EngineAlert = []
local IsTransmissionOilAlert = []

local IsMainHudVisible = Watched(false)
local IsSightHudVisible = Watched(false)
local IsPilotHudVisible = Watched(false)
local IsWeaponHudVisible = Watched(false)
local IsGunnerHudVisible = Watched(false)
local IsBomberViewHudVisible = Watched(false)
local IsArbiterHudVisible = Watched(false)
local IsMfdEnabled = Watched(false)
local IsIlsEnabled = Watched(false)
local IsMfdSightHudVisible = Watched(false)
local RwrForMfd = Watched(false)
local RwrPosSize = Watched([0, 0, 20, 20])
local MlwsLwsForMfd = Watched(false)
local MfdSightPosSize = [0, 0, 0, 0]
local IlsPosSize = [0, 0, 0, 0]
local DetectAllyProgress = Watched(-1)
local DetectAllyState = Watched(false)

local GunOverheatState = Watched(0)

local IsCompassVisible = Watched(false)

local helicopterState = {

  IndicatorsVisible,
  CurrentTime,

  DistanceToGround,
  VerticalSpeed,

  RocketAimX,
  RocketAimY,
  RocketAimVisible,
  RocketSightMode,

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
}

::interop.updateCannons <- function(index, count, sec = -1) {
  CannonCount[index](count)
  CannonReloadTime[index](sec)
}

::interop.updateIsCannonEmpty <- function(index, is_empty) {
  if (is_empty != IsCannonEmpty.value[index])
    IsCannonEmpty(@(v) v[index] = is_empty)
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

for (local i = 0; i < NUM_ENGINES_MAX; ++i) {
  TrtMode.append(Watched(0))
  Trt.append(Watched(0))
  isEngineControled.append(Watched(false))
  ThrottleState.append(Watched(1))
}


for (local i = 0; i < NUM_CANNONS_MAX; ++i) {
  CannonCount.append(Watched(0))
  CannonReloadTime.append(Watched(-1))
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