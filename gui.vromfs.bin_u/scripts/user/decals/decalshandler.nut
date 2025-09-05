from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getCachedDataByType } = require("%scripts/customization/decorCache.nut")
let { decoratorTypes } = require("%scripts/customization/types.nut")
let { toggleUnlockFavButton, initUnlockFavInContainer } = require("%scripts/unlocks/favoriteUnlocks.nut")
let { getUnlockCondsDescByCfg, getUnlockMultDescByCfg, getUnlockMainCondDescByCfg,
  buildConditionsConfig, buildUnlockDesc } = require("%scripts/unlocks/unlocksViewModule.nut")
let { canStartPreviewScene, useDecorator, showDecoratorAccessRestriction,
  getDecoratorDataToUse } = require("%scripts/customization/contentPreview.nut")
let { setTimeout, clearTimer } = require("dagor.workcycle")
let { utf8ToLower } = require("%sqstd/string.nut")
let { initTree } = require("%scripts/user/skins/decoratorGroupsTree.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings } = require("%scripts/clientState/localProfile.nut")
let { canGetDecoratorFromTrophy } = require("%scripts/items/itemsManagerGetters.nut")
let { isInMenu } = require("%scripts/clientState/clientStates.nut")
let { canDoUnlock } = require("%scripts/unlocks/unlocksModule.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { placePriceTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { isCollectionItem } = require("%scripts/collections/collections.nut")
let { askPurchaseDecorator, askConsumeDecoratorCoupon,
  findDecoratorCouponOnMarketplace } = require("%scripts/customization/decoratorAcquire.nut")
let { getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { isProfileReceived } = require("%appGlobals/login/loginState.nut")

const SELECTED_DECAL_SAVE_ID = "wnd/selectedDecal"

function filterDecalsListFunc(decal, nameFilter) {
  if (nameFilter != "") {
    let hasSubstring = (decal.searchId.indexof(nameFilter) != null) ||
    decal.searchName.indexof(nameFilter) != null
    if (!hasSubstring)
      return false
  }
  return true
}

local DecalsHandler = class (gui_handlers.BaseGuiHandlerWT) {
  wndType          = handlerType.CUSTOM
  sceneBlkName     = "%gui/profile/decalsPage.blk"

  parent = null
  openParams = null
  treeHandlerWeak = null
  decalsCache = null
  totalReceived = 0
  applyFilterTimer = null
  decalNameFilter = ""
  selectedCategory = ""
  selectedDecal = ""

  function initScreen() {
    this.prepareDecals()
    this.updateTotalReceived()
    this.loadSelectedDecal()
    this.applyOpenParams()
    this.createDecalsTree()
    this.updateDecalsTree()
  }

  function applyOpenParams() {
    if (this.openParams == null)
      return

    let { initCategory } = this.openParams
    if (initCategory == "")
      return

    this.selectedCategory = initCategory
    this.selectedDecal = ""
  }

  function applyDecalFilter(obj) {
    clearTimer(this.applyFilterTimer)
    this.decalNameFilter = obj.getValue()
    if(this.decalNameFilter == "") {
      this.updateDecalsTree()
      return
    }

    let applyCallback = Callback(@() this.updateDecalsTree(), this)
    this.applyFilterTimer = setTimeout(0.8, @() applyCallback())
  }

  function updateTotalReceived() {
    let totalReceivedObj = this.scene.findObject("total_received")
    totalReceivedObj.setValue(loc("profile/decals/totalReceived", { count = this.totalReceived }))
  }

  function onFilterCancel(filterObj) {
    if (filterObj.getValue() != "")
      filterObj.setValue("")
    else if (this.parent != null)
      this.guiScene.performDelayed(this.parent, this.parent.goBack)
  }

  function prepareDecals() {
    if (this.decalsCache != null)
      return
    this.totalReceived = 0
    this.decalsCache = []
    let decoratorsList = getCachedDataByType(decoratorTypes.DECALS).decoratorsList

    foreach (decalId, decal in decoratorsList) {
      if (!decal.isVisible())
        continue
      this.decalsCache.append({
        searchId = utf8ToLower(decalId)
        searchName = utf8ToLower(decal.getName())
        decal
        category = decal.category
        group = decal.group != "" ? decal.group : "other"
      })

      if (decoratorTypes.DECALS.isPlayerHaveDecorator(decalId))
        this.totalReceived++
    }
  }

  function prepareDecalsTreeData() {
    let decorCache = getCachedDataByType(decoratorTypes.DECALS)
    let treeData = []
    foreach (category in decorCache.categories) {
      let groups = decorCache.catToGroupNames[category]
      let isNoGroups = groups.len() == 1 && groups[0] == "other"
      treeData.append({
        id = category
        itemTag = "campaign_item"
        itemText = $"#decals/category/{category}"
        isCollapsable = !isNoGroups
        hidden = false
        isNoGroups
      })

      if (isNoGroups)
        continue

      foreach (group in groups) {
        treeData.append({
          id = $"{category}/{group}"
          itemText = $"#decals/group/{group}"
          hidden = false
        })
      }
    }
    return treeData
  }

  function createDecalsTree() {
    this.treeHandlerWeak = initTree({
      scene = this.scene.findObject("treeDecalsNest")
      treeData = this.prepareDecalsTreeData()
      selectCallback = Callback(@(id) this.onDecalsCategorySelect(id), this)
      prevSelected = this.selectedCategory
    })
  }

  function updateDecalsTree() {
    let nameFilter = utf8ToLower(this.decalNameFilter)
    let filteredDecals = this.decalsCache.filter(@(decal) filterDecalsListFunc(decal, nameFilter))
    this.showContent(filteredDecals.len() > 0)
    if (filteredDecals.len() == 0)
      return

    let treeData = []

    foreach (decal in filteredDecals) {
      let { category, group } = decal
      if (!treeData.contains(category))
        treeData.append(category)

      let groupId = $"{category}/{group}"
      if (!treeData.contains(groupId))
        treeData.append(groupId)
    }
    this.treeHandlerWeak?.update(treeData)
  }

  function onDecalsCategorySelect(id) {
    this.selectedCategory = id
    let decalsListObj = this.scene.findObject("decals_zone")
    let [categoryId, groupId = "other"] = this.selectedCategory.split("/")
    let items = this.getDecalsView(categoryId, groupId)

    let decalId = this.selectedDecal
    let markup = handyman.renderCached("%gui/commonParts/imgFrame.tpl", { items })
    this.guiScene.replaceContentFromText(decalsListObj, markup, markup.len(), this)

    let selectedDecalIndex = items.findindex(@(v) v.id == decalId) ?? 0

    if (decalsListObj.getValue() != selectedDecalIndex)
      decalsListObj.setValue(selectedDecalIndex)
    else
      this.onDecalSelect(decalsListObj)

    this.saveSelectedDecal()
  }

  function getDecalsView(categoryId, groupId) {
    let nameFilter = utf8ToLower(this.decalNameFilter)
    let decals = this.decalsCache.filter(@(v) (v.category == categoryId && v.group == groupId && filterDecalsListFunc(v, nameFilter)))
    if (decals.len() == 0)
      return []

    return decals.map(function(v) {
      let decorator = v.decal
      let isLocked = !decorator.isUnlocked()
      local lockText = null
      local statusLock = isLocked ? "achievement" : null
      if (isLocked && (decorator.unlockBlk == null || decorator.unlockBlk?.hideUntilUnlocked == true))
        if (decorator.getCouponItemdefId() != null) {
          statusLock = "market"
        } else if (!decorator.getCost().isZero()) {
          statusLock = "gold"
          lockText = decorator.getCost().tostring()
        }

      return {
        id = decorator.id
        tooltipId = getTooltipType("DECORATION").getTooltipId(decorator.id, decorator.decoratorType.unlockedItemType)
        unlocked = true
        tag = "imgSelectable"
        image = decorator.decoratorType.getImage(decorator)
        imgRatio = decorator.decoratorType.getRatio(decorator)
        statusLock
        lockText
        imgClass = "profileMedals"
      }
    })
  }

  function onDecalSelect(obj) {
    let index = obj.getValue()
    if ((index < 0) || (index >= obj.childrenCount()))
      return
    let item = obj.getChild(index)
    let decalId = item.id
    this.selectedDecal = decalId
    let decal = this.getCurrentDecal()
    this.updateDecalInfo(decal)
    this.updateDecalButtons(decal)
    this.saveSelectedDecal()
    item.scrollToView()
  }

  function updateDecalInfo(decal) {
    let infoObj = showObjById("decal_info", decal != null, this.scene)
    if (!decal)
      return

    let img = decal.decoratorType.getImage(decal)
    let imgObj = infoObj.findObject("decalImage")
    imgObj["background-image"] = img

    let title = decal.getName()
    infoObj.findObject("decalTitle").setValue(title)

    let desc = decal.getDesc()
    infoObj.findObject("decalDesc").setValue(desc)

    let cfg = decal.unlockBlk != null
      ? buildUnlockDesc(buildConditionsConfig(decal.unlockBlk))
      : null

    let progressObj = infoObj.findObject("decalProgress")
    if (cfg != null) {
      let progressData = cfg.getProgressBarData()
      progressObj.show(progressData.show)
      if (progressData.show)
        progressObj.setValue(progressData.value)
    }
    else
      progressObj.show(false)

    infoObj.findObject("decalMainCond").setValue(getUnlockMainCondDescByCfg(cfg , { showSingleStreakCondText = true }))
    infoObj.findObject("decalMultDecs").setValue(getUnlockMultDescByCfg(cfg))
    infoObj.findObject("decalConds").setValue(getUnlockCondsDescByCfg(cfg))
    infoObj.findObject("decalPrice").setValue(this.getDecalObtainInfo(decal))
    infoObj.findObject("checkbox_favorites").unlockId = decal?.unlockId ?? ""
  }

  function updateDecalButtons(decal) {
    if (!decal) {
      showObjectsByTable(this.scene, {
        btn_buy_decorator              = false
        btn_fav                        = false
        btn_preview                    = false
        btn_use_decorator              = false
        btn_store                      = false
        btn_marketplace_consume_coupon = false
        btn_marketplace_find_coupon    = false
        btn_go_to_collection           = false
      })
      return
    }

    let canBuy = decal.canBuyUnlock(null)
    let canConsumeCoupon = !canBuy && decal.canGetFromCoupon(null)
    let canFindOnMarketplace = !canBuy && !canConsumeCoupon
      && decal.canBuyCouponOnMarketplace(null)
    let canFindInStore = !canBuy && !canConsumeCoupon && !canFindOnMarketplace
      && canGetDecoratorFromTrophy(decal)

    let containerObj = this.scene.findObject("page_content")
    let buyBtnObj = showObjById("btn_buy_decorator", canBuy, containerObj)
    if (canBuy && buyBtnObj?.isValid())
      placePriceTextToButton(containerObj, "btn_buy_decorator", loc("mainmenu/btnOrder"), decal.getCost())

    let canFav = !decal.isUnlocked() && canDoUnlock(decal.unlockBlk)

    showObjById("checkbox_favorites", canFav, containerObj)
    if (canFav)
      initUnlockFavInContainer(decal.unlockId, containerObj)

    let canUse = decal.isUnlocked() && canStartPreviewScene(false)
    let canPreview = !canUse && decal.canPreview()

    showObjectsByTable(this.scene, {
      btn_preview                    = isInMenu.get() && canPreview
      btn_use_decorator              = isInMenu.get() && canUse
      btn_store                      = isInMenu.get() && canFindInStore
      btn_go_to_collection           = isInMenu.get() && isCollectionItem(decal)
      btn_marketplace_consume_coupon = canConsumeCoupon
      btn_marketplace_find_coupon    = canFindOnMarketplace
    })
  }

  function getDecalObtainInfo(decor) {
    if (decor.isUnlocked())
      return ""

    if (decor.canBuyUnlock(null))
      return decor.getCostText()

    if (decor.canGetFromCoupon(null))
      return " ".concat(loc("currency/gc/sign/colored"),
        colorize("currencyGCColor", loc("shop/object/can_get_from_coupon")))

    if (decor.canBuyCouponOnMarketplace(null))
      return " ".concat(loc("currency/gc/sign/colored"),
        colorize("currencyGCColor", loc("shop/object/can_be_found_on_marketplace")))

    if (canGetDecoratorFromTrophy(decor))
      return loc("mainmenu/itemCanBeReceived")

    return ""
  }

  function unlockToFavorites(obj) {
    toggleUnlockFavButton(obj)
  }

  function saveSelectedDecal() {
    saveLocalAccountSettings(SELECTED_DECAL_SAVE_ID, {
      category = this.selectedCategory
      decal = this.selectedDecal
    })
  }

  function loadSelectedDecal() {
    let blk = loadLocalAccountSettings(SELECTED_DECAL_SAVE_ID)
    if (blk == null)
      return

    this.selectedCategory = blk?.category
    this.selectedDecal = blk?.decal
  }

  function onEventItemsShopUpdate(_) {
    this.onDecalsCategorySelect(this.selectedCategory)
  }

  function showContent(visible) {
    showObjById("content", visible, this.scene)
    showObjById("empty_text", !visible, this.scene)
  }

  function getCurrentDecal() {
    let decalId = this.selectedDecal
    return this.decalsCache.findvalue(@(v) v.decal.id == decalId)?.decal
  }

  function onBuyDecorator() {
    let decor = this.getCurrentDecal()
    if (!decor)
      return
    askPurchaseDecorator(decor, null)
  }

  function onDecalUse() {
    let decor = this.getCurrentDecal()
    if (!decor)
      return

    let resourceType = decor.decoratorType.resourceType
    let decorData = getDecoratorDataToUse(decor.id, resourceType)
    if (decorData.decorator == null) {
      showDecoratorAccessRestriction(decor, getPlayerCurUnit(), true)
      return
    }

    useDecorator(decor, decorData.decoratorUnit, decorData.decoratorSlot)
  }

  function onDecalPreview() {
    this.getCurrentDecal()?.doPreview()
  }

  function onMarketplaceFindCoupon() {
    findDecoratorCouponOnMarketplace(this.getCurrentDecal())
  }

  function onMarketplaceConsumeCoupon() {
    askConsumeDecoratorCoupon(this.getCurrentDecal(), null)
  }

  function onGotoCollection() {
    broadcastEvent("GotoCollection", this.getCurrentDecal().id)
  }

  function onEventUnlocksCacheInvalidate(_p) {
    if (!isProfileReceived.get())
      return
    this.initScreen()
  }

  function onEventInventoryUpdate(_p) {
      this.initScreen()
  }

}

gui_handlers.DecalsHandler <- DecalsHandler

return {
  openDecalsPage = @(params = {}) handlersManager.loadHandler(DecalsHandler, params)
}
