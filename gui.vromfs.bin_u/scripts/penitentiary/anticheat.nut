from "%appGlobals/ranks_common_shared.nut" import calcBattleRatingFromRank
from "%sqstd/platform.nut" import is_windows
from "%scripts/dagui_natives.nut" import restart_game, is_eac_inited
from "%scripts/dagui_library.nut" import *

let { isPlatformSteamDeck } = require("%scripts/clientState/platform.nut")
let { recentBR } = require("%scripts/battleRatingState.nut")
let { getLeaderBattleRating, isSquadMember } = require("%scripts/squads/squadState.nut")

function isEventMrankConditionComplete(event) {
  if ((event?.antiCheatEnableMrank ?? -1) >= 0) {
    let br = isSquadMember()
      ? getLeaderBattleRating()
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