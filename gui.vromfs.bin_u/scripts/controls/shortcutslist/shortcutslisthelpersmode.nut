from "%scripts/dagui_library.nut" import *
let { CONTROL_TYPE } = require("%scripts/controls/controlsConsts.nut")
let { USEROPT_HELPERS_MODE } = require("%scripts/options/optionsExtNames.nut")

return [{
  id = "helpers_mode"
  type = CONTROL_TYPE.LISTBOX
  optionType = USEROPT_HELPERS_MODE
  onChangeValue = "onOptionsFilter"
  isFilterObj = true
}]