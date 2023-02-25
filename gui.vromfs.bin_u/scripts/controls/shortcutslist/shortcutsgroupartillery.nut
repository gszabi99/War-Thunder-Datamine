//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

return [
//-------------------------------------------------------
  {
    id = "ID_COMMON_ARTILLERY_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ID_SHOOT_ARTILLERY"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_CHANGE_ARTILLERY_TARGETING_MODE"
    checkAssign = false
  }
  {
    id = "ID_ARTILLERY_CANCEL"
    checkAssign = false
  }
]