//-file:plus-string
from "%scripts/dagui_natives.nut" import get_player_complaint_counts, char_ban_user
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { frnd, rnd, rnd_int } = require("dagor.random")
let { floor, abs } = require("math")
let getCaptchaCache = require("%scripts/captcha/captchaCache.nut")
let { sfpf } = require("%scripts/utils/screenUtils.nut")
let { register_command } = require("console")
let { get_charserver_time_sec } = require("chard")
let { isPlatformSteamDeck } = require("%scripts/clientState/platform.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { increaseCaptchaFailsCount, resetAllCaptchaFailsCounters, captchaFailsBlockCounter,
  captchaLastAttemptTimestamp, hasSuccessfullyTry, resetCaptchaFailsBlockCounter,
  captchFailsBanCounter, resetCaptchaFailsBanCounter, setLastAttemptTime } = require("%scripts/userstat/userstatCaptcha.nut")
let { secondsToString } = require("%scripts/time.nut")
let { userIdStr } = require("%scripts/user/myUser.nut")
let { getMaxUnitsRank } = require("%scripts/shop/shopUnitsInfo.nut")

let Rectangle = class {
  x = 0
  y = 0
  width = 0
  height = 0

  getRight = @() this.x + this.width
  getBottom = @() this.y + this.height
  getCenterX = @() this.x + this.width / 2
  getCenterY = @() this.y + this.height / 2
  getPosStr = @() $"{this.x}, {this.y}"

  function setPosFromStr(pos) {
    let posArray = pos.split(",")
    this.x = posArray[0].tointeger()
    this.y = posArray[1].tointeger()
  }

  function setSize(size) {
    this.width = size[0]
    this.height = size[1]
  }
}

let captchaImages = [
  "china_finishedresearch",
  "china_ground_finishedresearch",
  "china_heli_finishedresearch",
  "france_finishedresearch",
  "france_heli_finishedresearch",
  "france_newmodificationresearch",
  "france_heli_finishedresearch",
  "ger_boat_finishedresearch",
  "ger_boat_newmodificationresearch",
  "ger_finishedresearch"
]

const CAPTCHA_MAX_TRIES = 3
const SHOW_CAPTCHA_ITEM_ID = "show_captcha_item"
const CAPTCHA_DISPLAY_TIME_SEC = 60
const TRIES_BEFORE_TEMP_BLOCK = 6
const TRIES_BEFORE_BAN = 10
const TEMP_BLOCK_DURATION_SEC = 60
const BAN_DURATION_SEC = 86400

let function checkIsTempBlocked() {
  let hasExceedTries = captchaFailsBlockCounter.get() >= TRIES_BEFORE_TEMP_BLOCK
  if (hasExceedTries) {
    let blockTimePassed = get_charserver_time_sec() - captchaLastAttemptTimestamp.get()
    let blockTimeLeft = TEMP_BLOCK_DURATION_SEC - blockTimePassed
    if (blockTimeLeft <= 0) {
      resetCaptchaFailsBlockCounter()
      return false
    }
    else {
      showInfoMsgBox(
        loc("captcha/temp_blocked_time_left",
        { timeLeft = secondsToString(blockTimeLeft, true, true) })
      )
      return true
    }
  }
}

let function banUser() {
  let category = "BOT"
  let penalty =  "BAN"
  let comment = loc("charServer/ban/reason/BOT2")
  char_ban_user(userIdStr.value, BAN_DURATION_SEC, "", category, penalty, comment, "" , "")
}

local lastShowReason = "Captcha: there were no shows"

local CaptchaHandler = class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/captcha/captcha.blk"

  partObj = null
  captchaImage = null
  gap = 10
  maxDifference = 10
  maxTries = CAPTCHA_MAX_TRIES

  captchaData = Rectangle()
  holeData = Rectangle()
  partData = Rectangle()

  callbackSuccess = null
  callbackClose = null

  closeCountdown = CAPTCHA_DISPLAY_TIME_SEC

  function initScreen() {
    this.gap = sfpf(this.gap)
    this.maxDifference = sfpf(this.maxDifference)
    this.scene.findObject("captcha_timer").setUserData(this)
    this.initCaptcha()
    sendBqEvent("CLIENT_POPUP_1", "captcha.open", { reason = lastShowReason })
  }

  function initCaptcha() {
    this.initData()
    this.resetCaptcha()
  }

  function resetCaptcha() {
    this.initHole()
    this.setRandomCaptchaImage()
    this.initDraggablePart()
    this.scene.findObject("btn_check").enable(false)
    this.closeCountdown = CAPTCHA_DISPLAY_TIME_SEC
    this.updateCountdownMsg()
  }

  function initData() {
    this.captchaData.setSize(this.scene.findObject("captcha_image").getSize())
    this.holeData.setSize(this.scene.findObject("hole").getSize())
    this.partData.width = this.holeData.width
    this.partData.height = this.holeData.height
  }

  function setRandomCaptchaImage() {
    this.captchaImage = $"#ui/images/researches/{captchaImages[rnd() % captchaImages.len()]}?P1"
    this.scene.findObject("captcha_image")["background-image"] = this.captchaImage
  }

  function initHole() {
    this.holeData.x = rnd_int(this.gap, this.captchaData.width - this.holeData.width - this.gap)
    this.holeData.y = rnd_int(this.gap, this.captchaData.height - this.holeData.height - this.gap)
    this.scene.findObject("hole")["pos"] = this.holeData.getPosStr()
  }

  function initDraggablePart() {
    this.partObj = this.scene.findObject("part")

    local from = 0
    local to = 0
    if(this.holeData.getCenterX() < this.captchaData.getCenterX()) {
      from = this.holeData.getRight() + this.gap
      to = this.captchaData.width - this.partData.width - this.gap
    }
    else {
      from = this.gap
      to = this.holeData.x - this.partData.width - this.gap
    }
    this.partData.x = rnd_int(from, to)

    if(this.holeData.getCenterY() < this.captchaData.getCenterY()) {
      from = this.holeData.getBottom() + this.gap
      to = this.captchaData.height - this.partData.height - this.gap
    }
    else {
      from = this.gap
      to = this.holeData.y - this.partData.height - this.gap
    }
    this.partData.y = rnd_int(from, to)
    this.partObj["pos"] = this.partData.getPosStr()

    let backgroundPositionArr = []
    backgroundPositionArr.append(floor(1000 * this.holeData.x / this.captchaData.width))
    backgroundPositionArr.append(floor(1000 * this.holeData.y / this.captchaData.height))
    backgroundPositionArr.append(floor(1000 - 1000 * this.holeData.getRight() / this.captchaData.width))
    backgroundPositionArr.append(floor(1000 - 1000 * this.holeData.getBottom() / this.captchaData.height))

    let partImage = this.scene.findObject("part_image")

    partImage["background-image"] = this.captchaImage
    partImage["background-position"] = ", ".join(backgroundPositionArr)
  }

  onMoveStart = @(_obj) this.scene.findObject("btn_check").enable(true)

  onMoveEnd = @(obj) this.partData.setPosFromStr(obj.pos)

  function onCheck(_obj) {
    let isError = abs(this.holeData.x - this.partData.x) >= this.maxDifference
      || abs(this.holeData.y - this.partData.y) >= this.maxDifference

    if(isError) {
      this.maxTries--

      let cache = getCaptchaCache()
      cache.failsPerSession++
      cache.failsInRow++

      increaseCaptchaFailsCount()
      sendBqEvent("CLIENT_POPUP_1", "captcha.fail", {
        failsPerSession = cache.failsPerSession
        failsInRow = cache.failsInRow
      })

      if (captchFailsBanCounter.value >= TRIES_BEFORE_BAN) {
        resetCaptchaFailsBanCounter()
        return banUser()
      }

      if(checkIsTempBlocked() || this.maxTries == 0)
        return this.invokeCloseCallback()

      this.scene.findObject("captcha_task").setValue(loc("captcha/retry", { tries = this.maxTries }))
      this.resetCaptcha()
      return
    }
    this.invokeSuccessCallback()
  }

  function onClose(_obj) {
    this.invokeCloseCallback()
  }

  function invokeCloseCallback() {
    if(this.callbackClose != null)
      this.callbackClose()
    this.goBack()
  }

  function invokeSuccessCallback() {
    let cache = getCaptchaCache()
    sendBqEvent("CLIENT_POPUP_1", "captcha.success", { attemptNumber = CAPTCHA_MAX_TRIES - this.maxTries + 1 })
    cache.failsInRow = 0
    resetAllCaptchaFailsCounters()
    if(this.callbackSuccess != null)
      this.callbackSuccess()
    this.goBack()
  }

  function onCaptchaTimer(_d, t) {
    this.closeCountdown -= t
    if (this.closeCountdown <= 0)
      this.invokeCloseCallback()
    else
      this.updateCountdownMsg()
  }

  function updateCountdownMsg() {
    this.scene.findObject("captcha_countdown_msg").setValue(
      "".concat(
        loc("multiplayer/timeLeft"),
        loc("ui/colon"),
        loc("ui/space"),
        this.closeCountdown,
        loc("ui/space"),
        loc("debriefing/timeSec")
      )
    )
  }
}

gui_handlers.CaptchaHandler <- CaptchaHandler

let maxTimeBetweenShowCaptcha = 14400
let minComplaintsCountForShowCaptcha = 5
let minVehicleRankForShowCaptcha = 2

let function tryOpenCaptchaHandler(callbackSuccess = null, callbackClose = null) {
  let isCaptchaNotAllowed = !is_platform_pc || isPlatformSteamDeck
    || (!hasFeature("CaptchaAllowed") && ::ItemsManager.getInventoryItemById(SHOW_CAPTCHA_ITEM_ID) == null)
    ||  getMaxUnitsRank() < minVehicleRankForShowCaptcha
  if (isCaptchaNotAllowed) {
    if(callbackSuccess != null)
      callbackSuccess()
    return
  }

  if (checkIsTempBlocked())
    return callbackClose?()

  let cache = getCaptchaCache()
  cache.countTries++

  if(hasSuccessfullyTry.get()) {
    if (get_charserver_time_sec() - captchaLastAttemptTimestamp.get() >= maxTimeBetweenShowCaptcha) {
      handlersManager.loadHandler(CaptchaHandler, { callbackSuccess, callbackClose })
      lastShowReason = $"Captcha: time between show captcha > {maxTimeBetweenShowCaptcha} c"
      return
    }
    callbackSuccess?()
    return
  }

  if(cache.countTries > 6) {
    handlersManager.loadHandler(CaptchaHandler, { callbackSuccess, callbackClose })
    lastShowReason = "Captcha: number of unsuccessful attempts > 6"
    return
  }

  let countComplaints = get_player_complaint_counts()?.complaint_count_other["BOT"] ?? 0
  if(countComplaints >= minComplaintsCountForShowCaptcha) {
    handlersManager.loadHandler(CaptchaHandler, { callbackSuccess, callbackClose })
    lastShowReason = $"Captcha: number of complaints about the use of bots > {minComplaintsCountForShowCaptcha}"
    return
  }

  if(cache.hasRndTry || (frnd() < 0.5)) {
    handlersManager.loadHandler(CaptchaHandler, { callbackSuccess, callbackClose })
    lastShowReason = "Captcha: mandatory random showing"
    cache.hasRndTry = true
    setLastAttemptTime(get_charserver_time_sec() - maxTimeBetweenShowCaptcha) // to be sure captcha will shown after client restart

    return
  }

  callbackSuccess?()
}

//









return tryOpenCaptchaHandler