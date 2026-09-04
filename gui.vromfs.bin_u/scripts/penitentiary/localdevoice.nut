from "%sqStdLibs/helpers/subscriptions.nut" import add_event_listener
from "gameplayBinding" import isInFlight
from "%scripts/dagui_library.nut" import *

let devoiceList = {}

let localDevoice = {
  
  DEVOICE_RADIO      = 0x0001
  DEVOICE_MESSAGES   = 0x0002
  

  isMuted = @(name, devoiceMask) ((devoiceList?[name] ?? 0) & devoiceMask) != 0

  setMuted   = function(name, devoiceMask) { devoiceList[name] <- (devoiceList?[name] ?? 0) | devoiceMask }
  unsetMuted = function(name, devoiceMask) { devoiceList[name] <- (devoiceList?[name] ?? 0) & ~devoiceMask }
  switchMuted = @(name, devoiceMask) (this.isMuted(name, devoiceMask) ? this.unsetMuted : this.setMuted)(name, devoiceMask)
}

add_event_listener("LoadingStateChange",
  function(_p) {
    if (isInFlight())
      devoiceList.clear()
  }, localDevoice)

return localDevoice
