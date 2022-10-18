from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let bhvUnseen = require("%scripts/seen/bhvUnseen.nut")
let { fillItemDescr } = require("%scripts/items/itemVisual.nut")

::WarbondAward <- class
{
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

  constructor(warbond, awardBlk, idxInWbList)
  {
    id = awardBlk?.name
    idx = idxInWbList
    warbondWeak = warbond.weakref()
    blk = ::DataBlock()
    blk.setFrom(awardBlk)
    awardType = ::g_wb_award_type.getTypeByBlk(blk)
    ordinaryTasks = blk?.Ordinary ?? 0
    specialTasks = blk?.Special ?? 0
    reqMaxUnitRank = blk?.reqMaxUnitRank ?? -1
    imgNestDoubleSize = awardType?.imgNestDoubleSize ?? "no"
  }

  canPreview = @() awardType.canPreview(blk)
  doPreview = @() awardType.doPreview(blk)

  function isValid()
  {
    return warbondWeak != null
  }

  function getFullId()
  {
    if (!warbondWeak)
      return ""
    return warbondWeak.getFullId() + ::g_warbonds.FULL_ID_SEPARATOR + idx
  }

  function getLayeredImage()
  {
    return awardType.getLayeredImage(blk, warbondWeak)
  }

  function getDescriptionImage()
  {
    return awardType.getDescriptionImage(blk, warbondWeak)
  }

  function getCost()
  {
    return blk?.cost ?? 0
  }

  function getCostText()
  {
    if (!warbondWeak)
      return ""
    return warbondWeak.getPriceText(getCost())
  }

  function canBuy()
  {
    return !isItemLocked() && awardType.canBuy(warbondWeak, blk)
  }

  function isItemLocked()
  {
    return !isValid()
       || !isAvailableForCurrentWarbondShop()
       || !isAvailableByShopLevel()
       || !isAvailableByMedalsCount()
       || !isAvailableByUnitsRank()
       || isAllBought()
  }

  function isAvailableForCurrentWarbondShop()
  {
    if (!warbondWeak || !(blk?.forCurrentShopOnly ?? false))
      return true
    return warbondWeak.isCurrent()
  }

  function getWarbondShopLevelImage()
  {
    if (!warbondWeak)
      return ""

    let level = warbondWeak.getShopLevel(ordinaryTasks)
    if (level == 0)
      return ""

    return ::g_warbonds_view.getLevelItemMarkUp(warbondWeak, level, "0")
  }

  function getWarbondMedalImage()
  {
    let medals = getMedalsCountNum()
    if (!warbondWeak || medals == 0)
      return ""

    return ::g_warbonds_view.getSpecialMedalsMarkUp(warbondWeak, medals)
  }

  function getBuyText(isShort = true)
  {
    let res = loc("mainmenu/btnBuy")
    if (isShort)
      return res

    let cost = getCost()
    let costText = warbondWeak ? warbondWeak.getPriceText(cost) : cost
    return res + ((costText == "")? "" : loc("ui/parentheses/space", { text = costText }))
  }

  function buy()
  {
    if (!isValid())
      return
    if (!canBuy())
    {
      local reason = loc("warbond/msg/alreadyBoughtMax", { purchase = colorize("userlogColoredText", getNameText()) })
      if (!isAvailableForCurrentWarbondShop())
        reason = getNotAvailableForCurrentShopText(false)
      else if (!awardType.canBuy(warbondWeak, blk))
        reason = getAwardTypeCannotBuyReason(false)
      else if (!isAvailableByShopLevel())
        reason = getRequiredShopLevelText(false)
      else if (!isAvailableByMedalsCount())
        reason = getRequiredMedalsLevelText(false)
      else if (!isAvailableByUnitsRank())
        reason = getRequiredUnitsRankLevel(false)
      return ::showInfoMsgBox(reason)
    }

    let costWb = getCost()
    let balanceWb = warbondWeak.getBalance()
    if (costWb > balanceWb)
      return ::showInfoMsgBox(loc("not_enough_currency",
                                    { currency = warbondWeak.getPriceText(costWb - balanceWb, true, false) }))


    let msgText = loc("onlineShop/needMoneyQuestion",
                          { purchase = colorize("userlogColoredText", getNameText()),
                            cost = colorize("activeTextColor", getCostText())
                          })

    ::scene_msg_box("purchase_ask", null, msgText,
      [
        ["purchase", Callback(_buy, this) ],
        ["cancel", function() {} ]
      ],
      "purchase",
      { cancel_fn = function() {} }
    )
  }

  function _buy()
  {
    if (!isValid())
      return

    let taskId = awardType.requestBuy(warbondWeak, blk)
    let cb = Callback(onBought, this)
    ::g_tasker.addTask(taskId, {showProgressBox = true}, cb)
  }

  function onBought()
  {
    ::update_gamercards()
    ::broadcastEvent("WarbondAwardBought", { award = this })
  }

  function isAllBought()
  {
    if (!isValid())
      return false

    let maxBoughtCount = awardType.getMaxBoughtCount(warbondWeak, blk)
    return !awardType.hasIncreasingLimit() && maxBoughtCount > 0
      && getLeftBoughtCount() == 0
  }

  function getAvailableAmountText()
  {
    if (!isValid())
      return ""

    let maxBoughtCount = awardType.getMaxBoughtCount(warbondWeak, blk)
    let hasIncreasingLimit = awardType.hasIncreasingLimit()
    if (!hasIncreasingLimit && maxBoughtCount <= 0)
      return ""
    let leftAmount = getLeftBoughtCount()
    if (!hasIncreasingLimit && leftAmount == 0)
      return colorize("warningTextColor", loc("warbond/alreadyBoughtMax"))
    if (!awardType.showAvailableAmount)
      return ""
    return loc("warbond/availableForPurchase") + loc("ui/colon") + leftAmount
  }

  getLeftBoughtCount = @() isValid()
    ? max(awardType.getMaxBoughtCount(warbondWeak, blk) -  awardType.getBoughtCount(warbondWeak, blk), 0)
    : 0

  function addAmountTextToDesc(desc)
  {
    return ::g_string.implode([
      ::g_string.implode(getAdditionalTextsArray(), "\n"),
      desc, getRequiredUnitsRankLevel()], "\n\n")
  }

  function getAdditionalTextsArray()
  {
    return [
      getNotAvailableForCurrentShopText(),
      getAwardTypeCannotBuyReason(),
      getRequiredShopLevelText(),
      getRequiredMedalsLevelText(),
      getAvailableAmountText()
    ]
  }

  function fillItemDesc(descObj, handler)
  {
    let item = awardType.getDescItem(blk)
    if (!item)
      return false

    descObj.scrollToView(true)
    fillItemDescr(item, descObj, handler, true, true,
                                 { descModifyFunc = addAmountTextToDesc.bindenv(this) })
    return true
  }

  function getDescText()
  {
    return addAmountTextToDesc(awardType.getDescText(blk))
  }

  function hasCommonDesc() { return awardType.hasCommonDesc }
  function getNameText()   { return awardType.getNameText(blk) }

  function haveOrdinaryRequirement()
  {
    return ordinaryTasks > 0
  }

  function haveSpecialRequirement()
  {
    return specialTasks > 0
  }

  function getShopLevelText(tasksNum)
  {
    if (!warbondWeak)
      return ""

    let level = warbondWeak.getShopLevel(tasksNum)
    return warbondWeak.getShopLevelText(level)
  }

  function isAvailableByShopLevel()
  {
    if (!haveOrdinaryRequirement())
      return true

    let shopLevel = warbondWeak? warbondWeak.getShopLevel(ordinaryTasks) : 0
    let execTasks = warbondWeak? warbondWeak.getCurrentShopLevel() : 0
    return shopLevel <= execTasks
  }

  function isAvailableByMedalsCount()
  {
    if (!haveSpecialRequirement())
      return true

    let curMedalsCount = warbondWeak? warbondWeak.getCurrentMedalsCount() : 0
    let reqMedalsCount = getMedalsCountNum()
    return reqMedalsCount <= curMedalsCount
  }

  function isAvailableByUnitsRank()
  {
    if (reqMaxUnitRank <= 1 || reqMaxUnitRank > ::max_country_rank)
      return true

    return reqMaxUnitRank <= ::get_max_unit_rank()
  }

  function getMedalsCountNum()
  {
    return warbondWeak? warbondWeak.getMedalsCount(specialTasks) : 0
  }

  function getAwardTypeCannotBuyReason(colored = true)
  {
    if (!isValid() || !isRequiredSpecialTasksComplete())
      return ""

    let text = loc(awardType.canBuyReasonLocId(warbondWeak, blk))
    return colored? colorize("warningTextColor", text) : text
  }

  function isRequiredSpecialTasksComplete()
  {
    return isValid() && awardType.isReqSpecialTasks
      && !awardType.canBuy(warbondWeak, blk) && isAvailableForCurrentWarbondShop()
  }

  function getNotAvailableForCurrentShopText(colored = true)
  {
    if (isAvailableForCurrentWarbondShop())
      return ""

    let text = loc("warbonds/shop/notAvailableForCurrentShop")
    return colored? colorize("badTextColor", text) : text
  }

  function getRequiredShopLevelText(colored = true)
  {
    if (!haveOrdinaryRequirement())
      return ""

    let text = loc("warbonds/shop/requiredLevel", {
      level = getShopLevelText(ordinaryTasks)
    })
    return isAvailableByShopLevel() || !colored? text : colorize("badTextColor", text)
  }

  function getRequiredMedalsLevelText(colored = true)
  {
    if (!haveSpecialRequirement())
      return ""

    let text = loc("warbonds/shop/requiredMedals", {
      count = getMedalsCountNum()
    })
    return isAvailableByMedalsCount() || !colored? text : colorize("badTextColor", text)
  }

  function getRequiredUnitsRankLevel(colored = true)
  {
    if (reqMaxUnitRank < 2)
      return ""

    let text = loc("warbonds/shop/requiredUnitRank", {
      unitRank = reqMaxUnitRank
    })
    return isAvailableByUnitsRank() || !colored? text : colorize("badTextColor", text)
  }

  getSeenId = @() (isValid() ? (warbondWeak.getSeenId() + "_") : "") + id

  /******************* params override to use in item.tpl ***********************************/
  function modActionName() { return canBuy() ? getBuyText(true) : null }
  function price() { return getCostText() }
  function contentIconData() { return awardType.getContentIconData(blk) }
  function tooltipId() { return awardType.getTooltipId(blk, warbondWeak) }
  function amount() { return blk?.amount ?? 0 }
  function itemIndex() { return getFullId() }
  function headerText() { return awardType.getIconHeaderText(blk) }
  unseenIcon = @() !isItemLocked() && bhvUnseen.makeConfigStr(SEEN.WARBONDS_SHOP, getSeenId())
  /************************** end of params override ****************************************/
}
