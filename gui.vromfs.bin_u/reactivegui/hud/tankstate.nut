from "%rGui/globals/ui_library.nut" import *

let { interop } = require("%rGui/globals/interop.nut")
let interopGen = require("%rGui/interopGen.nut")
let { floor } = require("%sqstd/math.nut")

let IndicatorsVisible = Watched(false)
let CurrentTime = Watched(false)

let CoaxialBullets = Watched(0)
let CoaxialCartridges = Watched(0)
let CoaxialCartridgeSize = Watched(0)
let CoaxialGunStartLoadAtTime = Watched(0)
let CoaxialGunNextShotAtTime = Watched(0)
let MachineGunBullets = Watched(0)
let MachineGunCartridges = Watched(0)
let MachineGunCartridgeSize = Watched(0)
let MachineGunStartLoadAtTime = Watched(0)
let MachineGunNextShotAtTime = Watched(0)

let IsCommanderViewAimModeActive = Watched(false)

let activeProtectionSystemModules = []
let activeProtectionSystemModulesCount = Watched(0)

let getModuleDefaultParams = @() {
  shotCountRemain = Watched(0)
  emitterPosX = Watched(0.0)
  emitterPosY = Watched(0.0)
  horAnglesX = Watched(0.0)
  horAnglesY = Watched(0.0)
  timeToReady = Watched(0.0)
  shotCount = Watched(0.0)
}
function resizeActiveProtectionSystemModules(count) {
  let size = activeProtectionSystemModules.len()
  if (count < size) {
    activeProtectionSystemModules.resize(count)
    return
  }

  for (local i = size; i < count; i++)
    activeProtectionSystemModules.append(getModuleDefaultParams())
}

activeProtectionSystemModulesCount.subscribe(resizeActiveProtectionSystemModules)

let tankState = {
  IndicatorsVisible,
  CurrentTime,

  IsCommanderViewAimModeActive

  activeProtectionSystemModulesCount
  activeProtectionSystemModules
  CoaxialBullets
  CoaxialCartridges
  CoaxialCartridgeSize
  CoaxialGunStartLoadAtTime
  CoaxialGunNextShotAtTime
  MachineGunBullets
  MachineGunCartridges
  MachineGunCartridgeSize
  MachineGunStartLoadAtTime
  MachineGunNextShotAtTime

  




}

interopGen({
  stateTable = tankState
  prefix = "tank"
  postfix = "Update"
})

interop.updateActiveProtectionSystem <- function (shotCount, shotCountRemain, emitterPosX, emitterPosY, horAnglesX, horAnglesY, timeToReady, index) {
  if (index >= activeProtectionSystemModules.len())
    return
  let module = activeProtectionSystemModules[index]
  module.shotCount(shotCount)
  module.shotCountRemain(shotCountRemain)
  module.emitterPosX(floor(emitterPosX * 100) / 100)
  module.emitterPosY(floor(emitterPosY * 100) / 100)
  module.horAnglesX(floor(horAnglesX * 100) / 100)
  module.horAnglesY(floor(horAnglesY * 100) / 100)
  module.timeToReady(floor(timeToReady * 100) / 100)
}

return tankState
