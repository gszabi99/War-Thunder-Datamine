from "%rGui/missionState.nut" import totalDomTeam, totalDomEnabled
from "%rGui/hud/capZones/capZonesState.nut" import captureZoneStateIcons
from "%rGui/globalState.nut" import isInFlight
from "eventbus" import eventbus_subscribe
from "dagor.workcycle" import resetTimeout, clearTimer
from "%rGui/globals/ui_library.nut" import *

const TOTAL_DOMINATION_START_ANIM_ID = "totalDominationStarted"
const TOTAL_DOMINATION_MULT_ANIM_ID = "totalDominationMultChanged"

const ZONE_TIME_BONUS_ID = "zone_time_bonus"
const ZONE_TIME_BONUS_SHOW_SEC = 4

let isTotalDominationStarted = keepref(Computed(@() totalDomEnabled.get() && totalDomTeam.get() != 0
  && !captureZoneStateIcons.get()))
isTotalDominationStarted.subscribe(@(v) v ? anim_start(TOTAL_DOMINATION_START_ANIM_ID) : null )

let zoneTimeBonus = Watched(0)

function hideZoneTimeBonus() {
  zoneTimeBonus.set(0)
}

eventbus_subscribe("setMissionScore", function onZoneTimeBonus(ev) {
  if (ev?.id != ZONE_TIME_BONUS_ID || !(ev?.visible ?? false))
    return
  zoneTimeBonus.set(ev?.value ?? 0)
  resetTimeout(ZONE_TIME_BONUS_SHOW_SEC, hideZoneTimeBonus)
})

isInFlight.subscribe(function resetZoneTimeBonus(v) {
  if (v)
    return
  clearTimer(hideZoneTimeBonus)
  hideZoneTimeBonus()
})

return freeze({
  TOTAL_DOMINATION_START_ANIM_ID
  TOTAL_DOMINATION_MULT_ANIM_ID
  zoneTimeBonus
})
