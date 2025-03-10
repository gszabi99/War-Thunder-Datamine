from "%scripts/dagui_library.nut" import *


let enums = require("%sqStdLibs/helpers/enums.nut")

let g_hud_hint_types = {
  types = []

  template = {
    nestId = ""
    hintStyle = ""
    isReplaceableByPriority = false

    isReplaceable = @(newHint, newEventData, oldHint, oldEventData)
      !this.isReplaceableByPriority || newHint.getPriority(newEventData) >= oldHint.getPriority(oldEventData)
    isSameReplaceGroup = function (hint1, hint2) { return hint1 == hint2 }
  }
}


enums.addTypes(g_hud_hint_types, {
  COMMON = {
    nestId = "common_priority_hints"
    hintStyle = "hudHintCommon"
  }

  MISSION_STANDARD = {
    nestId = "mission_hints"
    hintStyle = "hudHintCommon"
    isReplaceableByPriority = true
    isSameReplaceGroup = function (hint1, hint2) {
      return hint1.hintType == hint2.hintType
    }
  }

  MISSION_ACTION_HINTS = {
    nestId = "mission_action_hints"
    hintStyle = "hudHintAction"
    isReplaceableByPriority = true
  }

  WARNING_HINTS = {
    nestId = "warning_hints"
    hintStyle = "warningHints"
    isReplaceableByPriority = true
  }

  MISSION_TUTORIAL = { 
    nestId = "tutorial_hints"
    hintStyle = "hudHintCommon"
    isReplaceableByPriority = true
  }

  MISSION_BOTTOM = {
    nestId = "minor_priority_hints"
    hintStyle = "hudMinor"
    isReplaceableByPriority = true
  }

  REPAIR = {
    nestId = "mission_hints"
    hintStyle = "hudHintCommon"
  }

  MINOR = {
    nestId = "minor_priority_hints"
    hintStyle = "hudMinor"
  }

  ACTIONBAR = {
    nestId = "actionbar_hints"
    hintStyle = "hudMinor"
  }
})

return {
  g_hud_hint_types
}