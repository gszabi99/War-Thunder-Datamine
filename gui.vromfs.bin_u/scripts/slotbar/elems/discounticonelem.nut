//-file:plus-string
from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { subscribe_handler } = require("%sqStdLibs/helpers/subscriptions.nut")
let elemModelType = require("%sqDagui/elemUpdater/elemModelType.nut")
let elemViewType = require("%sqDagui/elemUpdater/elemViewType.nut")
let { topMenuShopActive } = require("%scripts/mainmenu/topMenuStates.nut")
let { promoteUnits } = require("%scripts/unit/remainingTimeUnit.nut")


elemModelType.addTypes({
  DISCOUNT_MARKER = {
    init = @() subscribe_handler(this, g_listener_priority.DEFAULT_HANDLER)

    onEventDiscountsDataUpdated = @(_p) this.notify([])
    onEventPromoteUnitsChanged = @(_p) this.notify([])
    onEventShopWndSwitched = @(_p) this.notify([])
  }
})


elemViewType.addTypes({
  SHOP_DISCOUNT_MARKER = {
    model = elemModelType.DISCOUNT_MARKER

    updateView = function(obj, _params) {
      let haveDicsount = ::g_discount.haveAnyUnitDiscount()
      obj.tooltip = loc("discount/notification")
      obj.show(haveDicsount)
    }
  }

  COUNTRY_DISCOUNT_MARKER = {
    model = elemModelType.DISCOUNT_MARKER

    updateView = function(obj, _params) {
      let discountData = ::g_discount.generateDiscountInfo(
        ::g_discount.getUnitDiscountList(obj.countryId))
      let maxDiscount = discountData?.maxDiscount ?? 0
      let isVisible = topMenuShopActive.value && maxDiscount > 0
        && promoteUnits.value.findvalue(@(u) u.unit.shopCountry == obj.countryId) == null
      obj.show(isVisible)
      if (!isVisible)
        return
      obj.text = "-" + maxDiscount + "%"
      obj.tooltip = discountData?.discountTooltip ?? ""
    }
  }
})

return {}
