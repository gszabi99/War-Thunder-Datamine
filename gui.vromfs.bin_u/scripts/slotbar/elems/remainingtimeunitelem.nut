from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { subscribe_handler } = require("%sqStdLibs/helpers/subscriptions.nut")
let elemModelType = require("%sqDagui/elemUpdater/elemModelType.nut")
let elemViewType = require("%sqDagui/elemUpdater/elemViewType.nut")
let { topMenuShopActive } = require("%scripts/mainmenu/topMenuStates.nut")
let { promoteUnits } = require("%scripts/unit/remainingTimeUnit.nut")
let { isUnitSpecial } = require("%appGlobals/ranks_common_shared.nut")
let { isUnitGift } = require("%scripts/unit/unitInfo.nut")

elemModelType.addTypes({
  REMAINING_TIME_UNIT = {
    function init() {
      subscribe_handler(this, g_listener_priority.DEFAULT_HANDLER)
    }

    isVisible = @() promoteUnits.value.findvalue(@(d) d.isActive) != null

    getTooltip = @() loc("mainmenu/promoteUnit")

    onEventShopWndSwitched = @(_p) this.notify([])
    onEventPromoteUnitsChanged = @(_p) this.notify([])
    onEventDiscountsDataUpdated = @(_p) this.notify([])
  }
})

elemViewType.addTypes({
  SHOP_REMAINING_TIME_UNIT = {
    model = elemModelType.REMAINING_TIME_UNIT

    function updateView(obj, _params) {
      let isVisible = this.model.isVisible()
      obj.show(isVisible)
      if (!isVisible)
        return

      let haveDicsount = ::g_discount.haveAnyUnitDiscount()
      let tooltipText = haveDicsount
        ? $"{loc("mainmenu/promoteUnit")}\n{loc("discount/notification")}"
        : loc("mainmenu/promoteUnit")
      obj.tooltip = tooltipText
      obj.findObject("remainingTimeTimerIcon").show(haveDicsount)
    }
  }

  COUNTRY_REMAINING_TIME_UNIT = {
    model = elemModelType.REMAINING_TIME_UNIT

    function updateView(obj, _params) {
      local isVisible = topMenuShopActive.value && this.model.isVisible()
      if (!isVisible) {
        obj.show(isVisible)
        return
      }

      let countryId = obj.countryId
      let havePromoteUnitCountry = promoteUnits.value.findvalue(@(u) u.unit.shopCountry == countryId) != null
      obj.show(havePromoteUnitCountry)
      if (!havePromoteUnitCountry)
        return
      let discountsList = ::g_discount.getUnitDiscountList(countryId)
      let haveDicsountAndRemUnit = havePromoteUnitCountry && discountsList.len() != 0
      let tooltipText = haveDicsountAndRemUnit
        ? $"{loc("mainmenu/promoteUnit")}\n{::g_discount.generateDiscountInfo(discountsList)?.discountTooltip}"
        : loc("mainmenu/promoteUnit")

      obj.tooltip = loc(tooltipText)
      obj.findObject("remainingTimeTimerIcon").show(haveDicsountAndRemUnit)
    }
  }

  SHOP_PAGES_REMAINING_TIME_UNIT = {
    model = elemModelType.REMAINING_TIME_UNIT

    function updateView(obj, _params) {
      local isVisible = topMenuShopActive.value && this.model.isVisible()
      if (!isVisible) {
        obj.show(isVisible)
        return
      }

      foreach (promUnit in promoteUnits.value) {
        if (promUnit.unit.shopCountry == obj.countryId && promUnit.unit.unitType.armyId == obj.armyId) {
          obj.show(true)
          return
        }
      }
      obj.show(false)
    }
  }

  SHOP_RANK_REMAINING_TIME_UNIT = {
    model = elemModelType.REMAINING_TIME_UNIT

    function updateView(obj, _params) {
      local count = 0
      let units = promoteUnits.get()
      if (units.len() == 0) {
        obj.show(false)
        return
      }

      let countryId = obj?.countryId ?? ""
      let armyId = obj?.armyId ?? ""
      let rank = to_integer_safe(obj?.rank) ?? -1
      let needCollectPremiumUnits = (obj?.isForPremium ?? "no") == "yes"
      local unitsNames = ""
      foreach (promUnit in units) {
        if (promUnit.unit.shopCountry != countryId
            || promUnit.unit.unitType.armyId != armyId
            || promUnit.unit.rank != rank)
          continue

        if (needCollectPremiumUnits != (isUnitSpecial(promUnit.unit)
            || isUnitGift(promUnit.unit)
            || promUnit.unit?.isSquadronVehicle?()))
          continue
        let unitName = loc($"{promUnit.unit.name}_shop")
        unitsNames = unitsNames == ""
          ? "".concat(loc("mainmenu/promoteUnit"), "\n* ", unitName)
          : $"{unitsNames}\n* {unitName}"

        count++
      }
      obj.show(count > 0)
      if (count > 0) {
        obj.findObject("count_text")?.setValue($"×{count}")
        obj.tooltip = unitsNames
      }
    }
  }

  SHOP_SLOT_REMAINING_TIME_UNIT = {
    model = elemModelType.REMAINING_TIME_UNIT

    function updateView(obj, params) {
      obj.show(promoteUnits.value?[params?.unitName].isActive)

    }
  }
})

return {}
