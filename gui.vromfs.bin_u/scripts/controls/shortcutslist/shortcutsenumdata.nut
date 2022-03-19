local enums = require("sqStdLibs/helpers/enums.nut")

local template = {
  //id - add in generation
  type = CONTROL_TYPE.SHORTCUT

  checkGroup = ctrlGroups.DEFAULT
  checkAssign = true
  reqInMouseAim = null
  needShowInHelp = false

  isHidden = false
  shortcutId = -1
}

local function definitionFunc(shArray, shEnum)
{
  foreach (idx, sh in shArray)
  {
    //Fill required params before it will be used below
    if (typeof sh == "string")
      sh = {id = sh}

    if (!("type" in sh))
      sh.type <- template.type

    if (sh.type == CONTROL_TYPE.AXIS)
    {
      sh.axisIndex <- ::get_axis_index(sh.id)
      sh.axisName <- sh.id
      sh.modifiersId <- {}
    }

    if (sh.id in shEnum)
      dagor.assertf(false, "Shortcuts: Found duplicate " + sh.id)

    enums.addTypes(shEnum, {[sh.id] = sh}, function() {
        if (reqInMouseAim == null)
          reqInMouseAim = checkAssign
      },
    "id")
  }
}

return {
  template = template
  definitionFunc = definitionFunc
}