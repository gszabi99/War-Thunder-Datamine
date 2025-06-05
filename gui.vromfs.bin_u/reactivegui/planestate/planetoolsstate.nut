from "%rGui/globals/ui_library.nut" import *

let { interop } = require("%rGui/globals/interop.nut")
let interopGen = require("%rGui/interopGen.nut")

let IlsVisible = Watched(false)
let IlsPosSize = [0, 0, 0, 0]
let IlsColor = Watched(Color(255, 255, 0, 240))
let IlsLineScale = Watched(1.0)
let BombingMode = Watched(false)
let AimLocked = Watched(false)
let TargetPosValid = Watched(false)
let TargetPos = Watched([0, 0])
let TimeBeforeBombRelease = Watched(0.0)
let DistToSafety = Watched(0.0)
let DistToTarget = Watched(0.0)
let RocketMode = Watched(false)
let AAMRocketMode = Watched(false)
let CannonMode = Watched(false)
let AirCannonMode = Watched(false)
let BombCCIPMode = Watched(false)
let BlkFileName = Watched("")
let IsMfdEnabled = Watched(false)
let MfdOpticAtgmSightVis = Watched(false)
let IlsAtgmTrackerVisible = Watched(false)
let IlsAtgmTargetPos = [0, 0]
let IlsAtgmLocked = Watched(false)
let RwrScale = Watched(1.0)
let RwrBackHide = Watched(false)
let RadarTargetDistRate = Watched(0.0)
let RadarTargetDist = Watched(0.0)
let RadarTargetHeight = Watched(0.0)
let RadarTargetPosValid = Watched(false)
let RadarTargetPos = [0, 0]
let RadarTargetAngle = Watched(-1.0)
let RadarTargetVel = Watched(-1.0)
let RadarTargetBearing = Watched(0.0)
let GunfireSolutionPointNum = Watched(-1)
let GunfireSolution = [-1, -1]
let AamAccelLock = Watched(false)
let MfdRadarWithNavVis = Watched(false)
let MfdRadarNavPosSize = [0, 0, 0, 0]
let AimLockPos = [0, 0]
let AimLockValid = Watched(false)
let AimLockDist = Watched(-1)
let TvvMark = [0, 0] 
let TvvIlsMark = [0, 0]
let IsTVVIlsMarkValid = Watched(false)
let TvvHMDMark = [0, 0]
let AtgmTargetDist = Watched(0.0)
let MfdVdiVisible = Watched(false)
let MfdVdiPosSize = [0, 0, 0, 0]
let VdiColor = Watched(Color(255, 255, 0, 240))
let IsOnGround = Watched(false)
let DigitalDevicesVisible = Watched(false)
let DigDevicesPosSize = [0, 0, 0, 0]
let MfdCameraZoom = Watched(0.0)
let HmdYaw = Watched(0.0)
let HmdPitch = Watched(0.0)
let HmdVisible = Watched(false)
let HmdBlockIls = Watched(false)
let RwrBlkName = Watched("")
let AimLockYaw = Watched(0.0)
let AimLockPitch = Watched(0.0)
let ScreenFwdDirPos = [0, 0]
let HmdTargetPos = [0, 0]
let HmdTargetPosValid = Watched(false)
let CustomPages = Watched({})
let HmdGunTargeting = Watched(false)
let MfdRwrColor = Watched(Color(0, 255, 0, 240))
let IsLightsOn = Watched(false)
let HmdBrightnessMult = Watched(1.0)
let MfdHsdVisible = Watched(false)
let MfdHsdPosSize = Watched([0.0, 0.0, 0.0, 0.0])
let TVVPitch = Watched(0.0)

let planeState = {
  BlkFileName,
  IlsVisible,
  IlsPosSize,
  IlsColor,
  IlsLineScale,
  BombingMode,
  AimLocked,
  TargetPosValid,
  TargetPos,
  TimeBeforeBombRelease,
  DistToSafety,
  DistToTarget,
  RocketMode,
  AAMRocketMode,
  CannonMode,
  BombCCIPMode,
  IsMfdEnabled,
  MfdOpticAtgmSightVis,
  IlsAtgmTrackerVisible,
  IlsAtgmTargetPos,
  IlsAtgmLocked,
  RwrScale,
  RwrBackHide,
  RadarTargetDist,
  RadarTargetPosValid,
  RadarTargetPos,
  RadarTargetDistRate,
  RadarTargetHeight,
  RadarTargetAngle,
  RadarTargetBearing,
  RadarTargetVel,
  GunfireSolutionPointNum,
  GunfireSolution,
  AamAccelLock,
  MfdRadarWithNavVis,
  MfdRadarNavPosSize,
  AimLockValid,
  AimLockDist,
  AimLockPos,
  TvvMark,
  TvvIlsMark,
  IsTVVIlsMarkValid,
  TvvHMDMark,
  AtgmTargetDist,
  MfdVdiVisible,
  MfdVdiPosSize,
  VdiColor,
  IsOnGround,
  AirCannonMode,
  DigitalDevicesVisible,
  DigDevicesPosSize,
  MfdCameraZoom,
  HmdYaw,
  HmdPitch,
  HmdVisible,
  HmdBlockIls,
  HmdBrightnessMult,
  RwrBlkName,
  AimLockYaw,
  AimLockPitch,
  ScreenFwdDirPos,
  HmdTargetPos,
  HmdTargetPosValid,
  CustomPages,
  HmdGunTargeting,
  MfdRwrColor,
  IsLightsOn,
  MfdHsdVisible,
  MfdHsdPosSize,
  TVVPitch
}

interop.updatePlaneIlsPosSize <- function(x, y, w, h) {
  IlsPosSize[0] = x
  IlsPosSize[1] = y
  IlsPosSize[2] = w
  IlsPosSize[3] = h
}

interop.updatePlaneMfdRadarNavPosSize <- function(x, y, w, h) {
  MfdRadarNavPosSize[0] = x
  MfdRadarNavPosSize[1] = y
  MfdRadarNavPosSize[2] = w
  MfdRadarNavPosSize[3] = h
}

interop.updatePlaneVdiPosSize <- function(x, y, w, h) {
  MfdVdiPosSize[0] = x
  MfdVdiPosSize[1] = y
  MfdVdiPosSize[2] = w
  MfdVdiPosSize[3] = h
}

interop.updateDigDevicesPosSize <- function(x, y, w, h) {
  DigDevicesPosSize[0] = x
  DigDevicesPosSize[1] = y
  DigDevicesPosSize[2] = w
  DigDevicesPosSize[3] = h
}

interop.updatePlaneMfdHsdPosSize <- function(x, y, w, h) {
  let curVal = MfdHsdPosSize.get()
  if (curVal[0] != x || curVal[1] != y || curVal[2] != w || curVal[3] != h)
    MfdHsdPosSize([x, y, w, h])
}

interop.updateAimLockPos <- function(x, y) {
  AimLockPos[0] = x
  AimLockPos[1] = y
}

interop.updateScreenFwdDirPos <- function(x, y) {
  ScreenFwdDirPos[0] = x
  ScreenFwdDirPos[1] = y
}

interop.updateRadarTargetPos <- function(x, y) {
  RadarTargetPos[0] = x
  RadarTargetPos[1] = y
}

interop.updateGunfireSolution <- function(x, y) {
  GunfireSolution[0] = x
  GunfireSolution[1] = y
}

interop.updateIlsAtgmTargetPos <- function(x, y) {
  IlsAtgmTargetPos[0] = x
  IlsAtgmTargetPos[1] = y
}

interop.updateTvvTarget <- function(x, y) {
  TvvMark[0] = x
  TvvMark[1] = y
}

interop.updateTVVIls <- function(x, y) {
  TvvIlsMark[0] = x
  TvvIlsMark[1] = y
}

interop.updateTvvHmd <- function(x, y) {
  TvvHMDMark[0] = x
  TvvHMDMark[1] = y
}

interop.updateHmdTargetPos <- function(x, y) {
  HmdTargetPos[0] = x
  HmdTargetPos[1] = y
}

interopGen({
  stateTable = planeState
  prefix = "plane"
  postfix = "Update"
})

return planeState