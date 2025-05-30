from "%scripts/dagui_natives.nut" import is_decals_disabled, get_time_till_decals_disabled
from "%scripts/dagui_library.nut" import *

let { eventbus_send, eventbus_subscribe } = require("eventbus")
let penalty = require("penalty")
let { leaveSessionRoom } = require("%scripts/matchingRooms/sessionLobbyManager.nut")
let { leaveAllQueuesSilent } = require("%scripts/queue/queueManager.nut")
let { getBannedMessage } = require("%scripts/penitentiary/penaltyMessages.nut")

















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

return {
  showBannedStatusMsgBox
}