//checked for plus_string
from "%scripts/dagui_library.nut" import *
let { stripTags } = require("%sqstd/string.nut")
let { isUnitGift } = require("%scripts/unit/unitInfo.nut")
let { Cost } = require("%scripts/money.nut")

let getUnitShopPriceText = @(unit)
  ::canBuyUnitOnMarketplace(unit) ? loc("currency/gc/sign/colored", "")
  : ::isUnitUsable(unit) ? ""
  : isUnitGift(unit) ? stripTags(loc($"shop/giftAir/{unit.gift}", "shop/giftAir/alpha"))
  : ::canBuyUnit(unit) || ::isUnitSpecial(unit) || ::isUnitResearched(unit)
    ? Cost(::wp_get_cost(unit.name), ::wp_get_cost_gold(unit.name)).getTextAccordingToBalance()
  : ""

return { getUnitShopPriceText }