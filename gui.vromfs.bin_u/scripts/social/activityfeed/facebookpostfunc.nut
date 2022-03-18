return function(config, customFeedParams) {
  if ("requireLocalization" in customFeedParams)
    foreach(name in customFeedParams.requireLocalization)
      customFeedParams[name] <- ::loc(customFeedParams[name])

  let locId = ::getTblValue("locId", config, "")
  if (locId == "")
  {
    ::dagor.debug("facebookPostActivityFeed, Not found locId in config")
    ::debugTableData(config)
    return
  }

  customFeedParams.player <- ::my_user_name
  let message = ::loc("activityFeed/" + locId, customFeedParams)
  let link = ::getTblValue("link", customFeedParams, "")
  let backgroundPost = ::getTblValue("backgroundPost", config, false)
  ::make_facebook_login_and_do((@(link, message, backgroundPost) function() {
                 if (!backgroundPost)
                  ::scene_msg_box("facebook_login", null, ::loc("facebook/uploading"), null, null)
                 ::facebook_post_link(link, message)
               })(link, message, backgroundPost), this)
}