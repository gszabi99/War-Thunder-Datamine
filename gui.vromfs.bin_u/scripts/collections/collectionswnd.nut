local { getCollectionsList } = require("scripts/collections/collections.nut")
local { updateDecoratorDescription } = require("scripts/customization/decoratorDescription.nut")
local { placePriceTextToButton } = require("scripts/viewUtils/objectTextUpdate.nut")
local { askPurchaseDecorator, askConsumeDecoratorCoupon,
  findDecoratorCouponOnMarketplace } = require("scripts/customization/decoratorAcquire.nut")

const MAX_COLLECTION_ITEMS = 10
const IS_ONLY_UNCOMPLETED_SAVE_ID = "collections/isOnlyUncompleted"

local collectionsWnd = class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType          = handlerType.MODAL
  sceneBlkName     = "gui/collections/collectionsWnd.blk"

  collectionsList = null
  curPage = 0
  collectionsPerPage = -1
  countItemsInRow = -1
  collectionHeight = 0
  lastSelectedDecoratorObjId = ""
  collectionsListObj = null
  isOnlyUncompleted = false
  selectedDecoratorId = null

  function initScreen() {
    isOnlyUncompleted = ::load_local_account_settings(IS_ONLY_UNCOMPLETED_SAVE_ID, false)
      && (selectedDecoratorId == null || !isCollectionCompleted(selectedDecoratorId))
    collectionsList = filterCollectionsList()
    collectionsListObj = scene.findObject("collections_list")
    updateOnlyUncompletedCheckbox()
    initCollectionsListSizeOnce()
    initState()
    fillPage()
    ::move_mouse_on_child_by_value(collectionsListObj)
  }

  function initCollectionsListSizeOnce() {
    if (collectionsPerPage > 0)
      return

    local wndCollectionsObj = scene.findObject("wnd_collections")
    countItemsInRow = ::to_pixels("1@collectionWidth-1@collectionPrizeWidth")
      / (::to_pixels("1@collectionItemSizeWithIndent"))
    local countRowInCollection = ::ceil(MAX_COLLECTION_ITEMS / (countItemsInRow*1.0))
    collectionHeight = "".concat(countRowInCollection,
      "@collectionItemSizeWithIndent+1@buttonHeight-1@blockInterval")
    local sizes = ::g_dagui_utils.adjustWindowSize(wndCollectionsObj, collectionsListObj,
      "@collectionWidth", collectionHeight, "@blockInterval", "@blockInterval", {windowSizeX = 0})
    collectionsPerPage = sizes.itemsCountY
  }

  function initState() {
    if (selectedDecoratorId == null)
      return

    local decoratorId = selectedDecoratorId
    local collectionIdx = collectionsList.findindex(@(c) c.findDecoratorById(decoratorId).decorator != null)
    if (collectionIdx == null)
      return

    curPage = ::ceil(collectionIdx / collectionsPerPage).tointeger()
    lastSelectedDecoratorObjId = collectionsList[collectionIdx].getDecoratorObjId(collectionIdx, selectedDecoratorId)
  }

  function isCollectionCompleted(decoratorId) {
    return getCollectionsList()
      .findvalue(@(c) c.findDecoratorById(decoratorId).decorator != null)
      .prize.isUnlocked()
  }

  function goToPage(obj) {
    curPage = obj.to_page.tointeger()
    fillPage()
  }

  function fillPage() {
    local view = { collections = [] }
    local pageStartIndex = curPage * collectionsPerPage
    local pageEndIndex = min((curPage + 1) * collectionsPerPage, collectionsList.len())
    local idxOnPage = 0
    for(local i=pageStartIndex; i < pageEndIndex; i++) {
      local collectionTopPos = $"{idxOnPage} * ({collectionHeight} + 1@blockInterval)"
      view.collections.append(
        collectionsList[i].getView(countItemsInRow, collectionTopPos, collectionHeight, i))
      idxOnPage++
    }
    view.hasCollections <- view.collections.len() > 0

    local data = ::handyman.renderCached("gui/collections/collection", view)
    if (::check_obj(collectionsListObj))
      guiScene.replaceContentFromText(collectionsListObj, data, data.len(), this)

    local prevValue = collectionsListObj.getValue()
    local value = findLastValue(prevValue)
    if (value >= 0)
      collectionsListObj.setValue(value)

    updateDecoratorInfo()

    generatePaginator(scene.findObject("paginator_place"), this,
      curPage, ::ceil(collectionsList.len().tofloat() / collectionsPerPage) - 1, null, true /*show last page*/)
  }

  function findLastValue(prevValue) {
    local enabledValue = null
    for(local i = 0; i < collectionsListObj.childrenCount(); i++)
    {
      local childObj = collectionsListObj.getChild(i)
      if (!childObj.isEnabled())
        continue
      if (childObj?.id == lastSelectedDecoratorObjId)
        return i
      if (enabledValue == null || prevValue == i)
        enabledValue = i
    }
    return enabledValue ?? -1
  }

  function getDecoratorConfig(id = null) {
    local curDecoratorParams = (id ?? getCurDecoratorObj()?.id
      ?? lastSelectedDecoratorObjId ?? "").split(";")
    if (curDecoratorParams.len() < 2)
      return {
        collectionIdx = null
        decorator = null
        isPrize = false
      }

    local collectionIdx = ::to_integer_safe(curDecoratorParams[0])
    local collectionDecorator = collectionsList?[collectionIdx].findDecoratorById(curDecoratorParams[1])
    return {
      collectionIdx = collectionIdx
      decorator = collectionDecorator?.decorator
      isPrize = collectionDecorator?.isPrize ?? false
    }
  }

  function getCurDecoratorObj() {
    if (::show_console_buttons && !collectionsListObj.isHovered())
      return null

    local value = ::get_obj_valid_index(collectionsListObj)
    if (value < 0)
      return null

    return collectionsListObj.getChild(value)
  }

  function updateDecoratorInfo() {
    local decoratorConfig = getDecoratorConfig()
    local decorator = decoratorConfig?.decorator
    local hasInfo = decorator != null
    local infoNestObj = showSceneBtn("decorator_info", hasInfo)
    if (hasInfo) {
      local imgRatio = 1.0 / (decorator?.decoratorType.getRatio(decorator) ?? 1)
      updateDecoratorDescription(infoNestObj, this, decorator?.decoratorType, decorator, {
        additionalDescriptionMarkup = decoratorConfig.isPrize
          ? collectionsList?[decoratorConfig?.collectionIdx ?? -1]?.getCollectionViewForPrize()
          : null
        imgSize = ["1@profileMedalSizeBig", $"{imgRatio}@profileMedalSizeBig"]
        useBigImg = true
        showAsTrophyContent = !decorator?.canBuyUnlock(null)
          && !decorator?.canGetFromCoupon(null)
          && !decorator?.canBuyCouponOnMarketplace(null)
          && ::ItemsManager.canGetDecoratorFromTrophy(decorator)
      })
    }
    updateButtons(decoratorConfig)
  }

  function onSelectDecorator() {
    local value = ::get_obj_valid_index(collectionsListObj)
    if (value >= 0)
      lastSelectedDecoratorObjId = collectionsListObj.getChild(value)?.id ?? ""
    updateDecoratorInfo()
  }

  function updateButtons(curDecoratorConfig) {
    local decorator = curDecoratorConfig?.decorator
    local canBuy = decorator?.canBuyUnlock(null) ?? false
    local canConsumeCoupon = !canBuy && (decorator?.canGetFromCoupon(null) ?? false)
    local canFindOnMarketplace = !canBuy && !canConsumeCoupon
      && (decorator?.canBuyCouponOnMarketplace(null) ?? false)
    local canFindInStore = !canBuy && !canConsumeCoupon && !canFindOnMarketplace
      && ::ItemsManager.canGetDecoratorFromTrophy(decorator)

    local bObj = showSceneBtn("btn_buy_decorator", canBuy)
    if (canBuy && ::check_obj(bObj))
      placePriceTextToButton(scene, "btn_buy_decorator", ::loc("mainmenu/btnOrder"), decorator?.getCost())

    ::showBtnTable(scene, {
      btn_preview = decorator?.canPreview() ?? false
      btn_marketplace_consume_coupon = canConsumeCoupon
      btn_marketplace_find_coupon = canFindOnMarketplace
      btn_store = canFindInStore
    })
  }

  function onDecoratorPreview(obj) {
    if (!isValid())
      return

    getDecoratorConfig()?.decorator.doPreview()
  }

  function updateCollectionsList() {
    collectionsList = filterCollectionsList()
    fillPage()
  }

  function onEventProfileUpdated(p) {
    updateCollectionsList()
  }

  function onEventInventoryUpdate(params)
  {
    updateCollectionsList()
  }

  function onColletionsListFocusChange() {
    updateDecoratorInfo()
  }

  function getHandlerRestoreData() {
    local data = {
      openData = {
      }
      stateData = {
        lastSelectedDecoratorObjId = getCurDecoratorObj()?.id ?? lastSelectedDecoratorObjId
      }
    }
    return data
  }

  function restoreHandler(stateData) {
    local collectionIdx = getDecoratorConfig(stateData.lastSelectedDecoratorObjId)?.collectionIdx
    if (collectionIdx == null)
      return
    curPage = ::ceil(collectionIdx / collectionsPerPage).tointeger()
    lastSelectedDecoratorObjId = stateData.lastSelectedDecoratorObjId
    fillPage()
  }

  function onEventBeforeStartShowroom(p) {
    ::handlersManager.requestHandlerRestore(this, ::gui_handlers.MainMenu)
  }

  function onBuyDecorator() {
    local decorator = getDecoratorConfig()?.decorator
    askPurchaseDecorator(decorator, null)
  }

  function onBtnMarketplaceFindCoupon(obj)
  {
    local decorator = getDecoratorConfig()?.decorator
    findDecoratorCouponOnMarketplace(decorator)
  }

  function onBtnMarketplaceConsumeCoupon(obj)
  {
    local decorator = getDecoratorConfig()?.decorator
    askConsumeDecoratorCoupon(decorator, null)
  }

  function updateOnlyUncompletedCheckbox()
  {
    local checkboxObj = scene.findObject("checkbox_only_uncompleted")
    checkboxObj.setValue(isOnlyUncompleted)
  }

  function filterCollectionsList()
  {
    return isOnlyUncompleted
      ? getCollectionsList().filter(@(val) !val.prize.isUnlocked())
      : getCollectionsList()
  }

  function onOnlyUncompletedCheck(obj)
  {
    isOnlyUncompleted = obj.getValue()
    collectionsList = filterCollectionsList()
    curPage = 0
    fillPage()
    ::save_local_account_settings(IS_ONLY_UNCOMPLETED_SAVE_ID, isOnlyUncompleted)
  }
}

::gui_handlers.collectionsWnd <- collectionsWnd

return {
  openCollectionsWnd = @(params = {}) ::handlersManager.loadHandler(collectionsWnd, params)
  hasAvailableCollections = @() ::has_feature("Collection") && getCollectionsList().len() > 0
}