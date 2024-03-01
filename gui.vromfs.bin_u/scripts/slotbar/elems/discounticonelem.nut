//-file:plus-string
from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { subscribe_handler } = require("%sqStdLibs/helpers/subscriptions.nut")
let elemModelType = require("%sqDagui/elemUpdater/elemModelType.nut")
let elemViewType = require("%sqDagui/elemUpdater/elemViewType.nut")
let { topMenuShopActive } = require("%scripts/mainmenu/topMenuStates.nut")
let { promoteUnits } = require("%scripts/unit/remainingTimeUnit.nut")


elemModelType.addTypes({
  COUNTRY_DISCOUN_ICON = {
    init = @() subscribe_handler(this, g_listener_priority.DEFAULT_HANDLER)

    onEventDiscountsDataUpdated = @(_p) this.notify([])
    onEventPromoteUnitsChanged = @(_p) this.notify([])
    onEventShopWndSwitched = @(_p) this.notify([])
  }
})


elemViewType.addTypes({
  COUNTRY_DISCOUN_ICON = {
    model = elemModelType.COUNTRY_DISCOUN_ICON

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
