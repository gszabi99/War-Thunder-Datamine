local { getItemStatusTbl,
        getItemUnlockCost,
        getItemCost } = require("scripts/weaponry/itemInfo.nut")
local { isFakeBullet,
        getBulletGroupIndex } = require("scripts/weaponry/bulletsInfo.nut")
local { getLastWeapon,
        setLastWeapon } = require("scripts/weaponry/weaponryInfo.nut")
local { AMMO,
        getAmmoAmountData,
        getAmmoAmount,
        getAmmoMaxAmount,
        getAmmoCost } = require("scripts/weaponry/ammoInfo.nut")
local { getWeaponInfoText,
        getWeaponNameText } = require("scripts/weaponry/weaponryVisual.nut")
local { canBuyMod, isModClassExpendable } = require("scripts/weaponry/modificationInfo.nut")

::checkUnitWeapons <- function checkUnitWeapons(unit)
{
  local weapon = getLastWeapon(unit.name)
  local weaponText = getAmmoAmountData(unit, weapon, AMMO.WEAPON)
  if (weaponText.warning)
    return weaponText.amount? UNIT_WEAPONS_WARNING : UNIT_WEAPONS_ZERO

  for (local i = 0; i < unit.unitType.bulletSetsQuantity; i++)
  {
    local modifName = ::get_last_bullets(unit.name, i);
    if (modifName && modifName != "" && ::shop_is_modification_enabled(unit.name, modifName))
    {
      local modificationText = getAmmoAmountData(unit, modifName, AMMO.MODIFICATION)
      if (modificationText.warning)
        return modificationText.amount? UNIT_WEAPONS_WARNING : UNIT_WEAPONS_ZERO
    }
  }

  return UNIT_WEAPONS_READY;
}

::get_weapon_name_by_blk_path <- function get_weapon_name_by_blk_path(weaponBlkPath)
{
  local idxLastSlash = ::g_string.lastIndexOf(weaponBlkPath, "/")
  local idxStart = idxLastSlash != ::g_string.INVALID_INDEX ? (idxLastSlash + 1) : 0
  local idxEnd = ::g_string.endsWith(weaponBlkPath, ".blk") ? -4 : weaponBlkPath.len()
  return weaponBlkPath.slice(idxStart, idxEnd)
}

::is_weapon_params_equal <- function is_weapon_params_equal(item1, item2)
{
  if (typeof(item1) != "table" || typeof(item2) != "table" || !item1.len() || !item2.len())
    return false
  local skipParams = [ "num", "ammo" ]
  foreach (idx, val in item1)
    if (!::isInArray(idx, skipParams) && !::u.isEqual(val, item2[idx]))
      return false
  return true
}

::isCaliberCannon <- function isCaliberCannon(caliber_mm)
{
  return caliber_mm >= 15
}

::isAirHaveSecondaryWeapons <- function isAirHaveSecondaryWeapons(air)
{
  local foundWeapon = false
  for (local i = 0; i < air.weapons.len(); i++)
    if (!::isWeaponAux(air.weapons[i]))
      if (foundWeapon)
        return true
      else
        foundWeapon = true
  return "" != getWeaponInfoText(air, { isPrimary = false, weaponPreset = 0, needTextWhenNoWeapons = false })
}

::get_expendable_modifications_array <- function get_expendable_modifications_array(unit)
{
  if (!("modifications" in unit))
    return []

  return ::u.filter(unit.modifications, isModClassExpendable)
}

::getPrimaryWeaponsList <- function getPrimaryWeaponsList(air)
{
  if(air.primaryWeaponMods)
    return air.primaryWeaponMods

  air.primaryWeaponMods = [""]

  local airBlk = ::get_full_unit_blk(air.name)
  if(!airBlk || !airBlk?.modifications)
    return air.primaryWeaponMods

  foreach(modName, modification in airBlk.modifications)
    if (modification?.effects?.commonWeapons)
      air.primaryWeaponMods.append(modName)

  return air.primaryWeaponMods
}

::get_last_primary_weapon <- function get_last_primary_weapon(air)
{
  local primaryList = ::getPrimaryWeaponsList(air)
  foreach(modName in primaryList)
    if (modName!="" && ::shop_is_modification_enabled(air.name, modName))
      return modName
  return ""
}

::getCommonWeaponsBlk <- function getCommonWeaponsBlk(airBlk, primaryMod)
{
  if (primaryMod == "" && airBlk?.commonWeapons)
    return airBlk.commonWeapons

  if (airBlk?.modifications)
    foreach(modName, modification in airBlk.modifications)
      if (modName == primaryMod)
      {
        if (modification?.effects.commonWeapons)
          return modification.effects.commonWeapons
        break
      }
  return null
}

::updateRelationModificationList <- function updateRelationModificationList(air, modifName)
{
  local mod = ::getModificationByName(air, modifName)
  if (mod && !("relationModification" in mod))
  {
    local blk = ::get_modifications_blk();
    mod.relationModification <- [];
    foreach(ind, m in air.modifications)
    {
      if ("reqModification" in m && ::isInArray(modifName, m.reqModification))
      {
        local modification = blk?.modifications?[m.name]
        if (modification?.effects)
          foreach (effectType, effect in modification.effects)
          {
            if (effectType == "additiveBulletMod")
            {
              mod.relationModification.append(m.name)
              break;
            }
          }
      }
    }
  }
}

::get_premExpMul_add_value <- function get_premExpMul_add_value(unit)
{
  return (::get_ranks_blk()?.goldPlaneExpMul ?? 1.0) - 1.0
}

/*
::getActiveBulletsModificationName <- function getActiveBulletsModificationName(air, group_index)
{
  if (typeof(air) == "string")
    air = getAircraftByName(air)
  if (!air || !("modifications" in air))
    return null

  local groupsCount = 0
  if (air.unitType.canUseSeveralBulletsForGun)
    groupsCount = ::BULLETS_SETS_QUANTITY
  else
    groupsCount = ::getBulletsGroupCount(air);

  if (group_index >= 0 && group_index < groupsCount)
    return air.unitType.canUseSeveralBulletsForGun ? ::get_unit_option(air.name, ::USEROPT_BULLETS0 + group_index) : ::get_last_bullets(air.name, group_index)
  return null; //no group
}
*/

::check_bad_weapons <- function check_bad_weapons()
{
  foreach(unit in ::all_units)
  {
    if (!unit.isUsable())
      continue

    local curWeapon = getLastWeapon(unit.name)
    if (curWeapon=="")
      continue

    if (!::shop_is_weapon_available(unit.name, curWeapon, false, false) && !::shop_is_weapon_purchased(unit.name, curWeapon))
      setLastWeapon(unit.name, "")
  }
}

::get_reload_time_by_caliber <- function get_reload_time_by_caliber(caliber, ediff = null)
{
  local diff = ::get_difficulty_by_ediff(ediff ?? ::get_current_ediff())
  if (diff != ::g_difficulty.ARCADE)
    return null
  return ::reload_cooldown_time?[caliber]
}

::isModMaxExp <- function isModMaxExp(air, mod)
{
  return ::shop_get_module_exp(air.name, mod.name) >= ::getTblValue("reqExp", mod, 0)
}

::can_buy_weapons_item <- function can_buy_weapons_item(air, item)
{
  return ::g_weaponry_types.getUpgradeTypeByItem(item).canBuy(air, item)
}

::is_weapon_enabled <- function is_weapon_enabled(unit, weapon)
{
  return ::shop_is_weapon_available(unit.name, weapon.name, true, false) //no point to check purchased unit even in respawn screen
         //temporary hack: check ammo amount for forced units by mission,
         //because shop_is_weapon_available function work incorrect with them
         && (!::is_game_mode_with_spendable_weapons()
             || getAmmoAmount(unit, weapon.name, AMMO.WEAPON)
             || !getAmmoMaxAmount(unit, weapon.name, AMMO.WEAPON)
            )
         && (!::is_in_flight() || ::g_mis_custom_state.getCurMissionRules().isUnitWeaponAllowed(unit, weapon))
}

::is_weapon_unlocked <- function is_weapon_unlocked(unit, weapon)
{
  foreach(rp in ["reqWeapon", "reqModification"])
      if (rp in weapon)
        foreach (req in weapon[rp])
          if (rp == "reqWeapon" && !::shop_is_weapon_purchased(unit.name, req))
            return false
          else
          if (rp == "reqModification" && !::shop_is_modification_purchased(unit.name, req))
            return false
  return true
}

::is_weapon_visible <- function is_weapon_visible(unit, weapon, onlyBought = true, weaponTags = null)
{
  if (::isWeaponAux(weapon))
    return false

  if (weaponTags != null)
  {
    local hasTag = false
    foreach(t in weaponTags)
      if (::getTblValue(t, weapon))
      {
        hasTag = true
        break
      }
    if (!hasTag)
      return false
  }

  if (onlyBought &&  !::shop_is_weapon_purchased(unit.name, weapon.name)
      && getAmmoCost(unit, weapon.name, AMMO.WEAPON) > ::zero_money)
    return false

  return true
}

::get_weapon_by_name <- function get_weapon_by_name(unit, weaponName)
{
  if (!("weapons" in unit))
    return null

  return ::u.search(unit.weapons, (@(weaponName) function(weapon) {
      return weapon.name == weaponName
    })(weaponName))
}

::get_all_modifications_cost <- function get_all_modifications_cost(unit, open = false)
{
  local modsCost = ::Cost()
  foreach(modification in ::getTblValue("modifications", unit, {}))
  {
    local statusTbl = getItemStatusTbl(unit, modification)
    if (statusTbl.maxAmount == statusTbl.amount)
      continue

    local skipSummary = false
    local _modCost = ::Cost()

    if (open)
    {
      local openCost = getItemUnlockCost(unit, modification)
      if (!openCost.isZero())
        _modCost = openCost
    }

    if (canBuyMod(unit, modification))
    {
      local modificationCost = getItemCost(unit, modification)
      if (!modificationCost.isZero())
      {
        skipSummary = statusTbl.maxAmount > 1

        if (modificationCost.gold > 0)
          skipSummary = true

        _modCost = modificationCost
      }
    }

    // premium modifications or ammo is separated,
    // so no need to show it's price with other modifications.
    if (skipSummary)
      continue

    modsCost += _modCost
  }

  return modsCost
}

::prepareUnitsForPurchaseMods <- {
  unitsTable = {} //unitName - unitBlock

  function clear() { unitsTable = {} }
  function getUnits() { return unitsTable }
  function haveUnits() { return unitsTable.len() > 0 }

  function addUnit(unit)
  {
    if (!unit)
      return

    unitsTable[unit.name] <- unit
  }

  function checkUnboughtMods(silent = false)
  {
    if (!haveUnits())
      return

    local cost = ::Cost()
    local unitsWithNBMods = []
    local stringOfUnits = []

    foreach(unitName, unit in unitsTable)
    {
      local modsCost = ::get_all_modifications_cost(unit)
      if (modsCost.isZero())
        continue

      cost += modsCost
      unitsWithNBMods.append(unit)
      stringOfUnits.append(::colorize("userlogColoredText", ::getUnitName(unit, true)))
    }

    if (unitsWithNBMods.len() == 0)
      return

    if (silent)
    {
      if (::check_balance_msgBox(cost, null, silent))
        ::prepareUnitsForPurchaseMods.purchaseModifications(unitsWithNBMods)
      return
    }

    ::scene_msg_box("buy_all_available_mods", null,
      ::loc("msgbox/buy_all_researched_modifications",
        { unitsList = ::g_string.implode(stringOfUnits, ","), cost = cost.getTextAccordingToBalance() }),
      [["yes", (@(cost, unitsWithNBMods) function() {
          if (!::check_balance_msgBox(cost, function(){::prepareUnitsForPurchaseMods.checkUnboughtMods()}))
            return

          ::prepareUnitsForPurchaseMods.purchaseModifications(unitsWithNBMods)
        })(cost, unitsWithNBMods)],
       ["no", function(){ ::prepareUnitsForPurchaseMods.clear() } ]],
        "yes", { cancel_fn = function() { ::prepareUnitsForPurchaseMods.clear() }})
  }

  function purchaseModifications(unitsArray)
  {
    if (unitsArray.len() == 0)
    {
      ::prepareUnitsForPurchaseMods.clear()
      ::showInfoMsgBox(::loc("msgbox/all_researched_modifications_bought"), "successfully_bought_mods")
      return
    }

    local curUnit = unitsArray.remove(0)
    local afterSuccessFunc = (@(unitsArray) function() {
      ::prepareUnitsForPurchaseMods.purchaseModifications(unitsArray)
    })(unitsArray)

    ::WeaponsPurchase(curUnit, {afterSuccessfullPurchaseCb = afterSuccessFunc, silent = true})
  }
}

::getModificationByName <- function getModificationByName(unit, modName, isFakeBulletsAllowed = false)
{
  if (!("modifications" in unit))
    return null

  foreach(i, modif in unit.modifications)
    if (modif.name == modName)
      return modif

  if (!isFakeBulletsAllowed)
    return null

  if (isFakeBullet(modName))
  {
    local groupIdxStr = ::g_string.slice(modName, ::fakeBullets_prefix.len(), ::fakeBullets_prefix.len() + 1)
    local groupIdx = ::to_integer_safe(groupIdxStr, -1)
    if (groupIdx < 0)
      return null
    return {
      name = modName
      isDefaultForGroup = groupIdx
    }
  }

  // Attempt to get modification from group index (e.g. default modification).
  local groupIndex = getBulletGroupIndex(unit.name, modName)
  if (groupIndex >= 0)
    return { name = modName, isDefaultForGroup = groupIndex }

  return null
}

::get_linked_gun_index <- function get_linked_gun_index(group_index, total_groups, bulletSetsQuantity, canBeDuplicate = true)
{
  if (!canBeDuplicate)
    return group_index
  return (group_index.tofloat() * total_groups / bulletSetsQuantity + 0.001).tointeger()
}

::isAirHaveAnyWeaponsTags <- function isAirHaveAnyWeaponsTags(air, tags, checkPurchase = true)
{
  if (!air)
    return false

  foreach(w in air.weapons)
    if (::shop_is_weapon_purchased(air.name, w.name) > 0 || !checkPurchase)
      foreach(tag in tags)
        if ((tag in w) && w[tag])
          return true
  return false
}

::get_weapons_list <- function get_weapons_list(aircraft, need_cost, wtags, only_bought=false, check_aircraft_purchased=true)
{
  local descr = {}
  descr.items <- []
  descr.values <- []
  descr.cost <- []
  descr.costGold <- []
  descr.hints <- []

  local unit = ::getAircraftByName(aircraft)
  if (!unit)
    return descr

  local optionSeparator = ", "
  local hintSeparator = "\n"

  foreach(weapNo, weapon in unit.weapons)
  {
    local weaponName = weapon.name
    if (!::is_weapon_visible(unit, weapon, only_bought, wtags))
      continue

    local cost = getAmmoCost(unit, weaponName, AMMO.WEAPON)
    descr.cost.append(cost.wp)
    descr.costGold.append(cost.gold)
    descr.values.append(weaponName)

    local costText = (need_cost && cost > ::zero_money)? "(" + cost.getUncoloredWpText() + ") " : ""
    local amountText = check_aircraft_purchased && ::is_game_mode_with_spendable_weapons() ?
      getAmmoAmountData(unit, weaponName, AMMO.WEAPON).text : "";

    local tooltip = costText + getWeaponInfoText(unit, { isPrimary = false, weaponPreset = weapNo, newLine = hintSeparator })
      + amountText

    descr.items.append({
      text = costText + getWeaponNameText(unit, false, weapNo, optionSeparator) + amountText
      tooltip = tooltip
    })
    descr.hints.append(tooltip)
  }

  return descr
}