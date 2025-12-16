from "%scripts/dagui_natives.nut" import save_short_token, restart_game
from "%scripts/dagui_library.nut" import *
let { save_profile } = require("chard")
let { is_in_loading_screen } = require("%sqDagui/framework/baseGuiHandlerManager.nut")
let { isInSessionRoom } = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { is_pc } = require("%sqstd/platform.nut")

let canRestartClientByPlatform = is_pc

let canRestartClient = @() canRestartClientByPlatform
  && !(is_in_loading_screen() || isInSessionRoom.get())

function applyRestartClient() {

  if (!canRestartClient()) {
    showInfoMsgBox(loc("msgbox/client_restart_rejected"), "sysopt_restart_rejected")
    return
  }

  log("[sysopt] Restarting client.")
  save_profile(false)
  save_short_token()
  restart_game(false)
}

return {
  applyRestartClient
  canRestartClient
}
