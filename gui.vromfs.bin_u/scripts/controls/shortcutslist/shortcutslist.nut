local shortcutsEnumData = require("scripts/controls/shortcutsList/shortcutsEnumData.nut")

local shortcutsModulesList = require("scripts/controls/shortcutsList/shortcutsModulesList.nut")

local shortcutsList = {
  types = []
  template = shortcutsEnumData.template
  addShortcuts = shortcutsEnumData.definitionFunc
}

foreach (list in shortcutsModulesList.value)
  shortcutsList.addShortcuts(list, shortcutsList)

return shortcutsList