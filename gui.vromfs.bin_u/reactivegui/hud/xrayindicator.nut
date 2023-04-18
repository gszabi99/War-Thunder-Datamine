from "%rGui/globals/ui_library.nut" import *

let { dmgIndicatorStates } = require("%rGui/hudState.nut")

let xrayIndicator = @() {
  watch = dmgIndicatorStates
  size = flex()
  children = (dmgIndicatorStates.value?.isVisible ?? true)
    ? {
        rendObj = ROBJ_XRAYDOLL
        rotateWithCamera = true
        pos = dmgIndicatorStates.value?.pos ?? [0, 0]
        size = dmgIndicatorStates.value.size
      }
    : null
}

return xrayIndicator