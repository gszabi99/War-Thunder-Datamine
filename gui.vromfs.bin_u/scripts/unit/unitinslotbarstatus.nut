from "%scripts/crew/crewInfo.nut" import getCrewByAir
from "%scripts/dagui_library.nut" import *
from "%globalScripts/gameModeNativeConsts.nut" import *

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

return freeze({
  isUnitAvailableForGM
  isUnitInSlotbar
})