from "%scripts/dagui_library.nut" import *

let { isPlatformSony, isPlatformXboxOne,
  isPlatformPC } = require("%scripts/clientState/platform.nut")
let psnUser = require("sony.user")

let function isUnlockVisibleOnCurPlatform(unlockBlk) {
  if (unlockBlk?.psn && !isPlatformSony)
    return false
  if (unlockBlk?.ps_plus && !psnUser.hasPremium())
    return false
  if (unlockBlk?.hide_for_platform == target_platform)
    return false

  let unlockType = ::get_unlock_type(unlockBlk?.type ?? "")
  if (unlockType == UNLOCKABLE_TROPHY_PSN && !isPlatformSony)
    return false
  if (unlockType == UNLOCKABLE_TROPHY_XBOXONE && !isPlatformXboxOne)
    return false
  if (unlockType == UNLOCKABLE_TROPHY_STEAM && !isPlatformPC)
    return false
  return true
}

return {
  isUnlockVisibleOnCurPlatform
}