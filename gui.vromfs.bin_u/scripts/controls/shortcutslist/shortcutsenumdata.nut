from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let enums = require("%sqStdLibs/helpers/enums.nut")

let template = {
  //id - add in generation
  type = CONTROL_TYPE.SHORTCUT

  checkGroup = ctrlGroups.DEFAULT
  checkAssign = true
  reqInMouseAim = null
  needShowInHelp = false

  isHidden = false
  shortcutId = -1
}

let function definitionFunc(shArray, shEnum)
{
  foreach (_idx, shSrc in shArray)
  {
    //Fill required params before it will be used below
    let sh = (typeof shSrc == "string") ? {id = shSrc} : clone shSrc

    if (!("type" in sh))
      sh.type <- template.type

    if (sh.type == CONTROL_TYPE.AXIS)
    {
      sh.axisIndex <- ::get_axis_index(sh.id)
      sh.axisName <- sh.id
      sh.modifiersId <- {}
    }

    if (sh.id in shEnum)
      assert(false, "Shortcuts: Found duplicate " + sh.id)

    enums.addTypes(shEnum, {[sh.id] = sh}, function() {
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