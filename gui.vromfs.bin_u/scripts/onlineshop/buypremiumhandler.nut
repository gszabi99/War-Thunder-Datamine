from "%scripts/dagui_natives.nut" import  get_entitlement_cost_gold, purchase_entitlement, is_online_available, set_char_cb
from "%scripts/dagui_library.nut" import *
from "app" import isAppActive

let { floor } = require("math")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { topMenuHandler } = require("%scripts/mainmenu/topMenuStates.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { getShopPriceBlk } = require("%scripts/onlineShop/onlineShopState.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getEntitlementDescription, getEntitlementName, getPricePerEntitlement, getEntitlementPriceFloat,
  getEntitlementAmount, getEntitlementFullTimeText, getEntitlementPrice } = require("%scripts/onlineShop/entitlements.nut")
let time = require("%scripts/time.nut")
let { Cost } = require("%scripts/money.nut")
let { warningIfGold } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { checkBalanceMsgBox } = require("%scripts/user/balanceFeatures.nut")
let purchaseConfirmation = require("%scripts/purchase/purchaseConfirmationHandler.nut")
let { addTask } = require("%scripts/tasker.nut")
let { ENTITLEMENTS_PRICE } = require("%scripts/utils/configs.nut")
let { bundlesShopInfo } = require("%scripts/onlineShop/entitlementsInfo.nut")
let { onOnlinePurchase } = require("%scripts/onlineShop/onlinePurchase.nut")
let { steam_is_overlay_active } = require("steam")
let { is_builtin_browser_active } = require("%scripts/onlineShop/browserWndHelpers.nut")
let { updateEntitlementsLimited } = require("%scripts/onlineShop/entitlementsUpdate.nut")
let { getRemainingPremiumTime } = require("%scripts/user/premium.nut")
let { updateGamercards } = require("%scripts/gamercard/gamercard.nut")

const MIN_DISPLAYED_PERCENT_SAVING = 5

let getRatioCoeff = @(num) num == "1" ? 41.0/150 : 76.0/150

gui_handlers.BuyPremiumHandler <- class (gui_handlers.BaseGuiHandlerWT) {
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
    let msgText = warningIfGold(
      loc("onlineShop/needMoneyQuestion",
        { purchase = getEntitlementName(this.product), cost = price.getTextAccordingToBalance() }),
      price)

    let onCallbackYes = Callback(function() {
      if (checkBalanceMsgBox(price))
        this.goForwardIfPurchase(this.product)
    }, this)
    purchaseConfirmation("purchase_ask", msgText, onCallbackYes)
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
}
