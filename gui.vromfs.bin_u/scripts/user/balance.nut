from "%scripts/dagui_natives.nut" import get_cur_rank_info, shop_get_free_exp
from "%scripts/dagui_library.nut" import *
let { Balance } = require("%scripts/money.nut")

function get_balance() {
  let info = get_cur_rank_info()
  return { wp = info.wp, gold = info.gold }
}

function get_gui_balance() {
  let info = get_cur_rank_info()
  return Balance(info.wp, info.gold, shop_get_free_exp())
}

let hasMultiplayerRestritionByBalance = @() get_cur_rank_info().gold < 0

return {
  get_balance
  get_gui_balance
  hasMultiplayerRestritionByBalance
}