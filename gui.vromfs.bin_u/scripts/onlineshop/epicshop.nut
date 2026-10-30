from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/onlineShop/ingameConsoleStore.nut" import IngameConsoleStore
from "%scripts/dagui_library.nut" import *

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