//checked for plus_string
from "%scripts/dagui_library.nut" import *

let u = require("%sqStdLibs/helpers/u.nut")
let { isPlatformPS4 } = require("%scripts/clientState/platform.nut")
let psnPostFuncSrc = require("%scripts/social/activityFeed/ps4PostFunc.nut")

let psnPostFunc = function(config, feed) {
  if (isPlatformPS4 && hasFeature("ActivityFeedPs4"))
    psnPostFuncSrc(config, feed)
}

return function(v_config, v_customFeedParams = {}, receiver = bit_activity.NONE) {
  if (u.isEmpty(v_config) || u.isEmpty(v_customFeedParams))
    return

  let config = u.copy(v_config)
  let customFeedParams = u.copy(v_customFeedParams)

  if (receiver & bit_activity.PS4_ACTIVITY_FEED)
    psnPostFunc(config, customFeedParams)
}
