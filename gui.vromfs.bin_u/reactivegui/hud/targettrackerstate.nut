local interopGen = require("reactiveGui/interopGen.nut")

local HasTargetTracker = Watched(false)
local IsSightLocked = Watched(false)
local IsTargetTracked = Watched(false)
local AimCorrectionEnabled = Watched(false)

local TargetRadius = Watched(0.0)
local TargetAge = Watched(0.0)

local TargetX = Watched(0.0)
local TargetY = Watched(0.0)


local targetTrackerState = {
  HasTargetTracker
  IsSightLocked
  IsTargetTracked
  AimCorrectionEnabled

  TargetRadius
  TargetAge

  TargetX
  TargetY
}

interopGen({
  stateTable = targetTrackerState
  prefix = "targetTracker"
  postfix = "Update"
})

return targetTrackerState
