let interopGen = require("interopGen.nut")
let { NUM_ENGINES_MAX } = require("hudState")

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

let CannonState = []
for (local i = 0; i < NUM_CANNONS_MAX; ++i) {
  CannonState.append(Watched({count=0, seconds=-1, selected=false}))
}
let CannonSelectedArray = Watched(array(NUM_CANNONS_MAX, false))
let CannonSelected = Watched(false)
let IsCannonEmpty = Watched(array(NUM_CANNONS_MAX, false))
let isAllCannonsEmpty = Computed(@() !IsCannonEmpty.value.contains(false))
let CannonMode = Watched(0)

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

let MachineGunState = []
for (local i = 0; i < NUM_CANNONS_MAX; ++i) {
  MachineGunState.append(Watched({count=0, seconds=-1, selected=false}))
}
let MachineGunsSelectedArray = Watched(array(NUM_CANNONS_MAX, false))
let IsMachineGunsEmpty = Watched(array(NUM_CANNONS_MAX, false))
let isAllMachineGunsEmpty = Computed(@() !IsMachineGunsEmpty.value.contains(false))
let MachineGunsMode = Watched(0)

let BombsState = Watched({
  count=0, seconds=-1, mode=0, selected=false, salvo=0, name="", actualCount=-1})
let RocketsState = Watched({                                                      // -duplicate-assigned-expr
  count=0, seconds=-1, mode=0, selected=false, salvo=0, name="", actualCount=-1})
let TorpedoesState = Watched({                                                    // -duplicate-assigned-expr
  count=0, seconds=-1, mode=0, selected=false, salvo=0, name="", actualCount=-1})
let AdditionalCannonsState = Watched({count=0, seconds=-1, mode=0, selected=false})
let AgmState = Watched({
  count=0, seconds=-1, timeToHit=-1, timeToWarning=-1, selected=false, name="", actualCount=-1})
let AamState = Watched({count=0, seconds=-1, selected=false, name="", actualCount=-1})
let GuidedBombsState = Watched({seconds=-1, count=0, mode=0, selected=false, name="", actualCount=-1})
let FlaresState = Watched({count=0, seconds=-1, mode=0})
let ChaffsState = Watched({count=0, seconds=-1, mode=0})// -duplicate-assigned-expr

let IsCanAdditionalEmpty = Watched(false)
let IsTrpEmpty = Watched(false)
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
  isAllMachineGunsEmpty,

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

  CannonCount = CannonState.map(@(c) Computed(@() c.value.count)),
  CannonReloadTime = CannonState.map(@(c) Computed(@() c.value.seconds)),
  IsCannonEmpty,
  CannonMode,
  CannonSelectedArray,
  CannonSelected,

  InstructorState,
  InstructorForced,

  StaminaValue,
  StaminaState,

  CannonsAdditionalCount = Computed(@() AdditionalCannonsState.value.count),
  CannonsAdditionalSeconds = Computed(@() AdditionalCannonsState.value.seconds),
  CannonsAdditionalMode =  Computed(@() AdditionalCannonsState.value.mode),
  CannonsAdditionalSelected = Computed(@() AdditionalCannonsState.value.selected),

  AgmCount = Computed(@() AgmState.value.count),
  AgmSeconds = Computed(@() AgmState.value.seconds),
  AgmTimeToHit = Computed(@() AgmState.value.timeToHit),
  AgmTimeToWarning = Computed(@() AgmState.value.timeToWarning),
  AgmActualCount = Computed(@() AgmState.value.actualCount),
  AgmName = Computed(@() AgmState.value.name),
  AgmSelected = Computed(@() AgmState.value.selected),

  AamCount = Computed(@() AamState.value.count),
  AamSeconds = Computed(@() AamState.value.seconds),
  AamActualCount = Computed(@() AamState.value.actualCount),
  AamName = Computed(@() AamState.value.name),
  AamSelected = Computed(@() AamState.value.selected),

  GuidedBombsCount = Computed(@() GuidedBombsState.value.count),
  GuidedBombsSeconds = Computed(@() GuidedBombsState.value.seconds),
  GuidedBombsActualCount = Computed(@() GuidedBombsState.value.actualCount),
  GuidedBombsName = Computed(@() GuidedBombsState.value.name),
  GuidedBombsSelected = Computed(@() GuidedBombsState.value.selected),

  FlaresCount = Computed(@() FlaresState.value.count),
  FlaresSeconds = Computed(@() FlaresState.value.seconds),
  FlaresMode = Computed(@() FlaresState.value.mode),

  ChaffsCount = Computed(@() ChaffsState.value.count),
  ChaffsSeconds = Computed(@() ChaffsState.value.seconds),
  ChaffsMode = Computed(@() ChaffsState.value.mode),

  IsMachineGunsEmpty,
  MachineGunsSelectedArray,
  MachineGunsMode,
  MachineGunsCount = MachineGunState.map(@(c) Computed(@() c.value.count)),
  MachineGunsReloadTime = MachineGunState.map(@(c) Computed(@() c.value.seconds)),

  BombsCount = Computed(@() BombsState.value.count),
  BombsSeconds = Computed(@() BombsState.value.seconds),
  BombsMode = Computed(@() BombsState.value.mode),
  BombsSelected = Computed(@() BombsState.value.selected),
  BombsSalvo = Computed(@() BombsState.value.salvo),
  BombsName = Computed(@() BombsState.value.name),
  BombsActualCount = Computed(@() BombsState.value.actualCount),

  RocketsCount = Computed(@() RocketsState.value.count),
  RocketsSeconds = Computed(@() RocketsState.value.seconds),
  RocketsMode = Computed(@() RocketsState.value.mode),
  RocketsSelected = Computed(@() RocketsState.value.selected),
  RocketsSalvo = Computed(@() RocketsState.value.salvo),
  RocketsName = Computed(@() RocketsState.value.name),
  RocketsActualCount = Computed(@() RocketsState.value.actualCount),

  TorpedoesCount = Computed(@() TorpedoesState.value.count),
  TorpedoesSeconds = Computed(@() TorpedoesState.value.seconds),
  TorpedoesMode = Computed(@() TorpedoesState.value.mode),
  TorpedoesSelected = Computed(@() TorpedoesState.value.selected),
  TorpedoesSalvo = Computed(@() TorpedoesState.value.salvo),
  TorpedoesName = Computed(@() TorpedoesState.value.name),
  TorpedoesActualCount = Computed(@() TorpedoesState.value.actualCount),

  IsCanAdditionalEmpty,
  IsRktEmpty,
  IsAgmEmpty,
  IsAamEmpty,
  IsGuidedBmbEmpty,
  IsBmbEmpty,
  IsTrpEmpty,
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
}

::interop.updateIsCannonEmpty <- function(index, is_empty) {
  if (is_empty != IsCannonEmpty.value[index])
    IsCannonEmpty.mutate(@(v) v[index] = is_empty)
}

::interop.updateCannonsArray <- function(index, count, seconds, selected, _time, _endTime) {
  CannonState[index]({count, seconds, selected})

  if (selected != CannonSelectedArray.value[index])
    CannonSelectedArray.mutate(@(v) v[index] = selected)
}

::interop.updateMachineGunsArray <- function(index, count, seconds, selected, _time, _endTime) {
  MachineGunState[index]({count, seconds, selected})

  if (selected != MachineGunsSelectedArray.value[index])
    MachineGunsSelectedArray.mutate(@(v) v[index] = selected)
}

::interop.updateBombs <- @(count, seconds, mode, selected, salvo, name, actualCount, _time, _endTime)
  BombsState({count, seconds, mode, selected, salvo, name, actualCount})

::interop.updateRockets <- @(count, seconds, mode, selected, salvo, name, actualCount, _time, _endTime)
  RocketsState({count, seconds, mode, selected, salvo, name, actualCount})

::interop.updateTorpedoes <- @(count, seconds, mode, selected, salvo, name, actualCount, _time, _endTime)
  TorpedoesState({count, seconds, mode, selected, salvo, name, actualCount})

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

::interop.updateIsMachineGunsEmpty <- function(index, is_empty) {
  if (is_empty != IsMachineGunsEmpty.value[index])
    IsMachineGunsEmpty.mutate(@(v) v[index] = is_empty)
}

::interop.updateAdditionalCannons <- function(count, seconds, mode, selected) {
  AdditionalCannonsState({count, seconds, mode, selected})
}

::interop.updateAgm <- function(count, seconds, timeToHit, timeToWarning, selected, name, actualCount) {
  AgmState({count, seconds, timeToHit, timeToWarning, selected, name, actualCount})
}

::interop.updateAam <- function(count, seconds, selected, name, actualCount) {
  AamState({count, seconds, selected, name, actualCount})
}

::interop.updateGuidedBombs <- function(count, seconds,  mode, selected, name, actualCount) {
  GuidedBombsState({count, seconds,  mode, selected, name, actualCount})
}

::interop.updateFlares <- function(count, mode, seconds) {
  FlaresState({count, mode, seconds})
}

::interop.updateChaffs <- function(count, mode, seconds) {
  ChaffsState({count, mode, seconds})
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