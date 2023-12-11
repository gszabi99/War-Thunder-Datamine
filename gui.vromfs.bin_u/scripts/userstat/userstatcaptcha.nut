from "%scripts/dagui_library.nut" import *
let userstat = require("userstat")
let { APP_ID } = require("app")
let { userIdInt64 } = require("%scripts/user/myUser.nut")
let { userstatStats, refreshUserstatStats } = require("%scripts/userstat/userstat.nut")
let { get_charserver_time_sec } = require("chard")
let { register_command } = require("console")

enum CaptchaUserstatName {
  FAILS_BLOCK_COUNTER    = "val_captcha_fail_count"
  FAILS_BAN_COUNTER      = "val_captcha_fail_ban_count"
  LAST_ATTEMPT_TIMESTAMP = "val_captcha_pass_timestamp"
}

let captchaFailsBlockCounter = Watched(0)
let captchFailsBanCounter = Watched(0)
let captchaLastAttemptTimestamp = Watched(0)

let hasSuccessfullyTry = Computed(@()
  captchaFailsBlockCounter.get() == 0
  && captchFailsBanCounter.get() == 0
  && captchaLastAttemptTimestamp.get() != 0
)

userstatStats.subscribe(function(d) {
  let failsBlock = d?.stats["global"].stats[CaptchaUserstatName.FAILS_BLOCK_COUNTER] ?? 0
  let time = d?.stats["global"].stats[CaptchaUserstatName.LAST_ATTEMPT_TIMESTAMP] ?? 0
  let failsBan = d?.stats["global"].stats[CaptchaUserstatName.FAILS_BAN_COUNTER] ?? 0

  captchaFailsBlockCounter.set(failsBlock)
  captchFailsBanCounter.set(failsBan)
  captchaLastAttemptTimestamp.set(time)
})

let function updateCaptchaUserstats(params) {
  let { blockCounter = null, banCounter = null time = get_charserver_time_sec() } = params
  captchaLastAttemptTimestamp.set(time)

  let reqData = {
    [CaptchaUserstatName.LAST_ATTEMPT_TIMESTAMP] = { ["$set"] = time },
    ["$mode"] = "stats"
  }

  if (blockCounter != null) {
    reqData[CaptchaUserstatName.FAILS_BLOCK_COUNTER] <- { ["$set"] = blockCounter }
    captchaFailsBlockCounter.set(blockCounter)
  }
  if (banCounter != null) {
    reqData[CaptchaUserstatName.FAILS_BAN_COUNTER] <- { ["$set"] = banCounter }
    captchFailsBanCounter.set(banCounter)
  }

  let userstatRequestData = {
    add_token = true
    headers = { appid = APP_ID, userId = userIdInt64.value }
    action = "ClnChangeStats"
    data = reqData
  }
  userstat.request(userstatRequestData, @(_) refreshUserstatStats())
 }

let function increaseCaptchaFailsCount() {
  updateCaptchaUserstats({
    blockCounter = captchaFailsBlockCounter.get() + 1
    banCounter = captchFailsBanCounter.get() + 1
  })
}

let function resetAllCaptchaFailsCounters() {
  updateCaptchaUserstats({
    blockCounter = 0
    banCounter = 0
  })
}

let function resetCaptchaFailsBlockCounter() {
  updateCaptchaUserstats({
    blockCounter = 0
    time = 0 // resets time after block period passed to properly compute hasSuccessfullyTry
  })
}

let function resetCaptchaFailsBanCounter() {
  updateCaptchaUserstats({
    banCounter = 0
    time = 0 // resets time on ban to properly compute hasSuccessfullyTry
  })
}

let function setLastAttemptTime(time) {
  updateCaptchaUserstats({ time })
}

//


















 return {
  captchaFailsBlockCounter,
  resetAllCaptchaFailsCounters,
  increaseCaptchaFailsCount,
  captchaLastAttemptTimestamp,
  hasSuccessfullyTry,
  resetCaptchaFailsBlockCounter,
  captchFailsBanCounter,
  resetCaptchaFailsBanCounter,
  setLastAttemptTime
 }