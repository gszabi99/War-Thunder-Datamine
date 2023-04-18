//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let shortcutsEnumData = require("%scripts/controls/shortcutsList/shortcutsEnumData.nut")

let shGroupAxis = require("%scripts/controls/shortcutsList/shortcutsGroupAxis.nut")

let shortcutsAxis = {
  types = []
  template = shortcutsEnumData.template
  addShortcuts = shortcutsEnumData.definitionFunc
}

shortcutsAxis.addShortcuts(shGroupAxis, shortcutsAxis)

return shortcutsAxis