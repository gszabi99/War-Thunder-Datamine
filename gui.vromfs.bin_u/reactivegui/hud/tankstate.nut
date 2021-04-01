local interopGen = require("reactiveGui/interopGen.nut")

local IsCommanderViewAimModeActive = Watched(false)

local activeProtectionSystemModules = []
local ActiveProtectionSystemModulesCount = Watched(0)

local getModuleDefaultParams = @() {
  shotCountRemain = Watched(0)
  posX = Watched(0.0)
  posY = Watched(0.0)
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

::interop.updateActiveProtectionSystem <- function (shotCountRemain, posX, posY, horAnglesX, horAnglesY, timeToReady, index) {
  local module = activeProtectionSystemModules[index]
  module.shotCountRemain(shotCountRemain)
  module.posX(posX)
  module.posY(posY)
  module.horAnglesX(horAnglesX)
  module.horAnglesY(horAnglesY)
  module.timeToReady(timeToReady)
}

return tankState
