local shortcutsEnumData = require("scripts/controls/shortcutsList/shortcutsEnumData.nut")

local shGroupAxis = require("scripts/controls/shortcutsList/shortcutsGroupAxis.nut")

local shortcutsAxis = {
  types = []
  template = shortcutsEnumData.template
  addShortcuts = shortcutsEnumData.definitionFunc
}

shortcutsAxis.addShortcuts(shGroupAxis, shortcutsAxis)

return shortcutsAxis