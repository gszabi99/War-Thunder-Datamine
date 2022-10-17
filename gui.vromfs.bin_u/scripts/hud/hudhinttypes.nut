from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let enums = require("%sqStdLibs/helpers/enums.nut")
::g_hud_hint_types <- {
  types = []
}

::g_hud_hint_types.template <- {
  nestId = ""
  hintStyle = ""
  isReplaceableByPriority = false

  isReplaceable = @(newHint, newEventData, oldHint, oldEventData)
    !isReplaceableByPriority || newHint.getPriority(newEventData) >= oldHint.getPriority(oldEventData)
  isSameReplaceGroup = function (hint1, hint2) { return hint1 == hint2 }
}

enums.addTypesByGlobalName("g_hud_hint_types", {
  COMMON = {
    nestId = "common_priority_hints"
    hintStyle = "hudHintCommon"
  }

  MISSION_STANDARD = {
    nestId = "mission_hints"
    hintStyle = "hudHintCommon"
    isReplaceableByPriority = true
    isSameReplaceGroup = function (hint1, hint2)
    {
      return hint1.hintType == hint2.hintType
    }
  }

  MISSION_TUTORIAL = { //lower than standard hint, so can override with other mp hints.
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
