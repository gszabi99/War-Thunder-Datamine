from "%scripts/dagui_natives.nut" import restart_game, is_eac_inited
from "%scripts/dagui_library.nut" import *
let { is_windows } = require("%sqstd/platform.nut")
let { isPlatformSteamDeck } = require("%scripts/clientState/platform.nut")
let { recentBR } = require("%scripts/battleRating.nut")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let { calcBattleRatingFromRank } = require("%appGlobals/ranks_common_shared.nut")

function isEventMrankConditionComplete(event) {
  if ((event?.antiCheatEnableMrank ?? -1) >= 0) {
    let br = g_squad_manager.isSquadMember()
      ? g_squad_manager.getLeaderBattleRating()
      : recentBR.get()
    return br < calcBattleRatingFromRank(event.antiCheatEnableMrank)
  }
  return true
}

function shouldUseEac(event) {
  if (!isEventMrankConditionComplete(event))
    return true
  return event?.enableEAC ?? false
}

function showMsgboxIfEacInactive(event) {
  if (is_eac_inited() || !shouldUseEac(event))
    return true

  let eac = isPlatformSteamDeck && is_windows
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