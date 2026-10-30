import "penalty" as penalty
from "%scripts/matchingRooms/sessionLobbyManager.nut" import leaveSessionRoom
from "%scripts/queue/queueManager.nut" import leaveAllQueuesSilent
from "%scripts/penitentiary/penaltyMessages.nut" import getBannedMessage
from "eventbus" import eventbus_send, eventbus_subscribe
from "%scripts/dagui_natives.nut" import is_decals_disabled
from "%scripts/dagui_library.nut" import *

















function showBannedStatusMsgBox(showBanOnly = false) {
  let st = penalty.getPenaltyStatus()
  if (showBanOnly && st.status != penalty.BAN) {
    return
  }

  debugTableData(st, { recursionLevel = -1, addStr = "BAN " })

  local fn = function() {}
  local banType = ""
  if (st.status == penalty.BAN) {
    banType  = "ban"
    fn = @() eventbus_send("request_logout", {})
    leaveAllQueuesSilent()
    leaveSessionRoom()
  }
  else if (st.status == penalty.DEVOICE) {
    if (is_decals_disabled()) {
      banType = "mutedecal"
    }
    else {
      banType = "mute"
    }
  }
  else if (is_decals_disabled()) {
    banType = "decal"
  }
  else {
    return
  }

  let txt = getBannedMessage(st, banType)
  if (txt != "") {
    scene_msg_box("banned", null, txt, [["ok", fn ]], "ok", { saved = true, cancel_fn = fn })
  }
}

eventbus_subscribe("request_show_banned_status_msgbox", @(event) showBannedStatusMsgBox(event?.showBanOnly ?? false))

return freeze({
  showBannedStatusMsgBox
})