from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { subscribe_handler } = require("%sqStdLibs/helpers/subscriptions.nut")
let elemModelType = require("%sqDagui/elemUpdater/elemModelType.nut")
let elemViewType = require("%sqDagui/elemUpdater/elemViewType.nut")
let { topMenuShopActive } = require("%scripts/mainmenu/topMenuStates.nut")
let { promoteUnits } = require("%scripts/unit/remainingTimeUnit.nut")
let { isUnitSpecial } = require("%appGlobals/ranks_common_shared.nut")
let { isUnitGift, getUnitName, getUnitCountryIcon } = require("%scripts/unit/unitInfo.nut")
let { addTooltipTypes } = require("%scripts/utils/genericTooltipTypes.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { TIME_DAY_IN_SECONDS, buildDateTimeStr } = require("%scripts/time.nut")
let { secondsToString } = require("%appGlobals/timeLoc.nut")
let { get_charserver_time_sec } = require("chard")
let { getSortedUnits, createMoreText
  maxElementsInSimpleTooltip } = require("%scripts/markers/markerTooltipUtils.nut")
let { getUnitClassIco } = require("%scripts/unit/unitInfoTexts.nut")

elemModelType.addTypes({
  REMAINING_TIME_UNIT = {
    function init() {
      subscribe_handler(this, g_listener_priority.DEFAULT_HANDLER)
    }

    isVisible = @() promoteUnits.get().findvalue(@(d) d.isActive) != null

    onEventShopWndSwitched = @(_p) this.notify([])
    onEventPromoteUnitsChanged = @(_p) this.notify([])
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
      let havePromoteUnitCountry = promoteUnits.get().findvalue(@(u) u.unit.shopCountry == countryId) != null
      obj.show(havePromoteUnitCountry)
      if (!havePromoteUnitCountry)
        return
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

      foreach (promUnit in promoteUnits.get()) {
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
      obj.show(promoteUnits.get()?[params?.unitName].isActive)
      obj.tooltip = loc("mainmenu/promoteUnit")
    }
  }
})

function buildTimeTextValue(timeEnd) {
  let t = timeEnd - get_charserver_time_sec()
  return t < 0 ? loc("shop/tasksExpired") : t < TIME_DAY_IN_SECONDS
    ? loc("mainmenu/timeForBuyVehicleShort", { time = secondsToString(t) })
    : loc("mainmenu/dataRemaningTimeShort", { time = buildDateTimeStr(timeEnd, false, false) })
}

addTooltipTypes({
  REMAINING_TIME_UNIT = {
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, _id, params) {
      let { countryId = "", armyId = "" } = params
      let units = getSortedUnits(promoteUnits.get().values())
      local remainingUnits = countryId == "" ? units : units.filter(@(val) val.unit.shopCountry == countryId)
      remainingUnits = armyId == "" ? remainingUnits : remainingUnits.filter(@(val) val.unit.unitType.armyId == armyId)
      remainingUnits = remainingUnits
        .map(@(val, idx) {
          hasCountry = countryId == ""
          countryIcon = getUnitCountryIcon(val.unit)
          isWideIco = val.unit.unitType.isWideUnitIco
          unitTypeIco = getUnitClassIco(val.unit)
          unitName = getUnitName(val.unit.name, true)
          value = buildTimeTextValue(val.timeEnd)
          even = idx % 2 == 0
        })
      let view = {
        header = "#mainmenu/promoteUnit"
        isTooltipWide = true
        units = remainingUnits.slice(0, maxElementsInSimpleTooltip)
        hasMoreVehicles = remainingUnits.len() > maxElementsInSimpleTooltip
        moreVehicles = createMoreText(remainingUnits.len() - maxElementsInSimpleTooltip)
      }
      let data = handyman.renderCached("%gui/markers/markersTooltipSimple.tpl", view)
      obj.getScene().replaceContentFromText(obj, data, data.len(), handler)
      return true
    }
  }
})

return {}
