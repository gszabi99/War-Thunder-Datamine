//checked for plus_string
from "%scripts/dagui_library.nut" import *
let { CONTROL_TYPE } = require("%scripts/controls/controlsConsts.nut")

return [{
  id = "helpers_mode"
  type = CONTROL_TYPE.LISTBOX
  optionType = ::USEROPT_HELPERS_MODE
  onChangeValue = "onOptionsFilter"
  isFilterObj = true
}]