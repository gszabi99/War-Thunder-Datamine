local time = require("scripts/time.nut")
local { disableSeenUserlogs } = require("scripts/userLog/userlogUtils.nut")
local { stashBhvValueConfig } = require("sqDagui/guiBhv/guiBhvValueConfig.nut")
local { todayLoginExp,loginStreak, getExpRangeTextOfLoginStreak } = require("scripts/battlePass/seasonState.nut")

::gui_start_show_login_award <- function gui_start_show_login_award(blk)
{
  if (!blk || ::isInArray(blk.id, ::shown_userlog_notifications))
    return

  if (!::has_feature("everyDayLoginAward"))
    return

  ::gui_start_modal_wnd(::gui_handlers.EveryDayLoginAward, {userlog = blk})
}

class ::gui_handlers.EveryDayLoginAward extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/items/everyDayLoginAward.blk"
  needVoiceChat = false

  stylePrefix = "every_day_award_trophy_"
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

  function initScreen()
  {
    updateHeader()
    updateGuiBlkData()

    rewardsArray = getRewardsArray(getAwardName())
    periodicRewardsArray = getRewardsArray(getPeriodicAwardName())
    checkRewardsArray()

    updateAwards()
    updateDaysProgressBar()
    fillOpenedChest()
    initExpTexts()

    ::move_mouse_on_obj(getObj("btn_nav_open"))
  }

  function updateHeader()
  {
    local titleObj = scene.findObject("award_type_title")

    if (!::checkObj(titleObj))
      return

    local text = ::loc(userlog.body.rewardType+"/name")

    local itemId = getTrophyIdName(getAwardName())
    local item = ::ItemsManager.findItemById(itemId)
    if (item)
      text += ::loc("ui/colon") + item.getName(false)

    local periodAward = getPeriodAwardConfig()
    if (periodAward)
    {
      local period = ::getTblValue("periodicDays", periodAward)
      if (periodAward)
        text += " " + ::loc("keysPlus") + " " + ::loc("EveryDayLoginAward/periodAward", {period = period})
    }

    titleObj.setValue(text)
  }

  function updateGuiBlkData()
  {
    local guiBlk = ::configs.GUI.get()
    local data = guiBlk?.every_day_login_award
    if (!data)
      return
    local imageSectionName = "image"
    local imageSectionNameAlt = "tencent_image"
    if (::is_vendor_tencent() && ::u.isDataBlock(data[imageSectionNameAlt]))
      imageSectionName = imageSectionNameAlt

    savePeriodAwardData(data)

    updateObjectByData(data, {
                               name = "color",
                               objId = "filled_reward_progress",
                               param = "background-color",
                               tooltipFunc = function(paramsTable)
                               {
                                 local obj = ::getTblValue("obj", paramsTable)
                                 local weeks = ::getTblValue("week", paramsTable, 0)
                                 if (!::checkObj(obj) || weeks <= 0)
                                  return

                                 obj.tooltip = ::loc("EveryDayLoginAward/progressBar/tooltip", {weeks = weeks})
                               }
                             })

    updateObjectByData(data, {
                                name = imageSectionName,
                                objId = "award_image",
                                param = "background-image",
                             })
    updateObjectByData(data, {
                                name = "progressBar",
                                objId = "left_framing",
                                param = "background-image",
                            })
    updateObjectByData(data, {
                                name = "progressBar",
                                objId = "right_framing",
                                param = "background-image",
                            })
  }

  function updateObjectByData(data, params = {})
  {
    local objId = ::getTblValue("objId", params, "")
    local obj = scene.findObject(objId)
    if (!::checkObj(obj))
      return

    local name = ::getTblValue("name", params, "")
    local block = data[name]
    local blockLen = block? block.paramCount() : 0
    if (blockLen <= 0)
      return

    local loopLen = ::to_integer_safe(::getTblValue("loopLenght", userlog.body, 1))
    local progress = ::to_integer_safe(::getTblValue("progress", userlog.body, 1)) - 1
    local weeksInARow = progress / loopLen

    local week = weeksInARow % blockLen

    local value = block[week.tostring()]
    local checkFunc = ::getTblValue("checkFunc", params)
    if (checkFunc && !checkFunc(value))
    {
      ::dagor.debug("Every Day Login Award: wrong name " + name)
      ::debugTableData(data)
      return
    }

    local tooltipFunc = ::getTblValue("tooltipFunc", params)
    if (tooltipFunc)
      tooltipFunc({obj = obj, week = weeksInARow})

    local param = ::getTblValue("param", params, "")
    obj[param] = value
  }

  function callItemsRoulette()
  {
    return ::ItemsRoulette.init(getTrophyIdName(getAwardName()),
                                 rewardsArray,
                                 scene.findObject("award_image"),
                                 this,
                                 function() {
                                   onOpenAnimFinish.call(this)
                                   fillOpenedChest.call(this)
                                 }
                               )
  }

  function updateRewardImage()
  {
    local awObj = scene.findObject("award_recieved")
    if (!::checkObj(awObj))
      return

    local layersData = getChestLayersData()
    if (isOpened)
    {
      layersData += useSingleAnimation? getRewardImage() : ""
      layersData += ::trophyReward.getRestRewardsNumLayer(rewardsArray, ::trophyReward.maxRewardsShow)
    }

    guiScene.replaceContentFromText(awObj, layersData, layersData.len(), this)
  }

  function getChestLayersData()
  {
    local id = getTrophyIdName(getAwardName())
    local item = ::ItemsManager.findItemById(id)
    if (item)
    {
      if (isOpened)
        return item.getOpenedBigIcon()

      return ::handyman.renderCached("gui/items/item", {
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

    ::dagor.debug("Every Day Login Award: not found item by id = " + id)
    ::debugTableData(userlog)
    return ::LayersIcon.getIconData("default_chest_debug")
  }

  function getRewardsArray(awardName)
  {
    local userlogConfig = []
    local total = ::get_user_logs_count()
    for (local i = total-1; i >= 0; i--)
    {
      local blk = ::DataBlock()
      ::get_user_log_blk_body(i, blk)

      if (blk.id == userlog.id)
        break

      if (blk.type != ::EULT_OPEN_TROPHY
        || getTrophyIdName(awardName) != ::getTblValue("id", blk.body, "")
        || !::getTblValue("everyDayLoginAward", blk.body, false))
        continue

      userlogConfig.append(::buildTableFromBlk(blk.body))
    }

    return userlogConfig
  }

  function getRewardImage()
  {
    if (rewardsArray.len() == 0)
      return ""

    local layersData = ""
    for(local i = 0; i < ::trophyReward.maxRewardsShow; i++)
    {
      if (!(i in rewardsArray))
        break

      layersData += ::trophyReward.getImageByConfig(rewardsArray[i], false)
    }

    if (layersData == "")
      return ""

    return ::LayersIcon.genDataFromLayer(::LayersIcon.findLayerCfg("item_place_container"), layersData)
  }

  function savePeriodAwardData(guiBlkEDLAdata = null)
  {
    curPeriodicAwardData = ::DataBlock()
    if (!guiBlkEDLAdata)
    {
      local guiBlk = ::configs.GUI.get()
      guiBlkEDLAdata = guiBlk?.every_day_login_award
    }

    if (!::u.isDataBlock(guiBlkEDLAdata)
        || !::u.isDataBlock(guiBlkEDLAdata?.periodic_award))
      return

    curPeriodicAwardData = ::u.copy(guiBlkEDLAdata.periodic_award)
  }

  function updatePeriodRewardImage()
  {
    local pawObj = scene.findObject("periodic_reward_recieved")
    local cfg = getPeriodAwardConfig()
    local period = ::getTblValue("periodicDays", cfg, 0)

    local isDefault = false
    local curentRewardData = curPeriodicAwardData.getBlockByName(period.tostring())
    if (!curentRewardData)
    {
      isDefault = true
      curentRewardData = curPeriodicAwardData.getBlockByName("default")
    }

    if (!::checkObj(pawObj) || !curentRewardData || !isOpened)
      return

    local bgImage = curentRewardData?.trophy
    if (::u.isEmpty(bgImage))
    {
      ::dagor.assertf(isDefault, "Every Day Login Award: empty trophy param for config for period " + period)
      ::debugTableData(cfg)
      return
    }

    local imgObj = pawObj.findObject("periodic_image")
    if (!::check_obj(imgObj))
      return

    imgObj["background-image"] = "@!" + bgImage
    pawObj.show(true)

    local animObj = pawObj.findObject("periodic_reward_animation")
    if (::checkObj(animObj))
    {
      animObj.animation = "show"
      guiScene.playSound("chest_open")
    }
  }

  function getTrophyIdName(name = "")
  {
    local prefix = "trophy/"
    local pLen = prefix.len()
    return (name.len() > pLen && name.slice(0, pLen) == prefix) ? name.slice(pLen) : name
  }

  function getAwardName()
  {
    return userlog?.body.chardReward0.name ?? ""
  }

  function getPeriodAwardConfig()
  {
    return ::getTblValue("chardReward1", userlog.body)
  }

  function getPeriodicAwardName()
  {
    return ::getTblValue("name", getPeriodAwardConfig(), "")
  }

  function stopRouletteSpinning()
  {
    if (rouletteAnimationFinished)
      return

    local obj = scene.findObject("rewards_list")
    ItemsRoulette.skipAnimation(obj)
    onOpenAnimFinish()
    fillOpenedChest()
  }

  function onViewRewards()
  {
    if (!isOpened || !rouletteAnimationFinished)
      return

    local arr = []
    arr.extend(rewardsArray)
    arr.extend(periodicRewardsArray)

    if (arr.len() > 1 || haveItems)
      ::gui_start_open_trophy_rewards_list({ rewardsArray = ::trophyReward.processUserlogData(arr) })
  }

  function onOpenChest(obj = null)
  {
    if (!isValid()) //onOpenchest is delayed callback
      return

    sendOpenTrophyStatistic(obj)
    disableSeenUserlogs([userlog.id])
    isOpened = true
    if (callItemsRoulette())
      useSingleAnimation = false

    updateButtons()
    local animId = useSingleAnimation? "open_chest_animation" : "reward_roullete"
    local animObj = scene.findObject(animId)
    if (::checkObj(animObj))
    {
      animObj.animation = "show"
      if (useSingleAnimation)
      {
        guiScene.playSound("chest_open")
        local delay = ::to_integer_safe(animObj?.chestReplaceDelay, 0)
        ::Timer(animObj, 0.001 * delay, fillOpenedChest, this)
      }
    }
    else
      fillOpenedChest()
  }

  function fillOpenedChest()
  {
    updateReward()
    updateRewardImage()
    updatePeriodRewardImage()
    updateButtons()
  }

  function updateButtons()
  {
    showSceneBtn("btn_open", !isOpened)
    showSceneBtn("btn_nav_open", !isOpened)
    showSceneBtn("btn_close", rouletteAnimationFinished || (isOpened && useSingleAnimation))
    showSceneBtn("open_chest_animation", !rouletteAnimationFinished)
    showSceneBtn("btn_rewards_list", isOpened && rouletteAnimationFinished && (rewardsArray.len() > 1 || haveItems))

    ::show_facebook_screenshot_button(scene, isOpened && rouletteAnimationFinished)
    updateExpTexts()
  }

  function onOpenAnimFinish()
  {
    rouletteAnimationFinished = true
  }

  function goBack()
  {
    if (!isOpened)
      onOpenChest()
    else if (!rouletteAnimationFinished)
      stopRouletteSpinning()
    else
    {
      base.goBack()
    }
  }

  function updateUnitItem(curUnit = null, obj = null)
  {
    if (!curUnit || !::check_obj(obj))
      return

    local params = {hasActions = true}
    local unitData = ::build_aircraft_item(curUnit.name, curUnit, params)
    guiScene.replaceContentFromText(obj, unitData, unitData.len(), this)
    ::fill_unit_item_timers(obj.findObject(curUnit.name), curUnit, params)
  }

  function checkRewardsArray()
  {
    foreach(reward in rewardsArray)
    {
      local rewardType = ::trophyReward.getType(reward)
      haveItems = haveItems || ::trophyReward.isRewardItem(rewardType)

      if (rewardType == "unit" || rewardType == "rentedUnit")
        unit = ::getAircraftByName(reward[rewardType]) || unit
    }

    foreach(reward in periodicRewardsArray)
    {
      local rewardType = ::trophyReward.getType(reward)
      haveItems = haveItems || ::trophyReward.isRewardItem(rewardType)

      if (rewardType == "unit" || rewardType == "rentedUnit")
        periodUnit = ::getAircraftByName(reward[rewardType]) || periodUnit
    }
  }

  function updateReward()
  {
    local haveUnit = unit != null || periodUnit != null
    local withoutUnitObj = showSceneBtn("block_without_unit", !haveUnit && isOpened)

    local withUnitObj = showSceneBtn("block_with_unit", haveUnit && isOpened)
    showSceneBtn("reward_join_img", periodicRewardsArray.len() > 0)

    if (!isOpened)
      return

    local placeObj = haveUnit? withUnitObj : withoutUnitObj
    if (!::check_obj(placeObj))
      return

    local gotTextObj = scene.findObject("got_text")
    if (::checkObj(gotTextObj))
      gotTextObj.setValue(::loc("reward") + ::loc("ui/colon"))

    local reward = unit? getRentUnitText(unit) : ::trophyReward.getReward(rewardsArray)
    local rewardTextObj = placeObj.findObject("reward_text")
    if (::checkObj(rewardTextObj))
      rewardTextObj.setValue(reward)

    local periodReward = periodUnit? getRentUnitText(periodUnit) : ::trophyReward.getReward(periodicRewardsArray)
    local pRewardTextObj = placeObj.findObject("period_reward_text")
    if (::checkObj(pRewardTextObj))
      pRewardTextObj.setValue(periodReward)

    updateUnitItem(unit, placeObj.findObject("reward_aircrafts"))
    updateUnitItem(periodUnit, placeObj.findObject("periodic_reward_aircrafts"))
  }

  function getRentUnitText(curUnit)
  {
    if (!curUnit || !curUnit.isRented())
      return ""

    local totalRentTime = curUnit.getRentTimeleft()
    local timeText = ::colorize("userlogColoredText", time.hoursToString(time.secondsToHours(totalRentTime)))

    local rentText = ::loc("shop/rentFor", {time = timeText})
    return ::colorize("activeTextColor", rentText)
  }

  function updateAwards()
  {
    local view = { items = [] }
    local loopLen = ::getTblValue("loopLenght", userlog.body, 0)
    local dayInLoop = ::getTblValue("dayInLoop", userlog.body)
    local progress = ::getTblValue("progress", userlog.body, 0)

    for (local i = 0; i < loopLen; i++)
    {
      local offset = ::getTblValue("daysForStat" + i, userlog.body)
      if (offset == null) //can be 0
        break

      local day = dayInLoop + offset
      if (day <= 0)
        day = loopLen + day + 1
      else if (day > loopLen)
        day = day - loopLen

      local today = offset == 0
      local tomorrow = offset == 1
      local previousAwards = offset < 0
      local periodRewardDays = ::getTblValue("awardPeriodStat" + i, userlog.body, -1)

      local item = prepairViewItem({
        type = userlog.type,
        itemId = ::getTblValue("awardTrophyStat" + i, userlog.body),
        today = today,
        tomorrow = tomorrow,
        dayNum = progress + offset,
        periodRewardDays = periodRewardDays
        arrowNext = i != 0,
        arrowType = (day - lastSavedDay) == 2? "double" : (day - lastSavedDay > 2? "triple" : "single"),
        enableBackground = true,
        itemHighlight = today? "white" : previousAwards? "black" : "none"
        openedPicture = previousAwards
        showTooltip = !previousAwards
        skipNavigation = previousAwards
      })

      checkMissingDays(view, day, i)
      view.items.append(item)
    }

    local awardsObj = scene.findObject("awards_line")
    if (view.items.len() > 0 && ::checkObj(awardsObj))
    {
      local data = ::handyman.renderCached(("gui/items/awardItem"), view)
      guiScene.replaceContentFromText(awardsObj, data, data.len(), this)
    }

    guiScene.setUpdatesEnabled(true, true)
  }

  function prepairViewItem(viewItemConfig)
  {
    local today = ::getTblValue("today", viewItemConfig, false)

    local weekDayText = ""
    if (today)
      weekDayText = ::loc("ui/parentheses", {text = ::loc("day/today")})
    else if (::getTblValue("tomorrow", viewItemConfig, false))
      weekDayText = ::loc("ui/parentheses", {text = ::loc("day/tomorrow")})

    local period = viewItemConfig.periodRewardDays
    local recentRewardData = curPeriodicAwardData.getBlockByName(period.tostring())
    local periodicRewImage = recentRewardData ? ::getTblValue("trophy", recentRewardData) : null

    return {
      award_day_text = ::loc("enumerated_day", {number = ::getTblValue("dayNum", viewItemConfig)})
      week_day_text = weekDayText
      openedPicture = ::getTblValue("openedPicture", viewItemConfig, false)
      current = today
      havePeriodReward = recentRewardData != null
      periodicRewardImage = periodicRewImage
      skipNavigation = true
      item = ::get_userlog_image_item(::ItemsManager.findItemById(::getTblValue("itemId", viewItemConfig)), viewItemConfig)
    }
  }

  function checkMissingDays(view, daysForLast, idx)
  {
    local daysDiff = idx == 0? 0 : (daysForLast - lastSavedDay)
    lastSavedDay = daysForLast
    if (daysDiff < 2)
      return
    else if (daysDiff > 2)
      daysDiff = 3

    for (local i = 1; i < daysDiff; i++)
      view.items.append({
        item = ::handyman.renderCached("gui/items/item", {
          items = [{
            enableBackground = true
            skipNavigation = true
          }]
        }),
        emptyBlock = "yes",
      })
  }

  function updateDaysProgressBar()
  {
    local value = ::getTblValue("dayInLoop", userlog.body, -1)
    local maxVal = ::getTblValue("loopLenght", userlog.body, -1)
    local progress = ::getTblValue("progress", userlog.body, -1)
    if (value < 0 || maxVal < 0)
    {
      value = progress
      maxVal = ::getTblValue("daysForLast", userlog.body, 0) + value
    }

    local blockObj = scene.findObject("reward_progress_box")
    if (!::checkObj(blockObj))
      return

    local textNestObj = blockObj.findObject("filled_reward_progress")

    local singleDayLength = blockObj.getSize()[0] * (1.0 / maxVal)

    local filledBoxWidth = ::to_integer_safe(singleDayLength * value)
    textNestObj.width = filledBoxWidth
    guiScene.setUpdatesEnabled(true, true)

    local view = { item = [] }
    for (local i = 0; i < maxVal; i++)
    {
      local param = "awardPeriodLin" + i
      if (!(param in userlog.body) || (value != progress && value == maxVal))
        continue

      if (value >= i) //Don't show image on previous days or today
        continue

      local isDefault = false
      local period = userlog.body[param]
      local rewardConfig = curPeriodicAwardData.getBlockByName(period.tostring())
      if (!rewardConfig)
      {
        isDefault = true
        rewardConfig = curPeriodicAwardData.getBlockByName("default")
      }

      if (!rewardConfig)
        continue

      local progressImage = rewardConfig.progress
      if (::u.isEmpty(progressImage))
      {
        ::dagor.assertf(isDefault, "Every Day Login Award: empty progress param for config for period = " + period)
        ::debugTableData(rewardConfig)
        continue
      }

      local itemNum = i
      local imgColor = "@commonImageColor"
      if (itemNum == value)
        imgColor = "@activeImageColor"
      else if (i < value)
        imgColor = "@fadedImageColor"

      local posX = (singleDayLength * itemNum - 0.5*singleDayLength).tointeger()
      view.item.append({
        image = progressImage
        posX = posX.tostring()
        color = imgColor
        tooltip = ::loc("EveryDayLoginAward/periodAward", {period = period})
      })
    }

    if (!view.item.len())
      return

    local data = ::handyman.renderCached("gui/items/edlaProgressBarRewardIcon", view)
    guiScene.appendWithBlk(blockObj, data, this)
  }

  function onEventCrewTakeUnit(params)
  {
    goBack()
  }

  function sendOpenTrophyStatistic(obj)
  {
    local objId = obj?.id
    ::add_big_query_record("daily_trophy_screen",
      objId == "btn_open" ? "main_get_reward"
        : objId == "btn_nav_open" ? "navbar_get_reward"
        : "exit")
  }

  function initExpTexts() {
    if (!::has_feature("BattlePass"))
      return

    scene.findObject("today_login_exp").setValue(stashBhvValueConfig([{
      watch = todayLoginExp
      updateFunc = ::Callback(@(obj, value) updateTodayLoginExp(obj, value), this)
    }]))
    scene.findObject("login_streak_exp").setValue(stashBhvValueConfig([{
      watch = loginStreak
      updateFunc = ::Callback(@(obj, value) updateLoginStreakExp(obj, value), this)
    }]))
  }

  function updateExpTexts() {
    if (!::has_feature("BattlePass"))
      return

    updateTodayLoginExp(scene.findObject("today_login_exp"), todayLoginExp.value)
    updateLoginStreakExp(scene.findObject("login_streak_exp"), loginStreak.value)
  }

  function updateTodayLoginExp(obj, value) {
    local isVisible = value > 0 && !isOpened
    obj.show(isVisible)
    if (!isVisible)
      return

    obj.findObject("today_login_exp_text").setValue(
      ::loc("updStats/battlepass_exp", { amount = value }))
  }

  function updateLoginStreakExp(obj, value) {
    local isVisible = value > 0
      && (rouletteAnimationFinished || (isOpened && useSingleAnimation))
    obj.show(isVisible)
    if (!isVisible)
      return

    local rangeExpText = ::loc("ui/parentheses/space", {
      text = getExpRangeTextOfLoginStreak() })
    obj.findObject("text").setValue("".concat(::loc("battlePass/seasonLoginStreak",
      { amount = value }), rangeExpText))
  }
}
