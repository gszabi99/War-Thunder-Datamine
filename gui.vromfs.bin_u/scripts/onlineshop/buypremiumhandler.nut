from "%scripts/dagui_natives.nut" import  get_entitlement_cost_gold, entitlement_expires_in, purchase_entitlement, shop_get_premium_account_ent_name
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { topMenuHandler } = require("%scripts/mainmenu/topMenuStates.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { getShopPriceBlk } = require("%scripts/onlineShop/onlineShopState.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getEntitlementDescription, getEntitlementName, getPricePerEntitlement,
  getEntitlementAmount, getEntitlementFullTimeText } = require("%scripts/onlineShop/entitlements.nut")
let time = require("%scripts/time.nut")
let { Cost } = require("%scripts/money.nut")
let { warningIfGold } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { checkBalanceMsgBox } = require("%scripts/user/balanceFeatures.nut")
let purchaseConfirmation = require("%scripts/purchase/purchaseConfirmationHandler.nut")
let { addTask } = require("%scripts/tasker.nut")
let { ENTITLEMENTS_PRICE } = require("%scripts/utils/configs.nut")

const MIN_DISPLAYED_PERCENT_SAVING = 5

let getRatioCoeff = @(num) num == "1" ? 41.0/150 : 76.0/150

gui_handlers.BuyPremiumHandler <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/premium/buyPremiumWnd.blk"
  owner = null
  afterCloseFunc = null

  goods = []
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

  function reinitScreen() {
    this.updatePremiumShopData()
    this.updateCurrentPremiumInfo()
  }

  function updatePremiumShopData() {
    this.goods.clear()
    let blk = getShopPriceBlk()
    let numBlocks = blk.blockCount()
    local groupCost = null

    for (local i = 0; i < numBlocks; i++) {
      let ib = blk.getBlock(i)
      let name = ib.getBlockName()
      if (ib?.chapter != "premium")
        continue

      let item = { name }

      for (local j = 0; j < ib.paramCount(); j++) {
        let paramName = ib.getParamName(j)
        if (!(paramName in item))
          item[paramName] <- ib.getParamValue(j)
      }

      if (groupCost == null)
        groupCost = getPricePerEntitlement(item)

      let amount = getEntitlementAmount(item)
      let savings = ((1 - (item.goldCost / (amount * groupCost))) * 100).tointeger()
      item.savings <- (savings >= MIN_DISPLAYED_PERCENT_SAVING) ? savings : 0
      this.goods.append(item)
    }

    let items = this.goods.map(function(item) {
      let amount = getEntitlementAmount(item).tostring()
      let digits = []
      for (local i = 0; i < amount.len(); i++) {
        let digit = amount.slice(i, i + 1)
        digits.append({
          digit
          ratioCoeff = getRatioCoeff(digit)
        })
      }
      return {
        name = item.name
        digits
        premiumCost = Cost(0, item.goldCost)
        savings = (item.savings > 0) ? loc("charServer/entitlement/discount/short", { savings = item.savings }) : ""
        days = getEntitlementFullTimeText(item)
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
    let expire = entitlement_expires_in(shop_get_premium_account_ent_name())
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
    topMenuHandler.value?.updateExpAndBalance.call(topMenuHandler.value)
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

  function onBuy(obj) {
    let productId = obj["premiumName"]
    let product = this.goods.findvalue(@(v) v.name == productId)
    if (product == null)
      return

    let price = Cost(0, get_entitlement_cost_gold(productId))
    let msgText = warningIfGold(
      loc("onlineShop/needMoneyQuestion",
        { purchase = getEntitlementName(product), cost = price.getTextAccordingToBalance() }),
      price)

    let onCallbackYes = Callback(function() {
      if (checkBalanceMsgBox(price))
        this.goForwardIfPurchase(product)
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
}
