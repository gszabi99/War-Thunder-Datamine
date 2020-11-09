local interopGen = require("daRg/helpers/interopGen.nut")

const NUM_ENGINES_MAX = 3
const NUM_TRANSMISSIONS_MAX = 6
const NUM_CANNONS_MAX = 3

local helicopterState = {
  IndicatorsVisible = Watched(false)
  CurrentTime = Watched(false)

  DistanceToGround = Watched(0.0)
  VerticalSpeed = Watched(0.0)

  RocketAimX = Watched(0.0)
  RocketAimY = Watched(0.0)
  RocketAimVisible = Watched(false)
  RocketSightMode = Watched(0) //Sight shape need to change in function of CCIP/CCRP

  TATargetX = Watched(0.0)
  TATargetY = Watched(0.0)
  TATargetVisible = Watched(false)

  GunDirectionX = Watched(0.0)
  GunDirectionY = Watched(0.0)
  GunDirectionVisible = Watched(false)
  GunInDeadZone = Watched(false)
  GunSightMode = Watched(0)

  HorAngle = Watched(0.0)

  TurretYaw   = Watched(0.0)
  TurretPitch = Watched(0.0)
  FovYaw    = Watched(0.0)
  FovPitch  = Watched(0.0)

  IsAgmLaunchZoneVisible = Watched(false)
  AgmLaunchZoneYawMin   = Watched(0.0)
  AgmLaunchZoneYawMax   = Watched(0.0)
  AgmLaunchZonePitchMin = Watched(0.0)
  AgmLaunchZonePitchMax = Watched(0.0)
  AgmLaunchZoneDistMin  = Watched(0.0)
  AgmLaunchZoneDistMax  = Watched(0.0)

  IsInsideLaunchZoneYawPitch = Watched(false)
  IsInsideLaunchZoneDist = Watched(false)

  IsSightLocked = Watched(false)
  IsTargetTracked = Watched(false)
  HasTargetTracker = Watched(false)
  IsLaserDesignatorEnabled = Watched(false)
  IsATGMOutOfTrackerSector = Watched(false)
  NoLosToATGM = Watched(false)
  AtgmTrackerRadius = Watched(0.0)
  TargetRadius = Watched(0.0)
  TargetAge = Watched(0.0)

  MainMask = Watched(0)
  SightMask = Watched(0)
  IlsMask = Watched(0)
  MfdSightMask = Watched(0)

  HudColor = Watched(Color(71, 232, 39, 240))
  AlertColor = Watched(Color(255, 0, 0, 240))
  MfdColor = Watched(Color(71, 232, 39, 240))

  TrtMode = Watched(0)

  Rpm = Watched(0)
  Trt = Watched(0)
  Spd = Watched(0)

  CannonCount = []
  CannonReloadTime = []
  IsCannonEmpty = []
  CannonMode = Watched(0)
  CannonSelected = Watched(false)

  MachineGuns = {
    count = Watched(0)
    seconds = Watched(-1)
    mode = Watched(0)
    selected = Watched(false)
  }

  CannonsAdditional = {
    count = Watched(0)
    seconds = Watched(-1)
    mode = Watched(0)
    selected = Watched(false)
  }

  Rockets = {
    count = Watched(0)
    seconds = Watched(-1)
    mode = Watched(0)
    selected = Watched(false)
  }

  Agm = {
    count = Watched(0)
    seconds = Watched(-1)
    timeToHit = Watched(-1)
    timeToWarning = Watched(-1)
    selected = Watched(false)
  }

  Aam = {
    count = Watched(0)
    seconds = Watched(-1)
    selected = Watched(false)
  }

  Bombs = {
    count = Watched(0)
    seconds = Watched(-1)
    mode = Watched(0)
    selected = Watched(false)
  }

  Flares = {
    count = Watched(0)
    seconds = Watched(-1)
    mode = Watched(0)
  }

  IsMachineGunEmpty = Watched(false)
  IsCanAdditionalEmpty = Watched(false)
  IsRktEmpty = Watched(false)
  IsAgmEmpty = Watched(false)
  IsAamEmpty = Watched(false)
  IsBmbEmpty = Watched(false)
  IsFlrEmpty = Watched(false)

  IsHighRateOfFire = Watched(false)

  IsRpmCritical = Watched(false)

  FixedGunDirectionX = Watched(-100)
  FixedGunDirectionY = Watched(-100)
  FixedGunDirectionVisible = Watched(false)
  FixedGunSightMode = Watched(0)

  IsRangefinderEnabled = Watched(false)
  RangefinderDist = Watched(0)

  OilTemperature = []
  WaterTemperature = []
  EngineTemperature = []

  OilState = []
  WaterState = []
  EngineState = []
  TransmissionOilState = []
  Fuel = Watched(-1)
  IsFuelCritical = Watched(false)

  IsOilAlert = []
  IsWaterAlert = []
  IsEngineAlert = []
  IsTransmissionOilAlert = []

  IsMainHudVisible = Watched(false)
  IsSightHudVisible = Watched(false)
  IsPilotHudVisible = Watched(false)
  IsGunnerHudVisible = Watched(false)
  IsMfdEnabled = Watched(false)
  IsIlsEnabled = Watched(false)
  IsMfdSightHudVisible = Watched(false)
  RwrForMfd = Watched(false)
  RwrPosSize = [0, 0, 20, 20]
  TwsForMfd = Watched(false)
  MfdSightPosSize = [0, 0, 0, 0]
  IlsPosSize = [0, 0, 0, 0]
  AimCorrectionEnabled = Watched(false)
  DetectAllyProgress = Watched(-1)
  DetectAllyState = Watched(false)

  GunOverheatState = Watched(0)

  IsCompassVisible = Watched(false)
}

::interop.updateCannons <- function(index, count, sec = -1) {
  helicopterState.CannonCount[index].update(count)
  helicopterState.CannonReloadTime[index].update(sec)
}

::interop.updateIsCannonEmpty <- function(index, is_empty) {
  helicopterState.IsCannonEmpty[index].update(is_empty)
}

::interop.updateRwrPosSize <- function(x, y, w, h = null) {
  helicopterState.RwrPosSize[0] = x
  helicopterState.RwrPosSize[1] = y
  helicopterState.RwrPosSize[2] = w
  helicopterState.RwrPosSize[3] = h ?? w
}

::interop.updateMfdSightPosSize <- function(x, y, w, h) {
  helicopterState.MfdSightPosSize[0] = x
  helicopterState.MfdSightPosSize[1] = y
  helicopterState.MfdSightPosSize[2] = w
  helicopterState.MfdSightPosSize[3] = h
}

::interop.updateIlsPosSize <- function(x, y, w, h) {
  helicopterState.IlsPosSize[0] = x
  helicopterState.IlsPosSize[1] = y
  helicopterState.IlsPosSize[2] = w
  helicopterState.IlsPosSize[3] = h
}

::interop.updateMachineGuns <- function(count, sec = -1, mode = 0, selected = false) {
  helicopterState.MachineGuns.count.update(count)
  helicopterState.MachineGuns.mode.update(mode)
  helicopterState.MachineGuns.seconds.update(sec)
  helicopterState.MachineGuns.selected.update(selected)
}

::interop.updateAdditionalCannons <- function(count, sec = -1, mode = 0, selected = false) {
  helicopterState.CannonsAdditional.count.update(count)
  helicopterState.CannonsAdditional.seconds.update(sec)
  helicopterState.CannonsAdditional.mode.update(mode)
  helicopterState.CannonsAdditional.selected.update(selected)
}

::interop.updateRockets <- function(count, sec = -1, mode = 0, selected = false) {
  helicopterState.Rockets.count.update(count)
  helicopterState.Rockets.mode.update(mode)
  helicopterState.Rockets.seconds.update(sec)
  helicopterState.Rockets.selected.update(selected)
}

::interop.updateAgm <- function(count, sec, timeToHit, timeToWarning, selected = false) {
  helicopterState.Agm.count.update(count)
  helicopterState.Agm.seconds.update(sec)
  helicopterState.Agm.timeToHit.update(timeToHit)
  helicopterState.Agm.timeToWarning.update(timeToWarning)
  helicopterState.Agm.selected.update(selected)
}

::interop.updateAam <- function(count, sec = -1, selected = false) {
  helicopterState.Aam.count.update(count)
  helicopterState.Aam.seconds.update(sec)
  helicopterState.Aam.selected.update(selected)
}

::interop.updateBombs <- function(count, sec = -1,  mode = 0, selected = false) {
  helicopterState.Bombs.count.update(count)
  helicopterState.Bombs.mode.update(mode)
  helicopterState.Bombs.seconds.update(sec)
  helicopterState.Bombs.selected.update(selected)
}

::interop.updateFlares <- function(count, mode = 0, sec = -1) {
  helicopterState.Flares.count.update(count)
  helicopterState.Flares.mode.update(mode)
  helicopterState.Flares.seconds.update(sec)
}

for (local i = 0; i < NUM_CANNONS_MAX; ++i) {
  helicopterState.CannonCount.append(Watched(0))
  helicopterState.CannonReloadTime.append(Watched(-1))
  helicopterState.IsCannonEmpty.append(Watched(false))
}

for (local i = 0; i < NUM_ENGINES_MAX; ++i)
{
  helicopterState.OilTemperature.append(Watched(0))
  helicopterState.WaterTemperature.append(Watched(0))
  helicopterState.EngineTemperature.append(Watched(0))

  helicopterState.OilState.append(Watched(0))
  helicopterState.WaterState.append(Watched(0))
  helicopterState.EngineState.append(Watched(0))

  helicopterState.IsOilAlert.append(Watched(false))
  helicopterState.IsWaterAlert.append(Watched(false))
  helicopterState.IsEngineAlert.append(Watched(false))
}

for (local i = 0; i < NUM_TRANSMISSIONS_MAX; ++i)
{
  helicopterState.TransmissionOilState.append(Watched(0))
  helicopterState.IsTransmissionOilAlert.append(Watched(false))
}

interopGen({
  stateTable = helicopterState
  prefix = "helicopter"
  postfix = "Update"
})

::interop.updateOilTemperature <- function (temperature, state, index) {
  helicopterState.OilTemperature[index].update(temperature)
  helicopterState.OilState[index].update(state)
}

::interop.updateWaterTemperature <- function (temperature, state, index) {
  helicopterState.WaterTemperature[index].update(temperature)
  helicopterState.WaterState[index].update(state)
}

::interop.updateEngineTemperature <- function (temperature, state, index) {
  helicopterState.EngineTemperature[index].update(temperature)
  helicopterState.EngineState[index].update(state)
}

::interop.updateTransmissionOilState <- function (state, index) {
  helicopterState.TransmissionOilState[index].update(state)
}

::interop.updateOilAlert <- function (value, index) {
  helicopterState.IsOilAlert[index].update(value)
}

::interop.updateTransmissionOilAlert <- function (value, index) {
  helicopterState.IsTransmissionOilAlert[index].update(value)
}

::interop.updateWaterAlert <- function (value, index) {
  helicopterState.IsWaterAlert[index].update(value)
}

::interop.updateEngineAlert <- function (value, index) {
  helicopterState.IsEngineAlert[index].update(value)
}

return helicopterState