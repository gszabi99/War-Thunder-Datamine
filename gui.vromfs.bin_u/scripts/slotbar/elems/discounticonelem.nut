let elemModelType = require("%sqDagui/elemUpdater/elemModelType.nut")
let elemViewType = require("%sqDagui/elemUpdater/elemViewType.nut")
let { topMenuShopActive } = require("%scripts/mainmenu/topMenuStates.nut")


elemModelType.addTypes({
  COUNTRY_DISCOUN_ICON = {
    init = @() ::subscribe_handler(this, ::g_listener_priority.DEFAULT_HANDLER)

    onEventDiscountsDataUpdated = @(p) notify([])
    onEventShopWndSwitched = @(p) notify([])
  }
})


elemViewType.addTypes({
  COUNTRY_DISCOUN_ICON = {
    model = elemModelType.COUNTRY_DISCOUN_ICON

    updateView = function(obj, params)
    {
      let discountData = ::g_discount.generateDiscountInfo(
        ::g_discount.getUnitDiscountList(obj.countryId))
      let maxDiscount = discountData?.maxDiscount ?? 0
      let isVisible = topMenuShopActive.value && maxDiscount > 0
      obj.show(isVisible)
      if (!isVisible)
        return
      obj.text = "-" + maxDiscount + "%"
      obj.tooltip = discountData?.discountTooltip ?? ""
    }
  }
})

return {}
