local chooseAmountWnd = require("scripts/wndLib/chooseAmountWnd.nut")

class ::items_classes.Wager extends ::BaseItem
{
  static iType = itemType.WAGER
  static defaultLocId = "wager"
  static defaultIconStyle = "default_wager_debug"
  static typeIcon = "#ui/gameuiskin#item_type_wagers"
  static defaultWinIcon = "kills"
  static defaultTextType = "maxwins_text"

  static hasRecentItemConfirmMessageBox = false
  static isPreferMarkupDescInTooltip = true

  canBuy = true
  allowBigPicture = false

  winIcon = null
  reqWinsNum = 0
  rewardType = null

  minWager = 0
  wagerStep = 0
  maxWager = 0

  curWager = null

  static winCondParams = {
    bitListInValue = true
  }

  conditions = null // Conditions for battle.
  numWins = -1
  winConditions = null
  numBattles = null

  maxWins = 0
  maxFails = 0

  rewardDataTypes = [
    {
      name = "rpRewardParams"
      icon = "currency/researchPoints/sign/colored"
      shortName = "RP"
    }, {
      name = "freeRpRewardParams"
      icon = "currency/freeResearchPoints/sign/colored"
      shortName = "FRP"
    }, {
      name = "wpRewardParams"
      icon = "warpoints/short/colored"
      shortName = "WP"
    }, {
      name = "goldRewardParams"
      icon = "gold/short/colored"
      shortName = "G"
    }
  ]

  tableRowTypeByName = {
    selected = {
      showCheckedIcon = true
      color = "@userlogColoredText"
    }
    header = {}
    regular = {
      color = "@unlockActiveColor"
    }
    disabled = {
      color = "@grayOptionColor"
    }
  }

  winParamsData = null
  rewardData = null
  isGoldWager = false

  constructor(blk, invBlk = null, slotData = null)
  {
    base.constructor(blk, invBlk, slotData)
    if (isActive())
    {
      numWins = ::getTblValue("numWins", invBlk, 0)
      numBattles = ::getTblValue("numBattles", invBlk, 0)
      curWager = ::getTblValue("wager", invBlk, 0)
    }
    iconStyle = blk?.iconStyle ?? blk?.type ?? id
    _initWagerParams(blk?.wagerParams)
  }

  function _initWagerParams(blk)
  {
    if (!blk)
      return

    winIcon = getWinIcon(blk?.win)
    reqWinsNum = blk?.win?.num ?? 0
    rewardType = checkRewardType(blk)
    minWager = blk?.minWager ?? 0
    if (curWager == null)
      curWager = minWager
    wagerStep = blk?.wagerStep ?? 1
    maxWager = blk?.maxWager ?? 0
    maxWins = blk?.maxWins ?? 0
    maxFails = blk?.maxFails ?? 0
    if (blk?.active != null)
      conditions = ::UnlockConditions.loadConditionsFromBlk(blk.active)
    if (blk?.win != null)
      winConditions = ::UnlockConditions.loadConditionsFromBlk(blk.win)
    winParamsData = createWinParamsData(blk?.winParams)
    isGoldWager = ::getTblValue("goldWager", blk, false)
  }

  function getRewardDataTypeByName(name)
  {
    foreach (rewardDataType in rewardDataTypes)
    {
      if (rewardDataType.name == name)
        return rewardDataType
    }
    return null
  }

  /** Return reward data type name with highest priority. */
  function checkRewardType(blk)
  {
    if (blk?.winParams == null)
      return null
    local bestIndex = -1
    foreach(reward in blk.winParams % "reward")
    {
      foreach (index, rewardDataType in rewardDataTypes)
      {
        if (rewardDataType.name in reward)
          bestIndex = ::max(bestIndex, index)
      }
    }
    if (bestIndex == -1)
      return null
    return rewardDataTypes[bestIndex].name
  }

  function getRewardText(rewData, stakeValue)
  {
    local text = ""
    foreach (rewardDataTypeName, rewardParams in rewData.rewardParamsTable)
    {
      if (text != "")
        text += ", "
      local rewardDataType = getRewardDataTypeByName(rewardDataTypeName)
      local rewardValue = getRewardValueByNumWins(rewardParams, rewData.winCount, stakeValue)
      text += ::g_language.decimalFormat(rewardValue) + ::loc(rewardDataType.icon)
    }
    return text
  }

  /** Creates array with reward data objects sorted by param value. */
  function createWinParamsData(blk)
  {
    local res = []
    if (blk == null)
      return res
    foreach (reward in blk % "reward")
    {
      local rewData = createRewardData(reward)
      // No need to add empty rewards.
      if (!rewData.isEmpty)
        res.append(rewData)
    }
    res.sort(function (rd1, rd2)
    {
      if (rd1.winCount != rd2.winCount)
        return rd1.winCount < rd2.winCount ? -1 : 1
      return 0
    })
    return res
  }

  /** Returns closest reward data to specified param value. */
  function getRewardDataByParam(winCount, winParams)
  {
    if (winCount < 1 || winCount > maxWins)
      return null
    local res = null
    for (local i = 0; i < winParams.len(); ++i)
    {
      local nextRewardData = winParams[i]
      if (nextRewardData.winCount > winCount)
        break
      res = nextRewardData
    }
    return res
  }

  /** Creates object with data binding reward parameters to win count (param). */
  function createRewardData(blk)
  {
    if (blk == null || ::getTblValue("param", blk, 0) == 0)
      return {}
    local res = {
      winCount = blk.param
      rewardParamsTable = {}
      isEmpty = true
    }
    foreach (rewardDataType in rewardDataTypes)
    {
      local rewardDataTypeName = rewardDataType.name
      local p3 = ::getTblValue(rewardDataTypeName, blk, null)
      if (typeof(p3) != "instance" || !(p3 instanceof ::Point3))
        continue
      if (p3.x == 0 && p3.y == 0 && p3.z == 0)
        continue
      res.rewardParamsTable[rewardDataTypeName] <- {
        a = p3.x
        b = p3.y
        c = p3.z
        //iconName = ::LayersIcon.findLayerCfg(getBasePartOfLayerId(/*small*/true) + "_" + rewardDataTypeName)
      }
      res.isEmpty = false
    }
    return res
  }

  function getRewardValueByNumWins(rewardParams, winsNum, wagerValue)
  {
    return rewardParams.a * wagerValue * ::pow(winsNum, rewardParams.b) + rewardParams.c
  }

  function getWinIcon(winBlk)
  {
    if (!winBlk)
      return defaultWinIcon

    local iconName = winBlk?.type
    for(local i = 0; i < winBlk.paramCount(); i++)
    {
      local paramName = winBlk.getParamName(i)
      if (paramName != "unlock")
        continue
      local paramValue = winBlk.getParamValue(i)
      if (!::LayersIcon.findLayerCfg(getBasePartOfLayerId(false) + "_" + paramValue))
        continue

      iconName = paramValue
      break
    }

    return iconName
  }

  function getIcon(addItemName = true)
  {
    return getLayersData(true)
  }

  function getBigIcon()
  {
    return getIcon()
  }

  function getLayersData(small = true)
  {
    local layersData = ::LayersIcon.genDataFromLayer(_getBestRewardImage(small))
    layersData += _getWinIconData(small)

    local mainLayerCfg = _getBackground(small)
    return ::LayersIcon.genDataFromLayer(mainLayerCfg, layersData)
  }

  function getBasePartOfLayerId(small)
  {
    return iconStyle// + (small? "_shop" : "")
  }

  function _getBackground(small)
  {
    return ::LayersIcon.findLayerCfg(getBasePartOfLayerId(small))
  }

  function _getWinIconData(small)
  {
    if (!winIcon)
      return ""

    local layers = []

    if (reqWinsNum && reqWinsNum > 1)
    {
      local textLayerId = getBasePartOfLayerId(small) + "_" + defaultTextType
      local textLayerCfg = ::LayersIcon.findLayerCfg(textLayerId)
      if (textLayerCfg)
      {
        textLayerCfg.id <- textLayerId
        textLayerCfg.text <- reqWinsNum? reqWinsNum.tostring() : ""
        layers.append(textLayerCfg)
      }
    }

    local imageLayerCfg = ::LayersIcon.findLayerCfg(getBasePartOfLayerId(small) + "_" + winIcon)
    if (imageLayerCfg)
      layers.append(imageLayerCfg)
    else
    {
      imageLayerCfg = ::LayersIcon.findLayerCfg(getBasePartOfLayerId(small) + "_" + defaultWinIcon)
      if (imageLayerCfg)
        layers.append(imageLayerCfg)
    }

    return ::LayersIcon.genInsertedDataFromLayer(::LayersIcon.findLayerCfg("wager_place_container"), layers)
  }

  function _getBestRewardImage(small)
  {
    if (!rewardType)
      return

    return ::LayersIcon.findLayerCfg(getBasePartOfLayerId(small) + "_" + rewardType)
  }

  function getAvailableStakeText()
  {
    if (curWager >= 0)
      return ::loc("items/wager/name") + ::loc("ui/colon") + ::getPriceAccordingToPlayersCurrency(curWager, 0)
    return ::loc("items/wager/notAvailable")
  }

  function getItemTypeDescription(loc_params = {})
  {
    loc_params.maxWins <- maxWins
    loc_params.maxFails <- maxFails
    return base.getItemTypeDescription(loc_params)
  }

  function getDescription(customParams = {})
  {
    local desc = ""
    local customNumWins = ::getTblValue("numWins", customParams, numWins)

    if (isActive())
      desc += ::loc("items/wager/numWins", { numWins = customNumWins, maxWins = maxWins })
    else
      desc += ::loc("items/wager/maxWins", { maxWins = maxWins })
    desc += "\n"

    if (maxFails > 0)
    {
      if (numBattles == null)
        desc += ::loc("items/wager/maxFails", { maxFails = maxFails })
      else
      {
        local customNumFails = ::getTblValue("numFails", customParams, numBattles - customNumWins)
        desc += ::loc("items/wager/numFails", {
          numFails = customNumFails
          maxFails = maxFails
        })
      }
      desc += "\n"
    }

    local stakeText
    local costParam = {isWpAlwaysShown = true}
    if (isActive())
      stakeText =::Cost(curWager).toStringWithParams(costParam)
    else if (maxWager == 0)
      stakeText = ""
    else if (minWager == maxWager)
      stakeText = ::Cost(minWager).toStringWithParams(costParam)
    else
      stakeText = ::format("%s-%s",
        ::Cost(minWager).toStringWithParams(costParam),
        ::Cost(maxWager).toStringWithParams(costParam))
    if (stakeText != "")
      desc += ::loc("items/wager/stake", { stakeText = stakeText }) + "\n"

    local expireText = getCurExpireTimeText()
    if (expireText != "")
      desc += "\n" + expireText

    if (winConditions != null && winConditions.len() > 0
        && ::getTblValue("showLongMarkupPart", customParams, true))
    {
      if (desc != "")
        desc += "\n"
      desc += ::colorize("grayOptionColor", ::loc("items/wager/winConditions"))
      desc += "\n" + ::UnlockConditions.getConditionsText(winConditions, null, null, winCondParams)
      desc += "\n" + ::colorize("grayOptionColor", ::loc("items/wager/winConditions/caption"))
    }

    return desc
  }

  _needLongMarkup = null
  function isNeedLongMarkup()
  {
    if (_needLongMarkup != null)
      return _needLongMarkup

    if (winConditions)
    {
      local mainCond = ::UnlockConditions.getMainProgressCondition(winConditions)
      local modeType = mainCond && mainCond.modeType
      _needLongMarkup = (modeType == "unlocks" || modeType == "char_unlocks")
                        && ::getTblValue("typeLocIDWithoutValue", mainCond) == null
    } else
      _needLongMarkup = false
    return _needLongMarkup
  }

  function getLongDescription()
  {
    return getDescription({ showLongMarkupPart = !isNeedLongMarkup() })
  }

  function _getMainCondViewData(mainCond)
  {
    local modeType = mainCond.modeType
    if (modeType != "unlocks" && modeType != "char_unlocks")
      return { text = ::UnlockConditions._genMainConditionText(mainCond, null, null, winCondParams) }

    local values = mainCond.values

    if (values.len() == 1)
      return {
        text = ::UnlockConditions._genMainConditionText(mainCond, null, null, winCondParams)
        tooltipId = ::g_tooltip.getIdUnlock(values[0])
      }

    local res = { subTexts = [] }
    res.subTexts.append({ text = ::UnlockConditions._genMainConditionText(mainCond, "", null, winCondParams) + ::loc("ui/colon") })

    local locValues = ::UnlockConditions.getLocForBitValues(modeType, values)
    foreach(idx, value in locValues)
      res.subTexts.append({
        text = ::colorize("unlockActiveColor", value) + ((idx < values.len() - 1) ? ::loc("ui/comma") : "")
        tooltipId = ::g_tooltip.getIdUnlock(values[idx])
      })

    return res
  }

  function getLongDescriptionMarkup(params = null)
  {
    if (!isNeedLongMarkup())
      return ""

    local view = { rows = [] }

    view.rows.append({ text = ::colorize("grayOptionColor", ::loc("items/wager/winConditions")) })

    local mainCond = ::UnlockConditions.getMainProgressCondition(winConditions)
    if (mainCond)
      view.rows.append(_getMainCondViewData(mainCond))

    local usualCond = ::UnlockConditions.getConditionsText(winConditions, null, null, { withMainCondition = false })
    view.rows.append({ text = usualCond })
    view.rows.append({ text = ::colorize("grayOptionColor", ::loc("items/wager/winConditions/caption")) })
    return ::handyman.renderCached("gui/items/conditionsTexts", view)
  }

  function getDescriptionAboveTable()
  {
    local desc = ""
    if (winParamsData != null && winParamsData.len() > 0)
      desc += ::colorize("grayOptionColor", ::loc("items/wager/winParams")) + "\n"

    return desc
  }

  function getDescriptionUnderTable()
  {
    if (conditions == null || conditions.len() == 0)
      return ""
    return ::colorize("grayOptionColor", ::loc("items/wager/conditions")) +
      "\n" + ::UnlockConditions.getConditionsText(conditions)
  }

  function getMainActionData(isShort = false, params = {})
  {
    local res = base.getMainActionData(isShort, params)
    if (res)
      return res
    if (isInventoryItem && amount && !isActive() && curWager >= 0)
      return {
        btnName = ::loc("item/activate")
      }

    return null
  }

  getWagerCost = @(value) isGoldWager ? ::Cost(0, value) : ::Cost(value)

  function doMainAction(cb, handler, params = null)
  {
    local baseResult = base.doMainAction(cb, handler, params)
    if (baseResult || !isInventoryItem)
      return true

    if (isActive())
      return false

    if (minWager == maxWager || maxWager == 0)
      activate(minWager, cb)
    else
    {
      local item = this
      chooseAmountWnd.open({
        parentObj = params?.obj
        align = params?.align ?? "bottom"
        minValue = minWager
        maxValue = maxWager
        curValue = maxWager
        valueStep = wagerStep

        headerText = ::loc("items/wager/stake/header")
        buttonText = ::loc("items/wager/stake/button")
        getValueText = @(value) value ? item.getWagerCost(value).getTextAccordingToBalance() : "0"

        onAcceptCb = @(value) item.activate(value, cb)
        onCancelCb = null
      })
    }
    return true
  }

  function activate(wagerValue, cb)
  {
    if (!uids || !uids.len())
      return false

    if (getWagerCost(wagerValue) > ::get_gui_balance())
    {
      showNotEnoughMoneyMsgBox(cb)
      return false
    }

    if (::get_current_wager_uid() == "")
    {
      activateImpl(wagerValue, cb)
      return true
    }

    local bodyText = ::format(::loc("msgbox/conflictingWager"), getWagerDescriptionForMessageBox(uids[0]))
    bodyText += "\n" + getWagerDescriptionForMessageBox(::get_current_wager_uid())
    local item = this
    ::scene_msg_box("conflicting_wager_message_box", null, bodyText,
      [
        [ "continue", @() item.activateImpl(wagerValue, cb) ],
        [ "cancel", @() cb({success=false}) ]
      ],
      "cancel")
    return true
  }

  function sendTaskActivate(wagerValue, cb)
  {
    local blk = ::DataBlock()
    blk.setStr("name", uids[0])
    blk.setInt("wager", wagerValue)
    local taskId = ::char_send_blk("cln_set_current_wager", blk)

    local isTaskSend = ::g_tasker.addTask(taskId, { showProgressBox = true },
      @() cb({ success = true }), @(res) cb({ success = false }))
    if (!isTaskSend)
      cb({success=false})
  }

  hasGoldReward = @() rewardType == "goldRewardParams"
  function activateImpl(wagerValue, cb)
  {
    if (!isGoldWager && !hasGoldReward()) {
      sendTaskActivate(wagerValue, cb)
      return
    }

    local activateLocId = wagerValue > 0 ? "msgbox/wagerActivate/withCost" : "msgbox/wagerActivate"
    local bodyText = ::loc(activateLocId, {
      name = getWagerDescriptionForMessageBox(uids[0])
      cost = getWagerCost(wagerValue)
    })
    local item = this
    ::scene_msg_box("activate_wager_message_box", null, bodyText,
      [
        [ "yes", @() item.sendTaskActivate(wagerValue, cb) ],
        [ "no", @() cb({success=false}) ]
      ],
      "yes")
  }

  function getWagerDescriptionForMessageBox(uid)
  {
    local wager = ::ItemsManager.findItemByUid(uid, itemType.WAGER)
    return wager == null ? "" : wager.getShortDescription()
  }

  function showNotEnoughMoneyMsgBox(cb)
  {
    local bodyTextLocString = "msgbox/notEnoughMoneyWager/"
    bodyTextLocString += isGoldWager ? "gold" : "wp"
    local bodyText = ::loc(bodyTextLocString)
    ::scene_msg_box("not_enough_money_message_box", null, bodyText,
      [["ok", @() cb({success=false}) ]],
      "ok")
  }

  function getShortDescription(colored = true)
  {
    local desc = getName(colored)
    local descVars = []
    if (isActive())
      descVars.append(numWins + "/" + maxWins)

    if (numBattles != null)
      descVars.append(::colorize("badTextColor", (numBattles-numWins) + "/" + maxFails))

    if (descVars.len() > 0)
      desc += ::loc("ui/parentheses/space", { text = ::g_string.implode(descVars, ", ") })

    return desc
  }

  /*override*/ function getDescriptionTitle()
  {
    return getName()
  }

  function isActive(...)
  {
    return uids && ::isInArray(::get_current_wager_uid(), uids)
  }

  /*override*/ function getTableData()
  {
    if (winParamsData == null || winParamsData.len() == 0)
      return null
    local view = createTableDataView(winParamsData, numWins)
    return ::handyman.renderCached("gui/items/wagerRewardsTable", view)
  }

  function createTableDataView(winParams, winsNum)
  {
    local view = {
      rows = []
    }

    local headerView = clone tableRowTypeByName.header
    headerView.winCount <- ::loc("items/wager/table/winCount")
    if (minWager == maxWager || isActive())
      headerView.rewardText <- ::loc("items/wager/table/reward")
    else
    {
      headerView.rewardText <- ::loc("items/wager/table/atMinStake")
      headerView.secondaryRewardText <- ::loc("items/wager/table/atMaxStake")
    }
    view.rows.append(headerView)

    local previousRewardData = null
    local activeRowPlaced = false
    local needActiveRow = isActive() && winsNum != 0
    for (local i = 0; i < winParams.len(); ++i)
    {
      local rewData = winParams[i]
      if (rewData.winCount > winsNum && !activeRowPlaced && needActiveRow)
      {
        activeRowPlaced = true
        local activeRewardData = getRewardDataByParam(winsNum, winParams)
        view.rows.append(createRewardView("selected", activeRewardData, winsNum))
        previousRewardData = activeRewardData
      }
      local isMeActive = rewData.winCount == winsNum && !activeRowPlaced && needActiveRow
      // Skipping rows with equal reward data.
      if (!isMeActive && compareRewardData(previousRewardData, rewData))
        continue

      local rowTypeName
      if (isMeActive)
        rowTypeName = "selected"
      else if (rewData.winCount < winsNum)
        rowTypeName = "disabled"
      else
        rowTypeName = "regular"

      previousRewardData = rewData
      local rewardView = createRewardView(rowTypeName, rewData)
      view.rows.append(rewardView)
      if (isMeActive)
        activeRowPlaced = true
    }
    if (!activeRowPlaced && needActiveRow)
    {
      local activeRewardData = getRewardDataByParam(winsNum, winParams)
      view.rows.append(createRewardView("selected", activeRewardData, winsNum))
    }
    return view
  }

  function compareRewardData(rd1, rd2)
  {
    foreach (rewardDataType in rewardDataTypes)
    {
      local rp1 = rd1?.rewardParamsTable[rewardDataType.name]
      local rp2 = rd2?.rewardParamsTable[rewardDataType.name]
      if (rp1 == rp2)
        continue
      if (!rp1 || !rp2)
        return false
      if (rp1.a != rp2.a || rp1.b != rp2.b || rp1.c != rp2.c)
        return false
    }
    return true
  }

  /**
   * @param winsNum Useful when creating reward view for current wager progress.
   */
  function createRewardView(rowTypeName, rewData, winsNum = -1)
  {
    if (winsNum == -1)
      winsNum = rewData?.winCount ?? 0
    local view = (rowTypeName in tableRowTypeByName)
      ? clone tableRowTypeByName[rowTypeName]
      : {}
    view.winCount <- winsNum.tostring()
    if (isActive())
      view.rewardText <- rewData == null ? "" : getRewardText(rewData, curWager)
    else
    {
      view.rewardText <- rewData == null ? "" : getRewardText(rewData, minWager)
      if (minWager != maxWager)
        view.secondaryRewardText <- rewData == null ? "" : getRewardText(rewData, maxWager)
    }
    return view
  }

  /**
   * Returns false if player does not
   * have enough resources to make a stake.
   */
  function checkStake()
  {
    if (isGoldWager)
      return curWager <= ::get_cur_rank_info().gold
    return curWager <= ::get_cur_rank_info().wp
  }
}
