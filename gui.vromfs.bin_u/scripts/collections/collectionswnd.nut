//checked for plus_string
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { getObjValidIndex, adjustWindowSize } = require("%sqDagui/daguiUtil.nut")
let { ceil } = require("math")
let { getCollectionsList } = require("%scripts/collections/collections.nut")
let { updateDecoratorDescription } = require("%scripts/customization/decoratorDescription.nut")
let { placePriceTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { move_mouse_on_child_by_value, handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { askPurchaseDecorator, askConsumeDecoratorCoupon,
  findDecoratorCouponOnMarketplace } = require("%scripts/customization/decoratorAcquire.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")

const MAX_COLLECTION_ITEMS = 10
const IS_ONLY_UNCOMPLETED_SAVE_ID = "collections/isOnlyUncompleted"

local collectionsWnd = class extends gui_handlers.BaseGuiHandlerWT {
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
    this.isOnlyUncompleted = loadLocalAccountSettings(IS_ONLY_UNCOMPLETED_SAVE_ID, false)
      && (this.selectedDecoratorId == null || !this.isCollectionCompleted(this.selectedDecoratorId))
    this.collectionsList = this.filterCollectionsList()
    this.collectionsListObj = this.scene.findObject("collections_list")
    this.updateOnlyUncompletedCheckbox()
    this.initCollectionsListSizeOnce()
    this.initState()
    this.fillPage()
    move_mouse_on_child_by_value(this.collectionsListObj)
  }

  function initCollectionsListSizeOnce() {
    if (this.collectionsPerPage > 0)
      return

    let wndCollectionsObj = this.scene.findObject("wnd_collections")
    this.countItemsInRow = to_pixels("1@collectionWidth-1@collectionPrizeWidth")
      / (to_pixels("1@collectionItemSizeWithIndent"))
    let countRowInCollection = ceil(MAX_COLLECTION_ITEMS / (this.countItemsInRow * 1.0))
    this.collectionHeight = "".concat(countRowInCollection,
      "@collectionItemSizeWithIndent+1@buttonHeight-1@blockInterval")
    let sizes = adjustWindowSize(wndCollectionsObj, this.collectionsListObj,
      "@collectionWidth", this.collectionHeight, "@blockInterval", "@blockInterval", { windowSizeX = 0 })
    this.collectionsPerPage = sizes.itemsCountY
  }

  function initState() {
    if (this.selectedDecoratorId == null)
      return

    let decoratorId = this.selectedDecoratorId
    let collectionIdx = this.collectionsList.findindex(@(c) c.findDecoratorById(decoratorId).decorator != null)
    if (collectionIdx == null)
      return

    this.curPage = ceil(collectionIdx / this.collectionsPerPage).tointeger()
    this.lastSelectedDecoratorObjId = this.collectionsList[collectionIdx].getDecoratorObjId(collectionIdx, this.selectedDecoratorId)
  }

  function isCollectionCompleted(decoratorId) {
    return getCollectionsList()
      .findvalue(@(c) c.findDecoratorById(decoratorId).decorator != null)
      ?.prize.isUnlocked()
      ?? false
  }

  function goToPage(obj) {
    this.curPage = obj.to_page.tointeger()
    this.fillPage()
  }

  function fillPage() {
    let view = { collections = [] }
    let pageStartIndex = this.curPage * this.collectionsPerPage
    let pageEndIndex = min((this.curPage + 1) * this.collectionsPerPage, this.collectionsList.len())
    local idxOnPage = 0
    for (local i = pageStartIndex; i < pageEndIndex; i++) {
      let collectionTopPos = $"{idxOnPage} * ({this.collectionHeight} + 1@blockInterval)"
      view.collections.append(
        this.collectionsList[i].getView(this.countItemsInRow, collectionTopPos, this.collectionHeight, i))
      idxOnPage++
    }
    view.hasCollections <- view.collections.len() > 0

    let data = handyman.renderCached("%gui/collections/collection.tpl", view)
    if (checkObj(this.collectionsListObj))
      this.guiScene.replaceContentFromText(this.collectionsListObj, data, data.len(), this)

    let prevValue = this.collectionsListObj.getValue()
    let value = this.findLastValue(prevValue)
    if (value >= 0)
      this.collectionsListObj.setValue(value)

    this.updateDecoratorInfo()

    ::generatePaginator(this.scene.findObject("paginator_place"), this,
      this.curPage, ceil(this.collectionsList.len().tofloat() / this.collectionsPerPage) - 1, null, true /*show last page*/ )
  }

  function findLastValue(prevValue) {
    local enabledValue = null
    for (local i = 0; i < this.collectionsListObj.childrenCount(); i++) {
      let childObj = this.collectionsListObj.getChild(i)
      if (!childObj.isEnabled())
        continue
      if (childObj?.id == this.lastSelectedDecoratorObjId)
        return i
      if (enabledValue == null || prevValue == i)
        enabledValue = i
    }
    return enabledValue ?? -1
  }

  function getDecoratorConfig(id = null) {
    let curDecoratorParams = (id ?? this.getCurDecoratorObj()?.id
      ?? this.lastSelectedDecoratorObjId ?? "").split(";")
    if (curDecoratorParams.len() < 2)
      return {
        collectionIdx = null
        decorator = null
        isPrize = false
      }

    let collectionIdx = to_integer_safe(curDecoratorParams[0])
    let collectionDecorator = this.collectionsList?[collectionIdx].findDecoratorById(curDecoratorParams[1])
    return {
      collectionIdx = collectionIdx
      decorator = collectionDecorator?.decorator
      isPrize = collectionDecorator?.isPrize ?? false
    }
  }

  function getCurDecoratorObj() {
    if (showConsoleButtons.value && !this.collectionsListObj.isHovered())
      return null

    let value = getObjValidIndex(this.collectionsListObj)
    if (value < 0)
      return null

    return this.collectionsListObj.getChild(value)
  }

  function updateDecoratorInfo() {
    let decoratorConfig = this.getDecoratorConfig()
    let decorator = decoratorConfig?.decorator
    let hasInfo = decorator != null
    let infoNestObj = this.showSceneBtn("decorator_info", hasInfo)
    if (hasInfo) {
      let imgRatio = 1.0 / (decorator?.decoratorType.getRatio(decorator) ?? 1)
      updateDecoratorDescription(infoNestObj, this, decorator?.decoratorType, decorator, {
        additionalDescriptionMarkup = decoratorConfig.isPrize
          ? this.collectionsList?[decoratorConfig?.collectionIdx ?? -1]?.getCollectionViewForPrize()
          : null
        imgSize = ["1@profileMedalSizeBig", $"{imgRatio}@profileMedalSizeBig"]
        showAsTrophyContent = !decorator?.canBuyUnlock(null)
          && !decorator?.canGetFromCoupon(null)
          && !decorator?.canBuyCouponOnMarketplace(null)
          && ::ItemsManager.canGetDecoratorFromTrophy(decorator)
      })
    }
    this.updateButtons(decoratorConfig)
  }

  function onSelectDecorator() {
    let value = getObjValidIndex(this.collectionsListObj)
    if (value >= 0)
      this.lastSelectedDecoratorObjId = this.collectionsListObj.getChild(value)?.id ?? ""
    this.updateDecoratorInfo()
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

    showObjectsByTable(this.scene, {
      btn_preview = decorator?.canPreview() ?? false
      btn_marketplace_consume_coupon = canConsumeCoupon
      btn_marketplace_find_coupon = canFindOnMarketplace
      btn_store = canFindInStore
    })
  }

  function onDecoratorPreview(_obj) {
    if (!this.isValid())
      return

    this.getDecoratorConfig()?.decorator.doPreview()
  }

  function updateCollectionsList() {
    this.collectionsList = this.filterCollectionsList()
    this.fillPage()
  }

  function onEventProfileUpdated(_p) {
    this.updateCollectionsList()
  }

  function onEventInventoryUpdate(_params) {
    this.updateCollectionsList()
  }

  function onColletionsListFocusChange() {
    this.updateDecoratorInfo()
  }

  function getHandlerRestoreData() {
    let data = {
      openData = {
      }
      stateData = {
        lastSelectedDecoratorObjId = this.getCurDecoratorObj()?.id ?? this.lastSelectedDecoratorObjId
      }
    }
    return data
  }

  function restoreHandler(stateData) {
    let collectionIdx = this.getDecoratorConfig(stateData.lastSelectedDecoratorObjId)?.collectionIdx
    if (collectionIdx == null)
      return
    this.curPage = ceil(collectionIdx / this.collectionsPerPage).tointeger()
    this.lastSelectedDecoratorObjId = stateData.lastSelectedDecoratorObjId
    this.fillPage()
  }

  function onEventBeforeStartShowroom(_p) {
    handlersManager.requestHandlerRestore(this, gui_handlers.MainMenu)
  }

  function onBuyDecorator() {
    let decorator = this.getDecoratorConfig()?.decorator
    askPurchaseDecorator(decorator, null)
  }

  function onBtnMarketplaceFindCoupon(_obj) {
    let decorator = this.getDecoratorConfig()?.decorator
    findDecoratorCouponOnMarketplace(decorator)
  }

  function onBtnMarketplaceConsumeCoupon(_obj) {
    let decorator = this.getDecoratorConfig()?.decorator
    askConsumeDecoratorCoupon(decorator, null)
  }

  function updateOnlyUncompletedCheckbox() {
    let checkboxObj = this.scene.findObject("checkbox_only_uncompleted")
    checkboxObj.setValue(this.isOnlyUncompleted)
  }

  function filterCollectionsList() {
    return this.isOnlyUncompleted
      ? getCollectionsList().filter(@(val) !val.prize.isUnlocked())
      : getCollectionsList()
  }

  function onOnlyUncompletedCheck(obj) {
    this.isOnlyUncompleted = obj.getValue()
    this.collectionsList = this.filterCollectionsList()
    this.curPage = 0
    this.fillPage()
    saveLocalAccountSettings(IS_ONLY_UNCOMPLETED_SAVE_ID, this.isOnlyUncompleted)
  }
}

gui_handlers.collectionsWnd <- collectionsWnd

return {
  openCollectionsWnd = @(params = {}) handlersManager.loadHandler(collectionsWnd, params)
  hasAvailableCollections = @() hasFeature("Collection") && getCollectionsList().len() > 0
}