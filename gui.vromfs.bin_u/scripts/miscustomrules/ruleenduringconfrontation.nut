from "%scripts/misCustomRules/missionCustomState.nut" import registerMissionRules
from "%scripts/dagui_library.nut" import *

let RuleBase = require("%scripts/misCustomRules/ruleBase.nut")

registerMissionRules("EnduringConfrontation", class (RuleBase) {
  function isStayOnRespScreen() {
    return false
  }
})