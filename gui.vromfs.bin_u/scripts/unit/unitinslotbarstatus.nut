from "%scripts/dagui_library.nut" import *

let { getCrewByAir } = require("%scripts/crew/crewInfo.nut")

let isUnitInSlotbar = @(unit) getCrewByAir(unit) != null

function isUnitAvailableForGM(air, gm) {
  if (air == null || !air.unitType.isAvailable())
    return false
  if (gm == GM_TEST_FLIGHT)
    return air.testFlight != "" || air.isAir() || air.isHelicopter() 
  if (gm == GM_DYNAMIC)
    return air.isAir()
  if (gm == GM_BUILDER)
    return air.isAir() && isUnitInSlotbar(air)
  return true
}

return {
  isUnitAvailableForGM
  isUnitInSlotbar
}