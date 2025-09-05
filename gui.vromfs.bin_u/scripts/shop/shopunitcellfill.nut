from "%scripts/dagui_natives.nut" import clan_get_exp, is_era_available, wp_shop_get_aircraft_xp_rate, rented_units_get_last_max_full_rent_time, wp_shop_get_aircraft_wp_rate
from "%scripts/dagui_library.nut" import *
from "%scripts/weaponry/weaponryConsts.nut" import UNIT_WEAPONS_READY
from "%scripts/utils_sa.nut" import get_tomoe_unit_icon
from "%scripts/clans/clanState.nut" import is_in_clan

let { is_harmonized_unit_image_required } = require("%scripts/langUtils/harmonized.nut")
let { isUnitSpecial } = require("%appGlobals/ranks_common_shared.nut")
let { Cost } = require("%scripts/money.nut")
let { format, split_by_chars } = require("string")
let { round } = require("math")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { canBuyNotResearched, isUnitElite, canResearchUnit, isUnitUsable,
  isUnitInResearch, isUnitsEraUnlocked, isUnitGroup, isUnitBroken
} = require("%scripts/unit/unitStatus.nut")
let { isUnitInSlotbar } = require("%scripts/unit/unitInSlotbarStatus.nut")
let { getBitStatus } = require("%scripts/unit/unitBitStatus.nut")
let { getUnitItemStatusText, getUnitRarity
} = require("%scripts/unit/unitInfoTexts.nut")
let { getUnitRole, getUnitRoleIcon } = require("%scripts/unit/unitInfoRoles.nut")
let { checkUnitWeapons, getWeaponsStatusName } = require("%scripts/weaponry/weaponryInfo.nut")
let { getUnitShopPriceText } = require("unitCardPkg.nut")
let SecondsUpdater = require("%sqDagui/timer/secondsUpdater.nut")
let { hasMarkerByUnitName, getUnlockIdByUnitName } = require("%scripts/unlocks/unlockMarkers.nut")
let { stashBhvValueConfig } = require("%sqDagui/guiBhv/guiBhvValueConfig.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { getShopDevMode, getUnitDebugRankText } = require("%scripts/debugTools/dbgShop.nut")
let { shopIsModificationEnabled } = require("chardResearch")
let { getUnitName,
  bit_unit_status, getUnitReqExp, getUnitExp, image_for_air
} = require("%scripts/unit/unitInfo.nut")
let { getEsUnitType } = require("%scripts/unit/unitParams.nut")
let { canBuyUnit } = require("%scripts/unit/unitShopInfo.nut")
let { isUnitPriceTextLong, getUnitSlotRankText } = require("%scripts/slotbar/slotbarView.nut")
let { getBonusImage } = require("%scripts/bonusModule.nut")
let { getCurrentGameModeEdiff } = require("%scripts/gameModes/gameModeManagerState.nut")
let { getTooltipType, addTooltipTypes } = require("%scripts/utils/genericTooltipTypes.nut")
let sectorAngle1PID = dagui_propid_add_name_id("sector-angle-1")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { get_ranks_blk } = require("blkGetters")
let { get_charserver_time_sec } = require("chard")
let { getUtcMidnight, secondsToString, buildDateStr, getTimestampFromStringUtc } = require("%scripts/time.nut")
let timeBase = require("%appGlobals/timeLoc.nut")
let { getUnlockNameText } = require("%scripts/unlocks/unlocksViewModule.nut")
let { get_units_count_at_rank } = require("%scripts/shop/shopCountryInfo.nut")
let { get_unit_preset_img } = require("%scripts/options/optionsExt.nut")
let { getUnitDiscount, getGroupDiscount } = require("%scripts/discounts/discountsState.nut")
let { canBuyUnitOnMarketplace } = require("%scripts/unit/canBuyUnitOnMarketplace.nut")
let { canBuyUnitOnline } = require("%scripts/unit/availabilityBuyOnline.nut")
let { hasUnitEvent } = require("%scripts/unit/unitEvents.nut")

let setBool = @(obj, prop, val) obj[prop] = val ? "yes" : "no"
let {expNewNationBonusDailyBattleCount = 1} = get_ranks_blk()

addTooltipTypes({
  SHOP_CELL_NATION_BONUS = {
    isCustomTooltipFill = true

    getNationBonusElapsedUpdateTime = function() {
      let midNight = getUtcMidnight()
      let curTime = get_charserver_time_sec()
      return midNight - curTime + (midNight < curTime ? timeBase.TIME_DAY_IN_SECONDS : 0)
    }

    updateNationBonusTooltipTime = function(timer, _dt) {
      let parent = timer.getParent()
      let timerText = parent.findObject("time_text")
      let oldTime = to_integer_safe(timer.timeInSeconds)

      let elapsedTime = this.getNationBonusElapsedUpdateTime()
      if (oldTime < elapsedTime) {
        timerText.setValue(secondsToString(0))
        return
      }
      timer.timeInSeconds = elapsedTime
      timerText.setValue(secondsToString(elapsedTime))
    }

    fillTooltip = function(obj, handler, _id, params) {
      if (!obj.isValid())
        return false

      let { rank = 0, maxRank = -1, unitName = null, unitTypeName = "", isOver = false} = params
      local view = {}
      if (isOver) {
        let timeInSeconds = this.getNationBonusElapsedUpdateTime()
        let bonusUpdateTime = secondsToString(timeInSeconds)
        view = {
          timeLabel = "".concat(loc("shop/unit_nation_bonus_tooltip/update_time"), " ")
          timeText = bonusUpdateTime
          isOver = "yes"
          unitName
          timeInSeconds
        }
      } else {
        let bonusData = get_ranks_blk().ExpNewNationBonus?[unitTypeName]
        let percentData = []
        local lastPercent = -1
        local lastPercentData = null

        for (local i = 0; i <= maxRank; i++) {
          let percent = bonusData?[$"rank{i}"]
          if (percent == null)
            continue
          if (lastPercent == percent) {
            lastPercentData.maxRank = i
            continue
          }

          lastPercent = percent
          lastPercentData = {minRank = i, maxRank = i, percent}
          percentData.append(lastPercentData)
        }

        local percetnsString = ""
        foreach (data in percentData) {
          let rankStr = "".concat(get_roman_numeral(data.minRank),
            data.minRank == data.maxRank ? "" : $"-{get_roman_numeral(data.maxRank)}")
          percetnsString = "".concat(percetnsString, loc("shop/age/num", {num = rankStr}), $" - {data.percent}%",
            data.maxRank == maxRank ? "" : " | ")
        }

        let battlesRemain = loc("shop/unit_nation_bonus_tooltip/battles_remain",
          {battlesRemain = $"{params.battlesRemain}/{expNewNationBonusDailyBattleCount}"})

        let { isRecentlyReleased } = params
        let recentlyReleasedDays = get_ranks_blk()?.recentlyReleasedUnitConsideredNewDays ?? 0

        view = {
          bonusText = isRecentlyReleased ? loc("shop/unit_nation_bonus_tooltip/recentlyReleasedDays", { recentlyReleasedDays })
            : loc("shop/unit_nation_bonus_tooltip/bonus_amount", {bonusAmount = bonusData?[$"rank{params.rank}"] ?? 0})
          isRecentlyReleased
          battlesRemain
          unitName
          rangNum = loc("ui/parentheses", {text = loc("shop/age/num", {num = get_roman_numeral(rank)})})
          percents = loc("shop/unit_nation_bonus_tooltip/bonus_text", {percents = percetnsString})
        }
      }

      let data = handyman.renderCached("%gui/shop/nationBonusIconTooltip.tpl", view)
      obj.getScene().replaceContentFromText(obj, data, data.len(), handler)
      if (isOver)
        obj.findObject("over_timer").setUserData(this)
      return true
    }
  }
})

function showInObj(obj, id, val) {
  let tgtObj = obj.findObject(id)
  tgtObj.show(val)
  tgtObj.enable(val)
  return tgtObj
}

function updateProgressInObj(cell, id, progress, isPaused) {
  let obj = cell.findObject(id)
  let isVisible = progress >= 0
  obj.show(isVisible)
  if (!isVisible)
    return

  setBool(obj, "paused", isPaused)
  obj.setValue(progress)
}

function updateSector1InObj(cell, id, angle) {
  let obj = cell.findObject(id)
  if (angle != (obj.getFinalProp(sectorAngle1PID) ?? -1).tointeger()) {
    obj.set_prop_latent(sectorAngle1PID, angle)
    obj.updateRendElem()
  }
  return obj
}

function initCell(cell, initData, shiftY) {
  let { id, posX = 0, posY = 0, position = "relative" } = initData
  cell.pos = $"{posX}w, {posY - shiftY}h"
  cell.position = position

  let prevId = cell.holderId
  if (prevId == id)
    return
  cell.holderId = id
  cell.id = $"unitCell_{id}"
  let cardObj = cell.findObject(prevId)
  cardObj.id = id
  cardObj.title = showConsoleButtons.get() ? "" : "$tooltipObj"
  cardObj.findObject("mainActionButton").holderId = id
}

function updateCardStatus(obj, _id, statusTbl) {
  let {
    isGroup                   = false,
    unitName                  = "",
    unitImage                 = "",
    nameText                  = "",
    unitRarity                = "",
    unitClassIcon             = "",
    unitClass                 = "",
    isPkgDev                  = false,
    isRecentlyReleased        = false,
    tooltipId                 = "",
    hasActionsMenu            = false,
    shopStatus                = "",
    unitRankText              = "",
    isInactive                = false,
    isViewDisabled            = false,
    isBroken                  = false,
    isLocked                  = false,
    needInService             = false,
    isMounted                 = false,
    isElite                   = false,
    hasTalismanIcon           = false,
    isTalismanComplete        = true,
    weaponsStatus             = "",
    progressText              = "",
    progressStatus            = "",
    isResearchPaused          = false,
    researchProgressOld       = -1,
    researchProgressNew       = -1,
    priceText                 = "",
    primaryUnitId             = "", 
    mainButtonText            = "",
    mainButtonIcon            = "",
    maxRank                   = -1,
    discount                  = 0,
    expMul                    = 1.0,
    wpMul                     = 1.0,
    hasObjective              = false,
    rank                      = 0,
    unitTypeName              = "",
    hasNationBonus            = false,
    nationBonusBattlesRemain  = 0
    markerHolderId            = ""
    endResearchDate           = ""
    hasAlarmIcon              = false
  } = statusTbl
  let isLongPriceText = isUnitPriceTextLong(priceText)

  setBool(obj, "group", isGroup)
  obj.primaryUnitId = primaryUnitId
  obj.unit_name = unitName
  obj.shopStat = shopStatus
  obj.unitRarity = unitRarity
  setBool(obj, "isPkgDev", isPkgDev)
  setBool(obj, "isBroken", isBroken)
  setBool(obj, "refuseOpenHoverMenu", !hasActionsMenu || isGroup)
  setBool(obj, "isElite", isElite)
  setBool(obj, "isRecentlyReleased", isRecentlyReleased)
  setBool(obj, "hasAlarmIcon", hasAlarmIcon)
  obj["cursor"] = hasActionsMenu && !isGroup ? "context-menu" : "normal"

  obj.findObject("unitImage")["foreground-image"] = unitImage
  obj.findObject("unitTooltip").tooltipId = tooltipId
  if (showConsoleButtons.get())
    obj.tooltipId = tooltipId
  setBool(showInObj(obj, "talisman", hasTalismanIcon), "incomplete", !isTalismanComplete)
  setBool(showInObj(obj, "inServiceMark", needInService), "mounted", isMounted)
  setBool(obj, "actionOnDrag", needInService && !isGroup)
  showInObj(obj, "weaponStatusIcon", weaponsStatus != "").weaponsStatus = weaponsStatus
  showInObj(obj, "repairIcon", isBroken)

  let remainingMarkerObj = obj.findObject("remainingMarker")
  remainingMarkerObj.setValue(stashBhvValueConfig(
    { viewId = "SHOP_SLOT_REMAINING_TIME_UNIT", unitName = unitName }
  ))

  let newsMarkerObj = obj.findObject("newsMarker")
  newsMarkerObj.setValue(stashBhvValueConfig(
    { viewId = "SHOP_SLOT_NEWS_UNIT", unitName = isGroup ? obj.id : unitName }
  ))

  let eventMarkerObj = obj.findObject("eventMarker")
  eventMarkerObj.setValue(stashBhvValueConfig(
    { viewId = "SHOP_SLOT_EVENT_MARKER", unitName = isGroup ? obj.id : unitName }
  ))

  if (hasAlarmIcon)
    obj.findObject("alarm_icon").tooltip = loc("mainmenu/vehicleResearchTillDate",
      { time = buildDateStr(getTimestampFromStringUtc(endResearchDate)) })

  let markerContainer = obj.findObject("marker_container")
  let unlockMarker = markerContainer.findObject("unlockMarker")
  unlockMarker["isActive"] = hasObjective? "yes" : "no"
  if(hasObjective) {
    let holderId = isGroup ? markerHolderId : unitName
    let unlockName = getUnlockNameText(-1, getUnlockIdByUnitName(holderId, getCurrentGameModeEdiff()))
    unlockMarker.tooltip = loc("mainmenu/objectiveNameAvailable", { unlockName })
    unlockMarker.holderId = holderId
  }

  let nationBonus = showInObj(markerContainer, "nation_bonus_marker", hasNationBonus)
  let isNationBonusOver = nationBonusBattlesRemain <= 0
  nationBonus.isOver = (isNationBonusOver || isRecentlyReleased) ? "yes" : "no"

  if (hasNationBonus) {
    let tooltipObj = nationBonus.findObject("bonus_tooltip")
    tooltipObj.tooltipId = getTooltipType("SHOP_CELL_NATION_BONUS").getTooltipId("bonus", {
      battlesRemain = nationBonusBattlesRemain
      rank
      maxRank
      isOver = isNationBonusOver
      unitTypeName
      isRecentlyReleased
    })
  }

  let nameObj = obj.findObject("nameText")
  nameObj.setValue(nameText)
  setBool(nameObj, "disabled", isViewDisabled)

  let progressObj = obj.findObject("progressText")
  progressObj.setValue(progressText)
  progressObj.progressStatus = progressStatus

  updateProgressInObj(obj, "progressOld", researchProgressOld, isResearchPaused)
  updateProgressInObj(obj, "progressNew", researchProgressNew, isResearchPaused)

  let priceObj = obj.findObject("priceText")
  priceObj.setValue(priceText)
  setBool(priceObj, "tinyFont", isLongPriceText)

  let rankObj = obj.findObject("rankText")
  rankObj.setValue(unitRankText)
  setBool(rankObj, "tinyFont", isLongPriceText)
  setBool(rankObj, "locked", isLocked)

  let classPlace = showInObj(obj, "classIconPlace", unitClassIcon != "")
  if (unitClassIcon != "") {
    let classObj = classPlace.findObject("classIcon")
    classObj.setValue(unitClassIcon)
    classObj.shopItemType = unitClass
  }

  let hasMainButton = !isInactive && (mainButtonText != "" || mainButtonIcon != "")
    && (!showConsoleButtons.get() || isGroup)
  let mainBtnObj = obj.findObject("mainActionButton")
  setBool(mainBtnObj, "forceHide", !hasMainButton)
  if (hasMainButton) {
    mainBtnObj.setValue(mainButtonText)
    showInObj(mainBtnObj, "mainActionIcon", mainButtonIcon != "")["background-image"] = mainButtonIcon
  }

  let needDiscount = discount > 0
  let discountObj = markerContainer.findObject("unitDiscount")
  if (!needDiscount)
    discountObj.setValue("")
  else {
    discountObj.setValue($"-{discount}%")
    discountObj.tooltip = format(loc("discount/buy/tooltip"), discount.tostring())
  }

  let hasBonus = expMul > 1 || wpMul > 1
  let bonusObj = showInObj(obj, "unitBonusMark", hasBonus)
  if (hasBonus) {
    bonusObj.bonusType = expMul > 1 && wpMul > 1 ? "wp_exp"
      : expMul > 1 ? "exp"
      : "wp"
    bonusObj["background-image"] = getBonusImage("item", max(expMul, wpMul), "air")
    let locEnd = isGroup ? "/group/tooltip" : "/tooltip"
    let tooltipArr = []
    if (expMul > 1)
      tooltipArr.append(format(loc($"bonus/expitemAircraftMul{locEnd}"), $"x{expMul}"))
    if (wpMul > 1)
      tooltipArr.append(format(loc($"bonus/wpitemAircraftMul{locEnd}"), $"x{wpMul}"))
    bonusObj.tooltip = "\n".join(tooltipArr, true)
  }
}

function updateCellStatus(cell, statusTbl) {
  let { isInactive = false, isVisible = true, tooltipId = "" } = statusTbl
  setBool(cell, "inactive", isInactive)
  cell.enable(isVisible && !isInactive)
  cell.show(isVisible)
  if (!isVisible)
    return

  if (showConsoleButtons.get())
    cell.tooltipId = tooltipId
  let id = cell.holderId
  let cardObj = cell.findObject(id)
  updateCardStatus(cardObj, id, statusTbl)
}

function updateCellTimedStatusImpl(cell, timedTbl) {
  let { rentProgress = -1 } = timedTbl

  let rentIcon = showInObj(cell, "rentIcon", rentProgress >= 0)
  if (rentProgress >= 0)
    updateSector1InObj(rentIcon, "rentProgress", 360 - round(360.0 * rentProgress).tointeger())
}

let getUnitFixedParams = function(unit, params) {
  let { tooltipParams = {} } = params
  return {
    unitName            = unit.name
    unitImage           = image_for_air(unit)
    nameText            = getUnitName(unit)
    unitRarity          = getUnitRarity(unit)
    unitClassIcon       = getUnitRoleIcon(unit)
    unitClass           = getUnitRole(unit)
    isPkgDev            = unit.isPkgDev
    isRecentlyReleased  = unit.isRecentlyReleased()
    tooltipId           = getTooltipType("UNIT").getTooltipId(unit.name, tooltipParams)
    hasActionsMenu      = true
  }
}

function getUnitRankText(unit, showBR, ediff) {
  return getShopDevMode() && hasFeature("DevShopMode")
    ? getUnitDebugRankText(unit)
    : getUnitSlotRankText(unit, null, showBR, ediff)
}

let getUnitStatusTbl = function(unit, params) {
  let { shopResearchMode = false, forceNotInResearch = false, mainActionText = "",
    showBR = false, getEdiffFunc = getCurrentGameModeEdiff
  } = params

  let isOwn           = unit.isBought()
  let isUsable        = isUnitUsable(unit)
  let isUsableSlave   = unit.isUsableSlaveUnit()
  let isSpecial       = isUnitSpecial(unit)
  let bitStatus       = getBitStatus(unit, params)

  let res = {
    shopStatus          = getUnitItemStatusText(bitStatus, false)
    unitRankText        = getUnitRankText(unit, showBR, getEdiffFunc())
    isInactive          = (bit_unit_status.disabled & bitStatus) != 0
      || (shopResearchMode && (bit_unit_status.locked & bitStatus) != 0)
    isBroken            = isUnitBroken(unit)
    isLocked            = !isUsable && !isUsableSlave && !isSpecial && !unit.isSquadronVehicle()
      && !canBuyUnitOnMarketplace(unit) && !isUnitsEraUnlocked(unit) && !unit.isCrossPromo && !hasUnitEvent(unit.name)
    needInService       = isUsable
    isMounted           = isUsable && isUnitInSlotbar(unit)
    weaponsStatus       = getWeaponsStatusName(isUsable ? checkUnitWeapons(unit) : UNIT_WEAPONS_READY)
    isElite             = isOwn ? isUnitElite(unit) : isSpecial
    hasTalismanIcon     = isSpecial || shopIsModificationEnabled(unit.name, "premExpMul")
    priceText           = getUnitShopPriceText(unit)

    discount            = isOwn ? 0 : getUnitDiscount(unit)
    expMul              = wp_shop_get_aircraft_xp_rate(unit.name)
    wpMul               = wp_shop_get_aircraft_wp_rate(unit.name)
    hasObjective        = !shopResearchMode && (bit_unit_status.locked & bitStatus) == 0
      && hasMarkerByUnitName(unit.name, getEdiffFunc())
    endResearchDate     = unit.endResearchDate
    hasAlarmIcon        = unit.endResearchDate != null && !isOwn
  }

  if (canBuyNotResearched(unit)) {
    if(!is_in_clan()) {
      res.priceText = unit.getOpenCost().getTextAccordingToBalance()
      params.hideProgress <- getUnitExp(unit) > 0
    }
    else if(is_in_clan() && (bitStatus & bit_unit_status.inResearch) == 0 ) {
      res.priceText = unit.getOpenCost().getTextAccordingToBalance()
      params.hideProgress <- true
    }
  }

  if (forceNotInResearch || !isUnitInResearch(unit) || hasFeature("SpendGold")) 
    if (showConsoleButtons.get())
      res.mainButtonIcon <- "#ui/gameuiskin#slot_menu.svg"
    else
      res.mainButtonText <- mainActionText
  return res
}

function getUnitResearchStatusTbl(unit, params) {
  if(params?.hideProgress)
    return {}
  if (unit.isBought() || !canResearchUnit(unit))
    return {}
  let unitReqExp = getUnitReqExp(unit)
  if (unitReqExp <= 0)
    return {}

  let { forceNotInResearch = false, flushExp = 0, unitTypeName,
    nationBonusBattlesRemain, maxRank, hasNationBonus} = params

  let isVehicleInResearch = isUnitInResearch(unit) && !forceNotInResearch
  let isSquadronVehicle = unit.isSquadronVehicle()
  let unitCurExp = getUnitExp(unit)
  let diffExp = isSquadronVehicle ? min(clan_get_exp(), unitReqExp - unitCurExp) : 0
  let isLockedSquadronVehicle = isSquadronVehicle && !is_in_clan() && diffExp <= 0
  if (isLockedSquadronVehicle && unitCurExp <= 0)
    return {}

  let unitNewExp = unitCurExp + (isVehicleInResearch ? diffExp : 0)
  let isFull = isSquadronVehicle ? diffExp > 0 && unitNewExp >= unitReqExp
    : unitCurExp + flushExp >= unitReqExp

  return {
    progressText             =  isSquadronVehicle
      ? Cost().setSap(unitReqExp - unitCurExp).tostring()
      : Cost().setRp(unitReqExp - unitCurExp).tostring()

    progressStatus           = isFull ? "researched"
      : isVehicleInResearch ? "research"
      : ""

    isResearchPaused         = !isVehicleInResearch || isLockedSquadronVehicle
    researchProgressOld      = (1000.0 * unitCurExp / unitReqExp).tointeger()
    researchProgressNew      = (1000.0 * unitNewExp / unitReqExp).tointeger()
    hasNationBonus           = hasNationBonus && isVehicleInResearch && !isSquadronVehicle
    nationBonusBattlesRemain
    rank                     = unit?.rank ?? 0
    maxRank
    unitTypeName
  }
}

function getUnitTimedStatusTbl(unit) {
  let isRented = unit.isRented()
  let maxTime = isRented ? rented_units_get_last_max_full_rent_time(unit.name) : -1
  return {
    rentProgress = isRented
      ? unit.getRentTimeleft().tofloat() / (maxTime == 0 ? -1 : maxTime)
      : -1
    needUpdateByTime = isRented
  }
}

function getFakeUnitStatusTbl(unit, params) {
  let { showBR = false, getEdiffFunc = getCurrentGameModeEdiff } = params

  let nameForLoc = unit?.isReqForFakeUnit ? split_by_chars(unit.name, "_")?[0] : unit.name
  let { esUnitType } = unitTypes.getByName(unit.name, false)
  let isFakeAirRankOpen = get_units_count_at_rank(unit?.rank, esUnitType, unit?.country, true)
  let bitStatus = unit?.isReqForFakeUnit ? bit_unit_status.disabled
    : isFakeAirRankOpen ? bit_unit_status.owned
    : bit_unit_status.locked
  return {
    unitName             = unit.name
    unitImage            = unit.image
    nameText             = loc(unit?.nameLoc ?? $"mainmenu/type_{nameForLoc}")
    isInactive           = true
    shopStatus           = getUnitItemStatusText(bitStatus, true)
    unitRankText         = getUnitRankText(unit, showBR, getEdiffFunc())
    isViewDisabled       = bitStatus == bit_unit_status.disabled
  }
}

function getGroupStatusTbl(group, params) {
  let { forceNotInResearch = false, shopResearchMode = false, tooltipParams = {},
    showBR = false, getEdiffFunc = getCurrentGameModeEdiff
  } = params
  let unitsList = group.airsGroup

  local isInactive         = false
  local isGroupUsable      = false
  local isGroupInResearch  = false
  local isElite            = true
  local isPkgDev           = false
  local isRecentlyReleased = false
  local hasTalismanIcon    = false
  local isTalismanComplete = true
  local bitStatus          = 0
  local expMul             = 1.0
  local wpMul              = 1.0

  local mountedUnit        = null
  local firstUnboughtUnit  = null
  local researchingUnit    = null
  local rentedUnit         = null
  local hasObjective       = false
  local markerHolderId     = ""
  local hasAlarmIcon       = false

  foreach (unit in unitsList) {
    let isInResearch = !forceNotInResearch && isUnitInResearch(unit)
    let isUsable = isUnitUsable(unit)

    if (isInResearch || (canResearchUnit(unit) && !researchingUnit)) {
      researchingUnit = unit
      isGroupInResearch = isInResearch
    }
    else if (!isUsable && !firstUnboughtUnit && (canBuyUnit(unit) || canBuyUnitOnline(unit)))
      firstUnboughtUnit = unit

    if (isUsable) {
      if (isUnitInSlotbar(unit))
        mountedUnit = unit
      isGroupUsable = true
    }

    if (unit.isRented()) {
      if (!rentedUnit || unit.getRentTimeleft() <= rentedUnit.getRentTimeleft())
        rentedUnit = unit
    }

    let curBitStatus = getBitStatus(unit)
    bitStatus = bitStatus | curBitStatus
    isPkgDev = isPkgDev || unit.isPkgDev
    isRecentlyReleased = isRecentlyReleased || unit.isRecentlyReleased()
    isElite = isElite && isUnitElite(unit)
    let hasTalisman = isUnitSpecial(unit) || shopIsModificationEnabled(unit.name, "premExpMul")
    hasTalismanIcon = hasTalismanIcon || hasTalisman
    isTalismanComplete = isTalismanComplete && hasTalisman
    expMul = max(expMul, wp_shop_get_aircraft_xp_rate(unit.name))
    wpMul = max(wpMul, wp_shop_get_aircraft_wp_rate(unit.name))

    if (!hasObjective && !shopResearchMode
        && (bit_unit_status.locked & curBitStatus) == 0
        && hasMarkerByUnitName(unit.name, getEdiffFunc())) {
      hasObjective = true
      markerHolderId = unit.name
    }
  }

  if (shopResearchMode
      && !(bitStatus & (bit_unit_status.canBuy | bit_unit_status.inResearch | bit_unit_status.canResearch))) {
    if (!(bitStatus & bit_unit_status.locked))
      bitStatus = bit_unit_status.disabled
    isInactive = true
  }

  let primaryUnit = rentedUnit || mountedUnit || (isGroupInResearch && researchingUnit)
    || firstUnboughtUnit || unitsList[0]
  let needUnitNameOnPlate = rentedUnit != null || mountedUnit  != null
    || (isGroupInResearch && researchingUnit != null) || (firstUnboughtUnit != null && researchingUnit == null)
  let unitForBR = rentedUnit || researchingUnit || firstUnboughtUnit || group

  let researchStatusTbl = researchingUnit ? getUnitResearchStatusTbl(researchingUnit, params) : {}
  let unitImage = get_unit_preset_img(group.name)
    ?? (is_harmonized_unit_image_required(primaryUnit)
        ? get_tomoe_unit_icon(group.name, !group.name.endswith("_group"))
        : "!{0}".subst(group?.image ?? "#ui/unitskin#planes_group.ddsx"))

  return {
    
    isGroup             = true
    hasActionsMenu      = true
    isPkgDev,
    isRecentlyReleased,
    mainButtonIcon      = showConsoleButtons.get() ? "#ui/gameuiskin#slot_unfold.svg" : "",

    
    primaryUnitId       = primaryUnit.name,
    unitImage,
    nameText            = needUnitNameOnPlate ? getUnitName(primaryUnit) : loc($"shop/group/{group.name}")
    unitRarity          = getUnitRarity(primaryUnit)
    unitClassIcon       = getUnitRoleIcon(primaryUnit)
    unitClass           = getUnitRole(primaryUnit)
    tooltipId           = getTooltipType("UNIT").getTooltipId(primaryUnit.name, tooltipParams)

    
    shopStatus          = getUnitItemStatusText(bitStatus, true),
    unitRankText        = getUnitRankText(unitForBR, showBR, getEdiffFunc())
    isInactive,
    isBroken            = bitStatus & bit_unit_status.broken,
    isLocked            = !is_era_available(unitsList[0].shopCountry, unitsList[0].rank, getEsUnitType(unitsList[0])),
    needInService       = isGroupUsable
    isMounted           = mountedUnit != null,
    isElite,
    hasTalismanIcon,
    isTalismanComplete,
    priceText           = firstUnboughtUnit && !researchingUnit ? getUnitShopPriceText(firstUnboughtUnit) : "",

    discount            = firstUnboughtUnit ? getGroupDiscount(unitsList) : 0,
    hasObjective,
    markerHolderId,
    expMul,
    wpMul,
    hasAlarmIcon
  }.__update(researchStatusTbl)
}

function getGroupTimedStatusTbl(group) {
  local unit = null
  local rentLeft = 0
  foreach (u in group.airsGroup)
    if (u.isRented() && (!unit || rentLeft >= u.getRentTimeleft())) {
      unit = u
      rentLeft = u.getRentTimeleft()
    }
  if (unit == null)
    return { rentProgress = -1, needUpdateByTime = false }

  let maxTime = rented_units_get_last_max_full_rent_time(unit.name)
  return {
    rentProgress = maxTime == 0 ? -1 : maxTime
    needUpdateByTime = true
  }
}

let getStatusTbl = @(unitOrGroup, params) unitOrGroup == null ? { isVisible = false }
  : isUnitGroup(unitOrGroup) ? getGroupStatusTbl(unitOrGroup, params)
  : unitOrGroup?.isFakeUnit ? getFakeUnitStatusTbl(unitOrGroup, params)
  : getUnitStatusTbl(unitOrGroup, params)
      .__update(getUnitResearchStatusTbl(unitOrGroup, params))
      .__update(getUnitFixedParams(unitOrGroup, params))

let getTimedStatusTbl = @(unitOrGroup, _params) unitOrGroup == null ? {}
  : isUnitGroup(unitOrGroup) ? getGroupTimedStatusTbl(unitOrGroup)
  : unitOrGroup?.isFakeUnit ? {}
  : getUnitTimedStatusTbl(unitOrGroup)

function updateCellTimedStatus(cell, getTimedStatus) {
  local timedStatus = getTimedStatus()
  updateCellTimedStatusImpl(cell, timedStatus)
  if (!timedStatus?.needUpdateByTime)
    return

  let holderId = cell.holderId
  let cardObj = cell.findObject(holderId)
  SecondsUpdater(cardObj, function(_obj, _) {
    if (holderId != cell.holderId) 
      return true
    timedStatus = getTimedStatus()
    updateCellTimedStatusImpl(cell, timedStatus) 
    return !timedStatus?.needUpdateByTime
  })
}

return {
  getStatusTbl = getStatusTbl
  getTimedStatusTbl = getTimedStatusTbl
  updateCellStatus = updateCellStatus
  updateCellTimedStatus = updateCellTimedStatus
  initCell = initCell
  getUnitRankText = getUnitRankText
  expNewNationBonusDailyBattleCount
}