from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
require("%scripts/onlineShop/ingameConsoleStore.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let statsd = require("statsd")
let { isPlayerRecommendedEmailRegistration } = require("%scripts/user/countryUtils.nut")
let { showPcStorePromo } = require("%scripts/user/pcStorePromo.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { addTask } = require("%scripts/tasker.nut")
let { updateEntitlementsLimited } = require("%scripts/onlineShop/entitlementsUpdate.nut")
let { updateGamercards } = require("%scripts/gamercard/gamercard.nut")
let { updateOnlineShopDiscounts } = require("%scripts/discounts/discounts.nut")

gui_handlers.XboxShop <- class (gui_handlers.IngameConsoleStore) {
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
}