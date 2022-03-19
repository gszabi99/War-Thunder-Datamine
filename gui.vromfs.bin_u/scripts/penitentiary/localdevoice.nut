local devoiceList = {}

local localDevoice = {
  //Devoice type bit mask
  DEVOICE_RADIO      = 0x0001
  DEVOICE_MESSAGES   = 0x0002
  //end of devoice type bit mask

  isMuted = @(name, devoiceMask) ((devoiceList?[name] ?? 0) & devoiceMask) != 0

  setMuted   = function(name, devoiceMask) { devoiceList[name] <- (devoiceList?[name] ?? 0) | devoiceMask }
  unsetMuted = function(name, devoiceMask) { devoiceList[name] <- (devoiceList?[name] ?? 0) & ~devoiceMask }
  switchMuted = @(name, devoiceMask) (isMuted(name, devoiceMask) ? unsetMuted : setMuted)(name, devoiceMask)
}

::add_event_listener("LoadingStateChange",
  function(p)
  {
    if (::is_in_flight())
      devoiceList.clear()
  }, localDevoice)

return localDevoice
