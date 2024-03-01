from "%scripts/dagui_natives.nut" import get_axis_index
from "%scripts/dagui_library.nut" import *

let { getShortcutGroupMask } = require("controls")
let enums = require("%sqStdLibs/helpers/enums.nut")
let { CONTROL_TYPE } = require("%scripts/controls/controlsConsts.nut")

let template = {
  //id - add in generation
  type = CONTROL_TYPE.SHORTCUT

  checkAssign = true
  reqInMouseAim = null
  needShowInHelp = false

  isHidden = false
  shortcutId = -1
}

function definitionFunc(shArray, shEnum) {
  foreach (_idx, shSrc in shArray) {
    //Fill required params before it will be used below
    let sh = (type(shSrc) == "string") ? { id = shSrc } : clone shSrc

    if (!("type" in sh))
      sh.type <- template.type

    if (sh.type == CONTROL_TYPE.AXIS) {
      sh.axisIndex <- get_axis_index(sh.id)
      sh.axisName <- sh.id
      sh.modifiersId <- {}
    }

    if (sh.id in shEnum)
      assert(false, $"Shortcuts: Found duplicate {sh.id}")

    if (sh.type == CONTROL_TYPE.AXIS || sh.type == CONTROL_TYPE.SHORTCUT)
      sh.checkGroup <- getShortcutGroupMask(sh.id)

    enums.addTypes(shEnum, { [sh.id] = sh }, function() {
        if (this.reqInMouseAim == null)
          this.reqInMouseAim = this.checkAssign
      },
    "id")
  }
}

return {
  template
  definitionFunc
}