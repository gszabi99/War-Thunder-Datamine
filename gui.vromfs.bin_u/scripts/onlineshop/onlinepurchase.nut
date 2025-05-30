from "%scripts/dagui_natives.nut" import yuplay2_get_payment_methods, yuplay2_buy_entitlement, update_entitlements
from "%scripts/dagui_library.nut" import *
let { showGuestEmailRegistration, needShowGuestEmailRegistration } = require("%scripts/user/suggestionEmailRegistration.nut")
let { format } = require("string")
let { steam_is_running } = require("steam")
let { doBrowserPurchase } = require("%scripts/onlineShop/onlineShopModel.nut")
let { openPaymentWnd } = require("%scripts/paymentHandler.nut")
let { getEntitlementName } = require("%scripts/onlineShop/entitlements.nut")
let { bundlesShopInfo } = require("%scripts/onlineShop/entitlementsInfo.nut")
let { get_yu2_error_text } = require("%scripts/utils/errorMsgBox.nut")
let { getCurCircuitOverride } = require("%appGlobals/curCircuitOverride.nut")

let payMethodsCfg = [
  
  
  { id = YU2_PAY_PAYPAL,      name = "paypal" }
  { id = YU2_PAY_WEBMONEY,    name = "webmoney" }
  { id = YU2_PAY_AMAZON,      name = "amazon" }
  { id = YU2_PAY_GJN,         getName = @() getCurCircuitOverride("coinsName", "gjncoins") }
]

function doYuplayPurchase(product, payMethod) {
  let guid = bundlesShopInfo.value?[product.name].guid ?? ""
  if (guid == "")
    logerr($"Error: not found guid for {product.name}")

  let response = (guid == "") ? -1 : yuplay2_buy_entitlement(guid, payMethod)
  if (response != YU2_OK) {
    let errorText = get_yu2_error_text(response)
    scene_msg_box("errorMessageBox", get_cur_gui_scene(), errorText, [["ok", function() {}]], "ok")
    log($"yuplay2_buy_entitlement have returned {response} with task = {product.name}, guid = {guid}, payMethod = {payMethod}")
    return
  }

  update_entitlements()

  scene_msg_box("purchase_done", get_cur_gui_scene(),
    format(loc("userlog/buy_entitlement"), getEntitlementName(product)),
    [["ok", @() null]], "ok", { cancel_fn = @() null })
}

function onYuplayPurchase(product, payMethod, nameLocId) {
  let msgText = loc("onlineShop/needMoneyQuestion/onlinePaymentSystem", {
    purchase = colorize("activeTextColor", getEntitlementName(product)),
    paymentSystem = colorize("userlogColoredText", loc(nameLocId))
  })
  scene_msg_box("yuplay_purchase_ask", get_cur_gui_scene(), msgText,
    [ ["yes", @() doYuplayPurchase(product, payMethod) ],
      ["no", function() {}]
    ], "yes", { cancel_fn = function() {} })
}

function onOnlinePurchase(product) {
  if (needShowGuestEmailRegistration()) {
    showGuestEmailRegistration()
    return
  }

  if (steam_is_running() || !hasFeature("PaymentMethods"))
    return doBrowserPurchase(product.name)

  let payMethods = yuplay2_get_payment_methods()
  if (!payMethods)
    return doBrowserPurchase(product.name)

  let items = []
  foreach (method in payMethodsCfg)
    if ((payMethods & method.id)) {
      let payMethodId = method.id
      let metodName = method?.getName() ?? method.name
      let name = $"yuNetwork/payMethod/{metodName}"
      items.append({
        name
        icon = $"!#ui/gameuiskin/payment_{metodName}.svg"
        callback = @() onYuplayPurchase(product, payMethodId, name)
      })
    }

  let name = "yuNetwork/payMethod/other"
  items.append({
    name
    icon = ""
    callback = @() doBrowserPurchase(product.name)
  })

  openPaymentWnd({ items = items, cancel_fn = function() {} })
}

return {
  onOnlinePurchase
}