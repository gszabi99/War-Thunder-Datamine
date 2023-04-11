//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let shortcutsListModule = require("%scripts/controls/shortcutsList/shortcutsList.nut")

let getShortcutById = @(shortcutId) shortcutsListModule?[shortcutId]

let function isAxisBoundToMouse(shortcutId) {
  return ::is_axis_mapped_on_mouse(shortcutId)
}

let function getBitArrayAxisIdByShortcutId(joyParams, shortcutId) {
  let shortcutData = getShortcutById(shortcutId)
  let axis = joyParams.getAxis(shortcutData?.axisIndex ?? -1)
  if (axis.axisId < 0)
    if (isAxisBoundToMouse(shortcutId))
      return ::get_mouse_axis(shortcutId, null, joyParams)
    else
      return GAMEPAD_AXIS.NOT_AXIS

  return 1 << axis.axisId
}

let function getComplexAxesId(shortcutComponents) {
  let joyParams = ::JoystickParams()
  joyParams.setFrom(::joystick_get_cur_settings())
  local axesId = 0
  foreach (shortcutId in shortcutComponents)
    axesId = axesId | getBitArrayAxisIdByShortcutId(joyParams, shortcutId)

  return axesId
}

/**
 * Checks wether all components assigned to one stick or mouse move.
 * @shortcutComponents - array of components, contains shortcutIds
 * @return - bool
*/
let isComponentsAssignedToSingleInputItem = @(axesId)
  axesId == GAMEPAD_AXIS.RIGHT_STICK
  || axesId == GAMEPAD_AXIS.LEFT_STICK
  || axesId == MOUSE_AXIS.MOUSE_MOVE

return {
  getShortcutById
  isAxisBoundToMouse
  getComplexAxesId
  isComponentsAssignedToSingleInputItem
}
