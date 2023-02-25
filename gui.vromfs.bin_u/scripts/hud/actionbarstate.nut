//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { FRP_INITIAL } = require("frp")
let { getActionBarItems } = require("hudActionBar")

let actionBar = Watched([])

let skipedParameters = {
  aimReady = true
  cooldown = true
  blockedCooldown = true
}

let function actionIsEqual(a, b) {
  if (type(a) != type(b))
    return false
  if (type(a) != "table")
    return a == b
  foreach (k, v in a)
    if ((k not in skipedParameters) && v != b?[k])
      return false
  return true
}

let actionBarItems = keepref(Computed(function(prev) {
  if (prev == FRP_INITIAL)
    prev = []
  let cur = actionBar.value
  let res = []
  local hasChanges = prev.len() != cur.len()
  foreach (idx, action in cur) {
    let prevAction = prev?[idx]
    let isChanged = !actionIsEqual(action, prevAction)
    res.append(isChanged ? action : prevAction)
    hasChanges = hasChanges || isChanged
  }
  return hasChanges ? res : prev
}))

let updateActionBar = @() actionBar(getActionBarItems())
return {
  updateActionBar
  actionBarItems
}
