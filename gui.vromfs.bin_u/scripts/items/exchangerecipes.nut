from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import MARK_RECIPE, itemType

let { Cost } = require("%scripts/money.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { format } = require("string")
let DataBlock  = require("DataBlock")
let DataBlockAdapter = require("%scripts/dataBlockAdapter.nut")
let inventoryClient = require("%scripts/inventory/inventoryClient.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let time = require("%scripts/time.nut")
let { getCustomLocalizationPresets, getRandomEffect,
  getEffectOnStartCraftPresetById } = require("%scripts/items/workshop/workshop.nut")
let startCraftWnd = require("%scripts/items/workshop/startCraftWnd.nut")
let { getUserstatItemRewardData, userstatItemsListLocId
} = require("%scripts/userstat/userstatItemsRewards.nut")
let { autoConsumeItems } = require("%scripts/items/autoConsumeItems.nut")
let { isMarketplaceEnabled } = require("%scripts/items/itemsMarketplace.nut")
let { showExternalTrophyRewardWnd } = require("%scripts/items/showExternalTrophyRewardWnd.nut")
let { get_cur_base_gui_handler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let chooseAmountWnd = require("%scripts/wndLib/chooseAmountWnd.nut")
let { floor } = require("math")
let { hasBuyAndOpenChestWndStyle } = require("%scripts/items/buyAndOpenChestWndStyles.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { isProfileReceived } = require("%scripts/login/loginStates.nut")

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

function showExchangeInventoryErrorMsg(errorId, componentItem) {
  let locIdPrefix = componentItem.getLocIdsList()?.inventoryErrorPrefix
  showInfoMsgBox(loc($"{locIdPrefix}{errorId}", { itemName = componentItem.getName() }),
    "exchange_inventory_error")
}

let hasFakeRecipesInList = @(recipes) u.search(recipes, @(r) r?.isFake) != null

function getRecipesCraftTimeText(recipes) {
  let minSeconds = max(u.min(recipes, @(r) r?.craftTime ?? 0)?.craftTime ?? 0, 0)
  let maxSeconds = max(u.max(recipes, @(r) r?.craftTime ?? 0)?.craftTime ?? 0, 0)
  if (minSeconds <= 0 && maxSeconds <= 0)
    return ""

  let timeText = [loc("icon/hourglass"), time.secondsToString(minSeconds, true, true)]
  if (minSeconds != maxSeconds)
    timeText.append(loc("ui/ndash"), time.secondsToString(maxSeconds, true, true))

  return loc(recipes[0].getLocIdsList().craftTime, { time = " ".join(timeText) })
}

function getSortedRecipesToShow(recipes, maxRecipes, hasFakeRecipes) {
  let isFullRecipesList = recipes.len() <= maxRecipes
  local recipesToShow = recipes
  if (!hasFakeRecipes)
    recipesToShow.sort(@(a, b) a.sortReqQuantityComponents <=> b.sortReqQuantityComponents)
  if (isFullRecipesList)
    return recipesToShow

  recipesToShow = recipes.filter(@(r) r.isUsable && !r.isRecipeLocked())
  if (recipesToShow.len() == maxRecipes)
    return recipesToShow

  if (recipesToShow.len() > maxRecipes)
    return recipesToShow.slice(0, maxRecipes)

  foreach (r in recipes)
    if (!r.isUsable && !r.isRecipeLocked()) {
      recipesToShow.append(r)
      if (recipesToShow.len() == maxRecipes)
        break
    }
  return recipesToShow
}


function getRequirements(recipes, componentItem, params, shouldReturnMarkup) {
  if (componentItem.showAllowableRecipesOnly())
    return ""

  let maxRecipes = (params?.maxRecipes ?? componentItem.getMaxRecipesToShow()) || recipes.len()
  let hasFakeRecipes = hasFakeRecipesInList(recipes)
  let recipesToShow = getSortedRecipesToShow(recipes, maxRecipes, hasFakeRecipes)

  let isMultiRecipes = recipes.len() > 1
  local isMultiExtraItems = false
  let needShowHeader = params?.needShowHeader ?? true
  local headerFirst = ""
  local headerNext = ""
  if (needShowHeader) {
    foreach (recipe in recipesToShow) {
      let multipleExtraItems = recipe.visibleComponents.filter(
        @(c) c.itemdefId != recipe.generatorId && componentItem.id != c.itemdefId)
      isMultiExtraItems  = isMultiExtraItems || (multipleExtraItems.len() > 1)
    }

    let craftTimeText = getRecipesCraftTimeText(recipes)
    headerFirst = colorize("grayOptionColor",
      componentItem.getDescRecipeListHeader(recipesToShow.len(), recipes.len(),
                                          isMultiExtraItems, hasFakeRecipes,
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

let getRequirementsMarkup = @(recipes, componentItem, params)
  getRequirements(recipes, componentItem, params, true)

let getRequirementsText = @(recipes, componentItem, params)
  getRequirements(recipes, componentItem, params, false)

function getRecipesComponents(recipes, componentItem, params) {
  if (componentItem.showAllowableRecipesOnly())
    return []

  let maxRecipes = (params?.maxRecipes ?? componentItem.getMaxRecipesToShow()) || recipes.len()
  let hasFakeRecipes = hasFakeRecipesInList(recipes)
  let recipesToShow = getSortedRecipesToShow(recipes, maxRecipes, hasFakeRecipes)
  let res = []
  foreach (recipe in recipesToShow)
    res.append(recipe.getItemsListForPrizesView(params))
  return res
}

function saveMarkedRecipes(newMarkedRecipesUid) {
  if (!newMarkedRecipesUid.len())
    return

  local markRecipeBlk = loadLocalAccountSettings(markRecipeSaveId)
  if (!markRecipeBlk)
    markRecipeBlk = DataBlock()
  foreach (i in newMarkedRecipesUid)
    markRecipeBlk[i] = MARK_RECIPE.USED

  saveLocalAccountSettings(markRecipeSaveId, markRecipeBlk)
}

function showUseErrorMsg(recipes, componentItem) {
  let locId = componentItem.getCantUseLocId()
  let text = colorize("badTextColor", loc(locId))
  let msgboxParams = {
    data_below_text = getRequirementsMarkup(recipes, componentItem, {
      widthByParentParent = true
      headerParams = { hasHeaderPadding = true }
    }),
    baseHandler = get_cur_base_gui_handler(), //FIX ME: used only for tooltip
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
    buttons.insert(0, [ "find_on_marketplace", @() requiredItem.openLink() ])
    defBtn = "find_on_marketplace"
  }

  scene_msg_box("cant_open_chest", null, text, buttons, defBtn, msgboxParams)
}

function showUseErrorMsgIfNeed(recipe, componentItem, recipes = null){
  if (componentItem.hasReachedMaxAmount() && !(recipe?.isDisassemble ?? false)) {
    scene_msg_box("reached_max_amount", null,
    loc(componentItem.getLocIdsList().reachedMaxAmount),
      [["cancel"]], "cancel")
    return true
  }

  if (!recipe?.isUsable) {
    showUseErrorMsg(recipes ?? [recipe], componentItem)
    return true
  }

  return false
}

function showConfirmExchangeMsg(recipe, componentItem, params, quantity = 1, recipes = null) {
  let msgData = componentItem.getConfirmMessageData(recipe, quantity)
  let msgboxParams = { cancel_fn = function() {} }

  if (msgData?.needRecipeMarkup)
    msgboxParams.__update({
      data_below_text = recipe.getExchangeMarkup(componentItem,
        { header = msgData?.headerRecipeMarkup ?? ""
          headerParams = recipeComponentHeaderParams
          widthByParentParent = true
          quantity
        })
      baseHandler = get_cur_base_gui_handler()
    })
  if (recipe.isDisassemble && params?.bundleContent) {
    msgboxParams.__update({
      data_below_text = "".concat(msgboxParams?.data_below_text ?? "",
        ::PrizesView.getPrizesListView(params.bundleContent,
          { header = loc("mainmenu/you_will_receive")
            headerParams = recipeComponentHeaderParams
            widthByParentParent = true
          }, false)
      )
      baseHandler = get_cur_base_gui_handler()
    })
  }

  scene_msg_box("chest_exchange", null, msgData.text, [
    [ "yes", function() {
        recipe.updateComponents()
        if (recipe.isUsable && recipe.quantityAvailableExchanges >= quantity)
          recipe.doExchange(componentItem, quantity, params)
        else
          showUseErrorMsg(recipes ?? [recipe], componentItem)
      } ],
    [ "no" ]
  ], "yes", msgboxParams)
}

function tryUseRecipes(recipes, componentItem, params = {}) {
  let {reciepeExchangeAmount = 1} = params

  let recipe = recipes.findvalue(@(r) r.isUsable) ?? recipes.findvalue(@(r) r.isDisassemble)
  if (showUseErrorMsgIfNeed(recipe, componentItem, recipes) || recipe == null)
    return false

  if (hasBuyAndOpenChestWndStyle(componentItem) && !params?.isFromChestWnd) {
    broadcastEvent("openChestWndOrTrophy", {chest = componentItem})
    return true
  }

  if (params?.shouldSkipMsgBox || recipe.shouldSkipMsgBox) {
    recipe.doExchange(componentItem, reciepeExchangeAmount, params)
    return true
  }

  showConfirmExchangeMsg(recipe, componentItem, params, reciepeExchangeAmount, recipes)
  return true
}

function tryUseRecipeSeveralTime(recipe, componentItem, maxAmount, params = {}) {
  if (showUseErrorMsgIfNeed(recipe, componentItem))
    return

  maxAmount = min(maxAmount, recipe.quantityAvailableExchanges)
  if (params?.shouldSkipMsgBox || recipe.shouldSkipMsgBox) {
    recipe.doExchange(componentItem, maxAmount, params)
    return true
  }

  if (maxAmount == 1) {
    showConfirmExchangeMsg(recipe, componentItem, params)
    return
  }

  chooseAmountWnd.open({
    parentObj = params?.obj
    align = params?.align ?? "bottom"
    minValue = 1
    maxValue = maxAmount
    curValue = maxAmount
    valueStep = 1

    headerText = $"{loc(componentItem.getLocIdsList().consumeSeveral)} {componentItem.getName()}"
    buttonText = loc("item/consume")
    getValueText = @(value) value.tostring()

    onAcceptCb = @(value) showConfirmExchangeMsg(recipe, componentItem, params, value)
    onCancelCb = null
  })
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
  needSaveMarkRecipe = true

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
  quantityAvailableExchanges = 0

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
    this.needSaveMarkRecipe = params?.needSaveMarkRecipe ?? true

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
    local minQuantityAvailableExchanges = null
    foreach (component in componentsArray) {
      let curQuantity = this.getCompQuantityById(items, component.itemdefid)
      let reqQuantity = component.quantity
      let quantityExchanges = reqQuantity == 0 ? 0 : floor(curQuantity / reqQuantity)
      minQuantityAvailableExchanges = min(minQuantityAvailableExchanges ?? quantityExchanges, quantityExchanges)
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
    this.quantityAvailableExchanges = minQuantityAvailableExchanges ?? 0
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
        commentText = this.getComponentQuantityText(component, params)
      }))
    }
    return ::PrizesView.getPrizesListView(list, params, false)
  }

  function getForcedVisibleComps(idsTbl) {
    if (!idsTbl || idsTbl.len() == 0)
      return []
    let inventoryItems = ::ItemsManager.getInventoryList(itemType.ALL, @(item) item.id in idsTbl)

    return idsTbl.keys().map(function(id) {
      let curQuantity = this.getCompQuantityById(inventoryItems, id)
      return {
        itemdefId = id
        curQuantity = curQuantity
        reqQuantity = 1
        has = curQuantity > 0
      }
    }.bindenv(this))
  }

  function getItemsListForPrizesView(params = null) {
    if (params?.canOpenForGold ?? false)
      return [{ gold = this.getOpenCost(params?.componentToHide)?.gold ?? 0 }]
    let res = []
    let visibleResources = params?.visibleResources ?? this.allowableComponents
    let forcedVisibleComps = this.getForcedVisibleComps(params?.forcedVisibleResources)
    let allComps = (clone this.components).extend(forcedVisibleComps)
    foreach (component in allComps)
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
      { time = "".concat(loc("icon/hourglass"), " ", time.secondsToString(this.craftTime, true, true)) })
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

    if (curMark == MARK_RECIPE.USED)
      return this.isFake ? "#ui/gameuiskin#icon_primary_fail.svg"
        : "#ui/gameuiskin#icon_primary_ok.svg"

    if (curMark == MARK_RECIPE.BY_USER)
      return "#ui/gameuiskin#icon_primary_attention.svg"

    return ""
  }

  function getMarkLocIdByPath(path) {
    let curMark = this.getMark()
    if (curMark == MARK_RECIPE.NONE)
      return ""

    if (curMark == MARK_RECIPE.USED)
      return loc($"{path}{this.isFake ? "fake" : "true"}")

    if (curMark == MARK_RECIPE.BY_USER)
      return loc($"{path}fakeByUser")

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

  function getComponentQuantityText(component, params = null) {
    if (!(params?.showCurQuantities ?? true))
      return component.reqQuantity > 1 ?
        ("".concat(nbsp, format(loc("weapons/counter/right/short"), component.reqQuantity))) : ""

    let { needShowItemName = true, quantity = 1, needColoredText = true } = params
    let locId = needShowItemName ? "ui/parentheses/space" : "ui/parentheses"
    let locText = loc(locId, { text = $"{component.curQuantity}/{component.reqQuantity * quantity}" })
    if (needColoredText)
      return colorize(this.getComponentQuantityColor(component, true), locText)

    return locText
  }

  getComponentQuantityColor = @(component, needCheckRecipeLocked = false)
    this.isRecipeLocked() && needCheckRecipeLocked ? "fadedTextColor"
      : component.has ? "goodTextColor"
      : "badTextColor"

  //////////////////////////////////// Internal functions ////////////////////////////////////

  function getMaterialsListForExchange(recipesQuantity) {
    let res = []
    let usedUidsList = {}
    this.components.each(function(component) {
      if (this.reqItems.findvalue(@(c) c.itemdefid == component.itemdefId) != null)
        return
      local leftCount = component.reqQuantity * recipesQuantity
      let itemsList = ::ItemsManager.getInventoryList(itemType.ALL, @(item) item.id == component.itemdefId)
      foreach (item in itemsList) {
        foreach (i in item.uids) {
          let leftByUid = usedUidsList?[i] ?? item.amountByUids[i]
          if (leftByUid <= 0)
            continue

          let count = min(leftCount, leftByUid).tointeger()
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
    let recipe = this //to not remove recipe until operation complete
    params = params ?? {}
    if (componentItem.canRecraftFromRewardWnd()) {
      params.__update({
        reUseRecipeUid = this.uid
        usedRecipeAmount = amount
      })
    }

    let errorCb = (componentItem?.shouldAutoConsume ?? true) ? null
      : @(errorId) showExchangeInventoryErrorMsg(errorId, componentItem)

    let effectOnStartCraft = this.getEffectOnStartCraft()
    if (effectOnStartCraft?.showImage != null)
      startCraftWnd(effectOnStartCraft)
    if (effectOnStartCraft?.playSound != null)
      get_cur_gui_scene()?.playSound(getRandomEffect(effectOnStartCraft.playSound))

    inventoryClient.exchange(
      this.getMaterialsListForExchange(amount),
      this.generatorId,
      amount.tointeger(),
      @(resultItems) recipe.onExchangeComplete(componentItem, resultItems, params)
      errorCb,
      this.requirement
    )
  }

  function onExchangeComplete(componentItem, resultItems, params = null) {
    ::ItemsManager.markInventoryUpdate()
    let { cb = null, showCollectRewardsWaitBox = true } = params
    if (cb != null)
      cb()

    let resultItemsShowOpening = resultItems.filter(::trophyReward.isShowItemInTrophyReward)
    let parentGen = componentItem.getParentGen() ?? componentItem.getGenerator()
    let isHasFakeRecipes = parentGen && hasFakeRecipesInList(parentGen.getRecipes())
    let parentRecipe = parentGen?.getRecipeByUid?(componentItem.craftedFrom)
    if (isHasFakeRecipes && (parentRecipe?.markRecipe?() ?? false) && !parentRecipe?.isFake)
      parentGen.markAllRecipes()
    let effectOnOpenChest = componentItem.getEffectOnOpenChest()

    if (resultItemsShowOpening.len() > 0) {
      let userstatItemRewardData = getUserstatItemRewardData(componentItem.id)
      let isUserstatRewards = userstatItemRewardData != null
      let rewardTitle = isUserstatRewards ? userstatItemRewardData.rewardTitleLocId
        : parentRecipe ? parentRecipe.isDisassemble ?
            componentItem.getDissasembledCaption() :
            parentRecipe.getRewardTitleLocId(isHasFakeRecipes)
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
          itemId = to_integer_safe(extItem?.itemid ?? -1)
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
        usedRecipeAmount = params?.usedRecipeAmount ?? 1
      }
      if (componentItem?.itemDef.tags.showTrophyWndWhenReciveAllRewardsData ?? false)
        showExternalTrophyRewardWnd({
          trophyItemDefId = componentItem.id
          showCollectRewardsWaitBox
          expectedPrizes
          rewardWndConfig
        })
      else
        broadcastEvent("openChestWndOrTrophy", {chest = componentItem, expectedPrizes, rewardWndConfig})
    }
    else if (effectOnOpenChest?.playSound != null) {
      let isDelayedExchange = resultItems.findindex(@(v) v?.itemdef.type == "delayedexchange") != null
      if (!isDelayedExchange)
        get_cur_gui_scene()?.playSound(getRandomEffect(effectOnOpenChest.playSound))
    }

    autoConsumeItems()
  }

  getSaveId = @() $"{markRecipeSaveId}{this.uid}"

  function markRecipe(isUserMark = false, needSave = true) {
    let curMark = this.getMark()
    let marker = !isUserMark ? MARK_RECIPE.USED
      : (isUserMark && curMark == MARK_RECIPE.NONE) ? MARK_RECIPE.BY_USER
      : MARK_RECIPE.NONE

    if (curMark == marker)
      return false

    this.mark = marker
    if (needSave && this.needSaveMarkRecipe)
      saveLocalAccountSettings(this.getSaveId(), marker)

    return true
  }

  function loadStateRecipe() {
    this.mark = !this.needSaveMarkRecipe ? MARK_RECIPE.NONE
      : isProfileReceived.get() ? loadLocalAccountSettings(this.getSaveId(), MARK_RECIPE.NONE)
      : null
  }

  function getMark() {
    if (this.mark != null)
      return this.mark
    this.loadStateRecipe()
    return this.mark ?? MARK_RECIPE.NONE
  }

  getCompQuantityById = @(comps, id) comps
    .filter(@(i) i.id == id).reduce( @(res, item) res + item.amount, 0)

  getRewardTitleLocId = @(hasFakeRecipe = true) hasFakeRecipe
    ? this.getMarkLocIdByPath(this.getLocIdsList().craftFinishedTitlePrefix)
    : this.getLocIdsList().rewardTitle

  getRecipeStr = @() ",".join(
    this.initedComponents.map(@(component) "".concat(component.itemdefid,
      component.quantity > 1 ? ($"x{component.quantity}") : "")),
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

return {
  ExchangeRecipes
  hasFakeRecipesInList
  getRequirementsMarkup
  getRequirementsText
  saveMarkedRecipes
  tryUseRecipes
  tryUseRecipeSeveralTime
  getRecipesComponents
}
