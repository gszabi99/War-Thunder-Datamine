from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { setTimeout, clearTimer } = require("dagor.workcycle")
let { utf8ToLower } = require("%sqstd/string.nut")
let { getCollectionsList } = require("%scripts/collections/collections.nut")
let { updateDecoratorDescription } = require("%scripts/customization/decoratorDescription.nut")
let { placePriceTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { getObjValidIndex, move_mouse_on_child_by_value } = require("%sqDagui/daguiUtil.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { askPurchaseDecorator, askConsumeDecoratorCoupon,
  findDecoratorCouponOnMarketplace } = require("%scripts/customization/decoratorAcquire.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings } = require("%scripts/clientState/localProfile.nut")
let { canGetDecoratorFromTrophy } = require("%scripts/items/itemsManagerGetters.nut")

const IS_ONLY_UNCOMPLETED_SAVE_ID = "collections/isOnlyUncompleted"

local CollectionsHandler = class (gui_handlers.BaseGuiHandlerWT) {
  wndType          = handlerType.CUSTOM
  sceneBlkName     = "%gui/collections/collectionsPage.blk"

  parent = null
  applyFilterTimer = null
  collectionNameFilter = ""
  collectionsList = null
  collectionsNavigatorObj = null
  collectionsListObj = null
  decalsListObj = null
  mainPrizeObj = null
  isOnlyUncompleted = false
  selectedDecoratorId = null
  currentConfigs = null

  function initScreen() {
    this.isOnlyUncompleted = loadLocalAccountSettings(IS_ONLY_UNCOMPLETED_SAVE_ID, false)
      && (this.selectedDecoratorId == null || !this.isCollectionCompleted(this.selectedDecoratorId))
    this.collectionsList = this.filterCollectionsList()
    this.updateContentVisibility()
    this.collectionsListObj = this.scene.findObject("collections")
    this.decalsListObj = this.scene.findObject("collections_list")
    this.mainPrizeObj = this.scene.findObject("main_prize")
    this.collectionsNavigatorObj = this.scene.findObject("collections_navigator")
    this.updateOnlyUncompletedCheckbox()
    this.fillCollectionsList()
    move_mouse_on_child_by_value(this.collectionsListObj)
    this.jumpToDecorator()
    this.updateTotalCollected()
  }

  function updateTotalCollected() {
    let count = getCollectionsList().reduce(function(res, v) { res += v.prize.isUnlocked() ? 1 : 0; return res }, 0)
    let totalReceivedObj = this.scene.findObject("total_received")
    totalReceivedObj.setValue(loc("profile/collections/totalReceived", { count }))
  }

  function updateContentVisibility() {
    this.scene.findObject("content").show(this.collectionsList.len() > 0)
    this.scene.findObject("empty_text").show(this.collectionsList.len() == 0)
  }

  function fillCollectionsList() {
    let view = { items = [] }
    for (local i = 0; i < this.collectionsList.len(); i++)
      view.items.append({
        id = this.collectionsList[i].getDecoratorObjId(i, this.collectionsList[i].prize.id)
        text = this.collectionsList[i].getLocName()
        autoScrollText = true
      })

    let data = handyman.renderCached("%gui/commonParts/shopFilter.tpl", view)
    this.guiScene.replaceContentFromText(this.collectionsListObj, data, data.len(), this)
    this.collectionsListObj.setValue(0)
  }

  function onCollectionSelect(_obj = null) {
    let value = getObjValidIndex(this.collectionsListObj)
    this.updateCollectionInfo(value)
  }

  function updateCollectionInfo(index) {
    this.fillCollectionItems(index)
    this.updateDecoratorInfo()
  }

  function fillCollectionItems(index) {
    let view = this.collectionsList[index].getView(index)
    let decalsMarkup = handyman.renderCached("%gui/commonParts/imgFrame.tpl", { items = view.items })
    this.guiScene.replaceContentFromText(this.decalsListObj, decalsMarkup, decalsMarkup.len(), this)

    let mainPrizeMarkup = handyman.renderCached("%gui/commonParts/imgFrame.tpl", { items = [view.mainPrize] })
    this.guiScene.replaceContentFromText(this.mainPrizeObj, mainPrizeMarkup, mainPrizeMarkup.len(), this)

    let thisCapture = this
    this.currentConfigs = view.items.map(@(item) thisCapture.getDecoratorConfig(item.id))
    this.currentConfigs.append(this.getDecoratorConfig(view.mainPrize.id))

    this.collectionsNavigatorObj.setValue(this.currentConfigs.len()-1)
  }

  function jumpToDecorator() {
    if (this.selectedDecoratorId == null)
      return

    let decoratorId = this.selectedDecoratorId
    let collectionIdx = this.collectionsList.findindex(@(c) c.findDecoratorById(decoratorId).decorator != null)
    if (collectionIdx == null)
      return

    this.collectionsListObj.setValue(collectionIdx)

    local decoratorIdx = null
    if (this.collectionsList[collectionIdx].prize.id == this.selectedDecoratorId)
      decoratorIdx = this.collectionsList[collectionIdx].collectionItems.len()
    else
      decoratorIdx = this.collectionsList[collectionIdx].collectionItems.findindex(@(d) d.id == decoratorId)

    if (decoratorIdx != null)
      this.collectionsNavigatorObj.setValue(decoratorIdx)
  }

  function isCollectionCompleted(decoratorId) {
    return getCollectionsList()
      .findvalue(@(c) c.findDecoratorById(decoratorId).decorator != null)
      ?.prize.isUnlocked()
      ?? false
  }

  function getDecoratorConfig(id = null) {
    if (id == null) {
      let index = this.getSelectedIndex()
      if (index < 0 || index >= this.currentConfigs.len())
        return {
          collectionIdx = null
          decorator = null
          isPrize = false
        }
      return this.currentConfigs[index]
    }

    let curDecoratorParams = id.split(";")
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

  function getSelectedIndex() {
    return to_integer_safe(this.collectionsNavigatorObj?.getValue() ?? "-1")
  }

  function updateDecoratorInfo() {
    let decoratorConfig = this.getDecoratorConfig()
    let decorator = decoratorConfig?.decorator
    if (decorator == null)
      return

    let infoNestObj = showObjById("decorator_info", true, this.scene)
    let imgRatio = 1.0 / decorator.decoratorType.getRatio(decorator)
    local additionalDescriptionMarkup = null
    if (decoratorConfig.isPrize)
      additionalDescriptionMarkup = this.collectionsList?[decoratorConfig?.collectionIdx ?? -1]?.getCollectionViewMarkup(
        { hasHorizontalFlow = true, fixedTitleWidth = "300@sf/@pf"}
      )

    updateDecoratorDescription(infoNestObj, this, decorator.decoratorType, decorator, {
      additionalDescriptionMarkup
      imgSize = ["1@profileMedalSizeBig", $"{imgRatio}@profileMedalSizeBig"]
      showAsTrophyContent = !decorator.canBuyUnlock(null)
        && !decorator.canGetFromCoupon(null)
        && !decorator.canBuyCouponOnMarketplace(null)
        && canGetDecoratorFromTrophy(decorator)
      needAddIndentationUnderImage = false
    })

    this.updateButtons(decoratorConfig)
  }

  function onSelectDecorator() {
    this.updateDecoratorInfo()
  }

  function updateButtons(curDecoratorConfig) {
    let decorator = curDecoratorConfig?.decorator
    let canBuy = decorator?.canBuyUnlock(null) ?? false
    let canConsumeCoupon = !canBuy && (decorator?.canGetFromCoupon(null) ?? false)
    let canFindOnMarketplace = !canBuy && !canConsumeCoupon
      && (decorator?.canBuyCouponOnMarketplace(null) ?? false)
    let canFindInStore = !canBuy && !canConsumeCoupon && !canFindOnMarketplace
      && canGetDecoratorFromTrophy(decorator)

    let bObj = showObjById("btn_buy_decorator", canBuy, this.scene)
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
    this.updateContentVisibility()
    this.updateTotalCollected()
    if (this.collectionsList.len() != this.collectionsListObj.childrenCount())
      this.fillCollectionsList()
  }

  function onEventProfileUpdated(_p) {
    this.updateCollectionsList()
    this.onCollectionSelect()
  }

  function onEventInventoryUpdate(_params) {
    this.updateCollectionsList()
  }

  function onCollectionsListFocusChange() {
    this.updateDecoratorInfo()
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
    let list = this.isOnlyUncompleted
      ? getCollectionsList().filter(@(val) !val.prize.isUnlocked())
      : getCollectionsList()
    let nameFilter = utf8ToLower(this.collectionNameFilter)
    return nameFilter == "" ? list
      : list.filter(@(v) v.searchName.indexof(nameFilter) != null)
  }

  function onOnlyUncompletedCheck(obj) {
    this.isOnlyUncompleted = obj.getValue()
    this.collectionsList = this.filterCollectionsList()
    this.updateContentVisibility()
    this.fillCollectionsList()
    saveLocalAccountSettings(IS_ONLY_UNCOMPLETED_SAVE_ID, this.isOnlyUncompleted)
  }

  function applyCollectionFilter(obj) {
    clearTimer(this.applyFilterTimer)
    this.collectionNameFilter = utf8ToLower(obj.getValue())
    if(this.collectionNameFilter == "") {
      this.updateCollectionsList()
      return
    }

    let applyCallback = Callback(@() this.updateCollectionsList(), this)
    this.applyFilterTimer = setTimeout(0.8, @() applyCallback())
  }

  function onFilterCancel(filterObj) {
    if (filterObj.getValue() != "")
      filterObj.setValue("")
    else if (this.parent != null)
      this.guiScene.performDelayed(this.parent, this.parent.goBack)
  }

  onEventCollectionsCacheInvalidate = @(_) this.updateCollectionsList()
}

gui_handlers.CollectionsHandler <- CollectionsHandler

return {
  openCollectionsPage = @(params = {}) handlersManager.loadHandler(CollectionsHandler, params)
  hasAvailableCollections = @() hasFeature("Collection") && getCollectionsList().len() > 0
}