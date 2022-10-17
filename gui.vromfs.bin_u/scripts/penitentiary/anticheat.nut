let { isPlatformSteamDeck } = require("%scripts/clientState/platform.nut")

let function shouldUseEac(event)
{
  return event?.enableEAC ?? false
}

let function showMsgboxIfEacInactive(event)
{
  if (::is_eac_inited() || !shouldUseEac(event))
    return true

  let eac = isPlatformSteamDeck && ::is_platform_windows
    ? "eac/eac_for_linux"
    : "eac/eac_not_inited_restart"

  ::scene_msg_box("eac_required", null, ::loc(eac),
       [
         ["restart",  function() {::restart_game(true)}],
         ["cancel", function() {}]
       ], null)
  return false
}


return {
  showMsgboxIfEacInactive = showMsgboxIfEacInactive
  shouldUseEac = shouldUseEac
}