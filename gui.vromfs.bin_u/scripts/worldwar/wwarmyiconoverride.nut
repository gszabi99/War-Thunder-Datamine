from "%scripts/dagui_library.nut" import *
let { getSettings, getSettingsArray } = require("%appGlobals/worldWar/wwSettings.nut")
let { artilleryReadyState } = require("%appGlobals/worldWar/wwArtilleryStatus.nut")
let wwEvent = require("%scripts/worldWar/wwEvent.nut")

artilleryReadyState.subscribe(function(p) {
  let armies = p.keys().map(@(armyName) ::g_world_war.getArmyByName(armyName))
  wwEvent("MapArmiesByStatusUpdated", { armies })
})

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