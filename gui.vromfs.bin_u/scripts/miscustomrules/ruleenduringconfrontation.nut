from "%scripts/dagui_library.nut" import *
let { registerMissionRules } = require("%scripts/misCustomRules/missionCustomState.nut")
let RuleBase = require("%scripts/misCustomRules/ruleBase.nut")

registerMissionRules("EnduringConfrontation", class (RuleBase) {
  function isStayOnRespScreen() {
    return false
  }
})