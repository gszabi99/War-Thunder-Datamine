local shortcutsEnumData = require("scripts/controls/shortcutsList/shortcutsEnumData.nut")

local shortcutsModulesList = require("scripts/controls/shortcutsList/shortcutsModulesList.nut")

local shortcutsList = {
  types = []
  template = shortcutsEnumData.template
  addShortcuts = shortcutsEnumData.definitionFunc
}

local function updateShortcutsList(value) {
  foreach (list in value)
    shortcutsList.addShortcuts(list, shortcutsList)
}

updateShortcutsList(shortcutsModulesList.value)

shortcutsModulesList.subscribe(@(v) updateShortcutsList(v))

return shortcutsList