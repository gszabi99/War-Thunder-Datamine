local { getCollectionsList } = require("scripts/collections/collections.nut")
local { updateDecoratorDescription } = require("scripts/customization/decoratorDescription.nut")
local { placePriceTextToButton } = require("scripts/viewUtils/objectTextUpdate.nut")

local collectionsWnd = class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType          = handlerType.MODAL
  sceneBlkName     = "gui/collections/collectionsWnd.blk"

  collectionsList = null
  curPage = 0
  collectionsPerPage = -1
  lastSelectedDecoratorObjId = ""
  collectionsListObj = null

  function initScreen() {
    collectionsList = getCollectionsList()
    collectionsListObj = scene.findObject("collections_list")
    initCollectionsListSizeOnce()
    fillPage()
    initFocusArray()
    if (collectionsListObj.childrenCount() > 0)
      collectionsListObj.select()
  }

  function getMainFocusObj() {
    return collectionsListObj
  }

  function initCollectionsListSizeOnce() {
    if (collectionsPerPage > 0)
      return

    local wndCollectionsObj = scene.findObject("wnd_collections")
    local sizes = ::g_dagui_utils.adjustWindowSize(wndCollectionsObj, collectionsListObj,
      "@collectionWidth", "@collectionHeight", "@blockInterval", "@blockInterval", { windowSizeX = 0 })
    collectionsPerPage = sizes.itemsCountY
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
      view.collections.append(collectionsList[i].getView(idxOnPage))
      idxOnPage++
    }

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
    local curDecoratorParams = (id ?? getCurDecoratorObj()?.id ?? "").split(";")
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
    if (::show_console_buttons && !collectionsListObj.isFocused())
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
    local couponItemdefId = decorator?.getCouponItemdefId()
    local unit = null
    if (decorator?.decoratorType == ::g_decorator_type.SKINS)
      unit = ::getAircraftByName(::g_unlocks.getPlaneBySkinId(decorator?.id))
    local canBuy = decorator?.canBuyUnlock(unit) ?? false
    local isUnlocked = decorator?.isUnlocked() ?? false
    local canConsumeCoupon = !isUnlocked && !canBuy &&
      (::ItemsManager.getInventoryItemById(couponItemdefId)?.canConsume() ?? false)
    local canFindOnMarketplace = !isUnlocked && !canBuy && !canConsumeCoupon && couponItemdefId != null

    local bObj = showSceneBtn("btn_buy_decorator", canBuy)
    if (canBuy && ::check_obj(bObj))
      placePriceTextToButton(scene, "btn_buy_decorator", ::loc("mainmenu/btnOrder"), decorator.getCost())

    ::showBtnTable(scene, {
      btn_preview = decorator?.canPreview() ?? false
      btn_marketplace_consume_coupon = canConsumeCoupon
      btn_marketplace_find_coupon = canFindOnMarketplace
    })
  }

  function onDecoratorPreview(obj) {
    if (!isValid())
      return

    getDecoratorConfig()?.decorator.doPreview()
  }

  function updateCollectionsList() {
    collectionsList = getCollectionsList()
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
    if (isValid())
      updateDecoratorInfo()
  }

  function getHandlerRestoreData() {
    local data = {
      openData = {
      }
      stateData = {
        lastSelectedDecoratorObjId = getCurDecoratorObj()?.id
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
    if (decorator == null)
      return

    local cost = decorator.getCost()
    local decoratorType = decorator.decoratorType
    local unitName = ""
    local decoratorId = decorator.id
    if (decoratorType == ::g_decorator_type.SKINS) {
      unitName = ::g_unlocks.getPlaneBySkinId(decoratorId)
      decoratorId = ::g_unlocks.getSkinNameBySkinId(decoratorId)
    }
    local msgText = ::warningIfGold(::loc("shop/needMoneyQuestion_purchaseDecal",
      { purchase = decorator.getName(),
        cost = cost.getTextAccordingToBalance()
      }), cost)

    msgBox("need_money", msgText,
          [["ok", function() {
            if (::check_balance_msgBox(cost))
              decoratorType.buyFunc(unitName, decoratorId, cost, @() null)
          }],
          ["cancel", function() {} ]], "ok")
  }

  function onBtnMarketplaceFindCoupon(obj)
  {
    local decorator = getDecoratorConfig()?.decorator
    local item = ::ItemsManager.findItemById(decorator?.getCouponItemdefId())
    if (!(item?.hasLink() ?? false))
      return
    item.openLink()
  }

  function onBtnMarketplaceConsumeCoupon(obj)
  {
    local decorator = getDecoratorConfig()?.decorator
    local inventoryItem = ::ItemsManager.getInventoryItemById(decorator?.getCouponItemdefId())
    if (!(inventoryItem?.canConsume() ?? false))
      return

    inventoryItem.consume(@(result) null, null)
  }
}

::gui_handlers.collectionsWnd <- collectionsWnd

return {
  openCollectionsWnd = @() ::handlersManager.loadHandler(collectionsWnd)
  hasAvailableCollections = @() ::has_feature("Collection") && getCollectionsList().len() > 0
}