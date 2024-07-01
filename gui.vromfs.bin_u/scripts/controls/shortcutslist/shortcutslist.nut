from "%scripts/dagui_library.nut" import *

let shortcutsEnumData = require("%scripts/controls/shortcutsList/shortcutsEnumData.nut")

let shortcutsModulesList = require("%scripts/controls/shortcutsList/shortcutsModulesList.nut")

let shortcutsList = {
  types = []
  template = shortcutsEnumData.template
  addShortcuts = shortcutsEnumData.definitionFunc
}

function updateShortcutsList(value) {
  foreach (list in value)
    shortcutsList.addShortcuts(list, shortcutsList)
}

updateShortcutsList(shortcutsModulesList.value)

shortcutsModulesList.subscribe(@(v) updateShortcutsList(v))

return shortcutsList