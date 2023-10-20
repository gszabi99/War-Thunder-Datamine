//-file:plus-string
from "%scripts/dagui_library.nut" import *


let bhvUnseen = require("%scripts/seen/bhvUnseen.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { fillItemDescr } = require("%scripts/items/itemVisual.nut")
let DataBlock = require("DataBlock")
let purchaseConfirmation = require("%scripts/purchase/purchaseConfirmationHandler.nut")

let WarbondAward = class {
  id = ""
  idx = 0
  awardType = ::g_wb_award_type[EWBAT_INVALID]
  warbondWeak = null
  blk = null
  ordinaryTasks = 0
  specialTasks = 0
  reqMaxUnitRank = -1

  //special params for award view
  needAllBoughtIcon = true
  imgNestDoubleSize = ""

  constructor(warbond, awardBlk, idxInWbList) {
    this.id = awardBlk?.name
    this.idx = idxInWbList
    this.warbondWeak = warbond.weakref()
    this.blk = DataBlock()
    this.blk.setFrom(awardBlk)
    this.awardType = ::g_wb_award_type.getTypeByBlk(this.blk)
    this.ordinaryTasks = this.blk?.Ordinary ?? 0
    this.specialTasks = this.blk?.Special ?? 0
    this.reqMaxUnitRank = this.blk?.reqMaxUnitRank ?? -1
    this.imgNestDoubleSize = this.awardType?.imgNestDoubleSize ?? "no"
  }

  canPreview = @() this.awardType.canPreview(this.blk)
  doPreview = @() this.awardType.doPreview(this.blk)

  function isValid() {
    return this.warbondWeak != null
  }

  function getFullId() {
    if (!this.warbondWeak)
      return ""
    return "".concat(this.warbondWeak.getFullId(), ::g_warbonds.FULL_ID_SEPARATOR, this.idx)
  }

  function getLayeredImage() {
    return this.awardType.getLayeredImage(this.blk, this.warbondWeak)
  }

  function getDescriptionImage() {
    return this.awardType.getDescriptionImage(this.blk, this.warbondWeak)
  }

  function getCost() {
    return this.blk?.cost ?? 0
  }

  function getCostText() {
    if (!this.warbondWeak)
      return ""
    return this.warbondWeak.getPriceText(this.getCost())
  }

  function canBuy() {
    return !this.isItemLocked() && this.awardType.canBuy(this.warbondWeak, this.blk)
  }

  function isItemLocked() {
    return !this.isValid()
       || !this.isAvailableForCurrentWarbondShop()
       || !this.isAvailableByShopLevel()
       || !this.isAvailableByMedalsCount()
       || !this.isAvailableByUnitsRank()
       || this.isAllBought()
  }

  function isAvailableForCurrentWarbondShop() {
    if (!this.warbondWeak || !(this.blk?.forCurrentShopOnly ?? false))
      return true
    return this.warbondWeak.isCurrent()
  }

  function getWarbondShopLevelImage() {
    if (!this.warbondWeak)
      return ""

    let level = this.warbondWeak.getShopLevel(this.ordinaryTasks)
    if (level == 0)
      return ""

    return ::g_warbonds_view.getLevelItemMarkUp(this.warbondWeak, level, "0")
  }

  function getWarbondMedalImage() {
    let medals = this.getMedalsCountNum()
    if (!this.warbondWeak || medals == 0)
      return ""

    return ::g_warbonds_view.getSpecialMedalsMarkUp(this.warbondWeak, medals)
  }

  function getBuyText(isShort = true) {
    let res = loc("mainmenu/btnBuy")
    if (isShort)
      return res

    let cost = this.getCost()
    let costText = this.warbondWeak ? this.warbondWeak.getPriceText(cost) : cost
    return res + ((costText == "") ? "" : loc("ui/parentheses/space", { text = costText }))
  }

  function buy() {
    if (!this.isValid())
      return
    if (!this.canBuy()) {
      local reason = loc("warbond/msg/alreadyBoughtMax", { purchase = colorize("userlogColoredText", this.getNameText()) })
      if (!this.isAvailableForCurrentWarbondShop())
        reason = this.getNotAvailableForCurrentShopText(false)
      else if (!this.awardType.canBuy(this.warbondWeak, this.blk))
        reason = this.getAwardTypeCannotBuyReason(false)
      else if (!this.isAvailableByShopLevel())
        reason = this.getRequiredShopLevelText(false)
      else if (!this.isAvailableByMedalsCount())
        reason = this.getRequiredMedalsLevelText(false)
      else if (!this.isAvailableByUnitsRank())
        reason = this.getRequiredUnitsRankLevel(false)
      return showInfoMsgBox(reason)
    }

    let costWb = this.getCost()
    let balanceWb = this.warbondWeak.getBalance()
    if (costWb > balanceWb)
      return showInfoMsgBox(loc("not_enough_currency",
                                    { currency = this.warbondWeak.getPriceText(costWb - balanceWb, true, false) }))


    let msgText = loc("onlineShop/needMoneyQuestion",
                          { purchase = colorize("userlogColoredText", this.getNameText()),
                            cost = colorize("activeTextColor", this.getCostText())
                          })
    purchaseConfirmation("purchase_ask", msgText, Callback(this._buy, this))
  }

  function _buy() {
    if (!this.isValid())
      return

    let taskId = this.awardType.requestBuy(this.warbondWeak, this.blk)
    let cb = Callback(this.onBought, this)
    ::g_tasker.addTask(taskId, { showProgressBox = true }, cb)
  }

  function onBought() {
    ::update_gamercards()
    broadcastEvent("WarbondAwardBought", { award = this })
  }

  function isAllBought() {
    if (!this.isValid())
      return false

    let maxBoughtCount = this.awardType.getMaxBoughtCount(this.warbondWeak, this.blk)
    return !this.awardType.hasIncreasingLimit && maxBoughtCount > 0
      && this.getLeftBoughtCount() == 0
  }

  function getAvailableAmountText() {
    if (!this.isValid())
      return ""

    let maxBoughtCount = this.awardType.getMaxBoughtCount(this.warbondWeak, this.blk)
    let hasIncreasingLimit = this.awardType.hasIncreasingLimit
    if (!hasIncreasingLimit && maxBoughtCount <= 0)
      return ""
    let leftAmount = this.getLeftBoughtCount()
    if (!hasIncreasingLimit && leftAmount == 0)
      return colorize("warningTextColor", loc("warbond/alreadyBoughtMax"))
    if (!this.awardType.showAvailableAmount)
      return ""
    return "".concat(loc("warbond/availableForPurchase"), loc("ui/colon"), leftAmount)
  }

  getLeftBoughtCount = @() this.isValid()
    ? max(this.awardType.getMaxBoughtCount(this.warbondWeak, this.blk) -  this.awardType.getBoughtCount(this.warbondWeak, this.blk), 0)
    : 0

  function addAmountTextToDesc(desc) {
    return "\n\n".join([
      "\n".join(this.getAdditionalTextsArray(), true),
      desc, this.getRequiredUnitsRankLevel()], true)
  }

  function getAdditionalTextsArray() {
    return [
      this.getNotAvailableForCurrentShopText(),
      this.getAwardTypeCannotBuyReason(),
      this.getRequiredShopLevelText(),
      this.getRequiredMedalsLevelText(),
      this.getAvailableAmountText()
    ]
  }

  function fillItemDesc(descObj, handler) {
    let item = this.awardType.getDescItem(this.blk)
    if (!item)
      return false

    descObj.scrollToView(true)
    fillItemDescr(item, descObj, handler, true, true,
                                 { descModifyFunc = this.addAmountTextToDesc.bindenv(this) })
    return true
  }

  function getDescText() {
    return this.addAmountTextToDesc(this.awardType.getDescText(this.blk))
  }

  function hasCommonDesc() { return this.awardType.hasCommonDesc }
  function getNameText()   { return this.awardType.getNameText(this.blk) }

  function haveOrdinaryRequirement() {
    return this.ordinaryTasks > 0
  }

  function haveSpecialRequirement() {
    return this.specialTasks > 0
  }

  function getShopLevelText(tasksNum) {
    if (!this.warbondWeak)
      return ""

    let level = this.warbondWeak.getShopLevel(tasksNum)
    return this.warbondWeak.getShopLevelText(level)
  }

  function isAvailableByShopLevel() {
    if (!this.haveOrdinaryRequirement())
      return true

    let shopLevel = this.warbondWeak ? this.warbondWeak.getShopLevel(this.ordinaryTasks) : 0
    let execTasks = this.warbondWeak ? this.warbondWeak.getCurrentShopLevel() : 0
    return shopLevel <= execTasks
  }

  function isAvailableByMedalsCount() {
    if (!this.haveSpecialRequirement())
      return true

    let curMedalsCount = this.warbondWeak ? this.warbondWeak.getCurrentMedalsCount() : 0
    let reqMedalsCount = this.getMedalsCountNum()
    return reqMedalsCount <= curMedalsCount
  }

  function isAvailableByUnitsRank() {
    if (this.reqMaxUnitRank <= 1 || this.reqMaxUnitRank > ::max_country_rank)
      return true

    return this.reqMaxUnitRank <= ::get_max_unit_rank()
  }

  function getMedalsCountNum() {
    return this.warbondWeak ? this.warbondWeak.getMedalsCount(this.specialTasks) : 0
  }

  function getAwardTypeCannotBuyReason(colored = true) {
    if (!this.isValid() || !this.isRequiredSpecialTasksComplete())
      return ""

    let text = loc(this.awardType.canBuyReasonLocId(this.warbondWeak, this.blk))
    return colored ? colorize("warningTextColor", text) : text
  }

  function isRequiredSpecialTasksComplete() {
    return this.isValid() && this.awardType.isReqSpecialTasks
      && !this.awardType.canBuy(this.warbondWeak, this.blk) && this.isAvailableForCurrentWarbondShop()
  }

  function getNotAvailableForCurrentShopText(colored = true) {
    if (this.isAvailableForCurrentWarbondShop())
      return ""

    let text = loc("warbonds/shop/notAvailableForCurrentShop")
    return colored ? colorize("badTextColor", text) : text
  }

  function getRequiredShopLevelText(colored = true) {
    if (!this.haveOrdinaryRequirement())
      return ""

    let text = loc("warbonds/shop/requiredLevel", {
      level = this.getShopLevelText(this.ordinaryTasks)
    })
    return this.isAvailableByShopLevel() || !colored ? text : colorize("badTextColor", text)
  }

  function getRequiredMedalsLevelText(colored = true) {
    if (!this.haveSpecialRequirement())
      return ""

    let text = loc("warbonds/shop/requiredMedals", {
      count = this.getMedalsCountNum()
    })
    return this.isAvailableByMedalsCount() || !colored ? text : colorize("badTextColor", text)
  }

  function getRequiredUnitsRankLevel(colored = true) {
    if (this.reqMaxUnitRank < 2)
      return ""

    let text = loc("warbonds/shop/requiredUnitRank", {
      unitRank = this.reqMaxUnitRank
    })
    return this.isAvailableByUnitsRank() || !colored ? text : colorize("badTextColor", text)
  }

  getSeenId = @() (this.isValid() ? (this.warbondWeak.getSeenId() + "_") : "") + this.id

  /******************* params override to use in item.tpl ***********************************/
  function modActionName() { return this.canBuy() ? this.getBuyText(true) : null }
  function price() { return this.getCostText() }
  function contentIconData() { return this.awardType.getContentIconData(this.blk) }
  function tooltipId() { return this.awardType.getTooltipId(this.blk, this.warbondWeak) }
  function amount() { return this.blk?.amount ?? 0 }
  function itemIndex() { return this.getFullId() }
  function headerText() { return this.awardType.getIconHeaderText(this.blk) }
  unseenIcon = @() !this.isItemLocked() && bhvUnseen.makeConfigStr(SEEN.WARBONDS_SHOP, this.getSeenId())
  /************************** end of params override ****************************************/
}

return { WarbondAward }