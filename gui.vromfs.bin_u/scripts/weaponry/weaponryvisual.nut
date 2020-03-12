local time = require("scripts/time.nut")
local stdMath = require("std/math.nut")
local { countMeasure } = require("scripts/options/optionsMeasureUnits.nut")
local { getBulletsSetData,
        getModificationBulletsGroup } = require("scripts/weaponry/bulletsInfo.nut")
local { WEAPON_TEXT_PARAMS,
        WEAPON_TYPE,
        getLastWeapon,
        getPresetsWeaponry,
        addWeaponsFromBlk,
        getWeaponExtendedInfo } = require("scripts/weaponry/weaponryInfo.nut")

local function getWeaponInfoText(air, p = WEAPON_TEXT_PARAMS)
{
  local text = ""
  air = typeof(air) == "string" ? ::getAircraftByName(air) : air
  if (!air)
    return text

  p = WEAPON_TEXT_PARAMS.__merge(p)

  local unitType = ::get_es_unit_type(air)
  local weapons = getPresetsWeaponry(air, p)
  if (weapons == null)
    return text

  if (::u.isEmpty(weapons) && p.needTextWhenNoWeapons)
      text += ::loc("weapon/noPrimaryWeapon")
  local weaponTypeList = [ "cannons", "guns", "aam", "agm", "rockets", "turrets", "torpedoes",
    "bombs", "smoke", "flares" ]
  local consumableWeapons = [ "aam", "agm", "rockets", "torpedoes", "bombs", "smoke", "flares" ]
  local stackableWeapons = ["turrets"]
  foreach (index, weaponType in weaponTypeList)
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

          if (::isInArray(weaponType, consumableWeapons))
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
                  ::isInArray(unitType, [::ES_UNIT_TYPE_AIRCRAFT, ::ES_UNIT_TYPE_HELICOPTER])) // torpedoes drop for air only
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
                tText += getWeaponExtendedInfo(weapon, weaponType, air, p.ediff, p.newLine + ::nbsp + ::nbsp + ::nbsp + ::nbsp)
            }
          }
          else
          {
            if (isShortDesc)
              weapTypeCount += ("turrets" in trigger)? 0 : weapon.num
            else
            {
              tText += ::loc($"weapons/{weaponName}")
              if (weapon.num > 1)
                tText += ::format(::loc("weapons/counter"), weapon.num)

              if (weapon.ammo > 0)
                tText += " (" + ::loc("shop/ammo") + ::loc("ui/colon") + weapon.ammo + ")"

              if (!air.unitType.canUseSeveralBulletsForGun)
              {
                local rTime = ::get_reload_time_by_caliber(weapon.caliber, p.ediff)
                if (rTime)
                {
                  if (p.isLocalState)
                  {
                    local difficulty = ::get_difficulty_by_ediff(p.ediff ?? ::get_current_ediff())
                    local key = ::isCaliberCannon(weapon.caliber) ? "cannonReloadSpeedK" : "gunReloadSpeedK"
                    local speedK = air.modificators?[difficulty.crewSkillName]?[key] ?? 1.0
                    if (speedK)
                      rTime = stdMath.round_by_value(rTime / speedK, 1.0).tointeger()
                  }
                  tText += " " + ::loc("bullet_properties/cooldown") + " " + time.secondsToString(rTime, true, true)
                }
              }
            }
          }
        }

      if (isShortDesc)
        weapTypeCount += ("turrets" in trigger)? trigger.turrets : 0
      else
      {
        if ("turrets" in trigger) // && !air.unitType.canUseSeveralBulletsForGun)
        {
          if(trigger.turrets > 1)
            tText = ::format(::loc("weapons/turret_number"), trigger.turrets) + tText
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
    if (p.isPrimary)
      text = ::loc("weapon/noPrimaryWeapon")
    else
      text = (air.isAir() || air.isHelicopter()) ? ::loc("weapon/noSecondaryWeapon")
        : ::loc("weapon/noAdditionalWeapon")

  return text
}

local function getWeaponNameText(air, isPrimary = null, weaponPreset=-1, newLine=", ")
{
  return getWeaponInfoText(air,
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
  local primaryWeapon = ::get_last_primary_weapon(unit)
  local secondaryWeapon = getLastWeapon(unit.name)

  local primaryBlk = ::getCommonWeaponsBlk(unitBlk, primaryWeapon)
  local weaponTypes = {}
  if (primaryBlk)
    weaponTypes = addWeaponsFromBlk(weaponTypes, primaryBlk, unit)
  if (unitBlk?.weapon_presets)
    foreach (wp in (unitBlk.weapon_presets % "preset"))
      if (wp.name == secondaryWeapon)
      {
        local wpBlk = ::DataBlock(wp.blk)
        if (wpBlk)
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

// return short desc of air.weapons[weaponPresetNo], like M\C\B\T
local function getWeaponShortType(air, weaponPresetNo=0)
{
  if (typeof(air) == "string")
    air = ::getAircraftByName(air)

  if (!air)
    return ""

  local textArr = []
  if (air.weapons[weaponPresetNo].frontGun)
    textArr.append(::loc("weapons_types/short/guns"))
  if (air.weapons[weaponPresetNo].cannon)
    textArr.append(::loc("weapons_types/short/cannons"))
  if (air.weapons[weaponPresetNo].bomb)
    textArr.append(::loc("weapons_types/short/bombs"))
  if (air.weapons[weaponPresetNo].rocket)
    textArr.append(::loc("weapons_types/short/rockets"))
  if (air.weapons[weaponPresetNo].torpedo)
    textArr.append(::loc("weapons_types/short/torpedoes"))

  return ::loc("weapons_types/short/separator").join(textArr)
}

local function getWeaponShortTypeFromWpName(wpName, air = null)
{
  if (!wpName || typeof(wpName) != "string")
    return ""

  if (typeof(air) == "string")
    air = ::getAircraftByName(air)

  if (!air)
    return ""

  for (local i = 0; i < air.weapons.len(); ++i)
  {
    if (wpName == air.weapons[i].name)
      return getWeaponShortType(air, i)
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

local function getBulletsListHeader(unit, bulletsList)
{
  local locId = ""
  if (bulletsList.weaponType == WEAPON_TYPE.ROCKET)
    locId = "modification/_rockets"
  else if (::isInArray(bulletsList.weaponType, [ WEAPON_TYPE.AAM, WEAPON_TYPE.AGM ]))
    locId = "modification/_missiles"
  else if (bulletsList.weaponType == WEAPON_TYPE.FLARES)
    locId = "modification/_flares"
  else if (bulletsList.weaponType == WEAPON_TYPE.SMOKE_SCREEN)
    locId = "modification/_smoke_screen"
  else if (bulletsList.weaponType == WEAPON_TYPE.GUN)
  {
    if (unit.unitType.canUseSeveralBulletsForGun)
      locId = ::isCaliberCannon(bulletsList.caliber)? "modification/_tank_gun_pack" : "modification/_tank_minigun_pack"
    else
      locId = bulletsList.isTurretBelt ? "modification/_turret_belt_pack/short" : "modification/_belt_pack/short"
  }
  return ::format(::loc(locId), bulletsList.caliber.tostring())
}

return {
  getWeaponInfoText               = getWeaponInfoText
  getWeaponNameText               = getWeaponNameText
  getWeaponXrayDescText           = getWeaponXrayDescText
  getWeaponDescTextByTriggerGroup = getWeaponDescTextByTriggerGroup
  getWeaponShortTypeFromWpName    = getWeaponShortTypeFromWpName
  getDefaultBulletName            = getDefaultBulletName
  getBulletsListHeader            = getBulletsListHeader
}
