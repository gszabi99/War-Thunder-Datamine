from "%scripts/dagui_library.nut" import *
from "%scripts/mainConsts.nut" import SEEN

let { broadcastEvent, addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { promoteUnits } = require("%scripts/unit/remainingTimeUnit.nut")
let { getUnitsWithNationBonuses, getNationBonusMarkState } = require("%scripts/nationBonuses/nationBonuses.nut")
let { getUnitsDiscounts } = require("%scripts/discounts/discounts.nut")
let { getUnitsWithUnlock } = require("%scripts/unlocks/unlockMarkers.nut")
let { getCurrentGameModeEdiff } = require("%scripts/gameModes/gameModeManagerState.nut")
let seenList = require("%scripts/seen/seenList.nut").get(SEEN.UNLOCK_MARKERS)
let seenListEvents = require("%scripts/seen/seenListEvents.nut")
let { deferOnce } = require("dagor.workcycle")
let { addTooltipTypes } = require("%scripts/utils/genericTooltipTypes.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { topMenuShopActive } = require("%scripts/mainmenu/topMenuStates.nut")
let { getSortedDiscountUnits, createMoreText, maxTooltipUnitsCount } = require("%scripts/markers/markerTooltipUtils.nut")
let { getUnitClassIco } = require("%scripts/unit/unitInfoTexts.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { TIME_DAY_IN_SECONDS, buildDateTimeStr, getTimestampFromStringUtc } = require("%scripts/time.nut")
let { hoursToString } = require("%appGlobals/timeLoc.nut")
let { get_charserver_time_sec } = require("chard")
let { get_ranks_blk } = require("blkGetters")

let { expNewNationBonusDailyBattleCount = 1 } = get_ranks_blk()

function buildTimeTextValue(timeEnd) {
  if(timeEnd == null || timeEnd == "")
    return ""
  timeEnd = timeEnd.tointeger()
  let t = timeEnd - get_charserver_time_sec()
  return t < 0 ? loc("shop/tasksExpired") : t < TIME_DAY_IN_SECONDS
    ? loc("mainmenu/timeForBuyVehicleShort", { time = hoursToString(t / 3600.0, true, true) })
    : loc("mainmenu/dataRemaningTimeShort", { time = buildDateTimeStr(timeEnd, false, false) })
}

let markersWidths = {
  promoteMarker = "1@markerWidth"
  unlockMarker = "1@markerWidth"
  bonusMarker = "1@markerWidth"
  discountMarker = "1@discountMarkerWidth"
}

let markersMargin = "0.5@blockInterval"

local idCounter = 0

let customBuildValueFunctions = {
  promoteMarker = @(unitData) buildTimeTextValue(unitData.timeEnd)
  unlockMarker = @(unitData) unitData.endDate != null ? buildTimeTextValue(getTimestampFromStringUtc(unitData.endDate)) : ""
  bonusMarker = @(unitData) $"{unitData.battlesRemainCount}/{expNewNationBonusDailyBattleCount}"
  discountMarker = @(unitData) $"{unitData.discount}%"
}

let customTimerData = {
  promoteMarker = function(unitData) {
    idCounter++
    return {
      endDate = unitData.timeEnd
      id = $"id_{idCounter}"
    }
  }
  unlockMarker = function(unitData) {
    idCounter++
    return {
      endDate = unitData.endDate != null ? getTimestampFromStringUtc(unitData.endDate) : unitData.endDate
      id = $"id_{idCounter}"
    }
  }
}

let cacheCountryMarkers = {}

function invalidateCache() {
  cacheCountryMarkers.clear()
  deferOnce(@() broadcastEvent("CountryMarkersInvalidate"))
}

function getCountryMarkersData(countryId) {
  if (countryId in cacheCountryMarkers)
    return cacheCountryMarkers[countryId]

  let countryMarkers = []

  let unlockMarkersData = getUnitsWithUnlock(getCurrentGameModeEdiff()).filter(@(val) val.unit.shopCountry == countryId
    && seenList.getNewCount([val.unlockId]) > 0)
  if (unlockMarkersData.len() > 0)
    countryMarkers.append({ markerId = "unlockMarker", units = unlockMarkersData, header = "#mainmenu/objectiveAvailable" })

  let bonusMarkersData = getUnitsWithNationBonuses().units.filter(@(b) b.unit.shopCountry == countryId
    && getNationBonusMarkState(countryId, b.unit.unitType.armyId))
  if (bonusMarkersData.len() > 0)
    countryMarkers.append({ markerId = "bonusMarker", units = bonusMarkersData, header = "#shop/unit_nation_bonus_tooltip/header" })

  let promoteMarkersData = promoteUnits.get().filter(@(u) u.unit.shopCountry == countryId).values()
  if (promoteMarkersData.len() > 0)
    countryMarkers.append({ markerId = "promoteMarker", units = promoteMarkersData, header = "#mainmenu/promoteUnit" })

  let discountMarkersData = getSortedDiscountUnits(getUnitsDiscounts(countryId))
  if (discountMarkersData.len() > 0)
    countryMarkers.append({ markerId = "discountMarker", units = discountMarkersData, header = "#discount/notification" })

  cacheCountryMarkers[countryId] <- countryMarkers
  return countryMarkers
}

function getCountryMarkersWidth(countryId) {
  let countryMarkers = getCountryMarkersData(countryId)
  let countMarkers = countryMarkers.len()
  if(countMarkers == 0)
    return 0
  return countryMarkers.reduce(function(res, markerData) {
    return res + to_pixels(markersWidths[markerData.markerId])
  }, 0) + (countMarkers - 1) * to_pixels(markersMargin)
}

seenListEvents.subscribe(SEEN.UNLOCK_MARKERS, null, Callback(invalidateCache))

addListenersWithoutEnv({
  DiscountsDataUpdated = @(_p) invalidateCache()
  PromoteUnitsChanged = @(_p) invalidateCache()
  UnlockMarkersCacheInvalidate = @(_p) invalidateCache()
})

addTooltipTypes({
  STACKEDMARKERS = {
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
      if (!topMenuShopActive.get())
        return false

      let { countryId } = params
      local unitsLeft = maxTooltipUnitsCount
      let countryMarkersData = getCountryMarkersData(countryId)

      let result = countryMarkersData.map(function(data) {
        return {
          more = data.units.len()
          units = 0
          data
        }
      })

      local allUnitsCount = result.reduce(function(res, data) {
        return res + data.more
      }, 0)

      while (allUnitsCount > 0 && unitsLeft > 0) {
        for (local i = 0; i < result.len(); i++) {
          let countryMarker = result[i]
          if (countryMarker.more == 0)
            continue
          countryMarker.units++
          countryMarker.more--
          unitsLeft--
          allUnitsCount--
        }
      }

      idCounter = 0
      let blocks = result.map(function(value, index) {
        return {
          header = value.data.header
          units = value.data.units.slice(0, value.units).map(@(unitData, idx) {
            hasCountry = false
            isWideIco = unitData.unit.unitType.isWideUnitIco
            unitTypeIco = getUnitClassIco(unitData.unit)
            unitName = getUnitName(unitData.unit.name, true)
            value = customBuildValueFunctions[value.data.markerId](unitData)
            even = idx % 2 == 0
          }.__merge(customTimerData?[value.data.markerId](unitData) ?? {}))
          hasMoreVehicles = value.more > 0
          moreVehicles = createMoreText(value.more)
          hasBlocksSeparator = index != 0
        }
      })

      let needTimer = result.findindex(@(v) ["unlockMarker", "promoteMarker"].contains(v.data.markerId)) != null
      let unitsCount = result.reduce(function(res, val) {
        return ["unlockMarker", "promoteMarker"].contains(val.data.markerId) ? res + val.units : res
      }, 0)

      let data = handyman.renderCached("%gui/markers/markersTooltipSimple.tpl", { blocks, isTooltipWide = true, needTimer, unitsCount })
      obj.getScene().replaceContentFromText(obj, data, data.len(), handler)

      if(needTimer)
        obj.findObject("timeLeftTimer").setUserData(this)
      return true
    }
  }
})

return {
  getCountryMarkersWidth
  buildTimeTextValue
}