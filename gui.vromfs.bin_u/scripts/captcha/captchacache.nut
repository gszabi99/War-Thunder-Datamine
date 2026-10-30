from "%scripts/user/profileStates.nut" import userIdStr
from "%scripts/dagui_library.nut" import *

let captchaCache = mkHardPersist("captcha.captchaCache")("captchaCache", {})

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