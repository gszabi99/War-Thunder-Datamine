from "%scripts/dagui_library.nut" import *

let { register_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { IngameConsoleStore } = require("%scripts/onlineShop/ingameConsoleStore.nut")

register_gui_handler("EpicShop", class (IngameConsoleStore) {
  needWaitIcon = true
  isLoadingInProgress = false

  function loadCurSheetItemsList() {
    this.itemsList = this.itemsCatalog?[this.curSheet.mediaType] ?? []
  }

  function onEventEpicShopItemUpdated(_p) {
    this.updateSorting()
    this.fillItemsList()
  }

  function onEventEpicShopDataUpdated(p) {
    this.isLoadingInProgress = p?.isLoadingInProgress ?? false
    this.fillItemsList()
    this.updateItemInfo()
  }
})