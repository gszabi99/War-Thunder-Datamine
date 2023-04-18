//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let elemViewType = require("%sqDagui/elemUpdater/elemViewType.nut")
let time = require("%scripts/time.nut")

elemViewType.addTypes({
  COPYRIGHT_TEXT = {
    updateView = function(obj, _params) {
      let copyRight = obj.findObject("copyright_text")
      copyRight.setValue(loc("mainmenu/legal_text",  { currentYear = time.getCurrentYear() }))
    }
  }
})