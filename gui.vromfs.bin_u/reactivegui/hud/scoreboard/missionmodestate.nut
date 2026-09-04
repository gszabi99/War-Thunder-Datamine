from "%rGui/missionState.nut" import totalDomTeam, totalDomEnabled
from "%rGui/globals/ui_library.nut" import *

const TOTAL_DOMINATION_START_ANIM_ID = "totalDominationStarted"
const TOTAL_DOMINATION_MULT_ANIM_ID = "totalDominationMultChanged"

let isTotalDominationStarted = keepref(Computed(@() totalDomEnabled.get() && totalDomTeam.get() != 0))
isTotalDominationStarted.subscribe(@(v) v ? anim_start(TOTAL_DOMINATION_START_ANIM_ID) : null )

return {
  TOTAL_DOMINATION_START_ANIM_ID
  TOTAL_DOMINATION_MULT_ANIM_ID
}
