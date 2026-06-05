from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")

require("ingameConsoleStore.nut")

gui_handlers.EpicShop <- class (gui_handlers.IngameConsoleStore) {
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
}