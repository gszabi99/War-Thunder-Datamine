from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let elemModelType = require("%sqDagui/elemUpdater/elemModelType.nut")
let elemViewType = require("%sqDagui/elemUpdater/elemViewType.nut")
let { topMenuShopActive } = require("%scripts/mainmenu/topMenuStates.nut")
let { subscribe_handler } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getUnitsWithUnlock } = require("%scripts/unlocks/unlockMarkers.nut")
let { getCurrentGameModeEdiff } = require("%scripts/gameModes/gameModeManagerState.nut")
let { getUnitName, getUnitCountryIcon } = require("%scripts/unit/unitInfo.nut")
let { addTooltipTypes } = require("%scripts/utils/genericTooltipTypes.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { getTimestampFromStringUtc } = require("%scripts/time.nut")
let { getSortedUnits, prepareForTooltip, createMoreText } = require("%scripts/markers/markerTooltipUtils.nut")
let { getUnitClassIco } = require("%scripts/unit/unitInfoTexts.nut")
let { buildTimeTextValue } = require("%scripts/markers/markerUtils.nut")

elemModelType.addTypes({
  UNLOCK_MARKER = {
    init = @() subscribe_handler(this, g_listener_priority.DEFAULT_HANDLER)

    onEventShopWndSwitched = @(_p) this.notify([])
  }
})

elemViewType.addTypes({
  COUNTRY_UNLOCK_MARKER = {
    model = elemModelType.UNLOCK_MARKER
    updateView = @(obj, _) obj.show(topMenuShopActive.get())
  }
})

addTooltipTypes({
  UNLOCK_MARKER = {
    isCustomTooltipFill = true

    updateTimeLeft = function(timer, _dt) {
      let unitsCount = timer.unitsCount.tointeger()
      let parent = timer.getParent()
      for (local i = 1; i <= unitsCount; i++) {
        let valueObj = parent.findObject($"id_{i}")
        if (valueObj == null)
          continue
        valueObj.setValue(buildTimeTextValue(valueObj.endDate))
      }
    }

    fillTooltip = function(obj, handler, _id, params) {
      if (obj.getParent()?["stacked"] == "yes")
        return false

      let { countryId = "", armyId = "" } = params
      let sortedUnits = getSortedUnits(getUnitsWithUnlock(getCurrentGameModeEdiff()))
      let unlockUnits = (countryId == "" && armyId == "") ? sortedUnits
        : sortedUnits.filter(@(val) (countryId == "" || val.unit.shopCountry == countryId) && (armyId == "" || val.unit.unitType.armyId == armyId))

      let { tooltipUnits, tooltipUnitsCount } = prepareForTooltip(unlockUnits)
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
              value = val.endDate != null ? buildTimeTextValue(getTimestampFromStringUtc(val.endDate)) : ""
              endDate = val.endDate != null ? getTimestampFromStringUtc(val.endDate) : val.endDate
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
        header = "#mainmenu/objectiveAvailable"
        blocks
        isTooltipWide = true
        hasMoreVehicles = tooltipUnitsCount < unlockUnits.len()
        moreVehicles = createMoreText(unlockUnits.len() - tooltipUnitsCount)
        needTimer = true
        unitsCount = tooltipUnits.reduce(function(res, val) { return res + val.units.len() }, 0)
      }

      let data = handyman.renderCached("%gui/markers/markersTooltip.tpl", view)
      obj.getScene().replaceContentFromText(obj, data, data.len(), handler)
      obj.findObject("timeLeftTimer").setUserData(this)
      return true
    }
  }
})
