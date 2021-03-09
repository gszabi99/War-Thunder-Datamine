local { round_by_value } = require("std/math.nut")
local { secondsToString } = require("scripts/time.nut")
local { blkFromPath } = require("sqStdLibs/helpers/datablockUtils.nut")
local { countMeasure } = require("scripts/options/optionsMeasureUnits.nut")
local { WEAPON_TYPE, TRIGGER_TYPE, CONSUMABLE_TYPES, WEAPON_TEXT_PARAMS, getLastWeapon,
  getUnitWeaponry, isCaliberCannon, addWeaponsFromBlk, getCommonWeaponsBlk, getLastPrimaryWeapon,
  getWeaponExtendedInfo
} = require("scripts/weaponry/weaponryInfo.nut")
local { getBulletsSetData, getModificationName } = require("scripts/weaponry/bulletsInfo.nut")
local { getModificationBulletsGroup } = require("scripts/weaponry/modificationInfo.nut")


local function getReloadTimeByCaliber(caliber, ediff = null)
{
  local diff = ::get_difficulty_by_ediff(ediff ?? ::get_current_ediff())
  if (diff != ::g_difficulty.ARCADE)
    return null
  return ::reload_cooldown_time?[caliber]
}

local getTextNoWeapons = @(unit, isPrimary) isPrimary ? ::loc("weapon/noPrimaryWeapon")
  : (unit.isAir() || unit.isHelicopter()) ? ::loc("weapon/noSecondaryWeapon")
  : ::loc("weapon/noAdditionalWeapon")

local function getWeaponInfoText(unit, p = WEAPON_TEXT_PARAMS)
{
  local text = ""
  unit = typeof(unit) == "string" ? ::getAircraftByName(unit) : unit
  if (!unit)
    return text

  local weapons = getUnitWeaponry(unit, p)
  if (weapons == null)
    return text

  p = WEAPON_TEXT_PARAMS.__merge(p)
  local unitType = ::get_es_unit_type(unit)
  if (::u.isEmpty(weapons) && p.needTextWhenNoWeapons)
    text += getTextNoWeapons(unit, p.isPrimary)
  local stackableWeapons = [WEAPON_TYPE.TURRETS]
  foreach (index, weaponType in WEAPON_TYPE)
  {
    if (!(weaponType in weapons))
      continue

    local triggers = weapons[weaponType]
    triggers.sort(@(a, b) b.caliber <=> a.caliber)

    if (::isInArray(weaponType, stackableWeapons))
    {  //merge stackable in one
      for(local i=0; i<triggers.len(); i++)
      {
        triggers[i][weaponType] <- 1
        local sameIdx = -1
        for(local j=0; j<i; j++)
          if (triggers[i].len() == triggers[j].len())
          {
            local same = true
            foreach(wName, w in triggers[j])
              if (!(wName in triggers[i]) ||
                  ((typeof(w) == "table") && triggers[i][wName].num!=w.num))
              {
                same = false
                break
              }
            if (same)
            {
              sameIdx = j
              break
            }
          }
        if (sameIdx>=0)
        {
          triggers[sameIdx][weaponType]++
          foreach(wName, w in triggers[i])
            if (typeof(w) == "table")
              triggers[sameIdx][wName].ammo += w.ammo
          triggers.remove(i)
          i--
        }
      }
    }

    local isShortDesc = p.detail <= INFO_DETAIL.SHORT //for weapons SHORT == LIMITED_11
    local weapTypeCount = 0; //for shortDesc only
    foreach (trigger in triggers)
    {
      local tText = ""
      foreach (weaponName, weapon in trigger)
        if (typeof(weapon) == "table")
        {
          if (tText != "" && weapTypeCount==0)
            tText += p.newLine

          if (::isInArray(weaponType, CONSUMABLE_TYPES))
          {
            if (isShortDesc)
            {
              tText += ::loc($"weapons/{weaponName}/short")
              if (weapon.ammo > 1)
                tText += " " + ::format(::loc("weapons/counter/right/short"), weapon.ammo)
            }
            else
            {
              tText += ::loc($"weapons/{weaponName}") + ::format(::loc("weapons/counter"), weapon.ammo)
              if (weaponType == "torpedoes" && p.isPrimary != null &&
                  ::isInArray(unitType, [::ES_UNIT_TYPE_AIRCRAFT, ::ES_UNIT_TYPE_HELICOPTER])) // torpedoes drop for unit only
              {
                if (weapon.dropSpeedRange)
                {
                  local speedKmph = countMeasure(0, [weapon.dropSpeedRange.x, weapon.dropSpeedRange.y])
                  local speedMps  = countMeasure(3, [weapon.dropSpeedRange.x, weapon.dropSpeedRange.y])
                  tText += "\n"+::format( ::loc("weapons/drop_speed_range"),
                    "{0} {1}".subst(speedKmph, ::loc("ui/parentheses", { text = speedMps })) )
                }
                if (weapon.dropHeightRange)
                  tText += "\n"+::format(::loc("weapons/drop_height_range"),
                    countMeasure(1, [weapon.dropHeightRange.x, weapon.dropHeightRange.y]))
              }
              if (p.detail >= INFO_DETAIL.EXTENDED && unitType != ::ES_UNIT_TYPE_TANK)
                tText += getWeaponExtendedInfo(weapon, weaponType, unit, p.ediff, p.newLine + ::nbsp + ::nbsp + ::nbsp + ::nbsp)
            }
          }
          else
          {
            if (isShortDesc)
              weapTypeCount += (TRIGGER_TYPE.TURRETS in trigger)? 0 : weapon.num
            else
            {
              tText += ::loc($"weapons/{weaponName}")
              if (weapon.num > 1)
                tText += ::format(::loc("weapons/counter"), weapon.num)

              if (weapon.ammo > 0)
                tText += " (" + ::loc("shop/ammo") + ::loc("ui/colon") + weapon.ammo + ")"

              if (!unit.unitType.canUseSeveralBulletsForGun)
              {
                local rTime = getReloadTimeByCaliber(weapon.caliber, p.ediff)
                if (rTime)
                {
                  if (p.isLocalState)
                  {
                    local difficulty = ::get_difficulty_by_ediff(p.ediff ?? ::get_current_ediff())
                    local key = isCaliberCannon(weapon.caliber) ? "cannonReloadSpeedK" : "gunReloadSpeedK"
                    local speedK = unit.modificators?[difficulty.crewSkillName]?[key] ?? 1.0
                    if (speedK)
                      rTime = round_by_value(rTime / speedK, 1.0).tointeger()
                  }
                  tText += " " + ::loc("bullet_properties/cooldown") + " " + secondsToString(rTime, true, true)
                }
              }
            }
          }
        }

      if (isShortDesc)
        weapTypeCount += (TRIGGER_TYPE.TURRETS in trigger)? trigger[TRIGGER_TYPE.TURRETS] : 0
      else
      {
        if (TRIGGER_TYPE.TURRETS in trigger) // && !unit.unitType.canUseSeveralBulletsForGun)
        {
          if(trigger[TRIGGER_TYPE.TURRETS] > 1)
            tText = ::format(::loc("weapons/turret_number"), trigger[TRIGGER_TYPE.TURRETS]) + tText
          else
            tText = ::g_string.utf8ToUpper(::loc("weapons_types/turrets"), 1) + ::loc("ui/colon") + tText
        }
      }

      if (tText!="")
        text += ((text!="")? p.newLine : "") + tText
    }
    if (weapTypeCount>0)
    {
      if (text!="") text += p.newLine
      if (isShortDesc)
        text += ::loc("weapons_types/" + weaponType) + ::nbsp + ::format(::loc("weapons/counter/right/short"), weapTypeCount)
      else
        text += ::loc("weapons_types/" + weaponType) + ::format(::loc("weapons/counter"), weapTypeCount)
    }
  }

  if (text=="" && p.needTextWhenNoWeapons)
    text = getTextNoWeapons(unit, p.isPrimary)

  return text
}

local function getWeaponNameText(unit, isPrimary = null, weaponPreset=-1, newLine=", ")
{
  return getWeaponInfoText(unit,
    { isPrimary = isPrimary, weaponPreset = weaponPreset, newLine = newLine, detail = INFO_DETAIL.SHORT })
}


local function getWeaponXrayDescText(weaponBlk, unit, ediff)
{
  local weaponsBlk = ::DataBlock()
  weaponsBlk["Weapon"] = weaponBlk
  local weaponTypes = addWeaponsFromBlk({}, weaponsBlk, unit)
  foreach (weaponType, weaponTypeList in weaponTypes)
    foreach (weapons in weaponTypeList)
      foreach (weapon in weapons)
        if (::u.isTable(weapon))
          return getWeaponExtendedInfo(weapon, weaponType, unit, ediff, "\n")
  return ""
}


local function getWeaponDescTextByTriggerGroup(triggerGroup, unit, ediff)
{
  local unitBlk = ::get_full_unit_blk(unit.name)
  local primaryWeapon = getLastPrimaryWeapon(unit)
  local secondaryWeapon = getLastWeapon(unit.name)

  local primaryBlk = getCommonWeaponsBlk(unitBlk, primaryWeapon)
  local weaponTypes = {}
  if (primaryBlk)
    weaponTypes = addWeaponsFromBlk(weaponTypes, primaryBlk, unit)
  if (unitBlk?.weapon_presets)
    foreach (wp in (unitBlk.weapon_presets % "preset"))
      if (wp.name == secondaryWeapon)
      {
        local wpBlk = blkFromPath(wp.blk)
        weaponTypes = addWeaponsFromBlk(weaponTypes, wpBlk, unit)
        break
      }

  if (weaponTypes?[triggerGroup])
    foreach (weapons in weaponTypes[triggerGroup])
      foreach (weaponName, weapon in weapons)
        if (::u.isTable(weapon))
          return "".concat(
            ::loc($"weapons/{weaponName}"),
            ::format(::loc("weapons/counter"), weapon.ammo),
            getWeaponExtendedInfo(weapon, triggerGroup, unit, ediff, "\n{0}{0}{0}{0}".subst(::nbsp))
          )
  return ""
}

// return short desc of unit.weapons[weaponPresetNo], like M\C\B\T
local function getWeaponShortType(unit, weaponPresetNo=0)
{
  if (typeof(unit) == "string")
    unit = ::getAircraftByName(unit)

  if (!unit)
    return ""

  local textArr = []
  if (unit.weapons[weaponPresetNo].frontGun)
    textArr.append(::loc("weapons_types/short/guns"))
  if (unit.weapons[weaponPresetNo].cannon)
    textArr.append(::loc("weapons_types/short/cannons"))
  if (unit.weapons[weaponPresetNo].bomb)
    textArr.append(::loc("weapons_types/short/bombs"))
  if (unit.weapons[weaponPresetNo].rocket)
    textArr.append(::loc("weapons_types/short/rockets"))
  if (unit.weapons[weaponPresetNo].torpedo)
    textArr.append(::loc("weapons_types/short/torpedoes"))

  return ::loc("weapons_types/short/separator").join(textArr)
}

local function getWeaponShortTypeFromWpName(wpName, unit = null)
{
  if (!wpName || typeof(wpName) != "string")
    return ""

  if (typeof(unit) == "string")
    unit = ::getAircraftByName(unit)

  if (!unit)
    return ""

  for (local i = 0; i < unit.weapons.len(); ++i)
  {
    if (wpName == unit.weapons[i].name)
      return getWeaponShortType(unit, i)
  }

  return ""
}

local function getDefaultBulletName(unit)
{
  if (!("modifications" in unit))
    return ""

  local ignoreGroups = [null, ""]
  for (local modifNo = 0; modifNo < unit.modifications.len(); modifNo++)
  {
    local modif = unit.modifications[modifNo]
    local modifName = modif.name;

    local groupName = getModificationBulletsGroup(modifName);
    if (::isInArray(groupName, ignoreGroups))
      continue

    local bData = getBulletsSetData(unit, modifName)
    if (!bData || bData?.useDefaultBullet)
      return groupName + "_default"

    ignoreGroups.append(groupName)
  }
  return ""
}

local function getModItemName(unit, item, limitedName = true)
{
  return ::g_weaponry_types.getUpgradeTypeByItem(item).getLocName(unit, item, limitedName)
}

local function getReqModsText(unit, item)
{
  local reqText = ""
  foreach(rp in ["reqWeapon", "reqModification"])
      if (rp in item)
        foreach (req in item[rp])
          if (rp == "reqWeapon" && !::shop_is_weapon_purchased(unit.name, req))
            reqText += ((reqText=="")?"":"\n") + ::loc(rp) + ::loc("ui/colon") + getWeaponNameText(unit.name, false, req, ", ")
          else
          if (rp == "reqModification" && !::shop_is_modification_purchased(unit.name, req))
            reqText += ((reqText=="")?"":"\n") + ::loc(rp) + ::loc("ui/colon") + getModificationName(unit, req)
  return reqText
}

local function getBulletsListHeader(unit, bulletsList)
{
  local locId = ""
  if (bulletsList.weaponType == WEAPON_TYPE.ROCKETS)
    locId = "modification/_rockets"
  else if (::isInArray(bulletsList.weaponType, [ WEAPON_TYPE.AAM, WEAPON_TYPE.AGM ]))
    locId = "modification/_missiles"
  else if (bulletsList.weaponType == WEAPON_TYPE.FLARES)
    locId = "modification/_flares"
  else if (bulletsList.weaponType == WEAPON_TYPE.SMOKE)
    locId = "modification/_smoke_screen"
  else if (bulletsList.weaponType == WEAPON_TYPE.GUNS)
  {
    if (unit.unitType.canUseSeveralBulletsForGun)
      locId = isCaliberCannon(bulletsList.caliber)? "modification/_tank_gun_pack" : "modification/_tank_minigun_pack"
    else
      locId = bulletsList.isTurretBelt ? "modification/_turret_belt_pack/short" : "modification/_belt_pack/short"
  }
  else if (bulletsList.weaponType == WEAPON_TYPE.COUNTERMEASURES)
    locId = "modification/_countermeasures"
  return ::format(::loc(locId), bulletsList.caliber.tostring())
}

//include spawn score cost
local function getFullItemCostText(unit, item, spawnScoreOnly = false)
{
  local res = ""
  local wType = ::g_weaponry_types.getUpgradeTypeByItem(item)
  local misRules = ::g_mis_custom_state.getCurMissionRules()

  if ((!::is_in_flight() || misRules.isWarpointsRespawnEnabled) && !spawnScoreOnly)
    res = wType.getCost(unit, item).tostring()

  if (::is_in_flight() && misRules.isScoreRespawnEnabled)
  {
    local scoreCostText = wType.getScoreCostText(unit, item)
    if (scoreCostText.len())
      res += (res.len() ? ", " : "") + scoreCostText
  }
  return res
}

return {
  getWeaponInfoText
  getWeaponNameText
  getWeaponXrayDescText
  getWeaponDescTextByTriggerGroup
  getWeaponShortType
  getWeaponShortTypeFromWpName
  getDefaultBulletName
  getModItemName
  getReqModsText
  getBulletsListHeader
  getFullItemCostText
}