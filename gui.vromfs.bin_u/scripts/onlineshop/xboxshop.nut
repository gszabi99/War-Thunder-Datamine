import "statsd" as statsd
from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/onlineShop/ingameConsoleStore.nut" import IngameConsoleStore
from "%scripts/user/countryUtils.nut" import isPlayerRecommendedEmailRegistration
from "%scripts/user/pcStorePromo.nut" import showPcStorePromo
from "%scripts/bqQueue/bqQueue.nut" import sendBqEvent
from "%scripts/tasker.nut" import addTask
from "%scripts/onlineShop/entitlementsUpdate.nut" import updateEntitlementsLimited
from "%scripts/gamercard/gamercard.nut" import updateGamercards
from "%scripts/discounts/discounts.nut" import updateOnlineShopDiscounts
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "%scripts/dagui_library.nut" import *

register_gui_handler("XboxShop", class (IngameConsoleStore) {
  function loadCurSheetItemsList() {
    this.itemsList = this.itemsCatalog?[this.curSheet?.categoryId] ?? []
  }

  function onEventXboxSystemUIReturn(_p) {
    if (isPlayerRecommendedEmailRegistration())
      showPcStorePromo()

    this.curItem = this.getCurItem()
    if (!this.curItem)
      return

    let wasItemBought = this.curItem.isBought
    this.curItem.updateIsBoughtStatus(Callback(function(success) {

      let wasPurchasePerformed = success && (wasItemBought != this.curItem.isBought)

      if (wasPurchasePerformed) {
        broadcastEvent("EntitlementStoreItemPurchased", { id = this.curItem.id })
        statsd.send_counter("sq.close_product.purchased", 1)
        sendBqEvent("CLIENT_POPUP_1", "close_product", {
          itemId = this.curItem.id,
          action = "purchased"
        })
        addTask(updateEntitlementsLimited(),
          {
            showProgressBox = true
            progressBoxText = loc("charServer/checking")
          },
          Callback(function() {
            this.updateSorting()
            this.fillItemsList()
            updateOnlineShopDiscounts()

            if (this.curItem.isMultiConsumable || wasPurchasePerformed)
              updateGamercards()
          }, this)
        )
      }

    }, this))
  }

  function goBack() {
    addTask(updateEntitlementsLimited(),
      {
        showProgressBox = true
        progressBoxText = loc("charServer/checking")
      },
      Callback(function() {
        updateOnlineShopDiscounts()
        updateGamercards()
      })
    )

    base.goBack()
  }
})