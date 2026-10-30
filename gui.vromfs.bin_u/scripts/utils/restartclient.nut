from "%scripts/sqDagui/framework/baseGuiHandlerManager.nut" import is_in_loading_screen
from "%scripts/matchingRooms/sessionLobbyState.nut" import isInSessionRoom
from "chard" import save_profile
from "%sqstd/platform.nut" import is_pc
from "%scripts/dagui_natives.nut" import save_short_token, restart_game
from "%scripts/dagui_library.nut" import *

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

return freeze({
  applyRestartClient
  canRestartClient
})
