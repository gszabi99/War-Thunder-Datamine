from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv
from "auth_wt" import get_player_tags
from "%scripts/dagui_library.nut" import *
from "types" import String

let userName = mkWatched(persist, "userName", "")
let userIdStr = mkWatched(persist, "userIdStr", "-1")
let userIdInt64 = Computed(@() userIdStr.get().tointeger())

let havePlayerTag = @(tag) get_player_tags().indexof(tag) != null

function haveAnyPlayerTag(tags) {
  foreach (tag in tags)
    if (havePlayerTag(tag))
      return true
  return false
}

let isGuestLogin = Watched(havePlayerTag("guestlogin"))
let updateGuestLogin = @() isGuestLogin.set(havePlayerTag("guestlogin"))

function isMyUserId(userId) {
  if (userId instanceof String)
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
  haveAnyPlayerTag
  isMyUserId
}