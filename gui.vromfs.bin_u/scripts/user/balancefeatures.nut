from "%scripts/dagui_natives.nut" import get_cur_rank_info
from "%scripts/dagui_library.nut" import *

let { isInMenu } = require("%scripts/clientState/clientStates.nut")
let { launchOnlineShop } = require("%scripts/onlineShop/onlineShopModel.nut")
let { get_gui_balance, hasMultiplayerRestritionByBalance } = require("%scripts/user/balance.nut")
let { updateEntitlementsLimited } = require("%scripts/onlineShop/entitlementsUpdate.nut")

function isShowGoldBalanceWarning() {
  if (!hasMultiplayerRestritionByBalance())
    return false

  updateEntitlementsLimited()
  let cancelBtnText = isInMenu.get() ? "cancel" : "ok"
  local defButton = cancelBtnText
  let buttons = [[cancelBtnText, @() null]]

  if (isInMenu.get()) {
    let purchaseBtn = "#mainmenu/btnBuy"
    defButton = purchaseBtn
    buttons.insert(0, [purchaseBtn,
      @() launchOnlineShop(null, "eagles", null, "buy_gold_msg")])
  }

  scene_msg_box("no_money", null, loc("revoking_fraudulent_purchases"), buttons, defButton)
  return true
}

function checkBalanceMsgBox(cost, afterCheck = null, silent = false) {
  if (cost.isZero())
    return true

  let balance = get_gui_balance()
  local text = null
  local isGoldNotEnough = false
  if (cost.wp > 0 && balance.wp < cost.wp)
    text = loc("not_enough_warpoints")
  if (cost.gold > 0 && balance.gold < cost.gold) {
    text = loc("not_enough_gold")
    isGoldNotEnough = true
    updateEntitlementsLimited()
  }

  if (!text)
    return true
  if (silent)
    return false

  let cancelBtnText = isInMenu.get() ? "cancel" : "ok"
  local defButton = cancelBtnText
  let buttons = [[cancelBtnText,  function() { if (afterCheck) afterCheck (); } ]]
  local shopType = ""
  if (isGoldNotEnough && hasFeature("EnableGoldPurchase"))
    shopType = "eagles"
  else if (!isGoldNotEnough && hasFeature("SpendGold"))
    shopType = "warpoints"

  if (isInMenu.get() && shopType != "") {
    let purchaseBtn = "#mainmenu/btnBuy"
    defButton = purchaseBtn
    buttons.insert(0, [purchaseBtn, @() launchOnlineShop(null, shopType, afterCheck, "buy_gold_msg")])
  }

  scene_msg_box("no_money", null, text, buttons, defButton)
  return false
}

return {
  isShowGoldBalanceWarning
  checkBalanceMsgBox
}