from "%rGui/globals/ui_library.nut" import *

let interopGen = require("interopGen.nut")

let fcsState = {
  IsVisible = Watched(false)
  IsBinocular = Watched(false)
  OpticsWidth = Watched(0.0)
  StaticFov = Watched(0.0)
  CalcProgress = Watched(-1.0)

  IsTargetSelected = Watched(false)
  IsTargetDataAvailable = Watched(false)
  TargetFwdDir = Watched(0.0)
  TargetSpeed = Watched(0.0)
  TargetAzimuth = Watched(0.0)

  HeadingAngle = Watched(0.0)
  HeroAzimuthAngle = Watched(0.0)
  TargetAzimuthAngle = Watched(0.0)
  ShotState = Watched(FCSShotState.SHOT_NONE)
  ShotDiscrepancy = Watched(0.0)
  IsFCSVisible = Watched(false)

  IsForestallVisible = Watched(false)
  IsHorizontalAxisVisible = Watched(true)
  IsVerticalAxisVisible = Watched(true)
  IsForestallMarkerVisible = Watched(true)
  ForestallAzimuth = Watched(0.0)
  ForestallAzimuthWidth = Watched(0.0)
  ForestallPitchDelta = Watched(0.0)
  ForestallPosX = Watched(0.0)
  ForestallPosY = Watched(0.0)
  TargetPosX = Watched(0.0)
  TargetPosY = Watched(0.0)
}

interopGen({
  stateTable = fcsState
  prefix = "fcs"
  postfix = "Update"
})

return fcsState
