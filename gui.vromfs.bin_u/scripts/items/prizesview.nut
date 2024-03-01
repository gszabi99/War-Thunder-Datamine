//-file:plus-string
from "%scripts/dagui_natives.nut" import get_unlock_type, get_name_by_unlock_type
from "%scripts/dagui_library.nut" import *

let { Cost } = require("%scripts/money.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { isInMenu } = require("%scripts/baseGuiHandlerManagerWT.nut")
let time = require("%scripts/time.nut")
let DataBlockAdapter = require("%scripts/dataBlockAdapter.nut")
let { cutPostfix, utf8ToLower } = require("%sqstd/string.nut")
let workshop = require("%scripts/items/workshop/workshop.nut")
let globalCallbacks = require("%sqDagui/globalCallbacks/globalCallbacks.nut")
let { getUnitRole, getUnitClassColor } = require("%scripts/unit/unitInfoTexts.nut")
let { getModificationName } = require("%scripts/weaponry/bulletsInfo.nut")
let { getEntitlementConfig, getEntitlementName,
  getEntitlementDescription, getEntitlementLocParams, premiumAccountDescriptionArr } = require("%scripts/onlineShop/entitlements.nut")
let { getPrizeChanceConfig } = require("%scripts/items/prizeChance.nut")
let { MODIFICATION, SPARE } = require("%scripts/weaponry/weaponryTooltips.nut")
let { isLoadingBgUnlock } = require("%scripts/loading/loadingBgData.nut")
let TrophyMultiAward = require("%scripts/items/trophyMultiAward.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { formatLocalizationArrayToDescription } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { getFullUnlockDescByName, getUnlockNameText,
  getUnlockRewardsText } = require("%scripts/unlocks/unlocksViewModule.nut")
let { getUnlockType, isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { getDecorator } = require("%scripts/customization/decorCache.nut")
let { getGiftSparesCost } = require("%scripts/shop/giftSpares.nut")
let { getUnitName, getUnitCountryIcon } = require("%scripts/unit/unitInfo.nut")
let { decoratorTypes, getTypeByUnlockedItemType, getTypeByResourceType } = require("%scripts/customization/types.nut")
let { buildUnitSlot } = require("%scripts/slotbar/slotbarView.nut")
let { getCrewById } = require("%scripts/slotbar/slotbarState.nut")
let { BaseItem } = require("%scripts/items/itemsClasses/itemsBase.nut")
let { findItemById } = require("%scripts/items/itemsManager.nut")
let { getCrewName } = require("%scripts/crew/crew.nut")

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

enum prizesStack {
  NOT_STACKED
  DETAILED
  BY_TYPE
}

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
  UNLOCK_PROGRESS
}

enum STACK_TYPE {
  UNKNOWN
  ITEM      // Item params min-max range
  CURRENCY  // Currency min-max range
  VEHICLE   // Complete list of units
}

const UNITS_STACK_DETAILED_COUNT = 3
const UNITS_STACK_BY_TYPE_COUNT  = 6

let unitItemTypes = ["aircraft", "tank", "helicopter", "ship"]

let template = "%gui/items/trophyDesc.tpl"

let unlockAddProgressView = {
  battlpass_progress = {
    image = "#ui/gameuiskin#item_type_bp.svg"
    function getText(prize, v_typeName) {
      let progressArray = prize.unlockAddProgress.split("_")
      let value = progressArray.top()
      let typeName = cutPostfix(prize.unlockAddProgress, $"_{value}")
      return v_typeName ? loc(typeName)
        : loc("progress/amount", { amount = value.tointeger() * (prize?.count ?? 1) })
    }
    showCount = false
  }
  battlepass_add_warbonds = {
    image = "#ui/gameuiskin#item_warbonds.avif"
    function getText(prize, _v_typeName) {
      let unlock = getUnlockById(prize.unlockAddProgress)
      if (unlock == null)
        return ""

      let config = ::build_conditions_config(unlock)
      return config.maxVal <= (prize?.count ?? 1) ? getUnlockRewardsText(config)
        : ""
    }
    getDescription = @(_prize) loc("warbond/desc")
  }
}

let getUnlockAddProgressViewConfig = @(unlockId) unlockAddProgressView.findvalue(@(_, key) unlockId.indexof(key) != null)
let isUnlockAddProgressPrize = @(prize) prize?.unlockAddProgress != null
  && unlockAddProgressView.findvalue(@(_, key) prize.unlockAddProgress.indexof(key) != null)

let prizeViewConfig = {
  [PRIZE_TYPE.GOLD] = {
    getDescription = @(_) loc("charServer/chapter/eagles/desc")
    getTooltipConfig = @(_prize) { tooltip = loc("mainmenu/gold") }
  },
  [PRIZE_TYPE.WARPOINTS] = {
    getDescription = @(_) loc("charServer/chapter/warpoints/desc")
    getTooltipConfig = @(_prize) { tooltip = loc("mainmenu/warpoints") }
  },
  [PRIZE_TYPE.PREMIUM_ACCOUNT] = {
    function getDescription(_) {
      let paramEntitlement = getEntitlementLocParams()
      let locArr = premiumAccountDescriptionArr.map(@(d) d.__merge({ text = loc(d.locId, paramEntitlement) }))

      return formatLocalizationArrayToDescription(locArr)
    }
    getTooltipConfig = @(_prize) { tooltip = loc($"charServer/chapter/premium") }
  },
  [PRIZE_TYPE.ENTITLEMENT] = {
    getDescription = @(config) getEntitlementDescription(
      getEntitlementConfig(config.entitlement),
      config.entitlement)
    getTooltipConfig = @(prize) { tooltip = getEntitlementName(getEntitlementConfig(prize.entitlement)) }
  },
  [PRIZE_TYPE.MULTI_AWARD] = {
    getDescription = @(config) TrophyMultiAward(DataBlockAdapter(config)).getDescription(true)
    getTooltipConfig = @(prize) { tooltip = TrophyMultiAward(DataBlockAdapter(prize)).getName() }
  },
  [PRIZE_TYPE.UNLOCK] = {
    getDescription = @(config) getFullUnlockDescByName(config.unlock)
    getTooltipConfig = @(prize) { tooltipId = getTooltipType("UNLOCK").getTooltipId(prize.unlock) }
  },
  [PRIZE_TYPE.UNLOCK_TYPE] = {
    getDescription = @(config) loc($"trophy/unlockables_names/{config.unlockType}")
    getTooltipConfig = @(prize) { tooltipId = getTooltipType("UNLOCK").getTooltipId(prize.unlockType) }
  },
  [PRIZE_TYPE.UNIT] = {
    getDescriptionMarkup = function(config) {
      let data = ::PrizesView.getPrizesViewData(config, true)
      return handyman.renderCached(template, { list = [data] })
    }
    getTooltipConfig = @(prize) { tooltipId = getTooltipType("UNIT").getTooltipId(prize.unit) }
  },
  [PRIZE_TYPE.RENTED_UNIT] = {
    getTooltipConfig = @(prize) { tooltipId = getTooltipType("UNIT").getTooltipId(prize.rentedUnit) }
  },
  [PRIZE_TYPE.RESOURCE] = {
    function getDescription(config) {
      let decoratorType = getTypeByResourceType(config.resourceType)
      return getDecorator(config.resource, decoratorType).getTypeDesc()
    }
    function getTooltipConfig(prize) {
      let decoratorType = getTypeByResourceType(prize.resourceType)
      let decorator = getDecorator(prize.resource, decoratorType)
      return { tooltipId = getTooltipType("DECORATION").getTooltipId(decorator.id, decoratorType.unlockedItemType) }
    }
  },
  [PRIZE_TYPE.UNLOCK_PROGRESS] = {
    getDescription = @(prize) getUnlockAddProgressViewConfig(prize.unlockAddProgress)?.getDescription(prize) ?? ""
    getTooltipConfig = @(prize) { tooltip = this.getDescription(prize) }
  }
}

::PrizesView <- {

  function getTrophyOpenCountTillPrize(content, trophyInfo) {
    let res = []
    local trophiesCountTillPrize = 0
    foreach (prize in content) {
      if (prize?.till == null)
        continue

      let prizeType = this.getPrizeType(prize)
      let isReceived = prizeType == PRIZE_TYPE.UNIT && ::isUnitBought(getAircraftByName(prize.unit))
      let locId = isReceived ? "trophy/prizeAlreadyReceived" : "trophy/openCountTillPrize"
      res.append(loc(locId, {
        prizeText = this.getPrizeText(prize, false, false, !isReceived)
        trophiesCount = prize.till
      }))
      if (!isReceived)
        trophiesCountTillPrize = max(trophiesCountTillPrize, prize.till)
    }
    if (trophiesCountTillPrize > 0)
      res.append(loc("trophy/openCount", {
        openTrophiesCount = trophyInfo?.openCount ?? 0
        trophiesCount = trophiesCountTillPrize
      }))

    return "\n".join(res)
  }

  function getFilteredListsData(prizesList, isFitFunction) {
    let filteredItems = []
    let newPrizesList = []

    foreach (prize in prizesList) {
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

  function getPrizesViewArrayByCategory(prizes, titleOvr, params) {
    let { showOnlyCategoriesOfPrizes = false, categoryId } = params
    let isFirstHighlightedLine = categoryId % 2 == 0
    local prizeTitleView = titleOvr.__merge({ isHighlightedLine = isFirstHighlightedLine })

    if (showOnlyCategoriesOfPrizes)
      return [prizeTitleView]

    let arrayForView = this.getPrizesStacksArrayForView([], params.__merge({
      stacksList = prizes
      isFirstHighlightedLine = !isFirstHighlightedLine
    }))

    if (arrayForView.len() == 0)
      return [prizeTitleView]

    local buttonsCount = this.getMaxPrizeButtonsCount(arrayForView)
    prizeTitleView = prizeTitleView.__merge({
      buttonsCount = buttonsCount
      buttons = array(buttonsCount, { emptyButton = true })
      isCategory = true
      categoryId = categoryId
      onCategoryClick = "onPrizeCategoryClick"
    })
    return [prizeTitleView].extend(arrayForView)
  }

  function getPrizesViewArrayByWeightCategory(prizes, category, title, params) {
    return this.getPrizesViewArrayByCategory(prizes, { title }.__update(getPrizeChanceConfig(category)), params)
  }

  getMaxPrizeButtonsCount = @(prizes) prizes.reduce(@(acc, prize) prize.buttonsCount > acc ? prize.buttonsCount : acc, 0)

  getItemPrizeRarityText = @(categoryText, tag = null) "".concat(categoryText, loc("ui/parentheses/space", {
    text = tag ?? loc("item/rarity1")
  }))
  getItemTypePrizeText = @(itemBlkType) loc(
    $"trophy/unlockables_names/{itemBlkType == "unit" ? "aircraft" : itemBlkType}")

  function getPrizesStacksViewByWeight(content, fixedAmountHeaderFunc, params) {
    let { shopDesc = false, stackLevel = prizesStack.DETAILED, categoryWeight, showOnlyCategoriesOfPrizes = false } = params
    let view = clone params
    local stacksList = this._stackContent(content, stackLevel, shopDesc)
    let fixedAmount = fixedAmountHeaderFunc ? this._getContentFixedAmount(content) : 1
    let isFitByItemType = function(prize, itemType) {
      if (prize.prizeType != PRIZE_TYPE.ITEM)
        return false

      let blkType = prize?.item.blkType
      if (itemType == blkType)
        return true

      return itemType == "unit" && unitItemTypes.contains(blkType)
    }
    let isFitByRarity = @(prize, rarity) rarity == prize?.item.getQuality()

    view.isCollapsable <- !showOnlyCategoriesOfPrizes
    if (fixedAmountHeaderFunc)
      view.header <- fixedAmountHeaderFunc(fixedAmount)

    params = clone params
    params.needShowDropChance <- false
    params.hasChanceIcon <- false
    params.fixedAmount <- fixedAmount
    params.categoryId <- 0

    let notFoundPrizes = []
    local prizeListView = []
    foreach (category in categoryWeight) {
      let itemBlkType = category.prizeType
      let byTypeLists = this.getFilteredListsData(stacksList,
        @(p) isFitByItemType(p, itemBlkType))

      local byTypeArray = byTypeLists.filteredItems
      stacksList = byTypeLists.lostPrizesList

      if (byTypeArray.len() == 0)
        continue

      let categoryText = this.getItemTypePrizeText(itemBlkType)
      if (category.weight != null) {
        params.categoryId++
        prizeListView.extend(this.getPrizesViewArrayByWeightCategory(
          byTypeArray, { weight = category.weight }, categoryText, params))

        continue
      }

      foreach (rarityWeight in category.rarity) {
        let rarity = rarityWeight.rarity
        let byRarityLists = this.getFilteredListsData(byTypeArray,
          @(p) isFitByRarity(p, rarity))

        let byRarityArray = byRarityLists.filteredItems
        byTypeArray = byRarityLists.lostPrizesList

        if (byRarityArray.len() == 0)
          continue

        params.categoryId++
        prizeListView.extend(this.getPrizesViewArrayByWeightCategory(byRarityArray,
          { weight = rarityWeight.weight },
          this.getItemPrizeRarityText(categoryText, byRarityArray[0]?.item.rarity.tag), params))
      }

      while (byTypeArray.len() > 0) {
        let rarity = byTypeArray[0]?.item.getQuality()
        if (rarity == null) {
          notFoundPrizes.append(byTypeArray[0])
          byTypeArray.remove(0)
          continue
        }

        let byRarityLists = this.getFilteredListsData(byTypeArray,
          @(p) isFitByRarity(p, rarity))

        let byRarityArray = byRarityLists.filteredItems
        byTypeArray = byRarityLists.lostPrizesList
        params.categoryId++
        prizeListView.extend(this.getPrizesViewArrayByWeightCategory(byRarityArray,
          { weight = "low" },
          this.getItemPrizeRarityText(categoryText, byRarityArray[0]?.item.rarity.tag), params))
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

      let byTypeLists = this.getFilteredListsData(stacksList,
        @(p) isFitByItemType(p, itemBlkType))

      let byTypeArray = byTypeLists.filteredItems
      stacksList = byTypeLists.lostPrizesList
      params.categoryId++
      prizeListView.extend(this.getPrizesViewArrayByWeightCategory(byTypeArray,
        { weight = "low" }, this.getItemTypePrizeText(itemBlkType), params))
    }

    if (notFoundPrizes.len() > 0) {
      params.categoryId++
      prizeListView.extend(this.getPrizesViewArrayByWeightCategory(
        stacksList, { weight = "low" }, loc("attachables/category/other"), params))
    }

    let maxButtonsCount = prizeListView.reduce(@(res, p) max(p?.buttonsCount ?? 0, res), 0)
    prizeListView = prizeListView.map(@(p) p.__update({
      buttonsCount = maxButtonsCount
      buttons = p?.buttons ? p.buttons.resize(maxButtonsCount, { emptyButton = true })
        : array(maxButtonsCount, { emptyButton = true })
    }))

    view.list <- prizeListView
    return handyman.renderCached(template, view)
  }


  function getPrizesStacksArrayForView(content, params = null) {
    local { shopDesc = false, stackLevel = prizesStack.DETAILED, fixedAmount = 1,
      needShowDropChance = false, stacksList = null,
      isFirstHighlightedLine = false } = params

    stacksList = stacksList ?? this._stackContent(content, stackLevel, shopDesc)
    let showCount = fixedAmount == 1

    local maxButtonsCount = 0
    local hasChanceIcon = false
    let prizeListView = []
    foreach (idx, st in stacksList) {
      local data = null
      if (st.level == prizesStack.NOT_STACKED)
        data = this.getPrizesViewData(st.prize, showCount, params)
      else if (st.stackType == STACK_TYPE.ITEM) { //onl stack by items atm, so this only to do last check.
        let detailed = st.level == prizesStack.DETAILED
        local name = ""
        if (detailed)
          name = st.item.getStackName(st.params)
        else
          name = colorize("activeTextColor", this._getItemTypeName(st.item))

        local countText = ""
        if (showCount && st.countMax > 1)
          countText = (st.countMin < st.countMax) ? (" x" + st.countMin + "-x" + st.countMax) : (" x" + st.countMax)

        let kinds = detailed ? "" : colorize("fadedTextColor", loc("ui/parentheses/space", { text = loc("trophy/item_type_different_kinds") }))
        data = {
          title = name + countText + kinds
          icon = this.getPrizeTypeIcon(st.prize)
        }
      }
      else if (st.stackType == STACK_TYPE.VEHICLE) {
        data = {
          title = this._getStackUnitsText(st)
        }
      }
      else if (st.stackType == STACK_TYPE.CURRENCY) {
        data = {
          icon = this.getPrizeTypeIcon(st.prize)
          title = this.getStackCurrencyText(st)
        }
      }
      if (data != null) {
        maxButtonsCount = max(data?.buttonsCount ?? 0, maxButtonsCount)
        if (needShowDropChance) {
          let chanceConfig = getPrizeChanceConfig(st.prize)
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
        let buttons = d?.buttons ?? []
        if (buttons.len() < maxButtonsCount)
          d.buttons <- buttons.resize(maxButtonsCount, { emptyButton = true })
      })
    }

    return prizeListView
  }

  getViewDataUnlockProgress = @(prize, _showCount, _params = null) {
    title = this.getPrizeText(prize)
    icon = this.getPrizeTypeIcon(prize)
  }

  function getPrizeDescription(prize) {
    let prizeType = this.getPrizeType(prize)
    return prizeViewConfig?[prizeType].getDescription(prize) ?? ""
  }

  function getDescriptonView(prizeConfig = {}) {
    let prizeType = this.getPrizeType(prizeConfig)
    let view = {
      textDesc = prizeViewConfig?[prizeType].getDescription(prizeConfig)
      markupDesc = prizeViewConfig?[prizeType].getDescriptionMarkup(prizeConfig)
    }

    return view
  }

  function getPrizeTooltipConfig(prize) {
    let prizeType = this.getPrizeType(prize)
    return prizeViewConfig?[prizeType].getTooltipConfig(prize) ?? {}
  }

  hasKnowPrize = @(prize) this.getPrizeType(prize) != PRIZE_TYPE.UNKNOWN

  function getPrizesStacksViewByCategory(content, fixedAmountHeaderFunc, params) {
    let { shopDesc = false, stackLevel = prizesStack.DETAILED, categoryByItems, showOnlyCategoriesOfPrizes = false } = params
    let view = clone params
    let fixedAmount = fixedAmountHeaderFunc ? this._getContentFixedAmount(content) : 1

    view.isCollapsable <- !showOnlyCategoriesOfPrizes
    if (fixedAmountHeaderFunc)
      view.header <- fixedAmountHeaderFunc(fixedAmount)

    params = clone params
    params.needShowDropChance <- false
    params.hasChanceIcon <- false
    params.fixedAmount <- fixedAmount
    params.categoryId <- 0

    local prizeListView = []
    foreach (category in categoryByItems) {
      let { categoryName, itemDefIds } = category
      local stacksList = []
      local packList = []
      foreach (itemDefId in itemDefIds) {
        let prizes = content.filter(@(p) p.fromGenId == itemDefId)
        if (prizes.len() == 0)
          continue

        let stacks = this._stackContent(prizes, stackLevel, shopDesc)
        if (::ItemsManager.getItemOrRecipeBundleById(itemDefId)?.isContentPack() ?? false)
          packList.extend(stacks)
        else
          stacksList.extend(stacks)
      }

      let categoryText = loc($"trophyCategory/{categoryName}")
      if (packList.len() != 0) {
        params.categoryId++
        prizeListView.extend(this.getPrizesViewArrayByCategory(packList,
          {
            title = "".concat(categoryText,
              loc("ui/parentheses/space", { text = utf8ToLower(loc("shop/giftAir/campaign")) }))
          },
          params))
      }

      if (stacksList.len() != 0) {
        params.categoryId++
        prizeListView.extend(this.getPrizesViewArrayByCategory(stacksList, { title = categoryText }, params))
      }
    }

    let maxButtonsCount = prizeListView.reduce(@(res, p) max(p?.buttonsCount ?? 0, res), 0)
    prizeListView = prizeListView.map(@(p) p.__update({
      buttonsCount = maxButtonsCount
      buttons = p?.buttons ? p.buttons.resize(maxButtonsCount, { emptyButton = true })
        : array(maxButtonsCount, { emptyButton = true })
    }))

    view.list <- prizeListView
    return handyman.renderCached(template, view)
  }
}

::PrizesView.getPrizeType <- function getPrizeType(prize) {
  if (this.isPrizeMultiAward(prize))
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
  if (isUnlockAddProgressPrize(prize))
    return PRIZE_TYPE.UNLOCK_PROGRESS
  return PRIZE_TYPE.UNKNOWN
}

::PrizesView.getStackType <- function getStackType(prize) {
  let prizeType = this.getPrizeType(prize)
  if (prizeType == PRIZE_TYPE.ITEM)
    return STACK_TYPE.ITEM
  if (isInArray(prizeType, [ PRIZE_TYPE.GOLD, PRIZE_TYPE.WARPOINTS, PRIZE_TYPE.EXP, PRIZE_TYPE.WARBONDS ]))
    return STACK_TYPE.CURRENCY
  if (isInArray(prizeType, [ PRIZE_TYPE.UNIT, PRIZE_TYPE.RENTED_UNIT ]))
    return STACK_TYPE.VEHICLE
  return STACK_TYPE.UNKNOWN
}

::PrizesView.getPrizeTypeName <- function getPrizeTypeName(prize, colored = true) {
  return this.getPrizeText(prize, colored, true)
}

::PrizesView.getPrizeText <- function getPrizeText(prize, colored = true, v_typeName = false,
    showCount = true, full = false, forcedColor = ""
) {
  if (!prize)
    return ""

  local name = ""
  local color = "activeTextColor"
  if (this.isPrizeMultiAward(prize)) {
    if (full) {
      name = TrophyMultiAward(prize).getDescription(true)
      color = ""
    }
    else
      name = TrophyMultiAward(prize).getName()
  }
  else if (prize?.unit) {
    if (v_typeName)
      name = loc("trophy/unlockables_names/aircraft")
    else {
      name = getUnitName(prize.unit, true)
      color = getUnitClassColor(prize.unit)
    }
  }
  else if (prize?.rentedUnit) {
    if (v_typeName)
      name = loc("shop/unitRent")
    else {
      let unitName = prize.rentedUnit
      let unitColor = getUnitClassColor(unitName)
      name = loc("shop/rentUnitFor", {
        unit = colorize(unitColor, getUnitName(unitName, true))
        time = colorize("userlogColoredText", time.hoursToString(prize?.timeHours ?? 0))
      })
    }
  }
  else if (prize?.item || prize?.trophy) {
    let id = prize?.item || prize?.trophy
    local item = findItemById(id)
    if (v_typeName) {
      name = this._getItemTypeName(item)
      color = item ? "activeTextColor" : "red"
    }
    else {
      if (!item)
        name = id
      else {
        if (workshop.shouldDisguiseItem(item)) {
          item = item.makeEmptyInventoryItem()
          item.setDisguise(true)
        }
        name = item.getPrizeDescription(prize?.count ?? 1, colored)
        if (name)
          showCount = false
        else
          name = item.getShortDescription(colored)
      }
      color = item ? "activeTextColor" : "red"
    }
  }
  else if (prize?.premium_in_hours) {
    name = loc("charServer/entitlement/PremiumAccount") + loc("ui/colon") + time.hoursToString(prize.premium_in_hours)
    color = "userlogColoredText"
  }
  else if (prize?.entitlement) {
    name = getEntitlementName(getEntitlementConfig(prize.entitlement))
    color = "userlogColoredText"
  }
  else if (prize?.unlock) {
    let unlockId = prize.unlock
    let unlockType = getUnlockType(unlockId)
    let typeValid = unlockType >= 0

    local unlockTypeName = isLoadingBgUnlock(unlockId)
      ? loc("loading_bg")
      : loc($"trophy/unlockables_names/{typeValid ? get_name_by_unlock_type(unlockType) : "unknown"}")
    unlockTypeName = colored ? colorize(typeValid ? "activeTextColor" : "red", unlockTypeName) : unlockTypeName

    name = unlockTypeName
    if (!v_typeName) {
      local nameText = getUnlockNameText(unlockType, unlockId)
      if (colored)
        nameText = colorize(typeValid ? "userlogColoredText" : "red", nameText)
      if (unlockType != UNLOCKABLE_SLOT && nameText != "")
        name += loc("ui/colon") + nameText
    }
    if (full)
      name += "\n" + getFullUnlockDescByName(unlockId)
    color = "commonTextColor"
  }
  else if (prize?.unlockType)
    name = loc($"trophy/unlockables_names/{prize.unlockType}")
  else if (prize?.resource) {
    if (prize?.resourceType) {
      let decoratorType = getTypeByResourceType(prize.resourceType)
      let locName = decoratorType.getLocName(prize.resource, true)
      let valid = decoratorType != decoratorTypes.UNKNOWN
      let decorator = getDecorator(prize.resource, decoratorType)
      name = locName

      if (colored) {
        let nameColor = !valid ? "badTextColor"
          : forcedColor != "" ? forcedColor
          : decorator ? decorator.getRarityColor()
          : "activeTextColor"
        name = colorize(nameColor, name)
      }
    }
  }
  else if (prize?.resourceType)
    name = loc($"trophy/unlockables_names/{prize.resourceType}")
  else if (prize?.gold)
    name = Cost(0, prize.gold).toStringWithParams({ isGoldAlwaysShown = true, isColored = colored })
  else if (prize?.warpoints)
    name = Cost(prize.warpoints).toStringWithParams({ isWpAlwaysShown = true, isColored = colored })
  else if (prize?.exp)
    name = Cost().setFrp(prize.exp).toStringWithParams({ isColored = colored })
  else if (prize?.warbonds) {
    let wb = ::g_warbonds.findWarbond(prize.warbonds)
    name = wb && prize?.count ? wb.getPriceText(prize.count, true, false) : ""
    showCount = false
  }
  else if (prize?.unlockAddProgress) {
    let viewProgressConfig = getUnlockAddProgressViewConfig(prize.unlockAddProgress)
    name = viewProgressConfig?.getText(prize, v_typeName) ?? ""
    showCount = viewProgressConfig?.showCount ?? true
  }
  else {
    name = loc("item/unknown")
    color = "red"
  }

  local countText = ""
  if (showCount) {
    let count = prize?.count ?? 1
    countText = (!v_typeName && count > 1) ? " x" + count : ""
    if (colored)
      countText = colorize("commonTextColor", countText)
  }

  let commentText = prize?.commentText ?? ""

  if (forcedColor != "")
    color = forcedColor
  name = colored && color.len() ? colorize(color, name) : name
  return $"{name}{countText}{commentText}"
}

::PrizesView._getItemTypeName <- function _getItemTypeName(item) {
  return item ? item.getTypeName() : ""
}

::PrizesView.getPrizeTypeIcon <- function getPrizeTypeIcon(prize, unitImage = false) {
  if (!prize || prize?.noIcon)
    return ""
  if (this.isPrizeMultiAward(prize))
    return TrophyMultiAward(prize).getTypeIcon()
  if (prize?.unit)
    return unitImage ? ::image_for_air(prize.unit) : ::getUnitClassIco(prize.unit)
  if (prize?.rentedUnit)
    return "#ui/gameuiskin#item_type_rent.svg"
  if (prize?.item) {
    let item = findItemById(prize.item)
    return item?.getSmallIconName() ?? BaseItem.typeIcon
  }
  if (prize?.trophy) {
    let item = findItemById(prize.trophy)
    if (!item)
      return BaseItem.typeIcon
    let topPrize = item.getTopPrize()
    return topPrize ? this.getPrizeTypeIcon(topPrize) : "#ui/gameuiskin#item_type_trophies.svg"
  }
  if (prize?.premium_in_hours)
    return "#ui/gameuiskin#item_type_premium.svg"
  if (prize?.entitlement)
    return "#ui/gameuiskin#item_type_premium.svg"
  if (prize?.unlock || prize?.unlockType) {
    local unlockType = prize?.unlockType || getUnlockType(prize?.unlock)
    if (type(unlockType) == "string")
      unlockType = get_unlock_type(unlockType)
    return getTypeByUnlockedItemType(unlockType).prizeTypeIcon
  }

  if (prize?.resourceType)
    return getTypeByResourceType(prize.resourceType).prizeTypeIcon

  if (prize?.gold)
    return "#ui/gameuiskin#item_type_eagles.svg"
  if (prize?.warpoints)
    return "#ui/gameuiskin#item_type_warpoints.svg"
  if (prize?.exp)
    return "#ui/gameuiskin#item_type_Free_RP.svg"
  if (prize?.warbonds)
    return "#ui/gameuiskin#item_type_warbonds.svg"
  if (prize?.unlockAddProgress) {
    let viewProgreesConfig = getUnlockAddProgressViewConfig(prize.unlockAddProgress)
    return viewProgreesConfig?.image ?? ""
  }
  return "#ui/gameuiskin#item_type_placeholder.svg"
}

::PrizesView.isPrizeMultiAward <- function isPrizeMultiAward(prize) {
  return prize?.multiAwardsOnWorthGold != null
         || prize?.modsForBoughtUnit != null
}

::PrizesView._getContentFixedAmount <- function _getContentFixedAmount(content) {
  local res = -1
  foreach (prize in content) {
    let itemCount = prize?.count ?? 1
    if (res == itemCount)
      continue
    if (res >= 1)
      return 1
    res = itemCount
  }
  return max(res, 1)
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
::PrizesView._createStack <- function _createStack(prize) {
  let count = prize?.count ?? 1
  return {
    prizeType = this.getPrizeType(prize)
    stackType = this.getStackType(prize)
    level = prizesStack.NOT_STACKED
    size = 1
    prize = prize
    item = null
    countMin = count
    countMax = count
    params = null
  }
}

::PrizesView._findOneStack <- function _findOneStack(stackList, prizeType, checkFunc = function(_s) { return true }) {
  foreach (stack in stackList)
    if (prizeType == stack.prizeType && checkFunc(stack))
      return stack
  return null
}

::PrizesView._addPrizeItemToStack <- function _addPrizeItemToStack(stack, item, prize, stackLevel) {
  let count = prize?.count ?? 1
  stack.countMin = min(stack.countMin, count)
  stack.countMax = max(stack.countMax, count)
  stack.level    = max(stack.level, stackLevel)
  stack.size++
  if (stack?.params)
    item.updateStackParams(stack.params)
}

::PrizesView._findAndStackPrizeItem <- function _findAndStackPrizeItem(prize, stackList, stackLevel) {
  let item = findItemById(prize?.item)
  if (!item)
    return true

  let itype = item.iType
  local stack = this._findOneStack(stackList, PRIZE_TYPE.ITEM, function(stack) {
      let sItem = stack.item
      if (!sItem || sItem.iType != itype)
        return false

      local curStackLevel = prizesStack.BY_TYPE //real stack level, can be lower than requested
      if (sItem.canStack(item))
        curStackLevel = prizesStack.DETAILED

      if (curStackLevel > stackLevel)
        return false

      this._addPrizeItemToStack(stack, item, prize, curStackLevel)
      return true
    })

  if (stack)
    return true

  stack = this._createStack(prize)
  stack.item = item
  stack.params = {}
  item.updateStackParams(stack.params)
  stackList.append(stack)
  return true
}

::PrizesView.getPrizeCurrencyCfg <- function getPrizeCurrencyCfg(prize) {
  if ((prize?.gold ?? 0) > 0)
    return { type = PRIZE_TYPE.GOLD, val = prize.gold, printFunc = @(val) Cost(0, val).tostring() }
  if ((prize?.warpoints ?? 0) > 0)
    return {  type = PRIZE_TYPE.WARPOINTS, val = prize.warpoints, printFunc = @(val) Cost(val).tostring() }
  if ((prize?.exp ?? 0) > 0)
    return {  type = PRIZE_TYPE.EXP, val = prize.exp, printFunc = @(val) Cost().setFrp(val).tostring() }
  if (prize?.warbonds && (prize?.count ?? 0) > 0) {
    let wbId = prize.warbonds
    return {  type = PRIZE_TYPE.WARBONDS, val = prize.count, printFunc = @(val) ::g_warbonds.findWarbond(wbId).getPriceText(val, true, false) }
  }
  return null
}

::PrizesView._findAndStackPrizeCurrency <- function _findAndStackPrizeCurrency(prize, stackList) {
  let prizeType = this.getPrizeType(prize)

  local stack = this._findOneStack(stackList, prizeType)

  let cfg = this.getPrizeCurrencyCfg(prize)
  if (!cfg)
    return false

  if (stack) {
    stack.countMin = min(stack.countMin, cfg.val)
    stack.countMax = max(stack.countMax, cfg.val)
    stack.level = prizesStack.DETAILED
    return true
  }

  stack = this._createStack(prize)
  stack.countMin = cfg.val
  stack.countMax = cfg.val
  stack.params = { printFunc = cfg.printFunc }
  stackList.append(stack)
  return true
}

::PrizesView.getStackCurrencyText <- function getStackCurrencyText(stack) {
  let printFunc = stack.params.printFunc
  local res = printFunc(stack.countMin)
  if (stack.countMin != stack.countMax)
    res += " - " + printFunc(stack.countMax)
  return colorize("activeTextColor", res)
}

::PrizesView._findAndStackPrizeUnit <- function _findAndStackPrizeUnit(prize, stackList, stackLevel, shopDesc) {
  if (shopDesc)
    return false

  let prizeType = this.getPrizeType(prize)

  local stack = this._findOneStack(stackList, prizeType)

  if (stack) {
    stack.params.prizes.append(prize)
    stack.size++

    if (stack.size >= UNITS_STACK_BY_TYPE_COUNT)
      stack.level = max(prizesStack.BY_TYPE, stackLevel)
    else if (stack.size >= UNITS_STACK_DETAILED_COUNT)
      stack.level = max(prizesStack.DETAILED, stackLevel)

    return true
  }

  stack = this._createStack(prize)
  stack.params = {
    prizes = [ prize ]
  }
  stackList.append(stack)
  return true
}

::PrizesView._getStackUnitsText <- function _getStackUnitsText(stack) {
  let isDetailed = stack.level == prizesStack.DETAILED
  let prizeType = this.getPrizeType(stack.prize)
  let isRent = prizeType == PRIZE_TYPE.RENTED_UNIT

  let units = []
  foreach (p in stack.params.prizes) {
    let unitId = isRent ? p.rentedUnit : p.unit
    let color = getUnitClassColor(unitId)
    local name = colorize(color, getUnitName(unitId))
    if (isRent)
      name = "".concat(name, this._getUnitRentComment(getAircraftByName(unitId), p.timeHours, p.numSpares, true))
    units.append(name)
  }

  let header = this.getPrizeTypeName(stack.prize)
  let headerSeparator = loc("ui/colon") + (isDetailed ? "\n" : "")
  let unitsSeparator  = isDetailed ? "\n" : loc("ui/comma")

  return header + headerSeparator + unitsSeparator.join(units, true)
}

::PrizesView._stackContent <- function _stackContent(content, stackLevel = prizesStack.BY_TYPE, shopDesc = false) {
  let res = []
  foreach (prize in content) {
    let stackType = this.getStackType(prize)

    if (stackType == STACK_TYPE.ITEM && this._findAndStackPrizeItem(prize, res, stackLevel))
      continue
    if (stackType == STACK_TYPE.CURRENCY && this._findAndStackPrizeCurrency(prize, res))
      continue
    if (stackType == STACK_TYPE.VEHICLE && this._findAndStackPrizeUnit(prize, res, stackLevel, shopDesc))
      continue

    res.append(this._createStack(prize))
  }
  return res
}

::PrizesView.getPrizesListText <- function getPrizesListText(content, fixedAmountHeaderFunc = null, hasHeaderWithoutContent = true) {
  if (!hasHeaderWithoutContent && !content.len())
    return ""

  let stacksList = this._stackContent(content, prizesStack.DETAILED)
  let fixedAmount = fixedAmountHeaderFunc ? this._getContentFixedAmount(content) : 1 //1 - dont use fixed amount
  let showCount = fixedAmount == 1
  let list = []

  if (fixedAmountHeaderFunc)
    list.append(fixedAmountHeaderFunc(fixedAmount))

  let listMarker = nbsp + colorize("grayOptionColor", loc("ui/mdash")) + nbsp
  foreach (st in stacksList) {
    if (st.level == prizesStack.NOT_STACKED)
      list.append(listMarker + this.getPrizeText(st.prize, true, false, showCount))
    else if (st.stackType == STACK_TYPE.ITEM) { //onl stack by items atm, so this only to do last check.
      let detailed = st.level == prizesStack.DETAILED

      local name = ""
      if (detailed)
        name = st.item.getStackName(st.params)
      else
        name = colorize("activeTextColor", this._getItemTypeName(this.item))

      local countText = ""
      if (showCount && st.countMax > 1)
        countText = (st.countMin < st.countMax) ? (" x" + st.countMin + "-x" + st.countMax) : (" x" + st.countMax)

      let kinds = detailed ? "" : colorize("fadedTextColor", loc("ui/parentheses/space", { text = loc("trophy/item_type_different_kinds") }))
      list.append(listMarker + name + countText + kinds)
    }
    else if (st.stackType == STACK_TYPE.VEHICLE) {
      list.append(listMarker + this._getStackUnitsText(st))
    }
    else if (st.stackType == STACK_TYPE.CURRENCY) {
      list.append(listMarker + this.getStackCurrencyText(st))
    }
  }

  return "\n".join(list, true)
}

::PrizesView.getViewDataUnit <- function getViewDataUnit(unitName, params = null, rentTimeHours = 0, numSpares = 0) {
  let unit = getAircraftByName(unitName)
  if (!unit)
    return null

  let isBought = ::isUnitBought(unit)
  let receivedPrizes = getTblValue("receivedPrizes", params, true)
  let classIco = getTblValue("singlePrize", params, false) ? null : ::getUnitClassIco(unit)
  let countryIco = getUnitCountryIcon(unit, false)
  let shopItemType = getUnitRole(unit)
  let isShowLocalState = receivedPrizes || rentTimeHours > 0
  let buttons = this.getPrizeActionButtonsView({ unit = unitName }, params)
  let receiveOnce = params?.relatedItem ? "mainmenu/activateOnlyOnce" : "mainmenu/receiveOnlyOnce"
  local infoText = ""
  if (rentTimeHours > 0)
    infoText = this._getUnitRentComment(unit, rentTimeHours, numSpares, false)
  else if (rentTimeHours == 0 && numSpares > 0)
    infoText = this._getUnitSparesComment(unit, numSpares)
  if (!receivedPrizes && isBought)
    infoText += (infoText.len() ? "\n" : "") + colorize("badTextColor", loc(receiveOnce))

  let unitPlate = buildUnitSlot(unitName, unit, {
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
      numSpares
    }
  })
  return {
    classIco = classIco,
    countryIco = countryIco,
    shopItemType = shopItemType,
    unitPlate = unitPlate,
    commentText = infoText.len() ? infoText : null
    buttons = buttons
    buttonsCount = buttons.len()
  }
}

::PrizesView.getViewDataRentedUnit <- function getViewDataRentedUnit(unitName, params, timeHours, numSpares) {
  if (!timeHours)
    return null

  return this.getViewDataUnit(unitName, params, timeHours, numSpares)
}

::PrizesView._getUnitRentComment <- function _getUnitRentComment(unit, rentTimeHours = 0, numSpares = 0, short = false) {
  if (rentTimeHours == 0)
    return ""
  let timeStr = colorize("userlogColoredText", time.hoursToString(rentTimeHours))
  local text = short ? timeStr :
    colorize("activeTextColor", loc("shop/rentFor", { time =  timeStr }))
  if (numSpares > 0)
    text = "".concat(text, this._getUnitSparesComment(unit, numSpares))
  return short ? loc("ui/parentheses/space", { text = text }) : text
}

::PrizesView._getUnitSparesComment <- function _getUnitSparesComment(unit, numSpares) {
  let spareCost = getGiftSparesCost(unit)
  let giftSparesLoc = unit.isUsable() ? "mainmenu/giftSparesAdded" : "mainmenu/giftSpares"
  return colorize("grayOptionColor", loc(giftSparesLoc, { num = numSpares, cost = Cost().setGold(spareCost * numSpares) }))
}

::PrizesView.getViewDataMod <- function getViewDataMod(unitName, modName, params) {
  let unit = getAircraftByName(unitName)
  if (!unit)
    return null

  let { showTooltip = true } = params
  local icon = ""
  if (modName == "premExpMul") //talisman
    icon = "#ui/gameuiskin#item_type_talisman.svg"
  else
    icon = unit?.isTank() ? "#ui/gameuiskin#item_type_modification_tank.svg" : "#ui/gameuiskin#item_type_modification_aircraft.svg"

  return {
    icon = icon
    classIco = ::getUnitClassIco(unit)
    icon2 = getUnitCountryIcon(unit)
    shopItemType = getUnitRole(unit)
    title = colorize("activeTextColor", getUnitName(unitName, true)) + loc("ui/colon")
      + colorize("userlogColoredText",
        getModificationName(unit, modName))
    tooltipId = showTooltip ? MODIFICATION.getTooltipId(unitName, modName) : null
  }
}

::PrizesView.getViewDataSpare <- function getViewDataSpare(unitName, count, params) {
  let unit = getAircraftByName(unitName)
  let spare = getTblValue("spare", unit)
  if (!spare)
    return null

  let { showTooltip = true } = params
  local title = colorize("activeTextColor", getUnitName(unitName, true)) + loc("ui/colon")
              + colorize("userlogColoredText", loc("spare/spare"))
  if (count && count > 1)
    title += colorize("activeTextColor", " x" + count)
  return {
    icon = "#ui/gameuiskin#item_type_spare.svg"
    icon2 = getUnitCountryIcon(unit)
    shopItemType = getUnitRole(unit)
    title = title
    tooltipId = showTooltip ? SPARE.getTooltipId(unitName) : null
  }
}

::PrizesView.getViewDataSpecialization <- function getViewDataSpecialization(prize, params) {
  let specLevel = prize?.specialization ?? 1
  let unitName = prize?.unitName
  let unit = getAircraftByName(unitName)
  if (!unit)
    return null

  let { showTooltip = true } = params
  let crew = getCrewById(prize?.crew ?? 0)
  let title = colorize("userlogColoredText", getCrewName(crew)) + loc("ui/colon")
              + colorize("activeTextColor", getUnitName(unit))
              + ", " + colorize("userlogColoredText", loc("crew/qualification/" + specLevel))
  return {
    icon = (specLevel == 2) ? "#ui/gameuiskin#item_type_crew_aces.svg" : "#ui/gameuiskin#item_type_crew_experts.svg"
    icon2 = getUnitCountryIcon(unit)
    title = title
    tooltipId = showTooltip ? getTooltipType("UNIT").getTooltipId(unitName) : null
  }
}

::PrizesView.getViewDataDecorator <- function getViewDataDecorator(prize, params = null) {
  let { showTooltip = true } = params
  let id = prize?.resource ?? ""
  let decoratorType = getTypeByResourceType(prize?.resourceType)
  let isHave = decoratorType.isPlayerHaveDecorator(id)
  let isReceivedPrizes = params?.receivedPrizes ?? false
  let buttons = this.getPrizeActionButtonsView(prize, params)
  let receiveOnce = params?.relatedItem ? "mainmenu/activateOnlyOnce" : "mainmenu/receiveOnlyOnce"

  return {
    icon  = decoratorType.prizeTypeIcon
    title = this.getPrizeText(prize)
    tooltipId = showTooltip ? getTooltipType("DECORATION").getTooltipId(id, decoratorType.unlockedItemType, params) : null
    commentText = !isReceivedPrizes && isHave ?  colorize("badTextColor", loc(receiveOnce)) : null
    buttons = buttons
    buttonsCount = buttons.len()
  }
}

::PrizesView.getViewDataItem <- function getViewDataItem(prize, showCount, params = null) {
  let { showTooltip = true } = params
  let primaryIcon = prize?.primaryIcon
  let buttons = this.getPrizeActionButtonsView(prize, params)
  let item = findItemById(prize?.item)
  let itemIcon = (params?.isShowItemIconInsteadItemType ?? false) && item
    ? item.getIconName()
    : this.getPrizeTypeIcon(prize)
  return {
    icon  = primaryIcon ? primaryIcon : itemIcon
    icon2 = primaryIcon ? itemIcon : null
    title = (params?.needShowItemName ?? true)
      ? this.getPrizeText(prize, !params?.isLocked, false, showCount, true)
      : prize?.commentText ?? ""
    tooltipId = showTooltip ? getTooltipType("ITEM").getTooltipId(prize?.item) : null
    buttons = buttons
    buttonsCount = buttons.len()
  }
}

::PrizesView.getViewDataMultiAward <- function getViewDataMultiAward(prize, _params = null) {
  let multiAward = TrophyMultiAward(prize)
  return {
    icon = multiAward.getTypeIcon()
    title = multiAward.getDescription(true)
  }
}

::PrizesView.getViewDataDefault <- function getViewDataDefault(prize, showCount, params = null) {
  //!!FIX ME: better to refactor this. it used only here, but each function try do detect prize type by self
  //much faster will be to get viewData array and gen desc by it than in each function detect prize type.
  //Now we have function getPrizeType() for prize type detection.
  let { showTooltip = true } = params
  local needShowFullTitle = true
  local needShowIcon = true
  let tooltipId = !showTooltip ? null
    : prize?.trophy ? getTooltipType("UNLOCK").getTooltipId(prize.trophy)
    : prize?.unlock ? getTooltipType("SUBTROPHY").getTooltipId(prize.unlock, params)
    : null

  local previewImage = null
  local commentText = null
  if (prize?.unlock) {
    if (params?.showAsTrophyContent && isUnlockOpened(prize.unlock))
      commentText = colorize("badTextColor", loc("mainmenu/receiveOnlyOnce"))
    if (getUnlockType(prize.unlock) == UNLOCKABLE_PILOT) {
      needShowFullTitle = false
      needShowIcon = false
      previewImage = "cardAvatar { value:t='" + prize.unlock + "'}"
    }
  }

  let title = this.getPrizeText(prize, true, false, showCount, needShowFullTitle)
  let icon = needShowIcon ? this.getPrizeTypeIcon(prize) : null

  return {
    icon = icon,
    title = title,
    tooltipId = tooltipId,
    previewImage = previewImage
    commentText = commentText
  }
}

::PrizesView.getPrizesViewData <- function getPrizesViewData(prize, showCount = true, params = null) {
  if (this.isPrizeMultiAward(prize))
    return this.getViewDataMultiAward(prize, params)

  let unitName = prize?.unit

  if (unitName)
    if (prize?.mod)
      return this.getViewDataMod(unitName, prize?.mod, params)
    else
      return this.getViewDataUnit(unitName, params, prize?.timeHours ?? 0, prize?.numSpares ?? 0)
  if (prize?.rentedUnit)
    return this.getViewDataRentedUnit(prize?.rentedUnit, params, prize?.timeHours, prize?.numSpares)
  if (prize?.spare)
    return this.getViewDataSpare(prize?.spare, showCount ? prize?.count : 0, params)
  if (prize?.specialization)
    return this.getViewDataSpecialization(prize, params)
  if (prize?.resourceType)
    return this.getViewDataDecorator(prize, params)
  if (prize?.item)
    return this.getViewDataItem(prize, showCount, params)
  if (prize?.warbonds)
    return this.getViewDataDefault(prize, false, params)
  if (isUnlockAddProgressPrize(prize))
    return this.getViewDataUnlockProgress(prize, showCount, params)
  return this.getViewDataDefault(prize, showCount, params)
}

::PrizesView.getPrizesListView <- function getPrizesListView(content, params = null, hasHeaderWithoutContent = true) {
  if (!hasHeaderWithoutContent && !content.len())
    return ""

  let view = params ? clone params : {}
  if ("headerParams" in params) {
    view.__update(params.headerParams)
    params.$rawdelete("headerParams")
  }

  if (content.len() == 1) {
    if (!params)
      params = {}
    params.singlePrize <- true
  }

  if (!view?.timerId && view?.header == "")
    view.$rawdelete("header")

  view.list <- []
  foreach (prize in content) {
    let data = this.getPrizesViewData(prize, true, params)
    if (data)
      view.list.append(data)
  }
  return handyman.renderCached(template, view)
}

::PrizesView.getPrizesStacksView <- function getPrizesStacksView(content, fixedAmountHeaderFunc = null, params = {}) {
  let { stackLevel = prizesStack.DETAILED } = params
  if (stackLevel == prizesStack.NOT_STACKED && !fixedAmountHeaderFunc)
    return this.getPrizesListView(content, params)

  let view = clone params
  let fixedAmount = fixedAmountHeaderFunc ? this._getContentFixedAmount(content) : 1
  if (fixedAmountHeaderFunc)
    view.header <- fixedAmountHeaderFunc(fixedAmount)

  params.fixedAmount <- fixedAmount
  view.list <- this.getPrizesStacksArrayForView(content, params)
  return handyman.renderCached(template, view)
}

::PrizesView.getPrizeActionButtonsView <- function getPrizeActionButtonsView(prize, params = null) {
  let view = []
  if (!params?.shopDesc)
    return view

  let itemId = prize?.item ?? params?.relatedItem
  if (itemId) {
    let item = findItemById(itemId)
    if (!item || workshop.shouldDisguiseItem(item))
      return view
    if (item.canPreview() && isInMenu()) {
      let gcb = globalCallbacks.ITEM_PREVIEW
      view.append({
        image = "#ui/gameuiskin#btn_preview.svg"
        tooltip = "#mainmenu/btnPreview"
        funcName = gcb.cbName
        actionParamsMarkup = gcb.getParamsMarkup({ itemId = item.id })
      })
    }
    if (item.hasLink()) {
      let gcb = globalCallbacks.ITEM_LINK
      view.append({
        image = "#ui/gameuiskin#gc.svg"
        tooltip = "#" + item.linkActionLocId
        funcName = gcb.cbName
        actionParamsMarkup = gcb.getParamsMarkup({ itemId = item.id })
      })
    }
    return view
  }

  let unitId = prize?.unit || prize?.rentedUnit
  if (unitId && getAircraftByName(unitId)?.isInShop) {
    let gcb = globalCallbacks.UNIT_PREVIEW
    view.append({
      image = "#ui/gameuiskin#btn_preview.svg"
      tooltip = "#mainmenu/btnPreview"
      funcName = gcb.cbName
      actionParamsMarkup = gcb.getParamsMarkup({ unitId = unitId })
    })
    return view
  }

  let resource = prize?.resource
  let resourceType = prize?.resourceType
  if (resource && resourceType) {
    let gcb = globalCallbacks.DECORATOR_PREVIEW
    let decType = getTypeByResourceType(resourceType)
    let decorator = getDecorator(resource, decType)
    if (decorator?.canPreview())
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