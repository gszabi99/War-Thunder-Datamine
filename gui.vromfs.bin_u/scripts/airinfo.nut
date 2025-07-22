from "%scripts/dagui_natives.nut" import wp_get_repair_cost_by_mode, shop_get_aircraft_hp, shop_get_free_repairs_used, wp_get_cost_gold, get_spare_aircrafts_count, wp_get_repair_cost, has_entitlement, get_name_by_gamemode, shop_purchase_aircraft, wp_get_cost, char_send_blk, clan_get_exp, get_global_stats_blk, shop_time_until_repair, is_era_available, shop_get_full_repair_time_by_mode, calculate_mod_or_weapon_effect
from "%scripts/dagui_library.nut" import *
from "%scripts/gameModes/gameModeConsts.nut" import BATTLE_TYPES
from "%scripts/clans/clanState.nut" import is_in_clan

let { g_difficulty, get_battle_type_by_ediff, get_difficulty_by_ediff } = require("%scripts/difficulty.nut")
let { Cost } = require("%scripts/money.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { isInMenu } = require("%scripts/clientState/clientStates.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { format } = require("string")
let { hangar_get_current_unit_name, force_retrace_decorators,
  hangar_force_reload_model } = require("hangar")
let SecondsUpdater = require("%sqDagui/timer/secondsUpdater.nut")
let time = require("%scripts/time.nut")
let { round, roundToDigits, round_by_value } = require("%sqstd/math.nut")
let { getUnitTooltipImage,
  getChanceToMeetText, getShipMaterialTexts, getUnitItemStatusText, getCantBuyUnitReason
  getUnitRarity, getCharacteristicActualValue } = require("%scripts/unit/unitInfoTexts.nut")
let { isUnitDefault, canResearchUnit, isUnitInResearch, isUnitGroup,
  isUnitResearched, isPrevUnitResearched, isPrevUnitBought
} = require("%scripts/unit/unitStatus.nut")
let { isUnitAvailableForGM } = require("%scripts/unit/unitInSlotbarStatus.nut")
let { getBitStatus } = require("%scripts/unit/unitBitStatus.nut")
let { check_unit_mods_update } = require("%scripts/unit/unitChecks.nut")
let countMeasure = require("%scripts/options/optionsMeasureUnits.nut").countMeasure
let { getCrewPoints } = require("%scripts/crew/crewSkills.nut")
let { getWeaponInfoText, makeWeaponInfoData } = require("%scripts/weaponry/weaponryDescription.nut")
let { getLastWeapon } = require("%scripts/weaponry/weaponryInfo.nut")
let { placePriceTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { getModificationByName } = require("%scripts/weaponry/modificationInfo.nut")
let { getActiveBoostersArray, getBoostersEffects } = require("%scripts/items/boosterEffect.nut")
let { boosterEffectType } = require("%scripts/items/boosterEffectTypes.nut")
let { NO_BONUS, PREM_ACC, PREM_MOD, BOOSTER } = require("%scripts/debriefing/rewardSources.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { havePremium } = require("%scripts/user/premium.nut")
let { getUnitMassPerSecValue, getUnitWeaponPresetsCount } = require("%scripts/unit/unitWeaponryInfo.nut")
let { fillPromUnitInfo } = require("%scripts/unit/remainingTimeUnit.nut")
let { approversUnitToPreviewLiveResource } = require("%scripts/customization/skins.nut")
let { getLocIdsArray } = require("%scripts/langUtils/localization.nut")
let { getGiftSparesCount, getGiftSparesCost } = require("%scripts/shop/giftSpares.nut")
let { shopIsModificationEnabled } = require("chardResearch")
let { getCountryFlagForUnitTooltip } = require("%scripts/options/countryFlagsPreset.nut")
let { getUnitName, getUnitCountryIcon, getUnitExp, getUnitRealCost, getUnitCost, getPrevUnit
} = require("%scripts/unit/unitInfo.nut")
let { getEsUnitType } = require("%scripts/unit/unitParams.nut")
let { canBuyUnit, isUnitGift, isUnitBought } = require("%scripts/unit/unitShopInfo.nut")
let { get_warpoints_blk, get_ranks_blk, get_unittags_blk } = require("blkGetters")
let { isInFlight } = require("gameplayBinding")
let { getCrewSpText } = require("%scripts/crew/crewPointsText.nut")
let { calcBattleRatingFromRank, isUnitSpecial, EDIFF_SHIFT } = require("%appGlobals/ranks_common_shared.nut")
let { isCrewAvailableInSession } = require("%scripts/respawn/respawnState.nut")
let { getCurMissionRules } = require("%scripts/misCustomRules/missionCustomState.nut")
let { buildUnitSlot, fillUnitSlotTimers } = require("%scripts/slotbar/slotbarView.nut")
let { getCrewUnlockTimeByUnit } = require("%scripts/slotbar/slotbarStateData.nut")
let { getCrewById } = require("%scripts/slotbar/crewsList.nut")
let { getCrewByAir } = require("%scripts/crew/crewInfo.nut")
let { getBestItemSpecialOfferByUnit } = require("%scripts/items/itemsManager.nut")
let { hideBonus } = require("%scripts/bonusModule.nut")
let { getCurrentGameModeEdiff } = require("%scripts/gameModes/gameModeManagerState.nut")
let { measureType } = require("%scripts/measureType.nut")
let { getCrewLevel, getCrewName, getCrewStatus } = require("%scripts/crew/crew.nut")
let { getFlapsDestructionIndSpeed, getGearDestructionIndSpeed, getWingPlaneStrength
} = require("%scripts/airLimits.nut")
let { getSpecTypeByCrewAndUnit } = require("%scripts/crew/crewSpecType.nut")
let { canBuyUnitOnline } = require("%scripts/unit/availabilityBuyOnline.nut")
let { MAX_COUNTRY_RANK } = require("%scripts/ranks.nut")
let { hasUnitCoupon } = require("%scripts/items/unitCoupons.nut")
let { showAirDiscount } = require("%scripts/discounts/discountUtils.nut")
let { skillParametersRequestType } = require("%scripts/crew/skillParametersRequestType.nut")
let { findWarbond } = require("%scripts/warbonds/warbondsManager.nut")
let { getNotAvailableUnitByBRText } = require("%scripts/matchingRooms/sessionLobbyInfo.nut")
let { getUnitRoleIconAndTypeCaption } = require("%scripts/unit/unitInfoRoles.nut")
let { getUnitDiscountByName } = require("%scripts/discounts/discountsState.nut")
let { canBuyUnitOnMarketplace } = require("%scripts/unit/canBuyUnitOnMarketplace.nut")

let usageRatingAmount = [0.0003, 0.0005, 0.001, 0.002]

function fillProgressBar(obj, curExp, newExp, maxExp, isPaused = false) {
  if (!checkObj(obj) || !maxExp)
    return

  let guiScene = obj.getScene()
  if (!guiScene)
    return

  guiScene.replaceContent(obj, "%gui/countryExpItem.blk", this)

  local barObj = obj.findObject("expProgressOld")
  if (checkObj(barObj)) {
    barObj.show(true)
    barObj.setValue(1000.0 * curExp / maxExp)
    barObj.paused = isPaused ? "yes" : "no"
  }

  barObj = obj.findObject("expProgress")
  if (checkObj(barObj)) {
    barObj.show(true)
    barObj.setValue(1000.0 * newExp / maxExp)
    barObj.paused = isPaused ? "yes" : "no"
  }
}



::isTestFlightAvailable <- function isTestFlightAvailable(unit, skipUnitCheck = false) {
  if (!isUnitAvailableForGM(unit, GM_TEST_FLIGHT) || unit.isSlave())
    return false

  if (unit.isUsable()
      || skipUnitCheck
      || canResearchUnit(unit)
      || isUnitGift(unit)
      || isUnitResearched(unit)
      || isUnitSpecial(unit)
      || approversUnitToPreviewLiveResource.value == unit
      || unit?.isSquadronVehicle?())
    return true

  return false
}


::updateAirAfterSwitchMod <- function updateAirAfterSwitchMod(air, modName = null) {
  if (!air)
    return

  if (air.name == hangar_get_current_unit_name() && modName) {
    let modsList = modName == "" ? air.modifications : [ getModificationByName(air, modName) ]
    foreach (mod in modsList) {
      if (!(mod?.requiresModelReload ?? false))
        continue
      hangar_force_reload_model()
      force_retrace_decorators()
      break
    }
  }

  if (!isUnitGroup(air))
    check_unit_mods_update(air, null, true)
}


::check_secondary_weapon_mods_recount <- function check_secondary_weapon_mods_recount(unit, callback = null) {
  let uType = getEsUnitType(unit)
  if (uType == ES_UNIT_TYPE_AIRCRAFT || uType == ES_UNIT_TYPE_HELICOPTER) {
    let weaponName = getLastWeapon(unit.name)
    local secondaryMods = unit.secondaryWeaponMods
    if (secondaryMods && secondaryMods.weaponName == weaponName) {
      if (secondaryMods.effect)
        return true
      if (callback)
        secondaryMods.callback = callback
      return false
    }

    unit.secondaryWeaponMods = {
      weaponName = weaponName
      effect = null
      callback = callback
    }

    calculate_mod_or_weapon_effect(unit.name, weaponName, false, this, function(effect, ...) {
      secondaryMods = unit.secondaryWeaponMods
      if (!secondaryMods || weaponName != secondaryMods.weaponName)
        return

      secondaryMods.effect <- effect || {}
      broadcastEvent("SecondWeaponModsUpdated", { unit = unit })
      if (secondaryMods.callback != null) {
        secondaryMods.callback()
        secondaryMods.callback = null
      }
    })
    return false
  }

  if (uType == ES_UNIT_TYPE_BOAT || uType == ES_UNIT_TYPE_SHIP) {
    let torpedoMod = "torpedoes_movement_mode"
    let mod = getModificationByName(unit, torpedoMod)
    if (!mod || mod?.effects)
      return true
    calculate_mod_or_weapon_effect(unit.name, torpedoMod, true, this, function(effect, ...) {
      mod.effects <- effect
      if (callback)
        callback()
      broadcastEvent("SecondWeaponModsUpdated", { unit = unit })
    })
    return false
  }
  return true
}


function getHighestRankDiffNoPenalty(inverse = false) {
  let ranksBlk = get_ranks_blk()
  let paramPrefix = inverse
    ? "expPenaltyPercentForLowerRank"
    : "expPenaltyPercentForHigherRank"

  for (local rankDif = 0; rankDif < MAX_COUNTRY_RANK; rankDif++)
    if (ranksBlk[$"{paramPrefix}{rankDif}"] > 20)
      return rankDif - 1
  return 0
}

function getMinBestLevelingRank(unit) {
  if (!unit)
    return -1

  let unitRank = unit?.rank ?? -1
  if (isUnitSpecial(unit) || unitRank == 1)
    return 1
  let result = unitRank - getHighestRankDiffNoPenalty(true)
  return result > 0 ? result : 1
}

function getMaxBestLevelingRank(unit) {
  if (!unit)
    return -1

  let unitRank = unit?.rank ?? -1
  if (unitRank == MAX_COUNTRY_RANK)
    return MAX_COUNTRY_RANK
  let result = unitRank + getHighestRankDiffNoPenalty()
  return result <= MAX_COUNTRY_RANK ? result : MAX_COUNTRY_RANK
}

function getBattleTypeByUnit(unit) {
  let esUnitType = getEsUnitType(unit)
  if (esUnitType == ES_UNIT_TYPE_TANK)
    return BATTLE_TYPES.TANK
  if (esUnitType == ES_UNIT_TYPE_SHIP || esUnitType == ES_UNIT_TYPE_BOAT)
    return BATTLE_TYPES.SHIP
  return BATTLE_TYPES.AIR
}

function getFontIconByBattleType(battleType) {
  if (battleType == BATTLE_TYPES.TANK)
    return loc("icon/unittype/tank")
  if (battleType == BATTLE_TYPES.SHIP)
    return loc("icon/unittype/ship")
  return loc("icon/unittype/aircraft")
}

function getTopCharacteristicValue(unit, item, diff) {
  let { crewMemberTopSkill, prepareTextFunc } = item
  let { crewMember, skill, parameter } = crewMemberTopSkill
  let params = skillParametersRequestType.MAX_VALUES.getParameters(-1, unit)
  let topValue = params?[diff][crewMember][skill][parameter]
  return topValue != null ? prepareTextFunc(topValue) : topValue
}

function setReferenceMarker(obj, vMin, vMax, refer, modeName) {
  if (!checkObj(obj))
    return

  let refMarkerObj = obj.findObject("aircraft-reference-marker")
  if (checkObj(refMarkerObj)) {
    if (vMin == vMax || (modeName == "arcade")) {
      refMarkerObj.show(false)
      return
    }

    refMarkerObj.show(true)
    let left = min((refer - vMin) / (vMax - vMin), 1)
    refMarkerObj.left = format("%.3fpw - 0.5w)", left)
  }
}

function fillAirCharProgress(progressObj, vMin, vMax, cur) {
  if (!checkObj(progressObj))
    return
  if (vMin == vMax)
    return progressObj.show(false)
  else
    progressObj.show(true)
  let value = ((cur - vMin) / (vMax - vMin)) * 1000.0
  progressObj.setValue(value)
}

function fillAirInfoTimers(holderObj, air, needShopInfo, needShowExpiredMessage = false) {
  SecondsUpdater(holderObj, function(obj, _params) {
    local isActive = false

    
    let hp = shop_get_aircraft_hp(air.name)
    let isBroken = hp >= 0 && hp < 1
    isActive = isActive || isBroken 
    let hpTrObj = obj.findObject("aircraft-condition-tr")
    if (hpTrObj)
      if (isBroken) {
        let timeStr = time.hoursToString(shop_time_until_repair(air.name), false, true)
        let hpText = "".concat(loc("shop/damaged"), loc("ui/parentheses/space", { text = timeStr }))
        hpTrObj.show(true)
        hpTrObj.findObject("aircraft-condition").setValue(hpText)
      }
      else
        hpTrObj.show(false)
    if (needShopInfo && isBroken && obj.findObject("aircraft-repair_cost-tr")) {
      let cost = wp_get_repair_cost(air.name)
      obj.findObject("aircraft-repair_cost-tr").show(cost > 0)
      obj.findObject("aircraft-repair_cost").setValue(Cost(cost).getTextAccordingToBalance())
    }

    
    let isRented = air.isRented()
    isActive = isActive || isRented
    let rentObj = obj.findObject("unit_rent_time")
    if (checkObj(rentObj)) {
      let sec = air.getRentTimeleft()
      let show = sec > 0
      local value = ""
      if (show) {
        let timeStr = time.hoursToString(time.secondsToHours(sec), false, true, true)
        value = colorize("goodTextColor", "".concat(loc("mainmenu/unitRentTimeleft"), loc("ui/colon"), timeStr))
      }
      if (rentObj.isVisible() != show)
        rentObj.show(show)
      if (show && rentObj.getValue() != value)
        rentObj.setValue(value)
    }


    
    let haveDiscount = getUnitDiscountByName(air.name)
    let specialOfferItem = haveDiscount > 0 ? getBestItemSpecialOfferByUnit(air) : null
    isActive = isActive || specialOfferItem != null
    let discountObj = obj.findObject("special_offer_time")
    if (checkObj(rentObj)) {
      let expireTimeText = specialOfferItem?.getExpireTimeTextShort() ?? ""
      let show = expireTimeText != ""
      discountObj.show(show)
      if (show)
        discountObj.setValue(colorize("goodTextColor", loc("specialOffer/TillTime", { time = expireTimeText })))
    }

    let unlockTime = isInMenu.get() ? getCrewUnlockTimeByUnit(air) : 0
    let needShowUnlockTime = unlockTime > 0
    let lockObj = showObjById("aircraft-lockedCrew", needShowUnlockTime, obj)
    if (needShowUnlockTime && lockObj)
      lockObj.findObject("time").setValue(time.secondsToString(unlockTime))
    isActive = isActive || needShowUnlockTime

    let needShowPromUnitInfo = needShopInfo && fillPromUnitInfo(holderObj, air, needShowExpiredMessage)
    isActive = isActive || needShowPromUnitInfo

    return !isActive
  })
}

function showAirInfo(air, show, holderObj = null, handler = null, params = null) {
  handler = handler || handlersManager.getActiveRootHandler()
  if (!checkObj(holderObj)) {
    if (holderObj != null)
      return

    if (handler)
      holderObj = handler.scene.findObject("slot_info")
    if (!checkObj(holderObj))
      return
  }

  holderObj.show(show)
  if (!show || !air)
    return

  local topValueCount = 0

  let spare_cost = getGiftSparesCost(air)

  let tableObj = holderObj.findObject("air_info_panel_table")
  if (checkObj(tableObj)) {
    let isShowProgress = isInArray(air.esUnitType, [ ES_UNIT_TYPE_AIRCRAFT, ES_UNIT_TYPE_HELICOPTER ])
    tableObj["showStatsProgress"] = isShowProgress ? "yes" : "no"
  }

  let isSlave = air.isSlave()
  let bitStatus = getBitStatus(air, params)
  holderObj.shopStat = getUnitItemStatusText(bitStatus, false)
  holderObj.unitRarity = getUnitRarity(air)

  let {needCrewModificators = false, needCrewInfo = false, rentTimeHours = -1, isReceivedPrizes = false,
    researchExpInvest = 0, numSpares = 0, needShowExpiredMessage = false, showInFlightInfo = true} = params

  let showLocalState = (params?.showLocalState ?? true) && !isSlave
  let needShopInfo = (params?.needShopInfo ?? false) && !isSlave
  let needUnitReqInfo = (params?.needShopInfo ?? false)
  let hideRepairInfo = isSlave || (params?.hideRepairInfo ?? false)
  let warbondId = params?.wbId
  let getEdiffFunc = handler?.getCurrentEdiff
  let ediff = getEdiffFunc ? getEdiffFunc.call(handler) : getCurrentGameModeEdiff()
  let difficulty = get_difficulty_by_ediff(ediff)
  let diffCode = difficulty.diffCode

  let unitType = getEsUnitType(air)
  let crew = params?.crewId != null ? getCrewById(params.crewId) : getCrewByAir(air)
  let isOwn = isUnitBought(air)
  let special = isUnitSpecial(air)
  let cost = wp_get_cost(air.name)
  let costGold = wp_get_cost_gold(air.name)
  let aircraftPrice = special ? costGold : cost
  let gift = isUnitGift(air)
  let showPrice = showLocalState && !isOwn && aircraftPrice > 0 && !gift && warbondId == null
  let isResearched = isUnitResearched(air)
  let canResearch = !isSlave && canResearchUnit(air)
  let rBlk = get_ranks_blk()
  let wBlk = get_warpoints_blk()

  let isRented = air.isRented()
  let showAsRent = (showLocalState && isRented) || rentTimeHours > 0
  let isSquadronVehicle = air.isSquadronVehicle()
  let isInClan = is_in_clan()
  let expCur = getUnitExp(air)
  let showShortestUnitInfo = params?.showShortestUnitInfo ?? air.showShortestUnitInfo

  let isSecondaryModsValid = check_unit_mods_update(air)
    && ::check_secondary_weapon_mods_recount(air)

  local obj = holderObj.findObject("aircraft-name")
  if (checkObj(obj))
    obj.setValue(getUnitName(air.name, false))

  obj = holderObj.findObject("aircraft-type")
  if (checkObj(obj)) {
    let typeText = getUnitRoleIconAndTypeCaption(air)
    obj.show(typeText != "")
    obj.setValue(typeText)
  }

  obj = holderObj.findObject("player_country_exp")
  if (checkObj(obj)) {
    obj.show(showLocalState && canResearch)
    if (showLocalState && canResearch) {
      if (isSquadronVehicle)
        obj.isForSquadVehicle = "yes"
      let expTotal = air.reqExp
      let expInvest = isSquadronVehicle
        ? min(clan_get_exp(), expTotal - expCur)
        : researchExpInvest
      let isResearching = isUnitInResearch(air) && (!isSquadronVehicle || isInClan || expInvest > 0)

      fillProgressBar(obj,
        isSquadronVehicle && isResearching ? expCur : expCur - expInvest,
        isSquadronVehicle && isResearching ? expCur + expInvest : expCur,
        expTotal, !isResearching)

      let labelObj = obj.findObject("exp")
      if (checkObj(labelObj)) {
        let statusText = isResearching ? "".concat(loc("shop/in_research"), loc("ui/colon")) : ""
        let expCurText = isSquadronVehicle
          ? Cost().setSap(expCur).toStringWithParams({ isSapAlwaysShown = true })
          : Cost().setRp(expCur).toStringWithParams({ isRpAlwaysShown = true })
        local expText = format("%s%s%s%s",
          statusText,
          expCurText,
          loc("ui/slash"),
          isSquadronVehicle ? Cost().setSap(expTotal).tostring() : Cost().setRp(expTotal).tostring())
        expText = colorize(isResearching ? "cardProgressTextColor" : "commonTextColor", expText)
        if (isResearching && expInvest > 0)
          expText = "".concat(expText, colorize(isSquadronVehicle
            ? "cardProgressChangeSquadronColor"
            : "cardProgressTextBonusColor", loc("ui/parentheses/space",
            { text = "".concat("+ ", (isSquadronVehicle
              ? Cost().setSap(expInvest).tostring()
              : Cost().setRp(expInvest).tostring())) })))
        labelObj.setValue(expText)
      }
    }
  }

  obj = showObjById("aircraft-countryImg", !showShortestUnitInfo, holderObj)
  if (checkObj(obj) && !showShortestUnitInfo) {
    obj["background-image"] = getUnitCountryIcon(air, true)
    obj["tooltip"] = "".concat(loc("shop/unitCountry/operator"), loc("ui/colon"), loc(air.getOperatorCountry()),
      "\n", loc("shop/unitCountry/research"), loc("ui/colon"), loc(air.shopCountry))
  }

  if (hasFeature("UnitTooltipImage")) {
    obj = holderObj.findObject("aircraft-image-nest")
    if (obj?.isValid() ?? false) {
      obj.findObject("aircraft-image")["background-image"] = getUnitTooltipImage(air)
      let countryImage = showObjById("country-image", !showShortestUnitInfo, obj)
      if (!showShortestUnitInfo)
        countryImage["background-image"] = getCountryFlagForUnitTooltip(air.getOperatorCountry())
    }
  }

  if (showShortestUnitInfo)
    return

  showObjById("aircraft-country_and_level-tr", true, holderObj)
  showObjById("aircraft-tooltip-info", true, holderObj)

  let ageObj = holderObj.findObject("aircraft-age")
  if (checkObj(ageObj)) {
    let nameObj = ageObj.findObject("age_number")
    if (checkObj(nameObj))
      nameObj.setValue("".concat(loc("shop/age"), loc("ui/colon")))
    let yearsObj = ageObj.findObject("age_years")
    if (checkObj(yearsObj))
      yearsObj.setValue(get_roman_numeral(air.rank))
  }

  
  let showBr = !air.hideBrForVehicle
  let battleRating = air.getBattleRating(ediff)
  let brObj = showObjById("aircraft-battle_rating", showBr, holderObj)
  if (showBr) {
    brObj.findObject("aircraft-battle_rating-header").setValue($"{loc("shop/battle_rating")}{loc("ui/colon")}")
    brObj.findObject("aircraft-battle_rating-value").setValue(format("%.1f", air.getBattleRating(ediff)))
  }
  let battleRatingByBattleTypeTable = {}
  foreach (battleTypeIter in BATTLE_TYPES) {
    let battleRatingByBattleType = air.getBattleRating(ediff % EDIFF_SHIFT + EDIFF_SHIFT * battleTypeIter)
    let isShipHardcore = (battleTypeIter == 2) && (difficulty == g_difficulty.SIMULATOR) 
    if (battleRatingByBattleType != battleRating && !isShipHardcore) {
      battleRatingByBattleTypeTable[battleTypeIter] <- battleRatingByBattleType
    }
  }
  let hasBattleRatingByTypes = battleRatingByBattleTypeTable.len() > 0
  let brByTypeObj = showObjById("aircraft-battle_rating-value_by_battle_types", hasBattleRatingByTypes, brObj)
  if (hasBattleRatingByTypes) {
    local battleRatingByBattleTypesStrArr = []
    battleRatingByBattleTypeTable.each(@(bRating, bType) battleRatingByBattleTypesStrArr.append(
      $"{getFontIconByBattleType(bType)} {format("%.1f", bRating)}")
    )
    let battleRatingByBattleTypesStr = loc("ui/parentheses/space",
      { text = loc("ui/vertical_bar").join(battleRatingByBattleTypesStrArr, true)}
    )
    brByTypeObj.setValue(battleRatingByBattleTypesStr)
  }

  let meetObj = holderObj.findObject("aircraft-chance_to_met_tr")
  if (checkObj(meetObj)) {
    local erCompare = params?.economicRankCompare
    if (erCompare != null) {
      if (type(erCompare) == "table")
        erCompare = erCompare?[air.shopCountry] ?? 0.0
      let text = getChanceToMeetText(battleRating, calcBattleRatingFromRank(erCompare))
      meetObj.findObject("aircraft-chance_to_met").setValue(text)
    }
    meetObj.show(erCompare != null)
  }

  if (showLocalState && (canResearch || (!isOwn && !special && !gift))) {
    let prevUnitObj = holderObj.findObject("aircraft-prevUnit_bonus_tr")
    let prevUnit = getPrevUnit(air)
    if(checkObj(prevUnitObj)) {
      prevUnitObj.show(prevUnit != null)
      if (prevUnit) {
        let tdNameObj = prevUnitObj.findObject("aircraft-prevUnit")
        if (checkObj(tdNameObj))
          tdNameObj.setValue(format(loc("shop/prevUnitEfficiencyResearch"), getUnitName(prevUnit, true)))
        let tdValueObj = prevUnitObj.findObject("aircraft-prevUnit_bonus")
        if (checkObj(tdValueObj)) {
          let childParamName = $"expBonusPercentForChildForMode{diffCode}"
          let childBonusPercent = rBlk?[childParamName] ?? 0

          if (childBonusPercent > 0)
            tdValueObj.setValue(colorize("userlogColoredText", $"{childBonusPercent + 100}%"))
          else
            prevUnitObj.show(false)
        }
      }
    }
  }
  else
    showObjById("aircraft-prevUnit_bonus_tr", false, holderObj)

  let rpObj = holderObj.findObject("aircraft-require_rp_tr")
  if (checkObj(rpObj)) {
    let showRpReq = showLocalState && !isOwn && !special && !gift && !isResearched && !canResearch
    rpObj.show(showRpReq)
    if (showRpReq)
      rpObj.findObject("aircraft-require_rp").setValue(Cost().setRp(air.reqExp).tostring())
  }

  if (showPrice) {
    let priceObj = holderObj.findObject("aircraft-price-tr")
    if (priceObj) {
      priceObj.show(true)
      holderObj.findObject("aircraft-price").setValue(Cost(cost, costGold).getTextAccordingToBalance())
    }
  }

  let modCharacteristics = {
    [ES_UNIT_TYPE_AIRCRAFT] = [
      { id = "maxSpeed", id2 = "speed", prepareTextFunc = @(value) countMeasure(0, value) },
      { id = "turnTime", id2 = "virage", prepareTextFunc = function(value) { return format("%.1f %s", value, loc("measureUnits/seconds")) } },
      { id = "climbSpeed", id2 = "climb", prepareTextFunc = @(value) countMeasure(3, value) }
    ],
    [ES_UNIT_TYPE_TANK] = [
      { id = "mass", id2 = "mass", prepareTextFunc = function(value) { return format("%.1f %s", (value / 1000.0), loc("measureUnits/ton")) } },
      { id = "maxSpeed", id2 = "maxSpeed", prepareTextFunc = @(value) countMeasure(0, value) },
      { id = "turnTurretTime", id2 = "turnTurretSpeed", prepareTextFunc = function(value) { return format("%.1f%s", value.tofloat(), loc("measureUnits/deg_per_sec")) },
        crewMemberTopSkill = { crewMember = "tank_gunner" , skill = "tracking", parameter = "turnTurretSpeed" } }
    ],
    [ES_UNIT_TYPE_BOAT] = [
      
      { id = "maxSpeed", id2 = "maxSpeed", prepareTextFunc = @(value) countMeasure(0, value) }
    ],
    [ES_UNIT_TYPE_SHIP] = [
      
      { id = "maxSpeed", id2 = "maxSpeed", prepareTextFunc = @(value) countMeasure(0, value) }
    ],
    [ES_UNIT_TYPE_HELICOPTER] = [
      { id = "maxSpeed", id2 = "speed", prepareTextFunc = @(value) countMeasure(0, value) }
      { id = "climbSpeed", id2 = "climb", prepareTextFunc = @(value) countMeasure(3, value) }
    ]
  }

  local showReferenceText = false
  foreach (item in (modCharacteristics?[unitType] ?? {})) {
    let characteristicArr = getCharacteristicActualValue(air, [item.id, item.id2],
      item.prepareTextFunc, difficulty.crewSkillName, showLocalState || needCrewModificators)

    holderObj.findObject($"aircraft-{item.id}").setValue(characteristicArr[0])

    if(item?.crewMemberTopSkill != null) {
      let topValue = getTopCharacteristicValue(air, item, difficulty.crewSkillName)
      let hasTopValue = topValue != null && topValue != characteristicArr[0]
      holderObj.findObject($"aircraft-{item.id}-topValueDiv").show(hasTopValue)
      if(hasTopValue) {
        holderObj.findObject($"aircraft-{item.id}-topValue").setValue(topValue)
        topValueCount++
      }
    }

    if (!showLocalState && !needCrewModificators)
      continue

    let wmodObj = holderObj.findObject($"aircraft-weaponmod-{item.id}")
    if (wmodObj)
      wmodObj.setValue(characteristicArr[1])

    let progressObj = holderObj.findObject($"aircraft-progress-{item.id}")
    setReferenceMarker(progressObj, characteristicArr[2], characteristicArr[3], characteristicArr[5], difficulty.crewSkillName)
    fillAirCharProgress(progressObj, characteristicArr[2], characteristicArr[3], characteristicArr[4])
    showReferenceText = showReferenceText || characteristicArr[6]

    let waitObj = holderObj.findObject($"aircraft-{item.id}-wait")
    if (waitObj)
      waitObj.show(!isSecondaryModsValid)
  }
  let refTextObj = holderObj.findObject("references_text")
  if (checkObj(refTextObj))
    refTextObj.show(showReferenceText)

  holderObj.findObject("aircraft-speedAlt").setValue((air.shop?.maxSpeedAlt ?? 0) > 0 ?
    countMeasure(1, air.shop.maxSpeedAlt) : loc("shop/max_speed_alt_sea"))
  
  
  holderObj.findObject("aircraft-altitude").setValue(countMeasure(1, air.shop.maxAltitude))
  holderObj.findObject("aircraft-airfieldLen").setValue(countMeasure(1, air.shop.airfieldLen))
  holderObj.findObject("aircraft-wingLoading").setValue(countMeasure(5, air.shop.wingLoading))
  

  let totalCrewObj = holderObj.findObject("total-crew")
  if (checkObj(totalCrewObj))
    totalCrewObj.setValue(air.getCrewTotalCount().tostring())

  let cardAirplaneWingLoadingParameter = hasFeature("CardAirplaneWingLoadingParameter")
  let cardAirplanePowerParameter = hasFeature("CardAirplanePowerParameter")
  let cardHelicopterClimbParameter = hasFeature("CardHelicopterClimbParameter")

  let showCharacteristics = {
    ["aircraft-turnTurretTime-tr"]           = [ ES_UNIT_TYPE_TANK ],
    ["aircraft-angleVerticalGuidance-tr"]    = [ ES_UNIT_TYPE_TANK ],
    ["aircraft-shotFreq-tr"]                 = [ ES_UNIT_TYPE_TANK ],
    ["aircraft-reloadTime-tr"]               = [ ES_UNIT_TYPE_TANK ],
    ["aircraft-weaponPresets-tr"]            = [ ES_UNIT_TYPE_AIRCRAFT, ES_UNIT_TYPE_HELICOPTER ],
    ["aircraft-massPerSec-tr"]               = [ ES_UNIT_TYPE_AIRCRAFT, ES_UNIT_TYPE_HELICOPTER ],
    ["aircraft-armorThicknessHull-tr"]       = [ ES_UNIT_TYPE_TANK ],
    ["aircraft-armorThicknessTurret-tr"]     = [ ES_UNIT_TYPE_TANK ],
    ["aircraft-armorPiercing-tr"]            = [ ES_UNIT_TYPE_TANK ],
    ["aircraft-armorPiercingDist-tr"]        = [ ES_UNIT_TYPE_TANK ],
    ["aircraft-mass-tr"]                     = [ ES_UNIT_TYPE_TANK ],
    ["aircraft-horsePowers-tr"]              = [ ES_UNIT_TYPE_TANK ],
    ["aircraft-maxSpeed-tr"]                 = [ ES_UNIT_TYPE_AIRCRAFT, ES_UNIT_TYPE_TANK,
                                                 ES_UNIT_TYPE_BOAT, ES_UNIT_TYPE_SHIP, ES_UNIT_TYPE_HELICOPTER ],
    ["aircraft-maxDepth-tr"]                 = [ ES_UNIT_TYPE_BOAT, ES_UNIT_TYPE_SHIP ],
    ["aircraft-speedAlt-tr"]                 = [ ES_UNIT_TYPE_AIRCRAFT, ES_UNIT_TYPE_HELICOPTER ],
    ["aircraft-altitude-tr"]                 = [ ES_UNIT_TYPE_AIRCRAFT, ES_UNIT_TYPE_HELICOPTER ],
    ["aircraft-turnTime-tr"]                 = [ ES_UNIT_TYPE_AIRCRAFT ],
    ["aircraft-climbSpeed-tr"]               = cardHelicopterClimbParameter ? [ ES_UNIT_TYPE_AIRCRAFT, ES_UNIT_TYPE_HELICOPTER ] : [ ES_UNIT_TYPE_AIRCRAFT ],
    ["aircraft-airfieldLen-tr"]              = [ ES_UNIT_TYPE_AIRCRAFT ],
    ["aircraft-wingLoading-tr"]              = cardAirplaneWingLoadingParameter ? [ ES_UNIT_TYPE_AIRCRAFT ] : [],
    ["aircraft-visibilityFactor-tr"]         = [ ES_UNIT_TYPE_TANK ],
    ["aircraft-wingPlaneStrengthVne-tr"]     = [ ES_UNIT_TYPE_AIRCRAFT ],
    ["aircraft-wingPlaneStrengthMne-tr"]     = [ ES_UNIT_TYPE_AIRCRAFT ],
    ["aircraft-gearDestructionIndSpeed-tr"]  = [ ES_UNIT_TYPE_AIRCRAFT ],
    ["aircraft-flapsDestructionIndSpeed-tr"] = [ ES_UNIT_TYPE_AIRCRAFT ],
  }

  foreach (rowId, showForTypes in showCharacteristics) {
    let rowObj = holderObj.findObject(rowId)
    if (rowObj)
      rowObj.show(isInArray(unitType, showForTypes))
  }

  let powerToWeightRatioObject = holderObj.findObject("aircraft-powerToWeightRatio-tr")
  if (cardAirplanePowerParameter
    && isInArray(unitType, [ES_UNIT_TYPE_AIRCRAFT, ES_UNIT_TYPE_HELICOPTER])
    && "powerToWeightRatio" in air.shop) {
    holderObj.findObject("aircraft-powerToWeightRatio").setValue(countMeasure(6, air.shop.powerToWeightRatio))
    powerToWeightRatioObject.show(true)
  }
  else
    powerToWeightRatioObject.show(false)

  let thrustToWeightRatioObject = holderObj.findObject("aircraft-thrustToWeightRatio-tr")
  if (cardAirplanePowerParameter && unitType == ES_UNIT_TYPE_AIRCRAFT && air.shop?.thrustToWeightRatio) {
    holderObj.findObject("aircraft-thrustToWeightRatio").setValue(format("%.2f", air.shop.thrustToWeightRatio))
    thrustToWeightRatioObject.show(true)
  }
  else
    thrustToWeightRatioObject.show(false)

  if (unitType == ES_UNIT_TYPE_AIRCRAFT) {
    let wingPlaneStrengthVneObj = holderObj.findObject("aircraft-wingPlaneStrengthVne-tr")
    if (wingPlaneStrengthVneObj?.isValid() ?? false) {
      let wingPlaneStrengthMneObj = holderObj.findObject("aircraft-wingPlaneStrengthMne-tr")
      let wingPlaneStrength = getWingPlaneStrength(air)
      let hasWingPlaneStrength = wingPlaneStrength != null
      if (hasWingPlaneStrength) {
        if (wingPlaneStrength.len() == 1) {
          let { vne, mne } = wingPlaneStrength[0]
          let planeStrengthVne = measureType.SPEED.getMeasureUnitsText(vne / 3.6)
          holderObj.findObject("aircraft-wingPlaneStrengthVne").setValue(planeStrengthVne)
          holderObj.findObject("aircraft-wingPlaneStrengthMne").setValue($"{round_by_value(mne, 0.01)}")
        }
        else {
          let vneMin = measureType.SPEED.getMeasureUnitsText(wingPlaneStrength[0].vne / 3.6, false)
          let vneMax = measureType.SPEED.getMeasureUnitsText(wingPlaneStrength[1].vne / 3.6)
          holderObj.findObject("aircraft-wingPlaneStrengthVne").setValue($"{vneMin}/{vneMax}")
          let mneMin = wingPlaneStrength[0].mne
          let mneMax = wingPlaneStrength[1].mne
          holderObj.findObject("aircraft-wingPlaneStrengthMne").setValue($"{round_by_value(mneMin, 0.01)}/{round_by_value(mneMax, 0.01)}")
        }
      }
      wingPlaneStrengthVneObj.show(hasWingPlaneStrength)
      wingPlaneStrengthMneObj.show(hasWingPlaneStrength)
    }

    let gearDestructionIndSpeedObj = holderObj.findObject("aircraft-gearDestructionIndSpeed-tr")
    if (gearDestructionIndSpeedObj?.isValid() ?? false) {
      let gearDestructionIndSpeed = getGearDestructionIndSpeed(air)
      let hasGearDestructionIndSpeed = gearDestructionIndSpeed != -1
      if (hasGearDestructionIndSpeed) {
        let destructionSpeed = measureType.SPEED.getMeasureUnitsText(gearDestructionIndSpeed / 3.6)
        holderObj.findObject("aircraft-gearDestructionIndSpeed").setValue(destructionSpeed)
      }
      gearDestructionIndSpeedObj.show(hasGearDestructionIndSpeed)
    }

    let flapsDestructionIndSpeedObj = holderObj.findObject("aircraft-flapsDestructionIndSpeed-tr")
    if (flapsDestructionIndSpeedObj?.isValid() ?? false) {
      let flapsDestructionIndSpeed = getFlapsDestructionIndSpeed(air)
      let hasFlapsDestructionIndSpeed = flapsDestructionIndSpeed != -1
      if (hasFlapsDestructionIndSpeed) {
        let destructionSpeed = measureType.SPEED.getMeasureUnitsText(flapsDestructionIndSpeed / 3.6)
        holderObj.findObject("aircraft-flapsDestructionIndSpeed").setValue(destructionSpeed)
      }
      flapsDestructionIndSpeedObj.show(hasFlapsDestructionIndSpeed)
    }
  }

  let modificators = (showLocalState || needCrewModificators) ? "modificators" : "modificatorsBase"
  if (air.isTank() && air[modificators]) {
    let currentParams = air[modificators][difficulty.crewSkillName]
    let horsePowers = currentParams.horsePowers;
    let horsePowersRPM = currentParams.maxHorsePowersRPM;
    holderObj.findObject("aircraft-horsePowers").setValue(
      format("%s %s %d %s", measureType.HORSEPOWERS.getMeasureUnitsText(horsePowers),
        loc("shop/unitValidCondition"), horsePowersRPM.tointeger(), loc("measureUnits/rpm")))
    local thickness = currentParams.armorThicknessHull;
    holderObj.findObject("aircraft-armorThicknessHull").setValue(format("%d / %d / %d %s", thickness[0].tointeger(), thickness[1].tointeger(), thickness[2].tointeger(), loc("measureUnits/mm")))
    thickness = currentParams.armorThicknessTurret;
    holderObj.findObject("aircraft-armorThicknessTurret").setValue(format("%d / %d / %d %s", thickness[0].tointeger(), thickness[1].tointeger(), thickness[2].tointeger(), loc("measureUnits/mm")))
    let angles = currentParams.angleVerticalGuidance;
    let [minAngle, maxAngle] = angles
    let minAngleStr = minAngle == 0 ? "0" : format("%.1f", minAngle)
    let maxAngleStr = maxAngle == 0 ? "0" : format("+%.1f", maxAngle)
    holderObj.findObject("aircraft-angleVerticalGuidance").setValue("".concat(minAngleStr, " / ", maxAngleStr, loc("measureUnits/deg")))
    let armorPiercing = currentParams.armorPiercing;
    if (armorPiercing.len() > 0) {
      let textParts = []
      local countOutputValue = min(armorPiercing.len(), 3)
      for (local i = 0; i < countOutputValue; i++)
        textParts.append(round(armorPiercing[i]).tointeger())
      holderObj.findObject("aircraft-armorPiercing").setValue(format("%s %s", " / ".join(textParts, true), loc("measureUnits/mm")))
      let armorPiercingDist = currentParams.armorPiercingDist;
      textParts.clear()
      countOutputValue = min(armorPiercingDist.len(), 3)
      for (local i = 0; i < countOutputValue; i++)
        textParts.append(armorPiercingDist[i].tointeger())
      holderObj.findObject("aircraft-armorPiercingDist").setValue(format("%s %s", " / ".join(textParts, true), loc("measureUnits/meters_alt")))
    }
    else {
      holderObj.findObject("aircraft-armorPiercing-tr").show(false)
      holderObj.findObject("aircraft-armorPiercingDist-tr").show(false)
    }

    let shotFreq = ("shotFreq" in currentParams && currentParams.shotFreq > 0) ? currentParams.shotFreq : null;

    let loader = skillParametersRequestType.CURRENT_VALUES.getParameters(crew?.id ?? -1, air)[difficulty.crewSkillName]?.loader
    let reloadTime = loader?["loading_time_mult"]["tankLoderReloadingTime"]

    let visibilityFactor = ("visibilityFactor" in currentParams && currentParams.visibilityFactor > 0) ? currentParams.visibilityFactor : null;

    holderObj.findObject("aircraft-shotFreq-tr").show(shotFreq);
    holderObj.findObject("aircraft-reloadTime-tr").show(reloadTime);
    holderObj.findObject("aircraft-visibilityFactor-tr").show(visibilityFactor);
    if (shotFreq) {
      let val = roundToDigits(shotFreq * 60, 3).tostring()
      holderObj.findObject("aircraft-shotFreq").setValue(format("%s %s", val, loc("measureUnits/shotPerMinute")))
    }
    if (reloadTime) {
      let prepareTextFunc = @(value) format("%.1f %s", value, loc("measureUnits/seconds"))
      let reloadTimeTxt = prepareTextFunc(round_by_value(reloadTime, 0.1))
      holderObj.findObject("aircraft-reloadTime").setValue(reloadTimeTxt)

      let crewMemberTopSkill = {
        crewMember = "loader"
        skill = "loading_time_mult"
        parameter = "tankLoderReloadingTime"
      }

      let topValue = getTopCharacteristicValue(air, { crewMemberTopSkill, prepareTextFunc }, difficulty.crewSkillName)
      let hasTopValue = topValue != null && topValue != reloadTimeTxt
      holderObj.findObject("aircraft-reloadTime-topValueDiv").show(hasTopValue)
      if(hasTopValue) {
        holderObj.findObject("aircraft-reloadTime-topValue").setValue(topValue)
        topValueCount++
      }
    }
    if (visibilityFactor) {
      holderObj.findObject("aircraft-visibilityFactor-title").setValue("".concat(loc("shop/visibilityFactor"), loc("ui/colon")))
      holderObj.findObject("aircraft-visibilityFactor-value").setValue(format("%d %%", visibilityFactor))
    }
  }

  if (unitType == ES_UNIT_TYPE_SHIP || unitType == ES_UNIT_TYPE_BOAT) {
    let unitTags = get_unittags_blk()?[air.name] ?? {}

    
    let displacementKilos = unitTags?.Shop.displacement
    holderObj.findObject("ship-displacement-tr").show(displacementKilos != null)
    if (displacementKilos != null) {
      let displacementString = measureType.SHIP_DISPLACEMENT_TON.getMeasureUnitsText(displacementKilos / 1000, true)
      holderObj.findObject("ship-displacement-title").setValue("".concat(loc("info/ship/displacement"), loc("ui/colon")))
      holderObj.findObject("ship-displacement-value").setValue(displacementString)
    }

    
    let depthValue = unitTags?.Shop.maxDepth ?? 0
    holderObj.findObject("aircraft-maxDepth-tr").show(depthValue > 0)
    if (depthValue > 0)
      holderObj.findObject("aircraft-maxDepth").setValue("".concat(depthValue, loc("measureUnits/meters_alt")))

    
    let armorThicknessCitadel = unitTags?.Shop.armorThicknessCitadel
    holderObj.findObject("ship-citadelArmor-tr").show(armorThicknessCitadel != null)
    if (armorThicknessCitadel != null) {
      let val = [
        round(armorThicknessCitadel.x).tointeger(),
        round(armorThicknessCitadel.y).tointeger(),
        round(armorThicknessCitadel.z).tointeger(),
      ]
      holderObj.findObject("ship-citadelArmor-title").setValue("".concat(loc("info/ship/citadelArmor"), loc("ui/colon")))
      holderObj.findObject("ship-citadelArmor-value").setValue(
        format("%d / %d / %d %s", val[0], val[1], val[2], loc("measureUnits/mm")))
    }

    
    let armorThicknessMainFireTower = unitTags?.Shop.armorThicknessTurretMainCaliber
    holderObj.findObject("ship-mainFireTower-tr").show(armorThicknessMainFireTower != null)
    if (armorThicknessMainFireTower != null) {
      let val = [
        round(armorThicknessMainFireTower.x).tointeger(),
        round(armorThicknessMainFireTower.y).tointeger(),
        round(armorThicknessMainFireTower.z).tointeger(),
      ]
      holderObj.findObject("ship-mainFireTower-title").setValue("".concat(loc("info/ship/mainFireTower"), loc("ui/colon")))
      holderObj.findObject("ship-mainFireTower-value").setValue(
        format("%d / %d / %d %s", val[0], val[1], val[2], loc("measureUnits/mm")))
    }

    
    let atProtection = unitTags?.Shop.atProtection
    holderObj.findObject("ship-antiTorpedoProtection-tr").show(atProtection != null)
    if (atProtection != null) {
      holderObj.findObject("ship-antiTorpedoProtection-title").setValue(
        "".concat(loc("info/ship/antiTorpedoProtection"), loc("ui/colon")))
      holderObj.findObject("ship-antiTorpedoProtection-value").setValue(
        format("%d %s", atProtection, loc("measureUnits/kg")))
    }

    let shipMaterials = getShipMaterialTexts(air.name)

    
    {
      let valueText = shipMaterials?.hullValue ?? ""
      let isShow = valueText != ""
      holderObj.findObject("ship-hullMaterial-tr").show(isShow)
      if (isShow) {
        let labelText = "".concat((shipMaterials?.hullLabel ?? ""), loc("ui/colon"))
        holderObj.findObject("ship-hullMaterial-title").setValue(labelText)
        holderObj.findObject("ship-hullMaterial-value").setValue(valueText)
      }
    }

    
    {
      let valueText = shipMaterials?.superstructureValue ?? ""
      let isShow = valueText != ""
      holderObj.findObject("ship-superstructureMaterial-tr").show(isShow)
      if (isShow) {
        let labelText = "".concat((shipMaterials?.superstructureLabel ?? ""), loc("ui/colon"))
        holderObj.findObject("ship-superstructureMaterial-title").setValue(labelText)
        holderObj.findObject("ship-superstructureMaterial-value").setValue(valueText)
      }
    }
  }
  else {
    holderObj.findObject("ship-displacement-tr").show(false)
    holderObj.findObject("ship-citadelArmor-tr").show(false)
    holderObj.findObject("ship-mainFireTower-tr").show(false)
    holderObj.findObject("ship-antiTorpedoProtection-tr").show(false)
    holderObj.findObject("ship-hullMaterial-tr").show(false)
    holderObj.findObject("ship-superstructureMaterial-tr").show(false)
  }

  if (needShopInfo && holderObj.findObject("aircraft-train_cost-tr"))
    if (air.trainCost > 0) {
      holderObj.findObject("aircraft-train_cost-tr").show(true)
      holderObj.findObject("aircraft-train_cost").setValue(Cost(air.trainCost).getTextAccordingToBalance())
    }

  let showRewardsInfo = !isSlave && (!(params?.showRewardsInfoOnlyForPremium ?? false) || special)
  let rpRewardObj = showObjById("aircraft-reward_rp-tr", showRewardsInfo, holderObj)
  let wpRewardObj = showObjById("aircraft-reward_wp-tr", showRewardsInfo, holderObj)
  let wpTimedRewardObj = showObjById("aircraft-reward_wp_timed-tr", showRewardsInfo, holderObj)
  if (showRewardsInfo && (rpRewardObj != null || wpRewardObj != null || wpTimedRewardObj != null)) {
    let hasPremium  = havePremium.value
    let hasTalisman = special || shopIsModificationEnabled(air.name, "premExpMul")
    let boosterEffects = params?.boosterEffects ?? getBoostersEffects(getActiveBoostersArray())

    let wpMuls = air.getWpRewardMulList(difficulty)
    if (showAsRent)
      wpMuls.premMul = 1.0

    local wpMultText = [ wpMuls.wpMul.tostring() ]
    local wpTimedText = [ wpMuls.wpTimed.tostring() ]
    if (wpMuls.premMul != 1.0) {
      wpMultText.append(colorize("minorTextColor", loc("ui/multiply")),
        colorize("yellow", format("%.1f", wpMuls.premMul)))
      wpTimedText.append(colorize("minorTextColor", loc("ui/multiply")),
        colorize("yellow", format("%.1f", wpMuls.premMul)))
    }
    wpMultText = "".join(wpMultText)
    wpTimedText = "".join(wpTimedText)

    let rewardFormula = {
      rp = {
        obj           = rpRewardObj
        locId         = "reward"
        currency      = "currency/researchPoints/sign/colored"
        isTimedAward  = false
        multText      = air.expMul.tostring()
        multiplier    = air.expMul
        premUnitMul   = 1.0
        noBonus       = 1.0
        premAccBonus  = hasPremium  ? ((rBlk?.xpMultiplier ?? 1.0) - 1.0)    : 0.0
        premModBonus  = hasTalisman ? ((rBlk?.goldPlaneExpMul ?? 1.0) - 1.0) : 0.0
        boosterBonus  = (boosterEffects?[boosterEffectType.RP.name] ?? 0) / 100.0
      }
      wp = {
        obj           = wpRewardObj
        locId         = "reward"
        currency      = "warpoints/short/colored"
        isTimedAward  = false
        multText      = wpMultText
        multiplier    = wpMuls.wpMul
        premUnitMul   = wpMuls.premMul
        noBonus       = 1.0
        premAccBonus  = hasPremium ? ((wBlk?.wpMultiplier ?? 1.0) - 1.0) : 0.0
        premModBonus  = 0.0
        boosterBonus  = (boosterEffects?[boosterEffectType.WP.name] ?? 0) / 100.0
      }
      wp_timed = {
        obj           = wpTimedRewardObj
        locId         = "max_timed_reward"
        currency      = "warpoints/short/colored"
        isTimedAward  = true
        multText      = wpTimedText
        multiplier    = wpMuls.wpTimed
        premUnitMul   = wpMuls.premMul
        noBonus       = 1.0
        premAccBonus  = hasPremium ? ((wBlk?.wpMultiplier ?? 1.0) - 1.0) : 0.0
        premModBonus  = 0.0
        boosterBonus  = (boosterEffects?[boosterEffectType.WP.name] ?? 0) / 100.0
      }
    }

    local hasTimedAward = false
    foreach (id, f in rewardFormula) {
      if (f.obj == null)
        continue

      f.obj.show(f.multiplier != 0)

      if (f.multiplier == 0)
        continue

      if (!hasTimedAward && f.isTimedAward)
        hasTimedAward = true
      let result = f.multiplier * f.premUnitMul * (f.noBonus + f.premAccBonus + f.premModBonus + f.boosterBonus)
      local resultText = f.isTimedAward ? result : measureType.PERCENT_FLOAT.getMeasureUnitsText(result)
      resultText = "".concat(colorize("activeTextColor", resultText), loc(f.currency), f.isTimedAward ? loc("measureUnits/perMinute") : "")

      let sources = [NO_BONUS.__merge({ text = measureType.PERCENT_FLOAT.getMeasureUnitsText(f.noBonus) })]
      if (f.premAccBonus  > 0)
        sources.append(PREM_ACC.__merge({ text = measureType.PERCENT_FLOAT.getMeasureUnitsText(f.premAccBonus) }))
      if (f.premModBonus  > 0)
        sources.append(PREM_MOD.__merge({ text = measureType.PERCENT_FLOAT.getMeasureUnitsText(f.premModBonus) }))
      if (f.boosterBonus  > 0)
        sources.append(BOOSTER.__merge({ text = measureType.PERCENT_FLOAT.getMeasureUnitsText(f.boosterBonus) }))
      sources[sources.len() - 1].isLastBlock <- true
      let formula = handyman.renderCached("%gui/debriefing/rewardSources.tpl", {
        multiplier = f.multText
        sources
      })

      holderObj.getScene().replaceContentFromText(f.obj.findObject($"aircraft-reward_{id}"), formula, formula.len(), handler)
      local rewardText = loc(f.locId)
      if (f.isTimedAward)
        rewardText = "".concat(rewardText, showReferenceText ? "**" : "*")
      f.obj.findObject($"aircraft-reward_{id}-label").setValue($"{rewardText} {resultText}{loc("ui/colon")}")
    }

    let timedAwardHintTextObj = holderObj.findObject("timed_award_hint_text")
    if (timedAwardHintTextObj?.isValid() && hasTimedAward) {
      let hintText = colorize("fadedTextColor", loc("shop/timed_award_hint", { note_symbol = showReferenceText ? "**" : "*" }))
      timedAwardHintTextObj.setValue(hintText)
    }
    timedAwardHintTextObj?.show(hasTimedAward)
  }

  if (holderObj.findObject("aircraft-spare-tr")) {
    let spareCount = showLocalState ? get_spare_aircrafts_count(air.name) : 0
    holderObj.findObject("aircraft-spare-tr").show(spareCount > 0)
    if (spareCount > 0)
      holderObj.findObject("aircraft-spare").setValue("".concat(spareCount.tostring(), loc("icon/spare")))
  }

  if (hideRepairInfo)
    holderObj.findObject("aircraft-max_repair_cost-tr")?.show(false)

  let fullRepairTd = !hideRepairInfo ? holderObj.findObject("aircraft-full_repair_cost-td") : null
  if (fullRepairTd) {
    local repairCostData = ""
    let discountsList = {}
    let freeRepairsUnlimited = isUnitDefault(air)
    let egdCode = difficulty.egdCode
    if (freeRepairsUnlimited)
      repairCostData = format("textareaNoTab { smallFont:t='yes'; text:t='%s' }", loc("shop/free"))
    else {
      let avgRepairMul = wBlk?.avgRepairMul ?? 1.0
      let avgCost = (avgRepairMul * wp_get_repair_cost_by_mode(air.name, egdCode, showLocalState)).tointeger()
      let modeName = get_name_by_gamemode(egdCode, false)
      discountsList[modeName] <-$"{modeName}-discount"
      repairCostData = "".concat(repairCostData, format("".concat("tdiv { ",
                                 "textareaNoTab {smallFont:t='yes' text:t='%s' }",
                                 "discount { id:t='%s'; text:t=''; pos:t='-1*@scrn_tgt/100.0, 0.5ph-0.55h'; position:t='relative'; rotation:t='8' }",
                               "}\n"),
                          "".concat(((repairCostData != "") ? "/ " : ""), Cost(avgCost.tointeger()).getTextAccordingToBalance()),
                          discountsList[modeName]
                        ))
    }
    holderObj.getScene().replaceContentFromText(fullRepairTd, repairCostData, repairCostData.len(), null)
    foreach (modeName, objName in discountsList)
      showAirDiscount(fullRepairTd.findObject(objName), air.name, "repair", modeName)

    if (!freeRepairsUnlimited) {
      if (hasFeature("repairCostUsesPlayTime")) {
        let repairCostPerMin = air.getCostRepairPerMin(difficulty)
        if (repairCostPerMin) {
          holderObj.findObject("aircraft-repair_cost_per_min-tr").show(true)
          holderObj.findObject("aircraft-repair_cost_per_min").setValue(
            "".concat(repairCostPerMin.getColoredWpText(), loc("measureUnits/perMinute")))
        }
      }

      let hours = showLocalState || needCrewModificators ? shop_get_full_repair_time_by_mode(air.name, egdCode)
        : (air[$"repairTimeHrs{get_name_by_gamemode(egdCode, true)}"] ?? 0)
      let repairTimeText = time.hoursToString(hours, true)
      let label = loc((showLocalState || needCrewModificators) && crew ? "shop/full_repair_time_crew" : "shop/full_repair_time")
      holderObj.findObject("aircraft-full_repair_time_crew-tr").show(true)
      holderObj.findObject("aircraft-full_repair_time_crew-tr").tooltip = label
      holderObj.findObject("aircraft-full_repair_time_label").setValue(label)
      holderObj.findObject("aircraft-full_repair_time_crew").setValue(repairTimeText)

      let freeRepairs = showAsRent ? 0
        : (showLocalState || needCrewModificators) ? air.freeRepairs - shop_get_free_repairs_used(air.name)
        : air.freeRepairs
      let showFreeRepairs = freeRepairs > 0
      holderObj.findObject("aircraft-free_repairs-tr").show(showFreeRepairs)
      if (showFreeRepairs)
        holderObj.findObject("aircraft-free_repairs").setValue(freeRepairs.tostring())
    }
    else {
      holderObj.findObject("aircraft-full_repair_time_crew-tr").show(false)
      holderObj.findObject("aircraft-free_repairs-tr").show(false)
      hideBonus(holderObj.findObject("aircraft-full_repair_cost-discount"))
    }
  }

  let addInfoTextsList = []

  if (air.isPkgDev)
    addInfoTextsList.append(colorize("badTextColor", loc("locatedInPackage", { package = "PKG_DEV" })))
  if (air.isRecentlyReleased())
    addInfoTextsList.append(colorize("chapterUnlockedColor", loc("shop/unitIsRecentlyReleased")))
  if (isSquadronVehicle)
    addInfoTextsList.append(colorize("currencySapColor", loc("mainmenu/squadronVehicle")))
  if (air.disableFlyout)
    addInfoTextsList.append(colorize("warningTextColor", loc("mainmenu/vehicleCanNotGoToBattle")))
  if (air.event) {
    let eventLangBlk = GUI.get()?.eventLang
    let eventLang = eventLangBlk?[air.event]
      ? "".join(getLocIdsArray(eventLangBlk?[air.event]).map(@(id) loc(id)))
      : loc($"event/{air.event}")
    addInfoTextsList.append(colorize("chapterUnlockedColor",
      loc($"mainmenu/eventVehicle", { event = eventLang })))
  }

  let spare_count = getGiftSparesCount(air)

  if (isSquadronVehicle && needShopInfo) {
    if (isInClan) {
      if (isResearched)
        addInfoTextsList.append(loc("mainmenu/leaveSquadronNotLockedVehicle"))
      else {
        if (isUnitInResearch(air))
          addInfoTextsList.append(colorize("currencySapColor", loc("mainmenu/buyOrContinueResearch",
            { price = air.getOpenCost().getTextAccordingToBalance() })))
        else
          addInfoTextsList.append(colorize("currencySapColor", loc("mainmenu/researchOrBuy",
            { price = air.getOpenCost().getTextAccordingToBalance() })))

        if (expCur > 0)
          addInfoTextsList.append(loc("mainmenu/leaveSquadronNotClearProgress"))
      }
    }
    else if (!isResearched) {
      if (expCur > 0)
        addInfoTextsList.append(colorize("currencySapColor", loc("mainmenu/needJoinSquadronForResearchOrBuy/continue",
          { price = air.getOpenCost().getTextAccordingToBalance() })))
      else
        addInfoTextsList.append(colorize("currencySapColor", loc("mainmenu/needJoinSquadronForResearchOrBuy",
          { price = air.getOpenCost().getTextAccordingToBalance() })))
    }

    if (!isResearched && (spare_count > 0) && !air.isUsable())
      addInfoTextsList.append(colorize("userlogColoredText", loc("mainmenu/giftSparesClan",
        { num = spare_count, cost = Cost().setGold(spare_cost * spare_count) })))
  }

  if (isInFlight() && showInFlightInfo) {
    let missionRules = getCurMissionRules()
    if (missionRules.isWorldWarUnit(air.name)) {
      addInfoTextsList.append("".concat(loc("icon/worldWar/colored"), colorize("activeTextColor", loc("worldwar/unit"))))
      addInfoTextsList.append(loc("worldwar/unit/desc"))
    }
    if (missionRules.hasCustomUnitRespawns()) {
      let disabledUnitByBRText = crew && !isCrewAvailableInSession(crew, air)
        && getNotAvailableUnitByBRText(air)

      let respawnsleft = missionRules.getUnitLeftRespawns(air)
      if (respawnsleft == 0 || (respawnsleft > 0 && !disabledUnitByBRText)) {
        if (missionRules.isUnitAvailableBySpawnScore(air)) {
          addInfoTextsList.append("".concat(loc("icon/star/white"), colorize("activeTextColor", loc("worldWar/unit/wwSpawnScore"))))
          addInfoTextsList.append(loc("worldWar/unit/wwSpawnScore/desc"))
        }
        else {
          let respText = missionRules.getRespawnInfoTextForUnitInfo(air)
          let color = respawnsleft ? "@userlogColoredText" : "@warningTextColor"
          addInfoTextsList.append(colorize(color, respText))
        }
      }
      else if (disabledUnitByBRText)
        addInfoTextsList.append(colorize("badTextColor", disabledUnitByBRText))
    }

    if (!isOwn)
      addInfoTextsList.append(colorize("warningTextColor", loc("mainmenu/noLeaderboardProgress")))
  }

  if (warbondId) {
    let warbond = findWarbond(warbondId, params?.wbListId)
    let award = warbond ? warbond.getAwardById(air.name) : null
    if (award)
      addInfoTextsList.extend(award.getAdditionalTextsArray())
  }

  let giftSparesLoc = air.isUsable() ? "mainmenu/giftSparesAdded" : "mainmenu/giftSpares"

  if (rentTimeHours != -1) {
    if (rentTimeHours > 0) {
      let rentTimeStr = colorize("activeTextColor", time.hoursToString(rentTimeHours))
      addInfoTextsList.append(colorize("userlogColoredText", loc("shop/rentFor", { time =  rentTimeStr })))
    }
    else
      addInfoTextsList.append(colorize("userlogColoredText", loc("trophy/unlockables_names/trophy")))
    if(numSpares > 0)
      addInfoTextsList.append(colorize("userlogColoredText", loc(giftSparesLoc, { num = numSpares, cost = Cost().setGold(spare_cost * numSpares) })))
    if (isOwn && !isReceivedPrizes) {
      let text = "".concat(loc("mainmenu/itemReceived"), loc("ui/dot"), " ",
        loc(params?.relatedItem ? "mainmenu/activateOnlyOnce" : "mainmenu/receiveOnlyOnce"))
      addInfoTextsList.append(colorize("badTextColor", text))
    }
  }
  else {
    if (canBuyUnitOnline(air)) {
      addInfoTextsList.append(colorize("userlogColoredText",
        format(loc($"shop/giftAir/{air.gift}/info"), air.giftParam ? loc(air.giftParam) : "")))
      if (showLocalState)
        if (!isSquadronVehicle && spare_count > 0)
          addInfoTextsList.append(colorize("userlogColoredText", loc(giftSparesLoc,
            { num = spare_count, cost = Cost().setGold(spare_cost * spare_count) })))
    }
    if (isUnitDefault(air))
      addInfoTextsList.append(loc("shop/reserve/info"))
    if (hasUnitCoupon(air.name))
      addInfoTextsList.append(colorize("userlogColoredText", loc("shop/object/can_get_from_coupon")))
    else if (canBuyUnitOnMarketplace(air))
      addInfoTextsList.append(colorize("userlogColoredText", loc("shop/giftAir/coupon/info")))
  }

  let showPriceText = rentTimeHours == -1 && showLocalState && !isUnitBought(air)
    && isUnitResearched(air) && !canBuyUnitOnline(air) && canBuyUnit(air)
  let priceObj = showObjById("aircraft_price", showPriceText, holderObj)

  if(checkObj(priceObj))
    priceObj.findObject("aircraft_price_text_block").show(false)

  if (showPriceText && checkObj(priceObj) && getUnitDiscountByName(air.name) > 0) {
    placePriceTextToButton(holderObj, "aircraft_price", loc("events/air_can_buy"),
      getUnitCost(air), 0, getUnitRealCost(air), { textColor = "userlogColoredText" })

    if (!isSquadronVehicle && spare_count > 0)
      addInfoTextsList.append(colorize("userlogColoredText", loc(giftSparesLoc,
        { num = spare_count, cost = Cost().setGold(spare_cost * spare_count) })))
  }
  else if (showPriceText && warbondId == null && showLocalState) {
    let priceText = colorize("activeTextColor", getUnitCost(air).getTextAccordingToBalance())
    addInfoTextsList.append(colorize("userlogColoredText", loc("mainmenu/canBuyThisVehicle", { price = priceText })))

    if (!isSquadronVehicle && spare_count > 0)
      addInfoTextsList.append(colorize("userlogColoredText", loc(giftSparesLoc,
        { num = spare_count, cost = Cost().setGold(spare_cost * spare_count) })))
  }

  let infoObj = showObjById("aircraft-addInfo", !showShortestUnitInfo, holderObj)
  if (checkObj(infoObj))
    infoObj.setValue("\n".join(addInfoTextsList, true))

  if (needCrewInfo && crew) {
    let crewUnitType = air.getCrewUnitType()
    let crewLevel = getCrewLevel(crew, air, crewUnitType)
    let crewStatus = getCrewStatus(crew, air)
    let specType = getSpecTypeByCrewAndUnit(crew, air)
    let crewSpecIcon = specType.trainedIcon
    let crewSpecName = specType.getName()

    obj = holderObj.findObject("aircraft-crew_info")
    if (checkObj(obj))
      obj.show(true)

    obj = holderObj.findObject("aircraft-crew_name")
    if (checkObj(obj))
      obj.setValue(getCrewName(crew))

    obj = holderObj.findObject("aircraft-crew_level")
    if (checkObj(obj))
      obj.setValue("".concat(loc("crew/usedSkills"), " ", crewLevel))
    obj = holderObj.findObject("aircraft-crew_spec-label")
    if (checkObj(obj))
      obj.setValue("".concat(loc("crew/trained"), loc("ui/colon")))
    obj = holderObj.findObject("aircraft-crew_spec-icon")
    if (checkObj(obj))
      obj["background-image"] = crewSpecIcon
    obj = holderObj.findObject("aircraft-crew_spec")
    if (checkObj(obj))
      obj.setValue(crewSpecName)

    obj = holderObj.findObject("aircraft-crew_points")
    if (checkObj(obj) && !isInFlight() && crewStatus != "") {
      let crewPointsText = colorize("white", getCrewSpText(getCrewPoints(crew)))
      obj.show(true)
      obj.setValue("".concat(loc("crew/availablePoints/advice"), loc("ui/colon"), crewPointsText))
      obj["crewStatus"] = crewStatus
    }
  }

  if (needUnitReqInfo && !isRented) {
    let reason = getCantBuyUnitReason(air, true)
    let addTextObj = showObjById("aircraft-cant_buy_info", !showShortestUnitInfo && reason != "", holderObj)
    let unitNest = holderObj.findObject("prev_unit_nest")
    if (checkObj(addTextObj) && reason != "") {
      addTextObj.setValue(colorize("redMenuButtonColor", reason))
      if(checkObj(unitNest)) {
        let isPrevUnitShow = (!isPrevUnitResearched(air) || !isPrevUnitBought(air)) &&
          is_era_available(air.shopCountry, air?.rank ?? -1, unitType)
        unitNest.show(isPrevUnitShow)
        if (isPrevUnitShow) {
          let prevUnit = getPrevUnit(air)
          let unitBlk = buildUnitSlot(prevUnit.name, prevUnit)
          holderObj.getScene().replaceContentFromText(unitNest, unitBlk, unitBlk.len(), handler)
          fillUnitSlotTimers(unitNest.findObject(prevUnit.name), prevUnit)
        }
      }
    }
    else
      unitNest?.show(false)
  }

  if (has_entitlement("AccessTest") && needShopInfo && holderObj.findObject("aircraft-surviveRating")) {
    let blk = get_global_stats_blk()
    if (blk?["aircrafts"]) {
      let stats = blk["aircrafts"]?[air.name]
      local surviveText = loc("multiplayer/notAvailable")
      local winsText = loc("multiplayer/notAvailable")
      local usageText = loc("multiplayer/notAvailable")
      local rating = -1
      if (stats) {
        local survive = stats?.flyouts_deaths ?? 1.0
        survive = (survive == 0) ? 0 : 1.0 - 1.0 / survive
        surviveText = "".concat((survive * 100).tointeger(), "%")
        let wins = stats?.wins_flyouts ?? 0.0
        winsText = "".concat((wins * 100).tointeger(), "%")

        let usage = stats?.flyouts_factor ?? 0.0
        if (usage >= 0.000001) {
          rating = 0
          foreach (r in usageRatingAmount)
            if (usage > r)
              rating++
          usageText = loc($"shop/usageRating/{rating}")
          if (has_entitlement("AccessTest"))
            usageText = "".concat(usageText, " (", (usage * 100).tointeger(), "%)")
        }
      }
      holderObj.findObject("aircraft-surviveRating-tr").show(true)
      holderObj.findObject("aircraft-surviveRating").setValue(surviveText)
      holderObj.findObject("aircraft-winsRating-tr").show(true)
      holderObj.findObject("aircraft-winsRating").setValue(winsText)
      holderObj.findObject("aircraft-usageRating-tr").show(true)
      if (rating >= 0)
        holderObj.findObject("aircraft-usageRating").overlayTextColor = $"usageRating{rating}";
      holderObj.findObject("aircraft-usageRating").setValue(usageText)
    }
  }

  let weaponInfoParams = {
    weaponPreset = showLocalState ? -1 : 0
    ediff = ediff
    isLocalState = showLocalState
  }
  let weaponInfoData = makeWeaponInfoData(air, weaponInfoParams)
  let weaponsInfoText = getWeaponInfoText(air, weaponInfoData)
  obj = showObjById("weaponsInfo", !showShortestUnitInfo, holderObj)
  if (obj) {
    obj.setValue(weaponsInfoText)
    if(params?.parentWidth == true)
      obj["max-width"] = "pw"
  }

  let massPerSecValue = getUnitMassPerSecValue(air, showLocalState)
  if (massPerSecValue != 0) {
    let massPerSecText = format("%.2f %s", massPerSecValue, loc("measureUnits/kgPerSec"))
    obj = holderObj.findObject("aircraft-massPerSec")
    if (checkObj(obj))
      obj.setValue(massPerSecText)
  }
  obj = holderObj.findObject("aircraft-massPerSec-tr")
  if (checkObj(obj))
    obj.show(massPerSecValue != 0)

  obj = showObjById("aircraft-research-efficiency-tr", showRewardsInfo, holderObj)
  if (obj != null) {
    let minAge = getMinBestLevelingRank(air)
    let maxAge = getMaxBestLevelingRank(air)
    let rangeText = (minAge == maxAge) ? ("".concat(get_roman_numeral(minAge), nbsp, loc("shop/age"))) :
        "".concat(get_roman_numeral(minAge), nbsp, loc("ui/mdash"), nbsp, get_roman_numeral(maxAge), nbsp, loc("mainmenu/ranks"))
    obj.findObject("aircraft-research-efficiency").setValue(rangeText)
  }

  let wPresets = getUnitWeaponPresetsCount(air)
  obj = holderObj.findObject("aircraft-weaponPresets")
  if (checkObj(obj))
    obj.setValue(wPresets.tostring())

  obj = showObjById("current_game_mode_footnote_text", !showShortestUnitInfo, holderObj)
  if (checkObj(obj)) {
    let battleType = get_battle_type_by_ediff(ediff)
    let fonticon = getFontIconByBattleType(battleType)
    let diffName = nbsp.join([ fonticon, difficulty.getLocName() ], true)

    let unitStateId = !showLocalState ? "reference"
      : crew ? "current_crew"
      : air.isUsable() ? "current"
      : ""
    let unitState = (unitStateId != "") ? loc($"shop/showing_unit_state/{unitStateId}") : ""

    let currentGameModeFootnoteText = "".concat(
      loc("shop/all_info_relevant_to_current_game_mode"), loc("ui/colon"), diffName,
      (unitState != "") ? $"\n{unitState}" : "")
    obj.setValue(currentGameModeFootnoteText)
  }

  obj = holderObj.findObject("unit_rent_time")
  if (checkObj(obj))
    obj.show(false)

  if (showLocalState)
    fillAirInfoTimers(holderObj, air, needShopInfo, needShowExpiredMessage)

  showObjectsByTable(holderObj, {
    topValueHint = topValueCount > 0
    separator0 = !isSlave
    separator1 = !isSlave
    separator2 = !isSlave
  })
}

::showAirInfo <- showAirInfo

return {
  showAirInfo
  getBattleTypeByUnit
  getFontIconByBattleType
  usageRatingAmount
}