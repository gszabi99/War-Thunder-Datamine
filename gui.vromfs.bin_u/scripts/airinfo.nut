local { blkFromPath } = require("sqStdLibs/helpers/datablockUtils.nut")
local SecondsUpdater = require("sqDagui/timer/secondsUpdater.nut")
local time = require("scripts/time.nut")
local stdMath = require("std/math.nut")
local { getUnitRoleIcon, getUnitTooltipImage, getFullUnitRoleText,
  getChanceToMeetText, getShipMaterialTexts, getUnitItemStatusText,
  getUnitRarity, getUnitRequireUnlockText } = require("scripts/unit/unitInfoTexts.nut")
local unitStatus = require("scripts/unit/unitStatus.nut")
local countMeasure = require("scripts/options/optionsMeasureUnits.nut").countMeasure
local { getCrewPoints } = require("scripts/crew/crewSkills.nut")
local { getWeaponInfoText } = require("scripts/weaponry/weaponryDescription.nut")
local { isWeaponAux,
        getLastWeapon,
        getLastPrimaryWeapon } = require("scripts/weaponry/weaponryInfo.nut")
local unitTypes = require("scripts/unit/unitTypesList.nut")
local { placePriceTextToButton } = require("scripts/viewUtils/objectTextUpdate.nut")
local { isModResearched, getModificationByName
} = require("scripts/weaponry/modificationInfo.nut")
local { getCrewUnlockTimeByUnit } = require("scripts/crew/crewInfo.nut")
local { isModificationInTree } = require("scripts/weaponry/modsTree.nut")
local { boosterEffectType, getActiveBoostersArray,
  getBoostersEffects } = require("scripts/items/boosterEffect.nut")
local { isMarketplaceEnabled } = require("scripts/items/itemsMarketplace.nut")


const MODIFICATORS_REQUEST_TIMEOUT_MSEC = 20000

global enum CheckFeatureLockAction
{
  BUY,
  RESEARCH
}

local function afterUpdateAirModificators(unit, callback)
{
  if (unit.secondaryWeaponMods)
    unit.secondaryWeaponMods = null //invalidate secondary weapons cache
  ::broadcastEvent("UnitModsRecount", { unit = unit })
  if(callback != null)
    callback()
}

local function fillProgressBar(obj, curExp, newExp, maxExp, isPaused = false)
{
  if (!::checkObj(obj) || !maxExp)
    return

  local guiScene = obj.getScene()
  if (!guiScene)
    return

  guiScene.replaceContent(obj, "gui/countryExpItem.blk", this)

  local barObj = obj.findObject("expProgressOld")
  if (::checkObj(barObj))
  {
    barObj.show(true)
    barObj.setValue(1000.0 * curExp / maxExp)
    barObj.paused = isPaused ? "yes" : "no"
  }

  barObj = obj.findObject("expProgress")
  if (::checkObj(barObj))
  {
    barObj.show(true)
    barObj.setValue(1000.0 * newExp / maxExp)
    barObj.paused = isPaused ? "yes" : "no"
  }
}

::get_es_unit_type <- function get_es_unit_type(unit)
{
  return ::getTblValue("esUnitType", unit, ::ES_UNIT_TYPE_INVALID)
}

::getUnitTypeTextByUnit <- function getUnitTypeTextByUnit(unit)
{
  return ::getUnitTypeText(::get_es_unit_type(unit))
}

::isCountryHaveUnitType <- function isCountryHaveUnitType(country, unitType)
{
  foreach(unit in ::all_units)
    if (unit.shopCountry == country && ::get_es_unit_type(unit) == unitType)
      return true
  return false
}

::isUnitsEraUnlocked <- function isUnitsEraUnlocked(unit)
{
  return ::is_era_available(::getUnitCountry(unit), unit?.rank ?? -1, ::get_es_unit_type(unit))
}

::getUnitsNeedBuyToOpenNextInEra <- function getUnitsNeedBuyToOpenNextInEra(countryId, unitType, rank, ranksBlk = null)
{
  ranksBlk = ranksBlk || ::get_ranks_blk()
  local unitTypeText = getUnitTypeText(unitType)

  local needToOpen = ranksBlk?.needBuyToOpenNextInEra[countryId]["needBuyToOpenNextInEra" + unitTypeText + rank]
  if (needToOpen != null)
    return needToOpen

  needToOpen = ranksBlk?.needBuyToOpenNextInEra[countryId]["needBuyToOpenNextInEra" + rank]
  if (needToOpen != null)
    return needToOpen

  return -1
}

::getUnitCountry <- function getUnitCountry(unit)
{
  return ::getTblValue("shopCountry", unit, "")
}

::isUnitDefault <- function isUnitDefault(unit)
{
  if (!("name" in unit))
    return false
  return ::is_default_aircraft(unit.name)
}

::isUnitGift <- function isUnitGift(unit)
{
  return unit.gift != null
}

::get_unit_country_icon <- function get_unit_country_icon(unit, needOperatorCountry = false)
{
  return ::get_country_icon(needOperatorCountry ? unit.getOperatorCountry() : unit.shopCountry)
}

::isUnitGroup <- function isUnitGroup(unit)
{
  return unit && "airsGroup" in unit
}

::isGroupPart <- function isGroupPart(unit)
{
  return unit && unit.group != null
}

::canResearchUnit <- function canResearchUnit(unit)
{
  local isInShop = ::getTblValue("isInShop", unit)
  if (isInShop == null)
  {
    debugTableData(unit)
    ::dagor.assertf(false, "not existing isInShop param")
    return false
  }

  if (!isInShop)
    return false

  if (unit.reqUnlock && !::is_unlocked_scripted(-1, unit.reqUnlock))
    return false

  local status = ::shop_unit_research_status(unit.name)
  return (0 != (status & (::ES_ITEM_STATUS_IN_RESEARCH | ::ES_ITEM_STATUS_CAN_RESEARCH))) && !::isUnitMaxExp(unit)
}

::canBuyUnit <- function canBuyUnit(unit)
{
  if (::isUnitGift(unit))  //!!! FIX ME shop_unit_research_status may return ES_ITEM_STATUS_CAN_BUY
    return false           // if vehicle could be bought in game, but it became a gift vehicle.

  if (unit.reqUnlock && !::is_unlocked_scripted(-1, unit.reqUnlock))
    return false

  local status = ::shop_unit_research_status(unit.name)
  return (0 != (status & ::ES_ITEM_STATUS_CAN_BUY)) && unit.isVisibleInShop()
}

::canBuyUnitOnline <- function canBuyUnitOnline(unit)
{
  return !::isUnitBought(unit) && ::isUnitGift(unit) && unit.isVisibleInShop()
    && !::canBuyUnitOnMarketplace(unit)
}

::canBuyUnitOnMarketplace <- function canBuyUnitOnMarketplace(unit)
{
  return unit.marketplaceItemdefId != null
    && !::isUnitBought(unit)
    && isMarketplaceEnabled()
    && (::ItemsManager.findItemById(unit.marketplaceItemdefId)?.hasLink() ?? false)
}

::isUnitInResearch <- function isUnitInResearch(unit)
{
  if (!unit)
    return false

  if(!("name" in unit))
    return false

  local status = ::shop_unit_research_status(unit.name)
  return ((status & ::ES_ITEM_STATUS_IN_RESEARCH) != 0) && !::isUnitMaxExp(unit)
}

::findUnitNoCase <- function findUnitNoCase(unitName)
{
  unitName = unitName.tolower()
  foreach(name, unit in ::all_units)
    if (name.tolower() == unitName)
      return unit
  return null
}

::getUnitName <- function getUnitName(unit, shopName = true)
{
  local unitId = ::u.isUnit(unit) ? unit.name
    : ::u.isString(unit) ? unit
    : ""
  local localized = ::loc(unitId + (shopName ? "_shop" : "_0"), unitId)
  return shopName ? ::stringReplace(localized, " ", ::nbsp) : localized
}

::isUnitDescriptionValid <- function isUnitDescriptionValid(unit)
{
  if (!::has_feature("UnitInfo"))
    return false
  if (::has_feature("WikiUnitInfo"))
    return true // Because there is link to wiki.
  local desc = unit ? ::loc("encyclopedia/" + unit.name + "/desc", "") : ""
  return desc != "" && desc != ::loc("encyclopedia/no_unit_description")
}

::getUnitRealCost <- function getUnitRealCost(unit)
{
  return ::Cost(unit.cost, unit.costGold)
}

::getUnitCost <- function getUnitCost(unit)
{
  return ::Cost(::wp_get_cost(unit.name),
                ::wp_get_cost_gold(unit.name))
}

::isUnitBought <- function isUnitBought(unit)
{
  return unit ? unit.isBought() : false
}

::isUnitEliteByStatus <- function isUnitEliteByStatus(status)
{
  return status > ::ES_UNIT_ELITE_STAGE1
}

::isUnitElite <- function isUnitElite(unit)
{
  local unitName = ::getTblValue("name", unit)
  return unitName ? ::isUnitEliteByStatus(::get_unit_elite_status(unitName)) : false
}

::isUnitBroken <- function isUnitBroken(unit)
{
  return ::getUnitRepairCost(unit) > 0
}

/**
 * Returns true if unit can be installed in slotbar,
 * unit can be decorated with decals, etc...
 */
::isUnitUsable <- function isUnitUsable(unit)
{
  return unit ? unit.isUsable() : false
}

::isUnitFeatureLocked <- function isUnitFeatureLocked(unit)
{
  return unit.reqFeature != null && !::has_feature(unit.reqFeature)
}

::getUnitRepairCost <- function getUnitRepairCost(unit)
{
  if ("name" in unit)
    return ::wp_get_repair_cost(unit.name)
  return 0
}

::buyUnit <- function buyUnit(unit, silent = false)
{
  if (!::checkFeatureLock(unit, CheckFeatureLockAction.BUY))
    return false

  local canBuyNotResearchedUnit = unitStatus.canBuyNotResearched(unit)
  local unitCost = canBuyNotResearchedUnit ? unit.getOpenCost() : ::getUnitCost(unit)
  if (unitCost.gold > 0 && !::can_spend_gold_on_unit_with_popup(unit))
    return false

  if (!::canBuyUnit(unit) && !canBuyNotResearchedUnit)
  {
    if ((::isUnitResearched(unit) || ::isUnitSpecial(unit)) && !silent)
      ::show_cant_buy_or_research_unit_msgbox(unit)
    return false
  }

  if (silent)
    return ::impl_buyUnit(unit)

  local unitName  = ::colorize("userlogColoredText", ::getUnitName(unit, true))
  local unitPrice = unitCost.getTextAccordingToBalance()
  local msgText = warningIfGold(::loc("shop/needMoneyQuestion_purchaseAircraft",
      {unitName = unitName, cost = unitPrice}),
    unitCost)

  local additionalCheckBox = null
  if (::facebook_is_logged_in() && ::has_feature("FacebookWallPost"))
  {
    additionalCheckBox = "cardImg{ background-image:t='#ui/gameuiskin#facebook_logo.svg';}" +
                     "CheckBox {" +
                      "id:t='chbox_post_facebook_purchase'" +
                      "text:t='#facebook/shareMsg'" +
                      "value:t='no'" +
                      "on_change_value:t='onFacebookPostPurchaseChange';" +
                      "btnName:t='X';" +
                      "ButtonImg{}" +
                      "CheckBoxImg{}" +
                     "}"
  }

  ::scene_msg_box("need_money", null, msgText,
                  [["yes", (@(unit) function() {::impl_buyUnit(unit) })(unit) ],
                   ["no", function() {} ]],
                  "yes", { cancel_fn = function() {}, data_below_text = additionalCheckBox})
  return true
}

::impl_buyUnit <- function impl_buyUnit(unit)
{
  if (!unit)
    return false
  if (unit.isBought())
    return false

  local canBuyNotResearchedUnit = unitStatus.canBuyNotResearched(unit)
  local unitCost = canBuyNotResearchedUnit ? unit.getOpenCost() : ::getUnitCost(unit)
  if (!::check_balance_msgBox(unitCost))
    return false

  local unitName = unit.name
  local taskId = null
  if (canBuyNotResearchedUnit)
  {
    local blk = ::DataBlock()
    blk["unit"] = unit.name
    blk["cost"] = unitCost.wp
    blk["costGold"] = unitCost.gold

    taskId = ::char_send_blk("cln_buy_not_researched_clans_unit", blk)
  }
  else
    taskId = ::shop_purchase_aircraft(unitName)

  local progressBox = ::scene_msg_box("char_connecting", null, ::loc("charServer/purchase"), null, null)
  ::add_bg_task_cb(taskId, function() {
    ::destroyMsgBox(progressBox)
    ::broadcastEvent("UnitBought", {unitName = unit.name})
  })
  return true
}

::can_spend_gold_on_unit_with_popup <- function can_spend_gold_on_unit_with_popup(unit)
{
  if (unit.unitType.canSpendGold())
    return true

  ::g_popups.add(::getUnitName(unit), ::loc("msgbox/unitTypeRestrictFromSpendGold"),
    null, null, null, "cant_spend_gold_on_unit")
  return false
}

::show_cant_buy_or_research_unit_msgbox <- function show_cant_buy_or_research_unit_msgbox(unit)
{
  local reason = ::getCantBuyUnitReason(unit)
  if (::u.isEmpty(reason))
    return true

  ::scene_msg_box("need_buy_prev", null, reason, [["ok", function () {}]], "ok")
  return false
}

::checkFeatureLock <- function checkFeatureLock(unit, lockAction)
{
  if (!::isUnitFeatureLocked(unit))
    return true
  local params = {
    purchaseAvailable = ::has_feature("OnlineShopPacks")
    featureLockAction = lockAction
    unit = unit
  }

  ::gui_start_modal_wnd(::gui_handlers.VehicleRequireFeatureWindow, params)
  return false
}

::checkForResearch <- function checkForResearch(unit)
{
  // Feature lock has higher priority than ::canResearchUnit.
  if (!::checkFeatureLock(unit, CheckFeatureLockAction.RESEARCH))
    return false

  local isSquadronVehicle = unit.isSquadronVehicle()
  if (::canResearchUnit(unit) && !isSquadronVehicle)
    return true

  if (!::isUnitSpecial(unit) && !::isUnitGift(unit)
    && !isSquadronVehicle && !::isUnitsEraUnlocked(unit))
  {
    ::showInfoMsgBox(getCantBuyUnitReason(unit), "need_unlock_rank")
    return false
  }

  if (isSquadronVehicle)
  {
    if (min(::clan_get_exp(), unit.reqExp - ::getUnitExp(unit)) <= 0
      && (!::has_feature("ClanVehicles") || !::is_in_clan()))
    {
      if (!::has_feature("ClanVehicles"))
      {
        ::show_not_available_msg_box()
        return false
      }

      local button = [["#mainmenu/btnFindSquadron", @() ::gui_modal_clans()]]
      local defButton = "#mainmenu/btnFindSquadron"
      local msg = [::loc("mainmenu/needJoinSquadronForResearch")]

      local canBuyNotResearchedUnit = unitStatus.canBuyNotResearched(unit)
      local priceText = unit.getOpenCost().getTextAccordingToBalance()
      if (canBuyNotResearchedUnit)
      {
        button.append(["purchase", @() ::buyUnit(unit, true)])
        defButton = "purchase"
        msg.append("\n")
        msg.append(::loc("mainmenu/canOpenVehicle", {price = priceText}))
      }
      button.append(["cancel", function() {}])

      ::scene_msg_box("cant_research_squadron_vehicle", null, ::g_string.implode(msg, "\n"),
        button, defButton)

      return false
    } else
      return true
  }

  return ::show_cant_buy_or_research_unit_msgbox(unit)
}


::getCantBuyUnitReason <- function getCantBuyUnitReason(unit, isShopTooltip = false)
{
  if (!unit)
    return ::loc("leaderboards/notAvailable")

  if (::isUnitBought(unit) || ::isUnitGift(unit))
    return ""

  local special = ::isUnitSpecial(unit)
  local isSquadronVehicle = unit.isSquadronVehicle()
  if (!special && !isSquadronVehicle && !::isUnitsEraUnlocked(unit))
  {
    local countryId = ::getUnitCountry(unit)
    local unitType = ::get_es_unit_type(unit)
    local rank = unit?.rank ?? -1

    for (local prevRank = rank - 1; prevRank > 0; prevRank--)
    {
      local unitsCount = 0
      foreach (u in ::all_units)
        if (::isUnitBought(u) && (u?.rank ?? -1) == prevRank && ::getUnitCountry(u) == countryId && ::get_es_unit_type(u) == unitType)
          unitsCount++
      local unitsNeed = ::getUnitsNeedBuyToOpenNextInEra(countryId, unitType, prevRank)
      local unitsLeft = max(0, unitsNeed - unitsCount)

      if (unitsLeft > 0)
      {
        return ::loc("shop/unlockTier/locked", { rank = ::get_roman_numeral(rank) })
          + "\n" + ::loc("shop/unlockTier/reqBoughtUnitsPrevRank", { prevRank = ::get_roman_numeral(prevRank), amount = unitsLeft })
      }
    }
    return ::loc("shop/unlockTier/locked", { rank = ::get_roman_numeral(rank) })
  }
  else if (!::isPrevUnitResearched(unit))
  {
    if (isShopTooltip)
      return ::loc("mainmenu/needResearchPreviousVehicle")
    if (!::isUnitResearched(unit))
      return ::loc("msgbox/need_unlock_prev_unit/research",
        {name = ::colorize("userlogColoredText", ::getUnitName(::getPrevUnit(unit), true))})
    return ::loc("msgbox/need_unlock_prev_unit/researchAndPurchase",
      {name = ::colorize("userlogColoredText", ::getUnitName(::getPrevUnit(unit), true))})
  }
  else if (!::isPrevUnitBought(unit))
  {
    if (isShopTooltip)
      return ::loc("mainmenu/needBuyPreviousVehicle")
    return ::loc("msgbox/need_unlock_prev_unit/purchase", {name = ::colorize("userlogColoredText", ::getUnitName(::getPrevUnit(unit), true))})
  }
  else if (unitStatus.isRequireUnlockForUnit(unit))
    return getUnitRequireUnlockText(unit)
  else if (!special && !isSquadronVehicle && !::canBuyUnit(unit) && ::canResearchUnit(unit))
    return ::loc(::isUnitInResearch(unit) ? "mainmenu/needResearch/researching" : "mainmenu/needResearch")

  if (!isShopTooltip)
  {
    local info = ::get_profile_info()
    local balance = ::getTblValue("balance", info, 0)
    local balanceG = ::getTblValue("gold", info, 0)

    if (special && (::wp_get_cost_gold(unit.name) > balanceG))
      return ::loc("mainmenu/notEnoughGold")
    else if (!special && (::wp_get_cost(unit.name) > balance))
      return ::loc("mainmenu/notEnoughWP")
   }

  return ""
}

::isUnitAvailableForGM <- function isUnitAvailableForGM(air, gm)
{
  if (!air.unitType.isAvailable())
    return false
  if (gm == ::GM_TEST_FLIGHT)
    return air.testFlight != ""
  if (gm == ::GM_DYNAMIC || gm == ::GM_BUILDER)
    return air.isAir()
  return true
}

::isTestFlightAvailable <- function isTestFlightAvailable(unit, skipUnitCheck = false)
{
  if (!::isUnitAvailableForGM(unit, ::GM_TEST_FLIGHT))
    return false

  if (unit.isUsable()
      || skipUnitCheck
      || ::canResearchUnit(unit)
      || ::isUnitGift(unit)
      || ::isUnitResearched(unit)
      || ::isUnitSpecial(unit)
      || ::g_decorator.approversUnitToPreviewLiveResource == unit
      || unit?.isSquadronVehicle?())
    return true

  return false
}

//return true when modificators already valid.
::check_unit_mods_update <- function check_unit_mods_update(air, callBack = null, forceUpdate = false)
{
  if (!air.isInited)
  {
    ::script_net_assert_once("not inited unit request", "try to call check_unit_mods_update for not inited unit")
    return false
  }

  if (air.modificatorsRequestTime > 0
    && air.modificatorsRequestTime + MODIFICATORS_REQUEST_TIMEOUT_MSEC > ::dagor.getCurTime())
  {
    if (forceUpdate)
      ::remove_calculate_modification_effect_jobs()
    else
      return false
  }
  else if (!forceUpdate && air.modificators)
    return true

  if (air.isShipOrBoat())
  {
    air.modificatorsRequestTime = ::dagor.getCurTime()
    calculate_ship_parameters_async(air.name, this, (@(air, callBack) function(effect, ...) {
      air.modificatorsRequestTime = -1
      if (effect)
      {
        air.modificators = {
          arcade = effect.arcade
          historical = effect.historical
          fullreal = effect.fullreal
        }
        if (!air.modificatorsBase)
          air.modificatorsBase = air.modificators
      }

      afterUpdateAirModificators(air, callBack)
    })(air, callBack))
    return false
  }

  if (air.isTank())
  {
    air.modificatorsRequestTime = ::dagor.getCurTime()
    calculate_tank_parameters_async(air.name, this, (@(air, callBack) function(effect, ...) {
      air.modificatorsRequestTime = -1
      if (effect)
      {
        air.modificators = {
          arcade = effect.arcade
          historical = effect.historical
          fullreal = effect.fullreal
        }
        if (!air.modificatorsBase) // TODO: Needs tank params _without_ user progress here.
          air.modificatorsBase = air.modificators
      }
      afterUpdateAirModificators(air, callBack)
    })(air, callBack))
    return false
  }

  air.modificatorsRequestTime = ::dagor.getCurTime()
  ::calculate_min_and_max_parameters(air.name, this, (@(air, callBack) function(effect, ...) {
    air.modificatorsRequestTime = -1
    if (effect)
    {
      air.modificators = {
        arcade = effect.arcade
        historical = effect.historical
        fullreal = effect.fullreal
      }
      air.minChars = effect.min
      air.maxChars = effect.max

      if (::isUnitSpecial(air) && !::isUnitUsable(air))
        air.modificators = effect.max
    }
    afterUpdateAirModificators(air, callBack)
  })(air, callBack))
  return false
}

// modName == ""  mean 'all mods'.
::updateAirAfterSwitchMod <- function updateAirAfterSwitchMod(air, modName = null)
{
  if (!air)
    return

  if (air.name == ::hangar_get_current_unit_name() && modName)
  {
    local modsList = modName == "" ? air.modifications : [ getModificationByName(air, modName) ]
    foreach (mod in modsList)
    {
      if (!::getTblValue("requiresModelReload", mod, false))
        continue
      ::hangar_force_reload_model()
      break
    }
  }

  if (!::isUnitGroup(air))
    ::check_unit_mods_update(air, null, true)
}

//return true when already counted
::check_secondary_weapon_mods_recount <- function check_secondary_weapon_mods_recount(unit, callback = null)
{
  switch(::get_es_unit_type(unit))
  {
    case ::ES_UNIT_TYPE_AIRCRAFT:
    case ::ES_UNIT_TYPE_HELICOPTER:

      local weaponName = getLastWeapon(unit.name)
      local secondaryMods = unit.secondaryWeaponMods
      if (secondaryMods && secondaryMods.weaponName == weaponName)
      {
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

      ::calculate_mod_or_weapon_effect(unit.name, weaponName, false, this, function(effect, ...) {
        secondaryMods = unit.secondaryWeaponMods
        if (!secondaryMods || weaponName != secondaryMods.weaponName)
          return

        secondaryMods.effect <- effect || {}
        ::broadcastEvent("SecondWeaponModsUpdated", { unit = unit })
        if(secondaryMods.callback != null)
        {
          secondaryMods.callback()
          secondaryMods.callback = null
        }
      })
      return false

    case ::ES_UNIT_TYPE_BOAT:
    case ::ES_UNIT_TYPE_SHIP:

      local torpedoMod = "torpedoes_movement_mode"
      local mod = getModificationByName(unit, torpedoMod)
      if (!mod || mod?.effects)
        return true
      ::calculate_mod_or_weapon_effect(unit.name, torpedoMod, true, this, function(effect, ...) {
        mod.effects <- effect
        if (callback)
          callback()
        ::broadcastEvent("SecondWeaponModsUpdated", { unit = unit })
      })
      return false

    default:
      return true
  }
}

::getUnitExp <- function getUnitExp(unit)
{
  return ::shop_get_unit_exp(unit.name)
}

::getUnitReqExp <- function getUnitReqExp(unit)
{
  if(!("reqExp" in unit))
    return 0
  return unit.reqExp
}

::isUnitMaxExp <- function isUnitMaxExp(unit) //temporary while not exist correct status between in_research and canBuy
{
  return ::isUnitSpecial(unit) || (::getUnitReqExp(unit) <= ::getUnitExp(unit))
}

::getNextTierModsCount <- function getNextTierModsCount(unit, tier)
{
  if (tier < 1 || tier > unit.needBuyToOpenNextInTier.len() || !("modifications" in unit))
    return 0

  local req = unit.needBuyToOpenNextInTier[tier-1]
  foreach(mod in unit.modifications)
    if (("tier" in mod) && mod.tier == tier
      && isModificationInTree(unit, mod)
      && isModResearched(unit, mod)
    )
      req--
  return max(req, 0)
}

::generateUnitShopInfo <- function generateUnitShopInfo()
{
  local blk = ::get_shop_blk()
  local totalCountries = blk.blockCount()

  for(local c = 0; c < totalCountries; c++)  //country
  {
    local cblk = blk.getBlock(c)
    local totalPages = cblk.blockCount()

    for(local p = 0; p < totalPages; p++)
    {
      local pblk = cblk.getBlock(p)
      local totalRanges = pblk.blockCount()

      for(local r = 0; r < totalRanges; r++)
      {
        local rblk = pblk.getBlock(r)
        local totalAirs = rblk.blockCount()
        local prevAir = null

        for(local a = 0; a < totalAirs; a++)
        {
          local airBlk = rblk.getBlock(a)
          local air = ::getAircraftByName(airBlk.getBlockName())

          if (airBlk?.reqAir != null)
            prevAir = airBlk.reqAir

          if (air)
          {
            air.applyShopBlk(airBlk, prevAir)
            prevAir = air.name
          }
          else //aircraft group
          {
            local groupTotal = airBlk.blockCount()
            local firstIGroup = null
            local groupName = airBlk.getBlockName()
            for(local ga = 0; ga < groupTotal; ga++)
            {
              local gAirBlk = airBlk.getBlock(ga)
              air = ::getAircraftByName(gAirBlk.getBlockName())
              if (!air)
                continue
              air.applyShopBlk(gAirBlk, prevAir, groupName)
              prevAir = air.name
              if (!firstIGroup)
                firstIGroup = air
            }

            if (firstIGroup
                && !::isUnitSpecial(firstIGroup)
                && !::isUnitGift(firstIGroup))
              prevAir = firstIGroup.name
            else
              prevAir = null
          }
        }
      }
    }
  }
}

::getPrevUnit <- function getPrevUnit(unit)
{
  return "reqAir" in unit ? ::getAircraftByName(unit.reqAir) : null
}

::isUnitLocked <- function isUnitLocked(unit)
{
  local status = ::shop_unit_research_status(unit.name)
  return 0 != (status & ::ES_ITEM_STATUS_LOCKED)
}

::isUnitResearched <- function isUnitResearched(unit)
{
  if (::isUnitBought(unit) || ::canBuyUnit(unit))
    return true

  local status = ::shop_unit_research_status(unit.name)
  return (0 != (status & ::ES_ITEM_STATUS_RESEARCHED))
}

::isPrevUnitResearched <- function isPrevUnitResearched(unit)
{
  local prevUnit = ::getPrevUnit(unit)
  if (!prevUnit || ::isUnitResearched(prevUnit))
    return true
  return false
}

::isPrevUnitBought <- function isPrevUnitBought(unit)
{
  local prevUnit = ::getPrevUnit(unit)
  if (!prevUnit || ::isUnitBought(prevUnit))
    return true
  return false
}

::getMinBestLevelingRank <- function getMinBestLevelingRank(unit)
{
  if (!unit)
    return -1

  local unitRank = unit?.rank ?? -1
  if (::isUnitSpecial(unit) || unitRank == 1)
    return 1
  local result = unitRank - ::getHighestRankDiffNoPenalty(true)
  return result > 0 ? result : 1
}

::getMaxBestLevelingRank <- function getMaxBestLevelingRank(unit)
{
  if (!unit)
    return -1

  local unitRank = unit?.rank ?? -1
  if (unitRank == ::max_country_rank)
    return ::max_country_rank
  local result = unitRank + ::getHighestRankDiffNoPenalty()
  return result <= ::max_country_rank ? result : ::max_country_rank
}

::getHighestRankDiffNoPenalty <- function getHighestRankDiffNoPenalty(inverse = false)
{
  local ranksBlk = ::get_ranks_blk()
  local paramPrefix = inverse
                      ? "expMulWithTierDiffMinus"
                      : "expMulWithTierDiff"

  for (local rankDif = 0; rankDif < ::max_country_rank; rankDif++)
    if (ranksBlk[paramPrefix + rankDif] < 0.8)
      return rankDif - 1
  return 0
}

::get_battle_type_by_unit <- function get_battle_type_by_unit(unit)
{
  return (::get_es_unit_type(unit) == ::ES_UNIT_TYPE_TANK)? BATTLE_TYPES.TANK : BATTLE_TYPES.AIR
}

::getCharacteristicActualValue <- function getCharacteristicActualValue(air, characteristicName, prepareTextFunc, modeName, showLocalState = true)
{
  local modificators = showLocalState ? "modificators" : "modificatorsBase"

  local showReferenceText = false
  if (!(characteristicName[0] in air.shop))
    air.shop[characteristicName[0]] <- 0;

  local value = air.shop[characteristicName[0]] + (air[modificators] ? air[modificators][modeName][characteristicName[1]] : 0)
  local vMin = air.minChars ? air.shop[characteristicName[0]] + air.minChars[modeName][characteristicName[1]] : value
  local vMax = air.maxChars ? air.shop[characteristicName[0]] + air.maxChars[modeName][characteristicName[1]] : value
  local text = prepareTextFunc(value)
  if(air[modificators] && air[modificators][modeName][characteristicName[1]] == 0)
  {
    text = "<color=@goodTextColor>" + text + "</color>*"
    showReferenceText = true
  }

  local weaponModValue = air?.secondaryWeaponMods.effect[modeName][characteristicName[1]] ?? 0
  local weaponModText = ""
  if(weaponModValue != 0)
    weaponModText = "<color=@badTextColor>" + (weaponModValue > 0 ? " + " : " - ") + prepareTextFunc(fabs(weaponModValue)) + "</color>"
  return [text, weaponModText, vMin, vMax, value, air.shop[characteristicName[0]], showReferenceText]
}

::setReferenceMarker <- function setReferenceMarker(obj, vMin, vMax, refer, modeName)
{
  if(!::checkObj(obj))
    return

  local refMarkerObj = obj.findObject("aircraft-reference-marker")
  if (::checkObj(refMarkerObj))
  {
    if(vMin == vMax || (modeName == "arcade"))
    {
      refMarkerObj.show(false)
      return
    }

    refMarkerObj.show(true)
    local left = ::min((refer - vMin) / (vMax - vMin), 1)
    refMarkerObj.left = ::format("%.3fpw - 0.5w)", left)
  }
}

::fillAirCharProgress <- function fillAirCharProgress(progressObj, vMin, vMax, cur)
{
  if(!::checkObj(progressObj))
    return
  if(vMin == vMax)
    return progressObj.show(false)
  else
    progressObj.show(true)
  local value = ((cur - vMin) / (vMax - vMin)) * 1000.0
  progressObj.setValue(value)
}

::fillAirInfoTimers <- function fillAirInfoTimers(holderObj, air, needShopInfo)
{
  SecondsUpdater(holderObj, function(obj, params) {
    local isActive = false

    // Unit repair cost
    local hp = shop_get_aircraft_hp(air.name)
    local isBroken = hp >= 0 && hp < 1
    isActive = isActive || isBroken // warning disable: -const-in-bool-expr
    local hpTrObj = obj.findObject("aircraft-condition-tr")
    if (hpTrObj)
      if (isBroken)
      {
        //local hpText = format("%d%%", ::floor(hp*100))
        //hpText += (hp < 1)? " (" + time.hoursToString(shop_time_until_repair(air.name)) + ")" : ""
        local hpText = ::loc("shop/damaged") + " (" + time.hoursToString(shop_time_until_repair(air.name), false, true) + ")"
        hpTrObj.show(true)
        hpTrObj.findObject("aircraft-condition").setValue(hpText)
      } else
        hpTrObj.show(false)
    if (needShopInfo && isBroken && obj.findObject("aircraft-repair_cost-tr"))
    {
      local cost = ::wp_get_repair_cost(air.name)
      obj.findObject("aircraft-repair_cost-tr").show(cost > 0)
      obj.findObject("aircraft-repair_cost").setValue(::getPriceAccordingToPlayersCurrency(cost, 0))
    }

    // Unit rent time
    local isRented = air.isRented()
    isActive = isActive || isRented
    local rentObj = obj.findObject("unit_rent_time")
    if (::checkObj(rentObj))
    {
      local sec = air.getRentTimeleft()
      local show = sec > 0
      local value = ""
      if (show)
      {
        local timeStr = time.hoursToString(time.secondsToHours(sec), false, true, true)
        value = ::colorize("goodTextColor", ::loc("mainmenu/unitRentTimeleft") + ::loc("ui/colon") + timeStr)
      }
      if (rentObj.isVisible() != show)
        rentObj.show(show)
      if (show && rentObj.getValue() != value)
        rentObj.setValue(value)
    }


    // unit special offer
    local haveDiscount = ::g_discount.getUnitDiscountByName(air.name)
    local specialOfferItem = haveDiscount > 0 ? ::ItemsManager.getBestSpecialOfferItemByUnit(air) : null
    isActive = isActive || specialOfferItem != null
    local discountObj = obj.findObject("special_offer_time")
    if (::check_obj(rentObj)) {
      local expireTimeText = specialOfferItem?.getExpireTimeTextShort() ?? ""
      local show = expireTimeText != ""
      discountObj.show(show)
      if (show)
        discountObj.setValue(::colorize("goodTextColor", ::loc("specialOffer/TillTime", { time = expireTimeText })))
    }

    local unlockTime = ::isInMenu() ? getCrewUnlockTimeByUnit(air) : 0
    local needShowUnlockTime = unlockTime > 0
    local lockObj = ::showBtn("aircraft-lockedCrew", needShowUnlockTime, obj)
    if (needShowUnlockTime && lockObj)
      lockObj.findObject("time").setValue(time.secondsToString(unlockTime))
    isActive = isActive || needShowUnlockTime

    return !isActive
  })
}

::get_show_aircraft_name <- function get_show_aircraft_name()
{
  return ::show_aircraft? ::show_aircraft.name : ::hangar_get_current_unit_name()
}

::get_show_aircraft <- function get_show_aircraft()
{
  return ::show_aircraft? ::show_aircraft : ::getAircraftByName(::hangar_get_current_unit_name())
}

::set_show_aircraft <- function set_show_aircraft(unit)
{
  if (!unit)
    return
  ::show_aircraft = unit
  ::hangar_model_load_manager.loadModel(unit.name)
}

::showAirInfo <- function showAirInfo(air, show, holderObj = null, handler = null, params = null)
{
  handler = handler || ::handlersManager.getActiveBaseHandler()

  if (!::checkObj(holderObj))
  {
    if(holderObj != null)
      return

    if (handler)
      holderObj = handler.scene.findObject("slot_info")
    if (!::checkObj(holderObj))
      return
  }

  holderObj.show(show)
  if (!show || !air)
    return

  local tableObj = holderObj.findObject("air_info_panel_table")
  if (::check_obj(tableObj))
  {
    local isShowProgress = ::isInArray(air.esUnitType, [ ::ES_UNIT_TYPE_AIRCRAFT, ::ES_UNIT_TYPE_HELICOPTER ])
    tableObj["showStatsProgress"] = isShowProgress ? "yes" : "no"
  }

  local bitStatus = unitStatus.getBitStatus(air, params)
  holderObj.shopStat = getUnitItemStatusText(bitStatus, false)
  holderObj.unitRarity = getUnitRarity(air)

  local isInFlight = ::is_in_flight()

  local showLocalState   = ::getTblValue("showLocalState", params, true)
  local needCrewModificators = params?.needCrewModificators ?? false

  local getEdiffFunc = ::getTblValue("getCurrentEdiff", handler)
  local ediff = getEdiffFunc ? getEdiffFunc.call(handler) : ::get_current_ediff()
  local difficulty = ::get_difficulty_by_ediff(ediff)
  local diffCode = difficulty.diffCode

  local unitType = ::get_es_unit_type(air)
  local crew = params?.crewId != null ? ::get_crew_by_id(params.crewId) : ::getCrewByAir(air)

  local isOwn = ::isUnitBought(air)
  local special = ::isUnitSpecial(air)
  local cost = ::wp_get_cost(air.name)
  local costGold = ::wp_get_cost_gold(air.name)
  local aircraftPrice = special ? costGold : cost
  local gift = ::isUnitGift(air)
  local showPrice = showLocalState && !isOwn && aircraftPrice > 0 && !gift
  local isResearched = ::isUnitResearched(air)
  local canResearch = ::canResearchUnit(air)
  local rBlk = ::get_ranks_blk()
  local wBlk = ::get_warpoints_blk()
  local needShopInfo = ::getTblValue("needShopInfo", params, false)
  local needCrewInfo = ::getTblValue("needCrewInfo", params, false)

  local isRented = air.isRented()
  local rentTimeHours = ::getTblValue("rentTimeHours", params, -1)
  local isReceivedPrizes = params?.isReceivedPrizes ??  false
  local showAsRent = (showLocalState && isRented) || rentTimeHours > 0
  local isSquadronVehicle = air.isSquadronVehicle()
  local isInClan = ::is_in_clan()
  local expCur = ::getUnitExp(air)

  local isSecondaryModsValid = ::check_unit_mods_update(air)
    && ::check_secondary_weapon_mods_recount(air)

  local obj = holderObj.findObject("aircraft-name")
  if (::checkObj(obj))
    obj.setValue(::getUnitName(air.name, false))

  obj = holderObj.findObject("aircraft-type")
  if (::checkObj(obj))
  {
    local fonticon = getUnitRoleIcon(air)
    local typeText = getFullUnitRoleText(air)
    obj.show(typeText != "")
    obj.setValue(::colorize(::getUnitClassColor(air), fonticon + " " + typeText))
  }

  obj = holderObj.findObject("player_country_exp")
  if (::checkObj(obj))
  {
    obj.show(showLocalState && canResearch)
    if (showLocalState && canResearch)
    {
      if (isSquadronVehicle)
        obj.isForSquadVehicle = "yes"
      local expTotal = air.reqExp
      local expInvest = isSquadronVehicle
        ? ::min(::clan_get_exp(), expTotal - expCur)
        : ::getTblValue("researchExpInvest", params, 0)
      local isResearching = ::isUnitInResearch(air) && (!isSquadronVehicle || isInClan || expInvest > 0)

      fillProgressBar(obj,
        isSquadronVehicle && isResearching ? expCur : expCur - expInvest,
        isSquadronVehicle && isResearching ? expCur + expInvest : expCur,
        expTotal, !isResearching)

      local labelObj = obj.findObject("exp")
      if (::checkObj(labelObj))
      {
        local statusText = isResearching ? ::loc("shop/in_research") + ::loc("ui/colon") : ""
        local expCurText = isSquadronVehicle
          ? ::Cost().setSap(expCur).toStringWithParams({isSapAlwaysShown = true})
          : ::Cost().setRp(expCur).toStringWithParams({isRpAlwaysShown = true})
        local expText = ::format("%s%s%s%s",
          statusText,
          expCurText,
          ::loc("ui/slash"),
          isSquadronVehicle ? ::Cost().setSap(expTotal).tostring() : ::Cost().setRp(expTotal).tostring())
        expText = ::colorize(isResearching ? "cardProgressTextColor" : "commonTextColor", expText)
        if (isResearching && expInvest > 0)
          expText += ::colorize(isSquadronVehicle
            ? "cardProgressChangeSquadronColor"
            : "cardProgressTextBonusColor", ::loc("ui/parentheses/space",
            { text = "+ " + (isSquadronVehicle
              ? ::Cost().setSap(expInvest).tostring()
              : ::Cost().setRp(expInvest).tostring()) }))
        labelObj.setValue(expText)
      }
    }
  }

  obj = holderObj.findObject("aircraft-countryImg")
  if (::checkObj(obj))
  {
    obj["background-image"] = ::get_unit_country_icon(air, true)
    obj["tooltip"] = "".concat(::loc("shop/unitCountry/operator"), ::loc("ui/colon"), ::loc(air.getOperatorCountry()),
      "\n", ::loc("shop/unitCountry/research"), ::loc("ui/colon"), ::loc(air.shopCountry))
  }

  if (::has_feature("UnitTooltipImage"))
  {
    obj = holderObj.findObject("aircraft-image")
    if (::checkObj(obj))
      obj["background-image"] = getUnitTooltipImage(air)
  }

  local ageObj = holderObj.findObject("aircraft-age")
  if (::checkObj(ageObj))
  {
    local nameObj = ageObj.findObject("age_number")
    if (::checkObj(nameObj))
      nameObj.setValue(::loc("shop/age") + ::loc("ui/colon"))
    local yearsObj = ageObj.findObject("age_years")
    if (::checkObj(yearsObj))
      yearsObj.setValue(::get_roman_numeral(air.rank))
  }

  //count unit ratings
  local showBr = !air.hideBrForVehicle
  local battleRating = air.getBattleRating(ediff)
  local brObj = ::showBtn("aircraft-battle_rating", showBr, holderObj)
  if (showBr) {
    brObj.findObject("aircraft-battle_rating-header").setValue($"{::loc("shop/battle_rating")}{::loc("ui/colon")}")
    brObj.findObject("aircraft-battle_rating-value").setValue(format("%.1f", air.getBattleRating(ediff)))
  }

  local meetObj = holderObj.findObject("aircraft-chance_to_met_tr")
  if (::checkObj(meetObj))
  {
    local erCompare = ::getTblValue("economicRankCompare", params)
    if (erCompare != null)
    {
      if (typeof(erCompare) == "table")
        erCompare = ::getTblValue(air.shopCountry, erCompare, 0.0)
      local text = getChanceToMeetText(battleRating, ::calc_battle_rating_from_rank(erCompare))
      meetObj.findObject("aircraft-chance_to_met").setValue(text)
    }
    meetObj.show(erCompare != null)
  }

  if (showLocalState && (canResearch || (!isOwn && !special && !gift)))
  {
    local prevUnitObj = holderObj.findObject("aircraft-prevUnit_bonus_tr")
    local prevUnit = ::getPrevUnit(air)
    if (::checkObj(prevUnitObj) && prevUnit)
    {
      prevUnitObj.show(true)
      local tdNameObj = prevUnitObj.findObject("aircraft-prevUnit")
      if (::checkObj(tdNameObj))
        tdNameObj.setValue(::format(::loc("shop/prevUnitEfficiencyResearch"), ::getUnitName(prevUnit, true)))
      local tdValueObj = prevUnitObj.findObject("aircraft-prevUnit_bonus")
      if (::checkObj(tdValueObj))
      {
        local param_name = "prevAirExpMulMode"
        local curVal = rBlk?[param_name + diffCode.tostring()] ?? 1

        if (curVal != 1)
          tdValueObj.setValue(::format("<color=@userlogColoredText>%s%%</color>", (curVal*100).tostring()))
        else
          prevUnitObj.show(false)
      }
    }
  }

  local rpObj = holderObj.findObject("aircraft-require_rp_tr")
  if (::checkObj(rpObj))
  {
    local showRpReq = showLocalState && !isOwn && !special && !gift && !isResearched && !canResearch
    rpObj.show(showRpReq)
    if (showRpReq)
      rpObj.findObject("aircraft-require_rp").setValue(::Cost().setRp(air.reqExp).tostring())
  }

  if(showPrice)
  {
    local priceObj = holderObj.findObject("aircraft-price-tr")
    if (priceObj)
    {
      priceObj.show(true)
      holderObj.findObject("aircraft-price").setValue(::getPriceAccordingToPlayersCurrency(cost, costGold))
    }
  }

  local modCharacteristics = {
    [::ES_UNIT_TYPE_AIRCRAFT] = [
      {id = "maxSpeed", id2 = "speed", prepareTextFunc = @(value) countMeasure(0, value)},
      {id = "turnTime", id2 = "virage", prepareTextFunc = function(value){return format("%.1f %s", value, ::loc("measureUnits/seconds"))}},
      {id = "climbSpeed", id2 = "climb", prepareTextFunc = @(value) countMeasure(3, value)}
    ],
    [::ES_UNIT_TYPE_TANK] = [
      {id = "mass", id2 = "mass", prepareTextFunc = function(value){return format("%.1f %s", (value / 1000.0), ::loc("measureUnits/ton"))}},
      {id = "maxSpeed", id2 = "maxSpeed", prepareTextFunc = @(value) countMeasure(0, value)},
      {id = "turnTurretTime", id2 = "turnTurretSpeed", prepareTextFunc = function(value){return format("%.1f%s", value.tofloat(), ::loc("measureUnits/deg_per_sec"))}}
    ],
    [::ES_UNIT_TYPE_BOAT] = [
      //TODO ship modificators
      {id = "maxSpeed", id2 = "maxSpeed", prepareTextFunc = @(value) countMeasure(0, value)}
    ],
    [::ES_UNIT_TYPE_SHIP] = [
      //TODO ship modificators
      {id = "maxSpeed", id2 = "maxSpeed", prepareTextFunc = @(value) countMeasure(0, value)}
    ],
    [::ES_UNIT_TYPE_HELICOPTER] = [
      {id = "maxSpeed", id2 = "speed", prepareTextFunc = @(value) countMeasure(0, value)}
      {id = "climbSpeed", id2 = "climb", prepareTextFunc = @(value) countMeasure(3, value)}
    ]
  }

  local showReferenceText = false
  foreach(item in ::getTblValue(unitType, modCharacteristics, {}))
  {
    local characteristicArr = ::getCharacteristicActualValue(air, [item.id, item.id2],
      item.prepareTextFunc, difficulty.crewSkillName, showLocalState || needCrewModificators)
    holderObj.findObject("aircraft-" + item.id).setValue(characteristicArr[0])

    if (!showLocalState && !needCrewModificators)
      continue

    local wmodObj = holderObj.findObject("aircraft-weaponmod-" + item.id)
    if (wmodObj)
      wmodObj.setValue(characteristicArr[1])

    local progressObj = holderObj.findObject("aircraft-progress-" + item.id)
    setReferenceMarker(progressObj, characteristicArr[2], characteristicArr[3], characteristicArr[5], difficulty.crewSkillName)
    fillAirCharProgress(progressObj, characteristicArr[2], characteristicArr[3], characteristicArr[4])
    showReferenceText = showReferenceText || characteristicArr[6]

    local waitObj = holderObj.findObject("aircraft-" + item.id + "-wait")
    if (waitObj)
      waitObj.show(!isSecondaryModsValid)
  }
  local refTextObj = holderObj.findObject("references_text")
  if (::checkObj(refTextObj)) refTextObj.show(showReferenceText)

  holderObj.findObject("aircraft-speedAlt").setValue((air.shop?.maxSpeedAlt ?? 0) > 0 ?
    countMeasure(1, air.shop.maxSpeedAlt) : ::loc("shop/max_speed_alt_sea"))
//    holderObj.findObject("aircraft-climbTime").setValue(format("%02d:%02d", air.shop.climbTime.tointeger() / 60, air.shop.climbTime.tointeger() % 60))
//    holderObj.findObject("aircraft-climbAlt").setValue(countMeasure(1, air.shop.climbAlt))
  holderObj.findObject("aircraft-altitude").setValue(countMeasure(1, air.shop.maxAltitude))
  holderObj.findObject("aircraft-airfieldLen").setValue(countMeasure(1, air.shop.airfieldLen))
  holderObj.findObject("aircraft-wingLoading").setValue(countMeasure(5, air.shop.wingLoading))
//  holderObj.findObject("aircraft-range").setValue(countMeasure(2, air.shop.range * 1000.0))

  local totalCrewObj = holderObj.findObject("total-crew")
  if (::check_obj(totalCrewObj))
    totalCrewObj.setValue(air.getCrewTotalCount().tostring())

  local cardAirplaneWingLoadingParameter = ::has_feature("CardAirplaneWingLoadingParameter")
  local cardAirplanePowerParameter = ::has_feature("CardAirplanePowerParameter")
  local cardHelicopterClimbParameter = ::has_feature("CardHelicopterClimbParameter")

  local showCharacteristics = {
    ["aircraft-turnTurretTime-tr"]        = [ ::ES_UNIT_TYPE_TANK ],
    ["aircraft-angleVerticalGuidance-tr"] = [ ::ES_UNIT_TYPE_TANK ],
    ["aircraft-shotFreq-tr"]              = [ ::ES_UNIT_TYPE_TANK ],
    ["aircraft-reloadTime-tr"]            = [ ::ES_UNIT_TYPE_TANK ],
    ["aircraft-weaponPresets-tr"]         = [ ::ES_UNIT_TYPE_AIRCRAFT, ::ES_UNIT_TYPE_HELICOPTER ],
    ["aircraft-massPerSec-tr"]            = [ ::ES_UNIT_TYPE_AIRCRAFT, ::ES_UNIT_TYPE_HELICOPTER ],
    ["aircraft-armorThicknessHull-tr"]    = [ ::ES_UNIT_TYPE_TANK ],
    ["aircraft-armorThicknessTurret-tr"]  = [ ::ES_UNIT_TYPE_TANK ],
    ["aircraft-armorPiercing-tr"]         = [ ::ES_UNIT_TYPE_TANK ],
    ["aircraft-armorPiercingDist-tr"]     = [ ::ES_UNIT_TYPE_TANK ],
    ["aircraft-mass-tr"]                  = [ ::ES_UNIT_TYPE_TANK ],
    ["aircraft-horsePowers-tr"]           = [ ::ES_UNIT_TYPE_TANK ],
    ["aircraft-maxSpeed-tr"]              = [ ::ES_UNIT_TYPE_AIRCRAFT, ::ES_UNIT_TYPE_TANK,
                                              ::ES_UNIT_TYPE_BOAT, ::ES_UNIT_TYPE_SHIP, ::ES_UNIT_TYPE_HELICOPTER ],
    ["aircraft-maxDepth-tr"]              = [ ::ES_UNIT_TYPE_BOAT, ::ES_UNIT_TYPE_SHIP ],
    ["aircraft-speedAlt-tr"]              = [ ::ES_UNIT_TYPE_AIRCRAFT, ::ES_UNIT_TYPE_HELICOPTER ],
    ["aircraft-altitude-tr"]              = [ ::ES_UNIT_TYPE_AIRCRAFT, ::ES_UNIT_TYPE_HELICOPTER ],
    ["aircraft-turnTime-tr"]              = [ ::ES_UNIT_TYPE_AIRCRAFT ],
    ["aircraft-climbSpeed-tr"]            = cardHelicopterClimbParameter ? [ ::ES_UNIT_TYPE_AIRCRAFT, ::ES_UNIT_TYPE_HELICOPTER ] : [ ::ES_UNIT_TYPE_AIRCRAFT ],
    ["aircraft-airfieldLen-tr"]           = [ ::ES_UNIT_TYPE_AIRCRAFT ],
    ["aircraft-wingLoading-tr"]           = cardAirplaneWingLoadingParameter ? [ ::ES_UNIT_TYPE_AIRCRAFT ] : [],
    ["aircraft-visibilityFactor-tr"]      = [ ::ES_UNIT_TYPE_TANK ]
  }

  foreach (rowId, showForTypes in showCharacteristics)
  {
    local rowObj = holderObj.findObject(rowId)
    if (rowObj)
      rowObj.show(::isInArray(unitType, showForTypes))
  }

  local powerToWeightRatioObject = holderObj.findObject("aircraft-powerToWeightRatio-tr")
  if (cardAirplanePowerParameter
    && ::isInArray(unitType, [::ES_UNIT_TYPE_AIRCRAFT, ::ES_UNIT_TYPE_HELICOPTER])
    && "powerToWeightRatio" in air.shop)
  {
    holderObj.findObject("aircraft-powerToWeightRatio").setValue(countMeasure(6, air.shop.powerToWeightRatio))
    powerToWeightRatioObject.show(true)
  }
  else
    powerToWeightRatioObject.show(false)

  local thrustToWeightRatioObject = holderObj.findObject("aircraft-thrustToWeightRatio-tr")
  if (cardAirplanePowerParameter && unitType == ::ES_UNIT_TYPE_AIRCRAFT && air.shop?.thrustToWeightRatio)
  {
    holderObj.findObject("aircraft-thrustToWeightRatio").setValue(format("%.2f", air.shop.thrustToWeightRatio))
    thrustToWeightRatioObject.show(true)
  }
  else
    thrustToWeightRatioObject.show(false)

  local modificators = (showLocalState || needCrewModificators) ? "modificators" : "modificatorsBase"
  if (air.isTank() && air[modificators])
  {
    local currentParams = air[modificators][difficulty.crewSkillName]
    local horsePowers = currentParams.horsePowers;
    local horsePowersRPM = currentParams.maxHorsePowersRPM;
    holderObj.findObject("aircraft-horsePowers").setValue(
      ::format("%s %s %d %s", ::g_measure_type.HORSEPOWERS.getMeasureUnitsText(horsePowers),
        ::loc("shop/unitValidCondition"), horsePowersRPM.tointeger(), ::loc("measureUnits/rpm")))
    local thickness = currentParams.armorThicknessHull;
    holderObj.findObject("aircraft-armorThicknessHull").setValue(format("%d / %d / %d %s", thickness[0].tointeger(), thickness[1].tointeger(), thickness[2].tointeger(), ::loc("measureUnits/mm")))
    thickness = currentParams.armorThicknessTurret;
    holderObj.findObject("aircraft-armorThicknessTurret").setValue(format("%d / %d / %d %s", thickness[0].tointeger(), thickness[1].tointeger(), thickness[2].tointeger(), ::loc("measureUnits/mm")))
    local angles = currentParams.angleVerticalGuidance;
    holderObj.findObject("aircraft-angleVerticalGuidance").setValue(format("%d / %d%s", angles[0].tointeger(), angles[1].tointeger(), ::loc("measureUnits/deg")))
    local armorPiercing = currentParams.armorPiercing;
    if (armorPiercing.len() > 0)
    {
      local textParts = []
      local countOutputValue = min(armorPiercing.len(), 3)
      for(local i = 0; i < countOutputValue; i++)
        textParts.append(stdMath.round(armorPiercing[i]).tointeger())
      holderObj.findObject("aircraft-armorPiercing").setValue(format("%s %s", ::g_string.implode(textParts, " / "), ::loc("measureUnits/mm")))
      local armorPiercingDist = currentParams.armorPiercingDist;
      textParts.clear()
      countOutputValue = min(armorPiercingDist.len(), 3)
      for(local i = 0; i < countOutputValue; i++)
        textParts.append(armorPiercingDist[i].tointeger())
      holderObj.findObject("aircraft-armorPiercingDist").setValue(format("%s %s", ::g_string.implode(textParts, " / "), ::loc("measureUnits/meters_alt")))
    }
    else
    {
      holderObj.findObject("aircraft-armorPiercing-tr").show(false)
      holderObj.findObject("aircraft-armorPiercingDist-tr").show(false)
    }

    local shotFreq = ("shotFreq" in currentParams && currentParams.shotFreq > 0) ? currentParams.shotFreq : null;
    local reloadTime = ("reloadTime" in currentParams && currentParams.reloadTime > 0) ? currentParams.reloadTime : null;
    if ((currentParams?.reloadTimeByDiff?[diffCode] ?? 0) > 0)
      reloadTime = currentParams.reloadTimeByDiff[diffCode]
    local visibilityFactor = ("visibilityFactor" in currentParams && currentParams.visibilityFactor > 0) ? currentParams.visibilityFactor : null;

    holderObj.findObject("aircraft-shotFreq-tr").show(shotFreq);
    holderObj.findObject("aircraft-reloadTime-tr").show(reloadTime);
    holderObj.findObject("aircraft-visibilityFactor-tr").show(visibilityFactor);
    if (shotFreq)
    {
      local val = stdMath.roundToDigits(shotFreq * 60, 3).tostring()
      holderObj.findObject("aircraft-shotFreq").setValue(format("%s %s", val, ::loc("measureUnits/shotPerMinute")))
    }
    if (reloadTime)
      holderObj.findObject("aircraft-reloadTime").setValue(format("%.1f %s", reloadTime, ::loc("measureUnits/seconds")))
    if (visibilityFactor)
    {
      holderObj.findObject("aircraft-visibilityFactor-title").setValue(::loc("shop/visibilityFactor") + ::loc("ui/colon"))
      holderObj.findObject("aircraft-visibilityFactor-value").setValue(format("%d %%", visibilityFactor))
    }
  }

  if (unitType == ::ES_UNIT_TYPE_SHIP || unitType == ::ES_UNIT_TYPE_BOAT)
  {
    local unitTags = ::getTblValue(air.name, ::get_unittags_blk(), {})

    // ship-displacement
    local displacementKilos = unitTags?.Shop?.displacement
    holderObj.findObject("ship-displacement-tr").show(displacementKilos != null)
    if(displacementKilos!= null)
    {
      local displacementString = ::g_measure_type.SHIP_DISPLACEMENT_TON.getMeasureUnitsText(displacementKilos/1000, true)
      holderObj.findObject("ship-displacement-title").setValue(::loc("info/ship/displacement") + ::loc("ui/colon"))
      holderObj.findObject("ship-displacement-value").setValue(displacementString)
    }

    // submarine-depth
    local depthValue = unitTags?.Shop?.maxDepth ?? 0
    holderObj.findObject("aircraft-maxDepth-tr").show(depthValue > 0)
    if(depthValue > 0)
      holderObj.findObject("aircraft-maxDepth").setValue(depthValue + ::loc("measureUnits/meters_alt"))

    // ship-citadelArmor
    local armorThicknessCitadel = unitTags?.Shop.armorThicknessCitadel
    holderObj.findObject("ship-citadelArmor-tr").show(armorThicknessCitadel != null)
    if(armorThicknessCitadel != null)
    {
      local val = [
        stdMath.round(armorThicknessCitadel.x).tointeger(),
        stdMath.round(armorThicknessCitadel.y).tointeger(),
        stdMath.round(armorThicknessCitadel.z).tointeger(),
      ]
      holderObj.findObject("ship-citadelArmor-title").setValue(::loc("info/ship/citadelArmor") + ::loc("ui/colon"))
      holderObj.findObject("ship-citadelArmor-value").setValue(
        format("%d / %d / %d %s", val[0], val[1],val[2], ::loc("measureUnits/mm")))
    }

    // ship-mainFireTower
    local armorThicknessMainFireTower = unitTags?.Shop.armorThicknessTurretMainCaliber
    holderObj.findObject("ship-mainFireTower-tr").show(armorThicknessMainFireTower != null)
    if(armorThicknessMainFireTower != null)
    {
      local val = [
        stdMath.round(armorThicknessMainFireTower.x).tointeger(),
        stdMath.round(armorThicknessMainFireTower.y).tointeger(),
        stdMath.round(armorThicknessMainFireTower.z).tointeger(),
      ]
      holderObj.findObject("ship-mainFireTower-title").setValue(::loc("info/ship/mainFireTower") + ::loc("ui/colon"))
      holderObj.findObject("ship-mainFireTower-value").setValue(
        format("%d / %d / %d %s", val[0], val[1],val[2], ::loc("measureUnits/mm")))
    }

    // ship-antiTorpedoProtection
    local atProtection = unitTags?.Shop.atProtection
    holderObj.findObject("ship-antiTorpedoProtection-tr").show(atProtection != null)
    if(atProtection != null)
    {
      holderObj.findObject("ship-antiTorpedoProtection-title").setValue(
        "".concat(::loc("info/ship/antiTorpedoProtection"), ::loc("ui/colon")))
      holderObj.findObject("ship-antiTorpedoProtection-value").setValue(
        ::format("%d %s", atProtection, ::loc("measureUnits/kg")))
    }

    local shipMaterials = getShipMaterialTexts(air.name)

    // ship-hullMaterial
    {
      local valueText = shipMaterials?.hullValue ?? ""
      local isShow = valueText != ""
      holderObj.findObject("ship-hullMaterial-tr").show(isShow)
      if (isShow)
      {
        local labelText = (shipMaterials?.hullLabel ?? "") + ::loc("ui/colon")
        holderObj.findObject("ship-hullMaterial-title").setValue(labelText)
        holderObj.findObject("ship-hullMaterial-value").setValue(valueText)
      }
    }

    // ship-superstructureMaterial
    {
      local valueText = shipMaterials?.superstructureValue ?? ""
      local isShow = valueText != ""
      holderObj.findObject("ship-superstructureMaterial-tr").show(isShow)
      if (isShow)
      {
        local labelText = (shipMaterials?.superstructureLabel ?? "") + ::loc("ui/colon")
        holderObj.findObject("ship-superstructureMaterial-title").setValue(labelText)
        holderObj.findObject("ship-superstructureMaterial-value").setValue(valueText)
      }
    }
  }
  else
  {
    holderObj.findObject("ship-displacement-tr").show(false)
    holderObj.findObject("ship-citadelArmor-tr").show(false)
    holderObj.findObject("ship-mainFireTower-tr").show(false)
    holderObj.findObject("ship-antiTorpedoProtection-tr").show(false)
    holderObj.findObject("ship-hullMaterial-tr").show(false)
    holderObj.findObject("ship-superstructureMaterial-tr").show(false)
  }

  if (needShopInfo && holderObj.findObject("aircraft-train_cost-tr"))
    if (air.trainCost > 0)
    {
      holderObj.findObject("aircraft-train_cost-tr").show(true)
      holderObj.findObject("aircraft-train_cost").setValue(::getPriceAccordingToPlayersCurrency(air.trainCost, 0))
    }

  local showRewardsInfo = !(params?.showRewardsInfoOnlyForPremium ?? false) || special
  local rpRewardObj = ::showBtn("aircraft-reward_rp-tr", showRewardsInfo, holderObj)
  local wpRewardObj = ::showBtn("aircraft-reward_wp-tr", showRewardsInfo, holderObj)
  if (showRewardsInfo && (rpRewardObj != null || wpRewardObj!=null))
  {
    local hasPremium  = ::havePremium()
    local hasTalisman = special || ::shop_is_modification_enabled(air.name, "premExpMul")
    local boosterEffects = ::getTblValue("boosterEffects", params,
      getBoostersEffects(getActiveBoostersArray()))

    local wpMuls = air.getWpRewardMulList(difficulty)
    if (showAsRent)
      wpMuls.premMul = 1.0

    local wpMultText = [ wpMuls.wpMul.tostring() ]
    if (wpMuls.premMul != 1.0)
      wpMultText.append(::colorize("minorTextColor", ::loc("ui/multiply")),
        ::colorize("yellow", ::format("%.1f", wpMuls.premMul)))
    wpMultText = "".join(wpMultText)

    local rewardFormula = {
      rp = {
        obj           = rpRewardObj
        currency      = "currency/researchPoints/sign/colored"
        multText      = air.expMul.tostring()
        multiplier    = air.expMul
        premUnitMul   = 1.0
        noBonus       = 1.0
        premAccBonus  = hasPremium  ? ((rBlk?.xpMultiplier ?? 1.0) - 1.0)    : 0.0
        premModBonus  = hasTalisman ? ((rBlk?.goldPlaneExpMul ?? 1.0) - 1.0) : 0.0
        boosterBonus  = ::getTblValue(boosterEffectType.RP.name, boosterEffects, 0) / 100.0
      }
      wp = {
        obj           = wpRewardObj
        currency      = "warpoints/short/colored"
        multText      = wpMultText
        multiplier    = wpMuls.wpMul
        premUnitMul   = wpMuls.premMul
        noBonus       = 1.0
        premAccBonus  = hasPremium ? ((wBlk?.wpMultiplier ?? 1.0) - 1.0) : 0.0
        premModBonus  = 0.0
        boosterBonus  = ::getTblValue(boosterEffectType.WP.name, boosterEffects, 0) / 100.0
      }
    }

    foreach (id, f in rewardFormula)
    {
      if (f.obj == null)
        continue

      local result = f.multiplier * f.premUnitMul * ( f.noBonus + f.premAccBonus + f.premModBonus + f.boosterBonus )
      local resultText = ::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText(result)
      resultText = ::colorize("activeTextColor", resultText) + ::loc(f.currency)

      local formula = ::handyman.renderCached("gui/debriefing/rewardSources", {
        multiplier = f.multText
        noBonus    = ::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText(f.noBonus)
        premAcc    = f.premAccBonus  > 0 ? ::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText(f.premAccBonus)  : null
        premMod    = f.premModBonus  > 0 ? ::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText(f.premModBonus)  : null
        booster    = f.boosterBonus  > 0 ? ::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText(f.boosterBonus)  : null
      })

      holderObj.getScene().replaceContentFromText(f.obj.findObject($"aircraft-reward_{id}"), formula, formula.len(), handler)
      f.obj.findObject($"aircraft-reward_{id}-label").setValue($"{::loc("reward")} {resultText}{::loc("ui/colon")}")
    }
  }

  if (holderObj.findObject("aircraft-spare-tr"))
  {
    local spareCount = showLocalState ? ::get_spare_aircrafts_count(air.name) : 0
    holderObj.findObject("aircraft-spare-tr").show(spareCount > 0)
    if (spareCount > 0)
      holderObj.findObject("aircraft-spare").setValue(spareCount.tostring() + ::loc("icon/spare"))
  }

  local fullRepairTd = holderObj.findObject("aircraft-full_repair_cost-td")
  if (fullRepairTd)
  {
    local repairCostData = ""
    local discountsList = {}
    local freeRepairsUnlimited = ::isUnitDefault(air)
    local egdCode = difficulty.egdCode
    if (freeRepairsUnlimited)
      repairCostData = ::format("textareaNoTab { smallFont:t='yes'; text:t='%s' }", ::loc("shop/free"))
    else
    {
      local avgRepairMul = wBlk?.avgRepairMul ?? 1.0
      local avgCost = (avgRepairMul * ::wp_get_repair_cost_by_mode(air.name, egdCode, showLocalState)).tointeger()
      local modeName = ::get_name_by_gamemode(egdCode, false)
      discountsList[modeName] <- modeName + "-discount"
      repairCostData += format("tdiv { " +
                                 "textareaNoTab {smallFont:t='yes' text:t='%s' }" +
                                 "discount { id:t='%s'; text:t=''; pos:t='-1*@scrn_tgt/100.0, 0.5ph-0.55h'; position:t='relative'; rotation:t='8' }" +
                               "}\n",
                          ((repairCostData!="")?"/ ":"") + ::getPriceAccordingToPlayersCurrency(avgCost.tointeger(), 0),
                          discountsList[modeName]
                        )
    }
    holderObj.getScene().replaceContentFromText(fullRepairTd, repairCostData, repairCostData.len(), null)
    foreach(modeName, objName in discountsList)
      ::showAirDiscount(fullRepairTd.findObject(objName), air.name, "repair", modeName)

    if (!freeRepairsUnlimited)
    {
      local hours = showLocalState || needCrewModificators ? ::shop_get_full_repair_time_by_mode(air.name, egdCode)
        : ::getTblValue("repairTimeHrs" + ::get_name_by_gamemode(egdCode, true), air, 0)
      local repairTimeText = time.hoursToString(hours, false)
      local label = ::loc((showLocalState || needCrewModificators) && crew ? "shop/full_repair_time_crew" : "shop/full_repair_time")
      holderObj.findObject("aircraft-full_repair_time_crew-tr").show(true)
      holderObj.findObject("aircraft-full_repair_time_crew-tr").tooltip = label
      holderObj.findObject("aircraft-full_repair_time_label").setValue(label)
      holderObj.findObject("aircraft-full_repair_time_crew").setValue(repairTimeText)

      local freeRepairs = showAsRent ? 0
        : (showLocalState || needCrewModificators) ? air.freeRepairs - shop_get_free_repairs_used(air.name)
        : air.freeRepairs
      local showFreeRepairs = freeRepairs > 0
      holderObj.findObject("aircraft-free_repairs-tr").show(showFreeRepairs)
      if (showFreeRepairs)
        holderObj.findObject("aircraft-free_repairs").setValue(freeRepairs.tostring())
    }
    else
    {
      holderObj.findObject("aircraft-full_repair_time_crew-tr").show(false)
      holderObj.findObject("aircraft-free_repairs-tr").show(false)
//        if (holderObj.findObject("aircraft-full_repair_time-tr"))
//          holderObj.findObject("aircraft-full_repair_time-tr").show(false)
      ::hideBonus(holderObj.findObject("aircraft-full_repair_cost-discount"))
    }
  }

  local addInfoTextsList = []

  if (air.isPkgDev)
    addInfoTextsList.append(::colorize("badTextColor", ::loc("locatedInPackage", { package = "PKG_DEV" })))
  if (air.isRecentlyReleased())
    addInfoTextsList.append(::colorize("chapterUnlockedColor", ::loc("shop/unitIsRecentlyReleased")))
  if (isSquadronVehicle)
    addInfoTextsList.append(::colorize("currencySapColor", ::loc("mainmenu/squadronVehicle")))
  if (air.disableFlyout)
    addInfoTextsList.append(::colorize("warningTextColor", ::loc("mainmenu/vehicleCanNotGoToBattle")))

  if (isSquadronVehicle && needShopInfo)
  {
    if (isInClan)
    {
      if (isResearched)
        addInfoTextsList.append(::loc("mainmenu/leaveSquadronNotLockedVehicle"))
      else if (!isResearched && expCur > 0)
        addInfoTextsList.append(::loc("mainmenu/leaveSquadronNotClearProgress"))
    }
    else if (!isResearched)
    {
      if (expCur > 0)
        addInfoTextsList.append(::colorize("badTextColor", ::loc("mainmenu/needJoinSquadronForResearch/continue")))
      else
        addInfoTextsList.append(::colorize("badTextColor", ::loc("mainmenu/needJoinSquadronForResearch")))
    }
  }

  if (isInFlight)
  {
    local missionRules = ::g_mis_custom_state.getCurMissionRules()
    if (missionRules.isWorldWarUnit(air.name))
    {
      addInfoTextsList.append(::loc("icon/worldWar/colored") + ::colorize("activeTextColor",::loc("worldwar/unit")))
      addInfoTextsList.append(::loc("worldwar/unit/desc"))
    }
    if (missionRules.hasCustomUnitRespawns())
    {
      local disabledUnitByBRText = crew && !::is_crew_available_in_session(crew.idInCountry, false)
        && ::SessionLobby.getNotAvailableUnitByBRText(air)

      local respawnsleft = missionRules.getUnitLeftRespawns(air)
      if (respawnsleft == 0 || (respawnsleft>0 && !disabledUnitByBRText))
      {
        if (missionRules.isUnitAvailableBySpawnScore(air))
        {
          addInfoTextsList.append(::loc("icon/star/white") + ::colorize("activeTextColor",::loc("worldWar/unit/wwSpawnScore")))
          addInfoTextsList.append(::loc("worldWar/unit/wwSpawnScore/desc"))
        }
        else
        {
          local respText = missionRules.getRespawnInfoTextForUnitInfo(air)
          local color = respawnsleft ? "@userlogColoredText" : "@warningTextColor"
          addInfoTextsList.append(::colorize(color, respText))
        }
      }
      else if (disabledUnitByBRText)
        addInfoTextsList.append(::colorize("badTextColor", disabledUnitByBRText))
    }

    if (!isOwn)
      addInfoTextsList.append(::colorize("warningTextColor", ::loc("mainmenu/noLeaderboardProgress")))
  }

  local warbondId = ::getTblValue("wbId", params)
  if (warbondId)
  {
    local warbond = ::g_warbonds.findWarbond(warbondId, ::getTblValue("wbListId", params))
    local award = warbond? warbond.getAwardById(air.name) : null
    if (award)
      addInfoTextsList.extend(award.getAdditionalTextsArray())
  }

  if (rentTimeHours != -1)
  {
    if (rentTimeHours > 0)
    {
      local rentTimeStr = ::colorize("activeTextColor", time.hoursToString(rentTimeHours))
      addInfoTextsList.append(::colorize("userlogColoredText", ::loc("shop/rentFor", { time =  rentTimeStr })))
    }
    else
      addInfoTextsList.append(::colorize("userlogColoredText", ::loc("trophy/unlockables_names/trophy")))
    if (isOwn && !isReceivedPrizes)
    {
      local text = ::loc("mainmenu/itemReceived") + ::loc("ui/dot") + " " +
        ::loc(params?.relatedItem ? "mainmenu/activateOnlyOnce" : "mainmenu/receiveOnlyOnce")
      addInfoTextsList.append(::colorize("badTextColor", text))
    }
  }
  else
  {
    if (::canBuyUnitOnline(air))
      addInfoTextsList.append(::colorize("userlogColoredText",
        ::format(::loc("shop/giftAir/"+air.gift+"/info"), air.giftParam ? ::loc(air.giftParam) : "")))
    if (::isUnitDefault(air))
      addInfoTextsList.append(::loc("shop/reserve/info"))
    if (::canBuyUnitOnMarketplace(air))
      addInfoTextsList.append(::colorize("userlogColoredText",::loc("shop/giftAir/coupon/info")))
  }

  local showPriceText = rentTimeHours == -1 && showLocalState && !::isUnitBought(air)
    && ::isUnitResearched(air) && !::canBuyUnitOnline(air) && ::canBuyUnit(air)
  local priceObj = ::showBtn("aircraft_price", showPriceText, holderObj)
  if (showPriceText && ::check_obj(priceObj) && ::g_discount.getUnitDiscountByName(air.name) > 0) {
    placePriceTextToButton(holderObj, "aircraft_price",
      ::colorize("userlogColoredText", ::loc("events/air_can_buy")), ::getUnitCost(air), 0, ::getUnitRealCost(air))
  } else if (showPriceText) {
    local priceText = ::colorize("activeTextColor", ::getUnitCost(air).getTextAccordingToBalance())
    addInfoTextsList.append(::colorize("userlogColoredText", ::loc("mainmenu/canBuyThisVehicle", { price = priceText })))
  }

  local infoObj = holderObj.findObject("aircraft-addInfo")
  if (::checkObj(infoObj))
    infoObj.setValue(::g_string.implode(addInfoTextsList, "\n"))

  if (needCrewInfo && crew)
  {
    local crewUnitType = air.getCrewUnitType()
    local crewLevel = ::g_crew.getCrewLevel(crew, air, crewUnitType)
    local crewStatus = ::get_crew_status(crew, air)
    local specType = ::g_crew_spec_type.getTypeByCrewAndUnit(crew, air)
    local crewSpecIcon = specType.trainedIcon
    local crewSpecName = specType.getName()

    obj = holderObj.findObject("aircraft-crew_info")
    if (::checkObj(obj))
      obj.show(true)

    obj = holderObj.findObject("aircraft-crew_name")
    if (::checkObj(obj))
      obj.setValue(::g_crew.getCrewName(crew))

    obj = holderObj.findObject("aircraft-crew_level")
    if (::checkObj(obj))
      obj.setValue(::loc("crew/usedSkills") + " " + crewLevel)
    obj = holderObj.findObject("aircraft-crew_spec-label")
    if (::checkObj(obj))
      obj.setValue(::loc("crew/trained") + ::loc("ui/colon"))
    obj = holderObj.findObject("aircraft-crew_spec-icon")
    if (::checkObj(obj))
      obj["background-image"] = crewSpecIcon
    obj = holderObj.findObject("aircraft-crew_spec")
    if (::checkObj(obj))
      obj.setValue(crewSpecName)

    obj = holderObj.findObject("aircraft-crew_points")
    if (::checkObj(obj) && !isInFlight && crewStatus != "")
    {
      local crewPointsText = ::colorize("white", ::get_crew_sp_text(getCrewPoints(crew)))
      obj.show(true)
      obj.setValue(::loc("crew/availablePoints/advice") + ::loc("ui/colon") + crewPointsText)
      obj["crewStatus"] = crewStatus
    }
  }

  if (needShopInfo && !isRented)
  {
    local reason = ::getCantBuyUnitReason(air, true)
    local addTextObj = holderObj.findObject("aircraft-cant_buy_info")
    if (::checkObj(addTextObj) && !::u.isEmpty(reason))
    {
      addTextObj.setValue(::colorize("redMenuButtonColor", reason))

      local unitNest = holderObj.findObject("prev_unit_nest")
      if (::checkObj(unitNest) && (!::isPrevUnitResearched(air) || !::isPrevUnitBought(air)) &&
        ::is_era_available(air.shopCountry, air?.rank ?? -1, unitType))
      {
        local prevUnit = ::getPrevUnit(air)
        local unitBlk = ::build_aircraft_item(prevUnit.name, prevUnit)
        holderObj.getScene().replaceContentFromText(unitNest, unitBlk, unitBlk.len(), handler)
        ::fill_unit_item_timers(unitNest.findObject(prevUnit.name), prevUnit)
      }
    }
  }

  if (::has_entitlement("AccessTest") && needShopInfo && holderObj.findObject("aircraft-surviveRating"))
  {
    local blk = ::get_global_stats_blk()
    if (blk?["aircrafts"])
    {
      local stats = blk["aircrafts"]?[air.name]
      local surviveText = ::loc("multiplayer/notAvailable")
      local winsText = ::loc("multiplayer/notAvailable")
      local usageText = ::loc("multiplayer/notAvailable")
      local rating = -1
      if (stats)
      {
        local survive = stats?.flyouts_deaths ?? 1.0
        survive = (survive==0)? 0 : 1.0 - 1.0/survive
        surviveText = (survive * 100).tointeger() + "%"
        local wins = stats?.wins_flyouts ?? 0.0
        winsText = (wins * 100).tointeger() + "%"

        local usage = stats?.flyouts_factor ?? 0.0
        if (usage >= 0.000001)
        {
          rating = 0
          foreach(r in ::usageRating_amount)
            if (usage > r)
              rating++
          usageText = ::loc("shop/usageRating/" + rating)
          if (::has_entitlement("AccessTest"))
            usageText += " (" + (usage * 100).tointeger() + "%)"
        }
      }
      holderObj.findObject("aircraft-surviveRating-tr").show(true)
      holderObj.findObject("aircraft-surviveRating").setValue(surviveText)
      holderObj.findObject("aircraft-winsRating-tr").show(true)
      holderObj.findObject("aircraft-winsRating").setValue(winsText)
      holderObj.findObject("aircraft-usageRating-tr").show(true)
      if (rating>=0)
        holderObj.findObject("aircraft-usageRating").overlayTextColor = "usageRating" + rating;
      holderObj.findObject("aircraft-usageRating").setValue(usageText)
    }
  }

  local weaponsInfoText = getWeaponInfoText(air,
    { weaponPreset = showLocalState ? -1 : 0, ediff = ediff, isLocalState = showLocalState })
  obj = holderObj.findObject("weaponsInfo")
  if (obj) obj.setValue(weaponsInfoText)

  local lastPrimaryWeaponName = showLocalState ? getLastPrimaryWeapon(air) : ""
  local lastPrimaryWeapon = getModificationByName(air, lastPrimaryWeaponName)
  local massPerSecValue = ::getTblValue("mass_per_sec_diff", lastPrimaryWeapon, 0)

  local weaponIndex = -1
  local wPresets = 0
  if (air.weapons.len() > 0)
  {
    local lastWeapon = showLocalState ? getLastWeapon(air.name) : ""
    weaponIndex = 0
    foreach(idx, weapon in air.weapons)
    {
      if (isWeaponAux(weapon))
        continue
      wPresets++
      if (lastWeapon == weapon.name && "mass_per_sec" in weapon)
        weaponIndex = idx
    }
  }

  if (weaponIndex != -1)
  {
    local weapon = air.weapons[weaponIndex]
    massPerSecValue += ::getTblValue("mass_per_sec", weapon, 0)
  }

  if (massPerSecValue != 0)
  {
    local massPerSecText = format("%.2f %s", massPerSecValue, ::loc("measureUnits/kgPerSec"))
    obj = holderObj.findObject("aircraft-massPerSec")
    if (::checkObj(obj))
      obj.setValue(massPerSecText)
  }
  obj = holderObj.findObject("aircraft-massPerSec-tr")
  if (::checkObj(obj))
    obj.show(massPerSecValue != 0)

  obj = ::showBtn("aircraft-research-efficiency-tr", showRewardsInfo, holderObj)
  if (obj != null)
  {
    local minAge = ::getMinBestLevelingRank(air)
    local maxAge = ::getMaxBestLevelingRank(air)
    local rangeText = (minAge == maxAge) ? (::get_roman_numeral(minAge) + ::nbsp + ::loc("shop/age")) :
        (::get_roman_numeral(minAge) + ::nbsp + ::loc("ui/mdash") + ::nbsp + ::get_roman_numeral(maxAge) + ::nbsp + ::loc("mainmenu/ranks"))
    obj.findObject("aircraft-research-efficiency").setValue(rangeText)
  }

  obj = holderObj.findObject("aircraft-weaponPresets")
  if (::checkObj(obj))
    obj.setValue(wPresets.tostring())

  obj = holderObj.findObject("current_game_mode_footnote_text")
  if (::checkObj(obj))
  {
    local battleType = ::get_battle_type_by_ediff(ediff)
    local fonticon = !::CAN_USE_EDIFF ? "" :
      ::loc(battleType == BATTLE_TYPES.AIR ? "icon/unittype/aircraft" : "icon/unittype/tank")
    local diffName = ::g_string.implode([ fonticon, difficulty.getLocName() ], ::nbsp)

    local unitStateId = !showLocalState ? "reference"
      : crew ? "current_crew"
      : "current"
    local unitState = ::loc("shop/showing_unit_state/" + unitStateId)

    obj.setValue(::loc("shop/all_info_relevant_to_current_game_mode") + ::loc("ui/colon") + diffName + "\n" + unitState)
  }

  obj = holderObj.findObject("unit_rent_time")
  if (::checkObj(obj))
    obj.show(false)

  if (showLocalState)
    ::fillAirInfoTimers(holderObj, air, needShopInfo)
}

::__types_for_coutries <- null //for avoid recalculations
::get_unit_types_in_countries <- function get_unit_types_in_countries()
{
  if (::__types_for_coutries)
    return ::__types_for_coutries

  local defaultCountryData = {}
  foreach(unitType in unitTypes.types)
    defaultCountryData[unitType.esUnitType] <- false

  ::__types_for_coutries = {}
  foreach(country in ::shopCountriesList)
    ::__types_for_coutries[country] <- clone defaultCountryData

  foreach(unit in ::all_units)
  {
    if (!unit.unitType.isAvailable())
      continue
    local esUnitType = unit.unitType.esUnitType
    local countryData = ::getTblValue(::getUnitCountry(unit), ::__types_for_coutries)
    if (::getTblValue(esUnitType, countryData, true))
      continue
    countryData[esUnitType] <- ::isUnitBought(unit)
  }

  return ::__types_for_coutries
}

::get_player_cur_unit <- function get_player_cur_unit()
{
  local unit = null
  if (::is_in_flight())
    unit = ::getAircraftByName(::get_player_unit_name())
  if (!unit || unit.name == "dummy_plane")
    unit = ::show_aircraft
  return unit
}

::is_loaded_model_high_quality <- function is_loaded_model_high_quality(def = true)
{
  if (::hangar_get_loaded_unit_name() == "")
    return def
  return ::hangar_is_high_quality()
}

::get_units_list <- function get_units_list(filterFunc)
{
  local res = []
  foreach(unit in ::all_units)
    if (filterFunc(unit))
      res.append(unit)
  return res
}

local function isUnitAvailableForRank(unit, rank, esUnitType, country, exact_rank, needBought)
{
  // Keep this in sync with getUnitsCountAtRank() in chard
  return (esUnitType == ::get_es_unit_type(unit) || esUnitType == ::ES_UNIT_TYPE_TOTAL)
    && (country == unit.shopCountry || country == "")
    && (unit.rank == rank || (!exact_rank && unit.rank > rank))
    && ((!needBought || ::isUnitBought(unit)) && unit.isVisibleInShop())
}

local function hasUnitAtRank(rank, esUnitType, country, exact_rank, needBought = true)
{
  foreach (unit in ::all_units)
    if (isUnitAvailableForRank(unit, rank, esUnitType, country, exact_rank, needBought))
      return true
  return false
}

::get_units_count_at_rank <- function get_units_count_at_rank(rank, esUnitType, country, exact_rank, needBought = true)
{
  local count = 0
  foreach (unit in ::all_units)
    if (isUnitAvailableForRank(unit, rank, esUnitType, country, exact_rank, needBought))
      count++
  return count
}

{
  local unitCacheName = null
  local unitCacheBlk = null
  ::get_full_unit_blk <- function get_full_unit_blk(unitName) //better to not use this funtion, and collect all data from wpcost and unittags
  {
    if (unitName != unitCacheName)
    {
      unitCacheName = unitName
      unitCacheBlk = blkFromPath(::get_unit_file_name(unitName))
    }
    return unitCacheBlk
  }
}

::get_fm_file <- function get_fm_file(unitId, unitBlkData = null)
{
  local unitPath = ::get_unit_file_name(unitId)
  if (unitBlkData == null)
    unitBlkData = ::get_full_unit_blk(unitId)
  local nodes = ::split(unitPath, "/")
  if (nodes.len())
    nodes.pop()
  local unitDir = ::g_string.implode(nodes, "/")
  local fmPath = unitDir + "/" + (unitBlkData?.fmFile ?? ("fm/" + unitId))
  return blkFromPath(fmPath)
}

return {
  hasUnitAtRank
}