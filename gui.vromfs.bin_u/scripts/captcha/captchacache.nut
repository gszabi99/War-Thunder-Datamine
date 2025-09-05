from "%scripts/dagui_library.nut" import *

let captchaCache = persist("captchaCache", @() {})
let { userIdStr } = require("%scripts/user/profileStates.nut")

let userCache = {
  countTries = 0
  failsPerSession = 0
  failsInRow = 0
  hasRndTry = false
}

function getCaptchaCache() {
  let userId = userIdStr.get()
  if(captchaCache?[userId] == null)
    captchaCache[userId] <- clone userCache
  return captchaCache[userId]
}

return getCaptchaCache