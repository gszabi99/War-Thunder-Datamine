from "%scripts/dagui_library.nut" import *
let { getOperationById } = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")
let { getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")
let { wwGetOperationId } = require("worldwar")
let { getWwSetting } = require("%scripts/worldWar/worldWarStates.nut")

let getCustomAppearance = @(mapName) getWwSetting("mapCustomAppearance", null)?[mapName]

function getCustomViewCountryData(countryName, mapName = null, needIconId = false) {
  mapName = mapName ?? getOperationById(wwGetOperationId())?.getMapId() ?? ""
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