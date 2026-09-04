import "%sqStdLibs/helpers/u.nut" as u
import "DataBlock" as DataBlock
from "%sqstd/datablock.nut" import convertBlk
from "console" import register_command
from "dagor.random" import rnd_int
from "%globalScripts/unlockConsts.nut" import *
from "%scripts/dagui_natives.nut" import get_user_log_blk_body, get_user_logs_count
from "%scripts/dagui_library.nut" import *
from "chard" import getLoginGuardState, LOGIN_STREAK_GUARD_PERIOD_DEFAULT

let { move_mouse_on_obj } = require("%scripts/sqDagui/daguiUtil.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { register_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { BaseGuiHandlerWT } = require("%scripts/baseGuiHandlerWT.nut")
let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")
let { Timer } = require("%scripts/sqDagui/timer/timer.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { handlerType } = require("%scripts/sqDagui/framework/handlerType.nut")
let time = require("%scripts/time.nut")
let { disableSeenUserlogs, shownUserlogNotifications } = require("%scripts/userLog/userlogUtils.nut")
let { getUserlogImageItem } = require("%scripts/userLog/userlogViewData.nut")
let { stashBhvValueConfig } = require("%scripts/sqDagui/guiBhv/guiBhvValueConfig.nut")
let { todayLoginExp, loginStreak, getExpRangeTextOfLoginStreak } = require("%scripts/battlePass/seasonState.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { initItemsRoulette, skipItemsRouletteAnimation } = require("%scripts/items/roulette/itemsRoulette.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { openTrophyRewardsList } = require("%scripts/items/trophyRewardList.nut")
let openQrWindow = require("%scripts/wndLib/qrWindow.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { buildUnitSlot, fillUnitSlotTimers } = require("%scripts/slotbar/slotbarView.nut")
let { findItemById } = require("%scripts/items/itemsManagerModule.nut")
let { MAX_REWARDS_SHOW_IN_TROPHY, getTrophyRewardType, processTrophyRewardsUserlogData, isRewardItem, getRestRewardsNumLayer } = require("%scripts/items/trophyReward.nut")
let { getPrizeImageByConfig, getTrophyReward } = require("%scripts/items/prizesView.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { needUseHangarDof } = require("%scripts/viewUtils/hangarDof.nut")
let { isHandlerInScene } = require("%scripts/sqDagui/framework/baseGuiHandlerManager.nut")

let getStreakGuardPeriod = @() getUnlockById("every_day_award")?.mode.streakGuardPeriod
  ?? LOGIN_STREAK_GUARD_PERIOD_DEFAULT

let sizeTimerPid = dagui_propid_add_name_id("_size-timer")
let sizeDelayPid = dagui_propid_add_name_id("_size_delay")

const ARROWS_ANIM_TIME = 0.4
const ARROWS_STOP_BEFORE_END_TIME = 0.1

class EveryDayLoginAward (BaseGuiHandlerWT) {
  wndType = handlerType.BASE
  shouldBlurSceneBgFn = needUseHangarDof
  sceneBlkName = "%gui/items/everyDayLoginAward.blk"
  needVoiceChat = false

  lastSavedDay = 0
  userlog = null
  isOpened = false
  haveItems = false
  useSingleAnimation = true
  rouletteAnimationFinished = false

  rewardsArray = [] 
  periodicRewardsArray = [] 

  curPeriodicAwardData = null

  unit = null
  periodUnit = null

  function initScreen() {
    let loginGuardState = getLoginGuardState()
    log($"Every Day Login Award: loginGuardState loginStreak={loginGuardState.loginStreak} loginGuard={loginGuardState.loginGuard} period={getStreakGuardPeriod()}")
    debugTableData(loginGuardState)
    this.updateGuiBlkData()

    this.rewardsArray = this.getRewardsArray(this.getAwardName())
    this.periodicRewardsArray = this.getRewardsArray(this.getPeriodicAwardName())
    this.checkRewardsArray()

    this.updateAwards()
    this.updateDaysProgressBar()
    this.fillOpenedChest()
    this.initExpTexts()

    move_mouse_on_obj(this.getObj("btn_open"))
    let sendShortcuts = showConsoleButtons.get() ? "{{INPUT_BUTTON GAMEPAD_R1}}" : ""
    let tipHint = loc("dailyAward/playWTM", {sendShortcuts})
    let textObjName = showConsoleButtons.get() ? "wtm_text_console" : "wtm_text"

    showObjById(textObjName, true, this.scene).setValue(tipHint)
  }

  function updateGuiBlkData() {
    let guiBlk = GUI.get()
    let data = guiBlk?.every_day_login_award
    if (!data)
      return

    this.savePeriodAwardData(data)

    this.updateObjectByData(data, {
                               name = "color",
                               objId = "filled_reward_progress",
                               param = "background-color",
                               tooltipFunc = function(paramsTable) {
                                 let obj = paramsTable?.obj
                                 let weeks = (paramsTable?.week ?? 0)
                                 if (!checkObj(obj) || weeks <= 0)
                                  return

                                 obj.tooltip = loc("EveryDayLoginAward/progressBar/tooltip", { weeks = weeks })
                               }
                             })

    this.updateBackgroundImage(data?.image)

    this.updateObjectByData(data, {
                                name = "progressBar",
                                objId = "left_framing",
                                param = "background-image",
                            })
    this.updateObjectByData(data, {
                                name = "progressBar",
                                objId = "right_framing",
                                param = "background-image",
                            })

  }

  function updateObjectByData(data, params = {}) {
    let objId = (params?.objId ?? "")
    let obj = this.scene.findObject(objId)
    if (!checkObj(obj))
      return

    let name = (params?.name ?? "")
    let block = data[name]
    let blockLen = block ? block.paramCount() : 0
    if (blockLen <= 0)
      return

    let loopLen = to_integer_safe((this.userlog.body?.loopLenght ?? 1))
    let progress = to_integer_safe((this.userlog.body?.progress ?? 1)) - 1
    let weeksInARow = progress / loopLen

    let week = weeksInARow % blockLen

    let value = block[week.tostring()]
    let checkFunc = params?.checkFunc
    if (checkFunc && !checkFunc(value)) {
      log($"Every Day Login Award: wrong name {name}")
      debugTableData(data)
      return
    }

    let tooltipFunc = params?.tooltipFunc
    if (tooltipFunc)
      tooltipFunc({ obj = obj, week = weeksInARow })

    let param = (params?.param ?? "")
    obj[param] = value
  }

  function updateBackgroundImage(images) {
    let imagesCount = images != null ? images.paramCount() : 0
    if (imagesCount == 0)
      return

    let obj = this.scene.findObject("award_image")
    if (!(obj?.isValid() ?? false))
      return

    obj["background-image"] = images?[rnd_int(0, imagesCount - 1).tostring()]
  }

  function callItemsRoulette() {
    return initItemsRoulette(this.getTrophyIdName(this.getAwardName()),
                                 this.rewardsArray,
                                 this.scene.findObject("award_image"),
                                 this,
                                 function() {
                                   this.onOpenAnimFinish.call(this)
                                   this.fillOpenedChest.call(this)
                                 }
                               )
  }

  function updateRewardImage() {
    let awObj = this.scene.findObject("trophy_image_wrapper")
    if (!checkObj(awObj))
      return

    local layersData = this.getChestLayersData()
    if (this.isOpened) {
      layersData = "".concat(layersData,
        this.useSingleAnimation ? this.getRewardImage() : "",
        getRestRewardsNumLayer(this.rewardsArray, MAX_REWARDS_SHOW_IN_TROPHY)
      )
    }

    this.guiScene.replaceContentFromText(awObj, layersData, layersData.len(), this)
  }

  function getChestLayersData() {
    let id = this.getTrophyIdName(this.getAwardName())
    let item = findItemById(id)
    if (item) {
      if (this.isOpened)
        return item.getOpenedBigIcon()

      return handyman.renderCached("%gui/items/item.tpl", {
        items = item.getViewData({
          enableBackground = false,
          showAction = false,
          showPrice = false,
          bigPicture = true,
          contentIcon = false,
          skipNavigation = true,
        })
      })
    }

    log($"Every Day Login Award: not found item by id = {id}")
    debugTableData(this.userlog)
    return LayersIcon.getIconData("default_chest_debug")
  }

  function getRewardsArray(awardName) {
    let userlogConfig = []
    let total = get_user_logs_count()
    for (local i = total - 1; i >= 0; i--) {
      let blk = DataBlock()
      get_user_log_blk_body(i, blk)

      if (blk.id == this.userlog.id)
        break

      if (blk.type != EULT_OPEN_TROPHY
        || this.getTrophyIdName(awardName) != (blk.body?.id ?? "")
        || !(blk.body?.everyDayLoginAward ?? false))
        continue

      userlogConfig.append(convertBlk(blk.body))
    }

    return userlogConfig
  }

  function getRewardImage() {
    if (this.rewardsArray.len() == 0)
      return ""

    local layersData = ""
    for (local i = 0; i < MAX_REWARDS_SHOW_IN_TROPHY; i++) {
      if (!(i in this.rewardsArray))
        break

      layersData = "".concat(layersData, getPrizeImageByConfig(this.rewardsArray[i], false))
    }

    if (layersData == "")
      return ""

    return LayersIcon.genDataFromLayer(LayersIcon.findLayerCfg("item_place_container"), layersData)
  }

  function savePeriodAwardData(guiBlkEDLAdata = null) {
    this.curPeriodicAwardData = DataBlock()
    if (!guiBlkEDLAdata) {
      let guiBlk = GUI.get()
      guiBlkEDLAdata = guiBlk?.every_day_login_award
    }

    if (!u.isDataBlock(guiBlkEDLAdata)
        || !u.isDataBlock(guiBlkEDLAdata?.periodic_award))
      return

    this.curPeriodicAwardData = u.copy(guiBlkEDLAdata.periodic_award)
  }

  function updatePeriodRewardImage() {
    let pawObj = this.scene.findObject("periodic_reward_received")
    let cfg = this.getPeriodAwardConfig()
    let period = (cfg?.periodicDays ?? 0)

    local isDefault = false
    local curentRewardData = this.curPeriodicAwardData.getBlockByName(period.tostring())
    if (!curentRewardData) {
      isDefault = true
      curentRewardData = this.curPeriodicAwardData.getBlockByName("default")
    }

    if (!checkObj(pawObj) || !curentRewardData || !this.isOpened)
      return

    let bgImage = curentRewardData?.trophy
    if (u.isEmpty(bgImage)) {
      assert(isDefault,$"Every Day Login Award: empty trophy param for config for period {period}")
      debugTableData(cfg)
      return
    }

    let imgObj = this.useSingleAnimation
      ? this.scene.findObject("periodic_image_chest")
      : this.scene.findObject("periodic_image")

    if (!imgObj?.isValid())
      return

    imgObj["background-image"] =$"@!{bgImage}"
    imgObj.show(true)
    pawObj.show(true)

    let animObj = pawObj.findObject("periodic_reward_animation")
    if (checkObj(animObj)) {
      animObj.animation = "show"
      this.guiScene.playSound("chest_open")
    }
  }

  function getTrophyIdName(name = "") {
    const prefix = "trophy/"
    let pLen = prefix.len()
    return (name.len() > pLen && name.slice(0, pLen) == prefix) ? name.slice(pLen) : name
  }

  function getAwardName() {
    return this.userlog?.body.chardReward0.name ?? ""
  }

  function getPeriodAwardConfig() {
    return this.userlog.body?.chardReward1
  }

  function getPeriodicAwardName() {
    return (this.getPeriodAwardConfig()?.name ?? "")
  }

  function stopRouletteSpinning() {
    if (this.rouletteAnimationFinished)
      return

    let obj = this.scene.findObject("rewards_list")
    skipItemsRouletteAnimation(obj)
    this.startRouletteArrowsAnim(0, 0, ARROWS_ANIM_TIME)
    this.onOpenAnimFinish()
    this.fillOpenedChest()
  }

  function startRouletteArrowsAnim(delay, sizeTimer, totalTime) {
    let arrowsObj = this.scene.findObject("arrows_anim")
    arrowsObj.setFloatProp(sizeDelayPid, delay)
    arrowsObj.setFloatProp(sizeTimerPid, sizeTimer)
    arrowsObj["size-time"] = $"{totalTime * 1000}"
  }

  function onViewRewards() {
    if (!this.isOpened || !this.rouletteAnimationFinished)
      return

    let arr = []
    arr.extend(this.rewardsArray)
    arr.extend(this.periodicRewardsArray)

    if (arr.len() > 1 || this.haveItems)
      openTrophyRewardsList({ rewardsArray = processTrophyRewardsUserlogData(arr) })
  }

  function openChest() {
    this.isOpened = true
    if (this.callItemsRoulette())
      this.useSingleAnimation = false

    this.updateButtons()
    let animId = this.useSingleAnimation ? "open_chest_animation" : "reward_roullete"
    let animObj = this.scene.findObject(animId)
    if (checkObj(animObj)) {
      animObj.animation = "show"
      if (this.useSingleAnimation) {
        this.guiScene.playSound("chest_open")
        let delay = to_integer_safe(animObj?.chestReplaceDelay, 0)
        Timer(animObj, 0.001 * delay, this.fillOpenedChest, this)
      }
      else {
        let roulletteObj = this.scene.findObject("rewards_list")
        let config = roulletteObj.getUserData()
        let arrowsTimeShift = config?.anim.FINAL_ANIM_TIME
          ?? config?.anim.TIME_TO_FINALIZE
          ?? (ARROWS_ANIM_TIME + ARROWS_STOP_BEFORE_END_TIME)
        this.startRouletteArrowsAnim(config ? (config.totalTime - arrowsTimeShift) : 0, 0,
          arrowsTimeShift - ARROWS_STOP_BEFORE_END_TIME
        )
      }
    }
    else
      this.fillOpenedChest()
  }

  function fillOpenedChest() {
    this.updateReward()
    this.updateRewardImage()
    this.updatePeriodRewardImage()
    this.updateButtons()
  }

  function updateButtons() {
    showObjById("btn_open", !this.isOpened, this.scene)
    showObjById("btn_nav_open", this.isOpened, this.scene)
    showObjById("open_chest_animation", !this.rouletteAnimationFinished, this.scene)
    showObjById("btn_rewards_list", this.isOpened && this.rouletteAnimationFinished && (this.rewardsArray.len() > 1 || this.haveItems), this.scene)

    if (this.isOpened) {
      this.scene.findObject("btn_nav_open").setValue(this.rouletteAnimationFinished || this.useSingleAnimation
        ? loc("mainmenu/btnClose")
        : loc("msgbox/btn_skip"))
    }

    this.updateExpTexts()
  }

  function onOpenAnimFinish() {
    this.rouletteAnimationFinished = true
  }

  function goBack(obj = null) {
    if (!this.isOpened) {
      this.openChest()
      this.sendOpenTrophyStatistic(obj)
      disableSeenUserlogs([this.userlog.id])
    }
    else if (!this.rouletteAnimationFinished)
      this.stopRouletteSpinning()
    else
      this.guiScene.performDelayed(this, base.goBack)
  }

  function updateUnitItem(curUnit = null, obj = null) {
    if (!curUnit || !checkObj(obj))
      return

    let unitData = buildUnitSlot(curUnit.name, curUnit)
    this.guiScene.replaceContentFromText(obj, unitData, unitData.len(), this)
    fillUnitSlotTimers(obj.findObject(curUnit.name), curUnit)
  }

  function checkRewardsArray() {
    foreach (reward in this.rewardsArray) {
      let rewardType = getTrophyRewardType(reward)
      this.haveItems = this.haveItems || isRewardItem(rewardType)

      if (rewardType == "unit" || rewardType == "rentedUnit")
        this.unit = getAircraftByName(reward[rewardType]) || this.unit
    }

    foreach (reward in this.periodicRewardsArray) {
      let rewardType = getTrophyRewardType(reward)
      this.haveItems = this.haveItems || isRewardItem(rewardType)

      if (rewardType == "unit" || rewardType == "rentedUnit")
        this.periodUnit = getAircraftByName(reward[rewardType]) || this.periodUnit
    }
  }

  function updateReward() {
    let haveUnit = this.unit != null || this.periodUnit != null
    let withoutUnitObj = showObjById("block_without_unit", !haveUnit && this.isOpened, this.scene)

    let withUnitObj = showObjById("block_with_unit", haveUnit && this.isOpened, this.scene)
    showObjById("reward_join_img", this.periodicRewardsArray.len() > 0, this.scene)

    if (!this.isOpened)
      return

    let placeObj = haveUnit ? withUnitObj : withoutUnitObj
    if (!checkObj(placeObj))
      return

    let gotTextObj = this.scene.findObject("chest_award_label")
    gotTextObj.setValue("".concat(loc("reward"), loc("ui/colon")))

    let reward = this.unit ? this.getRentUnitText(this.unit) : getTrophyReward(this.rewardsArray)
    let rewardTextObj = placeObj.findObject("reward_text")
    if (checkObj(rewardTextObj))
      rewardTextObj.setValue(reward)

    let periodReward = this.periodUnit ? this.getRentUnitText(this.periodUnit) : getTrophyReward(this.periodicRewardsArray)
    let pRewardTextObj = placeObj.findObject("period_reward_text")
    if (checkObj(pRewardTextObj))
      pRewardTextObj.setValue(periodReward)

    this.updateUnitItem(this.unit, placeObj.findObject("reward_aircrafts"))
    this.updateUnitItem(this.periodUnit, placeObj.findObject("periodic_reward_aircrafts"))
  }

  function getRentUnitText(curUnit) {
    if (!curUnit || !curUnit.isRented())
      return ""

    let totalRentTime = curUnit.getRentTimeleft()
    let timeText = colorize("userlogColoredText", time.hoursToString(time.secondsToHours(totalRentTime)))

    let rentText = loc("shop/rentFor", { time = timeText })
    return colorize("activeTextColor", rentText)
  }

  function updateAwards() {
    let view = { items = [] }
    let loopLen = (this.userlog.body?.loopLenght ?? 0)
    let dayInLoop = this.userlog.body?.dayInLoop ?? 1
    let progress = (this.userlog.body?.progress ?? 0)

    for (local i = 0; i < loopLen; i++) {
      let offset = this.userlog.body?[$"daysForStat{i}"]
      if (offset == null) 
        break

      local day = dayInLoop + offset
      if (day <= 0)
        day = loopLen + day + 1
      else if (day > loopLen)
        day = day - loopLen

      let today = offset == 0
      let tomorrow = offset == 1
      let previousAwards = offset < 0
      let periodRewardDays = (this.userlog.body?[$"awardPeriodStat{i}"] ?? -1)

      let item = this.prepairViewItem({
        type = this.userlog.type,
        itemId = this.userlog.body?[$"awardTrophyStat{i}"],
        today = today,
        tomorrow = tomorrow,
        dayNum = progress + offset,
        periodRewardDays = periodRewardDays
        arrowNext = i != 0,
        arrowType = (day - this.lastSavedDay) == 2 ? "double" : (day - this.lastSavedDay > 2 ? "triple" : "single"),
        enableBackground = true,
        itemHighlight = today ? "white" : previousAwards ? "black" : "none"
        openedPicture = previousAwards
        showTooltip = !previousAwards
        skipNavigation = previousAwards
      })

      this.checkMissingDays(view, day, i)
      view.items.append(item)
    }

    let awardsObj = this.scene.findObject("awards_line")
    if (view.items.len() > 0 && checkObj(awardsObj)) {
      let data = handyman.renderCached(("%gui/items/awardItem.tpl"), view)
      this.guiScene.replaceContentFromText(awardsObj, data, data.len(), this)
    }

    this.guiScene.setUpdatesEnabled(true, true)
  }

  function prepairViewItem(viewItemConfig) {
    let today = (viewItemConfig?.today ?? false)

    local weekDayText = ""
    if (today)
      weekDayText = loc("ui/parentheses", { text = loc("day/today") })
    else if ((viewItemConfig?.tomorrow ?? false))
      weekDayText = loc("ui/parentheses", { text = loc("day/tomorrow") })

    let period = viewItemConfig.periodRewardDays
    let recentRewardData = this.curPeriodicAwardData.getBlockByName(period.tostring())
    let periodicRewImage = recentRewardData ? recentRewardData?.trophy : null

    return {
      award_day_text = loc("enumerated_day", { number = viewItemConfig?.dayNum })
      week_day_text = weekDayText
      openedPicture = (viewItemConfig?.openedPicture ?? false)
      current = today
      havePeriodReward = recentRewardData != null
      periodicRewardImage = periodicRewImage
      skipNavigation = true
      item = getUserlogImageItem(findItemById(viewItemConfig?.itemId), viewItemConfig)
    }
  }

  function checkMissingDays(view, daysForLast, idx) {
    local daysDiff = idx == 0 ? 0 : (daysForLast - this.lastSavedDay)
    this.lastSavedDay = daysForLast
    if (daysDiff < 2)
      return
    else if (daysDiff > 2)
      daysDiff = 3

    for (local i = 1; i < daysDiff; i++)
      view.items.append({
        item = handyman.renderCached("%gui/items/item.tpl", {
          items = [{
            enableBackground = true
            skipNavigation = true
          }]
        }),
        emptyBlock = "yes",
      })
  }

  function updateDaysProgressBar() {
    local value = (this.userlog.body?.dayInLoop ?? -1)
    local maxVal = (this.userlog.body?.loopLenght ?? -1)
    let progress = (this.userlog.body?.progress ?? -1)
    if (value < 0 || maxVal < 0) {
      value = progress
      maxVal = (this.userlog.body?.daysForLast ?? 0) + value
    }

    let blockObj = this.scene.findObject("reward_progress_box")
    if (!checkObj(blockObj))
      return

    let textNestObj = blockObj.findObject("filled_reward_progress")

    let singleDayLength = blockObj.getSize()[0] * (1.0 / maxVal)

    let filledBoxWidth = to_integer_safe(singleDayLength * value)
    textNestObj.width = filledBoxWidth
    this.guiScene.setUpdatesEnabled(true, true)

    let view = { item = [] }
    for (local i = 0; i < maxVal; i++) {
      let param = $"awardPeriodLin{i}"
      if (!(param in this.userlog.body) || (value != progress && value == maxVal))
        continue

      if (value >= i) 
        continue

      local isDefault = false
      let period = this.userlog.body[param]
      local rewardConfig = this.curPeriodicAwardData.getBlockByName(period.tostring())
      if (!rewardConfig) {
        isDefault = true
        rewardConfig = this.curPeriodicAwardData.getBlockByName("default")
      }

      if (!rewardConfig)
        continue

      let progressImage = rewardConfig.progress
      if (u.isEmpty(progressImage)) {
        assert(isDefault, $"Every Day Login Award: empty progress param for config for period = {period}")
        debugTableData(rewardConfig)
        continue
      }

      let itemNum = i
      local imgColor = "@commonImageColor"
      if (itemNum == value)
        imgColor = "@activeImageColor"
      else if (i < value)
        imgColor = "@fadedImageColor"

      let posX = (singleDayLength * itemNum - 0.5 * singleDayLength).tointeger()
      view.item.append({
        image = progressImage
        posX = posX.tostring()
        color = imgColor
        tooltip = loc("EveryDayLoginAward/periodAward", { period = period })
      })
    }

    if (!view.item.len())
      return

    let data = handyman.renderCached("%gui/items/edlaProgressBarRewardIcon.tpl", view)
    this.guiScene.appendWithBlk(blockObj, data, this)
  }

  function onEventCrewTakeUnit(_params) {
    this.goBack()
  }

  function sendOpenTrophyStatistic(obj) {
    let objId = obj?.id
    sendBqEvent("CLIENT_GAMEPLAY_1", "daily_trophy_screen", {
      result = objId == "btn_open" ? "main_get_reward"
        : objId == "btn_nav_open" ? "navbar_get_reward"
        : "exit"})
  }

  function initExpTexts() {
    this.scene.findObject("today_login_exp_watch").setValue(stashBhvValueConfig([{
      watch = todayLoginExp
      updateFunc = Callback(@(_obj, _value) this.updateExpTexts(), this)
    },
    {
      watch = loginStreak
      updateFunc = Callback(@(_obj, _value) this.updateExpTexts(), this)
    }]))
  }

  function updateExpTexts() {
    let obj = this.scene.findObject("today_login_exp_text")
    if (loginStreak.get() > 0
        && (this.rouletteAnimationFinished || (this.isOpened && this.useSingleAnimation))) {
      this.updateLoginStreakExp(obj, loginStreak.get())
    }
    else {
      this.updateTodayLoginExp(obj, todayLoginExp.get())
    }
  }

  function updateTodayLoginExp(obj, value) {
    obj.setValue(value <= 0 ? "" : loc("updStats/battlepass_exp", { amount = value }))
  }

  function updateLoginStreakExp(obj, value) {
    let rangeExpText = loc("ui/parentheses/space", {
      text = getExpRangeTextOfLoginStreak() })
    obj.setValue("".concat(loc("battlePass/seasonLoginStreak",
      { amount = value }), rangeExpText))
  }

  function onWarThunderMobileLink() {
    openQrWindow({
      headerText = loc("war_thunder_mobile")
      additionalInfoText = loc("dailyAward/qrCodeWTM")
      qrCodesData = [
        {url = "https://play.google.com/store/apps/details?id=com.gaijingames.wtm", text = loc("qrCode/GooglePlay")}
        {url = "https://apps.apple.com/us/app/war-thunder-mobile/id1577525428", text = loc("qrCode/AppStore")}
        {url = "https://wtmobile.com/", text = loc("qrCode/downloadApkFile")}
      ]
      needUrlWithQrRedirect = true
    })
  }

}

register_gui_handler("EveryDayLoginAward", EveryDayLoginAward)

function showEveryDayLoginAwardWnd(blk) {
  if (!blk || isInArray(blk.id, shownUserlogNotifications.get()))
    return

  if (!hasFeature("everyDayLoginAward"))
    return

  if (isHandlerInScene(EveryDayLoginAward))
    return

  loadHandler(EveryDayLoginAward, { userlog = blk })
}

function hasEveryDayLoginAward() {
  let total = get_user_logs_count()
  for (local i = total - 1; i >= 0; --i) {
    let blk = DataBlock()
    get_user_log_blk_body(i, blk)

    if (blk.type == EULT_CHARD_AWARD && blk.body?.rewardType == "EveryDayLoginAward")
      return !(blk?.disabled ?? false)
  }
  return false
}

function debugEveryDayLoginAward(numAwardsToSkip = 0, launchWindow = true) {
  let total = get_user_logs_count()
  for (local i = total - 1; i > 0; i--) {
    let blk = DataBlock()
    get_user_log_blk_body(i, blk)

    if (blk.type == EULT_CHARD_AWARD && blk.body?.rewardType == "EveryDayLoginAward") {
      if (numAwardsToSkip > 0) {
        numAwardsToSkip--
        continue
      }

      if (launchWindow) {
        shownUserlogNotifications.mutate(function(v) {
          let shownIdx = v.indexof(blk?.id)
          if (shownIdx != null)
            v.remove(shownIdx)
        })
        showEveryDayLoginAwardWnd(blk)
      }
      else {
        console_print("PRINT EVERY DAY LOGIN AWARD")
        debugTableData(blk)
      }
      return
    }
  }
  console_print("!!!! NOT FOUND ANY EVERY DAY LOGIN AWARD")
}

register_command(debugEveryDayLoginAward, "debug.everyDayLoginAward")

return {
  EveryDayLoginAward
  showEveryDayLoginAwardWnd
  hasEveryDayLoginAward
}
