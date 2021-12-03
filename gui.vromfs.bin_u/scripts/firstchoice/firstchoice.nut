local unitTypes = require("scripts/unit/unitTypesList.nut")
local { getPlayerName, isPlatformXboxOne } = require("scripts/clientState/platform.nut")

local getFirstChosenUnitType = function(defValue = ::ES_UNIT_TYPE_INVALID)
{
  foreach(unitType in unitTypes.types)
    if (unitType.isFirstChosen())
      return unitType.esUnitType
  return defValue
}

local isNeedFirstCountryChoice = function()
{
  return getFirstChosenUnitType() == ::ES_UNIT_TYPE_INVALID
         && !::stat_get_value_respawns(0, 1)
         && !::disable_network()
}

local fillUserNick = function (nestObj, headerLocId = null) {
  if (!isPlatformXboxOne)
    return

  if (!nestObj?.isValid())
    return

  local guiScene = nestObj.getScene()
  if (!guiScene)
    return

  local cfg = ::get_profile_info()
  local data =  ::handyman.renderCached("gui/firstChoice/userNick", {
      userIcon = cfg?.icon ? $"#ui/images/avatars/{cfg.icon}" : ""
      userName = ::colorize("@mainPlayerColor", getPlayerName(cfg?.name ?? ""))
    })
  guiScene.replaceContentFromText(nestObj, data, data.len())
}

return {
  fillUserNick
  getFirstChosenUnitType
  isNeedFirstCountryChoice
}