//-file:plus-string
from "%scripts/dagui_natives.nut" import char_send_blk, get_cur_rank_info, get_current_wager_uid
from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType

let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")
let { Cost } = require("%scripts/money.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { pow } = require("math")
let DataBlock  = require("DataBlock")
let { format } = require("string")
let { isPoint3 } = require("%sqStdLibs/helpers/u.nut")
let chooseAmountWnd = require("%scripts/wndLib/chooseAmountWnd.nut")
let { loadConditionsFromBlk, getMainProgressCondition } = require("%scripts/unlocks/unlocksConditions.nut")
let { getUnlockMainCondDesc, getUnlockCondsDesc, getLocForBitValues,
  getFullUnlockCondsDesc } = require("%scripts/unlocks/unlocksViewModule.nut")
let { decimalFormat } = require("%scripts/langUtils/textFormat.nut")
let { get_gui_balance } = require("%scripts/user/balance.nut")
let { addTask } = require("%scripts/tasker.nut")
let { BaseItem } = require("%scripts/items/itemsClasses/itemsBase.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")

let Wager = class (BaseItem) {
  static name = "Wager"
  static iType = itemType.WAGER
  static defaultLocId = "wager"
  static defaultIconStyle = "default_wager_debug"
  static typeIcon = "#ui/gameuiskin#item_type_wagers.svg"
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

  constructor(blk, invBlk = null, slotData = null) {
    base.constructor(blk, invBlk, slotData)
    if (this.isActive()) {
      this.numWins = getTblValue("numWins", invBlk, 0)
      this.numBattles = getTblValue("numBattles", invBlk, 0)
      this.curWager = getTblValue("wager", invBlk, 0)
    }
    this.iconStyle = blk?.iconStyle ?? blk?.type ?? this.id
    this._initWagerParams(blk?.wagerParams)
  }

  function _initWagerParams(blk) {
    if (!blk)
      return

    this.winIcon = this.getWinIcon(blk?.win)
    this.reqWinsNum = blk?.win?.num ?? 0
    this.rewardType = this.checkRewardType(blk)
    this.minWager = blk?.minWager ?? 0
    if (this.curWager == null)
      this.curWager = this.minWager
    this.wagerStep = blk?.wagerStep ?? 1
    this.maxWager = blk?.maxWager ?? 0
    this.maxWins = blk?.maxWins ?? 0
    this.maxFails = blk?.maxFails ?? 0
    if (blk?.active != null)
      this.conditions = loadConditionsFromBlk(blk.active)
    if (blk?.win != null)
      this.winConditions = loadConditionsFromBlk(blk.win)
    this.winParamsData = this.createWinParamsData(blk?.winParams)
    this.isGoldWager = getTblValue("goldWager", blk, false)
  }

  function getRewardDataTypeByName(name) {
    foreach (rewardDataType in this.rewardDataTypes) {
      if (rewardDataType.name == name)
        return rewardDataType
    }
    return null
  }

  /** Return reward data type name with highest priority. */
  function checkRewardType(blk) {
    if (blk?.winParams == null)
      return null
    local bestIndex = -1
    foreach (reward in blk.winParams % "reward") {
      foreach (index, rewardDataType in this.rewardDataTypes) {
        if (rewardDataType.name in reward)
          bestIndex = max(bestIndex, index)
      }
    }
    if (bestIndex == -1)
      return null
    return this.rewardDataTypes[bestIndex].name
  }

  function getRewardText(rewData, stakeValue) {
    local text = ""
    foreach (rewardDataTypeName, rewardParams in rewData.rewardParamsTable) {
      if (text != "")
        text += ", "
      let rewardDataType = this.getRewardDataTypeByName(rewardDataTypeName)
      let rewardValue = this.getRewardValueByNumWins(rewardParams, rewData.winCount, stakeValue)
      text += decimalFormat(rewardValue) + loc(rewardDataType.icon)
    }
    return text
  }

  /** Creates array with reward data objects sorted by param value. */
  function createWinParamsData(blk) {
    let res = []
    if (blk == null)
      return res
    foreach (reward in blk % "reward") {
      let rewData = this.createRewardData(reward)
      // No need to add empty rewards.
      if (!rewData.isEmpty)
        res.append(rewData)
    }
    res.sort(function (rd1, rd2) {
      if (rd1.winCount != rd2.winCount)
        return rd1.winCount < rd2.winCount ? -1 : 1
      return 0
    })
    return res
  }

  /** Returns closest reward data to specified param value. */
  function getRewardDataByParam(winCount, winParams) {
    if (winCount < 1 || winCount > this.maxWins)
      return null
    local res = null
    for (local i = 0; i < winParams.len(); ++i) {
      let nextRewardData = winParams[i]
      if (nextRewardData.winCount > winCount)
        break
      res = nextRewardData
    }
    return res
  }

  /** Creates object with data binding reward parameters to win count (param). */
  function createRewardData(blk) {
    if (blk == null || getTblValue("param", blk, 0) == 0)
      return {}
    let res = {
      winCount = blk.param
      rewardParamsTable = {}
      isEmpty = true
    }
    foreach (rewardDataType in this.rewardDataTypes) {
      let rewardDataTypeName = rewardDataType.name
      let p3 = getTblValue(rewardDataTypeName, blk, null)
      if (!isPoint3(p3))
        continue
      if (p3.x == 0 && p3.y == 0 && p3.z == 0)
        continue
      res.rewardParamsTable[rewardDataTypeName] <- {
        a = p3.x
        b = p3.y
        c = p3.z
        //iconName = LayersIcon.findLayerCfg(getBasePartOfLayerId(/*small*/true) + "_" + rewardDataTypeName)
      }
      res.isEmpty = false
    }
    return res
  }

  function getRewardValueByNumWins(rewardParams, winsNum, wagerValue) {
    return rewardParams.a * wagerValue * pow(winsNum, rewardParams.b) + rewardParams.c
  }

  function getWinIcon(winBlk) {
    if (!winBlk)
      return this.defaultWinIcon

    local iconName = winBlk?.type
    for (local i = 0; i < winBlk.paramCount(); i++) {
      let paramName = winBlk.getParamName(i)
      if (paramName != "unlock")
        continue
      let paramValue = winBlk.getParamValue(i)
      if (!LayersIcon.findLayerCfg(this.getBasePartOfLayerId(false) + "_" + paramValue))
        continue

      iconName = paramValue
      break
    }

    return iconName
  }

  function getIcon(_addItemName = true) {
    return this.getLayersData(true)
  }

  function getBigIcon() {
    return this.getIcon()
  }

  function getLayersData(small = true) {
    local layersData = LayersIcon.genDataFromLayer(this._getBestRewardImage(small))
    layersData += this._getWinIconData(small)

    let mainLayerCfg = this._getBackground(small)
    return LayersIcon.genDataFromLayer(mainLayerCfg, layersData)
  }

  function getBasePartOfLayerId(_small) {
    return this.iconStyle // + (small? "_shop" : "")
  }

  function _getBackground(small) {
    return LayersIcon.findLayerCfg(this.getBasePartOfLayerId(small))
  }

  function _getWinIconData(small) {
    if (!this.winIcon)
      return ""

    let layers = []

    if (this.reqWinsNum && this.reqWinsNum > 1) {
      let textLayerId = this.getBasePartOfLayerId(small) + "_" + this.defaultTextType
      let textLayerCfg = LayersIcon.findLayerCfg(textLayerId)
      if (textLayerCfg) {
        textLayerCfg.id <- textLayerId
        textLayerCfg.text <- this.reqWinsNum ? this.reqWinsNum.tostring() : ""
        layers.append(textLayerCfg)
      }
    }

    local imageLayerCfg = LayersIcon.findLayerCfg(this.getBasePartOfLayerId(small) + "_" + this.winIcon)
    if (imageLayerCfg)
      layers.append(imageLayerCfg)
    else {
      imageLayerCfg = LayersIcon.findLayerCfg(this.getBasePartOfLayerId(small) + "_" + this.defaultWinIcon)
      if (imageLayerCfg)
        layers.append(imageLayerCfg)
    }

    return LayersIcon.genInsertedDataFromLayer(LayersIcon.findLayerCfg("wager_place_container"), layers)
  }

  function _getBestRewardImage(small) {
    if (!this.rewardType)
      return

    return LayersIcon.findLayerCfg(this.getBasePartOfLayerId(small) + "_" + this.rewardType)
  }

  function getAvailableStakeText() {
    if (this.curWager >= 0)
      return loc("items/wager/name") + loc("ui/colon") + Cost(this.curWager).getTextAccordingToBalance()
    return loc("items/wager/notAvailable")
  }

  function getItemTypeDescription(loc_params = {}) {
    loc_params.maxWins <- this.maxWins
    loc_params.maxFails <- this.maxFails
    return base.getItemTypeDescription(loc_params)
  }

  function getDescription(customParams = {}) {
    local desc = ""
    let customNumWins = getTblValue("numWins", customParams, this.numWins)

    if (this.isActive())
      desc += loc("items/wager/numWins", { numWins = customNumWins, maxWins = this.maxWins })
    else
      desc += loc("items/wager/maxWins", { maxWins = this.maxWins })
    desc += "\n"

    if (this.maxFails > 0) {
      if (this.numBattles == null)
        desc += loc("items/wager/maxFails", { maxFails = this.maxFails })
      else {
        let customNumFails = getTblValue("numFails", customParams, this.numBattles - customNumWins)
        desc += loc("items/wager/numFails", {
          numFails = customNumFails
          maxFails = this.maxFails
        })
      }
      desc += "\n"
    }

    local stakeText
    let costParam = { isWpAlwaysShown = true }
    if (this.isActive())
      stakeText = Cost(this.curWager).toStringWithParams(costParam)
    else if (this.maxWager == 0)
      stakeText = ""
    else if (this.minWager == this.maxWager)
      stakeText = Cost(this.minWager).toStringWithParams(costParam)
    else
      stakeText = format("%s-%s",
        Cost(this.minWager).toStringWithParams(costParam),
        Cost(this.maxWager).toStringWithParams(costParam))
    if (stakeText != "")
      desc += loc("items/wager/stake", { stakeText = stakeText }) + "\n"

    let expireText = this.getCurExpireTimeText()
    if (expireText != "")
      desc += "\n" + expireText

    if (this.winConditions != null && this.winConditions.len() > 0
        && getTblValue("showLongMarkupPart", customParams, true)) {
      if (desc != "")
        desc += "\n"
      desc += colorize("grayOptionColor", loc("items/wager/winConditions"))
      desc += "\n" + getFullUnlockCondsDesc(this.winConditions, null, null, this.winCondParams)
      desc += "\n" + colorize("grayOptionColor", loc("items/wager/winConditions/caption"))
    }

    return desc
  }

  _needLongMarkup = null
  function isNeedLongMarkup() {
    if (this._needLongMarkup != null)
      return this._needLongMarkup

    if (this.winConditions) {
      let mainCond = getMainProgressCondition(this.winConditions)
      let modeType = mainCond && mainCond.modeType
      this._needLongMarkup = (modeType == "unlocks" || modeType == "char_unlocks")
                        && getTblValue("typeLocIDWithoutValue", mainCond) == null
    }
    else
      this._needLongMarkup = false
    return this._needLongMarkup
  }

  function getLongDescription() {
    return this.getDescription({ showLongMarkupPart = !this.isNeedLongMarkup() })
  }

  function _getMainCondViewData(mainCond) {
    let modeType = mainCond.modeType
    if (modeType != "unlocks" && modeType != "char_unlocks")
      return { text = getUnlockMainCondDesc(mainCond, null, null, this.winCondParams) }

    let values = mainCond.values

    if (values.len() == 1)
      return {
        text = getUnlockMainCondDesc(mainCond, null, null, this.winCondParams)
        tooltipId = getTooltipType("UNLOCK").getTooltipId(values[0])
      }

    let res = { subTexts = [] }
    res.subTexts.append({ text = getUnlockMainCondDesc(mainCond, "", null, this.winCondParams) + loc("ui/colon") })

    let locValues = getLocForBitValues(modeType, values)
    foreach (idx, value in locValues)
      res.subTexts.append({
        text = colorize("unlockActiveColor", value) + ((idx < values.len() - 1) ? loc("ui/comma") : "")
        tooltipId = getTooltipType("UNLOCK").getTooltipId(values[idx])
      })

    return res
  }

  function getLongDescriptionMarkup(_params = null) {
    if (!this.isNeedLongMarkup())
      return ""

    let view = { rows = [] }

    view.rows.append({ text = colorize("grayOptionColor", loc("items/wager/winConditions")) })

    let mainCond = getMainProgressCondition(this.winConditions)
    if (mainCond)
      view.rows.append(this._getMainCondViewData(mainCond))

    let usualCond = getUnlockCondsDesc(this.winConditions)
    view.rows.append({ text = usualCond })
    view.rows.append({ text = colorize("grayOptionColor", loc("items/wager/winConditions/caption")) })
    return handyman.renderCached("%gui/items/conditionsTexts.tpl", view)
  }

  function getDescriptionAboveTable() {
    local desc = ""
    if (this.winParamsData != null && this.winParamsData.len() > 0)
      desc += colorize("grayOptionColor", loc("items/wager/winParams")) + "\n"

    return desc
  }

  function getDescriptionUnderTable() {
    if (this.conditions == null || this.conditions.len() == 0)
      return ""
    return colorize("grayOptionColor", loc("items/wager/conditions")) +
      "\n" + getFullUnlockCondsDesc(this.conditions)
  }

  function getMainActionData(isShort = false, params = {}) {
    let res = base.getMainActionData(isShort, params)
    if (res)
      return res
    if (this.isInventoryItem && this.amount && !this.isActive() && this.curWager >= 0)
      return {
        btnName = loc("item/activate")
      }

    return null
  }

  getWagerCost = @(value) this.isGoldWager ? Cost(0, value) : Cost(value)

  function doMainAction(cb, handler, params = null) {
    let baseResult = base.doMainAction(cb, handler, params)
    if (baseResult || !this.isInventoryItem)
      return true

    if (this.isActive())
      return false

    if (this.minWager == this.maxWager || this.maxWager == 0)
      this.activate(this.minWager, cb)
    else {
      let item = this
      chooseAmountWnd.open({
        parentObj = params?.obj
        align = params?.align ?? "bottom"
        minValue = this.minWager
        maxValue = this.maxWager
        curValue = this.maxWager
        valueStep = this.wagerStep

        headerText = loc("items/wager/stake/header")
        buttonText = loc("items/wager/stake/button")
        getValueText = @(value) value ? item.getWagerCost(value).getTextAccordingToBalance() : "0"

        onAcceptCb = @(value) item.activate(value, cb)
        onCancelCb = null
      })
    }
    return true
  }

  function activate(wagerValue, cb) {
    if (!this.uids || !this.uids.len())
      return false

    if (this.getWagerCost(wagerValue) > get_gui_balance()) {
      this.showNotEnoughMoneyMsgBox(cb)
      return false
    }

    if (get_current_wager_uid() == "") {
      this.activateImpl(wagerValue, cb)
      return true
    }

    local bodyText = format(loc("msgbox/conflictingWager"), this.getWagerDescriptionForMessageBox(this.uids[0]))
    bodyText += "\n" + this.getWagerDescriptionForMessageBox(get_current_wager_uid())
    let item = this
    scene_msg_box("conflicting_wager_message_box", null, bodyText,
      [
        [ "continue", @() item.activateImpl(wagerValue, cb) ],
        [ "cancel", @() cb({ success = false }) ]
      ],
      "cancel")
    return true
  }

  function sendTaskActivate(wagerValue, cb) {
    let blk = DataBlock()
    blk.setStr("name", this.uids[0])
    blk.setInt("wager", wagerValue)
    let taskId = char_send_blk("cln_set_current_wager", blk)

    let isTaskSend = addTask(taskId, { showProgressBox = true },
      @() cb({ success = true }), @(_res) cb({ success = false }))
    if (!isTaskSend)
      cb({ success = false })
  }

  hasGoldReward = @() this.rewardType == "goldRewardParams"
  function activateImpl(wagerValue, cb) {
    if (!this.isGoldWager && !this.hasGoldReward()) {
      this.sendTaskActivate(wagerValue, cb)
      return
    }

    let activateLocId = wagerValue > 0 ? "msgbox/wagerActivate/withCost" : "msgbox/wagerActivate"
    let bodyText = loc(activateLocId, {
      name = this.getWagerDescriptionForMessageBox(this.uids[0])
      cost = this.getWagerCost(wagerValue)
    })
    let item = this
    scene_msg_box("activate_wager_message_box", null, bodyText,
      [
        [ "yes", @() item.sendTaskActivate(wagerValue, cb) ],
        [ "no", @() cb({ success = false }) ]
      ],
      "yes", { cancel_fn = @() cb({ success = false }) })
  }

  function getWagerDescriptionForMessageBox(uid) {
    let wager = ::ItemsManager.findItemByUid(uid, itemType.WAGER)
    return wager == null ? "" : wager.getShortDescription()
  }

  function showNotEnoughMoneyMsgBox(cb) {
    local bodyTextLocString = "msgbox/notEnoughMoneyWager/"
    bodyTextLocString += this.isGoldWager ? "gold" : "wp"
    let bodyText = loc(bodyTextLocString)
    scene_msg_box("not_enough_money_message_box", null, bodyText,
      [["ok", @() cb({ success = false }) ]],
      "ok")
  }

  function getShortDescription(colored = true) {
    local desc = this.getName(colored)
    let descVars = []
    if (this.isActive())
      descVars.append($"{this.numWins}/{this.maxWins}")

    if (this.numBattles != null)
      descVars.append(colorize("badTextColor", (this.numBattles - this.numWins) + "/" + this.maxFails))

    if (descVars.len() > 0)
      desc += loc("ui/parentheses/space", { text = ", ".join(descVars, true) })

    return desc
  }

  /*override*/ function getDescriptionTitle() {
    return this.getName()
  }

  function isActive(...) {
    return this.uids && isInArray(get_current_wager_uid(), this.uids)
  }

  /*override*/ function getTableData() {
    if (this.winParamsData == null || this.winParamsData.len() == 0)
      return null
    let view = this.createTableDataView(this.winParamsData, this.numWins)
    return handyman.renderCached("%gui/items/wagerRewardsTable.tpl", view)
  }

  function createTableDataView(winParams, winsNum) {
    let view = {
      rows = []
    }

    let headerView = clone this.tableRowTypeByName.header
    headerView.winCount <- loc("items/wager/table/winCount")
    if (this.minWager == this.maxWager || this.isActive())
      headerView.rewardText <- loc("items/wager/table/reward")
    else {
      headerView.rewardText <- loc("items/wager/table/atMinStake")
      headerView.secondaryRewardText <- loc("items/wager/table/atMaxStake")
    }
    view.rows.append(headerView)

    local previousRewardData = null
    local activeRowPlaced = false
    let needActiveRow = this.isActive() && winsNum != 0
    for (local i = 0; i < winParams.len(); ++i) {
      let rewData = winParams[i]
      if (rewData.winCount > winsNum && !activeRowPlaced && needActiveRow) {
        activeRowPlaced = true
        let activeRewardData = this.getRewardDataByParam(winsNum, winParams)
        view.rows.append(this.createRewardView("selected", activeRewardData, winsNum))
        previousRewardData = activeRewardData
      }
      let isMeActive = rewData.winCount == winsNum && !activeRowPlaced && needActiveRow
      // Skipping rows with equal reward data.
      if (!isMeActive && this.compareRewardData(previousRewardData, rewData))
        continue

      local rowTypeName
      if (isMeActive)
        rowTypeName = "selected"
      else if (rewData.winCount < winsNum)
        rowTypeName = "disabled"
      else
        rowTypeName = "regular"

      previousRewardData = rewData
      let rewardView = this.createRewardView(rowTypeName, rewData)
      view.rows.append(rewardView)
      if (isMeActive)
        activeRowPlaced = true
    }
    if (!activeRowPlaced && needActiveRow) {
      let activeRewardData = this.getRewardDataByParam(winsNum, winParams)
      view.rows.append(this.createRewardView("selected", activeRewardData, winsNum))
    }
    return view
  }

  function compareRewardData(rd1, rd2) {
    foreach (rewardDataType in this.rewardDataTypes) {
      let rp1 = rd1?.rewardParamsTable[rewardDataType.name]
      let rp2 = rd2?.rewardParamsTable[rewardDataType.name]
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
  function createRewardView(rowTypeName, rewData, winsNum = -1) {
    if (winsNum == -1)
      winsNum = rewData?.winCount ?? 0
    let view = (rowTypeName in this.tableRowTypeByName)
      ? clone this.tableRowTypeByName[rowTypeName]
      : {}
    view.winCount <- winsNum.tostring()
    if (this.isActive())
      view.rewardText <- rewData == null ? "" : this.getRewardText(rewData, this.curWager)
    else {
      view.rewardText <- rewData == null ? "" : this.getRewardText(rewData, this.minWager)
      if (this.minWager != this.maxWager)
        view.secondaryRewardText <- rewData == null ? "" : this.getRewardText(rewData, this.maxWager)
    }
    return view
  }

  /**
   * Returns false if player does not
   * have enough resources to make a stake.
   */
  function checkStake() {
    if (this.isGoldWager)
      return this.curWager <= get_cur_rank_info().gold
    return this.curWager <= get_cur_rank_info().wp
  }
}
return {Wager}