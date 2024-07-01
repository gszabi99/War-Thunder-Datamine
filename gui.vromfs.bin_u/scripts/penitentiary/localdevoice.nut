from "%scripts/dagui_library.nut" import *


let { add_event_listener } = require("%sqStdLibs/helpers/subscriptions.nut")
let { isInFlight } = require("gameplayBinding")

let devoiceList = {}

let localDevoice = {
  //Devoice type bit mask
  DEVOICE_RADIO      = 0x0001
  DEVOICE_MESSAGES   = 0x0002
  //end of devoice type bit mask

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
