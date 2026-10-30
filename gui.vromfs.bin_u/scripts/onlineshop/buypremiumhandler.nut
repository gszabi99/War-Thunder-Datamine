import "%scripts/time.nut" as time
from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/mainmenu/topMenuStates.nut" import topMenuHandler
from "%sqStdLibs/helpers/handyman.nut" import handyman
from "%scripts/onlineShop/onlineShopState.nut" import getShopPriceBlk
from "%scripts/onlineShop/entitlements.nut" import getEntitlementDescription, getEntitlementName, getPricePerEntitlement, getEntitlementPriceFloat, getEntitlementAmount, getEntitlementFullTimeText, getEntitlementPrice
from "%scripts/money.nut" import Cost
from "%scripts/viewUtils/objectTextUpdate.nut" import warningIfGold
from "%scripts/user/balanceFeatures.nut" import checkBalanceMsgBox
from "%scripts/purchase/purchaseConfirmationHandler.nut" import purchaseConfirmation
from "%scripts/tasker.nut" import addTask
from "%scripts/onlineShop/entitlementsInfo.nut" import bundlesShopInfo
from "%scripts/onlineShop/onlinePurchase.nut" import onOnlinePurchase
from "%scripts/onlineShop/browserWndHelpers.nut" import is_builtin_browser_active
from "%scripts/onlineShop/entitlementsUpdate.nut" import updateEntitlementsLimited
from "%scripts/user/premium.nut" import getRemainingPremiumTime
from "%scripts/gamercard/gamercard.nut" import updateGamercards
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "math" import floor
from "steam" import steam_is_overlay_active
from "%scripts/dagui_natives.nut" import get_entitlement_cost_gold, purchase_entitlement, is_online_available, set_char_cb
from "%scripts/dagui_library.nut" import *
from "app" import isAppActive

let { ENTITLEMENTS_PRICE } = require("%scripts/utils/configs.nut")

const MIN_DISPLAYED_PERCENT_SAVING = 5

let getRatioCoeff = @(num) num == "1" ? 41.0/150 : 76.0/150

register_gui_handler("BuyPremiumHandler", class (BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/premium/buyPremiumWnd.blk"
  owner = null
  afterCloseFunc = null
  needFullUpdate = false

  goods = []
  product = null
  lastExpire = null

  function initScreen() {
    ENTITLEMENTS_PRICE.checkUpdate(
      Callback(function() {
        this.reinitScreen()
      }, this)
      Callback(function(_result) { this.reinitScreen() }, this)
      true
    )
    this.reinitScreen()
    this.scene.findObject("premiumTimer").setUserData(this)
  }

  function reinitScreen(_params = null) {
    this.updatePremiumShopData()
    this.updateCurrentPremiumInfo()
  }

  function updatePremiumShopData() {
    let chapter = hasFeature("PremiumSubscription") ? "premium_subscription" : "premium"
    this.goods.clear()
    let blk = getShopPriceBlk()
    let numBlocks = blk.blockCount()
    local groupCost = null

    for (local i = 0; i < numBlocks; i++) {
      let ib = blk.getBlock(i)
      let name = ib.getBlockName()
      if (ib?.chapter != chapter)
        continue

      let item = { name }

      for (local j = 0; j < ib.paramCount(); j++) {
        let paramName = ib.getParamName(j)
        if (!(paramName in item))
          item[paramName] <- ib.getParamValue(j)
      }

      local savings = 0
      if (item?.onlinePurchase ?? false) {
        let productInfo = bundlesShopInfo.get()?[item.name]
        let discount_mul = productInfo?.discount_mul ?? 1
        savings = ((1.0 - discount_mul) * 100).tointeger()
      }
      else {
        let itemCost = getEntitlementPriceFloat(item)
        if (groupCost == null)
          groupCost = getPricePerEntitlement(item)
        let amount = getEntitlementAmount(item)
        savings = ((1 - (itemCost / (amount * groupCost))) * 100).tointeger()
      }
      item.savings <- (savings >= MIN_DISPLAYED_PERCENT_SAVING) ? savings : 0
      this.goods.append(item)
    }

    let items = this.goods.map(function(item) {
      local amount = getEntitlementAmount(item)
      if (amount < 1)
        amount = floor(amount * 24 + 0.5).tointeger()
      amount = amount.tostring()

      let digits = []
      for (local i = 0; i < amount.len(); i++) {
        let digit = amount.slice(i, i + 1)
        digits.append({
          digit
          ratioCoeff = getRatioCoeff(digit)
        })
      }

      let discount = item?.goldDiscount ?? 0

      return {
        name = item.name
        digits
        premiumCost = getEntitlementPrice(item)
        savings = (item.savings > 0) ? loc("charServer/entitlement/discount/short", { savings = item.savings }) : ""
        days = getEntitlementFullTimeText(item)
        isOnlinePurchase = item?.onlinePurchase ?? false
        hasDiscount = discount > 0
        discount = $"-{discount}%"
      }
    })

    let data = handyman.renderCached("%gui/premium/premiumItem.tpl", { items })
    let premiumListObj = this.scene.findObject("premiumList")
    this.guiScene.replaceContentFromText(premiumListObj, data, data.len(), this)

    if (this.goods.len() == 0)
      return
    let descText = getEntitlementDescription(this.goods[0], this.goods[0].name)
    let premiumInfoTextObj = this.scene.findObject("premiumInfoText")
    premiumInfoTextObj.setValue(descText)

    this.guiScene.applyPendingChanges(true)
    this.scene.findObject("separator")["height"] = max(premiumListObj.getSize()[1], premiumInfoTextObj.getSize()[1])
  }

  function updateCurrentPremiumInfo(_obj = null, _dt = null) {
    let expire = getRemainingPremiumTime()
    if (this.lastExpire == expire)
      return
    this.lastExpire = expire
    let premiumInfoObj = this.scene.findObject("premiumInfoHeader")
    let headerImageObj = premiumInfoObj.findObject("headerImage")
    let premiumExpiredTextObj = premiumInfoObj.findObject("premiumExpiredText")
    let lastPremiumDaysTextObj = premiumInfoObj.findObject("lastPremiumDaysText")

    if (expire > 0) {
      headerImageObj["background-image"] = "!ui/images/premium/premium_account_header"
      headerImageObj["width"] = "717@sf/@pf"
      premiumExpiredTextObj.setValue(loc("shop/premiumAccountActive"))
      lastPremiumDaysTextObj.setValue(time.getExpireText(expire))
    }
    else {
      headerImageObj["background-image"] = "!ui/images/premium/premium_account_header_inactive"
      headerImageObj["width"] = "593@sf/@pf"
      premiumExpiredTextObj.setValue(loc("shop/premiumAccountInactive"))
      lastPremiumDaysTextObj.setValue("")
    }
  }

  function afterModalDestroy() {
    topMenuHandler.get()?.updateExpAndBalance.call(topMenuHandler.get())
    this.popCloseFunc()
  }

  function popCloseFunc() {
    if (!this.afterCloseFunc)
      return
    this.afterCloseFunc()
    this.afterCloseFunc = null
  }

  function onDestroy() {
    this.popCloseFunc()
  }

  function onEventOnlineShopPurchaseSuccessful(_p) {
    this.updatePremiumShopData()
    this.updateCurrentPremiumInfo()
  }

  function onShopBuy(obj) {
    this.product = this.goods.findvalue(@(v) v.name == obj["premiumName"])
    if (this.product == null)
      return
    onOnlinePurchase(this.product)
  }

  function onBuy(obj) {
    let productId = obj["premiumName"]
    this.product = this.goods.findvalue(@(v) v.name == productId)
    if (this.product == null)
      return

    let price = Cost(0, get_entitlement_cost_gold(productId))
    let text = warningIfGold(
      loc("onlineShop/needMoneyQuestion",
        { purchase = getEntitlementName(this.product), cost = price.getTextAccordingToBalance() }),
      price)

    let callbackYes = Callback(
      @() checkBalanceMsgBox(price)
            ? this.goForwardIfPurchase(this.product)
            : null,
      this
    )
    purchaseConfirmation({ id = "purchase_ask", text, callbackYes }, price)
  }

  function goForwardIfPurchase(product) {
    let taskId = purchase_entitlement(product.name)
    let taskOptions = { showProgressBox = true }
    let taskSuccessCallback = Callback(function () {
      broadcastEvent("OnlineShopPurchaseSuccessful", { purchData = product })
      }, this)
    addTask(taskId, taskOptions, taskSuccessCallback)
  }

  function updateEntitlements() {
    if (!isAppActive() || steam_is_overlay_active() || is_builtin_browser_active())
      this.needFullUpdate = true
    else if (this.needFullUpdate && is_online_available()) {
      this.needFullUpdate = false
      this.taskId = updateEntitlementsLimited()
      if (this.taskId < 0)
        return

      set_char_cb(this, this.slotOpCb)
      this.showTaskProgressBox(loc("charServer/checking"))
      this.afterSlotOp = function() {
        if (!checkObj(this.scene))
          return
        broadcastEvent("EntitlementsUpdatedFromOnlineShop")
        this.reinitScreen()
        updateGamercards()
        broadcastEvent("OnlineShopPurchaseSuccessful", { purchData = this.product ?? {} })
      }
    }
  }

  function onTimer(_obj, _dt) {
    this.updateCurrentPremiumInfo()
    this.updateEntitlements()
  }
})
