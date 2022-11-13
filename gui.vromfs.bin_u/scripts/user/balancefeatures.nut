from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let hasMultiplayerRestritionByBalance =@() ::get_cur_rank_info().gold < 0

let function isShowGoldBalanceWarning() {
  if (!hasMultiplayerRestritionByBalance())
    return false

  ::update_entitlements_limited()
  let cancelBtnText = ::isInMenu() ? "cancel" : "ok"
  local defButton = cancelBtnText
  let buttons = [[cancelBtnText, @() null]]

  if (::isInMenu()) {
    let purchaseBtn = "#mainmenu/btnBuy"
    defButton = purchaseBtn
    buttons.insert(0, [purchaseBtn,
      @() ::OnlineShopModel.launchOnlineShop(null, "eagles", null, "buy_gold_msg")])
  }

  ::scene_msg_box("no_money", null, loc("revoking_fraudulent_purchases"), buttons, defButton)
  return true
}

return {
  hasMultiplayerRestritionByBalance
  isShowGoldBalanceWarning
}