//checked for plus_string
from "%scripts/dagui_library.nut" import *
let { getOperationById } = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")
let { getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")

let getCustomAppearance = @(mapName) ::g_world_war.getSetting("mapCustomAppearance", null)?[mapName]

local function getCustomViewCountryData(countryName, mapName = null, needIconId = false) {
  mapName = mapName ?? getOperationById(::ww_get_operation_id())?.getMapId() ?? ""
  let customAppearance = getCustomAppearance(mapName)?[countryName]
  let iconId = customAppearance?.flag ?? countryName
  return {
    icon = needIconId ? iconId : getCountryIcon(iconId)
    locId = customAppearance?.name ?? countryName
  }
}

return {
  getCustomViewCountryData
}