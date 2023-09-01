//-file:plus-string
from "%scripts/dagui_library.nut" import *

let { Cost } = require("%scripts/money.nut")

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")

let { format } = require("string")
let DataBlock  = require("DataBlock")
let DataBlockAdapter = require("%scripts/dataBlockAdapter.nut")
let inventoryClient = require("%scripts/inventory/inventoryClient.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let asyncActions = require("%sqStdLibs/helpers/asyncActions.nut")
let time = require("%scripts/time.nut")
let { getCustomLocalizationPresets, getRandomEffect,
  getEffectOnStartCraftPresetById } = require("%scripts/items/workshop/workshop.nut")
let startCraftWnd = require("%scripts/items/workshop/startCraftWnd.nut")
let { getUserstatItemRewardData,
  userstatItemsListLocId, userstatRewardTitleLocId
} = require("%scripts/userstat/userstatItemsRewards.nut")
let { autoConsumeItems } = require("%scripts/items/autoConsumeItems.nut")
let { isMarketplaceEnabled } = require("%scripts/items/itemsMarketplace.nut")
let { showExternalTrophyRewardWnd } = require("%scripts/items/showExternalTrophyRewardWnd.nut")

global enum MARK_RECIPE {
  NONE
  BY_USER
  USED
}

let markRecipeSaveId = "markRecipe/"

let recipeComponentHeaderParams = {
  headerFont = "mediumFont"
  hasHeaderPadding = true
  isCentered = true
}

let defaultLocIdsList = {
  craftTime                 = "msgBox/assembleItem/time"
  rewardTitle               = "mainmenu/itemAssembled/title"
  headerRecipeMarkup        = "msgBox/items_will_be_spent"
  craftFinishedTitlePrefix  = "mainmenu/craftFinished/title/"
  markTooltipPrefix         = "item/recipes/markTooltip/"
  markDescPrefix            = "item/recipes/markDesc/"
  markMsgBoxCantUsePrefix   = "msgBox/craftProcess/cant/"
  msgBoxConfirmWhithItemName = null
  actionButton              = null
}

let function showExchangeInventoryErrorMsg(errorId, componentItem) {
  let locIdPrefix = componentItem.getLocIdsList()?.inventoryErrorPrefix
  ::showInfoMsgBox(loc($"{locIdPrefix}{errorId}", { itemName = componentItem.getName() }),
    "exchange_inventory_error")
}

local lastRecipeIdx = 0
local ExchangeRecipes = class {
  idx = 0
  uid = ""
  components = null
  generatorId = null
  requirement = null
  mark = null

  isUsable = false
  isMultipleItems = false
  isFake = false
  hasChestInComponents = false
  shouldSkipMsgBox = false

  craftTime = 0
  initedComponents = null
  isDisassemble = false

  locIdsList = null
  localizationPresetName = null
  sortReqQuantityComponents = 0
  effectOnStartCraftPresetName = null
  reqItems = null
  visibleComponents = null
  allowableComponents = null
  showRecipeAsProduct = null

  constructor(params) {
    this.idx = lastRecipeIdx++
    this.generatorId = params.generatorId
    this.isFake = params?.isFake ?? false
    this.craftTime = params?.craftTime ?? 0
    this.isDisassemble = params?.isDisassemble ?? false
    this.localizationPresetName = params?.localizationPresetName
    this.effectOnStartCraftPresetName = params?.effectOnStartCraftPresetName ?? ""
    this.allowableComponents = params?.allowableComponents
    this.showRecipeAsProduct = params?.showRecipeAsProduct
    this.shouldSkipMsgBox = !!params?.shouldSkipMsgBox

    let parsedRecipe = params.parsedRecipe
    this.initedComponents = parsedRecipe.components
    this.reqItems = parsedRecipe.reqItems
    this.sortReqQuantityComponents = this.initedComponents.filter(this.isVisibleComponent.bindenv(this))
        .map(@(component) component.quantity).reduce(@(res, value) res + value, 0)
      + this.reqItems.filter(this.isVisibleComponent.bindenv(this))
        .map(@(component) component.quantity).reduce(@(res, value) res + value, 0)
    this.requirement = parsedRecipe.requirement

    let recipeStr = this.requirement != null ? this.getRecipeStr() : parsedRecipe.recipeStr
    this.uid = $"{this.generatorId};{recipeStr}"

    this.updateComponents()
    this.loadStateRecipe()
  }

  function updateComponents() {
    let componentsArray = (clone this.initedComponents).extend(this.reqItems)
    let componentsCount = componentsArray.len()
    this.isUsable = componentsCount > 0
    this.isMultipleItems = componentsCount > 1

    local extraItemsCount = 0
    this.components = []
    this.visibleComponents = []
    let componentItemdefArray = componentsArray.map(@(c) c.itemdefid)
    let items = ::ItemsManager.getInventoryList(itemType.ALL,
      @(item) isInArray(item.id, componentItemdefArray))
    this.hasChestInComponents = u.search(items, @(i) i.iType == itemType.CHEST) != null
    foreach (component in componentsArray) {
      let curQuantity = items.filter(@(i) i.id == component.itemdefid).reduce(
        @(res, item) res + item.amount, 0)
      let reqQuantity = component.quantity
      let isHave = curQuantity >= reqQuantity
      this.isUsable = this.isUsable && isHave
      let shopItem = ::ItemsManager.findItemById(component.itemdefid)
      local cost = null
      if (shopItem?.isCanBuy() ?? false) {
        cost = Cost() + shopItem.getCost()
        cost = cost.setFromTbl({
          wp = cost.wp * reqQuantity
          gold = cost.gold * reqQuantity
        })
      }

      this.components.append({
        has = isHave
        itemdefId = component.itemdefid
        reqQuantity = reqQuantity
        curQuantity = curQuantity
        cost = cost
      })

      let isVisible = this.isVisibleComponent(component)
      if (isVisible)
        this.visibleComponents.append(this.components.top())

      if (reqQuantity > 1)
        this.isMultipleItems = true
      if (isVisible && component.itemdefid != this.generatorId)
        extraItemsCount++
    }
  }

  function isEnabled() {
    return this.requirement == null || hasFeature(this.requirement)
  }

  function hasComponent(itemdefid) {
    foreach (c in this.components)
      if (c.itemdefId == itemdefid)
        return true
    return false
  }

  isVisibleComponent = @(component) this.allowableComponents == null || (component.itemdefid in this.allowableComponents)

  function getExchangeMarkup(componentItem, params) {
    let list = []
    foreach (component in this.visibleComponents) {
      if (component.itemdefId == componentItem.id)
        continue
      list.append(DataBlockAdapter({
        item  = component.itemdefId
        commentText = this.getComponentQuantityText(component)
      }))
    }
    return ::PrizesView.getPrizesListView(list, params, false)
  }

  function getItemsListForPrizesView(params = null) {
    if (params?.canOpenForGold ?? false)
      return [{ gold = this.getOpenCost(params?.componentToHide)?.gold ?? 0 }]
    let res = []
    let visibleResources = params?.visibleResources ?? this.allowableComponents
    foreach (component in this.components)
      if (component.itemdefId != params?.componentToHide?.id
       && (visibleResources == null || visibleResources?[component.itemdefId]))
        res.append(DataBlockAdapter({
          item  = component.itemdefId
          commentText = this.getComponentQuantityText(component, params)
        }))
    return res
  }

  function getTextMarkup(params = null) {
    if (!params)
      params = {}
    params = params.__merge({ isLocked = this.isRecipeLocked() })

    let list = this.getItemsListForPrizesView(params)
    return ::PrizesView.getPrizesListView(list, params, false)
  }

  function getText(params = null) {
    let list = this.getItemsListForPrizesView(params)
    let headerFunc = params?.header ? @(...) params.header : null
    return ::PrizesView.getPrizesListText(list, headerFunc, false)
  }

  function hasCraftTime() {
    return this.craftTime > 0
  }

  function getCraftTime() {
    return this.craftTime
  }

  function getCraftTimeText() {
    return loc(this.getLocIdsList().craftTime,
      { time = loc("icon/hourglass") + " " + time.secondsToString(this.craftTime, true, true) })
  }

  getItemMarkupParams = @() {
     contentIcon = false
     hasTimer = false
     addItemName = false
     showPrice = false
     showAction = false
     shouldHideAdditionalAmmount = true
  }

  function getIconedMarkup() {
    let itemsViewData = []
    if (this.showRecipeAsProduct != null) {
      let item = ::ItemsManager.findItemById(this.showRecipeAsProduct.tointeger())
      if (item)
        itemsViewData.append(item.getViewData(this.getItemMarkupParams().__update({
          count = -1
          craftTimerText = item.getAdditionalTextInAmmount(false)
      })))
    }
    else
      foreach (component in this.visibleComponents) {
        let item = ::ItemsManager.findItemById(component.itemdefId)
        if (item)
          itemsViewData.append(item.getViewData(this.getItemMarkupParams().__update({
            count = this.getComponentQuantityText(component, { needColoredText = false })
            overlayAmountTextColor = this.getComponentQuantityColor(component)
            craftTimerText = item.getAdditionalTextInAmmount(false)
          })))
      }
    return handyman.renderCached("%gui/items/item.tpl", { items = itemsViewData })
  }

  getVisibleMarkupComponents = @() this.showRecipeAsProduct != null ? 1 : this.visibleComponents.len()

  function getMarkIcon() {
    let curMark = this.getMark()
    if (curMark == MARK_RECIPE.NONE)
      return ""

    let imgPrefix = "#ui/gameuiskin#"
    if (curMark == MARK_RECIPE.USED)
      return imgPrefix + (this.isFake ? "icon_primary_fail.svg" : "icon_primary_ok.svg")

    if (curMark == MARK_RECIPE.BY_USER)
      return imgPrefix + "icon_primary_attention.svg"

    return ""
  }

  function getMarkLocIdByPath(path) {
    let curMark = this.getMark()
    if (curMark == MARK_RECIPE.NONE)
      return ""

    if (curMark == MARK_RECIPE.USED)
      return loc(path + (this.isFake ? "fake" : "true"))

    if (curMark == MARK_RECIPE.BY_USER)
      return loc(path + "fakeByUser")

    return ""
  }

  getMarkText = @() this.getMarkLocIdByPath(this.getLocIdsList().markDescPrefix)
  getMarkTooltip = @() this.getMarkLocIdByPath(this.getLocIdsList().markTooltipPrefix)

  function getMarkDescMarkup() {
    let title = this.getMarkText()
    if (title == "")
      return ""

    let view = {
      list = [{
        icon  = this.getMarkIcon()
        title = title
        tooltip = this.getMarkTooltip()
      }]
    }
    return handyman.renderCached("%gui/items/trophyDesc.tpl", view)
  }

  function isRecipeLocked() {
    let curMark = this.getMark()
    return curMark == MARK_RECIPE.BY_USER || (curMark == MARK_RECIPE.USED && this.isFake)
  }

  getCantAssembleMarkedFakeLocId = @() this.getMarkLocIdByPath(this.getLocIdsList().markMsgBoxCantUsePrefix)
  function getOpenCost(componentItem) {
    local cost = Cost()
    foreach (component in this.components) {
      if (componentItem?.id == component.itemdefId)
        continue
      if (component.cost == null)
        return null
      cost += component.cost
    }

    return cost
  }

  function buyAllRequiredComponets(componentItem) {
    this.components.each(function(component) {
      if (componentItem.id == component.itemdefId)
        return
      let item = ::ItemsManager.findItemById(component.itemdefId)
      for (local i = 0; i < (component.reqQuantity - component.curQuantity); i++)
        item?._buy()
    })
  }

  static function getRequirementsMarkup(recipes, componentItem, params) {
    return this._getRequirements(recipes, componentItem, params, true)
  }

  static function getRequirementsText(recipes, componentItem, params) {
    return this._getRequirements(recipes, componentItem, params, false)
  }

  static function _getRequirements(recipes, componentItem, params, shouldReturnMarkup) {
    if (componentItem.showAllowableRecipesOnly())
      return ""

    let maxRecipes = (params?.maxRecipes ?? componentItem.getMaxRecipesToShow()) || recipes.len()
    let isFullRecipesList = recipes.len() <= maxRecipes

    let isMultiRecipes = recipes.len() > 1
    local isMultiExtraItems = false
    let hasFakeRecipesInList = this.hasFakeRecipes(recipes)

    local recipesToShow = recipes
    if (!hasFakeRecipesInList)
      recipesToShow.sort(@(a, b) a.sortReqQuantityComponents <=> b.sortReqQuantityComponents)
    if (!isFullRecipesList) {
      recipesToShow = recipes.filter(@(r) r.isUsable && !r.isRecipeLocked())
      if (recipesToShow.len() > maxRecipes)
        recipesToShow = recipesToShow.slice(0, maxRecipes)
      else if (recipesToShow.len() < maxRecipes)
        foreach (r in recipes)
          if (!r.isUsable && !r.isRecipeLocked()) {
            recipesToShow.append(r)
            if (recipesToShow.len() == maxRecipes)
              break
          }
    }

    let needShowHeader = params?.needShowHeader ?? true
    local headerFirst = ""
    local headerNext = ""
    if (needShowHeader) {
      foreach (recipe in recipesToShow) {
        let multipleExtraItems = recipe.visibleComponents.filter(
          @(c) c.itemdefId != recipe.generatorId && componentItem.id != c.itemdefId)
        isMultiExtraItems  = isMultiExtraItems || (multipleExtraItems.len() > 1)
      }

      let craftTimeText = this.getRecipesCraftTimeText(recipes)
      headerFirst = colorize("grayOptionColor",
        componentItem.getDescRecipeListHeader(recipesToShow.len(), recipes.len(),
                                            isMultiExtraItems, hasFakeRecipesInList,
                                            craftTimeText))
      headerNext = isMultiRecipes && isMultiExtraItems ?
        colorize("grayOptionColor", loc("hints/shortcut_separator")) : null
    }

    params.componentToHide <- componentItem
    params.showCurQuantities <- (params?.showCurQuantities ?? true) && componentItem.descReceipesListWithCurQuantities
    params.canOpenForGold <- componentItem.canOpenForGold()

    let res = []
    foreach (recipe in recipesToShow) {
      if (needShowHeader)
        params.header <- !res.len() ? headerFirst : headerNext

      if (shouldReturnMarkup)
        res.append(recipe.getTextMarkup(params))
      else
        res.append(recipe.getText(params))
    }

    return (shouldReturnMarkup ? "" : "\n").join(res, true)
  }

  static function getRecipesCraftTimeText(recipes) {
    let minSeconds = max(u.min(recipes, @(r) r?.craftTime ?? 0)?.craftTime ?? 0, 0)
    let maxSeconds = max(u.max(recipes, @(r) r?.craftTime ?? 0)?.craftTime ?? 0, 0)
    if (minSeconds <= 0 && maxSeconds <= 0)
      return ""

    local timeText = loc("icon/hourglass") + " " + time.secondsToString(minSeconds, true, true)
    if (minSeconds != maxSeconds)
      timeText += " " + loc("ui/ndash") + " " + time.secondsToString(maxSeconds, true, true)

    return loc(recipes[0].getLocIdsList().craftTime,
      { time = timeText })
  }

  static hasFakeRecipes = @(recipes) u.search(recipes, @(r) r?.isFake) != null

  static function saveMarkedRecipes(newMarkedRecipesUid) {
    if (!newMarkedRecipesUid.len())
      return

    local markRecipeBlk = ::load_local_account_settings(markRecipeSaveId)
    if (!markRecipeBlk)
      markRecipeBlk = DataBlock()
    foreach (i in newMarkedRecipesUid)
      markRecipeBlk[i] = MARK_RECIPE.USED

    ::save_local_account_settings(markRecipeSaveId, markRecipeBlk)
  }

  function getComponentQuantityText(component, params = null) {
    if (!(params?.showCurQuantities ?? true))
      return component.reqQuantity > 1 ?
        (::nbsp + format(loc("weapons/counter/right/short"), component.reqQuantity)) : ""

    let locId = params?.needShowItemName ?? true ? "ui/parentheses/space" : "ui/parentheses"
    let locText = loc(locId, { text = component.curQuantity + "/" + component.reqQuantity })
    if (params?.needColoredText ?? true)
      return colorize(this.getComponentQuantityColor(component, true), locText)

    return locText
  }

  getComponentQuantityColor = @(component, needCheckRecipeLocked = false)
    this.isRecipeLocked() && needCheckRecipeLocked ? "fadedTextColor"
      : component.has ? "goodTextColor"
      : "badTextColor"

  static function tryUse(recipes, componentItem, params = {}) {
    let recipe = recipes.findvalue(@(r) r.isUsable) ?? recipes.findvalue(@(r) r.isDisassemble)

    if (componentItem.hasReachedMaxAmount() && !(recipe?.isDisassemble ?? false)) {
      ::scene_msg_box("reached_max_amount", null,
      loc(componentItem.getLocIdsList().reachedMaxAmount),
        [["cancel"]], "cancel")
      return false
    }

    if (!recipe?.isUsable) {
      this.showUseErrorMsg(recipes, componentItem)
      return false
    }

    if (params?.shouldSkipMsgBox || recipe.shouldSkipMsgBox) {
      recipe.doExchange(componentItem, 1, params)
      return true
    }

    let msgData = componentItem.getConfirmMessageData(recipe)
    let msgboxParams = { cancel_fn = function() {} }

    if (msgData?.needRecipeMarkup)
      msgboxParams.__update({
        data_below_text = recipe.getExchangeMarkup(componentItem,
          { header = msgData?.headerRecipeMarkup ?? ""
            headerParams = recipeComponentHeaderParams
            widthByParentParent = true
          })
        baseHandler = ::get_cur_base_gui_handler()
      })
    if (recipe.isDisassemble && params?.bundleContent) {
      msgboxParams.__update({
        data_below_text = (msgboxParams?.data_below_text ?? "")
          + ::PrizesView.getPrizesListView(params.bundleContent,
              { header = loc("mainmenu/you_will_receive")
                headerParams = recipeComponentHeaderParams
                widthByParentParent = true
              }, false)
        baseHandler = ::get_cur_base_gui_handler()
      })
    }

    ::scene_msg_box("chest_exchange", null, msgData.text, [
      [ "yes", Callback(function() {
          recipe.updateComponents()
          if (recipe.isUsable)
            recipe.doExchange(componentItem, 1, params)
          else
            this.showUseErrorMsg(recipes, componentItem)
        }, this) ],
      [ "no" ]
    ], "yes", msgboxParams)
    return true
  }

  static function showUseErrorMsg(recipes, componentItem) {
    let locId = componentItem.getCantUseLocId()
    let text = colorize("badTextColor", loc(locId))
    let msgboxParams = {
      data_below_text = this.getRequirementsMarkup(recipes, componentItem, {
        widthByParentParent = true
        headerParams = { hasHeaderPadding = true }
      }),
      baseHandler = ::get_cur_base_gui_handler(), //FIX ME: used only for tooltip
      cancel_fn = function() {}
    }

    //Suggest to buy not enough item on marketplace
    local requiredItem = null
    if (isMarketplaceEnabled() && recipes.len() == 1)
      foreach (c in recipes[0].components)
        if (c.itemdefId != componentItem.id && c.curQuantity < c.reqQuantity) {
          let item = ::ItemsManager.findItemById(c.itemdefId)
          if (!item || !item.hasLink())
            continue
          requiredItem = item
          break
        }

    let buttons = [ ["cancel"] ]
    local defBtn = "cancel"
    if (requiredItem) {
      buttons.insert(0, [ "find_on_marketplace", Callback(@() requiredItem.openLink(), this) ])
      defBtn = "find_on_marketplace"
    }

    ::scene_msg_box("cant_open_chest", null, text, buttons, defBtn, msgboxParams)
  }


  //////////////////////////////////// Internal functions ////////////////////////////////////

  function getMaterialsListForExchange(usedUidsList) {
    let res = []
    this.components.each(function(component) {
      if (this.reqItems.findvalue(@(c) c.itemdefid == component.itemdefId) != null)
        return
      local leftCount = component.reqQuantity
      let itemsList = ::ItemsManager.getInventoryList(itemType.ALL, @(item) item.id == component.itemdefId)
      foreach (item in itemsList) {
        foreach (i in item.uids) {
          let leftByUid = usedUidsList?[i] ?? item.amountByUids[i]
          if (leftByUid <= 0)
            continue

          let count = min(leftCount, leftByUid)
          res.append([ i, count ])
          usedUidsList[i] <- leftByUid - count
          leftCount -= count
          if (!leftCount)
            break
        }
        if (!leftCount)
          break
      }
    }.bindenv(this))
    return res
  }

  function doExchange(componentItem, amount = 1, params = {}) {
    let resultItems = []
    let usedUidsList = {}
    let recipe = this //to not remove recipe until operation complete
    params = params ?? {}
    if (componentItem.canRecraftFromRewardWnd())
      params.reUseRecipeUid <- this.uid

    local leftAmount = amount
    let errorCb = (componentItem?.shouldAutoConsume ?? true)
      ? null
      : @(errorId) showExchangeInventoryErrorMsg(errorId, componentItem)
    let exchangeAction = (@(cb) inventoryClient.exchange(
      this.getMaterialsListForExchange(usedUidsList),
      this.generatorId,
      function(items) {
        resultItems.extend(items)
        cb()
      },
      errorCb,
      --leftAmount <= 0,
      this.requirement
    )).bindenv(recipe)

    let exchangeActions = array(amount, exchangeAction)
    exchangeActions.append(@(_cb) recipe.onExchangeComplete(componentItem, resultItems, params))

    let effectOnStartCraft = this.getEffectOnStartCraft()
    if (effectOnStartCraft?.showImage != null)
      startCraftWnd(effectOnStartCraft)
    if (effectOnStartCraft?.playSound != null)
      ::get_cur_gui_scene()?.playSound(getRandomEffect(effectOnStartCraft.playSound))

    asyncActions.callAsyncActionsList(exchangeActions)
  }

  function onExchangeComplete(componentItem, resultItems, params = null) {
    ::ItemsManager.markInventoryUpdate()
    if (params?.cb)
      params.cb()

    let resultItemsShowOpening = resultItems.filter(::trophyReward.isShowItemInTrophyReward)
    let parentGen = componentItem.getParentGen()
    let isHasFakeRecipes = parentGen && this.hasFakeRecipes(parentGen.getRecipes())
    let parentRecipe = parentGen?.getRecipeByUid?(componentItem.craftedFrom)
    if (isHasFakeRecipes && (parentRecipe?.markRecipe?() ?? false) && !parentRecipe?.isFake)
      parentGen.markAllRecipes()

    let effectOnOpenChest = componentItem.getEffectOnOpenChest()

    if (resultItemsShowOpening.len() > 0) {
      let userstatItemRewardData = getUserstatItemRewardData(componentItem.id)
      let isUserstatRewards = userstatItemRewardData != null
      let rewardTitle = isUserstatRewards ? userstatRewardTitleLocId
        : parentRecipe ? parentRecipe.getRewardTitleLocId(isHasFakeRecipes)
        : ""
      let rewardListLocId = isUserstatRewards ? userstatItemsListLocId
        : params?.rewardListLocId ? params.rewardListLocId
        : parentRecipe ? componentItem.getItemsListLocId()
        : ""

      let expectedPrizes = resultItemsShowOpening.map(function(extItem) {
        let itemdefId = extItem?.itemdef.itemdefid
        let item = ::ItemsManager.findItemById(itemdefId)
        return {
          id = componentItem.id
          itemId = ::to_integer_safe(extItem?.itemid ?? -1)
          item = itemdefId
          count = extItem?.quantity ?? 0
          needCollectRewards = item?.shouldAutoConsume ?? false
          isInternalTrophy = item?.metaBlk.trophy != null
        }
      })

      let rewardWndConfig = {
        rewardTitle = loc(rewardTitle),
        rewardListLocId = rewardListLocId
        isDisassemble = this.isDisassemble
        isHidePrizeActionBtn = params?.isHidePrizeActionBtn ?? false
        singleAnimationGuiSound = getRandomEffect(effectOnOpenChest?.playSound)
        rewardImage = effectOnOpenChest?.showImage
        rewardImageRatio = effectOnOpenChest?.imageRatio
        reUseRecipeUid = params?.reUseRecipeUid
      }
      if (componentItem?.itemDef.tags.showTrophyWndWhenReciveAllRewardsData ?? false)
        showExternalTrophyRewardWnd({
          trophyItemDefId = componentItem.id
          expectedPrizes
          rewardWndConfig
        })
      else
        ::gui_start_open_trophy(rewardWndConfig.__update({ [componentItem.id] = expectedPrizes }))
    }
    else if (effectOnOpenChest?.playSound != null) {
      let isDelayedExchange = resultItems.findindex(@(v) v?.itemdef.type == "delayedexchange") != null
      if (!isDelayedExchange)
        ::get_cur_gui_scene()?.playSound(getRandomEffect(effectOnOpenChest.playSound))
    }

    autoConsumeItems()
  }

  getSaveId = @() markRecipeSaveId + this.uid

  function markRecipe(isUserMark = false, needSave = true) {
    let curMark = this.getMark()
    let marker = !isUserMark ? MARK_RECIPE.USED
      : (isUserMark && curMark == MARK_RECIPE.NONE) ? MARK_RECIPE.BY_USER
      : MARK_RECIPE.NONE

    if (curMark == marker)
      return false

    this.mark = marker
    if (needSave)
      ::save_local_account_settings(this.getSaveId(), curMark)

    return true
  }

  function loadStateRecipe() {
    if (::g_login.isProfileReceived())
      this.mark = ::load_local_account_settings(this.getSaveId(), MARK_RECIPE.NONE)
  }

  function getMark() {
    if (this.mark != null)
      return this.mark
    this.loadStateRecipe()
    return this.mark ?? MARK_RECIPE.NONE
  }

  getRewardTitleLocId = @(hasFakeRecipe = true) hasFakeRecipe
    ? this.getMarkLocIdByPath(this.getLocIdsList().craftFinishedTitlePrefix)
    : this.getLocIdsList().rewardTitle

  getRecipeStr = @() ",".join(
    this.initedComponents.map(@(component) component.itemdefid.tostring()
      + (component.quantity > 1 ? ("x" + component.quantity) : "")),
    true)

  getLocIdsList = function() {
    if (this.locIdsList)
      return this.locIdsList

    this.locIdsList = defaultLocIdsList.__merge({
      craftTime   = this.isDisassemble
        ? "msgBox/disassembleItem/time"
        : "msgBox/assembleItem/time"
      rewardTitle = this.isDisassemble
        ? "mainmenu/itemDisassembled/title"
        : "mainmenu/itemAssembled/title"
      headerRecipeMarkup = (this.isMultipleItems && (this.isDisassemble || this.hasChestInComponents))
        ? "msgBox/extra_items_will_be_spent"
        : this.hasChestInComponents ? ""
        : "msgBox/items_will_be_spent"
    })

    if (this.localizationPresetName)
      this.locIdsList.__update(getCustomLocalizationPresets(this.localizationPresetName))

    return this.locIdsList
  }

  getHeaderRecipeMarkupText = @() loc(this.getLocIdsList().headerRecipeMarkup)

  getConfirmMessageLocId = @(itemLocIdsList) this.getLocIdsList().msgBoxConfirmWhithItemName ??
    (this.isDisassemble
      ? itemLocIdsList.msgBoxConfirmWhithItemNameDisassemble
      : itemLocIdsList.msgBoxConfirmWhithItemName)
  getActionButtonLocId = @() this.getLocIdsList().actionButton
  getEffectOnStartCraft = @() getEffectOnStartCraftPresetById(this.effectOnStartCraftPresetName)
}

u.registerClass("Recipe", ExchangeRecipes, @(r1, r2) r1.idx == r2.idx)

return ExchangeRecipes
