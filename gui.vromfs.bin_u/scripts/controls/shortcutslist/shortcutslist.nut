from "%scripts/dagui_library.nut" import *

let shortcutsEnumData = require("%scripts/controls/shortcutsList/shortcutsEnumData.nut")

let shortcutsModulesList = require("%scripts/controls/shortcutsList/shortcutsModulesList.nut")

let shortcutsListTypes = {
  types = []
  template = shortcutsEnumData.template
  addShortcuts = shortcutsEnumData.definitionFunc
}

function updateShortcutsList(value) {
  foreach (list in value)
    shortcutsListTypes.addShortcuts(list, shortcutsListTypes)
}

updateShortcutsList(shortcutsModulesList.get())

shortcutsModulesList.subscribe(@(v) updateShortcutsList(v))

return {
  shortcutsList = shortcutsListTypes.types
  getShortcutById = @(shortcutId) shortcutsListTypes?[shortcutId]
}