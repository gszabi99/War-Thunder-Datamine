from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let isClientRestartable = @() !::is_vendor_tencent()

let canRestartClient = @() isClientRestartable()
  && !(::is_in_loading_screen() || ::SessionLobby.isInRoom())

let function applyRestartClient() {
  if (!isClientRestartable())
    return

  if (!canRestartClient()) {
    ::showInfoMsgBox(loc("msgbox/client_restart_rejected"), "sysopt_restart_rejected")
    return
  }

  log("[sysopt] Restarting client.")
  ::save_profile(false)
  ::save_short_token()
  ::restart_game(false)
}

return {
  applyRestartClient
  isClientRestartable
  canRestartClient
}
