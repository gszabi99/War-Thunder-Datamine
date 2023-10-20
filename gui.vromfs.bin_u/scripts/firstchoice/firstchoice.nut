//checked for plus_string
from "%scripts/dagui_library.nut" import *
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { isPlatformXboxOne } = require("%scripts/clientState/platform.nut")
let { getPlayerName } = require("%scripts/user/remapNick.nut")

let isFirstChoiceShown = mkWatched(persist, "isFirstChoiceShown", false)

let getFirstChosenUnitType = function(defValue = ES_UNIT_TYPE_INVALID) {
  foreach (unitType in unitTypes.types)
    if (unitType.isFirstChosen())
      return unitType.esUnitType
  return defValue
}

let isNeedFirstCountryChoice = function() {
  return getFirstChosenUnitType() == ES_UNIT_TYPE_INVALID
         && !::stat_get_value_respawns(0, 1)
         && !::disable_network()
}

let fillUserNick = function (nestObj, _headerLocId = null) {
  if (!::g_login.isProfileReceived() || !isPlatformXboxOne)
    return

  if (!nestObj?.isValid())
    return

  let guiScene = nestObj.getScene()
  if (!guiScene)
    return

  let cfg = ::get_profile_info()
  let data =  handyman.renderCached("%gui/firstChoice/userNick.tpl", {
      userIcon = cfg?.icon ? $"#ui/images/avatars/{cfg.icon}" : ""
      userName = colorize("@mainPlayerColor", getPlayerName(cfg?.name ?? ""))
    })
  guiScene.replaceContentFromText(nestObj, data, data.len(), null)
}

return {
  fillUserNick
  getFirstChosenUnitType
  isNeedFirstCountryChoice
  isFirstChoiceShown
}