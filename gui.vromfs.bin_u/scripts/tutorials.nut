from "console" import register_command
from "%scripts/dagui_library.nut" import *

let { tryOpenNextTutorialHandler } = require("%scripts/tutorials/nextTutorialHandler.nut")
let { checkTutorialsList } = require("%scripts/tutorials/tutorialsData.nut")
let { getShowedUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { needShowTutorial, reqFirstCountryChoice } = require("%scripts/user/newbieTutorialDisplay.nut")

let hasRunTutorialDialog = @() needShowTutorial("unitTypeChoice", 1) || !reqFirstCountryChoice()

function checkTutorialOnStart() {
  let unit = getShowedUnit()
  let needAutoStartTutorial = !hasRunTutorialDialog()
  foreach (tutorial in checkTutorialsList) {
    let { id, isNeedAskInMainmenu = false, requiresFeature = null } = tutorial
    if (!isNeedAskInMainmenu)
      continue

    if (requiresFeature != null && !hasFeature(requiresFeature))
      continue

    if (tutorial.suitableForUnit(unit) && tryOpenNextTutorialHandler(id, true, needAutoStartTutorial))
      return
  }
}

register_command(@() checkTutorialOnStart(), "debug.checkTutorialOnStart")

return {
  checkTutorialOnStart
  hasRunTutorialDialog
}
