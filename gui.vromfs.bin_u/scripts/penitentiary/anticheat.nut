local function shouldUseEac(event)
{
  return event?.enableEAC ?? false
}

local function showMsgboxIfEacInactive(event)
{
  if (::is_eac_inited() || !shouldUseEac(event))
    return true

  ::scene_msg_box("eac_required", null, ::loc("eac/eac_not_inited_restart"),
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