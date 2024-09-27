//-file:plus-string
from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { subscribe_handler } = require("%sqStdLibs/helpers/subscriptions.nut")
let elemModelType = require("%sqDagui/elemUpdater/elemModelType.nut")
let elemViewType = require("%sqDagui/elemUpdater/elemViewType.nut")
let { topMenuShopActive } = require("%scripts/mainmenu/topMenuStates.nut")
let { getUnitName, getUnitCountryIcon } = require("%scripts/unit/unitInfo.nut")
let { addTooltipTypes } = require("%scripts/utils/genericTooltipTypes.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { g_discount, getUnitsDiscounts } = require("%scripts/discounts/discounts.nut")
let { getSortedDiscountUnits, prepareForTooltip, createMoreText } = require("%scripts/markers/markerTooltipUtils.nut")
let { getUnitClassIco } = require("%scripts/unit/unitInfoTexts.nut")

function getMaxDiscount(countryId) {
  return getUnitsDiscounts(countryId).reduce(function(res, val) {
    return max(res, val.discount)
  }, 0)
}

elemModelType.addTypes({
  DISCOUNT_MARKER = {
    init = @() subscribe_handler(this, g_listener_priority.DEFAULT_HANDLER)

    onEventDiscountsDataUpdated = @(_p) this.notify([])
    onEventShopWndSwitched = @(_p) this.notify([])
  }
})


elemViewType.addTypes({
  SHOP_DISCOUNT_MARKER = {
    model = elemModelType.DISCOUNT_MARKER

    updateView = function(obj, _params) {
      let haveDicsount = g_discount.haveAnyUnitDiscount()
      obj.show(haveDicsount)
    }
  }

  COUNTRY_DISCOUNT_MARKER = {
    model = elemModelType.DISCOUNT_MARKER

    updateView = function(obj, _params) {
      let maxDiscount = getMaxDiscount(obj.countryId)
      let isVisible = topMenuShopActive.value && maxDiscount > 0
      obj.show(isVisible)
      if (!isVisible)
        return
      obj.text = "-" + maxDiscount + "%"
    }
  }
})

addTooltipTypes({
  DISCOUNTS = {
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, _id, params) {
      if (obj.getParent()?["stacked"] == "yes")
        return false

      let { countryId = "", armyId = "" } = params
      let discountUnits = getSortedDiscountUnits(getUnitsDiscounts(countryId, armyId))
      let { tooltipUnits, tooltipUnitsCount } = prepareForTooltip(discountUnits)
      let blocks = tooltipUnits.map(function(block, index, arr) {
        let units = block.units
          .map(@(val, idx) {
            hasCountry = countryId == ""
            countryIcon = getUnitCountryIcon(val.unit)
            isWideIco = val.unit.unitType.isWideUnitIco
            unitTypeIco = getUnitClassIco(val.unit)
            unitName = getUnitName(val.unit.name, true)
            value = $"{val.discount}%"
            even = idx % 2 == 0
          })

        return {
          units
          hasMore = block.more > 0
          more = createMoreText(block.more)
          isLast = index == arr.len() - 1
        }
      })
      let view = {
        header = "#discount/notification"
        blocks
        hasMoreVehicles = tooltipUnitsCount < discountUnits.len()
        moreVehicles = createMoreText(discountUnits.len() - tooltipUnitsCount)
      }
      let data = handyman.renderCached("%gui/markers/markersTooltip.tpl", view)
      obj.getScene().replaceContentFromText(obj, data, data.len(), handler)
      return true
    }
  }
})

return {}
