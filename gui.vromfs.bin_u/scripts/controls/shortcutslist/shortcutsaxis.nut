from "%scripts/dagui_library.nut" import *

let shortcutsEnumData = require("%scripts/controls/shortcutsList/shortcutsEnumData.nut")

let shGroupAxis = require("%scripts/controls/shortcutsList/shortcutsGroupAxis.nut")

let shortcutsAxis = {
  types = []
  template = shortcutsEnumData.template
  addShortcuts = shortcutsEnumData.definitionFunc
}

shortcutsAxis.addShortcuts(shGroupAxis, shortcutsAxis)

return shortcutsAxis