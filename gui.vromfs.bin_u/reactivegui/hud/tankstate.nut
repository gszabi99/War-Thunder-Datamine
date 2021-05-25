local interopGen = require("reactiveGui/interopGen.nut")
local { floor } = require("std/math.nut")

local IsCommanderViewAimModeActive = Watched(false)

local activeProtectionSystemModules = []
local ActiveProtectionSystemModulesCount = Watched(0)

local getModuleDefaultParams = @() {
  shotCountRemain = Watched(0)
  emitterPosX = Watched(0.0)
  emitterPosY = Watched(0.0)
  horAnglesX = Watched(0.0)
  horAnglesY = Watched(0.0)
  timeToReady = Watched(0.0)
}
local function resizeActiveProtectionSystemModules(count) {
  local size = activeProtectionSystemModules.len()
  if (count < size) {
    activeProtectionSystemModules.resize(count)
    return
  }

  for (local i = size; i < count; i++)
    activeProtectionSystemModules.append(getModuleDefaultParams())
}

ActiveProtectionSystemModulesCount.subscribe(resizeActiveProtectionSystemModules)

local tankState = {
  IsCommanderViewAimModeActive
  ActiveProtectionSystemModulesCount
  activeProtectionSystemModules
}

interopGen({
  stateTable = tankState
  prefix = "tank"
  postfix = "Update"
})

::interop.updateActiveProtectionSystem <- function (shotCountRemain, emitterPosX, emitterPosY, horAnglesX, horAnglesY, timeToReady, index) {
  local module = activeProtectionSystemModules[index]
  module.shotCountRemain(shotCountRemain)
  module.emitterPosX(floor(emitterPosX*100)/100)
  module.emitterPosY(floor(emitterPosY*100)/100)
  module.horAnglesX(floor(horAnglesX*100)/100)
  module.horAnglesY(floor(horAnglesY*100)/100)
  module.timeToReady(floor(timeToReady*100)/100)
}

return tankState
