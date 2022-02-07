local elemViewType = require("sqDagui/elemUpdater/elemViewType.nut")
local time = require("scripts/time.nut")

elemViewType.addTypes({
  COPYRIGHT_TEXT = {
    updateView = function(obj, params) {
      local copyRight = obj.findObject("copyright_text")
      copyRight.setValue(::loc("mainmenu/legal_text",  { currentYear = time.getCurrentYear() }))
    }
  }
})