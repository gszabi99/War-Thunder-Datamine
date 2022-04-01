let { round_by_value } = require("%sqstd/math.nut")
let { secondsToString } = require("%scripts/time.nut")
let { countMeasure } = require("%scripts/options/optionsMeasureUnits.nut")
let { WEAPON_TYPE, TRIGGER_TYPE, CONSUMABLE_TYPES, WEAPON_TEXT_PARAMS, getLastWeapon,
  getUnitWeaponry, isCaliberCannon, addWeaponsFromBlk, getCommonWeapons, getLastPrimaryWeapon,
  getWeaponExtendedInfo
} = require("%scripts/weaponry/weaponryInfo.nut")
let { getBulletsSetData, getModificationName } = require("%scripts/weaponry/bulletsInfo.nut")
let { getModificationBulletsGroup } = require("%scripts/weaponry/modificationInfo.nut")
let { reloadCooldownTimeByCaliber } = require("%scripts/weaponry/weaponsParams.nut")
let { getPresetWeapons } = require("%scripts/weaponry/weaponryPresets.nut")


let function getReloadTimeByCaliber(caliber, ediff = null)
{
  let diff = ::get_difficulty_by_ediff(ediff ?? ::get_current_ediff())
  if (diff != ::g_difficulty.ARCADE)
    return null
  return reloadCooldownTimeByCaliber.value?[caliber]
}

let getTextNoWeapons = @(unit, isPrimary) isPrimary ? ::loc("weapon/noPrimaryWeapon")
  : (unit.isAir() || unit.isHelicopter()) ? ::loc("weapon/noSecondaryWeapon")
  : ::loc("weapon/noAdditionalWeapon")

local function getWeaponInfoText(unit, p = WEAPON_TEXT_PARAMS)
{
  local text = ""
  unit = typeof(unit) == "string" ? ::getAircraftByName(unit) : unit
  if (!unit)
    return text

  let weapons = getUnitWeaponry(unit, p)
  if (weapons == null)
    return text

  p = WEAPON_TEXT_PARAMS.__merge(p)
  let unitType = ::get_es_unit_type(unit)
  if (::u.isEmpty(weapons) && p.needTextWhenNoWeapons)
    text += getTextNoWeapons(unit, p.isPrimary)
  let stackableWeapons = [WEAPON_TYPE.TURRETS]
  foreach (index, weaponType in WEAPON_TYPE)
  {
    if (!(weaponType in weapons))
      continue

    let triggers = weapons[weaponType]
    triggers.sort(@(a, b) b.caliber <=> a.caliber)

    if (::isInArray(weaponType, stackableWeapons))
    {  //merge stackable in one
      for(local i=0; i<triggers.len(); i++)
      {
        triggers[i][weaponType] <- 1
        local sameIdx = -1
        for(local j=0; j<i; j++)
          if (triggers[i].weaponBlocks.len() == triggers[j].weaponBlocks.len())
          {
            local same = true
            foreach(wName, w in triggers[j].weaponBlocks)
              if ((wName not in triggers[i].weaponBlocks) || triggers[i].weaponBlocks[wName].num!=w.num)
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
          foreach(wName, w in triggers[i].weaponBlocks)
            triggers[sameIdx].weaponBlocks[wName].ammo += w.ammo
          triggers.remove(i)
          i--
        }
      }
    }

    let isShortDesc = p.detail <= INFO_DETAIL.SHORT //for weapons SHORT == LIMITED_11
    local weapTypeCount = 0 //for shortDesc only
    let gunNames = {}     //for shortDesc only
    foreach (trigger in triggers)
    {
      local tText = ""
      foreach (weaponName, weapon in trigger.weaponBlocks) {
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
                let speedKmph = countMeasure(0, [weapon.dropSpeedRange.x, weapon.dropSpeedRange.y])
                let speedMps  = countMeasure(3, [weapon.dropSpeedRange.x, weapon.dropSpeedRange.y])
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
          {
            if(!(TRIGGER_TYPE.TURRETS in trigger) && gunNames?[weaponName] == null)
              gunNames[weaponName] <- weapon.num
          }
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
                  let difficulty = ::get_difficulty_by_ediff(p.ediff ?? ::get_current_ediff())
                  let key = isCaliberCannon(weapon.caliber) ? "cannonReloadSpeedK" : "gunReloadSpeedK"
                  let speedK = unit.modificators?[difficulty.crewSkillName]?[key] ?? 1.0
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
    if (weapTypeCount == 0 && gunNames.len() == 0)
      continue

    text = text != "" ? "".concat(text, p.newLine) : ""
    if (isShortDesc)
    {
      if (weapTypeCount > 0)//Turrets
        text = "".concat(text, ::loc($"weapons_types/{weaponType}"), ::nbsp,
          ::format(::loc("weapons/counter/right/short"), weapTypeCount))
      if (gunNames.len() > 0)//Guns
      {
        let gunsTxt = []
        foreach(name, count in gunNames)
          gunsTxt.append("".concat(::loc($"weapons/{name}"), ::nbsp, count > 1
            ? ::format(::loc("weapons/counter/right/short"), count) : ""))
        text = $"{text} {(::loc("ui/comma")).join(gunsTxt)}"
      }
    }
    else
      text = "".concat(text, ::loc($"weapons_types/{weaponType}"),
        ::format(::loc("weapons/counter"), weapTypeCount))
  }

  if (text=="" && p.needTextWhenNoWeapons)
    text = getTextNoWeapons(unit, p.isPrimary)

  return text
}

let function getWeaponNameText(unit, isPrimary = null, weaponPreset=-1, newLine=", ")
{
  return getWeaponInfoText(unit,
    { isPrimary = isPrimary, weaponPreset = weaponPreset, newLine = newLine, detail = INFO_DETAIL.SHORT })
}


let function getWeaponXrayDescText(weaponBlk, unit, ediff)
{
  let weaponsArr = []
  ::u.appendOnce((::u.copy(weaponBlk)), weaponsArr)
  let weaponTypes = addWeaponsFromBlk({}, weaponsArr, unit)
  foreach (weaponType, weaponTypeList in weaponTypes)
    foreach (weapons in weaponTypeList)
      foreach (weapon in weapons.weaponBlocks)
        return getWeaponExtendedInfo(weapon, weaponType, unit, ediff, "\n")
  return ""
}


let function getWeaponDescTextByTriggerGroup(triggerGroup, unit, ediff)
{
  let unitBlk = ::get_full_unit_blk(unit.name)
  let primaryWeapon = getLastPrimaryWeapon(unit)
  let secondaryWeapon = getLastWeapon(unit.name)

  local weaponTypes = {}
  weaponTypes = addWeaponsFromBlk(weaponTypes, getCommonWeapons(unitBlk, primaryWeapon), unit)
  let curWeapon = unit.getWeapons().findvalue(@(w) w.name == secondaryWeapon)
  weaponTypes = addWeaponsFromBlk(weaponTypes, getPresetWeapons(unitBlk, curWeapon), unit)

  if (weaponTypes?[triggerGroup])
    foreach (weapons in weaponTypes[triggerGroup])
      foreach (weaponName, weapon in weapons.weaponBlocks)
        return "".concat(
          ::loc($"weapons/{weaponName}"),
          ::format(::loc("weapons/counter"), weapon.ammo),
          getWeaponExtendedInfo(weapon, triggerGroup, unit, ediff, "\n{0}{0}{0}{0}".subst(::nbsp))
        )
  return ""
}

// return short desc of unit.weapons[weaponPresetNo], like M\C\B\T
local function getWeaponShortType(unit, weapon)
{
  let textArr = []
  if (weapon.frontGun)
    textArr.append(::loc("weapons_types/short/guns"))
  if (weapon.cannon)
    textArr.append(::loc("weapons_types/short/cannons"))
  if (weapon.bomb)
    textArr.append(::loc("weapons_types/short/bombs"))
  if (weapon.rocket)
    textArr.append(::loc("weapons_types/short/rockets"))
  if (weapon.torpedo)
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

  foreach (weapon in unit.getWeapons())
  {
    if (wpName == weapon.name)
      return getWeaponShortType(unit, weapon)
  }

  return ""
}

let function getDefaultBulletName(unit)
{
  if (!("modifications" in unit))
    return ""

  let ignoreGroups = [null, ""]
  for (local modifNo = 0; modifNo < unit.modifications.len(); modifNo++)
  {
    let modif = unit.modifications[modifNo]
    let modifName = modif.name;

    let groupName = getModificationBulletsGroup(modifName);
    if (::isInArray(groupName, ignoreGroups))
      continue

    let bData = getBulletsSetData(unit, modifName)
    if (!bData || bData?.useDefaultBullet)
      return groupName + "_default"

    ignoreGroups.append(groupName)
  }
  return ""
}

let function getModItemName(unit, item, limitedName = true)
{
  return ::g_weaponry_types.getUpgradeTypeByItem(item).getLocName(unit, item, limitedName)
}

let function getReqModsText(unit, item)
{
  local reqText = ""
  foreach(rp in ["reqWeapon", "reqModification"])
      if (rp in item)
        foreach (req in item[rp])
          if (rp == "reqWeapon" && !::shop_is_weapon_purchased(unit.name, req))
            reqText += ((reqText=="")?"":"\n") + ::loc(rp) + ::loc("ui/colon") + getWeaponNameText(unit.name, false, req, ", ")
          else
          if (rp == "reqModification" && !::shop_is_modification_purchased(unit.name, req))
            reqText += ((reqText=="")?"":"\n") + ::loc(rp) + ::loc("ui/colon")
              + getModificationName(unit, req)
  return reqText
}

let function getBulletsListHeader(unit, bulletsList)
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
let function getFullItemCostText(unit, item, spawnScoreOnly = false)
{
  local res = ""
  let wType = ::g_weaponry_types.getUpgradeTypeByItem(item)
  let misRules = ::g_mis_custom_state.getCurMissionRules()

  if ((!::is_in_flight() || misRules.isWarpointsRespawnEnabled) && !spawnScoreOnly)
    res = wType.getCost(unit, item).tostring()

  if (::is_in_flight() && misRules.isScoreRespawnEnabled)
  {
    let scoreCostText = wType.getScoreCostText(unit, item)
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
  getWeaponShortTypeFromWpName
  getDefaultBulletName
  getModItemName
  getReqModsText
  getBulletsListHeader
  getFullItemCostText
}