from "%rGui/globals/ui_library.nut" import *

let interopGen = require("%rGui/interopGen.nut")
let { interop } = require("%rGui/globals/interop.nut")
let { NUM_ENGINES_MAX } = require("hudState")

const NUM_TRANSMISSIONS_MAX = 6
const NUM_CANNONS_MAX = 3
const NUM_TURRETS_MAX = 10

const NUM_BOMB_RELEASE_POINT = 80

let BombReleaseBlockedStates =
{
  notBlocked = 0,
  highSpeed = 1,
  bombBay = 2
}

local IndicatorsVisible = Watched(false)
local CurrentTime = Watched(false)

let DistanceToGround = Watched(0.0)
let RadarAltitude = Watched(0.0)
let RadarAltitudeAlert = Watched(0.0)
let VerticalSpeed = Watched(0.0)

let RocketAimX = Watched(0.0)
let RocketAimY = Watched(0.0)
let RocketAimVisible = Watched(false)
let RocketSightMode = Watched(0) 
let RocketSightSizeFactor = Watched(0.0)

let TATargetVisible = Watched(false)

let GunDirectionX = Watched(0.0)
let GunDirectionY = Watched(0.0)
let GunDirectionVisible = Watched(false)
let GunInDeadZone = Watched(false)
let GunSightMode = Watched(0)

let HorAngle = Watched(0.0)
let HorVelX = Watched(0.0)
let HorVelY = Watched(0.0)

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
let IsLaunchZoneAvailable        = Watched(false)
let IsOutLaunchZone              = Watched(false)
let IsLaunchZoneOnTarget         = Watched(true)
let LaunchZonePosX               = Watched(0.0)
let LaunchZonePosY               = Watched(0.0)
let LaunchZoneWatched = Watched({ x0 = 0, y0 = 0, x1 = 0, y1 = 0, x2 = 0, y2 = 0, x3 = 0, y3 = 0 })

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
  CannonState.append(Watched({ count = 0, seconds = -1, selected = false, mode = 0 }))
}
let CannonSelectedArray = Watched(array(NUM_CANNONS_MAX, false))
let CannonSelected = Watched(false)
let IsCannonEmpty = Watched(array(NUM_CANNONS_MAX, false))
let isAllCannonsEmpty = Computed(@() !IsCannonEmpty.get().contains(false))
let isCannonJamed = Watched(array(NUM_CANNONS_MAX, false))

let InstructorState = Watched(0)
let InstructorForced = Watched(false)

let StaminaValue  = Watched(0.0)
let StaminaState = Watched(0)

local BombReleaseVisible = Watched(false)
local BombReleaseBlockedState = Watched(0)
local BombReleaseBlockedTextPosX = Watched(0)
local BombReleaseBlockedTextPosY = Watched(0)
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
  MachineGunState.append(Watched({ count = 0, seconds = -1, selected = false, mode = 0 }))
}
let MachineGunsSelectedArray = Watched(array(NUM_CANNONS_MAX, false))
let IsMachineGunsEmpty = Watched(array(NUM_CANNONS_MAX, false))
let isAllMachineGunsEmpty = Computed(@() !IsMachineGunsEmpty.get().contains(false))

let BombsState = Watched({
  count = 0, seconds = -1, mode = 0, selected = false, salvo = 0, name = "", actualCount = -1, weaponIdx = -1 })
let RocketsState = Watched({                                                      
  count = 0, seconds = -1, mode = 0, selected = false, salvo = 0, name = "", actualCount = -1, weaponIdx = -1 })
let TorpedoesState = Watched({                                                    
  count = 0, seconds = -1, mode = 0, selected = false, salvo = 0, name = "", actualCount = -1, weaponIdx = -1 })
let AdditionalCannonsState = Watched({ count = 0, seconds = -1, mode = 0, selected = false })
let AgmState = Watched({
  count = 0, seconds = -1, timeToHit = -1, timeToWarning = -1, selected = false, name = "", actualCount = -1, weaponIdx = -1 })
let AamState = Watched({ count = 0, seconds = -1, timeToHit = -1, selected = false, name = "", actualCount = -1, weaponIdx = -1 })
let GuidedBombsState = Watched({ seconds = -1, timeToHit = -1, count = 0, mode = 0, selected = false, name = "", actualCount = -1, timeToWarning = -1, weaponIdx = -1})
let FlaresState = Watched({ count = 0, mode = 0, seconds = -1 })
let ChaffsState = Watched({ count = 0, mode = 0, seconds = -1 }) 

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
let TurretsOverheat = []
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
let HasExternalFuel = Watched(false)
let ExternalFuel = Watched(-1)
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
let MfdSightPosSize = Watched([0, 0, 0, 0])
let MfdFontScale = Watched(-1.0)
let IlsPosSize = [0, 0, 0, 0]
let DetectAllyProgress = Watched(-1)
let DetectAllyState = Watched(false)

let GunOverheatState = Watched(0)

let IsCompassVisible = Watched(false)


let isBombSightActivated = Watched(false)
let isAAMSightActivated = Watched(false)
let isRocketSightActivated = Watched(false)
let isCanonSightActivated = Watched(false)
let isTurretSightActivated = Watched(false)
let isParamTableActivated = Watched(false)

let IlsAtgmLaunchEdge1X = Watched(0)
let IlsAtgmLaunchEdge1Y = Watched(0)
let IlsAtgmLaunchEdge2X = Watched(0)
let IlsAtgmLaunchEdge2Y = Watched(0)
let IlsAtgmLaunchEdge3X = Watched(0)
let IlsAtgmLaunchEdge3Y = Watched(0)
let IlsAtgmLaunchEdge4X = Watched(0)
let IlsAtgmLaunchEdge4Y = Watched(0)

let helicopterState = {

  IndicatorsVisible,
  CurrentTime,

  DistanceToGround,
  RadarAltitude,
  RadarAltitudeAlert,
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
  HorVelX,
  HorVelY,

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
  IsLaunchZoneAvailable,
  IsOutLaunchZone,
  IsLaunchZoneOnTarget,
  LaunchZonePosX,
  LaunchZonePosY,
  LaunchZoneWatched,
  IlsAtgmLaunchEdge1X,
  IlsAtgmLaunchEdge1Y,
  IlsAtgmLaunchEdge2X,
  IlsAtgmLaunchEdge2Y,
  IlsAtgmLaunchEdge3X,
  IlsAtgmLaunchEdge3Y,
  IlsAtgmLaunchEdge4X,
  IlsAtgmLaunchEdge4Y,

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

  CannonCount = CannonState.map(@(c) Computed(@() c.get().count)),
  CannonReloadTime = CannonState.map(@(c) Computed(@() c.get().seconds)),
  CannonMode = CannonState.map(@(c) Computed(@() c.get().mode)),
  IsCannonEmpty,
  isCannonJamed,
  CannonSelectedArray,
  CannonSelected,

  InstructorState,
  InstructorForced,

  StaminaValue,
  StaminaState,

  CannonsAdditionalCount = Computed(@() AdditionalCannonsState.get().count),
  CannonsAdditionalSeconds = Computed(@() AdditionalCannonsState.get().seconds),
  CannonsAdditionalMode =  Computed(@() AdditionalCannonsState.get().mode),
  CannonsAdditionalSelected = Computed(@() AdditionalCannonsState.get().selected),

  AgmCount = Computed(@() AgmState.get().count),
  AgmSeconds = Computed(@() AgmState.get().seconds),
  AgmTimeToHit = Computed(@() AgmState.get().timeToHit),
  AgmTimeToWarning = Computed(@() AgmState.get().timeToWarning),
  AgmActualCount = Computed(@() AgmState.get().actualCount),
  AgmName = Computed(@() AgmState.get().name),
  AgmSelected = Computed(@() AgmState.get().selected),
  AgmWeaponIdx = Computed(@() AgmState.get().weaponIdx),

  AamCount = Computed(@() AamState.get().count),
  AamSeconds = Computed(@() AamState.get().seconds),
  AamTimeToHit = Computed(@() AamState.get().timeToHit),
  AamActualCount = Computed(@() AamState.get().actualCount),
  AamName = Computed(@() AamState.get().name),
  AamSelected = Computed(@() AamState.get().selected),
  AamWeaponIdx = Computed(@() AamState.get().weaponIdx),

  GuidedBombsCount = Computed(@() GuidedBombsState.get().count),
  GuidedBombsSeconds = Computed(@() GuidedBombsState.get().seconds),
  GuidedBombsTimeToHit = Computed(@() GuidedBombsState.get().timeToHit),
  GuidedBombsMode = Computed(@() GuidedBombsState.get().mode),
  GuidedBombsActualCount = Computed(@() GuidedBombsState.get().actualCount),
  GuidedBombsName = Computed(@() GuidedBombsState.get().name),
  GuidedBombsSelected = Computed(@() GuidedBombsState.get().selected),
  GuidedBombsTimeToWarning = Computed(@() GuidedBombsState.get().timeToWarning),
  GuidedBombsWeaponIdx = Computed(@() GuidedBombsState.get().weaponIdx),

  FlaresCount = Computed(@() FlaresState.get().count),
  FlaresMode = Computed(@() FlaresState.get().mode),
  FlaresSeconds = Computed(@() FlaresState.get().seconds),

  ChaffsCount = Computed(@() ChaffsState.get().count),
  ChaffsMode = Computed(@() ChaffsState.get().mode),
  ChaffsSeconds = Computed(@() ChaffsState.get().seconds),

  IsMachineGunsEmpty,
  MachineGunsSelectedArray,
  MachineGunsCount = MachineGunState.map(@(c) Computed(@() c.get().count)),
  MachineGunsReloadTime = MachineGunState.map(@(c) Computed(@() c.get().seconds)),
  MachineGunsMode = MachineGunState.map(@(c) Computed(@() c.get().mode)),

  BombsCount = Computed(@() BombsState.get().count),
  BombsSeconds = Computed(@() BombsState.get().seconds),
  BombsMode = Computed(@() BombsState.get().mode),
  BombsSelected = Computed(@() BombsState.get().selected),
  BombsSalvo = Computed(@() BombsState.get().salvo),
  BombsName = Computed(@() BombsState.get().name),
  BombsActualCount = Computed(@() BombsState.get().actualCount),
  BombsWeaponIdx = Computed(@() BombsState.get().weaponIdx),

  RocketsCount = Computed(@() RocketsState.get().count),
  RocketsSeconds = Computed(@() RocketsState.get().seconds),
  RocketsMode = Computed(@() RocketsState.get().mode),
  RocketsSelected = Computed(@() RocketsState.get().selected),
  RocketsSalvo = Computed(@() RocketsState.get().salvo),
  RocketsName = Computed(@() RocketsState.get().name),
  RocketsActualCount = Computed(@() RocketsState.get().actualCount),
  RocketsWeaponIdx = Computed(@() RocketsState.get().weaponIdx),

  TorpedoesCount = Computed(@() TorpedoesState.get().count),
  TorpedoesSeconds = Computed(@() TorpedoesState.get().seconds),
  TorpedoesMode = Computed(@() TorpedoesState.get().mode),
  TorpedoesSelected = Computed(@() TorpedoesState.get().selected),
  TorpedoesSalvo = Computed(@() TorpedoesState.get().salvo),
  TorpedoesName = Computed(@() TorpedoesState.get().name),
  TorpedoesActualCount = Computed(@() TorpedoesState.get().actualCount),

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
  HasExternalFuel,
  ExternalFuel,
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
  MfdFontScale,
  IlsPosSize,
  DetectAllyProgress,
  DetectAllyState,

  GunOverheatState,

  IsCompassVisible,

  BombReleaseVisible,
  BombReleaseBlockedStates,
  BombReleaseBlockedState,
  BombReleaseBlockedTextPosX,
  BombReleaseBlockedTextPosY,
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

interop.updateIsCannonEmpty <- function(index, is_empty) {
  if (is_empty != IsCannonEmpty.get()[index])
    IsCannonEmpty.mutate(@(v) v[index] = is_empty)
}

interop.updateisCannonJamed <- function(index, is_jamed) {
  if (is_jamed != isCannonJamed.get()[index])
    isCannonJamed.mutate(@(v) v[index] = is_jamed)
}

interop.updateCannonsArray <- function(tb) {
  let { index, count, seconds, selected, mode } = tb
  let curVal = CannonState[index].value
  if (curVal.count != count || curVal.seconds != seconds || curVal.selected != selected || curVal.mode != mode)
    CannonState[index](tb)

  if (selected != CannonSelectedArray.get()[index])
    CannonSelectedArray.mutate(@(v) v[index] = selected)
}

interop.updateMachineGunsArray <- function(tb) {
  let { index, count, seconds, selected, mode } = tb
  let curVal = MachineGunState[index].value
  if (curVal.count != count || curVal.seconds != seconds || curVal.selected != selected || curVal.mode != mode)
    MachineGunState[index](tb)

  if (selected != MachineGunsSelectedArray.get()[index])
    MachineGunsSelectedArray.mutate(@(v) v[index] = selected)
}

interop.updateBombs <- @(tb) BombsState.set(tb)

interop.updateRockets <- @(tb) RocketsState.set(tb)

interop.updateTorpedoes <- @(tb) TorpedoesState.set(tb)

interop.updateRwrPosSize <- function(x, y, w, h) {
  let cur = RwrPosSize.get()
  if (x != cur[0] || y != cur[1] || w != cur[2] || h != cur[3])
    RwrPosSize.set([x, y, w, h])
}

interop.updateMfdSightPosSize <- function(x, y, w, h) {
  let cur = MfdSightPosSize.get()
  if (x != cur[0] || y != cur[1] || w != cur[2] || h != cur[3])
    MfdSightPosSize.set([x, y, w, h])
}

interop.updateIlsPosSize <- function(x, y, w, h) {
  IlsPosSize[0] = x
  IlsPosSize[1] = y
  IlsPosSize[2] = w
  IlsPosSize[3] = h
}

interop.updateIsMachineGunsEmpty <- function(index, is_empty) {
  if (is_empty != IsMachineGunsEmpty.get()[index])
    IsMachineGunsEmpty.mutate(@(v) v[index] = is_empty)
}

interop.updateAdditionalCannons <- function(tb) {
  let { count, seconds, mode, selected } = tb
  let curVal = AdditionalCannonsState.get()
  if (curVal.count != count || curVal.seconds != seconds || curVal.mode != mode || curVal.selected != selected)
    AdditionalCannonsState.set(tb)
}

interop.updateAgm <- function(tb) {
  let { count, seconds, timeToHit, timeToWarning, selected, name, actualCount } = tb
  let curVal = AgmState.get()
  if (curVal.count != count || curVal.seconds != seconds || curVal.timeToHit != timeToHit
    || curVal.timeToWarning != timeToWarning || curVal.selected != selected || curVal.name != name
    || curVal.actualCount != actualCount)
    AgmState.set(tb)
}

interop.updateAam <- function(tb) {
  let { count, seconds, timeToHit, selected, name, actualCount } = tb
  let curVal = AamState.get()
  if (curVal.count != count || curVal.seconds != seconds || curVal.timeToHit != timeToHit || curVal.selected != selected
    || curVal.name != name || curVal.actualCount != actualCount)
    AamState.set(tb)
}

interop.updateGuidedBombs <- function(tb) {
  let { count, seconds, timeToHit, mode, selected, name, actualCount, timeToWarning } = tb
  let curVal = GuidedBombsState.get()
  if (curVal.count != count || curVal.seconds != seconds || curVal.timeToHit != timeToHit || curVal.mode != mode ||
    curVal.name != name || curVal.actualCount != actualCount || curVal.selected != selected || curVal.timeToWarning != timeToWarning)
    GuidedBombsState.set(tb)
}

interop.updateFlares <- function(count, mode, seconds) {
  let curVal = FlaresState.get()
  if (curVal.count != count || curVal.mode != mode || curVal.seconds != seconds)
    FlaresState.set({ count, mode, seconds })
}

interop.updateChaffs <- function(count, mode, seconds) {
  let curVal = ChaffsState.get()
  if (curVal.count != count || curVal.mode != mode || curVal.seconds != seconds)
    ChaffsState.set({ count, mode, seconds })
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

for (local i = 0; i < NUM_ENGINES_MAX; ++i) {
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

interop.updateTurretsVisibility <- function (visible, index) {
  TurretsVisible[index](visible)
}

interop.updateTurrets <- function (X, Y, overheat, isReloading, empty, visible, index) {
  TurretsDirectionX[index](X)
  TurretsDirectionY[index](Y)
  TurretsOverheat[index](overheat)
  TurretsReloading[index](isReloading)
  TurretsEmpty[index](empty)
  TurretsVisible[index](visible)
}

interop.updateOilTemperature <- function (temperature, state, index) {
  OilTemperature[index](temperature)
  OilState[index](state)
}

interop.updateWaterTemperature <- function (temperature, state, index) {
  WaterTemperature[index](temperature)
  WaterState[index](state)
}

interop.updateEngineTemperature <- function (temperature, state, index) {
  EngineTemperature[index](temperature)
  EngineState[index](state)
}

interop.updateTransmissionOilState <- function (state, index) {
  TransmissionOilState[index](state)
}

interop.updateOilAlert <- function (value, index) {
  OilAlert[index](value)
}

interop.updateTransmissionOilAlert <- function (value, index) {
  IsTransmissionOilAlert[index](value)
}

interop.updateWaterAlert <- function (value, index) {
  WaterAlert[index](value)
}

interop.updateEngineAlert <- function (value, index) {
  EngineAlert[index](value)
}

interop.updateEnginesThrottle <- function(mode, trt, state, index) {
  TrtMode[index](mode)
  Trt[index](trt)
  ThrottleState[index](state)
}

interop.updateEngineControl <- function(index, is_controlled) {
  isEngineControled[index](is_controlled)
}

interop.updateLaunchZone <- function(x0, y0, x1, y1, x2, y2, x3, y3) {
  let curVal = LaunchZoneWatched.get()
  if (curVal.x0 != x0 || curVal.y0 != y0 || curVal.x1 != x1 || curVal.y1 != y1
    || curVal.x2 != x2 || curVal.y2 != y2 || curVal.x3 != x3 || curVal.y3 != y3) {
    LaunchZoneWatched.set({ x0, x1, x2, x3, y0, y1, y2, y3 })
  }
}

return helicopterState