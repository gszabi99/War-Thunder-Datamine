//checked for plus_string
from "%scripts/dagui_library.nut" import *


let { tryOpenNextTutorialHandler } = require("%scripts/tutorials/nextTutorialHandler.nut")
let { checkTutorialsList } = require("%scripts/tutorials/tutorialsData.nut")
let { getShowedUnit } = require("%scripts/slotbar/playerCurUnit.nut")

let function checkTutorialOnStart() {
  let unit = getShowedUnit()
  foreach (tutorial in checkTutorialsList) {
    if (!(tutorial?.isNeedAskInMainmenu ?? false))
      continue

    if (("requiresFeature" in tutorial) && !hasFeature(tutorial.requiresFeature))
      continue

    if (tutorial.suitableForUnit(unit) && tryOpenNextTutorialHandler(tutorial.id))
      return
  }
}

return {
  checkTutorialOnStart
}