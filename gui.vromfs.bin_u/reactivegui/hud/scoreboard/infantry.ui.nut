from "%rGui/missionState.nut" import scoreLimit, localTeam, ticketsTeamA, ticketsTeamB
from "%rGui/hud/scoreboard/hudElemsPkg.nut" import mkTeamProgress, mkTeamCapPoint
from "%rGui/hud/capZones/capZonesState.nut" import startPollingZonesState, stopPollingZonesState, capZones
from "console" import register_command
from "%rGui/globals/ui_library.nut" import *

const ANIM_TRIGGER_ALLY = "main_anim_ally"
const ANIM_TRIGGER_ENEMY = "main_anim_enemy"


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

register_command(@() anim_start(ANIM_TRIGGER_ALLY), "ui.debug.infantry_battle_hud.play_anim_a")
register_command(@() anim_start(ANIM_TRIGGER_ENEMY), "ui.debug.infantry_battle_hud.play_anim_b")

return function mkBattleHud() {
  let localTeamTicketsW = Computed(@() localTeam.get() == 2
    ? ticketsTeamB.get()
    : ticketsTeamA.get())
  let enemyTeamTicketsW = Computed(@() localTeam.get() == 2
    ? ticketsTeamA.get()
    : ticketsTeamB.get())

  let onAllyTickets = @(score) score > 0 && anim_start(ANIM_TRIGGER_ALLY)
  let onEnemyTickets = @(score) score > 0 && anim_start(ANIM_TRIGGER_ENEMY)

  return {
    key = {}
    size = const [hdpx(420), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    gap = hdpx(4)
    valign = ALIGN_CENTER
    halign = ALIGN_CENTER
    children = [
      mkTeamProgress(true, localTeamTicketsW, scoreLimit, ANIM_TRIGGER_ALLY)
      mkCaptureZones()
      mkTeamProgress(false, enemyTeamTicketsW, scoreLimit, ANIM_TRIGGER_ENEMY)
    ]
    onAttach = function() {
      localTeamTicketsW.subscribe(onAllyTickets)
      enemyTeamTicketsW.subscribe(onEnemyTickets)
      startPollingZonesState()
    }
    onDetach = function() {
      localTeamTicketsW.unsubscribe(onAllyTickets)
      enemyTeamTicketsW.unsubscribe(onEnemyTickets)
      stopPollingZonesState()
    }
  }
}
