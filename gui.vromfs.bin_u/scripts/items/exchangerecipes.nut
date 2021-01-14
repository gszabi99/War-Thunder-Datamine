local inventoryClient = require("scripts/inventory/inventoryClient.nut")
local u = require("sqStdLibs/helpers/u.nut")
local asyncActions = require("sqStdLibs/helpers/asyncActions.nut")
local time = require("scripts/time.nut")
local { getCustomLocalizationPresets, getEffectOnStartCraftPresetById } = require("scripts/items/workshop/workshop.nut")
local startCraftWnd = require("scripts/items/workshop/startCraftWnd.nut")
local { getUserstatItemRewardData, removeUserstatItemRewardToShow,
  userstatItemsListLocId, userstatRewardTitleLocId
} = require("scripts/userstat/userstatItemsRewards.nut")
local { autoConsumeItems } = require("scripts/items/autoConsumeItems.nut")

global enum MARK_RECIPE {
  NONE
  BY_USER
  USED
}

local markRecipeSaveId = "markRecipe/"

local defaultLocIdsList = {
  craftTime                 = "msgBox/assembleItem/time"
  rewardTitle               = "mainmenu/itemAssembled/title"
  headerRecipeMarkup        = "msgBox/items_will_be_spent"
  craftFinishedTitlePrefix  = "mainmenu/craftFinished/title/"
  markTooltipPrefix         = "item/recipes/markTooltip/"
  markDescPrefix            = "item/recipes/markDesc/"
  markMsgBoxCantUsePrefix   = "msgBox/craftProcess/cant/"
  msgBoxConfirmWhithItemName= null
  actionButton              = null
}

local function showExchangeInventoryErrorMsg(errorId, componentItem) {
  local locIdPrefix = componentItem.getLocIdsList()?.inventoryErrorPrefix
  ::showInfoMsgBox(::loc($"{locIdPrefix}{errorId}", { itemName = componentItem.getName() }),
    "exchange_inventory_error")
}

local lastRecipeIdx = 0
local ExchangeRecipes = class {
  idx = 0
  uid = ""
  components = null
  generatorId = null
  requirement = null
  mark = MARK_RECIPE.NONE

  isUsable = false
  isMultipleItems = false
  isMultipleExtraItems = false
  isFake = false
  hasChestInComponents = false

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

  constructor(params)
  {
    idx = lastRecipeIdx++
    generatorId = params.generatorId
    isFake = params?.isFake ?? false
    craftTime = params?.craftTime ?? 0
    isDisassemble = params?.isDisassemble ?? false
    localizationPresetName = params?.localizationPresetName
    effectOnStartCraftPresetName = params?.effectOnStartCraftPresetName ?? ""
    allowableComponents = params?.allowableComponents

    local parsedRecipe = params.parsedRecipe
    initedComponents = parsedRecipe.components
    reqItems = parsedRecipe.reqItems
    sortReqQuantityComponents = initedComponents.filter(isVisibleComponent.bindenv(this))
        .map(@(component) component.quantity).reduce(@(res, value) res + value, 0)
      + reqItems.filter(isVisibleComponent.bindenv(this))
        .map(@(component) component.quantity).reduce(@(res, value) res + value, 0)
    requirement = parsedRecipe.requirement

    local recipeStr = (requirement != null || reqItems.len() > 0) ? getRecipeStr() : parsedRecipe.recipeStr
    uid = $"{generatorId};{recipeStr}"

    updateComponents()
    loadStateRecipe()
  }

  function updateComponents()
  {
    local componentsArray = (clone initedComponents).extend(reqItems)
    local componentsCount = componentsArray.len()
    isUsable = componentsCount > 0
    isMultipleItems = componentsCount > 1

    local extraItemsCount = 0
    components = []
    visibleComponents = []
    local componentItemdefArray = componentsArray.map(@(c) c.itemdefid)
    local items = ::ItemsManager.getInventoryList(itemType.ALL,
      @(item) ::isInArray(item.id, componentItemdefArray))
    hasChestInComponents = ::u.search(items, @(i) i.iType == itemType.CHEST) != null
    foreach (component in componentsArray)
    {
      local curQuantity = items.filter(@(i) i.id == component.itemdefid).reduce(
        @(res, item) res + item.amount, 0)
      local reqQuantity = component.quantity
      local isHave = curQuantity >= reqQuantity
      isUsable = isUsable && isHave
      local shopItem = ::ItemsManager.findItemById(component.itemdefid)
      local cost = null
      if (shopItem?.isCanBuy() ?? false) {
        cost = shopItem.getCost()
        cost = cost.setFromTbl({
          wp = cost.wp * reqQuantity
          gold = cost.gold * reqQuantity
        })
      }

      components.append({
        has = isHave
        itemdefId = component.itemdefid
        reqQuantity = reqQuantity
        curQuantity = curQuantity
        cost = cost
      })

      local isVisible = isVisibleComponent(component)
      if (isVisible)
        visibleComponents.append(components.top())

      if (reqQuantity > 1)
        isMultipleItems = true
      if (isVisible && component.itemdefid != generatorId)
        extraItemsCount++
    }

    isMultipleExtraItems = extraItemsCount - (isDisassemble ? 1 : 0) > 1
  }

  function isEnabled()
  {
    return requirement == null || ::has_feature(requirement)
  }

  function hasComponent(itemdefid)
  {
    foreach (c in components)
      if (c.itemdefId == itemdefid)
        return true
    return false
  }

  isVisibleComponent = @(component) allowableComponents == null || (component.itemdefid in allowableComponents)

  function getExchangeMarkup(componentItem, params)
  {
    local list = []
    foreach (component in visibleComponents)
    {
      if (component.itemdefId == componentItem.id)
        continue
      list.append(::DataBlockAdapter({
        item  = component.itemdefId
        commentText = getComponentQuantityText(component)
      }))
    }
    return ::PrizesView.getPrizesListView(list, params, false)
  }

  function getItemsListForPrizesView(params = null)
  {
    if (params?.canOpenForGold ?? false)
      return [{ gold = getOpenCost(params?.componentToHide)?.gold ?? 0 }]
    local res = []
    local visibleResources = params?.visibleResources ?? allowableComponents
    foreach (component in components)
      if (component.itemdefId != params?.componentToHide?.id
       && (visibleResources == null || visibleResources?[component.itemdefId]))
        res.append(::DataBlockAdapter({
          item  = component.itemdefId
          commentText = getComponentQuantityText(component, params)
        }))
    return res
  }

  function getTextMarkup(params = null)
  {
    if (!params)
      params = {}
    params = params.__merge({isLocked = isRecipeLocked()})

    local list = getItemsListForPrizesView(params)
    return ::PrizesView.getPrizesListView(list, params, false)
  }

  function getText(params = null)
  {
    local list = getItemsListForPrizesView(params)
    local headerFunc = params?.header && @(...) params.header
    return ::PrizesView.getPrizesListText(list, headerFunc, false)
  }

  function hasCraftTime()
  {
    return craftTime > 0
  }

  function getCraftTime()
  {
    return craftTime
  }

  function getCraftTimeText()
  {
    return ::loc(getLocIdsList().craftTime,
      {time = ::loc("icon/hourglass") + " " + time.secondsToString(craftTime, true, true)})
  }

  function getIconedMarkup()
  {
    local itemsViewData = []
    foreach (component in visibleComponents)
    {
      local item = ItemsManager.findItemById(component.itemdefId)
      if (item)
        itemsViewData.append(item.getViewData({
          count = getComponentQuantityText(component, { needColoredText = false })
          overlayAmountTextColor = getComponentQuantityColor(component)
          contentIcon = false
          hasTimer = false
          addItemName = false
          showPrice = false
          showAction = false
          shouldHideAdditionalAmmount = true
          craftTimerText = item.getAdditionalTextInAmmount(false)
        }))
    }
    return ::handyman.renderCached("gui/items/item", { items = itemsViewData })
  }

  function getMarkIcon()
  {
    if (mark == MARK_RECIPE.NONE)
      return ""

    local imgPrefix = "#ui/gameuiskin#"
    if (mark == MARK_RECIPE.USED)
      return imgPrefix + (isFake ? "icon_primary_fail.svg" : "icon_primary_ok")

    if (mark == MARK_RECIPE.BY_USER)
      return imgPrefix + "icon_primary_attention"

    return ""
  }

  function getMarkLocIdByPath(path)
  {
    if (mark == MARK_RECIPE.NONE)
      return ""

    if (mark == MARK_RECIPE.USED)
      return ::loc(path + (isFake ? "fake" : "true"))

    if (mark == MARK_RECIPE.BY_USER)
      return ::loc(path + "fakeByUser")

    return ""
  }

  getMarkText = @() getMarkLocIdByPath(getLocIdsList().markDescPrefix)
  getMarkTooltip = @() getMarkLocIdByPath(getLocIdsList().markTooltipPrefix)

  function getMarkDescMarkup()
  {
    local title = getMarkText()
    if (title == "")
      return ""

    local view = {
      list = [{
        icon  = getMarkIcon()
        title = title
        tooltip = getMarkTooltip()
      }]
    }
    return ::handyman.renderCached("gui/items/trophyDesc", view)
  }

  isRecipeLocked = @() mark == MARK_RECIPE.BY_USER || (mark == MARK_RECIPE.USED && isFake)
  getCantAssembleMarkedFakeLocId = @() getMarkLocIdByPath(getLocIdsList().markMsgBoxCantUsePrefix)
  function getOpenCost(componentItem) {
    local cost = ::Cost()
    foreach (component in components) {
      if (componentItem?.id == component.itemdefId)
        continue
      if (component.cost == null)
        return null
      cost += component.cost
    }

    return cost
  }

  function buyAllRequiredComponets(componentItem) {
    components.each(function(component) {
      if (componentItem.id == component.itemdefId)
        return
      local item = ::ItemsManager.findItemById(component.itemdefId)
      for (local i = 0; i < (component.reqQuantity - component.curQuantity); i++)
        item?._buy()
    })
  }

  static function getRequirementsMarkup(recipes, componentItem, params)
  {
    return _getRequirements(recipes, componentItem, params, true)
  }

  static function getRequirementsText(recipes, componentItem, params)
  {
    return _getRequirements(recipes, componentItem, params, false)
  }

  static function _getRequirements(recipes, componentItem, params, shouldReturnMarkup)
  {
    local showOnlyCraftTime = componentItem.showAllowableRecipesOnly()
    local craftTimeText = getRecipesCraftTimeText(recipes)
    if (showOnlyCraftTime) {
      if (shouldReturnMarkup)
        return ::PrizesView.getPrizesListView([], { header = craftTimeText })
      else
        return ::PrizesView.getPrizesListText([], @(...) craftTimeText)
    }

    local maxRecipes = (params?.maxRecipes ?? componentItem.getMaxRecipesToShow()) || recipes.len()
    local isFullRecipesList = recipes.len() <= maxRecipes

    local isMultiRecipes = recipes.len() > 1
    local isMultiExtraItems = false
    local hasFakeRecipesInList = hasFakeRecipes(recipes)

    local recipesToShow = recipes
    if (!hasFakeRecipesInList)
      recipesToShow.sort(@(a, b) a.sortReqQuantityComponents <=> b.sortReqQuantityComponents)
    if (!isFullRecipesList)
    {
      recipesToShow = u.filter(recipes, @(r) r.isUsable && !r.isRecipeLocked())
      if (recipesToShow.len() > maxRecipes)
        recipesToShow = recipesToShow.slice(0, maxRecipes)
      else if (recipesToShow.len() < maxRecipes)
        foreach(r in recipes)
          if (!r.isUsable && !r.isRecipeLocked())
          {
            recipesToShow.append(r)
            if (recipesToShow.len() == maxRecipes)
              break
          }
    }

    local needShowHeader = params?.needShowHeader ?? true
    local headerFirst = ""
    local headerNext = ""
    if (needShowHeader)
    {
      foreach (recipe in recipesToShow)
        isMultiExtraItems = isMultiExtraItems || recipe.isMultipleExtraItems

      headerFirst = ::colorize("grayOptionColor",
        componentItem.getDescRecipeListHeader(recipesToShow.len(), recipes.len(),
                                            isMultiExtraItems, hasFakeRecipesInList,
                                            craftTimeText))
      headerNext = isMultiRecipes && isMultiExtraItems ?
        ::colorize("grayOptionColor", ::loc("hints/shortcut_separator")) : null
    }

    params.componentToHide <- componentItem
    params.showCurQuantities <- componentItem.descReceipesListWithCurQuantities
    params.canOpenForGold <- componentItem.canOpenForGold()

    local res = []
    foreach (recipe in recipesToShow)
    {
      if (needShowHeader)
        params.header <- !res.len() ? headerFirst : headerNext

      if (shouldReturnMarkup)
        res.append(recipe.getTextMarkup(params))
      else
        res.append(recipe.getText(params))
    }

    return ::g_string.implode(res, shouldReturnMarkup ? "" : "\n")
  }

  static function getRecipesCraftTimeText(recipes)
  {
    local minSeconds = ::max(u.min(recipes, @(r) r?.craftTime ?? 0)?.craftTime ?? 0, 0)
    local maxSeconds = ::max(u.max(recipes, @(r) r?.craftTime ?? 0)?.craftTime ?? 0, 0)
    if (minSeconds <= 0 && maxSeconds <= 0)
      return ""

    local timeText = ::loc("icon/hourglass") + " " + time.secondsToString(minSeconds, true, true)
    if (minSeconds != maxSeconds)
      timeText += " " + ::loc("ui/ndash") + " " + time.secondsToString(maxSeconds, true, true)

    return ::loc(recipes[0].getLocIdsList().craftTime,
      {time = timeText})
  }

  static hasFakeRecipes = @(recipes) u.search(recipes, @(r) r?.isFake) != null

  static function saveMarkedRecipes(newMarkedRecipesUid)
  {
    if (!newMarkedRecipesUid.len())
      return

    local markRecipeBlk = ::load_local_account_settings(markRecipeSaveId)
    if (!markRecipeBlk)
      markRecipeBlk = ::DataBlock()
    foreach(_uid in newMarkedRecipesUid)
      markRecipeBlk[_uid] = MARK_RECIPE.USED

    ::save_local_account_settings(markRecipeSaveId, markRecipeBlk)
  }

  function getComponentQuantityText(component, params = null)
  {
    if (!(params?.showCurQuantities ?? true))
      return component.reqQuantity > 1 ?
        (::nbsp + ::format(::loc("weapons/counter/right/short"), component.reqQuantity)) : ""

    local locId = params?.needShowItemName ?? true ? "ui/parentheses/space" : "ui/parentheses"
    local locText = ::loc(locId, { text = component.curQuantity + "/" + component.reqQuantity })
    if (params?.needColoredText ?? true)
      return ::colorize(getComponentQuantityColor(component, true), locText)

    return locText
  }

  getComponentQuantityColor = @(component, needCheckRecipeLocked = false)
    isRecipeLocked() && needCheckRecipeLocked ? "fadedTextColor"
      : component.has ? "goodTextColor"
      : "badTextColor"

  static function tryUse(recipes, componentItem, params = {})
  {
    if (componentItem.hasReachedMaxAmount())
    {
      ::scene_msg_box("reached_max_amount", null,
        ::loc(componentItem.getLocIdsList().reachedMaxAmount),
        [["cancel"]], "cancel")
      return false
    }

    local recipe = null
    foreach (r in recipes)
      if (r.isUsable)
      {
        recipe = r
        break
      }

    if (recipe)
    {
      if (params?.shouldSkipMsgBox)
      {
        recipe.doExchange(componentItem, 1, params)
        return true
      }

      local msgData = componentItem.getConfirmMessageData(recipe)
      local msgboxParams = { cancel_fn = function() {} }

      if (msgData?.needRecipeMarkup)
        msgboxParams.__update({
          data_below_text = recipe.getExchangeMarkup(componentItem,
            { header = msgData?.headerRecipeMarkup ?? ""
              headerFont = "mediumFont"
              widthByParentParent = true
              hasHeaderPadding = true
              isCentered = true })
          baseHandler = ::get_cur_base_gui_handler()
        })
      if (recipe.isDisassemble && params?.bundleContent)
      {
        msgboxParams.__update({
          data_below_text = (msgboxParams?.data_below_text ?? "")
            + ::PrizesView.getPrizesListView(params.bundleContent,
                { header = ::loc("mainmenu/you_will_receive")
                  headerFont = "mediumFont"
                  widthByParentParent = true
                  hasHeaderPadding = true
                  isCentered = true }, false)
          baseHandler = ::get_cur_base_gui_handler()
        })
      }

      ::scene_msg_box("chest_exchange", null, msgData.text, [
        [ "yes", ::Callback(function()
          {
            recipe.updateComponents()
            if (recipe.isUsable)
              recipe.doExchange(componentItem, 1, params)
            else
              showUseErrorMsg(recipes, componentItem)
          }, this) ],
        [ "no" ]
      ], "yes", msgboxParams)
      return true
    }

    showUseErrorMsg(recipes, componentItem)
    return false
  }

  static function showUseErrorMsg(recipes, componentItem)
  {
    local locId = componentItem.getCantUseLocId()
    local text = ::colorize("badTextColor", ::loc(locId))
    local msgboxParams = {
      data_below_text = getRequirementsMarkup(recipes, componentItem, {
        widthByParentParent = true
        hasHeaderPadding = true
      }),
      baseHandler = ::get_cur_base_gui_handler(), //FIX ME: used only for tooltip
      cancel_fn = function() {}
    }

    //Suggest to buy not enough item on marketplace
    local requiredItem = null
    if (::ItemsManager.isMarketplaceEnabled() && recipes.len() == 1)
      foreach (c in recipes[0].components)
        if (c.itemdefId != componentItem.id && c.curQuantity < c.reqQuantity)
        {
          local item = ::ItemsManager.findItemById(c.itemdefId)
          if (!item || !item.hasLink())
            continue
          requiredItem = item
          break
        }

    local buttons = [ ["cancel"] ]
    local defBtn = "cancel"
    if (requiredItem)
    {
      buttons.insert(0, [ "find_on_marketplace", ::Callback(@() requiredItem.openLink(), this) ])
      defBtn = "find_on_marketplace"
    }

    ::scene_msg_box("cant_open_chest", null, text, buttons, defBtn, msgboxParams)
  }


  //////////////////////////////////// Internal functions ////////////////////////////////////

  function getMaterialsListForExchange(usedUidsList)
  {
    local res = []
    components.each(function(component) {
      if (reqItems.findvalue(@(c) c.itemdefid == component.itemdefId) != null)
        return
      local leftCount = component.reqQuantity
      local itemsList = ::ItemsManager.getInventoryList(itemType.ALL, @(item) item.id == component.itemdefId)
      foreach(item in itemsList)
      {
        foreach(_uid in item.uids)
        {
          local leftByUid = usedUidsList?[_uid] ?? item.amountByUids[_uid]
          if (leftByUid <= 0)
            continue

          local count = ::min(leftCount, leftByUid)
          res.append([ _uid, count ])
          usedUidsList[_uid] <- leftByUid - count
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

  function doExchange(componentItem, amount = 1, params = {})
  {
    local resultItems = []
    local usedUidsList = {}
    local recipe = this //to not remove recipe until operation complete
    if (componentItem.canRecraftFromRewardWnd())
      params.reUseRecipeUid <- uid

    local leftAmount = amount
    local errorCb = (componentItem?.shouldAutoConsume ?? true)
      ? null
      : @(errorId) showExchangeInventoryErrorMsg(errorId, componentItem)
    local exchangeAction = (@(cb) inventoryClient.exchange(
      getMaterialsListForExchange(usedUidsList),
      generatorId,
      function(items) {
        resultItems.extend(items)
        cb()
      },
      errorCb,
      --leftAmount <= 0,
      requirement
    )).bindenv(recipe)

    local exchangeActions = array(amount, exchangeAction)
    exchangeActions.append(@(cb) recipe.onExchangeComplete(componentItem, resultItems, params))

    local effectOnStartCraft = getEffectOnStartCraft()
    if (effectOnStartCraft?.showImage != null)
      startCraftWnd(effectOnStartCraft)
    if (effectOnStartCraft?.playSound != null)
      guiScene.playSound(effectOnStartCraft.playSound)

    asyncActions.callAsyncActionsList(exchangeActions)
  }

  function onExchangeComplete(componentItem, resultItems, params = null)
  {
    ::ItemsManager.markInventoryUpdate()
    if (params?.cb)
      params.cb()

    local resultItemsShowOpening  = ::u.filter(resultItems, ::trophyReward.isShowItemInTrophyReward)
    local parentGen = componentItem.getParentGen()
    local isHasFakeRecipes = parentGen && hasFakeRecipes(parentGen.getRecipes())
    local parentRecipe = parentGen?.getRecipeByUid?(componentItem.craftedFrom)
    if (isHasFakeRecipes && (parentRecipe?.markRecipe?() ?? false) && !parentRecipe?.isFake)
      parentGen.markAllRecipes()

    if (resultItemsShowOpening.len() > 0) {
      local userstatItemRewardData = getUserstatItemRewardData(componentItem.id)
      local isUserstatRewards = userstatItemRewardData != null
      local rewardTitle = isUserstatRewards ? userstatRewardTitleLocId
        : parentRecipe ? parentRecipe.getRewardTitleLocId(isHasFakeRecipes)
        : ""
      local rewardListLocId = isUserstatRewards ? userstatItemsListLocId
        : params?.rewardListLocId ? params.rewardListLocId
        : parentRecipe ? componentItem.getItemsListLocId()
        : ""

      local openTrophyWndConfigs = u.map(resultItemsShowOpening, @(extItem) {
        id = componentItem.id
        item = extItem?.itemdef?.itemdefid
        count = extItem?.quantity ?? 0
      })

      local effectOnOpenChest = componentItem.getEffectOnOpenChest()
      ::gui_start_open_trophy({ [componentItem.id] = openTrophyWndConfigs,
        rewardTitle = ::loc(rewardTitle),
        rewardListLocId = rewardListLocId
        isDisassemble = isDisassemble
        isHidePrizeActionBtn = params?.isHidePrizeActionBtn ?? false
        singleAnimationGuiSound = effectOnOpenChest?.playSound
        rewardImage = effectOnOpenChest?.showImage
        rewardImageRatio = effectOnOpenChest?.imageRatio
        rewardImageShowTimeSec = effectOnOpenChest?.showTimeSec ?? -1
        reUseRecipeUid = params?.reUseRecipeUid
      })
      removeUserstatItemRewardToShow(componentItem.id)
    }

    autoConsumeItems()
  }

  getSaveId = @() markRecipeSaveId + uid

  function markRecipe(isUserMark = false, needSave = true)
  {
    local marker = !isUserMark ? MARK_RECIPE.USED
      : (isUserMark && mark == MARK_RECIPE.NONE) ? MARK_RECIPE.BY_USER
      : MARK_RECIPE.NONE

    if(mark == marker)
      return false

    mark = marker
    if (needSave)
      ::save_local_account_settings(getSaveId(), mark)

    return true
  }

  function loadStateRecipe()
  {
    mark = ::load_local_account_settings(getSaveId(), MARK_RECIPE.NONE)
  }

  getRewardTitleLocId = @(hasFakeRecipes = true) hasFakeRecipes
    ? getMarkLocIdByPath(getLocIdsList().craftFinishedTitlePrefix)
    : getLocIdsList().rewardTitle

  getRecipeStr = @() ::g_string.implode(
    u.map(initedComponents, @(component) component.itemdefid.tostring()
      + (component.quantity > 1 ? ("x" + component.quantity) : "")),
    ",")

  getLocIdsList = function() {
    if (locIdsList)
      return locIdsList

    locIdsList = defaultLocIdsList.__merge({
      craftTime   = isDisassemble
        ? "msgBox/disassembleItem/time"
        : "msgBox/assembleItem/time"
      rewardTitle = isDisassemble
        ? "mainmenu/itemDisassembled/title"
        : "mainmenu/itemAssembled/title"
      headerRecipeMarkup = (isMultipleItems && (isDisassemble || hasChestInComponents))
        ? "msgBox/extra_items_will_be_spent"
        : hasChestInComponents ? ""
        : "msgBox/items_will_be_spent"
    })

    if (localizationPresetName)
      locIdsList.__update(getCustomLocalizationPresets(localizationPresetName))

    return locIdsList
  }

  getHeaderRecipeMarkupText = @() ::loc(getLocIdsList().headerRecipeMarkup)

  getConfirmMessageLocId = @(itemLocIdsList) getLocIdsList().msgBoxConfirmWhithItemName ??
    (isDisassemble
      ? itemLocIdsList.msgBoxConfirmWhithItemNameDisassemble
      : itemLocIdsList.msgBoxConfirmWhithItemName)
  getActionButtonLocId = @() getLocIdsList().actionButton
  getEffectOnStartCraft = @() getEffectOnStartCraftPresetById(effectOnStartCraftPresetName)
}

u.registerClass("Recipe", ExchangeRecipes, @(r1, r2) r1.idx == r2.idx)

return ExchangeRecipes
