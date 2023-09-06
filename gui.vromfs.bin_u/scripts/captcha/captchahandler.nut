//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { frnd, rnd, rnd_int } = require("dagor.random")
let { floor, abs } = require("math")
let getCaptchaCache = require("%scripts/captcha/captchaCache.nut")
let { sfpf } = require("%scripts/utils/screenUtils.nut")
let { register_command } = require("console")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { get_charserver_time_sec } = require("chard")

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

local CaptchaHandler = class extends gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/captcha/captcha.blk"

  partObj = null
  captchaImage = null
  gap = 10
  maxDifference = 10
  maxTries = 3

  captchaData = Rectangle()
  holeData = Rectangle()
  partData = Rectangle()

  callbackSuccess = null
  callbackClose = null

  function initScreen() {
    this.gap = sfpf(this.gap)
    this.maxDifference = sfpf(this.maxDifference)
    this.initCaptcha()
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
      if(this.maxTries == 0)
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
    cache.hasSuccessfullyTry = true
    cache.countTries = 0
    cache.lastTryTime = get_charserver_time_sec()
    if(this.callbackSuccess != null)
      this.callbackSuccess()
    this.goBack()
  }
}

gui_handlers.CaptchaHandler <- CaptchaHandler

let maxTimeBetweenShowCaptcha = 14400
let minComplaintsCountForShowCaptcha = 5
let minVehicleRankForShowCaptcha = 2

let getMaxUnitsRank = @() getAllUnits().reduce(@(res, unit) unit.isBought() ? max(res, unit.rank) : res, 0)

let function tryOpenCaptchaHandler(callbackSuccess = null, callbackClose = null) {
  if (!is_platform_pc || !hasFeature("CaptchaAllowed") || getMaxUnitsRank() < minVehicleRankForShowCaptcha) {
    if(callbackSuccess != null)
      callbackSuccess()
    return
  }

  let cache = getCaptchaCache()
  cache.countTries++

  if(cache.hasSuccessfullyTry) {
    if (get_charserver_time_sec() - cache.lastTryTime >= maxTimeBetweenShowCaptcha) {
      handlersManager.loadHandler(CaptchaHandler, { callbackSuccess, callbackClose })
      return
    }
    callbackSuccess()
    return
  }

  if(cache.countTries > 6) {
    handlersManager.loadHandler(CaptchaHandler, { callbackSuccess, callbackClose })
    return
  }

  let countComplaints = ::get_player_complaint_counts()?.complaint_count_other["BOT"] ?? 0
  if(countComplaints >= minComplaintsCountForShowCaptcha) {
    handlersManager.loadHandler(CaptchaHandler, { callbackSuccess, callbackClose })
    return
  }

  if(frnd() > 0.5) {
    handlersManager.loadHandler(CaptchaHandler, { callbackSuccess, callbackClose })
    return
  }

  if(callbackSuccess != null)
    callbackSuccess()
}

register_command(function() {
  let cache = getCaptchaCache()
  cache.hasSuccessfullyTry = !cache.hasSuccessfullyTry
  log($"'captcha passed' toggled to {cache.hasSuccessfullyTry}")
}, "captcha.toggle_passed")

return tryOpenCaptchaHandler