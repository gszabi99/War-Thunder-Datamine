from "%scripts/dagui_library.nut" import *

let { get_player_tags } = require("auth_wt")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")

let userName = mkWatched(persist, "userName", "")
let userIdStr = mkWatched(persist, "userIdStr", "-1")
let userIdInt64 = Computed(@() userIdStr.get().tointeger())

let havePlayerTag = @(tag) get_player_tags().indexof(tag) != null

let isGuestLogin = Watched(havePlayerTag("guestlogin"))
let updateGuestLogin = @() isGuestLogin(havePlayerTag("guestlogin"))

function isMyUserId(userId) {
  if (type(userId) == "string")
    return userId == userIdStr.get()
  return userId == userIdInt64.get()
}

addListenersWithoutEnv({
  AuthorizeComplete = @(_) updateGuestLogin()
})

return {
  userName
  userIdStr
  userIdInt64
  isGuestLogin
  havePlayerTag
  isMyUserId
}