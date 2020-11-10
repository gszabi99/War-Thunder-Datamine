local getUnitShopPriceText = @(unit)
  ::canBuyUnitOnMarketplace(unit) ? ::loc("currency/gc/sign/colored", "")
  : ::isUnitUsable(unit) ? ""
  : ::isUnitGift(unit) ? ::g_string.stripTags(::loc($"shop/giftAir/{unit.gift}", "shop/giftAir/alpha"))
  : ::canBuyUnit(unit) || ::isUnitSpecial(unit) || ::isUnitResearched(unit)
    ? ::getPriceAccordingToPlayersCurrency(::wp_get_cost(unit.name), ::wp_get_cost_gold(unit.name), true)
  : ""

return { getUnitShopPriceText }