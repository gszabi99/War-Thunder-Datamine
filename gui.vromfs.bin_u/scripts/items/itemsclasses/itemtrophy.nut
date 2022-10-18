from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { getPrizeChanceLegendMarkup } = require("%scripts/items/prizeChance.nut")
let { hoursToString, secondsToHours, getTimestampFromStringUtc,
  TIME_DAY_IN_SECONDS, TIME_WEEK_IN_SECONDS } = require("%scripts/time.nut")

::items_classes.Trophy <- class extends ::BaseItem
{
  static iType = itemType.TROPHY
  static defaultLocId = "trophy"
  static defaultIconStyle = "default_chest_debug"
  static typeIcon = "#ui/gameuiskin#item_type_trophies.svg"
  static isPreferMarkupDescInTooltip = true
  static userlogOpenLoc = "open_trophy"
  static hasTopRewardAsFirstItem = true

  canBuy = true

  showTypeInName = null // if undefined, false for items with custom localization, and true for items w/o custom localization.
  showRangePrize = false
  showCountryFlag = ""
  subtrophyShowAsPack = false

  allowBigPicture = false

  contentRaw = []
  contentUnpacked = []
  topPrize = null

  openingCaptionLocId = null
  instantOpening = false
  isGroupTrophy = false
  groupTrophyStyle = ""
  numTotal = -1
  showDropChance = false
  showTillValue = false
  showNameAsSingleAward = false

  beginDate = null
  endDate = null

  constructor(blk, invBlk = null, slotData = null)
  {
    base.constructor(blk, invBlk, slotData)

    subtrophyShowAsPack = blk?.subtrophyShowAsPack
    showTypeInName = blk?.showTypeInName
    showRangePrize = blk?.showRangePrize ?? false
    instantOpening = blk?.instantOpening ?? false
    showCountryFlag = blk?.showCountryFlag ?? ""
    numTotal = blk?.numTotal ?? 0
    isGroupTrophy = numTotal > 0 && !blk?.repeatable //for repeatable work as usual
    groupTrophyStyle = blk?.groupTrophyStyle ?? this.iconStyle
    openingCaptionLocId = blk?.captionLocId
    showDropChance = blk?.showDropChance ?? false
    showTillValue = blk?.showTillValue ?? false
    showNameAsSingleAward = blk?.showNameAsSingleAward ?? false

    if (blk?.beginDate && blk?.endDate) {
      beginDate = getTimestampFromStringUtc(blk.beginDate)
      endDate = getTimestampFromStringUtc(blk.endDate)
    }

    let blksArray = [blk]
    if (::u.isDataBlock(blk?.prizes))
      blksArray.insert(0, blk.prizes) //if prizes block exist, it's content must be shown in the first place

    contentRaw = []
    foreach (datablock in blksArray)
    {
      let content = datablock % "i"
      foreach (p in content)
      {
        let prize = ::DataBlock()
        prize.setFrom(p)

        let needMultiAwardInfo = p?.ranksRange != null && p?.resourceType != null && p.blockCount() == 0
        if (needMultiAwardInfo)
        {
          prize["multiAwardsOnWorthGold"] = 0
          prize.addBlock(p.resourceType).setFrom(p)
        }

        contentRaw.append(prize)
      }
    }
  }

  hasLifetime = @() beginDate != null
  hasLifetimeTimer = @() getRemainingLifetime() > 0

  function isEnabled() {
    if (!base.isEnabled())
      return false

    if (!hasLifetime())
      return true

    let curTime = ::get_charserver_time_sec()
    return beginDate <= curTime && curTime < endDate
  }

  function getRemainingLifetime() {
    if (!hasLifetime())
      return -1

    let curTime = ::get_charserver_time_sec()
    return curTime < beginDate || curTime >= endDate
      ? 0
      : endDate - curTime
  }

  function getRemainingLifetimeText() {
    let t = getRemainingLifetime()
    if (t == -1)
      return ""

    if (t == 0)
      return loc(this.itemExpiredLocId)

    let res = "".concat(
      loc("icon/hourglass"),
      ::nbsp,
      ::stringReplace(hoursToString(secondsToHours(t), false, true, true), " ", ::nbsp))

    return t <= TIME_DAY_IN_SECONDS  ? colorize("@red", res)
         : t <= TIME_WEEK_IN_SECONDS ? colorize("@itemSoonExpireColor", res)
         : res
  }

  function getSeenId() {
    let t = getRemainingLifetime()
    if (t == -1)
      return base.getSeenId()

    return t <= TIME_DAY_IN_SECONDS  ? $"{base.getSeenId()}_day"
         : t <= TIME_WEEK_IN_SECONDS ? $"{base.getSeenId()}_week"
         : base.getSeenId()
  }

  function needUnseenAlarmIcon() {
    let t = getRemainingLifetime()
    if (t == -1)
      return false
    if ((::get_trophy_info(this.id)?.openCount ?? 0) == 0)
      return false

    if (!(::getAircraftByName(getTopPrize()?.unit)?.isBought() ?? false))
      return false

    return t <= TIME_WEEK_IN_SECONDS
  }

  function getViewData(params = {}) {
    let res = base.getViewData(params)
    res.remainingLifetime <- getRemainingLifetimeText()
    return res
  }

  function _unpackContent(recursionUsedIds, useRecursion = true)
  {
    if (isInArray(this.id, recursionUsedIds))
    {
      log("id = " + this.id)
      debugTableData(recursionUsedIds)
      ::script_net_assert_once("trophy recursion",
                               "Infinite recursion detected in trophy: " + this.id + ". Array " + toString(recursionUsedIds))
      return null
    }

    recursionUsedIds.append(this.id)
    let content = []
    foreach (i in contentRaw)
    {
      if (!i?.trophy || i?.showAsPack)
      {
        content.append(i)
        continue
      }

      let subTrophy = ::ItemsManager.findItemById(i?.trophy)
      let countMul = i?.count ?? 1
      if (subTrophy)
      {
        if (getTblValue("subtrophyShowAsPack", subTrophy) || !useRecursion)
          content.append(i)
        else
        {
          let subContent = subTrophy.getContent(recursionUsedIds)
          foreach (sc in subContent)
          {
            let si = ::DataBlock()
            si.setFrom(sc)

            if (countMul != 1)
              si.count = (si?.count ?? 1) * countMul

            content.append(si)
          }
        }
      }
    }
    recursionUsedIds.pop()
    return content
  }

  function getContent(recursionUsedIds = [])
  {
    if (!contentUnpacked.len())
      contentUnpacked = _unpackContent(recursionUsedIds)
    return contentUnpacked
  }

  function getContentNoRecursion()
  {
    return _unpackContent([], false)
  }

  function _extractTopPrize(recursionUsedIds)
  {
    if (isInArray(this.id, recursionUsedIds))
    {
      log("id = " + this.id)
      debugTableData(recursionUsedIds)
      ::script_net_assert_once("trophy recursion",
                               "Infinite recursion detected in trophy: " + this.id + ". Array " + toString(recursionUsedIds))
      return
    }

    recursionUsedIds.append(this.id)
    local topPrizeBlk = null
    foreach(prize in contentRaw)
    {
      if (prize?.ignoreForTrophyType)
        continue

      if (prize?.trophy)
      {
        let subTrophy = ::ItemsManager.findItemById(prize.trophy)
        topPrizeBlk = subTrophy ? subTrophy.getTopPrize(recursionUsedIds) : null
      }
      else {
        topPrizeBlk = prize
      }

      if (topPrizeBlk != null) {
        topPrize = ::DataBlock()
        topPrize.setFrom(topPrizeBlk)
        topPrize.count = (prize?.count ?? 1) * (topPrize?.count ?? 1)
        break
      }
    }
    recursionUsedIds.pop()
  }

  function getTopPrize(recursionUsedIds = [])
  {
    if (!topPrize)
      _extractTopPrize(recursionUsedIds)
    return topPrize
  }

  function getCost(ignoreCanBuy = false)
  {
    if (this.isCanBuy() || ignoreCanBuy)
      return ::Cost(::wp_get_trophy_cost(this.id), ::wp_get_trophy_cost_gold(this.id))
    return ::Cost()
  }

  function getTrophyImage(id)
  {
    let layerStyle = ::LayersIcon.findLayerCfg(id)
    if (layerStyle)
      return ::LayersIcon.genDataFromLayer(layerStyle)

    return ::LayersIcon.getIconData(id, this.defaultIcon, 1.0, defaultIconStyle)
  }

  function getUsingStyle()
  {
    if (needOpenTrophyGroupOnBuy())
      return groupTrophyStyle
    return this.iconStyle
  }

  function getIcon(_addItemName = true)
  {
    return getTrophyImage(getUsingStyle())
  }

  function getBigIcon()
  {
    return getTrophyImage(getUsingStyle() + "_big")
  }

  function getOpenedIcon()
  {
    return getTrophyImage(getUsingStyle() + "_opened")
  }

  function getOpenedBigIcon()
  {
    return getTrophyImage(getUsingStyle() + "_opened_big")
  }

  function getName(colored = true)
  {
    let content = getContent()
    if (showNameAsSingleAward && content.len() == 1) {
      let awardCount = content[0]?.count ?? 1
      let awardType = ::PrizesView.getPrizeTypeName(content[0], false)
      return (awardCount > 1)
        ? loc("multiAward/name/count/singleType", { awardType, awardCount })
        : loc(awardType)
    }

    local name = this.locId ? "".join(::g_localization.getLocIdsArray(this.locId).map(@(id) loc(id))) : loc(("item/" + this.id), "")
    let hasCustomName = name != ""
    if (!hasCustomName)
      name = loc("item/" + defaultLocId)

    let showType = showTypeInName != null ? showTypeInName : !hasCustomName
    if (showType)
    {
      local prizeTypeName = ""
      if (showRangePrize)
        prizeTypeName = ::PrizesView.getPrizesListText(content)
      else
        prizeTypeName = ::PrizesView.getPrizeTypeName(getTopPrize(), colored)

      local comment = prizeTypeName.len() ? loc("ui/parentheses/space", { text = prizeTypeName }) : ""
      comment = colored ? colorize("commonTextColor", comment) : comment
      name += comment
    }
    return name
  }

  function getDescription()
  {
    return ::PrizesView.getPrizesListText(getContent(), _getDescHeader)
  }

  function _getDescHeader(fixedAmount = 1)
  {
    let locId = (fixedAmount > 1) ? "trophy/chest_contents/many" : "trophy/chest_contents"
    local headerText = loc(locId, { amount = colorize("commonTextColor", fixedAmount) })
    return colorize("grayOptionColor", headerText)
  }

  function getLongDescription()
  {
    return ""
  }

  function getLongDescriptionMarkup(params = null)
  {
    params = params || {}
    params.showAsTrophyContent <- true
    params.receivedPrizes <- false
    params.needShowDropChance <- needShowDropChance()

    return ::PrizesView.getPrizesStacksView(getContent(), _getDescHeader, params)
  }

  function getShortDescription(colored = true)
  {
    return getName(colored)
  }

  function getContentIconData()
  {
    if (showCountryFlag != "")
      return {
        contentIcon = ::get_country_icon(showCountryFlag)
        contentType = "flag"
      }

    local res = null
    let prize = getTopPrize()
    let icon = ::PrizesView.getPrizeTypeIcon(prize, true)
    if (icon == "")
      return res

    res = { contentIcon = icon }
    if (prize?.unit)
      res.contentType <- "unit"
    return res
  }

  function _requestBuy(params = {})
  {
    let blk = ::DataBlock()
    blk["name"] = this.id
    blk["index"] = getTblValue("index", params, -1)
    blk["cost"] = params.cost
    blk["costGold"] = params.costGold
    return ::char_send_blk("cln_buy_trophy", blk)
  }

  function getMainActionData(isShort = false, params = {})
  {
    if (!this.isInventoryItem && needOpenTrophyGroupOnBuy())
      return { btnName = loc("mainmenu/btnExpand") }

    return base.getMainActionData(isShort, params)
  }

  function doMainAction(cb, handler, params = null)
  {
    if (!this.isInventoryItem && needOpenTrophyGroupOnBuy())
      return ::gui_start_open_trophy_group_shop_wnd(this)
    return base.doMainAction(cb, handler, params)
  }

  function skipRoulette()
  {
    return instantOpening
  }

  function isAllowSkipOpeningAnim()
  {
    return true
  }

  function needOpenTrophyGroupOnBuy()
  {
    return isGroupTrophy && !::isHandlerInScene(::gui_handlers.TrophyGroupShopWnd)
  }

  function getOpeningCaption()
  {
    return loc(openingCaptionLocId || "mainmenu/trophyReward/title")
  }

  function getHiddenTopPrizeParams() { return null }
  function isHiddenTopPrize(_prize) { return false }

  needShowDropChance = @() hasFeature("ShowDropChanceInTrophy") && showDropChance

  function getTableData() {
    if (!needShowDropChance())
      return null

    let markup = getPrizeChanceLegendMarkup()
    if (markup == "")
      return null

    return markup
  }

  function getDescriptionAboveTable() {
    if (!showTillValue)
      return ""

    return ::PrizesView.getTrophyOpenCountTillPrize(getContent(), ::get_trophy_info(this.id))
  }

  function getDescriptionUnderTable() {
    let timeText = getRemainingLifetimeText()
    if (timeText == "")
      return timeText

    return "".concat(
      loc("items/expireTimeBeforeActivation"),
      loc("ui/colon"),
      colorize("activeTextColor", timeText))
  }

  canBuyTrophyByLimit = @() numTotal == 0 || numTotal > (::get_trophy_info(this.id)?.openCount ?? 0)
}
