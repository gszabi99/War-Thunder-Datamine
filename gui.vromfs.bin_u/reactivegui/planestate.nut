local interopGen = require("interopGen.nut")

local Speed = Watched(0)
local Altitude = Watched(0.0)
local ClimbSpeed = Watched(0.0)
local Tangage = Watched(0.0)
local Roll = Watched(0.0)
local CompassValue = Watched(0.0)
local IlsVisible = Watched(false)
local IlsPosSize = [0, 0, 0, 0]
local IlsColor = Watched(Color(255, 0, 0, 240))
local BombingMode = Watched(false)
local AimLocked = Watched(false)
local TargetPosValid = Watched(false)
local TargetPos = [0, 0]
local TimeBeforeBombRelease = Watched(0.0)
local DistToSafety = Watched(0.0)
local Aos = Watched(0.0)
local DistToTarget = Watched(0.0)
local RocketMode = Watched(false)
local CannonMode = Watched(false)
local BombCCIPMode = Watched(false)
local BlkFileName = Watched("")
local IsMfdEnabled = Watched(false)
local OpticAtgmSightVisible = Watched(false)
local MfdOpticAtgmSightVis = Watched(false)
local MfdSightPosSize = [0, 0, 0, 0]
local TurretYaw = Watched(0.0)
local TurretPitch = Watched(0.0)
local AtgmTrackerVisible = Watched(false)
local IlsAtgmTrackerVisible = Watched(false)
local IlsAtgmTargetPos = [0, 0]
local IlsAtgmLocked = Watched(false)
local RwrScale = Watched(1.0)
local IsLaserDesignatorEnabled = Watched(false)
local LaserPoint = [0, 0]

local planeState = {
  BlkFileName,
  Speed,
  Altitude,
  ClimbSpeed,
  Tangage,
  Roll,
  CompassValue,
  IlsVisible,
  IlsPosSize,
  IlsColor,
  BombingMode,
  AimLocked,
  TargetPosValid,
  TargetPos,
  TimeBeforeBombRelease,
  DistToSafety,
  DistToTarget,
  Aos,
  RocketMode,
  CannonMode,
  BombCCIPMode,
  IsMfdEnabled,
  OpticAtgmSightVisible,
  MfdOpticAtgmSightVis,
  MfdSightPosSize,
  TurretYaw,
  TurretPitch,
  AtgmTrackerVisible,
  IlsAtgmTrackerVisible,
  IlsAtgmTargetPos,
  IlsAtgmLocked,
  RwrScale,
  IsLaserDesignatorEnabled,
  LaserPoint
}

::interop.updatePlaneIlsPosSize <- function(x, y, w, h) {
  IlsPosSize[0] = x
  IlsPosSize[1] = y
  IlsPosSize[2] = w
  IlsPosSize[3] = h
}

::interop.updatePlaneMfdSightPosSize <- function(x, y, w, h) {
  MfdSightPosSize[0] = x
  MfdSightPosSize[1] = y
  MfdSightPosSize[2] = w
  MfdSightPosSize[3] = h
}

::interop.updatePlaneTargetPos <- function(x, y) {
  TargetPos[0] = x
  TargetPos[1] = y
}

::interop.updateLaserPoint <- function(x, y) {
  LaserPoint[0] = x
  LaserPoint[1] = y
}

::interop.updateIlsAtgmTargetPos <- function(x, y) {
  IlsAtgmTargetPos[0] = x
  IlsAtgmTargetPos[1] = y
}

interopGen({
  stateTable = planeState
  prefix = "plane"
  postfix = "Update"
})

return planeState