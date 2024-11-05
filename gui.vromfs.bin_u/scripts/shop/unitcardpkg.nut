from "%scripts/dagui_natives.nut" import wp_get_cost_gold, wp_get_cost
from "%scripts/dagui_library.nut" import *

let { isUnitSpecial } = require("%appGlobals/ranks_common_shared.nut")
let { stripTags } = require("%sqstd/string.nut")
let { canBuyUnit, isUnitGift } = require("%scripts/unit/unitShopInfo.nut")
let { isUnitUsable } = require("%scripts/unit/unitStatus.nut")

let { Cost } = require("%scripts/money.nut")

let getUnitShopPriceText = @(unit)
  ::canBuyUnitOnMarketplace(unit) ? loc("currency/gc/sign/colored", "")
  : isUnitUsable(unit) ? ""
  : isUnitGift(unit) ? stripTags(loc($"shop/giftAir/{unit.gift}", "shop/giftAir/alpha"))
  : canBuyUnit(unit) || isUnitSpecial(unit) || ::isUnitResearched(unit)
    ? Cost(::wp_get_cost(unit.name), wp_get_cost_gold(unit.name)).getTextAccordingToBalance()
  : ""

return { getUnitShopPriceText }