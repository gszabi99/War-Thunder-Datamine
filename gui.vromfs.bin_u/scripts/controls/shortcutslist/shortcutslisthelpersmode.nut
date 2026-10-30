from "%scripts/controls/controlsConsts.nut" import CONTROL_TYPE
from "%scripts/options/optionsExtNames.nut" import USEROPT_HELPERS_MODE
from "%scripts/dagui_library.nut" import *

return [{
  id = "helpers_mode"
  type = CONTROL_TYPE.LISTBOX
  optionType = USEROPT_HELPERS_MODE
  onChangeValue = "onOptionsFilter"
  isFilterObj = true
}]