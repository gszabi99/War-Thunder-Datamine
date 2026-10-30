from "%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut" import getOperationById
from "%scripts/options/countryFlagsPreset.nut" import getCountryIcon
from "%scripts/worldWar/worldWarCfgState.nut" import getWwSetting
from "worldwar" import wwGetOperationId
from "%scripts/dagui_library.nut" import *

let getCustomAppearance = @(mapName) getWwSetting("mapCustomAppearance", null)?[mapName]

function getCustomViewCountryData(countryName, mapName = null, needIconId = false) {
  mapName = mapName ?? getOperationById(wwGetOperationId())?.getMapId() ?? ""
  let customAppearance = getCustomAppearance(mapName)?[countryName]
  let iconId = customAppearance?.flag ?? countryName
  return {
    icon = needIconId ? iconId : getCountryIcon(iconId, false)
    locId = customAppearance?.name ?? countryName
  }
}

return freeze({
  getCustomViewCountryData
})