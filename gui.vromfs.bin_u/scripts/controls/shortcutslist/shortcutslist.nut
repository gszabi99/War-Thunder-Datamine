import "%scripts/controls/shortcutsList/shortcutTemplate.nut" as shortcutTemplate
from "%scripts/controls/controlsConsts.nut" import CONTROL_TYPE
from "controls" import getShortcutGroupMask
from "%scripts/dagui_natives.nut" import get_axis_index
from "%scripts/dagui_library.nut" import *
from "types" import String

let shortcutsListTypes = {
  types = []
}

function addShortcuts(shArray) {
  foreach (shSrc in shArray) {
    
    let sh = shortcutTemplate.__merge((shSrc instanceof String) ? { id = shSrc } : shSrc)
    sh.reqInMouseAim = sh.reqInMouseAim ?? sh.checkAssign
    let { id } = sh
    if (id in shortcutsListTypes) {
      assert(false, $"Shortcuts: Found duplicate {id}")
      continue
    }

    if (sh.type == CONTROL_TYPE.AXIS) {
      sh.axisIndex <- get_axis_index(id)
      sh.axisName <- id
      sh.modifiersId <- {}
      sh.checkGroup <- getShortcutGroupMask(id)
    }
    else if (sh.type == CONTROL_TYPE.SHORTCUT)
      sh.checkGroup <- getShortcutGroupMask(id)

    shortcutsListTypes.types.append(sh)
    shortcutsListTypes[id] <- sh
  }
}

function addShortcutModules(modules) {
  foreach (list in modules)
    addShortcuts(list)
}

return {
  shortcutsList = shortcutsListTypes.types
  getShortcutById = @(shortcutId) shortcutsListTypes?[shortcutId]
  addShortcutModules
}