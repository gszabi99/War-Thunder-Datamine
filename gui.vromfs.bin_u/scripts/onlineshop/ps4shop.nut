from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
require("ingameConsoleStore.nut")
let DataBlock = require("DataBlock")
let statsd = require("statsd")
let psnStore = require("sony.store")
let psnSystem = require("sony.sys")
let { getShopData, getShopItem } = require("%scripts/onlineShop/ps4ShopData.nut")
let { ENTITLEMENTS_PRICE } = require("%scripts/utils/configs.nut")
let { isPlayerRecommendedEmailRegistration } = require("%scripts/user/countryUtils.nut")
let { showPcStorePromo } = require("%scripts/user/pcStorePromo.nut")
let { updateOnlineShopDiscounts } = require("%scripts/discounts/discounts.nut")

gui_handlers.Ps4Shop <- class (gui_handlers.IngameConsoleStore) {
  needWaitIcon = true
  isLoadingInProgress = false

  function initScreen() {
    if (this.canDisplayStoreContents()) {
      psnStore.show_icon(psnStore.IconPosition.LEFT)
      base.initScreen()
      statsd.send_counter("sq.ingame_store.contents", 1, { callsite = "init_screen", status = "ok" })
      return
    }

    statsd.send_counter("sq.ingame_store.contents", 1, { callsite = "init_screen", status = "empty" })
    this.goBack()
  }

  function loadCurSheetItemsList() {
    this.itemsList = []
    let itemsLinks = getShopData().getBlockByName(this.curSheet?.categoryId ?? "")?.links ?? DataBlock()
    for (local i = 0; i < itemsLinks.blockCount(); i++) {
      let itemId = itemsLinks.getBlock(i).getBlockName()
      let block = getShopItem(itemId)
      if (block)
        this.itemsList.append(block)
      else
        log($"PS4: Ingame Shop: Skip missing info of item {itemId}")
    }
  }

  function afterModalDestroy() {
    psnStore.hide_icon()
  }

  function onDestroy() {
    psnStore.hide_icon()
  }

  function canDisplayStoreContents() {
    let isStoreEmpty = !this.isLoadingInProgress && !this.itemsCatalog.len()
    if (isStoreEmpty)
      psnSystem.show_message(psnSystem.Message.EMPTY_STORE, "", {})
    return !isStoreEmpty
  }

  function onEventPS4ShopSheetsInited(p) {
    this.isLoadingInProgress = p?.isLoadingInProgress ?? false
    if (!this.canDisplayStoreContents()) {
      statsd.send_counter("sq.ingame_store.contents", 1,
        { callsite = "on_event_shop_sheets_inited", status = "empty" })
      this.goBack()
      return
    }
    statsd.send_counter("sq.ingame_store.contents", 1,
      { callsite = "on_event_shop_sheets_inited", status = "ok" })

    this.fillItemsList()
    this.updateItemInfo()
  }

  function onEventPS4IngameShopUpdate(_p) {
    this.curItem = this.getCurItem()
    let wasBought = this.curItem?.isBought
    this.curItem?.updateIsBoughtStatus()
    if (wasBought != this.curItem?.isBought)
      ENTITLEMENTS_PRICE.checkUpdate()

    this.updateSorting()
    this.fillItemsList()
    updateOnlineShopDiscounts()

    if (isPlayerRecommendedEmailRegistration())
      showPcStorePromo()
  }

  function onEventSignOut(_p) {
    psnStore.hide_icon()
  }
}