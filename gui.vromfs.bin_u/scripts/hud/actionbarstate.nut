from "%scripts/dagui_library.nut" import *

let { FRP_INITIAL } = require("frp")
let { getActionBarItems } = require("hudActionBar")

let actionBar = Watched([])
let isVisualWeaponSelectorToggle = Watched(false)

let skipedParameters = {
  aimReady = true
  cooldown = true
  blockedCooldown = true
}

function secondActionIsEqual(abInfoA, abInfoB) {
  if (abInfoA == null || abInfoB == null)
    return false

  let aLen = abInfoB.len()
  let bLen = abInfoA.len()
  if (aLen != bLen)
    return false
  for (local i = 0; i < aLen; i++) {
    let a = abInfoA[i]
    let b = abInfoB[i]
    if (type(a) != type(b))
      return false
    if (type(a) != "table")
      return a == b

    foreach (k, v in a)
      if ((k not in skipedParameters) && v != b?[k])
        return false
  }
  return true
}

function actionIsEqual(a, b) {
  if (type(a) != type(b))
    return false
  if (type(a) != "table")
    return a == b

  foreach (k, v in a) {
    if (k == "additionalBulletInfo") {
      if (!secondActionIsEqual(v, b?[k]))
        return false
      continue
    }

    if ((k not in skipedParameters) && v != b?[k])
      return false
  }
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
  isVisualWeaponSelectorToggle
}
