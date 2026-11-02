import "%rGui/style/fontsState.nut" as fontsState
import "%appGlobals/style/cssColors.nut" as cssColors
import "%rGui/hud/spectator/replayPausedBlock.nut" as replayPausedBlock
import "%rGui/hud/spectator/spectatorToolbar.nut" as spectatorToolbar
import "%rGui/hud/spectator/sensorFilters.nut" as sensorFilters
import "%rGui/hud/spectator/teamTables.nut" as teamTables
from "%rGui/globals/ui_library.nut" import *
from "%rGui/dagui/units.nut" import px
from "%rGui/components/text.nut" import mkText
from "%rGui/style/screenState.nut" import bw, bh
from "%appGlobals/hud/spectatorState.nut" import spectatorSession
from "%rGui/hud/spectator/spectatorLiveState.nut" import startLiveUpdates, stopLiveUpdates

let sessionIdX = px("0.085@sf")
let sessionIdY = sh(100) - px("0.015@sf")
let sessionIdFont = fontsState.get("tiny")

function sessionIdText() {
  let sessionId = spectatorSession.get()?.sessionId ?? ""
  let watch = [spectatorSession, bw, bh]
  
  return sessionId == "" ? { watch }
    : mkText(sessionId, sessionIdFont, cssColors.commonTextColor,
        { watch, pos = [sessionIdX - bw.get(), sessionIdY - bh.get()] })
}

return freeze({
  size = flex()
  onAttach = startLiveUpdates
  onDetach = stopLiveUpdates
  children = [
    teamTables
    spectatorToolbar
    sensorFilters
    sessionIdText
    replayPausedBlock
  ]
})
