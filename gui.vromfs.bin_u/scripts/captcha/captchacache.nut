
//-file:plus-string
from "%scripts/dagui_library.nut" import *

let captchaCache = persist("captchaCache", @() {})

let userCache = {
  countTries = 0
  hasSuccessfullyTry = false
  lastTryTime = 0
}

let function getCaptchaCache() {
  let userId = ::my_user_id_str
  if(captchaCache?[userId] == null)
    captchaCache[userId] <- clone userCache
  return captchaCache[userId]
}

return getCaptchaCache