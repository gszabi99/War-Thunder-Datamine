from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { subscribe_handler } = require("%sqStdLibs/helpers/subscriptions.nut")
let elemModelType = require("%sqDagui/elemUpdater/elemModelType.nut")
let elemViewType = require("%sqDagui/elemUpdater/elemViewType.nut")
let { topMenuShopActive } = require("%scripts/mainmenu/topMenuStates.nut")
let { hasUnitEvent, getUnitEventId, getEventUnitsData } = require("%scripts/unit/unitEvents.nut")
let { unitNews } = require("%scripts/changelog/changeLogState.nut")
let { eventbus_subscribe } = require("eventbus")
let { guiStartProfile } = require("%scripts/user/profileHandler.nut")
let { gui_start_mainmenu } = require("%scripts/mainmenu/guiStartMainmenu.nut")
let { addTooltipTypes } = require("%scripts/utils/genericTooltipTypes.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { getSortedUnits, createMoreText, prepareForTooltip } = require("%scripts/markers/markerTooltipUtils.nut")
let { getUnitClassIco } = require("%scripts/unit/unitInfoTexts.nut")
let { getUnitName, getUnitCountryIcon } = require("%scripts/unit/unitInfo.nut")

function hasApropriateUnits(countryId, armyId) {
  let eventsUnits = getEventUnitsData()
  if (countryId == "" && armyId == "")
    return eventsUnits.len() > 0

  if (armyId == "")
    return eventsUnits.findindex(@(v) v.unit.shopCountry == countryId) != null

  return eventsUnits.findindex(@(v) v.unit.shopCountry == countryId && v.unit.unitType.armyId == armyId) != null
}

elemModelType.addTypes({
  EVENT_MARKER = {
    function init() {
      subscribe_handler(this, g_listener_priority.DEFAULT_HANDLER)
    }
    isVisible = @() true
    onEventShopWndSwitched = @(_p) this.notify([])
  }
})

elemViewType.addTypes({
  SHOP_SLOT_EVENT_MARKER = {
    model = elemModelType.EVENT_MARKER

    updateView = function(obj, params) {
      let unitName = params?.unitName
      if (unitName == null || !hasUnitEvent(unitName)) {
        obj.show(false)
        return
      }
      obj.show(true)

      let eventId = getUnitEventId(unitName)
      let isActive = unitNews.get().findindex(@(v) v.titleshort == eventId) != null
      obj["isActive"] = isActive ? "yes" : "no"
      obj["eventId"] = isActive ? eventId : ""

      let eventName = loc($"unlocks/chapter/{eventId}")
      let tooltipParts = [loc("mainmenu/vehicleAvailableByEvent", { eventName })]
      if (isActive)
        tooltipParts.append(loc("mainmenu/clickOnLabel"))
      obj.tooltip = "\n".join(tooltipParts)
    }
  }

  SHOP_PAGES_EVENT_MARKER = {
    model = elemModelType.EVENT_MARKER

    function updateView(obj, _params) {
      let isVisible = topMenuShopActive.get() && this.model.isVisible()
      if (!isVisible) {
        obj.show(isVisible)
        return
      }

      let { countryId = "", armyId = "" } = obj
      if (countryId == "" && armyId == "") {
        obj.show(false)
        return

      }
      obj.show(hasApropriateUnits(countryId, armyId))
    }
  }

  COUNTRY_EVENT_MARKER = {
    model = elemModelType.EVENT_MARKER

    function updateView(obj, _params) {
      let isVisible = topMenuShopActive.get() && this.model.isVisible()
      if (!isVisible) {
        obj.show(isVisible)
        return
      }

      let { countryId = "", armyId = "" } = obj
      obj.show(hasApropriateUnits(countryId, armyId))
    }
  }

  SHOP_EVENT_MARKER = {
    model = elemModelType.EVENT_MARKER

    function updateView(obj, _params) {
      let { countryId = "", armyId = "" } = obj
      obj.show(hasApropriateUnits(countryId, armyId))
    }
  }
})

addTooltipTypes({
  EVENT_UNIT = {
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, _id, params) {
      if (obj.getParent()?["stacked"] == "yes")
        return false

      let { countryId = "", armyId = "" } = params
      let rawUnits = getEventUnitsData()
      let sortedUnits = getSortedUnits(rawUnits)
      let eventUnits = (countryId == "" && armyId == "") ? sortedUnits
        : sortedUnits.filter(@(val) (countryId == "" || val.unit.shopCountry == countryId) && (armyId == "" || val.unit.unitType.armyId == armyId))

      let { tooltipUnits, tooltipUnitsCount } = prepareForTooltip(eventUnits)
      local idCounter = 0
      let blocks = tooltipUnits.map(function(block, index, arr) {
        let units = block.units
          .map(function(val, idx) {
            idCounter++
            return {
              hasCountry = countryId == ""
              countryIcon = getUnitCountryIcon(val.unit)
              isWideIco = val.unit.unitType.isWideUnitIco
              unitTypeIco = getUnitClassIco(val.unit)
              unitName = getUnitName(val.unit.name, true)
              value = loc($"unlocks/chapter/{val.eventId}")
              id = $"id_{idCounter}"
              even = idx % 2 == 0
            }
          })

        return {
          units
          hasMore = block.more > 0
          more = createMoreText(block.more)
          isLast = index == arr.len() - 1
        }
      })
      let view = {
        header = "#mainmenu/eventUnit"
        blocks
        isTooltipWide = true
        hasMoreVehicles = tooltipUnitsCount < eventUnits.len()
        moreVehicles = createMoreText(eventUnits.len() - tooltipUnitsCount)
        needTimer = true
        unitsCount = tooltipUnits.reduce(function(res, val) { return res + val.units.len() }, 0)
      }

      let data = handyman.renderCached("%gui/markers/markersTooltip.tpl", view)
      obj.getScene().replaceContentFromText(obj, data, data.len(), handler)
      return true
    }
  }
})

eventbus_subscribe("gotoAchievement", function(p) {
  gui_start_mainmenu()
  guiStartProfile({ initialSheet = "UnlockAchievement", curAchievementGroupName = p.eventId })
})

return {}