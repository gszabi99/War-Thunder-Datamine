from "%scripts/dagui_library.nut" import *

let captchaCache = persist("captchaCache", @() {})
let { userIdStr } = require("%scripts/user/myUser.nut")

let userCache = {
  countTries = 0
  hasSuccessfullyTry = false
  lastTryTime = 0
  failsPerSession = 0
  failsInRow = 0
}

let function getCaptchaCache() {
  let userId = userIdStr.value
  if(captchaCache?[userId] == null)
    captchaCache[userId] <- clone userCache
  return captchaCache[userId]
}

return getCaptchaCache