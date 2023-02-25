//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { subscribe } = require("eventbus")
let emptySceneWithDarg = require("%scripts/wndLib/emptySceneWithDarg.nut")

subscribe("hideMainMenuUi", function(params) {
  if (!::isInMenu())
    return

  if (params.hide)
    emptySceneWithDarg({})
  else
    ::gui_start_mainmenu()
})
