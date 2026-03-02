from "%scripts/dagui_library.nut" import *
let shortcutTemplate = require("%scripts/controls/shortcutsList/shortcutTemplate.nut")
let shGroupAxis = require("%scripts/controls/shortcutsList/shortcutsGroupAxis.nut")

let shortcutsAxis = {
  types = []
}

function fillShortcutsAxis() {
  foreach (shSrc in shGroupAxis) {
    
    let sh = shortcutTemplate.__merge(shSrc)
    sh.reqInMouseAim = sh.reqInMouseAim ?? sh.checkAssign

    let { id } = sh
    if (id in shortcutsAxis) {
      assert(false, $"Shortcuts: Found duplicate {id}")
      continue
    }

    shortcutsAxis.types.append(sh)
    shortcutsAxis[id] <- sh
  }
}

fillShortcutsAxis()

return shortcutsAxis