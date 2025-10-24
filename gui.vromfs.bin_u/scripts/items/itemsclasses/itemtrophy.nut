from "%scripts/dagui_natives.nut" import char_send_blk, get_trophy_info, wp_get_trophy_cost, wp_get_trophy_cost_gold
from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import *

let { isHandlerInScene, handlersManager } = require("%sqDagui/framework/baseGuiHandlerManager.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")
let { Cost } = require("%scripts/money.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let DataBlock  = require("DataBlock")
let { getPrizeChanceLegendMarkup, getTrophyChancesData, isTrophyChancesCalculated } = require("%scripts/items/prizeChance.nut")
let { hoursToString, secondsToHours, getTimestampFromStringUtc, calculateCorrectTimePeriodYears,
  TIME_DAY_IN_SECONDS, TIME_WEEK_IN_SECONDS } = require("%scripts/time.nut")
let { getLocIdsArray } = require("%scripts/langUtils/localization.nut")
let { get_charserver_time_sec } = require("chard")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")
let { BaseItem } = require("%scripts/items/itemsClasses/itemsBase.nut")
let { roundToDigits } = require("%sqstd/math.nut")
let { registerItemClass } = require("%scripts/items/itemsTypeClasses.nut")
let { findItemById } = require("%scripts/items/itemsManagerModule.nut")
let { getPrizeTypeIcon, getPrizeTypeName, getTrophyOpenCountTillPrize, getPrizesListText,
  getPrizesStacksView
} = require("%scripts/items/prizesView.nut")
let { getPlayerCountryCode } = require("%scripts/user/countryUtils.nut")
let { openUrl } = require("%scripts/onlineShop/url.nut")

function fillContentRaw(contentRaw, blksArray) {
  foreach (datablock in blksArray) {
    let addContent = (datablock % "d").map(function(item) {
      let prize = DataBlock()
      prize.setFrom(item)
      prize.availableIfAllPrizesReceived = true
      return prize
    })

    let content = (datablock % "i").extend(addContent)
    foreach (p in content) {
      let prize = DataBlock()
      prize.setFrom(p)

      let needMultiAwardInfo = p?.ranksRange != null && p?.resourceType != null && p.blockCount() == 0
      if (needMultiAwardInfo) {
        prize["multiAwardsOnWorthGold"] = 0
        prize.addBlock(p.resourceType).setFrom(p)
      }

      contentRaw.append(prize)
    }
  }
}

let oneHundredPercentFloat = 100.0

let Trophy = class (BaseItem) {
  static iType = itemType.TROPHY
  static name = "Trophy"
  static defaultLocId = "trophy"
  static defaultIconStyle = "default_chest_debug"
  static typeIcon = "#ui/gameuiskin#item_type_trophies.svg"
  static isPreferMarkupDescInTooltip = true
  static userlogOpenLoc = "open_trophy"
  static hasTopRewardAsFirstItem = true

  canBuy = true

  showTypeInName = null 
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
  showChances = false
  showTillValue = false
  showNameAsSingleAward = false
  isCrossPromo = false
  hasBtnLinkToChances = false

  beginDate = null
  endDate = null

  constructor(blk, invBlk = null, slotData = null) {
    base.constructor(blk, invBlk, slotData)
    this.subtrophyShowAsPack = blk?.subtrophyShowAsPack
    this.showTypeInName = blk?.showTypeInName
    this.showRangePrize = blk?.showRangePrize ?? false
    this.instantOpening = blk?.instantOpening ?? false
    this.showCountryFlag = blk?.showCountryFlag ?? ""
    this.numTotal = blk?.numTotal ?? 0
    this.isGroupTrophy = this.numTotal > 0 && !blk?.repeatable 
    this.groupTrophyStyle = blk?.groupTrophyStyle ?? this.iconStyle
    this.openingCaptionLocId = blk?.captionLocId
    this.showDropChance = blk?.showDropChance ?? false
    this.showTillValue = blk?.showTillValue ?? false
    this.showNameAsSingleAward = blk?.showNameAsSingleAward ?? false
    this.isCrossPromo = blk?.isCrossPromo
    let needShowChancesInCountries = blk?.showChancesInCountries.split(",")
    this.showChances = blk?.showChances || (needShowChancesInCountries?.indexof(getPlayerCountryCode()) != null)

    let showChanceLinkInCountries = this.showChances ? blk?.showChancesLinkInCountries.split(",") : null
    this.hasBtnLinkToChances = showChanceLinkInCountries?.contains(getPlayerCountryCode()) ?? false

    if (blk?.beginDate && blk?.endDate) {
      let { startTime, endTime } = calculateCorrectTimePeriodYears(
        getTimestampFromStringUtc(blk.beginDate),
        getTimestampFromStringUtc(blk.endDate))
      this.beginDate = startTime
      this.endDate = endTime
    }

    let blksArray = [blk]
    if (u.isDataBlock(blk?.prizes))
      blksArray.insert(0, blk.prizes) 

    this.contentRaw = []
    fillContentRaw(this.contentRaw, blksArray)
  }

  hasLifetime = @() this.beginDate != null
  hasLifetimeTimer = @() this.getRemainingLifetime() > 0

  function isEnabled() {
    if (!base.isEnabled())
      return false

    if (!this.hasLifetime())
      return true

    let curTime = get_charserver_time_sec()
    return this.beginDate <= curTime && curTime < this.endDate
  }

  function needProbabilityInfoBtn() {
    return this.hasBtnLinkToChances
  }

  function openProbabilityInfo() {
    let probabilityInfoLink = $"https://warthunder.com/ko/community/boxes/{this.id}"
    openUrl(probabilityInfoLink, this.forceExternalBrowser, false, this.linkBigQueryKey)
  }

  function getRemainingLifetime() {
    if (!this.hasLifetime())
      return -1

    let curTime = get_charserver_time_sec()
    return curTime < this.beginDate || curTime >= this.endDate
      ? 0
      : this.endDate - curTime
  }

  function getRemainingLifetimeText() {
    let t = this.getRemainingLifetime()
    if (t == -1)
      return ""

    if (t == 0)
      return loc(this.itemExpiredLocId)

    let res = "".concat(
      loc("icon/hourglass"),
      nbsp,
      hoursToString(secondsToHours(t), false, true, true).replace(" ", nbsp))

    return t <= TIME_DAY_IN_SECONDS  ? colorize("@red", res)
         : t <= TIME_WEEK_IN_SECONDS ? colorize("@itemSoonExpireColor", res)
         : res
  }

  function getSeenId() {
    let t = this.getRemainingLifetime()
    if (t == -1)
      return base.getSeenId()

    return t <= TIME_DAY_IN_SECONDS  ? $"{base.getSeenId()}_day"
         : t <= TIME_WEEK_IN_SECONDS ? $"{base.getSeenId()}_week"
         : base.getSeenId()
  }

  function isPrizeUnitBought() {
    local res = false
    let itemList = this.getContent()

    if (itemList.len() == 0)
      return res

    foreach(item in itemList) {
      if (!item?.unit)
        continue

      let unit = getAircraftByName(item.unit)
      res = unit?.isBought() ?? false
      if (!res)
        break
    }
    return res
  }

  function needUnseenAlarmIcon() {
    let t = this.getRemainingLifetime()
    if (t == -1)
      return false
    if ((get_trophy_info(this.id)?.openCount ?? 0) == 0)
      return false

    return this.isPrizeUnitBought() && t <= TIME_WEEK_IN_SECONDS
  }

  function getViewData(params = {}) {
    let res = base.getViewData(params)
    res.remainingLifetime <- this.getRemainingLifetimeText()
    return res
  }

  function _unpackContent(recursionUsedIds, useRecursion = true) {
    if (isInArray(this.id, recursionUsedIds)) {
      log($"id = {this.id}")
      debugTableData(recursionUsedIds)
      script_net_assert_once("trophy recursion",
        $"Infinite recursion detected in trophy: {this.id}. Array {toString(recursionUsedIds)}")
      return null
    }

    recursionUsedIds.append(this.id)
    let content = []
    foreach (i in this.contentRaw) {
      if (!i?.trophy || i?.showAsPack) {
        content.append(i)
        continue
      }

      let subTrophy = findItemById(i?.trophy)
      let countMul = i?.count ?? 1
      if (subTrophy) {
        if (getTblValue("subtrophyShowAsPack", subTrophy) || !useRecursion)
          content.append(i)
        else {
          let subContent = subTrophy.getContent(recursionUsedIds)
          foreach (sc in subContent) {
            let si = DataBlock()
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

  function _unpackContentWithChances(recursionUsedIds, useRecursion = true, openCount = 0) {
    if (isInArray(this.id, recursionUsedIds)) {
      log($"id = {this.id}")
      debugTableData(recursionUsedIds)
      script_net_assert_once("trophy recursion",
        $"Infinite recursion detected in trophy: {this.id}. Array {toString(recursionUsedIds)}")
      return null
    }

    recursionUsedIds.append(this.id)

    let blkWithChances = getTrophyChancesData(this.id, { prevOpencount = openCount })
    if (!blkWithChances) {
      logerr($"Didn't found trophie's prize chances for id = {this.id}")
      return null
    }
    let blksArray = [blkWithChances]
    if (u.isDataBlock(blkWithChances?.prizes))
      blksArray.insert(0, blkWithChances.prizes)

    let contentRawWithPrize = []
    fillContentRaw(contentRawWithPrize, blksArray)

    let contentWithChances = []
    foreach (i in contentRawWithPrize) {
      let percentStr = $"{roundToDigits((i?.percent ?? 0) / oneHundredPercentFloat, 3)}%"
      if (i?.percent != null && i.percent >= 0)
        i.percentStr = percentStr
      if (!i?.trophy || i?.showAsPack) {
        contentWithChances.append(i)
        continue
      }

      let trophyPercent = (i?.percent ?? 0) / oneHundredPercentFloat
      let subTrophy = findItemById(i?.trophy)
      let countMul = i?.count ?? 1
      if (subTrophy) {
        if (getTblValue("subtrophyShowAsPack", subTrophy) || !useRecursion)
          contentWithChances.append(i)
        else {
          let subContent = subTrophy.getContent(recursionUsedIds, true)
          foreach (sc in subContent) {
            let si = DataBlock()
            si.setFrom(sc)

            if (countMul != 1)
              si.count = (si?.count ?? 1) * countMul

            if (si?.percent != null && si.percent >= 0) {
              let siPercent = si.percent / oneHundredPercentFloat
              let siPercentStr = roundToDigits(trophyPercent * siPercent / oneHundredPercentFloat , 3)
              si.percentStr = $"{siPercentStr}%"
            }
            contentWithChances.append(si)
          }
        }
      }
    }
    recursionUsedIds.pop()
    return contentWithChances
  }

  function getContent(recursionUsedIds = [], showChances = null) {
    showChances = showChances ?? this.showChances
    if (!showChances) {
      if (!this.contentUnpacked.len())
        this.contentUnpacked = this._unpackContent(recursionUsedIds)
      return this.contentUnpacked
    }

    let openCount = get_trophy_info(this.id)?.openCount ?? 0
    if (!isTrophyChancesCalculated(this.id, openCount))
      this.contentUnpacked = this._unpackContentWithChances(recursionUsedIds, true, openCount)
    return this.contentUnpacked
  }

  function getContentNoRecursion() {
    return this._unpackContent([], false)
  }

  function _extractTopPrize(recursionUsedIds) {
    if (isInArray(this.id, recursionUsedIds)) {
      log($"id = {this.id}")
      debugTableData(recursionUsedIds)
      script_net_assert_once("trophy recursion",
        $"Infinite recursion detected in trophy: {this.id}. Array {toString(recursionUsedIds)}")
      return
    }

    recursionUsedIds.append(this.id)
    local topPrizeBlk = null
    foreach (prize in this.contentRaw) {
      if (prize?.ignoreForTrophyType)
        continue

      if (prize?.trophy) {
        let subTrophy = findItemById(prize.trophy)
        topPrizeBlk = subTrophy ? subTrophy.getTopPrize(recursionUsedIds) : null
      }
      else {
        topPrizeBlk = prize
      }

      if (topPrizeBlk != null) {
        this.topPrize = DataBlock()
        this.topPrize.setFrom(topPrizeBlk)
        this.topPrize.count = (prize?.count ?? 1) * (this.topPrize?.count ?? 1)
        break
      }
    }
    recursionUsedIds.pop()
  }

  function getTopPrize(recursionUsedIds = []) {
    if (!this.topPrize)
      this._extractTopPrize(recursionUsedIds)
    return this.topPrize
  }

  function getCost(ignoreCanBuy = false) {
    if (this.isCanBuy() || ignoreCanBuy)
      return Cost(wp_get_trophy_cost(this.id), wp_get_trophy_cost_gold(this.id))
    return Cost()
  }

  function getTrophyImage(id) {
    let layerStyle = LayersIcon.findLayerCfg(id)
    if (layerStyle)
      return LayersIcon.genDataFromLayer(layerStyle)

    return LayersIcon.getIconData(id, this.defaultIcon, 1.0, this.defaultIconStyle)
  }

  function getUsingStyle() {
    if (this.needOpenTrophyGroupOnBuy())
      return this.groupTrophyStyle
    return this.iconStyle
  }

  function getIcon(_addItemName = true) {
    return this.getTrophyImage(this.getUsingStyle())
  }

  function getBigIcon() {
    return this.getTrophyImage($"{this.getUsingStyle()}_big")
  }

  function getOpenedIcon() {
    return this.getTrophyImage($"{this.getUsingStyle()}_opened")
  }

  function getOpenedBigIcon() {
    return this.getTrophyImage($"{this.getUsingStyle()}_opened_big")
  }

  function getName(colored = true) {
    let content = this.getContent()
    if (this.showNameAsSingleAward && content.len() == 1) {
      let awardCount = content[0]?.count ?? 1
      let awardType = getPrizeTypeName(content[0], false)
      return (awardCount > 1)
        ? loc("multiAward/name/count/singleType", { awardType, awardCount })
        : loc(awardType)
    }

    local name = this.locId ? "".join(getLocIdsArray(this.locId).map(@(id) loc(id))) : loc(($"item/{this.id}"), "")
    let hasCustomName = name != ""
    if (!hasCustomName)
      name = loc($"item/{this.defaultLocId}")

    let showType = this.showTypeInName != null ? this.showTypeInName : !hasCustomName
    if (showType) {
      local prizeTypeName = ""
      if (this.showRangePrize)
        prizeTypeName = getPrizesListText(content)
      else
        prizeTypeName = getPrizeTypeName(this.getTopPrize(), colored)

      local comment = prizeTypeName.len() ? loc("ui/parentheses/space", { text = prizeTypeName }) : ""
      comment = colored ? colorize("commonTextColor", comment) : comment
      name = $"{name}{comment}"
    }
    return name
  }

  function getDescription() {
    return getPrizesListText(this.getContent(), this._getDescHeader)
  }

  function _getDescHeader(fixedAmount = 1) {
    let locId = (fixedAmount > 1) ? "trophy/chest_contents/many" : "trophy/chest_contents"
    local headerText = loc(locId, { amount = colorize("commonTextColor", fixedAmount) })
    return colorize("grayOptionColor", headerText)
  }

  function getLongDescription() {
    return ""
  }

  function getLongDescriptionMarkup(params = null) {
    params = params ?? {}
    params.showAsTrophyContent <- true
    params.receivedPrizes <- false
    params.dropChanceType <- this.getDropChanceType()
    params.needShowChance <- this.showChances && !params?.needHideChances

    let prizesList = this.getContent()
    let mainPrizes = prizesList.filter(@(prize) !prize?.availableIfAllPrizesReceived)
    let additionalPrizes = prizesList.filter(@(prize) !!prize?.availableIfAllPrizesReceived)
    local additionalPrizesMarkup = ""
    if (additionalPrizes.len() > 0) {
      let getHeader = @(...) colorize("grayOptionColor", loc("items/ifYouHaveAllItemsAbove"))
      additionalPrizesMarkup = getPrizesStacksView(additionalPrizes, getHeader)
    }
    let mainPrizesMarkup = getPrizesStacksView(mainPrizes, this._getDescHeader, params)

    return  $"{mainPrizesMarkup}{additionalPrizesMarkup}"
  }

  function getShortDescription(colored = true) {
    return this.getName(colored)
  }

  function getContentIconData() {
    if (this.showCountryFlag != "")
      return {
        contentIcon = getCountryIcon(this.showCountryFlag)
        contentType = "flag"
      }

    local res = null
    let prize = this.getTopPrize()
    let icon = getPrizeTypeIcon(prize, true)
    if (icon == "")
      return res

    res = { contentIcon = icon }
    if (prize?.unit)
      res.contentType <- "unit"
    return res
  }

  function _requestBuy(params = {}) {
    let blk = DataBlock()
    blk["name"] = this.id
    blk["index"] = getTblValue("index", params, -1)
    blk["cost"] = params.cost
    blk["costGold"] = params.costGold
    return char_send_blk("cln_buy_trophy", blk)
  }

  function getMainActionData(isShort = false, params = {}) {
    if (!this.isInventoryItem && this.needOpenTrophyGroupOnBuy())
      return { btnName = loc("mainmenu/btnExpand") }

    return base.getMainActionData(isShort, params)
  }

  function doMainAction(cb, handler, params = null) {
    if (!this.isInventoryItem && this.needOpenTrophyGroupOnBuy())
      return handlersManager.loadHandler(gui_handlers.TrophyGroupShopWnd, { trophy = this })


    if (this.isPrizeUnitBought()) {
      scene_msg_box("prize_unit_bought", null, loc(this.getLocIdsList().vehicleAlreadyBought),
        [["ok"]], "ok")
      return
    }

    return base.doMainAction(cb, handler, params)
  }

  function skipRoulette() {
    return this.instantOpening
  }

  function isAllowSkipOpeningAnim() {
    return true
  }

  function needOpenTrophyGroupOnBuy() {
    return this.isGroupTrophy && !isHandlerInScene(gui_handlers.TrophyGroupShopWnd)
  }

  function getOpeningCaption() {
    return loc(this.openingCaptionLocId ?? "mainmenu/trophyReward/title")
  }

  function getHiddenTopPrizeParams() { return null }
  function isHiddenTopPrize(_prize) { return false }

  function needShowTextChances() {
    return this.showChances
  }

  function getDropChanceType() {
    if (this.needShowTextChances())
      return CHANCE_VIEW_TYPE.TEXT
    if (hasFeature("ShowDropChanceInTrophy") && this.showDropChance)
     return CHANCE_VIEW_TYPE.ICON
    return CHANCE_VIEW_TYPE.NONE
  }

  function getTableData() {
    if (this.getDropChanceType() != CHANCE_VIEW_TYPE.ICON)
      return null

    let markup = getPrizeChanceLegendMarkup()
    if (markup == "")
      return null

    return markup
  }

  function getDescriptionAboveTable() {
    if (!this.showTillValue)
      return ""

    return getTrophyOpenCountTillPrize(this.getContent(), get_trophy_info(this.id))
  }

  function getDescriptionUnderTable() {
    let timeText = this.getRemainingLifetimeText()
    if (timeText == "")
      return timeText
    return loc("mainmenu/timeForBuyTrophy" { time = colorize("activeTextColor", timeText) })
  }

  canBuyTrophyByLimit = @() this.numTotal == 0 || this.numTotal > (get_trophy_info(this.id)?.openCount ?? 0)
}

registerItemClass(Trophy)
