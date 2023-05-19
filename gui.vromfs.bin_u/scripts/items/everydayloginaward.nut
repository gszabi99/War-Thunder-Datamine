//-file:plus-string

//checked for explicitness
#no-root-fallback
#explicit-this

from "%scripts/dagui_library.nut" import *
let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")
let u = require("%sqStdLibs/helpers/u.nut")

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let DataBlock  = require("DataBlock")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let time = require("%scripts/time.nut")
let { disableSeenUserlogs } = require("%scripts/userLog/userlogUtils.nut")
let { stashBhvValueConfig } = require("%sqDagui/guiBhv/guiBhvValueConfig.nut")
let { todayLoginExp, loginStreak, getExpRangeTextOfLoginStreak } = require("%scripts/battlePass/seasonState.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { register_command } = require("console")
let { initItemsRoulette, skipItemsRouletteAnimation } = require("%scripts/items/roulette/itemsRoulette.nut")

let class EveryDayLoginAward extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/items/everyDayLoginAward.blk"
  needVoiceChat = false

  lastSavedDay = 0
  userlog = null
  isOpened = false
  haveItems = false
  useSingleAnimation = true
  rouletteAnimationFinished = false

  rewardsArray = [] //every day reward
  periodicRewardsArray = [] //longer period reward

  curPeriodicAwardData = null

  unit = null
  periodUnit = null

  function initScreen() {
    this.updateHeader()
    this.updateGuiBlkData()

    this.rewardsArray = this.getRewardsArray(this.getAwardName())
    this.periodicRewardsArray = this.getRewardsArray(this.getPeriodicAwardName())
    this.checkRewardsArray()

    this.updateAwards()
    this.updateDaysProgressBar()
    this.fillOpenedChest()
    this.initExpTexts()

    ::move_mouse_on_obj(this.getObj("btn_nav_open"))
  }

  function updateHeader() {
    let titleObj = this.scene.findObject("award_type_title")

    if (!checkObj(titleObj))
      return

    local text = loc(this.userlog.body.rewardType + "/name")

    let itemId = this.getTrophyIdName(this.getAwardName())
    let item = ::ItemsManager.findItemById(itemId)
    if (item)
      text += loc("ui/colon") + item.getName(false)

    let periodAward = this.getPeriodAwardConfig()
    if (periodAward) {
      let period = getTblValue("periodicDays", periodAward)
      if (periodAward)
        text += " " + loc("keysPlus") + " " + loc("EveryDayLoginAward/periodAward", { period = period })
    }

    titleObj.setValue(text)
  }

  function updateGuiBlkData() {
    let guiBlk = GUI.get()
    let data = guiBlk?.every_day_login_award
    if (!data)
      return
    local imageSectionName = "image"
    let imageSectionNameAlt = "tencent_image"
    if (::is_vendor_tencent() && u.isDataBlock(data[imageSectionNameAlt]))
      imageSectionName = imageSectionNameAlt

    this.savePeriodAwardData(data)

    this.updateObjectByData(data, {
                               name = "color",
                               objId = "filled_reward_progress",
                               param = "background-color",
                               tooltipFunc = function(paramsTable) {
                                 let obj = getTblValue("obj", paramsTable)
                                 let weeks = getTblValue("week", paramsTable, 0)
                                 if (!checkObj(obj) || weeks <= 0)
                                  return

                                 obj.tooltip = loc("EveryDayLoginAward/progressBar/tooltip", { weeks = weeks })
                               }
                             })

    this.updateObjectByData(data, {
                                name = imageSectionName,
                                objId = "award_image",
                                param = "background-image",
                             })
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
    let objId = getTblValue("objId", params, "")
    let obj = this.scene.findObject(objId)
    if (!checkObj(obj))
      return

    let name = getTblValue("name", params, "")
    let block = data[name]
    let blockLen = block ? block.paramCount() : 0
    if (blockLen <= 0)
      return

    let loopLen = ::to_integer_safe(getTblValue("loopLenght", this.userlog.body, 1))
    let progress = ::to_integer_safe(getTblValue("progress", this.userlog.body, 1)) - 1
    let weeksInARow = progress / loopLen

    let week = weeksInARow % blockLen

    let value = block[week.tostring()]
    let checkFunc = getTblValue("checkFunc", params)
    if (checkFunc && !checkFunc(value)) {
      log("Every Day Login Award: wrong name " + name)
      debugTableData(data)
      return
    }

    let tooltipFunc = getTblValue("tooltipFunc", params)
    if (tooltipFunc)
      tooltipFunc({ obj = obj, week = weeksInARow })

    let param = getTblValue("param", params, "")
    obj[param] = value
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
    let awObj = this.scene.findObject("award_recieved")
    if (!checkObj(awObj))
      return

    local layersData = this.getChestLayersData()
    if (this.isOpened) {
      layersData += this.useSingleAnimation ? this.getRewardImage() : ""
      layersData += ::trophyReward.getRestRewardsNumLayer(this.rewardsArray, ::trophyReward.maxRewardsShow)
    }

    this.guiScene.replaceContentFromText(awObj, layersData, layersData.len(), this)
  }

  function getChestLayersData() {
    let id = this.getTrophyIdName(this.getAwardName())
    let item = ::ItemsManager.findItemById(id)
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

    log("Every Day Login Award: not found item by id = " + id)
    debugTableData(this.userlog)
    return LayersIcon.getIconData("default_chest_debug")
  }

  function getRewardsArray(awardName) {
    let userlogConfig = []
    let total = ::get_user_logs_count()
    for (local i = total - 1; i >= 0; i--) {
      let blk = DataBlock()
      ::get_user_log_blk_body(i, blk)

      if (blk.id == this.userlog.id)
        break

      if (blk.type != EULT_OPEN_TROPHY
        || this.getTrophyIdName(awardName) != getTblValue("id", blk.body, "")
        || !getTblValue("everyDayLoginAward", blk.body, false))
        continue

      userlogConfig.append(::buildTableFromBlk(blk.body))
    }

    return userlogConfig
  }

  function getRewardImage() {
    if (this.rewardsArray.len() == 0)
      return ""

    local layersData = ""
    for (local i = 0; i < ::trophyReward.maxRewardsShow; i++) {
      if (!(i in this.rewardsArray))
        break

      layersData += ::trophyReward.getImageByConfig(this.rewardsArray[i], false)
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
    let pawObj = this.scene.findObject("periodic_reward_recieved")
    let cfg = this.getPeriodAwardConfig()
    let period = getTblValue("periodicDays", cfg, 0)

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
      assert(isDefault, "Every Day Login Award: empty trophy param for config for period " + period)
      debugTableData(cfg)
      return
    }

    let imgObj = pawObj.findObject("periodic_image")
    if (!checkObj(imgObj))
      return

    imgObj["background-image"] = "@!" + bgImage
    pawObj.show(true)

    let animObj = pawObj.findObject("periodic_reward_animation")
    if (checkObj(animObj)) {
      animObj.animation = "show"
      this.guiScene.playSound("chest_open")
    }
  }

  function getTrophyIdName(name = "") {
    let prefix = "trophy/"
    let pLen = prefix.len()
    return (name.len() > pLen && name.slice(0, pLen) == prefix) ? name.slice(pLen) : name
  }

  function getAwardName() {
    return this.userlog?.body.chardReward0.name ?? ""
  }

  function getPeriodAwardConfig() {
    return getTblValue("chardReward1", this.userlog.body)
  }

  function getPeriodicAwardName() {
    return getTblValue("name", this.getPeriodAwardConfig(), "")
  }

  function stopRouletteSpinning() {
    if (this.rouletteAnimationFinished)
      return

    let obj = this.scene.findObject("rewards_list")
    skipItemsRouletteAnimation(obj)
    this.onOpenAnimFinish()
    this.fillOpenedChest()
  }

  function onViewRewards() {
    if (!this.isOpened || !this.rouletteAnimationFinished)
      return

    let arr = []
    arr.extend(this.rewardsArray)
    arr.extend(this.periodicRewardsArray)

    if (arr.len() > 1 || this.haveItems)
      ::gui_start_open_trophy_rewards_list({ rewardsArray = ::trophyReward.processUserlogData(arr) })
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
        let delay = ::to_integer_safe(animObj?.chestReplaceDelay, 0)
        ::Timer(animObj, 0.001 * delay, this.fillOpenedChest, this)
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
    this.showSceneBtn("btn_open", !this.isOpened)
    this.showSceneBtn("open_chest_animation", !this.rouletteAnimationFinished)
    this.showSceneBtn("btn_rewards_list", this.isOpened && this.rouletteAnimationFinished && (this.rewardsArray.len() > 1 || this.haveItems))

    if (this.isOpened)
      this.scene.findObject("btn_nav_open").setValue(this.rouletteAnimationFinished || this.useSingleAnimation
        ? loc("mainmenu/btnClose")
        : loc("msgbox/btn_skip"))

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
      base.goBack()
  }

  function updateUnitItem(curUnit = null, obj = null) {
    if (!curUnit || !checkObj(obj))
      return

    let params = { hasActions = true }
    let unitData = ::build_aircraft_item(curUnit.name, curUnit, params)
    this.guiScene.replaceContentFromText(obj, unitData, unitData.len(), this)
    ::fill_unit_item_timers(obj.findObject(curUnit.name), curUnit, params)
  }

  function checkRewardsArray() {
    foreach (reward in this.rewardsArray) {
      let rewardType = ::trophyReward.getType(reward)
      this.haveItems = this.haveItems || ::trophyReward.isRewardItem(rewardType)

      if (rewardType == "unit" || rewardType == "rentedUnit")
        this.unit = getAircraftByName(reward[rewardType]) || this.unit
    }

    foreach (reward in this.periodicRewardsArray) {
      let rewardType = ::trophyReward.getType(reward)
      this.haveItems = this.haveItems || ::trophyReward.isRewardItem(rewardType)

      if (rewardType == "unit" || rewardType == "rentedUnit")
        this.periodUnit = getAircraftByName(reward[rewardType]) || this.periodUnit
    }
  }

  function updateReward() {
    let haveUnit = this.unit != null || this.periodUnit != null
    let withoutUnitObj = this.showSceneBtn("block_without_unit", !haveUnit && this.isOpened)

    let withUnitObj = this.showSceneBtn("block_with_unit", haveUnit && this.isOpened)
    this.showSceneBtn("reward_join_img", this.periodicRewardsArray.len() > 0)

    if (!this.isOpened)
      return

    let placeObj = haveUnit ? withUnitObj : withoutUnitObj
    if (!checkObj(placeObj))
      return

    let gotTextObj = this.scene.findObject("got_text")
    if (checkObj(gotTextObj))
      gotTextObj.setValue(loc("reward") + loc("ui/colon"))

    let reward = this.unit ? this.getRentUnitText(this.unit) : ::trophyReward.getReward(this.rewardsArray)
    let rewardTextObj = placeObj.findObject("reward_text")
    if (checkObj(rewardTextObj))
      rewardTextObj.setValue(reward)

    let periodReward = this.periodUnit ? this.getRentUnitText(this.periodUnit) : ::trophyReward.getReward(this.periodicRewardsArray)
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
    let loopLen = getTblValue("loopLenght", this.userlog.body, 0)
    let dayInLoop = getTblValue("dayInLoop", this.userlog.body)
    let progress = getTblValue("progress", this.userlog.body, 0)

    for (local i = 0; i < loopLen; i++) {
      let offset = getTblValue("daysForStat" + i, this.userlog.body)
      if (offset == null) //can be 0
        break

      local day = dayInLoop + offset
      if (day <= 0)
        day = loopLen + day + 1
      else if (day > loopLen)
        day = day - loopLen

      let today = offset == 0
      let tomorrow = offset == 1
      let previousAwards = offset < 0
      let periodRewardDays = getTblValue("awardPeriodStat" + i, this.userlog.body, -1)

      let item = this.prepairViewItem({
        type = this.userlog.type,
        itemId = getTblValue("awardTrophyStat" + i, this.userlog.body),
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
    let today = getTblValue("today", viewItemConfig, false)

    local weekDayText = ""
    if (today)
      weekDayText = loc("ui/parentheses", { text = loc("day/today") })
    else if (getTblValue("tomorrow", viewItemConfig, false))
      weekDayText = loc("ui/parentheses", { text = loc("day/tomorrow") })

    let period = viewItemConfig.periodRewardDays
    let recentRewardData = this.curPeriodicAwardData.getBlockByName(period.tostring())
    let periodicRewImage = recentRewardData ? getTblValue("trophy", recentRewardData) : null

    return {
      award_day_text = loc("enumerated_day", { number = getTblValue("dayNum", viewItemConfig) })
      week_day_text = weekDayText
      openedPicture = getTblValue("openedPicture", viewItemConfig, false)
      current = today
      havePeriodReward = recentRewardData != null
      periodicRewardImage = periodicRewImage
      skipNavigation = true
      item = ::get_userlog_image_item(::ItemsManager.findItemById(getTblValue("itemId", viewItemConfig)), viewItemConfig)
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
    local value = getTblValue("dayInLoop", this.userlog.body, -1)
    local maxVal = getTblValue("loopLenght", this.userlog.body, -1)
    let progress = getTblValue("progress", this.userlog.body, -1)
    if (value < 0 || maxVal < 0) {
      value = progress
      maxVal = getTblValue("daysForLast", this.userlog.body, 0) + value
    }

    let blockObj = this.scene.findObject("reward_progress_box")
    if (!checkObj(blockObj))
      return

    let textNestObj = blockObj.findObject("filled_reward_progress")

    let singleDayLength = blockObj.getSize()[0] * (1.0 / maxVal)

    let filledBoxWidth = ::to_integer_safe(singleDayLength * value)
    textNestObj.width = filledBoxWidth
    this.guiScene.setUpdatesEnabled(true, true)

    let view = { item = [] }
    for (local i = 0; i < maxVal; i++) {
      let param = "awardPeriodLin" + i
      if (!(param in this.userlog.body) || (value != progress && value == maxVal))
        continue

      if (value >= i) //Don't show image on previous days or today
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
        assert(isDefault, "Every Day Login Award: empty progress param for config for period = " + period)
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
    ::add_big_query_record("daily_trophy_screen",
      objId == "btn_open" ? "main_get_reward"
        : objId == "btn_nav_open" ? "navbar_get_reward"
        : "exit")
  }

  function initExpTexts() {
    if (!hasFeature("BattlePass"))
      return

    this.scene.findObject("today_login_exp").setValue(stashBhvValueConfig([{
      watch = todayLoginExp
      updateFunc = Callback(@(obj, value) this.updateTodayLoginExp(obj, value), this)
    }]))
    this.scene.findObject("login_streak_exp").setValue(stashBhvValueConfig([{
      watch = loginStreak
      updateFunc = Callback(@(obj, value) this.updateLoginStreakExp(obj, value), this)
    }]))
  }

  function updateExpTexts() {
    if (!hasFeature("BattlePass"))
      return

    this.updateTodayLoginExp(this.scene.findObject("today_login_exp"), todayLoginExp.value)
    this.updateLoginStreakExp(this.scene.findObject("login_streak_exp"), loginStreak.value)
  }

  function updateTodayLoginExp(obj, value) {
    let isVisible = value > 0 && !this.isOpened
    obj.show(isVisible)
    if (!isVisible)
      return

    obj.findObject("today_login_exp_text").setValue(
      loc("updStats/battlepass_exp", { amount = value }))
  }

  function updateLoginStreakExp(obj, value) {
    let isVisible = value > 0
      && (this.rouletteAnimationFinished || (this.isOpened && this.useSingleAnimation))
    obj.show(isVisible)
    if (!isVisible)
      return

    let rangeExpText = loc("ui/parentheses/space", {
      text = getExpRangeTextOfLoginStreak() })
    obj.findObject("text").setValue("".concat(loc("battlePass/seasonLoginStreak",
      { amount = value }), rangeExpText))
  }
}

::gui_handlers.EveryDayLoginAward <- EveryDayLoginAward

let function showEveryDayLoginAwardWnd(blk) {
  if (!blk || isInArray(blk.id, ::shown_userlog_notifications))
    return

  if (!hasFeature("everyDayLoginAward"))
    return

  ::gui_start_modal_wnd(EveryDayLoginAward, { userlog = blk })
}

let function hasEveryDayLoginAward() {
  let total = ::get_user_logs_count()
  for (local i = total - 1; i >= 0; --i) {
    let blk = DataBlock()
    ::get_user_log_blk_body(i, blk)

    if (blk.type == EULT_CHARD_AWARD && blk.body?.rewardType == "EveryDayLoginAward")
      return !(blk?.disabled ?? false)
  }
  return false
}

let function debugEveryDayLoginAward(numAwardsToSkip = 0, launchWindow = true) {
  let total = ::get_user_logs_count()
  for (local i = total - 1; i > 0; i--) {
    let blk = DataBlock()
    ::get_user_log_blk_body(i, blk)

    if (blk.type == EULT_CHARD_AWARD && blk.body?.rewardType == "EveryDayLoginAward") {
      if (numAwardsToSkip > 0) {
        numAwardsToSkip--
        continue
      }

      if (launchWindow) {
        let shownIdx = ::shown_userlog_notifications.indexof(blk?.id)
        if (shownIdx != null)
          ::shown_userlog_notifications.remove(shownIdx)
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
  showEveryDayLoginAwardWnd
  hasEveryDayLoginAward
}