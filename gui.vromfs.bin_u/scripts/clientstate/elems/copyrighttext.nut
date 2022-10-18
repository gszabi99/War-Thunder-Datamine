let elemViewType = require("%sqDagui/elemUpdater/elemViewType.nut")
let time = require("%scripts/time.nut")

elemViewType.addTypes({
  COPYRIGHT_TEXT = {
    updateView = function(obj, params) {
      let copyRight = obj.findObject("copyright_text")
      copyRight.setValue(::loc("mainmenu/legal_text",  { currentYear = time.getCurrentYear() }))
    }
  }
})