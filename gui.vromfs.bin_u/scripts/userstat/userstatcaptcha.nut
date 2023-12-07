from "%scripts/dagui_library.nut" import *
let userstat = require("userstat")
let { APP_ID } = require("app")
let { userIdInt64 } = require("%scripts/user/myUser.nut")
let { userstatStats, refreshUserstatStats } = require("%scripts/userstat/userstat.nut")
let { get_charserver_time_sec } = require("chard")
let { register_command } = require("console")

enum CaptchaUserstatName {
  FAILS_COUNT            = "val_captcha_fail_count"
  LAST_ATTEMPT_TIMESTAMP = "val_captcha_pass_timestamp"
}

let captchaFailsCount = Watched(0)
let captchaLastAttemptTimestamp = Watched(0)

let hasSuccessfullyTry = Computed(@()
  captchaFailsCount.get() == 0 && captchaLastAttemptTimestamp.get() != 0)

userstatStats.subscribe(function(d) {
  let fails = d?.stats["global"].stats[CaptchaUserstatName.FAILS_COUNT] ?? 0
  let time = d?.stats["global"].stats[CaptchaUserstatName.LAST_ATTEMPT_TIMESTAMP] ?? 0

  captchaFailsCount.set(fails)
  captchaLastAttemptTimestamp.set(time)
})

let function updateCaptchaFailsCount(val, time = null) {
  if (time == null)
    time = get_charserver_time_sec()
  captchaFailsCount.set(val)
  captchaLastAttemptTimestamp.set(time)
  let userstatRequestData = {
    add_token = true
    headers = { appid = APP_ID, userId = userIdInt64.value }
    action = "ClnChangeStats"
    data = {
      [CaptchaUserstatName.FAILS_COUNT] = { ["$set"] = val },
      [CaptchaUserstatName.LAST_ATTEMPT_TIMESTAMP] = { ["$set"] = time },
      ["$mode"] = "stats"
    }
  }
  userstat.request(userstatRequestData, @(_) refreshUserstatStats())
 }

 let function increaseCaptchaFailsCount() {
  updateCaptchaFailsCount(captchaFailsCount.get() + 1)
 }

 let function resetCaptchaFailsCount() {
  updateCaptchaFailsCount(0)
 }

//

















 return {
  captchaFailsCount,
  resetCaptchaFailsCount,
  increaseCaptchaFailsCount,
  captchaLastAttemptTimestamp,
  hasSuccessfullyTry
 }