from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let elemModelType = require("%sqDagui/elemUpdater/elemModelType.nut")
let elemViewType = require("%sqDagui/elemUpdater/elemViewType.nut")
let { topMenuShopActive } = require("%scripts/mainmenu/topMenuStates.nut")
let { promoteUnits } = require("%scripts/unit/remainingTimeUnit.nut")

elemModelType.addTypes({
  REMAINING_TIME_UNIT = {
    function init(){
      ::subscribe_handler(this, ::g_listener_priority.DEFAULT_HANDLER)
    }

    isVisible = @() promoteUnits.value.findvalue(@(d) d.isActive) != null

    getTooltip = @() loc("mainmenu/promoteUnit")

    onEventShopWndSwitched = @(p) notify([])
    onEventPromoteUnitsChanged = @(p) notify([])
    onEventDiscountsDataUpdated = @(p) notify([])
  }
})

elemViewType.addTypes({
  SHOP_REMAINING_TIME_UNIT = {
    model = elemModelType.REMAINING_TIME_UNIT

    function updateView(obj, params){
      let isVisible = model.isVisible()
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

    function updateView(obj, params){
      local isVisible = topMenuShopActive.value && model.isVisible()
      if (!isVisible){
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

    function updateView(obj, params){
      local isVisible = topMenuShopActive.value && model.isVisible()
      if (!isVisible){
        obj.show(isVisible)
        return
      }

      foreach(promUnit in promoteUnits.value){
        if(promUnit.unit.shopCountry == obj.countryId && promUnit.unit.unitType.armyId == obj.armyId){
          obj.show(true)
          return
        }
      }
      obj.show(false)
    }
  }

  SHOP_SLOT_REMAINING_TIME_UNIT = {
    model = elemModelType.REMAINING_TIME_UNIT

    function updateView(obj, params){
      obj.show(promoteUnits.value?[params?.unitName].isActive)

    }
  }
})

return {}
