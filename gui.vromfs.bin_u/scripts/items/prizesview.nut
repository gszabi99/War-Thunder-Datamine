local time = require("scripts/time.nut")
local workshop = require("scripts/items/workshop/workshop.nut")
local globalCallbacks = require("sqDagui/globalCallbacks/globalCallbacks.nut")
local { getUnitRole } = require("scripts/unit/unitInfoTexts.nut")
local { getModificationName } = require("scripts/weaponry/bulletsInfo.nut")
local { getEntitlementConfig, getEntitlementName } = require("scripts/onlineShop/entitlements.nut")
local { getPrizeChanceConfig } = require("scripts/items/prizeChance.nut")

//prize - blk or table in format of trophy prizes from trophies.blk
//content - array of prizes (better to rename it)
//
//API:
//  getPrizeTypeName(prize, colored = true)   - return short prize text (only with type if it long)
//  getPrizeText(prize, colored = true, _typeName = false, showCount = true, full = false)
//
//  getPrizesListText(prizesList, fixedAmountHeaderFunc = null) - get text for prizesList.
//  getPrizesStacksView(content, fixedAmountHeaderFunc = null, params = null) - get prizes list stacked by stackLevel in params
//                                                 fixedAmount - function(amount) to generate header for prizes
//                                                               if they all have same amount
//                                               params - view data params. will be included to view data before render
//                                                  include:
//                                                  receivedPrizes (true) - show prizes as received.
//  getPrizesListView(content, params = null) - get full prizes list not stacked.
//

enum PRIZE_TYPE {
  UNKNOWN
  MULTI_AWARD
  ITEM
  TROPHY
  UNIT
  RENTED_UNIT
  MODIFICATION
  SPARE
  SPECIALIZATION
  PREMIUM_ACCOUNT
  ENTITLEMENT
  UNLOCK
  UNLOCK_TYPE
  GOLD
  WARPOINTS
  EXP
  WARBONDS
  RESOURCE
}

enum STACK_TYPE {
  UNKNOWN
  ITEM      // Item params min-max range
  CURRENCY  // Currency min-max range
  VEHICLE   // Complete list of units
}

const UNITS_STACK_DETAILED_COUNT = 3
const UNITS_STACK_BY_TYPE_COUNT  = 6

local unitItemTypes = ["aircraft", "tank", "helicopter", "ship"]

::PrizesView <- {
  template = "gui/items/trophyDesc"

  function getTrophyOpenCountTillPrize(content, trophyInfo) {
    local res = []
    local trophiesCountTillPrize = 0
    foreach (prize in content) {
      if (prize?.till == null)
        continue

      local prizeType = getPrizeType(prize)
      local isReceived = prizeType == PRIZE_TYPE.UNIT && ::isUnitBought(::getAircraftByName(prize.unit))
      local locId = isReceived ? "trophy/prizeAlreadyReceived" : "trophy/openCountTillPrize"
      res.append(::loc(locId, {
        prizeText = getPrizeText(prize, false, false, !isReceived)
        trophiesCount = prize.till
      }))
      if (!isReceived)
        trophiesCountTillPrize = ::max(trophiesCountTillPrize, prize.till)
    }
    if (trophiesCountTillPrize > 0)
      res.append(::loc("trophy/openCount", {
        openTrophiesCount = trophyInfo?.openCount ?? 0
        trophiesCount = trophiesCountTillPrize
      }))

    return "\n".join(res)
  }

  function getFilteredListsData(prizesList, isFitFunction) {
    local filteredItems = []
    local newPrizesList = []

    foreach(prize in prizesList) {
      if (isFitFunction(prize))
        filteredItems.append(prize)
      else
        newPrizesList.append(prize)
    }

    return {
      filteredItems
      lostPrizesList = newPrizesList
    }
  }

  function getPrizesViewArrayByWeightCategory(prizes, category, title, isFirstHighlightedLine, params) {
    local arrayForView = getPrizesStacksArrayForView([], params.__merge({
      stacksList = prizes
      isFirstHighlightedLine = !isFirstHighlightedLine
    }))
    local buttonsCount = arrayForView?[0].buttonsCount ?? 0
    local prizeListView = [(getPrizeChanceConfig(category).__merge({
      title = title
      isHighlightedLine = isFirstHighlightedLine
      buttonsCount = buttonsCount
      buttons = ::array(buttonsCount, { emptyButton = true })
    }))]
    prizeListView.extend(arrayForView)
    return prizeListView
  }

  getItemPrizeRarityText = @(categoryText, tag = null) "".concat(categoryText, ::loc("ui/parentheses/space", {
    text = tag ?? ::loc("item/rarity1")
  }))
  getItemTypePrizeText = @(itemBlkType) ::loc(
    $"trophy/unlockables_names/{itemBlkType == "unit" ? "aircraft" : itemBlkType}")

  function getPrizesStacksViewByWeight(content, fixedAmountHeaderFunc = null, params = null) {
    local { shopDesc = false, stackLevel = prizesStack.DETAILED, categoryWeight } = params
    local view = params ? clone params : {}
    local stacksList = _stackContent(content, stackLevel, shopDesc)
    local fixedAmount = fixedAmountHeaderFunc ? _getContentFixedAmount(content) : 1
    local isFitByItemType = function(prize, itemType) {
      if(prize.prizeType != PRIZE_TYPE.ITEM)
        return false

      local blkType = prize?.item.blkType
      if (itemType == blkType)
        return true

      return itemType == "unit" && unitItemTypes.contains(blkType)
    }
    local isFitByRarity = @(prize, rarity) rarity == prize?.item.getQuality()

    if (fixedAmountHeaderFunc)
      view.header <- fixedAmountHeaderFunc(fixedAmount)


    params.needShowDropChance <- false
    params.hasChanceIcon <- false
    params.fixedAmount <- fixedAmount

    local notFoundPrizes = []
    local prizeListView = []
    foreach(category in categoryWeight) {
      local itemBlkType = category.prizeType
      local byTypeLists = getFilteredListsData(stacksList,
        @(p) isFitByItemType(p, itemBlkType))

      local byTypeArray = byTypeLists.filteredItems
      stacksList = byTypeLists.lostPrizesList

      if (byTypeArray.len() == 0)
        continue

      local categoryText = getItemTypePrizeText(itemBlkType)
      if (category.weight != null) {
        prizeListView.extend(getPrizesViewArrayByWeightCategory(
          byTypeArray, { weight = category.weight }, categoryText, prizeListView.len() % 2 != 0, params))

        continue
      }

      foreach (rarityWeight in category.rarity) {
        local rarity = rarityWeight.rarity
        local byRarityLists = getFilteredListsData(byTypeArray,
          @(p) isFitByRarity(p, rarity))

        local byRarityArray = byRarityLists.filteredItems
        byTypeArray = byRarityLists.lostPrizesList

        if (byRarityArray.len() == 0)
          continue

        prizeListView.extend(getPrizesViewArrayByWeightCategory(byRarityArray,
          { weight = rarityWeight.weight },
          getItemPrizeRarityText(categoryText, byRarityArray[0]?.item.rarity.tag),
          prizeListView.len() % 2 != 0, params))
      }

      while (byTypeArray.len() > 0) {
        local rarity = byTypeArray[0]?.item.getQuality()
        if (rarity == null) {
          notFoundPrizes.append(byTypeArray[0])
          byTypeArray.remove(0)
          continue
        }

        local byRarityLists = getFilteredListsData(byTypeArray,
          @(p) isFitByRarity(p, rarity))

        local byRarityArray = byRarityLists.filteredItems
        byTypeArray = byRarityLists.lostPrizesList
        prizeListView.extend(getPrizesViewArrayByWeightCategory(byRarityArray,
          { weight = "low" }, getItemPrizeRarityText(categoryText, byRarityArray[0]?.item.rarity.tag),
          prizeListView.len() % 2 != 0, params))
      }
    }

    while (stacksList.len() > 0) {
      local itemBlkType = stacksList[0]?.item.blkType
      if (itemBlkType == null) {
        notFoundPrizes.append(stacksList[0])
        stacksList.remove(0)
        continue
      }

      itemBlkType = unitItemTypes.contains(itemBlkType) ? "unit"
        : itemBlkType

      local byTypeLists = getFilteredListsData(stacksList,
        @(p) isFitByItemType(p, itemBlkType))

      local byTypeArray = byTypeLists.filteredItems
      stacksList = byTypeLists.lostPrizesList
      prizeListView.extend(getPrizesViewArrayByWeightCategory(byTypeArray,
        { weight = "low" }, getItemTypePrizeText(itemBlkType),
        prizeListView.len() % 2 != 0, params))
    }

    if (notFoundPrizes.len() > 0)
      prizeListView.extend(getPrizesViewArrayByWeightCategory(
        stacksList, { weight = "low" }, ::loc("attachables/category/other"),
        prizeListView.len() % 2 != 0, params))

    view.list <- prizeListView
    return ::handyman.renderCached(template, view)
  }


  function getPrizesStacksArrayForView(content, params = null) {
    local { shopDesc = false, stackLevel = prizesStack.DETAILED, fixedAmount = 1,
      needShowDropChance = false, stacksList = null,
      isFirstHighlightedLine = false } = params

    stacksList = stacksList ?? _stackContent(content, stackLevel, shopDesc)
    local showCount = fixedAmount == 1

    local maxButtonsCount = 0
    local hasChanceIcon = false
    local prizeListView = []
    foreach (idx, st in stacksList) {
      local data = null
      if (st.level == prizesStack.NOT_STACKED)
        data = getPrizesViewData(st.prize, showCount, params)
      else if (st.stackType == STACK_TYPE.ITEM) {//onl stack by items atm, so this only to do last check.
        local detailed = st.level == prizesStack.DETAILED
        local name = ""
        if (detailed)
          name = st.item.getStackName(st.params)
        else
          name = ::colorize("activeTextColor", _getItemTypeName(st.item))

        local countText = ""
        if (showCount && st.countMax > 1)
          countText = (st.countMin < st.countMax) ? (" x" + st.countMin + "-x" + st.countMax) : (" x" + st.countMax)

        local kinds = detailed ? "" : ::colorize("fadedTextColor", ::loc("ui/parentheses/space", { text = ::loc("trophy/item_type_different_kinds") }))
        data = {
          title = name + countText + kinds
          icon = getPrizeTypeIcon(st.prize)
        }
      } else if (st.stackType == STACK_TYPE.VEHICLE)
      {
        data = {
          icon = getPrizeTypeIcon(st.prize)
          title = _getStackUnitsText(st)
        }
      } else if (st.stackType == STACK_TYPE.CURRENCY)
      {
        data = {
          icon = getPrizeTypeIcon(st.prize)
          title = getStackCurrencyText(st)
        }
      }
      if (data != null) {
        maxButtonsCount = ::max(data?.buttonsCount ?? 0, maxButtonsCount)
        if (needShowDropChance) {
          local chanceConfig = getPrizeChanceConfig(st.prize)
          hasChanceIcon = hasChanceIcon || chanceConfig.chanceIcon != null
          data.__update(chanceConfig)
        }
        prizeListView.append(data.__update({
          isHighlightedLine = isFirstHighlightedLine ? idx % 2 == 0 : idx % 2 != 0
        }))
      }
    }

    if (hasChanceIcon) {
      prizeListView.each(function(d) {
        d.buttonsCount <- maxButtonsCount + 1
        local buttons = d?.buttons ?? []
        if (buttons.len() < maxButtonsCount)
          d.buttons <- buttons.resize(maxButtonsCount, { emptyButton = true })
      })
    }

    return prizeListView
  }
}

PrizesView.getPrizeType <- function getPrizeType(prize)
{
  if (isPrizeMultiAward(prize))
    return PRIZE_TYPE.MULTI_AWARD
  if (prize?.item)
    return PRIZE_TYPE.ITEM
  if (prize?.trophy)
    return PRIZE_TYPE.TROPHY
  if (prize?.unit)
    return prize?.mod ? PRIZE_TYPE.MODIFICATION : PRIZE_TYPE.UNIT
  if (prize?.rentedUnit)
    return PRIZE_TYPE.RENTED_UNIT
  if (prize?.spare)
    return PRIZE_TYPE.SPARE
  if (prize?.specialization)
    return PRIZE_TYPE.SPECIALIZATION
  if (prize?.premium_in_hours)
    return PRIZE_TYPE.PREMIUM_ACCOUNT
  if (prize?.entitlement)
    return PRIZE_TYPE.ENTITLEMENT
  if (prize?.unlock)
    return PRIZE_TYPE.UNLOCK
  if (prize?.unlocktype)
    return PRIZE_TYPE.UNLOCK_TYPE
  if (prize?.gold)
    return PRIZE_TYPE.GOLD
  if (prize?.warpoints)
    return PRIZE_TYPE.WARPOINTS
  if (prize?.exp)
    return PRIZE_TYPE.EXP
  if (prize?.warbonds)
    return PRIZE_TYPE.WARBONDS
  if (prize?.resource)
    return PRIZE_TYPE.RESOURCE
  return PRIZE_TYPE.UNKNOWN
}

PrizesView.getStackType <- function getStackType(prize)
{
  local prizeType = getPrizeType(prize)
  if (prizeType == PRIZE_TYPE.ITEM)
    return STACK_TYPE.ITEM
  if (::isInArray(prizeType, [ PRIZE_TYPE.GOLD, PRIZE_TYPE.WARPOINTS, PRIZE_TYPE.EXP, PRIZE_TYPE.WARBONDS ]))
    return STACK_TYPE.CURRENCY
  if (::isInArray(prizeType, [ PRIZE_TYPE.UNIT, PRIZE_TYPE.RENTED_UNIT ]))
    return STACK_TYPE.VEHICLE
  return STACK_TYPE.UNKNOWN
}

PrizesView.getPrizeTypeName <- function getPrizeTypeName(prize, colored = true)
{
  return getPrizeText(prize, colored, true)
}

PrizesView.getPrizeText <- function getPrizeText(prize, colored = true, _typeName = false, showCount = true, full = false)
{
  if (!prize)
    return ""

  local name = ""
  local color = "activeTextColor"
  if (isPrizeMultiAward(prize))
  {
    if (full)
    {
      name = ::TrophyMultiAward(prize).getDescription(true)
      color = ""
    } else
      name = ::TrophyMultiAward(prize).getName()
  }
  else if (prize?.unit)
  {
    if (_typeName)
      name = ::loc("trophy/unlockables_names/aircraft")
    else
    {
      name = ::getUnitName(prize.unit, true)
      color = ::getUnitClassColor(prize.unit)
    }
  }
  else if (prize?.rentedUnit)
  {
    if (_typeName)
      name = ::loc("shop/unitRent")
    else
    {
      local unitName = prize.rentedUnit
      local unitColor = ::getUnitClassColor(unitName)
      name = ::loc("shop/rentUnitFor", {
        unit = ::colorize(unitColor, ::getUnitName(unitName, true))
        time = ::colorize("userlogColoredText", time.hoursToString(prize?.timeHours ?? 0))
      })
    }
  }
  else if (prize?.item || prize?.trophy)
  {
    local id = prize?.item || prize?.trophy
    local item = ::ItemsManager.findItemById(id)
    if (_typeName)
    {
      name = _getItemTypeName(item)
      color = item ? "activeTextColor" : "red"
    }
    else
    {
      if (!item)
        name = id
      else
      {
        if (workshop.shouldDisguiseItem(item))
        {
          item = item.makeEmptyInventoryItem()
          item.setDisguise(true)
        }
        name = item.getPrizeDescription(prize?.count ?? 1)
        if (name)
          showCount = false
        else
          name = item.getShortDescription(colored)
      }
      color = item ? "activeTextColor" : "red"
    }
  }
  else if (prize?.premium_in_hours)
  {
    name = ::loc("charServer/entitlement/PremiumAccount") + ::loc("ui/colon") + time.hoursToString(prize.premium_in_hours)
    color = "userlogColoredText"
  }
  else if (prize?.entitlement)
  {
    name = getEntitlementName(getEntitlementConfig(prize.entitlement))
    color = "userlogColoredText"
  }
  else if (prize?.unlock)
  {
    local unlockId = prize.unlock
    local unlockType = ::get_unlock_type_by_id(unlockId)
    local typeValid = unlockType >= 0
    local unlockTypeText = typeValid ? ::get_name_by_unlock_type(unlockType) : "unknown"

    local unlockTypeName = ::loc("trophy/unlockables_names/" + unlockTypeText)
    unlockTypeName = colored ? ::colorize(typeValid ? "activeTextColor" : "red", unlockTypeName) : unlockTypeName

    name = unlockTypeName
    if (!_typeName)
    {
      local nameText = ::get_unlock_name_text(unlockType, unlockId)
      if (colored)
        nameText = ::colorize(typeValid ? "userlogColoredText" : "red", nameText)
      if (unlockType != ::UNLOCKABLE_SLOT && nameText != "")
        name += ::loc("ui/colon") + nameText
    }
    if (full)
      name += "\n" + ::get_unlock_description(unlockId)
    color = "commonTextColor"
  }
  else if (prize?.unlockType)
    name = ::loc("trophy/unlockables_names/" + prize.unlockType)
  else if (prize?.resource)
  {
    if (prize?.resourceType)
    {
      local decoratorType = ::g_decorator_type.getTypeByResourceType(prize.resourceType)
      local locName = decoratorType.getLocName(prize.resource, true)
      local valid = decoratorType != ::g_decorator_type.UNKNOWN
      local decorator = ::g_decorator.getDecorator(prize.resource, decoratorType)
      name = locName

      if (colored)
      {
        local nameColor = !valid ? "badTextColor"
          : decorator ? decorator.getRarityColor()
          : "activeTextColor"
        name = ::colorize(nameColor, name)
      }

      if (prize?.gold)
        name += " " + ::Cost(0, prize.gold).toStringWithParams({isGoldAlwaysShown = true, isColored = colored})
    }
  }
  else if (prize?.resourceType)
    name = ::loc("trophy/unlockables_names/" + prize.resourceType)
  else if (prize?.gold)
    name = ::Cost(0, prize.gold).toStringWithParams({isGoldAlwaysShown = true, isColored = colored})
  else if (prize?.warpoints)
    name = ::Cost(prize.warpoints).toStringWithParams({isWpAlwaysShown = true, isColored = colored})
  else if (prize?.exp)
    name = ::Cost().setFrp(prize.exp).toStringWithParams({isColored = colored})
  else if (prize?.warbonds)
  {
    local wb = ::g_warbonds.findWarbond(prize.warbonds)
    name = wb && prize?.count ? wb.getPriceText(prize.count, true, false) : ""
    showCount = false
  }
  else
  {
    name = ::loc("item/unknown")
    color = "red"
  }

  local countText = ""
  if (showCount)
  {
    local count = prize?.count ?? 1
    countText = (!_typeName && count > 1) ? " x" + count : ""
    if (colored)
      countText = ::colorize("commonTextColor", countText)
  }

  local commentText = prize?.commentText ?? ""

  name = colored && color.len() ? ::colorize(color, name) : name
  return name + countText + commentText
}

PrizesView._getItemTypeName <- function _getItemTypeName(item)
{
  return item ? item.getTypeName() : ""
}

PrizesView.getPrizeTypeIcon <- function getPrizeTypeIcon(prize, unitImage = false)
{
  if (!prize || prize?.noIcon)
    return ""
  if (isPrizeMultiAward(prize))
    return ::TrophyMultiAward(prize).getTypeIcon()
  if (prize?.unit)
    return unitImage ? ::image_for_air(prize.unit) : ::getUnitClassIco(prize.unit)
  if (prize?.rentedUnit)
    return "#ui/gameuiskin#item_type_rent"
  if (prize?.item)
  {
    local item = ::ItemsManager.findItemById(prize.item)
    return item?.getSmallIconName() ?? ::BaseItem.typeIcon
  }
  if (prize?.trophy)
  {
    local item = ::ItemsManager.findItemById(prize.trophy)
    if (!item)
      return ::BaseItem.typeIcon
    local topPrize = item.getTopPrize()
    return topPrize ? getPrizeTypeIcon(topPrize) : "#ui/gameuiskin#item_type_trophies"
  }
  if (prize?.premium_in_hours)
    return "#ui/gameuiskin#item_type_premium"
  if (prize?.entitlement)
    return "#ui/gameuiskin#item_type_premium"
  if (prize?.unlock || prize?.unlockType)
  {
    local unlockType = prize?.unlockType || ::get_unlock_type_by_id(prize?.unlock)
    if (typeof(unlockType) == "string")
      unlockType = ::get_unlock_type(unlockType)
    return ::g_decorator_type.getTypeByUnlockedItemType(unlockType).prizeTypeIcon
  }

  if (prize?.resourceType)
    return ::g_decorator_type.getTypeByResourceType(prize.resourceType).prizeTypeIcon

  if (prize?.gold)
    return "#ui/gameuiskin#item_type_eagles"
  if (prize?.warpoints)
    return "#ui/gameuiskin#item_type_warpoints"
  if (prize?.exp)
    return "#ui/gameuiskin#item_type_Free_RP"
  if (prize?.warbonds)
    return "#ui/gameuiskin#item_type_warbonds"
  return "#ui/gameuiskin#item_type_placeholder"
}

PrizesView.isPrizeMultiAward <- function isPrizeMultiAward(prize)
{
  return prize?.multiAwardsOnWorthGold != null
         || prize?.modsForBoughtUnit != null
}

PrizesView._getContentFixedAmount <- function _getContentFixedAmount(content)
{
  local res = -1
  foreach (prize in content)
  {
    local itemCount = prize?.count ?? 1
    if (res == itemCount)
      continue
    if (res >= 1)
      return 1
    res = itemCount
  }
  return ::max(res, 1)
}

//stack = {
//  level = (int) prizesStack
//  stackSize = int
//  item = first item from stack to compare.  (null when prize not item)
//  prize = (datablock) prize from content (if stacked, than first example from stack)
//  countMin, countMax - collected range
//  params = table of custom params filled by item type, see updateStackParams(),
//    or filled by prize type for non-item prize types.
//}
PrizesView._createStack <- function _createStack(prize)
{
  local count = prize?.count ?? 1
  return {
    prizeType = getPrizeType(prize)
    stackType = getStackType(prize)
    level = prizesStack.NOT_STACKED
    size = 1
    prize = prize
    item = null
    countMin = count
    countMax = count
    params = null
  }
}

PrizesView._findOneStack <- function _findOneStack(stackList, prizeType, checkFunc = function(s) { return true } )
{
  foreach(stack in stackList)
    if (prizeType == stack.prizeType && checkFunc(stack))
      return stack
  return null
}

PrizesView._addPrizeItemToStack <- function _addPrizeItemToStack(stack, item, prize, stackLevel)
{
  local count = prize?.count ?? 1
  stack.countMin = ::min(stack.countMin, count)
  stack.countMax = ::max(stack.countMax, count)
  stack.level    = ::max(stack.level, stackLevel)
  stack.size++
  if (stack?.params)
    item.updateStackParams(stack.params)
}

PrizesView._findAndStackPrizeItem <- function _findAndStackPrizeItem(prize, stackList, stackLevel)
{
  local item = ::ItemsManager.findItemById(prize?.item)
  if (!item)
    return true

  local itype = item.iType
  local stack = _findOneStack(stackList, PRIZE_TYPE.ITEM, (@(itype, item, prize, stackLevel) function(stack) {
      local sItem = stack.item
      if (!sItem || sItem.iType != itype)
        return false

      local curStackLevel = prizesStack.BY_TYPE //real stack level, can be lower than requested
      if (sItem.canStack(item))
        curStackLevel = prizesStack.DETAILED

      if (curStackLevel > stackLevel)
        return false

      _addPrizeItemToStack(stack, item, prize, curStackLevel)
      return true
    })(itype, item, prize, stackLevel))

  if (stack)
    return true

  stack = _createStack(prize)
  stack.item = item
  stack.params = {}
  item.updateStackParams(stack.params)
  stackList.append(stack)
  return true
}

PrizesView.getPrizeCurrencyCfg <- function getPrizeCurrencyCfg(prize)
{
  if ((prize?.gold ?? 0) > 0)
    return { type = PRIZE_TYPE.GOLD, val = prize.gold, printFunc = @(val) ::Cost(0, val).tostring() }
  if ((prize?.warpoints ?? 0) > 0)
    return {  type = PRIZE_TYPE.WARPOINTS, val = prize.warpoints, printFunc = @(val) ::Cost(val).tostring() }
  if ((prize?.exp ?? 0) > 0)
    return {  type = PRIZE_TYPE.EXP, val = prize.exp, printFunc = @(val) ::Cost().setFrp(val).tostring() }
  if (prize?.warbonds && (prize?.count ?? 0) > 0)
  {
    local wbId = prize.warbonds
    return {  type = PRIZE_TYPE.WARBONDS, val = prize.count, printFunc = @(val) ::g_warbonds.findWarbond(wbId).getPriceText(val, true, false) }
  }
  return null
}

PrizesView._findAndStackPrizeCurrency <- function _findAndStackPrizeCurrency(prize, stackList)
{
  local prizeType = getPrizeType(prize)

  local stack = _findOneStack(stackList, prizeType)

  local cfg = getPrizeCurrencyCfg(prize)
  if (!cfg)
    return false

  if (stack)
  {
    stack.countMin = ::min(stack.countMin, cfg.val)
    stack.countMax = ::max(stack.countMax, cfg.val)
    stack.level = prizesStack.DETAILED
    return true
  }

  stack = _createStack(prize)
  stack.countMin = cfg.val
  stack.countMax = cfg.val
  stack.params = { printFunc = cfg.printFunc }
  stackList.append(stack)
  return true
}

PrizesView.getStackCurrencyText <- function getStackCurrencyText(stack)
{
  local printFunc = stack.params.printFunc
  local res = printFunc(stack.countMin)
  if (stack.countMin != stack.countMax)
    res += " - " + printFunc(stack.countMax)
  return ::colorize("activeTextColor", res)
}

PrizesView._findAndStackPrizeUnit <- function _findAndStackPrizeUnit(prize, stackList, stackLevel, shopDesc)
{
  if (shopDesc)
    return false

  local prizeType = getPrizeType(prize)

  local stack = _findOneStack(stackList, prizeType)

  if (stack)
  {
    stack.params.prizes.append(prize)
    stack.size++

    if (stack.size >= UNITS_STACK_BY_TYPE_COUNT)
      stack.level = ::max(prizesStack.BY_TYPE, stackLevel)
    else if (stack.size >= UNITS_STACK_DETAILED_COUNT)
      stack.level = ::max(prizesStack.DETAILED, stackLevel)

    return true
  }

  stack = _createStack(prize)
  stack.params = {
    prizes = [ prize ]
  }
  stackList.append(stack)
  return true
}

PrizesView._getStackUnitsText <- function _getStackUnitsText(stack)
{
  local isDetailed = stack.level == prizesStack.DETAILED
  local prizeType = getPrizeType(stack.prize)
  local isRent = prizeType == PRIZE_TYPE.RENTED_UNIT

  local units = []
  foreach (p in stack.params.prizes)
  {
    local unitId = isRent ? p.rentedUnit : p.unit
    local color = ::getUnitClassColor(unitId)
    local name = ::colorize(color, ::getUnitName(unitId))
    if (isRent)
      name += _getUnitRentComment(p.timeHours, p.numSpares, true)
    units.append(name)
  }

  local header = getPrizeTypeName(stack.prize)
  local headerSeparator = ::loc("ui/colon") + (isDetailed ? "\n" : "")
  local unitsSeparator  = isDetailed ? "\n" : ::loc("ui/comma")

  return header + headerSeparator + ::g_string.implode(units, unitsSeparator)
}

PrizesView._stackContent <- function _stackContent(content, stackLevel = prizesStack.BY_TYPE, shopDesc = false)
{
  local res = []
  foreach (prize in content)
  {
    local stackType = getStackType(prize)

    if (stackType == STACK_TYPE.ITEM && _findAndStackPrizeItem(prize, res, stackLevel))
      continue
    if (stackType == STACK_TYPE.CURRENCY && _findAndStackPrizeCurrency(prize, res))
      continue
    if (stackType == STACK_TYPE.VEHICLE && _findAndStackPrizeUnit(prize, res, stackLevel, shopDesc))
      continue

    res.append(_createStack(prize))
  }
  return res
}

PrizesView.getPrizesListText <- function getPrizesListText(content, fixedAmountHeaderFunc = null, hasHeaderWithoutContent = true)
{
  if (!hasHeaderWithoutContent && !content.len())
    return ""

  local stacksList = _stackContent(content, prizesStack.DETAILED)
  local fixedAmount = fixedAmountHeaderFunc ? _getContentFixedAmount(content) : 1 //1 - dont use fixed amount
  local showCount = fixedAmount == 1
  local list = []

  if (fixedAmountHeaderFunc)
    list.append(fixedAmountHeaderFunc(fixedAmount))

  local listMarker = ::nbsp + ::colorize("grayOptionColor", ::loc("ui/mdash")) + ::nbsp
  foreach (st in stacksList)
  {
    if (st.level == prizesStack.NOT_STACKED)
      list.append(listMarker + getPrizeText(st.prize, true, false, showCount))
    else if (st.stackType == STACK_TYPE.ITEM) //onl stack by items atm, so this only to do last check.
    {
      local detailed = st.level == prizesStack.DETAILED

      local name = ""
      if (detailed)
        name = st.item.getStackName(st.params)
      else
        name = ::colorize("activeTextColor", _getItemTypeName(item))

      local countText = ""
      if (showCount && st.countMax > 1)
        countText = (st.countMin < st.countMax) ? (" x" + st.countMin + "-x" + st.countMax) : (" x" + st.countMax)

      local kinds = detailed ? "" : ::colorize("fadedTextColor", ::loc("ui/parentheses/space", { text = ::loc("trophy/item_type_different_kinds") }))
      list.append(listMarker + name + countText + kinds)
    } else if (st.stackType == STACK_TYPE.VEHICLE)
    {
      list.append(listMarker + _getStackUnitsText(st))
    } else if (st.stackType == STACK_TYPE.CURRENCY)
    {
      list.append(listMarker + getStackCurrencyText(st))
    }
  }

  return ::g_string.implode(list, "\n")
}

PrizesView.getViewDataUnit <- function getViewDataUnit(unitName, params = null, rentTimeHours = 0, numSpares = 0)
{
  local unit = ::getAircraftByName(unitName)
  if (!unit)
    return null

  local isBought = ::isUnitBought(unit)
  local receivedPrizes = ::getTblValue("receivedPrizes", params, true)
  local classIco = ::getTblValue("singlePrize", params, false) ? null : ::getUnitClassIco(unit)
  local shopItemType = getUnitRole(unit)
  local isShowLocalState = receivedPrizes || rentTimeHours > 0
  local buttons = getPrizeActionButtonsView({ unit = unitName }, params)
  local receiveOnce = params?.relatedItem ? "mainmenu/activateOnlyOnce" : "mainmenu/receiveOnlyOnce"

  local infoText = ""
  if (rentTimeHours > 0)
    infoText = _getUnitRentComment(rentTimeHours, numSpares)
  if (!receivedPrizes && isBought)
    infoText += (infoText.len() ? "\n" : "") + ::colorize("badTextColor", ::loc(receiveOnce))

  local unitPlate = ::build_aircraft_item(unitName, unit, {
    hasActions = true,
    status = (!receivedPrizes && isBought) ? "locked" : "canBuy",
    isLocalState = isShowLocalState
    showAsTrophyContent = true
    isReceivedPrizes = receivedPrizes
    offerRentTimeHours = rentTimeHours
    tooltipParams = {
      rentTimeHours = rentTimeHours
      isReceivedPrizes = receivedPrizes
      showLocalState = isShowLocalState
      relatedItem = params?.relatedItem
    }
  })
  return {
    classIco = classIco,
    shopItemType = shopItemType,
    unitPlate = unitPlate,
    commentText = infoText.len() ? infoText : null
    buttons = buttons
    buttonsCount = buttons.len()
  }
}

PrizesView.getViewDataRentedUnit <- function getViewDataRentedUnit(unitName, params, timeHours, numSpares)
{
  if (!timeHours)
    return null

  return getViewDataUnit(unitName, params, timeHours, numSpares)
}

PrizesView._getUnitRentComment <- function _getUnitRentComment(rentTimeHours = 0, numSpares = 0, short = false)
{
  if (!rentTimeHours)
    return ""
  local timeStr = ::colorize("userlogColoredText", time.hoursToString(rentTimeHours))
  local text = short ? timeStr :
    ::colorize("activeTextColor", ::loc("shop/rentFor", { time =  timeStr }))
  if (numSpares)
    text += ::colorize("grayOptionColor", " + " + ::loc("multiAward/name/count/singleType", { awardType = ::loc("multiAward/type/spare") awardCount = numSpares }))
  return short ? ::loc("ui/parentheses/space", { text = text }) : text
}

PrizesView.getViewDataMod <- function getViewDataMod(unitName, modName, params)
{
  local unit = ::getAircraftByName(unitName)
  if (!unit)
    return null

  local icon = ""
  if (modName == "premExpMul") //talisman
    icon = "#ui/gameuiskin#item_type_talisman"
  else
    icon = unit?.isTank() ? "#ui/gameuiskin#item_type_modification_tank" : "#ui/gameuiskin#item_type_modification_aircraft"

  return {
    icon = icon
    icon2 = ::get_unit_country_icon(unit)
    title = ::colorize("activeTextColor", ::getUnitName(unitName, true)) + ::loc("ui/colon")
          + ::colorize("userlogColoredText", getModificationName(unit, modName))
    tooltipId = ::g_tooltip.getIdModification(unitName, modName)
  }
}

PrizesView.getViewDataSpare <- function getViewDataSpare(unitName, count, params)
{
  local unit = ::getAircraftByName(unitName)
  local spare = ::getTblValue("spare", unit)
  if (!spare)
    return null

  local title = ::colorize("activeTextColor", ::getUnitName(unitName, true)) + ::loc("ui/colon")
              + ::colorize("userlogColoredText", ::loc("spare/spare"))
  if (count && count > 1)
    title += ::colorize("activeTextColor", " x" + count)
  return {
    icon = "#ui/gameuiskin#item_type_spare"
    icon2 = ::get_unit_country_icon(unit)
    shopItemType = getUnitRole(unit)
    title = title
    tooltipId = ::g_tooltip.getIdSpare(unitName)
  }
}

PrizesView.getViewDataSpecialization <- function getViewDataSpecialization(prize, params)
{
  local specLevel = prize?.specialization ?? 1
  local unitName = prize?.unitName
  local unit = ::getAircraftByName(unitName)
  if (!unit)
    return null

  local crew = ::get_crew_by_id(prize?.crew ?? 0)
  local title = ::colorize("userlogColoredText", ::g_crew.getCrewName(crew)) + ::loc("ui/colon")
              + ::colorize("activeTextColor", ::getUnitName(unit))
              + ", " + ::colorize("userlogColoredText", ::loc("crew/qualification/" + specLevel))
  return {
    icon = (specLevel == 2) ? "#ui/gameuiskin#item_type_crew_aces" : "#ui/gameuiskin#item_type_crew_experts"
    icon2 = ::get_unit_country_icon(unit)
    title = title
    tooltipId = ::g_tooltip.getIdUnit(unitName)
  }
}

PrizesView.getViewDataDecorator <- function getViewDataDecorator(prize, params = null)
{
  local id = prize?.resource
  local decoratorType = ::g_decorator_type.getTypeByResourceType(prize?.resourceType)
  local isHave = decoratorType.isPlayerHaveDecorator(id)
  local isReceivedPrizes = params?.receivedPrizes ?? false
  local buttons = getPrizeActionButtonsView(prize, params)
  local receiveOnce = params?.relatedItem ? "mainmenu/activateOnlyOnce" : "mainmenu/receiveOnlyOnce"

  return {
    icon  = decoratorType.prizeTypeIcon
    title = getPrizeText(prize)
    tooltipId = ::g_tooltip.getIdDecorator(id, decoratorType.unlockedItemType, params)
    commentText = !isReceivedPrizes && isHave ?  ::colorize("badTextColor", ::loc(receiveOnce)) : null
    buttons = buttons
    buttonsCount = buttons.len()
  }
}

PrizesView.getViewDataItem <- function getViewDataItem(prize, showCount, params = null)
{
  local primaryIcon = prize?.primaryIcon
  local buttons = getPrizeActionButtonsView(prize, params)
  local item = ::ItemsManager.findItemById(prize?.item)
  local itemIcon = (params?.isShowItemIconInsteadItemType ?? false) && item
    ? item.getIconName()
    : getPrizeTypeIcon(prize)
  return {
    icon  = primaryIcon ? primaryIcon : itemIcon
    icon2 = primaryIcon ? itemIcon : null
    title = params?.needShowItemName ?? true
      ? getPrizeText(prize, !params?.isLocked, false, showCount, true)
      : prize?.commentText ?? ""
    tooltipId = item && !item.shouldAutoConsume ? ::g_tooltip.getIdItem(prize?.item, params) : null
    buttons = buttons
    buttonsCount = buttons.len()
  }
}

PrizesView.getViewDataMultiAward <- function getViewDataMultiAward(prize, params = null)
{
  local multiAward = ::TrophyMultiAward(prize)
  return {
    icon = multiAward.getTypeIcon()
    title = multiAward.getDescription(true)
  }
}

PrizesView.getViewDataDefault <- function getViewDataDefault(prize, showCount, params = null)
{
  //!!FIX ME: better to refactor this. it used only here, but each function try do detect prize type by self
  //much faster will be to get viewData array and gen desc by it than in each function detect prize type.
  //Now we have function getPrizeType() for prize type detection.
  local title = getPrizeText(prize, true, false, showCount, true)
  local icon = getPrizeTypeIcon(prize)
  local tooltipId = prize?.trophy ? ::g_tooltip.getIdSubtrophy(prize.trophy)
                  : prize?.unlock ? ::g_tooltip.getIdUnlock(prize.unlock, params)
                  : null

  local previewImage = null
  local commentText = null
  if (prize?.unlock)
  {
    if (params?.showAsTrophyContent && ::is_unlocked_scripted(-1, prize.unlock))
      commentText = ::colorize("badTextColor", ::loc("mainmenu/receiveOnlyOnce"))
    if (::get_unlock_type_by_id(prize.unlock) == ::UNLOCKABLE_PILOT)
      previewImage = "cardAvatar { value:t='" + prize.unlock +"'}"
  }

  return {
    icon = icon,
    title = title,
    tooltipId = tooltipId,
    previewImage = previewImage
    commentText = commentText
  }
}

PrizesView.getPrizesViewData <- function getPrizesViewData(prize, showCount = true, params = null)
{
  if (isPrizeMultiAward(prize))
    return getViewDataMultiAward(prize, params)

  local unitName = prize?.unit
  if (unitName)
    if (prize?.mod)
      return getViewDataMod(unitName, prize?.mod, params)
    else
      return getViewDataUnit(unitName, params)
  if (prize?.rentedUnit)
    return getViewDataRentedUnit(prize?.rentedUnit, params, prize?.timeHours, prize?.numSpares)
  if (prize?.spare)
    return getViewDataSpare(prize?.spare, showCount ? prize?.count : 0, params)
  if (prize?.specialization)
    return getViewDataSpecialization(prize, params)
  if (prize?.resourceType)
    return getViewDataDecorator(prize, params)
  if (prize?.item)
    return getViewDataItem(prize, showCount, params)
  if (prize?.warbonds)
    return getViewDataDefault(prize, false, params)
  return getViewDataDefault(prize, showCount, params)
}

PrizesView.getPrizesListView <- function getPrizesListView(content, params = null, hasHeaderWithoutContent = true)
{
  if (!hasHeaderWithoutContent && !content.len())
    return ""

  local view = params ? clone params : {}
  if (content.len() == 1)
  {
    if (!params)
      params = {}
    params.singlePrize <- true
  }

  if (!view?.timerId && view?.header == "")
    delete view.header

  view.list <- []
  foreach (prize in content)
  {
    local data = getPrizesViewData(prize, true, params)
    if (data)
      view.list.append(data)
  }
  return ::handyman.renderCached(template, view)
}

PrizesView.getPrizesStacksView <- function getPrizesStacksView(content, fixedAmountHeaderFunc = null, params = null)
{
  local { stackLevel = prizesStack.DETAILED } = params
  if (stackLevel == prizesStack.NOT_STACKED && !fixedAmountHeaderFunc)
    return getPrizesListView(content, params)

  local view = params ? clone params : {}
  local fixedAmount = fixedAmountHeaderFunc ? _getContentFixedAmount(content) : 1
  if (fixedAmountHeaderFunc)
    view.header <- fixedAmountHeaderFunc(fixedAmount)

  params.fixedAmount <- fixedAmount
  view.list <- getPrizesStacksArrayForView(content, params)
  return ::handyman.renderCached(template, view)
}

PrizesView.getPrizeActionButtonsView <- function getPrizeActionButtonsView(prize, params = null)
{
  local view = []
  if (!params?.shopDesc)
    return view

  local itemId = prize?.item ?? params?.relatedItem
  if (itemId)
  {
    local item = ::ItemsManager.findItemById(itemId)
    if (!item || workshop.shouldDisguiseItem(item))
      return view
    if (item.canPreview() && ::isInMenu())
    {
      local gcb = globalCallbacks.ITEM_PREVIEW
      view.append({
        image = "#ui/gameuiskin#btn_preview.svg"
        tooltip = "#mainmenu/btnPreview"
        funcName = gcb.cbName
        actionParamsMarkup = gcb.getParamsMarkup({ itemId = item.id })
      })
    }
    if (item.hasLink())
    {
      local gcb = globalCallbacks.ITEM_LINK
      view.append({
        image = "#ui/gameuiskin#gc.svg"
        tooltip = "#" + item.linkActionLocId
        funcName = gcb.cbName
        actionParamsMarkup = gcb.getParamsMarkup({ itemId = item.id })
      })
    }
    return view
  }

  local unitId = prize?.unit || prize?.rentedUnit
  if (unitId && ::getAircraftByName(unitId)?.isInShop)
  {
    local gcb = globalCallbacks.UNIT_PREVIEW
    view.append({
      image = "#ui/gameuiskin#btn_preview.svg"
      tooltip = "#mainmenu/btnPreview"
      funcName = gcb.cbName
      actionParamsMarkup = gcb.getParamsMarkup({ unitId = unitId })
    })
    return view
  }

  local resource = prize?.resource
  local resourceType = prize?.resourceType
  if (resource && resourceType)
  {
    local gcb = globalCallbacks.DECORATOR_PREVIEW
    local decType = ::g_decorator_type.getTypeByResourceType(resourceType)
    local decorator = ::g_decorator.getDecorator(resource, decType)
    if (decorator.canPreview())
      view.append({
        image = "#ui/gameuiskin#btn_preview.svg"
        tooltip = "#mainmenu/btnPreview"
        funcName = gcb.cbName
        actionParamsMarkup = gcb.getParamsMarkup({ resource = resource, resourceType = resourceType })
      })
    return view
  }

  return view
}
