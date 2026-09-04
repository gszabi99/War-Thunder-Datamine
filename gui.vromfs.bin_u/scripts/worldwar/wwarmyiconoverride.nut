from "%appGlobals/worldWar/wwSettings.nut" import getSettings, getSettingsArray
from "%appGlobals/worldWar/wwArtilleryStatus.nut" import artilleryReadyState
from "%scripts/dagui_library.nut" import *

let suffix = {
  UT_GROUND = "LoadedGround"
  UT_ARTILLERY = "LoadedArtillery"
  UT_INFANTRY = "LoadedInfantry"
}

function getIcon(name, overrideIconId, loadedArmyType, hasArtilleryAbility) {
  let isSimpleArtillery = overrideIconId == "" && hasArtilleryAbility

  let iconData = isSimpleArtillery ? getSettings("armyIconArtillery")
    : getSettingsArray("armyIconCustom").findvalue(@(v) v.name == overrideIconId)

  let ready = hasArtilleryAbility && (artilleryReadyState.get()?[name] ?? true)
  let suff = hasArtilleryAbility && ready ? "Ready" : suffix?[loadedArmyType] ?? ""
  return iconData?[$"iconName{suff}"] ?? ""
}

return {
  getIcon
}