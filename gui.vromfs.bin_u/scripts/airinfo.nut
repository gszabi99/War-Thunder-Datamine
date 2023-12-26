//-file:plus-string
from "%scripts/dagui_natives.nut" import wp_get_repair_cost_by_mode, shop_get_aircraft_hp, shop_get_free_repairs_used, wp_get_cost_gold, get_spare_aircrafts_count, calculate_tank_parameters_async, wp_get_repair_cost, calculate_min_and_max_parameters, get_unit_elite_status, has_entitlement, get_name_by_gamemode, calculate_ship_parameters_async, shop_purchase_aircraft, wp_get_cost, char_send_blk, shop_get_unit_exp, clan_get_exp, get_global_stats_blk, shop_time_until_repair, remove_calculate_modification_effect_jobs, is_era_available, shop_unit_research_status, shop_get_full_repair_time_by_mode, calculate_mod_or_weapon_effect
from "%scripts/dagui_library.nut" import *
from "%scripts/gameModes/gameModeConsts.nut" import BATTLE_TYPES

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { Cost } = require("%scripts/money.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { isInMenu, handlersManager, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { get_time_msec } = require("dagor.time")
let { format, split_by_chars } = require("string")
let { hangar_get_current_unit_name, hangar_get_loaded_unit_name, force_retrace_decorators,
  hangar_force_reload_model, hangar_is_high_quality } = require("hangar")
let { blkFromPath } = require("%sqstd/datablock.nut")
let SecondsUpdater = require("%sqDagui/timer/secondsUpdater.nut")
let time = require("%scripts/time.nut")
let stdMath = require("%sqstd/math.nut")
let { getUnitRoleIcon, getUnitTooltipImage, getFullUnitRoleText,
  getChanceToMeetText, getShipMaterialTexts, getUnitItemStatusText,
  getUnitRarity } = require("%scripts/unit/unitInfoTexts.nut")
let { getUnitRequireUnlockText } = require("%scripts/unlocks/unlocksViewModule.nut")
let unitStatus = require("%scripts/unit/unitStatus.nut")
let countMeasure = require("%scripts/options/optionsMeasureUnits.nut").countMeasure
let { getCrewPoints } = require("%scripts/crew/crewSkills.nut")
let { getWeaponInfoText } = require("%scripts/weaponry/weaponryDescription.nut")
let { getLastWeapon } = require("%scripts/weaponry/weaponryInfo.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { placePriceTextToButton, warningIfGold } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { isModResearched, getModificationByName
} = require("%scripts/weaponry/modificationInfo.nut")
let { isModificationInTree } = require("%scripts/weaponry/modsTree.nut")
let { boosterEffectType, getActiveBoostersArray,
  getBoostersEffects } = require("%scripts/items/boosterEffect.nut")
let { isMarketplaceEnabled } = require("%scripts/items/itemsMarketplace.nut")
let { NO_BONUS, PREM_ACC, PREM_MOD, BOOSTER } = require("%scripts/debriefing/rewardSources.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let DataBlock = require("DataBlock")
let { GUI } = require("%scripts/utils/configs.nut")
let { havePremium } = require("%scripts/user/premium.nut")
let { getUnitMassPerSecValue, getUnitWeaponPresetsCount } = require("%scripts/unit/unitWeaponryInfo.nut")
let { isPlatformPC } = require("%scripts/clientState/platform.nut")
let { getBundleId } = require("%scripts/onlineShop/onlineBundles.nut")
let { getShopItem } = require("%scripts/onlineShop/entitlementsStore.nut")
let { getUnitFileName } = require("vehicleModel")
let { fillPromUnitInfo } = require("%scripts/unit/remainingTimeUnit.nut")
let { approversUnitToPreviewLiveResource } = require("%scripts/customization/skins.nut")
let { getLocIdsArray } = require("%scripts/langUtils/localization.nut")
let { getGiftSparesCount, getGiftSparesCost } = require("%scripts/shop/giftSpares.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { shopIsModificationEnabled } = require("chardResearch")
let { getCountryFlagForUnitTooltip } = require("%scripts/options/countryFlagsPreset.nut")
let {
  getEsUnitType, isUnitsEraUnlocked, getUnitName, getUnitCountry,
  isUnitDefault, isUnitGift, getUnitCountryIcon,  getUnitsNeedBuyToOpenNextInEra,
  isUnitGroup, canResearchUnit, isRequireUnlockForUnit, canBuyUnit
} = require("%scripts/unit/unitInfo.nut")
let { get_warpoints_blk, get_ranks_blk, get_unittags_blk } = require("blkGetters")
let { isInFlight } = require("gameplayBinding")
let { getCrewSpText } = require("%scripts/crew/crewPoints.nut")
let { calcBattleRatingFromRank, CAN_USE_EDIFF, isUnitSpecial } = require("%appGlobals/ranks_common_shared.nut")
let { isCrewAvailableInSession } = require("%scripts/respawn/respawnState.nut")
let { getCurMissionRules } = require("%scripts/misCustomRules/missionCustomState.nut")
let { checkBalanceMsgBox } = require("%scripts/user/balanceFeatures.nut")
let { buildUnitSlot, fillUnitSlotTimers } = require("%scripts/slotbar/slotbarView.nut")
let { getCrewById, getCrewByAir, isUnitInSlotbar, getCrewUnlockTimeByUnit } = require("%scripts/slotbar/slotbarState.nut")

const MODIFICATORS_REQUEST_TIMEOUT_MSEC = 20000

enum CheckFeatureLockAction {
  BUY,
  RESEARCH
}

let function afterUpdateAirModificators(unit, callback) {
  if (unit.secondaryWeaponMods)
    unit.secondaryWeaponMods = null //invalidate secondary weapons cache
  broadcastEvent("UnitModsRecount", { unit = unit })
  if (callback != null)
    callback()
}

let function fillProgressBar(obj, curExp, newExp, maxExp, isPaused = false) {
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
// TODO: Move all global fns to unit/unitInfo.nut

let isEventUnit = @(unit) unit.event != null

::canBuyUnitOnline <- function canBuyUnitOnline(unit) {
  let canBuy = !::isUnitBought(unit)
    && isUnitGift(unit)
    && !isEventUnit(unit)
    && unit.isVisibleInShop()
    && !::canBuyUnitOnMarketplace(unit)
    && !unit.isCrossPromo

  if (isPlatformPC || !canBuy)
    return canBuy

  return null != unit.getEntitlements().findvalue(function(id) {
    let bundleId = getBundleId(id)
    return bundleId != "" && getShopItem(bundleId) != null
  })
}

::canBuyUnitOnMarketplace <- function canBuyUnitOnMarketplace(unit) {
  return unit.marketplaceItemdefId != null
    && !::isUnitBought(unit)
    && isMarketplaceEnabled()
    && (::ItemsManager.findItemById(unit.marketplaceItemdefId)?.hasLink() ?? false)
}

::isUnitInResearch <- function isUnitInResearch(unit) {
  if (!unit)
    return false

  if (!("name" in unit))
    return false

  local status = shop_unit_research_status(unit.name)
  return ((status & ES_ITEM_STATUS_IN_RESEARCH) != 0) && !::isUnitMaxExp(unit)
}

::findUnitNoCase <- function findUnitNoCase(unitName) {
  unitName = unitName.tolower()
  foreach (name, unit in getAllUnits())
    if (name.tolower() == unitName)
      return unit
  return null
}

::isUnitDescriptionValid <- function isUnitDescriptionValid(unit) {
  if (!hasFeature("UnitInfo"))
    return false
  if (hasFeature("WikiUnitInfo"))
    return true // Because there is link to wiki.
  let desc = unit ? loc("encyclopedia/" + unit.name + "/desc", "") : ""
  return desc != "" && desc != loc("encyclopedia/no_unit_description")
}

::getUnitRealCost <- function getUnitRealCost(unit) {
  return Cost(unit.cost, unit.costGold)
}

::getUnitCost <- function getUnitCost(unit) {
  return Cost(wp_get_cost(unit.name),
                wp_get_cost_gold(unit.name))
}

::isUnitBought <- function isUnitBought(unit) {
  return unit ? unit.isBought() : false
}

::isUnitEliteByStatus <- function isUnitEliteByStatus(status) {
  return status > ES_UNIT_ELITE_STAGE1
}

::isUnitElite <- function isUnitElite(unit) {
  let unitName = unit?.name
  return unitName ? ::isUnitEliteByStatus(get_unit_elite_status(unitName)) : false
}

::isUnitBroken <- function isUnitBroken(unit) {
  return ::getUnitRepairCost(unit) > 0
}

/**
 * Returns true if unit can be installed in slotbar,
 * unit can be decorated with decals, etc...
 */
::isUnitUsable <- function isUnitUsable(unit) {
  return unit ? unit.isUsable() : false
}

::isUnitFeatureLocked <- function isUnitFeatureLocked(unit) {
  return unit.reqFeature != null && !hasFeature(unit.reqFeature)
}

::getUnitRepairCost <- function getUnitRepairCost(unit) {
  if ("name" in unit)
    return wp_get_repair_cost(unit.name)
  return 0
}

::buyUnit <- function buyUnit(unit, silent = false) {
  if (!::checkFeatureLock(unit, CheckFeatureLockAction.BUY))
    return false

  let canBuyNotResearchedUnit = unitStatus.canBuyNotResearched(unit)
  let unitCost = canBuyNotResearchedUnit ? unit.getOpenCost() : ::getUnitCost(unit)
  if (unitCost.gold > 0 && !::can_spend_gold_on_unit_with_popup(unit))
    return false

  if (!canBuyUnit(unit) && !canBuyNotResearchedUnit) {
    if ((::isUnitResearched(unit) || isUnitSpecial(unit)) && !silent)
      ::show_cant_buy_or_research_unit_msgbox(unit)
    return false
  }

  if (silent)
    return ::impl_buyUnit(unit)

  let unitName  = colorize("userlogColoredText", getUnitName(unit, true))
  let unitPrice = unitCost.getTextAccordingToBalance()
  let msgText = warningIfGold(loc("shop/needMoneyQuestion_purchaseAircraft",
      { unitName = unitName, cost = unitPrice }),
    unitCost)

  local additionalCheckBox = null

  scene_msg_box("need_money", null, msgText,
                  [["yes", function() { ::impl_buyUnit(unit) } ],
                   ["no", function() {} ]],
                  "yes", { cancel_fn = function() {}, data_below_text = additionalCheckBox })
  return true
}

::impl_buyUnit <- function impl_buyUnit(unit) {
  if (!unit)
    return false
  if (unit.isBought())
    return false

  let canBuyNotResearchedUnit = unitStatus.canBuyNotResearched(unit)
  let unitCost = canBuyNotResearchedUnit ? unit.getOpenCost() : ::getUnitCost(unit)
  if (!checkBalanceMsgBox(unitCost))
    return false

  let unitName = unit.name
  local taskId = null
  if (canBuyNotResearchedUnit) {
    let blk = DataBlock()
    blk["unit"] = unit.name
    blk["cost"] = unitCost.wp
    blk["costGold"] = unitCost.gold

    taskId = char_send_blk("cln_buy_not_researched_clans_unit", blk)
  }
  else
    taskId = shop_purchase_aircraft(unitName)

  let progressBox = scene_msg_box("char_connecting", null, loc("charServer/purchase"), null, null)
  ::add_bg_task_cb(taskId, function() {
    destroyMsgBox(progressBox)
    broadcastEvent("UnitBought", { unitName = unit.name })
  })
  return true
}

::can_spend_gold_on_unit_with_popup <- function can_spend_gold_on_unit_with_popup(unit) {
  if (unit.unitType.canSpendGold())
    return true

  ::g_popups.add(getUnitName(unit), loc("msgbox/unitTypeRestrictFromSpendGold"),
    null, null, null, "cant_spend_gold_on_unit")
  return false
}

::show_cant_buy_or_research_unit_msgbox <- function show_cant_buy_or_research_unit_msgbox(unit) {
  let reason = ::getCantBuyUnitReason(unit)
  if (u.isEmpty(reason))
    return true

  scene_msg_box("need_buy_prev", null, reason, [["ok", function () {}]], "ok")
  return false
}

::checkFeatureLock <- function checkFeatureLock(unit, lockAction) {
  if (!::isUnitFeatureLocked(unit))
    return true
  let params = {
    purchaseAvailable = hasFeature("OnlineShopPacks")
    featureLockAction = lockAction
    unit = unit
  }

  loadHandler(gui_handlers.VehicleRequireFeatureWindow, params)
  return false
}

::checkForResearch <- function checkForResearch(unit) {
  // Feature lock has higher priority than canResearchUnit.
  if (!::checkFeatureLock(unit, CheckFeatureLockAction.RESEARCH))
    return false

  let isSquadronVehicle = unit.isSquadronVehicle()
  if (canResearchUnit(unit) && !isSquadronVehicle)
    return true

  if (!isUnitSpecial(unit) && !isUnitGift(unit)
    && !isSquadronVehicle && !isUnitsEraUnlocked(unit)) {
    showInfoMsgBox(::getCantBuyUnitReason(unit), "need_unlock_rank")
    return false
  }

  if (isSquadronVehicle) {
    if (min(clan_get_exp(), unit.reqExp - ::getUnitExp(unit)) <= 0
      && (!hasFeature("ClanVehicles") || !::is_in_clan())) {
      if (!hasFeature("ClanVehicles")) {
        ::show_not_available_msg_box()
        return false
      }

      let button = [["#mainmenu/btnFindSquadron", @() loadHandler(gui_handlers.ClansModalHandler)]]
      local defButton = "#mainmenu/btnFindSquadron"
      let msg = [loc("mainmenu/needJoinSquadronForResearch")]

      let canBuyNotResearchedUnit = unitStatus.canBuyNotResearched(unit)
      let priceText = unit.getOpenCost().getTextAccordingToBalance()
      if (canBuyNotResearchedUnit) {
        button.append(["purchase", @() ::buyUnit(unit, true)])
        defButton = "purchase"
        msg.append("\n")
        msg.append(loc("mainmenu/canOpenVehicle", { price = priceText }))
      }
      button.append(["cancel", function() {}])

      scene_msg_box("cant_research_squadron_vehicle", null, "\n".join(msg, true),
        button, defButton)

      return false
    }
    else
      return true
  }

  return ::show_cant_buy_or_research_unit_msgbox(unit)
}


::getCantBuyUnitReason <- function getCantBuyUnitReason(unit, isShopTooltip = false) {
  if (!unit)
    return loc("leaderboards/notAvailable")

  if (::isUnitBought(unit) || isUnitGift(unit))
    return ""

  let special = isUnitSpecial(unit)
  let isSquadronVehicle = unit.isSquadronVehicle()
  if (!special && !isSquadronVehicle && !isUnitsEraUnlocked(unit)) {
    let countryId = getUnitCountry(unit)
    let unitType = getEsUnitType(unit)
    let rank = unit?.rank ?? -1

    for (local prevRank = rank - 1; prevRank > 0; prevRank--) {
      local unitsCount = 0
      foreach (un in getAllUnits())
        if (::isUnitBought(un) && (un?.rank ?? -1) == prevRank && getUnitCountry(un) == countryId && getEsUnitType(un) == unitType)
          unitsCount++
      let unitsNeed = getUnitsNeedBuyToOpenNextInEra(countryId, unitType, prevRank)
      let unitsLeft = max(0, unitsNeed - unitsCount)

      if (unitsLeft > 0) {
        return loc("shop/unlockTier/locked", { rank = get_roman_numeral(rank) })
          + "\n" + loc("shop/unlockTier/reqBoughtUnitsPrevRank", { prevRank = get_roman_numeral(prevRank), amount = unitsLeft })
      }
    }
    return loc("shop/unlockTier/locked", { rank = get_roman_numeral(rank) })
  }
  else if (!::isPrevUnitResearched(unit)) {
    if (isShopTooltip)
      return loc("mainmenu/needResearchPreviousVehicle")
    if (!::isUnitResearched(unit))
      return loc("msgbox/need_unlock_prev_unit/research",
        { name = colorize("userlogColoredText", getUnitName(::getPrevUnit(unit), true)) })
    return loc("msgbox/need_unlock_prev_unit/researchAndPurchase",
      { name = colorize("userlogColoredText", getUnitName(::getPrevUnit(unit), true)) })
  }
  else if (!::isPrevUnitBought(unit)) {
    if (isShopTooltip)
      return loc("mainmenu/needBuyPreviousVehicle")
    return loc("msgbox/need_unlock_prev_unit/purchase", { name = colorize("userlogColoredText", getUnitName(::getPrevUnit(unit), true)) })
  }
  else if (isRequireUnlockForUnit(unit))
    return getUnitRequireUnlockText(unit)
  else if (!special && !isSquadronVehicle && !canBuyUnit(unit) && canResearchUnit(unit))
    return loc(::isUnitInResearch(unit) ? "mainmenu/needResearch/researching" : "mainmenu/needResearch")

  if (!isShopTooltip) {
    let info = ::get_profile_info()
    let balance = info?.balance ?? 0
    let balanceG = info?.gold ?? 0

    if (special && (wp_get_cost_gold(unit.name) > balanceG))
      return loc("mainmenu/notEnoughGold")
    else if (!special && (wp_get_cost(unit.name) > balance))
      return loc("mainmenu/notEnoughWP")
  }

  return ""
}

::isUnitAvailableForGM <- function isUnitAvailableForGM(air, gm) {
  if (air == null || !air.unitType.isAvailable())
    return false
  if (gm == GM_TEST_FLIGHT)
    return air.testFlight != ""
  if (gm == GM_DYNAMIC)
    return air.isAir()
  if (gm == GM_BUILDER)
    return air.isAir() && isUnitInSlotbar(air)
  return true
}

::isTestFlightAvailable <- function isTestFlightAvailable(unit, skipUnitCheck = false) {
  if (!::isUnitAvailableForGM(unit, GM_TEST_FLIGHT))
    return false

  if (unit.isUsable()
      || skipUnitCheck
      || canResearchUnit(unit)
      || isUnitGift(unit)
      || ::isUnitResearched(unit)
      || isUnitSpecial(unit)
      || approversUnitToPreviewLiveResource.value == unit
      || unit?.isSquadronVehicle?())
    return true

  return false
}

//return true when modificators already valid.
::check_unit_mods_update <- function check_unit_mods_update(air, callBack = null, forceUpdate = false, needMinMaxEffectsForAllUnitTypes = false) {
  if (!air.isInited) {
    script_net_assert_once("not inited unit request", "try to call check_unit_mods_update for not inited unit")
    return false
  }

  if (air.modificatorsRequestTime > 0
    && air.modificatorsRequestTime + MODIFICATORS_REQUEST_TIMEOUT_MSEC > get_time_msec()) {
    if (forceUpdate)
      remove_calculate_modification_effect_jobs()
    else
      return false
  }
  else if (!forceUpdate && air.modificators)
    return true

  if (air.isShipOrBoat()) {
    air.modificatorsRequestTime = get_time_msec()
    calculate_ship_parameters_async(air.name, this,  function(effect, ...) {
      air.modificatorsRequestTime = -1
      if (effect) {
        air.modificators = {
          arcade = effect.arcade
          historical = effect.historical
          fullreal = effect.fullreal
        }

        if (needMinMaxEffectsForAllUnitTypes) {
          air.minChars = effect.min
          air.maxChars = effect.max
        }

        if (!air.modificatorsBase)
          air.modificatorsBase = air.modificators
      }

      afterUpdateAirModificators(air, callBack)
    })
    return false
  }

  if (air.isTank()) {
    air.modificatorsRequestTime = get_time_msec()
    calculate_tank_parameters_async(air.name, this,  function(effect, ...) {
      air.modificatorsRequestTime = -1
      if (effect) {
        air.modificators = {
          arcade = effect.arcade
          historical = effect.historical
          fullreal = effect.fullreal
        }

        if (needMinMaxEffectsForAllUnitTypes) {
          air.minChars = effect.min
          air.maxChars = effect.max
        }

        if (!air.modificatorsBase) // TODO: Needs tank params _without_ user progress here.
          air.modificatorsBase = air.modificators
      }
      afterUpdateAirModificators(air, callBack)
    })
    return false
  }

  air.modificatorsRequestTime = get_time_msec()
  calculate_min_and_max_parameters(air.name, this,  function(effect, ...) {
    air.modificatorsRequestTime = -1
    if (effect) {
      air.modificators = {
        arcade = effect.arcade
        historical = effect.historical
        fullreal = effect.fullreal
      }
      air.minChars = effect.min
      air.maxChars = effect.max

      if (isUnitSpecial(air) && !::isUnitUsable(air))
        air.modificators = effect.max
    }
    afterUpdateAirModificators(air, callBack)
  })
  return false
}

// modName == ""  mean 'all mods'.
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
    ::check_unit_mods_update(air, null, true)
}

//return true when already counted
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

::getUnitExp <- function getUnitExp(unit) {
  return shop_get_unit_exp(unit.name)
}

::getUnitReqExp <- function getUnitReqExp(unit) {
  if (!("reqExp" in unit))
    return 0
  return unit.reqExp
}

::isUnitMaxExp <- function isUnitMaxExp(unit) { //temporary while not exist correct status between in_research and canBuy
  return isUnitSpecial(unit) || (::getUnitReqExp(unit) <= ::getUnitExp(unit))
}

::getNextTierModsCount <- function getNextTierModsCount(unit, tier) {
  if (tier < 1 || tier > unit.needBuyToOpenNextInTier.len() || !("modifications" in unit))
    return 0

  local req = unit.needBuyToOpenNextInTier[tier - 1]
  foreach (mod in unit.modifications)
    if (("tier" in mod) && mod.tier == tier
      && isModificationInTree(unit, mod)
      && isModResearched(unit, mod)
    )
      req--
  return max(req, 0)
}

::getPrevUnit <- function getPrevUnit(unit) {
  return "reqAir" in unit ? getAircraftByName(unit.reqAir) : null
}

::isUnitLocked <- function isUnitLocked(unit) {
  let status = shop_unit_research_status(unit.name)
  return 0 != (status & ES_ITEM_STATUS_LOCKED)
}

::isUnitResearched <- function isUnitResearched(unit) {
  if (::isUnitBought(unit) || canBuyUnit(unit))
    return true

  let status = shop_unit_research_status(unit.name)
  return (0 != (status & ES_ITEM_STATUS_RESEARCHED))
}

::isPrevUnitResearched <- function isPrevUnitResearched(unit) {
  let prevUnit = ::getPrevUnit(unit)
  if (!prevUnit || ::isUnitResearched(prevUnit))
    return true
  return false
}

::isPrevUnitBought <- function isPrevUnitBought(unit) {
  let prevUnit = ::getPrevUnit(unit)
  if (!prevUnit || ::isUnitBought(prevUnit))
    return true
  return false
}

::getMinBestLevelingRank <- function getMinBestLevelingRank(unit) {
  if (!unit)
    return -1

  let unitRank = unit?.rank ?? -1
  if (isUnitSpecial(unit) || unitRank == 1)
    return 1
  let result = unitRank - ::getHighestRankDiffNoPenalty(true)
  return result > 0 ? result : 1
}

::getMaxBestLevelingRank <- function getMaxBestLevelingRank(unit) {
  if (!unit)
    return -1

  let unitRank = unit?.rank ?? -1
  if (unitRank == ::max_country_rank)
    return ::max_country_rank
  let result = unitRank + ::getHighestRankDiffNoPenalty()
  return result <= ::max_country_rank ? result : ::max_country_rank
}

::getHighestRankDiffNoPenalty <- function getHighestRankDiffNoPenalty(inverse = false) {
  let ranksBlk = get_ranks_blk()
  let paramPrefix = inverse
                      ? "expMulWithTierDiffMinus"
                      : "expMulWithTierDiff"

  for (local rankDif = 0; rankDif < ::max_country_rank; rankDif++)
    if (ranksBlk[paramPrefix + rankDif] < 0.8)
      return rankDif - 1
  return 0
}

::get_battle_type_by_unit <- function get_battle_type_by_unit(unit) {
  return (getEsUnitType(unit) == ES_UNIT_TYPE_TANK) ? BATTLE_TYPES.TANK : BATTLE_TYPES.AIR
}

::getCharacteristicActualValue <- function getCharacteristicActualValue(air, characteristicName, prepareTextFunc, modeName, showLocalState = true) {
  let modificators = showLocalState ? "modificators" : "modificatorsBase"

  local showReferenceText = false
  if (!(characteristicName[0] in air.shop))
    air.shop[characteristicName[0]] <- 0;

  let value = air.shop[characteristicName[0]] + (air[modificators] ? air[modificators][modeName][characteristicName[1]] : 0)
  let vMin = air.minChars ? air.shop[characteristicName[0]] + air.minChars[modeName][characteristicName[1]] : value
  let vMax = air.maxChars ? air.shop[characteristicName[0]] + air.maxChars[modeName][characteristicName[1]] : value
  local text = prepareTextFunc(value)
  if (air[modificators] && air[modificators][modeName][characteristicName[1]] == 0) {
    text = "<color=@goodTextColor>" + text + "</color>*"
    showReferenceText = true
  }

  let weaponModValue = air?.secondaryWeaponMods.effect[modeName][characteristicName[1]] ?? 0
  local weaponModText = ""
  if (weaponModValue != 0)
    weaponModText = "<color=@badTextColor>" + (weaponModValue > 0 ? " + " : " - ") + prepareTextFunc(stdMath.fabs(weaponModValue)) + "</color>"
  return [text, weaponModText, vMin, vMax, value, air.shop[characteristicName[0]], showReferenceText]
}

let function setReferenceMarker(obj, vMin, vMax, refer, modeName) {
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

let function fillAirCharProgress(progressObj, vMin, vMax, cur) {
  if (!checkObj(progressObj))
    return
  if (vMin == vMax)
    return progressObj.show(false)
  else
    progressObj.show(true)
  let value = ((cur - vMin) / (vMax - vMin)) * 1000.0
  progressObj.setValue(value)
}

::fillAirInfoTimers <- function fillAirInfoTimers(holderObj, air, needShopInfo) {
  SecondsUpdater(holderObj, function(obj, _params) {
    local isActive = false

    // Unit repair cost
    let hp = shop_get_aircraft_hp(air.name)
    let isBroken = hp >= 0 && hp < 1
    isActive = isActive || isBroken // warning disable: -const-in-bool-expr
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

    // Unit rent time
    let isRented = air.isRented()
    isActive = isActive || isRented
    let rentObj = obj.findObject("unit_rent_time")
    if (checkObj(rentObj)) {
      let sec = air.getRentTimeleft()
      let show = sec > 0
      local value = ""
      if (show) {
        let timeStr = time.hoursToString(time.secondsToHours(sec), false, true, true)
        value = colorize("goodTextColor", loc("mainmenu/unitRentTimeleft") + loc("ui/colon") + timeStr)
      }
      if (rentObj.isVisible() != show)
        rentObj.show(show)
      if (show && rentObj.getValue() != value)
        rentObj.setValue(value)
    }


    // unit special offer
    let haveDiscount = ::g_discount.getUnitDiscountByName(air.name)
    let specialOfferItem = haveDiscount > 0 ? ::ItemsManager.getBestSpecialOfferItemByUnit(air) : null
    isActive = isActive || specialOfferItem != null
    let discountObj = obj.findObject("special_offer_time")
    if (checkObj(rentObj)) {
      let expireTimeText = specialOfferItem?.getExpireTimeTextShort() ?? ""
      let show = expireTimeText != ""
      discountObj.show(show)
      if (show)
        discountObj.setValue(colorize("goodTextColor", loc("specialOffer/TillTime", { time = expireTimeText })))
    }

    let unlockTime = isInMenu() ? getCrewUnlockTimeByUnit(air) : 0
    let needShowUnlockTime = unlockTime > 0
    let lockObj = showObjById("aircraft-lockedCrew", needShowUnlockTime, obj)
    if (needShowUnlockTime && lockObj)
      lockObj.findObject("time").setValue(time.secondsToString(unlockTime))
    isActive = isActive || needShowUnlockTime

    let needShowPromUnitInfo = needShopInfo && fillPromUnitInfo(holderObj, air)
    isActive = isActive || needShowPromUnitInfo

    return !isActive
  })
}

::showAirInfo <- function showAirInfo(air, show, holderObj = null, handler = null, params = null) {
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

  let spare_cost = getGiftSparesCost(air)

  let tableObj = holderObj.findObject("air_info_panel_table")
  if (checkObj(tableObj)) {
    let isShowProgress = isInArray(air.esUnitType, [ ES_UNIT_TYPE_AIRCRAFT, ES_UNIT_TYPE_HELICOPTER ])
    tableObj["showStatsProgress"] = isShowProgress ? "yes" : "no"
  }

  let bitStatus = unitStatus.getBitStatus(air, params)
  holderObj.shopStat = getUnitItemStatusText(bitStatus, false)
  holderObj.unitRarity = getUnitRarity(air)

  let { showLocalState = true, needCrewModificators = false, needShopInfo = false, needCrewInfo = false,
    rentTimeHours = -1, isReceivedPrizes = false, researchExpInvest = 0, numSpares = 0 } = params
  let warbondId = params?.wbId
  let getEdiffFunc = handler?.getCurrentEdiff
  let ediff = getEdiffFunc ? getEdiffFunc.call(handler) : ::get_current_ediff()
  let difficulty = ::get_difficulty_by_ediff(ediff)
  let diffCode = difficulty.diffCode

  let unitType = getEsUnitType(air)
  let crew = params?.crewId != null ? getCrewById(params.crewId) : getCrewByAir(air)

  let isOwn = ::isUnitBought(air)
  let special = isUnitSpecial(air)
  let cost = wp_get_cost(air.name)
  let costGold = wp_get_cost_gold(air.name)
  let aircraftPrice = special ? costGold : cost
  let gift = isUnitGift(air)
  let showPrice = showLocalState && !isOwn && aircraftPrice > 0 && !gift && warbondId == null
  let isResearched = ::isUnitResearched(air)
  let canResearch = canResearchUnit(air)
  let rBlk = get_ranks_blk()
  let wBlk = get_warpoints_blk()

  let isRented = air.isRented()
  let showAsRent = (showLocalState && isRented) || rentTimeHours > 0
  let isSquadronVehicle = air.isSquadronVehicle()
  let isInClan = ::is_in_clan()
  let expCur = ::getUnitExp(air)
  let showShortestUnitInfo = air.showShortestUnitInfo

  let isSecondaryModsValid = ::check_unit_mods_update(air)
    && ::check_secondary_weapon_mods_recount(air)

  local obj = holderObj.findObject("aircraft-name")
  if (checkObj(obj))
    obj.setValue(getUnitName(air.name, false))

  obj = holderObj.findObject("aircraft-type")
  if (checkObj(obj)) {
    let fonticon = getUnitRoleIcon(air)
    let typeText = getFullUnitRoleText(air)
    obj.show(typeText != "")
    obj.setValue(colorize(::getUnitClassColor(air), fonticon + " " + typeText))
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
      let isResearching = ::isUnitInResearch(air) && (!isSquadronVehicle || isInClan || expInvest > 0)

      fillProgressBar(obj,
        isSquadronVehicle && isResearching ? expCur : expCur - expInvest,
        isSquadronVehicle && isResearching ? expCur + expInvest : expCur,
        expTotal, !isResearching)

      let labelObj = obj.findObject("exp")
      if (checkObj(labelObj)) {
        let statusText = isResearching ? loc("shop/in_research") + loc("ui/colon") : ""
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
          expText += colorize(isSquadronVehicle
            ? "cardProgressChangeSquadronColor"
            : "cardProgressTextBonusColor", loc("ui/parentheses/space",
            { text = "+ " + (isSquadronVehicle
              ? Cost().setSap(expInvest).tostring()
              : Cost().setRp(expInvest).tostring()) }))
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
      obj.findObject("country-image")["background-image"] = getCountryFlagForUnitTooltip(air.getOperatorCountry())
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
      nameObj.setValue(loc("shop/age") + loc("ui/colon"))
    let yearsObj = ageObj.findObject("age_years")
    if (checkObj(yearsObj))
      yearsObj.setValue(get_roman_numeral(air.rank))
  }

  //count unit ratings
  let showBr = !air.hideBrForVehicle
  let battleRating = air.getBattleRating(ediff)
  let brObj = showObjById("aircraft-battle_rating", showBr, holderObj)
  if (showBr) {
    brObj.findObject("aircraft-battle_rating-header").setValue($"{loc("shop/battle_rating")}{loc("ui/colon")}")
    brObj.findObject("aircraft-battle_rating-value").setValue(format("%.1f", air.getBattleRating(ediff)))
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
    let prevUnit = ::getPrevUnit(air)
    if (checkObj(prevUnitObj) && prevUnit) {
      prevUnitObj.show(true)
      let tdNameObj = prevUnitObj.findObject("aircraft-prevUnit")
      if (checkObj(tdNameObj))
        tdNameObj.setValue(format(loc("shop/prevUnitEfficiencyResearch"), getUnitName(prevUnit, true)))
      let tdValueObj = prevUnitObj.findObject("aircraft-prevUnit_bonus")
      if (checkObj(tdValueObj)) {
        let param_name = "prevAirExpMulMode"
        let curVal = rBlk?[param_name + diffCode.tostring()] ?? 1

        if (curVal != 1)
          tdValueObj.setValue(format("<color=@userlogColoredText>%s%%</color>", (curVal * 100).tostring()))
        else
          prevUnitObj.show(false)
      }
    }
  }

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
      { id = "turnTurretTime", id2 = "turnTurretSpeed", prepareTextFunc = function(value) { return format("%.1f%s", value.tofloat(), loc("measureUnits/deg_per_sec")) } }
    ],
    [ES_UNIT_TYPE_BOAT] = [
      //TODO ship modificators
      { id = "maxSpeed", id2 = "maxSpeed", prepareTextFunc = @(value) countMeasure(0, value) }
    ],
    [ES_UNIT_TYPE_SHIP] = [
      //TODO ship modificators
      { id = "maxSpeed", id2 = "maxSpeed", prepareTextFunc = @(value) countMeasure(0, value) }
    ],
    [ES_UNIT_TYPE_HELICOPTER] = [
      { id = "maxSpeed", id2 = "speed", prepareTextFunc = @(value) countMeasure(0, value) }
      { id = "climbSpeed", id2 = "climb", prepareTextFunc = @(value) countMeasure(3, value) }
    ]
  }

  local showReferenceText = false
  foreach (item in (modCharacteristics?[unitType] ?? {})) {
    let characteristicArr = ::getCharacteristicActualValue(air, [item.id, item.id2],
      item.prepareTextFunc, difficulty.crewSkillName, showLocalState || needCrewModificators)
    holderObj.findObject("aircraft-" + item.id).setValue(characteristicArr[0])

    if (!showLocalState && !needCrewModificators)
      continue

    let wmodObj = holderObj.findObject("aircraft-weaponmod-" + item.id)
    if (wmodObj)
      wmodObj.setValue(characteristicArr[1])

    let progressObj = holderObj.findObject("aircraft-progress-" + item.id)
    setReferenceMarker(progressObj, characteristicArr[2], characteristicArr[3], characteristicArr[5], difficulty.crewSkillName)
    fillAirCharProgress(progressObj, characteristicArr[2], characteristicArr[3], characteristicArr[4])
    showReferenceText = showReferenceText || characteristicArr[6]

    let waitObj = holderObj.findObject("aircraft-" + item.id + "-wait")
    if (waitObj)
      waitObj.show(!isSecondaryModsValid)
  }
  let refTextObj = holderObj.findObject("references_text")
  if (checkObj(refTextObj))
    refTextObj.show(showReferenceText)

  holderObj.findObject("aircraft-speedAlt").setValue((air.shop?.maxSpeedAlt ?? 0) > 0 ?
    countMeasure(1, air.shop.maxSpeedAlt) : loc("shop/max_speed_alt_sea"))
//    holderObj.findObject("aircraft-climbTime").setValue(format("%02d:%02d", air.shop.climbTime.tointeger() / 60, air.shop.climbTime.tointeger() % 60))
//    holderObj.findObject("aircraft-climbAlt").setValue(countMeasure(1, air.shop.climbAlt))
  holderObj.findObject("aircraft-altitude").setValue(countMeasure(1, air.shop.maxAltitude))
  holderObj.findObject("aircraft-airfieldLen").setValue(countMeasure(1, air.shop.airfieldLen))
  holderObj.findObject("aircraft-wingLoading").setValue(countMeasure(5, air.shop.wingLoading))
//  holderObj.findObject("aircraft-range").setValue(countMeasure(2, air.shop.range * 1000.0))

  let totalCrewObj = holderObj.findObject("total-crew")
  if (checkObj(totalCrewObj))
    totalCrewObj.setValue(air.getCrewTotalCount().tostring())

  let cardAirplaneWingLoadingParameter = hasFeature("CardAirplaneWingLoadingParameter")
  let cardAirplanePowerParameter = hasFeature("CardAirplanePowerParameter")
  let cardHelicopterClimbParameter = hasFeature("CardHelicopterClimbParameter")

  let showCharacteristics = {
    ["aircraft-turnTurretTime-tr"]        = [ ES_UNIT_TYPE_TANK ],
    ["aircraft-angleVerticalGuidance-tr"] = [ ES_UNIT_TYPE_TANK ],
    ["aircraft-shotFreq-tr"]              = [ ES_UNIT_TYPE_TANK ],
    ["aircraft-reloadTime-tr"]            = [ ES_UNIT_TYPE_TANK ],
    ["aircraft-weaponPresets-tr"]         = [ ES_UNIT_TYPE_AIRCRAFT, ES_UNIT_TYPE_HELICOPTER ],
    ["aircraft-massPerSec-tr"]            = [ ES_UNIT_TYPE_AIRCRAFT, ES_UNIT_TYPE_HELICOPTER ],
    ["aircraft-armorThicknessHull-tr"]    = [ ES_UNIT_TYPE_TANK ],
    ["aircraft-armorThicknessTurret-tr"]  = [ ES_UNIT_TYPE_TANK ],
    ["aircraft-armorPiercing-tr"]         = [ ES_UNIT_TYPE_TANK ],
    ["aircraft-armorPiercingDist-tr"]     = [ ES_UNIT_TYPE_TANK ],
    ["aircraft-mass-tr"]                  = [ ES_UNIT_TYPE_TANK ],
    ["aircraft-horsePowers-tr"]           = [ ES_UNIT_TYPE_TANK ],
    ["aircraft-maxSpeed-tr"]              = [ ES_UNIT_TYPE_AIRCRAFT, ES_UNIT_TYPE_TANK,
                                              ES_UNIT_TYPE_BOAT, ES_UNIT_TYPE_SHIP, ES_UNIT_TYPE_HELICOPTER ],
    ["aircraft-maxDepth-tr"]              = [ ES_UNIT_TYPE_BOAT, ES_UNIT_TYPE_SHIP ],
    ["aircraft-speedAlt-tr"]              = [ ES_UNIT_TYPE_AIRCRAFT, ES_UNIT_TYPE_HELICOPTER ],
    ["aircraft-altitude-tr"]              = [ ES_UNIT_TYPE_AIRCRAFT, ES_UNIT_TYPE_HELICOPTER ],
    ["aircraft-turnTime-tr"]              = [ ES_UNIT_TYPE_AIRCRAFT ],
    ["aircraft-climbSpeed-tr"]            = cardHelicopterClimbParameter ? [ ES_UNIT_TYPE_AIRCRAFT, ES_UNIT_TYPE_HELICOPTER ] : [ ES_UNIT_TYPE_AIRCRAFT ],
    ["aircraft-airfieldLen-tr"]           = [ ES_UNIT_TYPE_AIRCRAFT ],
    ["aircraft-wingLoading-tr"]           = cardAirplaneWingLoadingParameter ? [ ES_UNIT_TYPE_AIRCRAFT ] : [],
    ["aircraft-visibilityFactor-tr"]      = [ ES_UNIT_TYPE_TANK ]
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

  let modificators = (showLocalState || needCrewModificators) ? "modificators" : "modificatorsBase"
  if (air.isTank() && air[modificators]) {
    let currentParams = air[modificators][difficulty.crewSkillName]
    let horsePowers = currentParams.horsePowers;
    let horsePowersRPM = currentParams.maxHorsePowersRPM;
    holderObj.findObject("aircraft-horsePowers").setValue(
      format("%s %s %d %s", ::g_measure_type.HORSEPOWERS.getMeasureUnitsText(horsePowers),
        loc("shop/unitValidCondition"), horsePowersRPM.tointeger(), loc("measureUnits/rpm")))
    local thickness = currentParams.armorThicknessHull;
    holderObj.findObject("aircraft-armorThicknessHull").setValue(format("%d / %d / %d %s", thickness[0].tointeger(), thickness[1].tointeger(), thickness[2].tointeger(), loc("measureUnits/mm")))
    thickness = currentParams.armorThicknessTurret;
    holderObj.findObject("aircraft-armorThicknessTurret").setValue(format("%d / %d / %d %s", thickness[0].tointeger(), thickness[1].tointeger(), thickness[2].tointeger(), loc("measureUnits/mm")))
    let angles = currentParams.angleVerticalGuidance;
    holderObj.findObject("aircraft-angleVerticalGuidance").setValue(format("%d / %d%s", angles[0].tointeger(), angles[1].tointeger(), loc("measureUnits/deg")))
    let armorPiercing = currentParams.armorPiercing;
    if (armorPiercing.len() > 0) {
      let textParts = []
      local countOutputValue = min(armorPiercing.len(), 3)
      for (local i = 0; i < countOutputValue; i++)
        textParts.append(stdMath.round(armorPiercing[i]).tointeger())
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
    local reloadTime = ("reloadTime" in currentParams && currentParams.reloadTime > 0) ? currentParams.reloadTime : null;
    if ((currentParams?.reloadTimeByDiff?[diffCode] ?? 0) > 0)
      reloadTime = currentParams.reloadTimeByDiff[diffCode]
    let visibilityFactor = ("visibilityFactor" in currentParams && currentParams.visibilityFactor > 0) ? currentParams.visibilityFactor : null;

    holderObj.findObject("aircraft-shotFreq-tr").show(shotFreq);
    holderObj.findObject("aircraft-reloadTime-tr").show(reloadTime);
    holderObj.findObject("aircraft-visibilityFactor-tr").show(visibilityFactor);
    if (shotFreq) {
      let val = stdMath.roundToDigits(shotFreq * 60, 3).tostring()
      holderObj.findObject("aircraft-shotFreq").setValue(format("%s %s", val, loc("measureUnits/shotPerMinute")))
    }
    if (reloadTime)
      holderObj.findObject("aircraft-reloadTime").setValue(format("%.1f %s", reloadTime, loc("measureUnits/seconds")))
    if (visibilityFactor) {
      holderObj.findObject("aircraft-visibilityFactor-title").setValue(loc("shop/visibilityFactor") + loc("ui/colon"))
      holderObj.findObject("aircraft-visibilityFactor-value").setValue(format("%d %%", visibilityFactor))
    }
  }

  if (unitType == ES_UNIT_TYPE_SHIP || unitType == ES_UNIT_TYPE_BOAT) {
    let unitTags = get_unittags_blk()?[air.name] ?? {}

    // ship-displacement
    let displacementKilos = unitTags?.Shop?.displacement
    holderObj.findObject("ship-displacement-tr").show(displacementKilos != null)
    if (displacementKilos != null) {
      let displacementString = ::g_measure_type.SHIP_DISPLACEMENT_TON.getMeasureUnitsText(displacementKilos / 1000, true)
      holderObj.findObject("ship-displacement-title").setValue(loc("info/ship/displacement") + loc("ui/colon"))
      holderObj.findObject("ship-displacement-value").setValue(displacementString)
    }

    // submarine-depth
    let depthValue = unitTags?.Shop?.maxDepth ?? 0
    holderObj.findObject("aircraft-maxDepth-tr").show(depthValue > 0)
    if (depthValue > 0)
      holderObj.findObject("aircraft-maxDepth").setValue(depthValue + loc("measureUnits/meters_alt"))

    // ship-citadelArmor
    let armorThicknessCitadel = unitTags?.Shop.armorThicknessCitadel
    holderObj.findObject("ship-citadelArmor-tr").show(armorThicknessCitadel != null)
    if (armorThicknessCitadel != null) {
      let val = [
        stdMath.round(armorThicknessCitadel.x).tointeger(),
        stdMath.round(armorThicknessCitadel.y).tointeger(),
        stdMath.round(armorThicknessCitadel.z).tointeger(),
      ]
      holderObj.findObject("ship-citadelArmor-title").setValue(loc("info/ship/citadelArmor") + loc("ui/colon"))
      holderObj.findObject("ship-citadelArmor-value").setValue(
        format("%d / %d / %d %s", val[0], val[1], val[2], loc("measureUnits/mm")))
    }

    // ship-mainFireTower
    let armorThicknessMainFireTower = unitTags?.Shop.armorThicknessTurretMainCaliber
    holderObj.findObject("ship-mainFireTower-tr").show(armorThicknessMainFireTower != null)
    if (armorThicknessMainFireTower != null) {
      let val = [
        stdMath.round(armorThicknessMainFireTower.x).tointeger(),
        stdMath.round(armorThicknessMainFireTower.y).tointeger(),
        stdMath.round(armorThicknessMainFireTower.z).tointeger(),
      ]
      holderObj.findObject("ship-mainFireTower-title").setValue(loc("info/ship/mainFireTower") + loc("ui/colon"))
      holderObj.findObject("ship-mainFireTower-value").setValue(
        format("%d / %d / %d %s", val[0], val[1], val[2], loc("measureUnits/mm")))
    }

    // ship-antiTorpedoProtection
    let atProtection = unitTags?.Shop.atProtection
    holderObj.findObject("ship-antiTorpedoProtection-tr").show(atProtection != null)
    if (atProtection != null) {
      holderObj.findObject("ship-antiTorpedoProtection-title").setValue(
        "".concat(loc("info/ship/antiTorpedoProtection"), loc("ui/colon")))
      holderObj.findObject("ship-antiTorpedoProtection-value").setValue(
        format("%d %s", atProtection, loc("measureUnits/kg")))
    }

    let shipMaterials = getShipMaterialTexts(air.name)

    // ship-hullMaterial
    {
      let valueText = shipMaterials?.hullValue ?? ""
      let isShow = valueText != ""
      holderObj.findObject("ship-hullMaterial-tr").show(isShow)
      if (isShow) {
        let labelText = (shipMaterials?.hullLabel ?? "") + loc("ui/colon")
        holderObj.findObject("ship-hullMaterial-title").setValue(labelText)
        holderObj.findObject("ship-hullMaterial-value").setValue(valueText)
      }
    }

    // ship-superstructureMaterial
    {
      let valueText = shipMaterials?.superstructureValue ?? ""
      let isShow = valueText != ""
      holderObj.findObject("ship-superstructureMaterial-tr").show(isShow)
      if (isShow) {
        let labelText = (shipMaterials?.superstructureLabel ?? "") + loc("ui/colon")
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

  let showRewardsInfo = !(params?.showRewardsInfoOnlyForPremium ?? false) || special
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

      if (f.multiplier == 0)
        continue

      if (!hasTimedAward && f.isTimedAward)
        hasTimedAward = true
      let result = f.multiplier * f.premUnitMul * (f.noBonus + f.premAccBonus + f.premModBonus + f.boosterBonus)
      local resultText = f.isTimedAward ? result : ::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText(result)
      resultText = "".concat(colorize("activeTextColor", resultText), loc(f.currency), f.isTimedAward ? loc("measureUnits/perMinute") : "")

      let sources = [NO_BONUS.__merge({ text = ::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText(f.noBonus) })]
      if (f.premAccBonus  > 0)
        sources.append(PREM_ACC.__merge({ text = ::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText(f.premAccBonus) }))
      if (f.premModBonus  > 0)
        sources.append(PREM_MOD.__merge({ text = ::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText(f.premModBonus) }))
      if (f.boosterBonus  > 0)
        sources.append(BOOSTER.__merge({ text = ::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText(f.boosterBonus) }))
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
      timedAwardHintTextObj.show(true)
    }
  }

  if (holderObj.findObject("aircraft-spare-tr")) {
    let spareCount = showLocalState ? get_spare_aircrafts_count(air.name) : 0
    holderObj.findObject("aircraft-spare-tr").show(spareCount > 0)
    if (spareCount > 0)
      holderObj.findObject("aircraft-spare").setValue(spareCount.tostring() + loc("icon/spare"))
  }

  let fullRepairTd = holderObj.findObject("aircraft-full_repair_cost-td")
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
      discountsList[modeName] <- modeName + "-discount"
      repairCostData += format("tdiv { " +
                                 "textareaNoTab {smallFont:t='yes' text:t='%s' }" +
                                 "discount { id:t='%s'; text:t=''; pos:t='-1*@scrn_tgt/100.0, 0.5ph-0.55h'; position:t='relative'; rotation:t='8' }" +
                               "}\n",
                          ((repairCostData != "") ? "/ " : "") + Cost(avgCost.tointeger()).getTextAccordingToBalance(),
                          discountsList[modeName]
                        )
    }
    holderObj.getScene().replaceContentFromText(fullRepairTd, repairCostData, repairCostData.len(), null)
    foreach (modeName, objName in discountsList)
      ::showAirDiscount(fullRepairTd.findObject(objName), air.name, "repair", modeName)

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
      ::hideBonus(holderObj.findObject("aircraft-full_repair_cost-discount"))
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
        if (::isUnitInResearch(air))
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

  if (isInFlight()) {
    let missionRules = getCurMissionRules()
    if (missionRules.isWorldWarUnit(air.name)) {
      addInfoTextsList.append(loc("icon/worldWar/colored") + colorize("activeTextColor", loc("worldwar/unit")))
      addInfoTextsList.append(loc("worldwar/unit/desc"))
    }
    if (missionRules.hasCustomUnitRespawns()) {
      let disabledUnitByBRText = crew && !isCrewAvailableInSession(crew, air)
        && ::SessionLobby.getNotAvailableUnitByBRText(air)

      let respawnsleft = missionRules.getUnitLeftRespawns(air)
      if (respawnsleft == 0 || (respawnsleft > 0 && !disabledUnitByBRText)) {
        if (missionRules.isUnitAvailableBySpawnScore(air)) {
          addInfoTextsList.append(loc("icon/star/white") + colorize("activeTextColor", loc("worldWar/unit/wwSpawnScore")))
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
    let warbond = ::g_warbonds.findWarbond(warbondId, params?.wbListId)
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
      let text = loc("mainmenu/itemReceived") + loc("ui/dot") + " " +
        loc(params?.relatedItem ? "mainmenu/activateOnlyOnce" : "mainmenu/receiveOnlyOnce")
      addInfoTextsList.append(colorize("badTextColor", text))
    }
  }
  else {
    if (::canBuyUnitOnline(air)) {
      addInfoTextsList.append(colorize("userlogColoredText",
        format(loc("shop/giftAir/" + air.gift + "/info"), air.giftParam ? loc(air.giftParam) : "")))
      if (showLocalState)
        if (!isSquadronVehicle && spare_count > 0)
          addInfoTextsList.append(colorize("userlogColoredText", loc(giftSparesLoc,
            { num = spare_count, cost = Cost().setGold(spare_cost * spare_count) })))
    }
    if (isUnitDefault(air))
      addInfoTextsList.append(loc("shop/reserve/info"))
    if (::canBuyUnitOnMarketplace(air))
      addInfoTextsList.append(colorize("userlogColoredText", loc("shop/giftAir/coupon/info")))
  }

  let showPriceText = rentTimeHours == -1 && showLocalState && !::isUnitBought(air)
    && ::isUnitResearched(air) && !::canBuyUnitOnline(air) && canBuyUnit(air)
  let priceObj = showObjById("aircraft_price", showPriceText, holderObj)
  if (showPriceText && checkObj(priceObj) && ::g_discount.getUnitDiscountByName(air.name) > 0) {
    placePriceTextToButton(holderObj, "aircraft_price",
      colorize("userlogColoredText", loc("events/air_can_buy")), ::getUnitCost(air), 0, ::getUnitRealCost(air))

    if (!isSquadronVehicle && spare_count > 0)
      addInfoTextsList.append(colorize("userlogColoredText", loc(giftSparesLoc,
        { num = spare_count, cost = Cost().setGold(spare_cost * spare_count) })))
  }
  else if (showPriceText && warbondId == null && showLocalState) {
    let priceText = colorize("activeTextColor", ::getUnitCost(air).getTextAccordingToBalance())
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
    let crewLevel = ::g_crew.getCrewLevel(crew, air, crewUnitType)
    let crewStatus = ::get_crew_status(crew, air)
    let specType = ::g_crew_spec_type.getTypeByCrewAndUnit(crew, air)
    let crewSpecIcon = specType.trainedIcon
    let crewSpecName = specType.getName()

    obj = holderObj.findObject("aircraft-crew_info")
    if (checkObj(obj))
      obj.show(true)

    obj = holderObj.findObject("aircraft-crew_name")
    if (checkObj(obj))
      obj.setValue(::g_crew.getCrewName(crew))

    obj = holderObj.findObject("aircraft-crew_level")
    if (checkObj(obj))
      obj.setValue(loc("crew/usedSkills") + " " + crewLevel)
    obj = holderObj.findObject("aircraft-crew_spec-label")
    if (checkObj(obj))
      obj.setValue(loc("crew/trained") + loc("ui/colon"))
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
      obj.setValue(loc("crew/availablePoints/advice") + loc("ui/colon") + crewPointsText)
      obj["crewStatus"] = crewStatus
    }
  }

  if (needShopInfo && !isRented) {
    let reason = ::getCantBuyUnitReason(air, true)
    let addTextObj = showObjById("aircraft-cant_buy_info", !showShortestUnitInfo, holderObj)
    if (checkObj(addTextObj) && !u.isEmpty(reason)) {
      addTextObj.setValue(colorize("redMenuButtonColor", reason))

      let unitNest = showObjById("prev_unit_nest", !showShortestUnitInfo, holderObj)
      if (checkObj(unitNest) && (!::isPrevUnitResearched(air) || !::isPrevUnitBought(air)) &&
        is_era_available(air.shopCountry, air?.rank ?? -1, unitType)) {
        let prevUnit = ::getPrevUnit(air)
        let unitBlk = buildUnitSlot(prevUnit.name, prevUnit)
        holderObj.getScene().replaceContentFromText(unitNest, unitBlk, unitBlk.len(), handler)
        fillUnitSlotTimers(unitNest.findObject(prevUnit.name), prevUnit)
      }
    }
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
        surviveText = (survive * 100).tointeger() + "%"
        let wins = stats?.wins_flyouts ?? 0.0
        winsText = (wins * 100).tointeger() + "%"

        let usage = stats?.flyouts_factor ?? 0.0
        if (usage >= 0.000001) {
          rating = 0
          foreach (r in ::usageRating_amount)
            if (usage > r)
              rating++
          usageText = loc($"shop/usageRating/{rating}")
          if (has_entitlement("AccessTest"))
            usageText += " (" + (usage * 100).tointeger() + "%)"
        }
      }
      holderObj.findObject("aircraft-surviveRating-tr").show(true)
      holderObj.findObject("aircraft-surviveRating").setValue(surviveText)
      holderObj.findObject("aircraft-winsRating-tr").show(true)
      holderObj.findObject("aircraft-winsRating").setValue(winsText)
      holderObj.findObject("aircraft-usageRating-tr").show(true)
      if (rating >= 0)
        holderObj.findObject("aircraft-usageRating").overlayTextColor = "usageRating" + rating;
      holderObj.findObject("aircraft-usageRating").setValue(usageText)
    }
  }

  let weaponsInfoText = getWeaponInfoText(air,
    { weaponPreset = showLocalState ? -1 : 0, ediff = ediff, isLocalState = showLocalState })
  obj = showObjById("weaponsInfo", !showShortestUnitInfo, holderObj)
  if (obj)
    obj.setValue(weaponsInfoText)

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
    let minAge = ::getMinBestLevelingRank(air)
    let maxAge = ::getMaxBestLevelingRank(air)
    let rangeText = (minAge == maxAge) ? (get_roman_numeral(minAge) + nbsp + loc("shop/age")) :
        (get_roman_numeral(minAge) + nbsp + loc("ui/mdash") + nbsp + get_roman_numeral(maxAge) + nbsp + loc("mainmenu/ranks"))
    obj.findObject("aircraft-research-efficiency").setValue(rangeText)
  }

  let wPresets = getUnitWeaponPresetsCount(air)
  obj = holderObj.findObject("aircraft-weaponPresets")
  if (checkObj(obj))
    obj.setValue(wPresets.tostring())

  obj = showObjById("current_game_mode_footnote_text", !showShortestUnitInfo, holderObj)
  if (checkObj(obj)) {
    let battleType = ::get_battle_type_by_ediff(ediff)
    let fonticon = !CAN_USE_EDIFF ? "" :
      loc(battleType == BATTLE_TYPES.AIR ? "icon/unittype/aircraft" : "icon/unittype/tank")
    let diffName = nbsp.join([ fonticon, difficulty.getLocName() ], true)

    let unitStateId = !showLocalState ? "reference"
      : crew ? "current_crew"
      : "current"
    let unitState = loc($"shop/showing_unit_state/{unitStateId}")

    obj.setValue(loc("shop/all_info_relevant_to_current_game_mode") + loc("ui/colon") + diffName + "\n" + unitState)
  }

  obj = holderObj.findObject("unit_rent_time")
  if (checkObj(obj))
    obj.show(false)

  if (showLocalState)
    ::fillAirInfoTimers(holderObj, air, needShopInfo)
}

local __types_for_coutries = null //for avoid recalculations
::get_unit_types_in_countries <- function get_unit_types_in_countries() {
  if (__types_for_coutries)
    return __types_for_coutries

  let defaultCountryData = {}
  foreach (unitType in unitTypes.types)
    defaultCountryData[unitType.esUnitType] <- false

  __types_for_coutries = {}
  foreach (country in shopCountriesList)
    __types_for_coutries[country] <- clone defaultCountryData

  foreach (unit in getAllUnits()) {
    if (!unit.unitType.isAvailable())
      continue
    let esUnitType = unit.unitType.esUnitType
    let countryData = __types_for_coutries?[getUnitCountry(unit)]
    if (countryData != null && !countryData?[esUnitType])
      countryData[esUnitType] <- ::isUnitBought(unit)
  }

  return __types_for_coutries
}

::is_loaded_model_high_quality <- function is_loaded_model_high_quality(def = true) {
  if (hangar_get_loaded_unit_name() == "")
    return def
  return hangar_is_high_quality()
}

::get_units_list <- function get_units_list(filterFunc) {
  let res = []
  foreach (unit in getAllUnits())
    if (filterFunc(unit))
      res.append(unit)
  return res
}

let function isUnitAvailableForRank(unit, rank, esUnitType, country, exact_rank, needBought) {
  // Keep this in sync with getUnitsCountAtRank() in chard
  return (esUnitType == getEsUnitType(unit) || esUnitType == ES_UNIT_TYPE_TOTAL)
    && (country == unit.shopCountry || country == "")
    && (unit.rank == rank || (!exact_rank && unit.rank > rank))
    && ((!needBought || ::isUnitBought(unit)) && unit.isVisibleInShop())
}

let function hasUnitAtRank(rank, esUnitType, country, exact_rank, needBought = true) {
  foreach (unit in getAllUnits())
    if (isUnitAvailableForRank(unit, rank, esUnitType, country, exact_rank, needBought))
      return true
  return false
}

::get_units_count_at_rank <- function get_units_count_at_rank(rank, esUnitType, country, exact_rank, needBought = true) {
  local count = 0
  foreach (unit in getAllUnits())
    if (isUnitAvailableForRank(unit, rank, esUnitType, country, exact_rank, needBought))
      count++
  return count
}

{
  local unitCacheName = null
  local unitCacheBlk = null
  ::get_full_unit_blk <- function get_full_unit_blk(unitName) { //better to not use this funtion, and collect all data from wpcost and unittags
    if (unitName != unitCacheName) {
      unitCacheName = unitName
      unitCacheBlk = DataBlock()
      let path = getUnitFileName(unitName)
      if (!unitCacheBlk.tryLoad(path, true))
        logerr($"not found unit blk on filePath = {path}")
    }
    return unitCacheBlk
  }
}

::get_fm_file <- function get_fm_file(unitId, unitBlkData = null) {
  let unitPath = getUnitFileName(unitId)
  if (unitBlkData == null)
    unitBlkData = ::get_full_unit_blk(unitId)
  let nodes = split_by_chars(unitPath, "/")
  if (nodes.len())
    nodes.pop()
  let unitDir = "/".join(nodes, true)
  let fmPath = unitDir + "/" + (unitBlkData?.fmFile ?? ("fm/" + unitId))
  return blkFromPath(fmPath)
}

return {
  CheckFeatureLockAction
  hasUnitAtRank
}
