local { getPrizeChanceLegendMarkup } = require("scripts/items/prizeChance.nut")

class ::items_classes.Trophy extends ::BaseItem
{
  static iType = itemType.TROPHY
  static defaultLocId = "trophy"
  static defaultIconStyle = "default_chest_debug"
  static typeIcon = "#ui/gameuiskin#item_type_trophies"
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
    groupTrophyStyle = blk?.groupTrophyStyle ?? iconStyle
    openingCaptionLocId = blk?.captionLocId
    showDropChance = blk?.showDropChance ?? false
    showTillValue = blk?.showTillValue ?? false
    showNameAsSingleAward = blk?.showNameAsSingleAward ?? false

    local blksArray = [blk]
    if (::u.isDataBlock(blk?.prizes))
      blksArray.insert(0, blk.prizes) //if prizes block exist, it's content must be shown in the first place

    contentRaw = []
    foreach (datablock in blksArray)
    {
      local content = datablock % "i"
      foreach (_prize in content)
      {
        local prize = ::DataBlock()
        prize.setFrom(_prize)
        contentRaw.append(prize)
      }
    }
  }

  function _unpackContent(recursionUsedIds, useRecursion = true)
  {
    if (::isInArray(id, recursionUsedIds))
    {
      ::dagor.debug("id = " + id)
      ::debugTableData(recursionUsedIds)
      ::script_net_assert_once("trophy recursion",
                               "Infinite recursion detected in trophy: " + id + ". Array " + ::toString(recursionUsedIds))
      return null
    }

    recursionUsedIds.append(id)
    local content = []
    foreach (i in contentRaw)
    {
      if (!i?.trophy || i?.showAsPack)
      {
        content.append(i)
        continue
      }

      local subTrophy = ::ItemsManager.findItemById(i?.trophy)
      local countMul = i?.count ?? 1
      if (subTrophy)
      {
        if (::getTblValue("subtrophyShowAsPack", subTrophy) || !useRecursion)
          content.append(i)
        else
        {
          local subContent = subTrophy.getContent(recursionUsedIds)
          foreach (_si in subContent)
          {
            local si = ::DataBlock()
            si.setFrom(_si)

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

  function _extractTopPrize(_recursionUsedIds)
  {
    if (::isInArray(id, _recursionUsedIds))
    {
      ::dagor.debug("id = " + id)
      ::debugTableData(_recursionUsedIds)
      ::script_net_assert_once("trophy recursion",
                               "Infinite recursion detected in trophy: " + id + ". Array " + ::toString(_recursionUsedIds))
      return
    }

    _recursionUsedIds.append(id)
    local topPrizeBlk = null
    foreach(prize in contentRaw)
    {
      if (prize?.ignoreForTrophyType)
        continue

      if (prize?.trophy)
      {
        local subTrophy = ::ItemsManager.findItemById(prize.trophy)
        topPrizeBlk = subTrophy ? subTrophy.getTopPrize(_recursionUsedIds) : null
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
    _recursionUsedIds.pop()
  }

  function getTopPrize(_recursionUsedIds = [])
  {
    if (!topPrize)
      _extractTopPrize(_recursionUsedIds)
    return topPrize
  }

  function getCost(ignoreCanBuy = false)
  {
    if (isCanBuy() || ignoreCanBuy)
      return ::Cost(::wp_get_trophy_cost(id), ::wp_get_trophy_cost_gold(id))
    return ::Cost()
  }

  function getTrophyImage(id)
  {
    local layerStyle = ::LayersIcon.findLayerCfg(id)
    if (layerStyle)
      return ::LayersIcon.genDataFromLayer(layerStyle)

    return ::LayersIcon.getIconData(id, defaultIcon, 1.0, defaultIconStyle)
  }

  function getUsingStyle()
  {
    if (needOpenTrophyGroupOnBuy())
      return groupTrophyStyle
    return iconStyle
  }

  function getIcon(addItemName = true)
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
    local content = getContent()
    if (showNameAsSingleAward && content.len() == 1) {
      local awardCount = content[0]?.count ?? 1
      local awardType = ::PrizesView.getPrizeTypeName(content[0], false)
      return (awardCount > 1)
        ? ::loc("multiAward/name/count/singleType", { awardType, awardCount })
        : ::loc(awardType)
    }

    local name = ::loc(locId || ("item/" + id), "")
    local hasCustomName = name != ""
    if (!hasCustomName)
      name = ::loc("item/" + defaultLocId)

    local showType = showTypeInName != null ? showTypeInName : !hasCustomName
    if (showType)
    {
      local prizeTypeName = ""
      if (showRangePrize)
        prizeTypeName = ::PrizesView.getPrizesListText(content)
      else
        prizeTypeName = ::PrizesView.getPrizeTypeName(getTopPrize(), colored)

      local comment = prizeTypeName.len() ? ::loc("ui/parentheses/space", { text = prizeTypeName }) : ""
      comment = colored ? ::colorize("commonTextColor", comment) : comment
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
    local locId = (fixedAmount > 1) ? "trophy/chest_contents/many" : "trophy/chest_contents"
    local headerText = ::loc(locId, { amount = ::colorize("commonTextColor", fixedAmount) })
    return ::colorize("grayOptionColor", headerText)
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
    local prize = getTopPrize()
    local icon = ::PrizesView.getPrizeTypeIcon(prize, true)
    if (icon == "")
      return res

    res = { contentIcon = icon }
    if (prize?.unit)
      res.contentType <- "unit"
    return res
  }

  function _requestBuy(params = {})
  {
    local blk = ::DataBlock()
    blk["name"] = id
    blk["index"] = ::getTblValue("index", params, -1)
    blk["cost"] = params.cost
    blk["costGold"] = params.costGold
    return ::char_send_blk("cln_buy_trophy", blk)
  }

  function getMainActionData(isShort = false, params = {})
  {
    if (!isInventoryItem && needOpenTrophyGroupOnBuy())
      return { btnName = ::loc("mainmenu/btnExpand") }

    return base.getMainActionData(isShort, params)
  }

  function doMainAction(cb, handler, params = null)
  {
    if (!isInventoryItem && needOpenTrophyGroupOnBuy())
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
    return ::loc(openingCaptionLocId || "mainmenu/trophyReward/title")
  }

  function getHiddenTopPrizeParams() { return null }
  function isHiddenTopPrize(prize) { return false }

  needShowDropChance = @() ::has_feature("ShowDropChanceInTrophy") && showDropChance

  function getTableData() {
    if (!needShowDropChance())
      return null

    local markup = getPrizeChanceLegendMarkup()
    if (markup == "")
      return null

    return markup
  }

  function getDescriptionAboveTable() {
    if (!showTillValue)
      return ""

    return ::PrizesView.getTrophyOpenCountTillPrize(getContent(), ::get_trophy_info(id))
  }

  canBuyTrophyByLimit = @() numTotal == 0 || numTotal > (::get_trophy_info(id)?.openCount ?? 0)
}
