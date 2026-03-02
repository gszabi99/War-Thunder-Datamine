from "%scripts/dagui_natives.nut" import get_axis_index
from "%scripts/dagui_library.nut" import *
let shortcutTemplate = require("%scripts/controls/shortcutsList/shortcutTemplate.nut")
let shortcutsModulesList = require("%scripts/controls/shortcutsList/shortcutsModulesList.nut")
let { getShortcutGroupMask } = require("controls")
let { CONTROL_TYPE } = require("%scripts/controls/controlsConsts.nut")

let shortcutsListTypes = {
  types = []
}

function addShortcuts(shArray) {
  foreach (shSrc in shArray) {
    
    let sh = shortcutTemplate.__merge((type(shSrc) == "string") ? { id = shSrc } : shSrc)
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

function updateShortcutsList(value) {
  foreach (list in value)
    addShortcuts(list)
}

updateShortcutsList(shortcutsModulesList.get())

shortcutsModulesList.subscribe(@(v) updateShortcutsList(v))

return {
  shortcutsList = shortcutsListTypes.types
  getShortcutById = @(shortcutId) shortcutsListTypes?[shortcutId]
}