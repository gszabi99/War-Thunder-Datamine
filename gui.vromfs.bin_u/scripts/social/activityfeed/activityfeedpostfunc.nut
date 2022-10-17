let u = require("%sqStdLibs/helpers/u.nut")
let { isPlatformPS4 } = require("%scripts/clientState/platform.nut")

let psnPostFunc = function(config, feed) {
  if (isPlatformPS4 && ::has_feature("ActivityFeedPs4"))
    require("%scripts/social/activityFeed/ps4PostFunc.nut")(config, feed)
}

let facebookPostFunc = function(config, feed) {
  if (::facebook_is_logged_in() && ::has_feature("FacebookWallPost"))
    require("%scripts/social/activityFeed/facebookPostFunc.nut")(config, feed)
}

return function(v_config, v_customFeedParams = {}, reciever = bit_activity.NONE) {
  if (u.isEmpty(v_config) || u.isEmpty(v_customFeedParams))
    return

  let config = u.copy(v_config)
  let customFeedParams = u.copy(v_customFeedParams)

  if (reciever & bit_activity.PS4_ACTIVITY_FEED)
    psnPostFunc(config, customFeedParams)

  if (reciever & bit_activity.FACEBOOK)
    facebookPostFunc(config, customFeedParams)
}
