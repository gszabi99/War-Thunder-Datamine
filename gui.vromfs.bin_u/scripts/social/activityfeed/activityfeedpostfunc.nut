local u = require("sqStdLibs/helpers/u.nut")
local { isPlatformSony } = require("scripts/clientState/platform.nut")

local psnPostFunc = function(config, feed) {
  if (isPlatformSony && ::has_feature("ActivityFeedPs4"))
    require("scripts/social/activityFeed/ps4PostFunc.nut")(config, feed)
}

local facebookPostFunc = function(config, feed) {
  if (::facebook_is_logged_in() && ::has_feature("FacebookWallPost"))
    require("scripts/social/activityFeed/facebookPostFunc.nut")(config, feed)
}

return function(_config, _customFeedParams = {}, reciever = bit_activity.NONE) {
  if (u.isEmpty(_config) || u.isEmpty(_customFeedParams))
    return

  local config = u.copy(_config)
  local customFeedParams = u.copy(_customFeedParams)

  if (reciever & bit_activity.PS4_ACTIVITY_FEED)
    psnPostFunc(config, customFeedParams)

  if (reciever & bit_activity.FACEBOOK)
    facebookPostFunc(config, customFeedParams)
}