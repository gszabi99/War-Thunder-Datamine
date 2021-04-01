local interopGen = require("interopGen.nut")

const NUM_ENGINES_MAX = 3
const NUM_TRANSMISSIONS_MAX = 6
const NUM_CANNONS_MAX = 3

local IndicatorsVisible = Watched(false)
local CurrentTime = Watched(false)

local DistanceToGround = Watched(0.0)
local VerticalSpeed = Watched(0.0)

local RocketAimX = Watched(0.0)
local RocketAimY = Watched(0.0)
local RocketAimVisible = Watched(false)
local RocketSightMode = Watched(0) //Sight shape need to change in function of CCIP/CCRP

local TATargetX = Watched(0.0)
local TATargetY = Watched(0.0)
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

local IsSightLocked = Watched(false)
local IsTargetTracked = Watched(false)
local HasTargetTracker = Watched(false)
local IsLaserDesignatorEnabled = Watched(false)
local IsATGMOutOfTrackerSector = Watched(false)
local NoLosToATGM = Watched(false)
local AtgmTrackerRadius = Watched(0.0)
local TargetRadius = Watched(0.0)
local TargetAge = Watched(0.0)

local MainMask = Watched(0)
local SightMask = Watched(0)
local IlsMask = Watched(0)
local MfdSightMask = Watched(0)

local HudColor = Watched(Color(71, 232, 39, 240))
local AlertColor = Watched(Color(255, 0, 0, 240))
local MfdColor = Watched(Color(71, 232, 39, 240))

local TrtMode = Watched(0)

local Rpm = Watched(0)
local Trt = Watched(0)
local Spd = Watched(0)

local CannonCount = []
local CannonReloadTime = []
local IsCannonEmpty = []
local CannonMode = Watched(0)
local CannonSelected = Watched(false)

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
}

local Agm = {
  count = Watched(0)
  seconds = Watched(-1)
  timeToHit = Watched(-1)
  timeToWarning = Watched(-1)
  selected = Watched(false)
}

local Aam = {
  count = Watched(0)
  seconds = Watched(-1)
  selected = Watched(false)
}

local Bombs = {
  seconds = Watched(-1)
  count = Watched(0)
  mode = Watched(0)
  selected = Watched(false)
  salvo = Watched(0)
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
local IsBmbEmpty = Watched(false)
local IsFlrEmpty = Watched(false)
local IsChaffsEmpty = Watched(false)

local IsHighRateOfFire = Watched(false)

local IsRpmCritical = Watched(false)

local FixedGunDirectionX = Watched(-100)
local FixedGunDirectionY = Watched(-100)
local FixedGunDirectionVisible = Watched(false)
local FixedGunSightMode = Watched(0)

local IsRangefinderEnabled = Watched(false)
local RangefinderDist = Watched(0)

local OilTemperature = []
local WaterTemperature = []
local EngineTemperature = []

local OilState = []
local WaterState = []
local EngineState = []
local TransmissionOilState = []
local Fuel = Watched(-1)
local IsFuelCritical = Watched(false)

local IsOilAlert = []
local IsWaterAlert = []
local IsEngineAlert = []
local IsTransmissionOilAlert = []

local IsMainHudVisible = Watched(false)
local IsSightHudVisible = Watched(false)
local IsPilotHudVisible = Watched(false)
local IsWeaponHudVisible = Watched(false)
local IsGunnerHudVisible = Watched(false)
local IsMfdEnabled = Watched(false)
local IsIlsEnabled = Watched(false)
local IsMfdSightHudVisible = Watched(false)
local RwrForMfd = Watched(false)
local RwrPosSize = [0, 0, 20, 20]
local MlwsLwsForMfd = Watched(false)
local MfdSightPosSize = [0, 0, 0, 0]
local IlsPosSize = [0, 0, 0, 0]
local AimCorrectionEnabled = Watched(false)
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

  TATargetX,
  TATargetY,
  TATargetVisible,

  GunDirectionX,
  GunDirectionY,
  GunDirectionVisible,
  GunInDeadZone,
  GunSightMode,

  HorAngle,

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

  IsSightLocked,
  IsTargetTracked,
  HasTargetTracker,
  IsLaserDesignatorEnabled,
  IsATGMOutOfTrackerSector,
  NoLosToATGM,
  AtgmTrackerRadius,
  TargetRadius,
  TargetAge,

  MainMask,
  SightMask,
  IlsMask,
  MfdSightMask,

  HudColor,
  AlertColor,
  MfdColor,

  TrtMode,

  Rpm,
  Trt,
  Spd,

  CannonCount,
  CannonReloadTime,
  IsCannonEmpty,
  CannonMode,
  CannonSelected,

  MachineGuns,
  CannonsAdditional,
  Rockets, Agm, Aam, Bombs, Flares, Chaffs

  IsMachineGunEmpty,
  IsCanAdditionalEmpty,
  IsRktEmpty,
  IsAgmEmpty,
  IsAamEmpty,
  IsBmbEmpty,
  IsFlrEmpty,
  IsChaffsEmpty,

  IsHighRateOfFire,

  IsRpmCritical,

  FixedGunDirectionX,
  FixedGunDirectionY,
  FixedGunDirectionVisible,
  FixedGunSightMode,

  IsRangefinderEnabled,
  RangefinderDist,

  OilTemperature,
  WaterTemperature,
  EngineTemperature,

  OilState,
  WaterState,
  EngineState,
  TransmissionOilState,
  Fuel,
  IsFuelCritical,

  IsOilAlert,
  IsWaterAlert,
  IsEngineAlert,
  IsTransmissionOilAlert,

  IsMainHudVisible,
  IsSightHudVisible,
  IsPilotHudVisible,
  IsWeaponHudVisible,
  IsGunnerHudVisible,
  IsMfdEnabled,
  IsIlsEnabled,
  IsMfdSightHudVisible,
  RwrForMfd,
  RwrPosSize,
  MlwsLwsForMfd,
  MfdSightPosSize,
  IlsPosSize,
  AimCorrectionEnabled,
  DetectAllyProgress,
  DetectAllyState,

  GunOverheatState,

  IsCompassVisible,
}

::interop.updateCannons <- function(index, count, sec = -1) {
  CannonCount[index].update(count)
  CannonReloadTime[index].update(sec)
}

::interop.updateIsCannonEmpty <- function(index, is_empty) {
  IsCannonEmpty[index].update(is_empty)
}

::interop.updateRwrPosSize <- function(x, y, w, h = null) {
  RwrPosSize[0] = x
  RwrPosSize[1] = y
  RwrPosSize[2] = w
  RwrPosSize[3] = h ?? w
}

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

::interop.updateRockets <- function(count, sec = -1, mode = 0, selected = false, salvo = 0) {
  Rockets.count.update(count)
  Rockets.mode.update(mode)
  Rockets.seconds.update(sec)
  Rockets.selected.update(selected)
  Rockets.salvo.update(salvo)
}

::interop.updateAgm <- function(count, sec, timeToHit, timeToWarning, selected = false) {
  Agm.count.update(count)
  Agm.seconds.update(sec)
  Agm.timeToHit.update(timeToHit)
  Agm.timeToWarning.update(timeToWarning)
  Agm.selected.update(selected)
}

::interop.updateAam <- function(count, sec = -1, selected = -1) {
  Aam.count.update(count)
  Aam.seconds.update(sec)
  Aam.selected.update(selected)
}

::interop.updateBombs <- function(count, sec = -1,  mode = 0, selected = false, salvo = 0) {
  Bombs.count.update(count)
  Bombs.mode.update(mode)
  Bombs.seconds.update(sec)
  Bombs.selected.update(selected)
  Bombs.salvo.update(salvo)
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
  IsCannonEmpty.append(Watched(false))
}

for (local i = 0; i < NUM_ENGINES_MAX; ++i){
  OilTemperature.append(Watched(0))
  WaterTemperature.append(Watched(0))
  EngineTemperature.append(Watched(0))

  OilState.append(Watched(0))
  WaterState.append(Watched(0))
  EngineState.append(Watched(0))

  IsOilAlert.append(Watched(false))
  IsWaterAlert.append(Watched(false))
  IsEngineAlert.append(Watched(false))
}

for (local i = 0; i < NUM_TRANSMISSIONS_MAX; ++i) {
  TransmissionOilState.append(Watched(0))
  IsTransmissionOilAlert.append(Watched(false))
}

interopGen({
  stateTable = helicopterState
  prefix = "helicopter"
  postfix = "Update"
})

::interop.updateOilTemperature <- function (temperature, state, index) {
  OilTemperature[index].update(temperature)
  OilState[index].update(state)
}

::interop.updateWaterTemperature <- function (temperature, state, index) {
  WaterTemperature[index].update(temperature)
  WaterState[index].update(state)
}

::interop.updateEngineTemperature <- function (temperature, state, index) {
  EngineTemperature[index].update(temperature)
  EngineState[index].update(state)
}

::interop.updateTransmissionOilState <- function (state, index) {
  TransmissionOilState[index].update(state)
}

::interop.updateOilAlert <- function (value, index) {
  IsOilAlert[index].update(value)
}

::interop.updateTransmissionOilAlert <- function (value, index) {
  IsTransmissionOilAlert[index].update(value)
}

::interop.updateWaterAlert <- function (value, index) {
  IsWaterAlert[index].update(value)
}

::interop.updateEngineAlert <- function (value, index) {
  IsEngineAlert[index].update(value)
}

return helicopterState