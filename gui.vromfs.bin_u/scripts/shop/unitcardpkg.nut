from "%scripts/unit/unitShopInfo.nut" import canBuyUnit, isUnitGift
from "%scripts/unit/unitStatus.nut" import isUnitUsable, isUnitResearched
from "%scripts/unit/canBuyUnitOnMarketplace.nut" import canBuyUnitOnMarketplace
from "%scripts/unit/unitEvents.nut" import hasUnitEvent
from "%scripts/money.nut" import Cost
from "%appGlobals/ranks_common_shared.nut" import isUnitSpecial
from "%sqStdLibs/helpers/daguiString.nut" import stripTags
from "%scripts/dagui_natives.nut" import wp_get_cost_gold, wp_get_cost
from "%scripts/dagui_library.nut" import *

let getUnitShopPriceText = @(unit)
  hasUnitEvent(unit.name) ? ""
  : canBuyUnitOnMarketplace(unit) ? loc("currency/gc/sign/colored", "")
  : isUnitUsable(unit) || unit.isUsableSlaveUnit() ? ""
  : isUnitGift(unit) ? stripTags(loc($"shop/giftAir/{unit.gift}", "shop/giftAir/alpha"))
  : canBuyUnit(unit) || isUnitSpecial(unit) || isUnitResearched(unit)
    ? Cost(wp_get_cost(unit.name), wp_get_cost_gold(unit.name)).getTextAccordingToBalance()
  : ""

return freeze({ getUnitShopPriceText })