from "%rGui/globals/ui_library.nut" import *

let { scoreLimit, localTeam, ticketsTeamA, ticketsTeamB } = require("%rGui/missionState.nut")
let { mkTeamProgress, mkTeamCapPoint } = require("%rGui/hud/scoreboard/hudElemsPkg.nut")
let { startPollingZonesState, stopPollingZonesState, capZones
} = require("%rGui/hud/capZones/capZonesState.nut")


function mkCaptureZones() {
  let zonesCount = Computed(@() capZones.get().len())
  return @() {
    watch = zonesCount
    flow = FLOW_HORIZONTAL
    gap = hdpx(2)
    valign = ALIGN_CENTER
    children = capZones.get().map(function(_cz, idx) {
      return mkTeamCapPoint(Computed(@() capZones.get()?[idx]), localTeam)
    })
  }
}


return function mkBattleHud() {
  let localTeamTicketsW = Computed(@() localTeam.get() == 2
    ? ticketsTeamB.get()
    : ticketsTeamA.get())
  let enemyTeamTicketsW = Computed(@() localTeam.get() == 2
    ? ticketsTeamA.get()
    : ticketsTeamB.get())

  return {
    key = {}
    size = [hdpx(420), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    gap = hdpx(4)
    valign = ALIGN_CENTER
    halign = ALIGN_CENTER
    children = [
      mkTeamProgress(true, localTeamTicketsW, scoreLimit)
      mkCaptureZones()
      mkTeamProgress(false, enemyTeamTicketsW, scoreLimit)
    ]
    onAttach = startPollingZonesState
    onDetach = stopPollingZonesState
  }
}
