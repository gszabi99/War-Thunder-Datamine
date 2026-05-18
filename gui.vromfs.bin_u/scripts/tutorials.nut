from "%scripts/dagui_library.nut" import *

let { tryOpenNextTutorialHandler } = require("%scripts/tutorials/nextTutorialHandler.nut")
let { checkTutorialsList } = require("%scripts/tutorials/tutorialsData.nut")
let { getShowedUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { register_command } = require("console")
let { needShowTutorial, reqFirstCountryChoice, isTutorialBeforeCountrySelect
} = require("%scripts/user/newbieTutorialDisplay.nut")




let hasRunTutorialDialog = @() !isTutorialBeforeCountrySelect()
  || needShowTutorial("unitTypeChoice", 1)
  || !reqFirstCountryChoice()

function checkTutorialOnStart() {
  let unit = getShowedUnit()
  foreach (tutorial in checkTutorialsList) {
    let { id, isNeedAskInMainmenu = false, requiresFeature = null } = tutorial
    if (!isNeedAskInMainmenu)
      continue

    if (requiresFeature != null && !hasFeature(requiresFeature))
      continue

    let hasDialog = hasRunTutorialDialog()
    if (tutorial.suitableForUnit(unit) && tryOpenNextTutorialHandler(id, true, hasDialog))
      return
  }
}

register_command(@() checkTutorialOnStart(), "debug.checkTutorialOnStart")

return {
  checkTutorialOnStart
  hasRunTutorialDialog
}
