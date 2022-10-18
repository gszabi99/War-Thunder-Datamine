from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { ceil } = require("math")
let { getCollectionsList } = require("%scripts/collections/collections.nut")
let { updateDecoratorDescription } = require("%scripts/customization/decoratorDescription.nut")
let { placePriceTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { askPurchaseDecorator, askConsumeDecoratorCoupon,
  findDecoratorCouponOnMarketplace } = require("%scripts/customization/decoratorAcquire.nut")

const MAX_COLLECTION_ITEMS = 10
const IS_ONLY_UNCOMPLETED_SAVE_ID = "collections/isOnlyUncompleted"

local collectionsWnd = class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType          = handlerType.MODAL
  sceneBlkName     = "%gui/collections/collectionsWnd.blk"

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
    collectionsListObj = this.scene.findObject("collections_list")
    updateOnlyUncompletedCheckbox()
    initCollectionsListSizeOnce()
    initState()
    fillPage()
    ::move_mouse_on_child_by_value(collectionsListObj)
  }

  function initCollectionsListSizeOnce() {
    if (collectionsPerPage > 0)
      return

    let wndCollectionsObj = this.scene.findObject("wnd_collections")
    countItemsInRow = to_pixels("1@collectionWidth-1@collectionPrizeWidth")
      / (to_pixels("1@collectionItemSizeWithIndent"))
    let countRowInCollection = ceil(MAX_COLLECTION_ITEMS / (countItemsInRow*1.0))
    collectionHeight = "".concat(countRowInCollection,
      "@collectionItemSizeWithIndent+1@buttonHeight-1@blockInterval")
    let sizes = ::g_dagui_utils.adjustWindowSize(wndCollectionsObj, collectionsListObj,
      "@collectionWidth", collectionHeight, "@blockInterval", "@blockInterval", {windowSizeX = 0})
    collectionsPerPage = sizes.itemsCountY
  }

  function initState() {
    if (selectedDecoratorId == null)
      return

    let decoratorId = selectedDecoratorId
    let collectionIdx = collectionsList.findindex(@(c) c.findDecoratorById(decoratorId).decorator != null)
    if (collectionIdx == null)
      return

    curPage = ceil(collectionIdx / collectionsPerPage).tointeger()
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
    let view = { collections = [] }
    let pageStartIndex = curPage * collectionsPerPage
    let pageEndIndex = min((curPage + 1) * collectionsPerPage, collectionsList.len())
    local idxOnPage = 0
    for(local i=pageStartIndex; i < pageEndIndex; i++) {
      let collectionTopPos = $"{idxOnPage} * ({collectionHeight} + 1@blockInterval)"
      view.collections.append(
        collectionsList[i].getView(countItemsInRow, collectionTopPos, collectionHeight, i))
      idxOnPage++
    }
    view.hasCollections <- view.collections.len() > 0

    let data = ::handyman.renderCached("%gui/collections/collection", view)
    if (checkObj(collectionsListObj))
      this.guiScene.replaceContentFromText(collectionsListObj, data, data.len(), this)

    let prevValue = collectionsListObj.getValue()
    let value = findLastValue(prevValue)
    if (value >= 0)
      collectionsListObj.setValue(value)

    updateDecoratorInfo()

    ::generatePaginator(this.scene.findObject("paginator_place"), this,
      curPage, ceil(collectionsList.len().tofloat() / collectionsPerPage) - 1, null, true /*show last page*/)
  }

  function findLastValue(prevValue) {
    local enabledValue = null
    for(local i = 0; i < collectionsListObj.childrenCount(); i++)
    {
      let childObj = collectionsListObj.getChild(i)
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
    let curDecoratorParams = (id ?? getCurDecoratorObj()?.id
      ?? lastSelectedDecoratorObjId ?? "").split(";")
    if (curDecoratorParams.len() < 2)
      return {
        collectionIdx = null
        decorator = null
        isPrize = false
      }

    let collectionIdx = ::to_integer_safe(curDecoratorParams[0])
    let collectionDecorator = collectionsList?[collectionIdx].findDecoratorById(curDecoratorParams[1])
    return {
      collectionIdx = collectionIdx
      decorator = collectionDecorator?.decorator
      isPrize = collectionDecorator?.isPrize ?? false
    }
  }

  function getCurDecoratorObj() {
    if (::show_console_buttons && !collectionsListObj.isHovered())
      return null

    let value = ::get_obj_valid_index(collectionsListObj)
    if (value < 0)
      return null

    return collectionsListObj.getChild(value)
  }

  function updateDecoratorInfo() {
    let decoratorConfig = getDecoratorConfig()
    let decorator = decoratorConfig?.decorator
    let hasInfo = decorator != null
    let infoNestObj = this.showSceneBtn("decorator_info", hasInfo)
    if (hasInfo) {
      let imgRatio = 1.0 / (decorator?.decoratorType.getRatio(decorator) ?? 1)
      updateDecoratorDescription(infoNestObj, this, decorator?.decoratorType, decorator, {
        additionalDescriptionMarkup = decoratorConfig.isPrize
          ? collectionsList?[decoratorConfig?.collectionIdx ?? -1]?.getCollectionViewForPrize()
          : null
        imgSize = ["1@profileMedalSizeBig", $"{imgRatio}@profileMedalSizeBig"]
        showAsTrophyContent = !decorator?.canBuyUnlock(null)
          && !decorator?.canGetFromCoupon(null)
          && !decorator?.canBuyCouponOnMarketplace(null)
          && ::ItemsManager.canGetDecoratorFromTrophy(decorator)
      })
    }
    updateButtons(decoratorConfig)
  }

  function onSelectDecorator() {
    let value = ::get_obj_valid_index(collectionsListObj)
    if (value >= 0)
      lastSelectedDecoratorObjId = collectionsListObj.getChild(value)?.id ?? ""
    updateDecoratorInfo()
  }

  function updateButtons(curDecoratorConfig) {
    let decorator = curDecoratorConfig?.decorator
    let canBuy = decorator?.canBuyUnlock(null) ?? false
    let canConsumeCoupon = !canBuy && (decorator?.canGetFromCoupon(null) ?? false)
    let canFindOnMarketplace = !canBuy && !canConsumeCoupon
      && (decorator?.canBuyCouponOnMarketplace(null) ?? false)
    let canFindInStore = !canBuy && !canConsumeCoupon && !canFindOnMarketplace
      && ::ItemsManager.canGetDecoratorFromTrophy(decorator)

    let bObj = this.showSceneBtn("btn_buy_decorator", canBuy)
    if (canBuy && checkObj(bObj))
      placePriceTextToButton(this.scene, "btn_buy_decorator", loc("mainmenu/btnOrder"), decorator?.getCost())

    ::showBtnTable(this.scene, {
      btn_preview = decorator?.canPreview() ?? false
      btn_marketplace_consume_coupon = canConsumeCoupon
      btn_marketplace_find_coupon = canFindOnMarketplace
      btn_store = canFindInStore
    })
  }

  function onDecoratorPreview(_obj) {
    if (!this.isValid())
      return

    getDecoratorConfig()?.decorator.doPreview()
  }

  function updateCollectionsList() {
    collectionsList = filterCollectionsList()
    fillPage()
  }

  function onEventProfileUpdated(_p) {
    updateCollectionsList()
  }

  function onEventInventoryUpdate(_params)
  {
    updateCollectionsList()
  }

  function onColletionsListFocusChange() {
    updateDecoratorInfo()
  }

  function getHandlerRestoreData() {
    let data = {
      openData = {
      }
      stateData = {
        lastSelectedDecoratorObjId = getCurDecoratorObj()?.id ?? lastSelectedDecoratorObjId
      }
    }
    return data
  }

  function restoreHandler(stateData) {
    let collectionIdx = getDecoratorConfig(stateData.lastSelectedDecoratorObjId)?.collectionIdx
    if (collectionIdx == null)
      return
    curPage = ceil(collectionIdx / collectionsPerPage).tointeger()
    lastSelectedDecoratorObjId = stateData.lastSelectedDecoratorObjId
    fillPage()
  }

  function onEventBeforeStartShowroom(_p) {
    ::handlersManager.requestHandlerRestore(this, ::gui_handlers.MainMenu)
  }

  function onBuyDecorator() {
    let decorator = getDecoratorConfig()?.decorator
    askPurchaseDecorator(decorator, null)
  }

  function onBtnMarketplaceFindCoupon(_obj)
  {
    let decorator = getDecoratorConfig()?.decorator
    findDecoratorCouponOnMarketplace(decorator)
  }

  function onBtnMarketplaceConsumeCoupon(_obj)
  {
    let decorator = getDecoratorConfig()?.decorator
    askConsumeDecoratorCoupon(decorator, null)
  }

  function updateOnlyUncompletedCheckbox()
  {
    let checkboxObj = this.scene.findObject("checkbox_only_uncompleted")
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
  hasAvailableCollections = @() hasFeature("Collection") && getCollectionsList().len() > 0
}