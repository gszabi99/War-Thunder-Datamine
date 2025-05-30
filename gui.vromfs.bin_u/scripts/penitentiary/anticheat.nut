from "%scripts/dagui_natives.nut" import restart_game, is_eac_inited
from "%scripts/dagui_library.nut" import *
let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { isPlatformSteamDeck } = require("%scripts/clientState/platform.nut")

function shouldUseEac(event) {
  return event?.enableEAC ?? false
}

function getSlotbarMaxMrank(event) {
  let ediff = events.getEDiffByEvent(event)
  let playersCurCountry = profileCountrySq.value
  let sidesList = events.getSidesList(event)
  let teamData = events.getTeamData(event, sidesList[0])
  let validUnits = events.getValidUnitsListForTeam(event, teamData, playersCurCountry)

  local maxMrank = 0
  foreach (unit in validUnits) {
    let mrank = unit.getEconomicRank(ediff)
    maxMrank = mrank > maxMrank ? mrank : maxMrank
  }
  return maxMrank
}

function showMsgboxIfEacInactive(event) {
  if (is_eac_inited())
    return true
  local mrankConditionComplete = true
  if ((event?.antiCheatEnableMrank ?? -1) >= 0) {
    let slotbarMaxMrank = getSlotbarMaxMrank(event)
    mrankConditionComplete = slotbarMaxMrank < event.antiCheatEnableMrank
  }

  if (mrankConditionComplete && !shouldUseEac(event))
    return true

  let eac = isPlatformSteamDeck && is_platform_windows
    ? "eac/eac_for_linux"
    : "eac/eac_not_inited_restart"

  scene_msg_box("eac_required", null, loc(eac),
       [
         ["restart",  function() { restart_game(true) }],
         ["cancel", function() {}]
       ], null)
  return false
}

return {
  showMsgboxIfEacInactive = showMsgboxIfEacInactive
  shouldUseEac = shouldUseEac
}