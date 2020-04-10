local stdMath = require("std/math.nut")
local { WEAPON_TYPE,
        getLastWeapon } = require("scripts/weaponry/weaponryInfo.nut")
local { AMMO,
        getAmmoAmountData } = require("scripts/weaponry/ammoInfo.nut")

local bulletIcons = {}

local bulletsFeaturesImg = [
  { id = "damage", values = [] }
  { id = "armor",  values = [] }
]

local DEFAULT_PRIMARY_BULLETS_INFO = {
  guns                      = 1
  total                     = 0 //catridges total
  catridge                  = 1
  groupIndex                = -1
  forcedMaxBulletsInRespawn = false
}

local BULLETS_LIST_PARAMS = {
  isOnlyBought          = false
  needCheckUnitPurchase = true
  needOnlyAvailable     = true
  needTexts             = false
  isForcedAvailable     = false
}

local getBulletIcons = @() bulletIcons
local getBulletsFeaturesImg = @() bulletsFeaturesImg

const BULLETS_CALIBER_QUANTITY = 4

local function getModificationBulletsGroup(modifName)
{
  local blk = ::get_modifications_blk()
  local modification = blk?.modifications?[modifName]
  if (modification)
  {
    if (!modification?.group)
      return "" //new_gun etc. - not a bullets list
    if (modification?.effects)
      foreach (effectType, effect in modification.effects)
      {
        if (effectType == "additiveBulletMod")
        {
          local underscore = modification.group.indexof("_")
          if (underscore)
            return modification.group.slice(0, underscore)
        }
        if (effectType == "bulletMod" || effectType == "additiveBulletMod")
          return modification.group
      }
  }
  else if (modifName.len()>8 && modifName.slice(modifName.len()-8)=="_default")
    return modifName.slice(0, modifName.len()-8)

  return ""
}

local function isFakeBullet(modName)
{
  return ::g_string.startsWith(modName, ::fakeBullets_prefix)
}

local function setUnitLastBullets(unit, groupIndex, value)
{
  if (unit.unitType.canUseSeveralBulletsForGun)
    ::set_unit_option(unit.name, ::USEROPT_BULLETS0 + groupIndex, value)

  local saveValue = value
  local modif = ::getModificationByName(unit, value)
  if (!modif) //default modification
    saveValue = ""

  //if (bulletsValue != null && ::get_gui_options_mode() == ::OPTIONS_MODE_TRAINING)
  dagor.debug("set_last_bullets " + value)
  local curBullets = ::get_last_bullets(unit.name, groupIndex)
  if (curBullets != saveValue) {
    ::set_last_bullets(unit.name, groupIndex, saveValue)
    ::broadcastEvent("UnitBulletsChanged", { unit = unit,
      groupIdx = groupIndex, bulletName = value })
  }
}

local function getBulletsItemsList(unit, bulletsList, groupIndex)
{
  local itemsList = []
  local curBulletsName = ::get_last_bullets(unit.name, groupIndex)
  local isCurBulletsValid = false
  foreach(i, value in bulletsList.values)
  {
    local bItem = ::getModificationByName(unit, value)
    isCurBulletsValid = isCurBulletsValid || value == curBulletsName ||
      (!bItem && curBulletsName == "")
    if (!bItem) //default
      bItem = { name = value, isDefaultForGroup = groupIndex }
    itemsList.append(bItem)
  }
  if (!isCurBulletsValid)
    setUnitLastBullets(unit, groupIndex, itemsList[0].name)

  return itemsList
}

local function getBulletsSearchName(unit, modifName) //need for default bullets, which not exist as modifications
{
  if (!("modifications" in unit))
    return ""
  if (::getModificationByName(unit, modifName))
    return modifName  //not default modification

  local groupName = getModificationBulletsGroup(modifName)
  if (groupName!="")
    foreach(i, modif in unit.modifications)
      if (getModificationBulletsGroup(modif.name) == groupName)
        return modif.name
  return ""
}

local function getModificationBulletsEffect(modifName)
{
  local blk = ::get_modifications_blk()
  local modification = blk?.modifications?[modifName]
  if (modification?.effects)
  {
    foreach (effectType, effect in modification.effects)
    {
      if (effectType == "additiveBulletMod")
        return modification.effects.additiveBulletMod
      if (effectType == "bulletMod")
        return modification.effects.bulletMod
    }
  }
  return ""
}
//FIX ME: Needs to relocate to another module (weaponsInfo or modificationInfo)
local function getWeaponModIdx(weaponBlk, modsList) {
  return modsList.findindex(@(modName) weaponBlk?[getModificationBulletsEffect(modName)]) ?? -1
}
//FIX ME: Needs to relocate to another module (weaponsInfo or modificationInfo)
local function findIdenticalWeapon(weapon, weaponList, modsList) {
  if (weapon in weaponList)
    return weapon

  local weaponBlk = ::DataBlock(weapon)
  if (!weaponBlk)
    return null

  local cartridgeSize = weaponBlk?.bulletsCartridge || 1
  local groupIdx = getWeaponModIdx(weaponBlk, modsList)

  foreach(blkName, info in weaponList) {
    if (info.groupIndex == groupIdx
      && cartridgeSize == info.catridge)
      return blkName
  }

  return null
}

local function getBulletsSetData(air, modifName, noModList = null)
    //noModList!=null -> generate sets for fake bullets. return setsAmount
    //id of thoose sets = modifName + setNum + "_default"
{
  if ((modifName in air.bulletsSets) && !noModList)
    return air.bulletsSets[modifName] //all sets saved for no need analyze blk everytime when it need.

  local res = null
  local airBlk = ::get_full_unit_blk(air.name)
  if (!airBlk?.modifications)
    return res

  local searchName = ""
  local mod = null
  if (!noModList)
  {
    searchName = getBulletsSearchName(air, modifName)
    if (searchName=="")
      return res
    mod = ::getModificationByName(air, modifName)
  }

  local wpList = []
  local primaryList = ::getPrimaryWeaponsList(air)
  foreach(primaryMod in primaryList)
  {
    local primaryBlk = ::getCommonWeaponsBlk(airBlk, primaryMod)
    if (primaryBlk)
      foreach (weapon in (primaryBlk % "Weapon"))
        if (weapon?.blk && !weapon?.dummy && !::isInArray(weapon.blk, wpList))
          wpList.append(weapon.blk)
  }

  if (airBlk?.weapon_presets && !noModList) //not for fake bullets
    foreach (preset in (airBlk.weapon_presets % "preset"))
      if (preset?.blk)
      {
        local pBlk = ::DataBlock(preset.blk)
        if (!pBlk)
          continue

        foreach (weapon in (pBlk % "Weapon"))
          if (weapon?.blk && !weapon?.dummy && !::isInArray(weapon.blk, wpList))
            wpList.append(weapon.blk)
      }

  local bulSetForIconParam = null
  local fakeBulletsSets = []
  foreach (wBlkName in wpList)
  {
    local wBlk = ::DataBlock(wBlkName)
    if (!wBlk || (!wBlk?[getModificationBulletsEffect(searchName)] && !noModList))
      continue
    if (noModList)
    {
      local skip = false
      foreach(modName in noModList)
        if (wBlk?[getModificationBulletsEffect(modName)])
        {
          skip = true
          break
        }
      if (skip)
        continue
    }

    local bulletsModBlk = wBlk?[getModificationBulletsEffect(modifName)]
    local bulletsBlk = bulletsModBlk ? bulletsModBlk : wBlk
    local bulletsList = bulletsBlk % "bullet"
    local weaponType = WEAPON_TYPE.GUN
    if (!bulletsList.len())
    {
      bulletsList = bulletsBlk % "rocket"
      if (bulletsList.len())
      {
        local rocket = bulletsList[0]
        if (rocket?.smokeShell == true)
          weaponType = WEAPON_TYPE.SMOKE_SCREEN
        else if (rocket?.smokeShell == false)
           weaponType = WEAPON_TYPE.FLARES
        else if (rocket?.operated || rocket?.guidanceType)
          weaponType = (rocket?.bulletType == "atgm_tank") ? WEAPON_TYPE.AGM : WEAPON_TYPE.AAM
        else
          weaponType = WEAPON_TYPE.ROCKET
      }
    }

    local isBulletBelt = weaponType == WEAPON_TYPE.GUN &&
      (wBlk?.isBulletBelt != false ||
        ((wBlk?.bulletsCartridge ?? 0) > 1 && !wBlk?.useSingleIconForBullet))

    foreach (b in bulletsList)
    {
      local paramsBlk = ::u.isDataBlock(b?.rocket) ? b.rocket : b
      if (!res)
        if (paramsBlk?.caliber)
          res = { caliber = 1000.0 * paramsBlk.caliber,
                  bullets = [],
                  isBulletBelt = isBulletBelt
                  catridge = wBlk?.bulletsCartridge ?? 0
                  weaponType = weaponType
                  useDefaultBullet = !wBlk?.notUseDefaultBulletInGui,
                  weaponBlkName = wBlkName
                  maxToRespawn = mod?.maxToRespawn ?? 0
                }
        else
          continue

      local bulletType = b?.bulletType ?? b.getBlockName()
      if (paramsBlk?.selfDestructionInAir)
        bulletType += "@s_d"
      res.bullets.append(bulletType)

      if (paramsBlk?.guiCustomIcon != null)
      {
        if (res?.customIconsMap == null)
          res.customIconsMap <- {}
        res.customIconsMap[bulletType] <- paramsBlk.guiCustomIcon
      }

      if ("bulletName" in b)
      {
        if (!("bulletNames" in res))
          res.bulletNames <- []
        res.bulletNames.append(b.bulletName)
      }

      foreach(param in ["explosiveType", "explosiveMass"])
        if (param in paramsBlk)
          res[param] <- paramsBlk[param]

      foreach(param in ["smokeShellRad", "smokeActivateTime", "smokeTime"])
        if (param in paramsBlk)
          res[param] <- paramsBlk[param]

      if (paramsBlk?.proximityFuse)
      {
        res.proximityFuseArmDistance <- paramsBlk.proximityFuse?.armDistance ?? 0
        res.proximityFuseRadius      <- paramsBlk.proximityFuse?.radius ?? 0
      }
    }

    if (res)
    {
      if (noModList)
      {
        if (!bulSetForIconParam && !noModList.len()
            && !res.isBulletBelt) //really first default bullet set. can have default icon params
          bulSetForIconParam = res
        fakeBulletsSets.append(res)
        res = null
      }
      else
      {
        bulSetForIconParam = res
        break
      }
    }
  }

  if (bulSetForIconParam)
  {
    local bIconParam = 0
    if (searchName == modifName) //not default bullet
      bIconParam = ::getTblValue("bulletsIconParam", mod, 0)
    else
      bIconParam = ::getTblValue("bulletsIconParam", air, 0)
    if (bIconParam)
      bulSetForIconParam.bIconParam <- {
        armor = bIconParam % 10 - 1
        damage = (bIconParam / 10).tointeger() - 1
      }
  }

  //res = { caliber = 0.00762, bullets = ["he_i", "i_t", "he_frag@s_d", "aphe"]}
  if (!noModList)
    air.bulletsSets[modifName] <- res
  else
  {
    fakeBulletsSets.sort(function(a, b) {
      if (a.caliber != b.caliber)
        return a.caliber > b.caliber ? -1 : 1
      return 0
    })
    for(local i = 0; i < fakeBulletsSets.len(); i++)
      air.bulletsSets[modifName + i + "_default"] <- fakeBulletsSets[i]
  }

  return noModList? fakeBulletsSets.len() : res
}

local function getBulletsModListByGroups(air)
{
  local modList = []
  local groups = []

  if ("modifications" in air)
    foreach(m in air.modifications)
    {
      local groupName = getModificationBulletsGroup(m.name)
      if (groupName!="" && !::isInArray(groupName, groups))
      {
        groups.append(groupName)
        modList.append(m.name)
      }
    }
  return modList
}

local function getActiveBulletsIntByWeaponsBlk(air, weaponsBlk, weaponToFakeBulletMask)
{
  local res = 0
  local wpList = []
  if (weaponsBlk)
    foreach (weapon in (weaponsBlk % "Weapon"))
      if (weapon?.blk && !weapon?.dummy && !::isInArray(weapon.blk, wpList))
        wpList.append(weapon.blk)

  if (wpList.len())
  {
    local modsList = getBulletsModListByGroups(air)
    foreach (wBlkName in wpList)
    {
      if (wBlkName in weaponToFakeBulletMask)
      {
        res = res | weaponToFakeBulletMask[wBlkName]
        continue
      }

      local wBlk = ::DataBlock(wBlkName)
      if (!wBlk)
        continue

      foreach(idx, modName in modsList)
        if (wBlk?[getModificationBulletsEffect(modName)])
        {
          res = stdMath.change_bit(res, idx, 1)
          break
        }
    }
  }
  return res
}

local function getBulletsGroupCount(air, full = false)
{
  if (!air)
    return 0
  if (air.bulGroups < 0)
  {
    local modList = []
    local groups = []

    foreach(m in air.modifications)
    {
      local groupName = getModificationBulletsGroup(m.name)
      if (groupName!="")
      {
        if (!::isInArray(groupName, groups))
          groups.append(groupName)
        modList.append(m.name)
      }
    }
    air.bulModsGroups = groups.len()
    air.bulGroups     = groups.len()

    local bulletSetsQuantity = air.unitType.bulletSetsQuantity
    if (air.bulGroups < bulletSetsQuantity)
    {
      local add = getBulletsSetData(air, ::fakeBullets_prefix, modList) || 0
      air.bulGroups = ::min(air.bulGroups + add, bulletSetsQuantity)
    }
  }
  return full? air.bulGroups : air.bulModsGroups
}

local function getBulletsInfoForPrimaryGuns(air)
{
  if (air.primaryBulletsInfo)
    return air.primaryBulletsInfo

  local res = []
  air.primaryBulletsInfo = res
  if (!air.unitType.canUseSeveralBulletsForGun)
    return res

  local airBlk = ::get_full_unit_blk(air.name)
  if (!airBlk)
    return res

  local commonWeaponBlk = ::getCommonWeaponsBlk(airBlk, "")
  if (!commonWeaponBlk)
    return res

  local modsList = getBulletsModListByGroups(air)
  local wpList = {} // name = amount
  foreach (weapon in (commonWeaponBlk % "Weapon"))
    if (weapon?.blk && !weapon?.dummy) {
      local weapName = findIdenticalWeapon(weapon.blk, wpList, modsList)
      if (weapName) {
        wpList[weapName].guns++
      } else {
        wpList[weapon.blk] <- clone DEFAULT_PRIMARY_BULLETS_INFO
        if (!("bullets" in weapon))
          continue

        wpList[weapon.blk].total = weapon?.bullets ?? 0
        local wBlk = ::DataBlock(weapon.blk)
        if (!wBlk)
          continue

        wpList[weapon.blk].catridge = wBlk?.bulletsCartridge || 1
        local totalBullets = wpList[weapon.blk].total
        wpList[weapon.blk].total = (wpList[weapon.blk].total /
          wpList[weapon.blk].catridge).tointeger()
        if (wpList[weapon.blk].total * wpList[weapon.blk].catridge < totalBullets)
          wpList[weapon.blk].total += 1

        wpList[weapon.blk].groupIndex = getWeaponModIdx(wBlk, modsList)
        wpList[weapon.blk].forcedMaxBulletsInRespawn = wBlk?.forcedMaxBulletsInRespawn ?? false
      }
    }

  foreach(idx, modName in modsList)
  {
    local bInfo = null
    foreach(blkName, info in wpList)
      if (info.groupIndex == idx)
      {
        bInfo = info
        break
      }
    res.append(bInfo || (clone DEFAULT_PRIMARY_BULLETS_INFO))
  }
  return res
}

local function getBulletsInfoForGun(unit, gunIdx)
{
  local bulletsInfo = getBulletsInfoForPrimaryGuns(unit)
  return ::getTblValue(gunIdx, bulletsInfo)
}

local function canBulletsBeDuplicate(unit)
{
  return unit.unitType.canUseSeveralBulletsForGun
}

local function getLastFakeBulletsIndex(unit)
{
  if (!canBulletsBeDuplicate(unit))
    return getBulletsGroupCount(unit, true)
  return BULLETS_CALIBER_QUANTITY - getBulletsGroupCount(unit, false) +
    getBulletsGroupCount(unit, true)
}

local function getFakeBulletName(bulletIdx)
{
  return ::fakeBullets_prefix + bulletIdx + "_default"
}
//FIX ME: Needs to relocate to visual module
local function getUniqModificationText(unit, modifName, isShortDesc)
{
  if (modifName == "premExpMul")
  {
    local value = ::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText(::get_premExpMul_add_value(unit), false)
    local ending = isShortDesc? "" : "/desc"
    return ::loc("modification/" + modifName + ending, "", { value = value })
  }
  return null
}
//FIX ME: Needs to relocate to visual module
// Generate text description for air.modifications[modificationNo]
local function getModificationInfo(air, modifName, isShortDesc=false, limitedName = false,
                                 obj = null, itemDescrRewriteFunc = null)
{
  local res = {desc = "", delayed = false}
  if (typeof(air) == "string")
    air = getAircraftByName(air)
  if (!air)
    return res

  local uniqText = getUniqModificationText(air, modifName, isShortDesc)
  if (uniqText)
  {
    res.desc = uniqText
    return res
  }

  local mod = ::getModificationByName(air, modifName)

  local ammo_pack_len = 0
  if (modifName.indexof("_ammo_pack") != null && mod)
  {
    ::updateRelationModificationList(air, modifName);
    if ("relationModification" in mod && mod.relationModification.len() > 0)
    {
      modifName = mod.relationModification[0];
      ammo_pack_len = mod.relationModification.len()
      mod = ::getModificationByName(air, modifName)
    }
  }

  local groupName = getModificationBulletsGroup(modifName)
  if (groupName=="") //not bullets
  {
    if (!isShortDesc && itemDescrRewriteFunc)
      res.delayed = ::calculate_mod_or_weapon_effect(air.name, modifName, true, obj, itemDescrRewriteFunc, null) ?? true

    local locId = modifName
    local ending = isShortDesc? (limitedName? "/short" : "") : "/desc"

    res.desc = ::loc("modification/" + locId + ending, "")
    if (res.desc == "" && isShortDesc && limitedName)
      res.desc = ::loc("modification/" + locId, "")

    if (res.desc == "")
    {
      local caliber = 0.0
      foreach(n in ::modifications_locId_by_caliber)
        if (locId.len() > n.len() && locId.slice(locId.len()-n.len()) == n)
        {
          locId = n
          caliber = ("caliber" in mod)? mod.caliber : 0.0
          if (limitedName)
            caliber = caliber.tointeger()
          break
        }

      locId = "modification/" + locId
      if (::isCaliberCannon(caliber))
        res.desc = ::locEnding(locId + "/cannon", ending, "")
      if (res.desc=="")
        res.desc = ::locEnding(locId, ending)
      if (caliber > 0)
        res.desc = ::format(res.desc, caliber.tostring())
    }
    return res //without effects atm
  }

  //bullets sets
  local set = getBulletsSetData(air, modifName)

  if (isShortDesc && !mod && set?.weaponType == WEAPON_TYPE.GUN && !air.unitType.canUseSeveralBulletsForGun)
  {
    res.desc = ::loc("modification/default_bullets")
    return res
  }

  if (!set)
  {
    if (res.desc == "")
      res.desc = modifName + " not found bullets"
    return res
  }

  local shortDescr = "";
  if (isShortDesc || ammo_pack_len) //bullets name
  {
    local locId = modifName
    local caliber = limitedName? set.caliber.tointeger() : set.caliber
    foreach(n in ::bullets_locId_by_caliber)
      if (locId.len() > n.len() && locId.slice(locId.len()-n.len()) == n)
      {
        locId = n
        break
      }
    if (limitedName)
      shortDescr = ::loc(locId + "/name/short", "")
    if (shortDescr == "")
      shortDescr = ::loc(locId + "/name")
    if (set?.bulletNames?[0]
      && (set.weaponType != WEAPON_TYPE.GUN || !set.isBulletBelt ||
      (::isCaliberCannon(caliber) && air.unitType.canUseSeveralBulletsForGun)))
    {
      locId = set.bulletNames[0]
      shortDescr = ::loc(locId, ::loc("weapons/" + locId + "/short", locId))
    }
    if (!mod && air.unitType.canUseSeveralBulletsForGun && set.isBulletBelt)
      shortDescr = ::loc("modification/default_bullets")
    shortDescr = format(shortDescr, caliber.tostring())
  }
  if (isShortDesc)
  {
    res.desc = shortDescr
    return res
  }

  if (ammo_pack_len)
  {
    if ("bulletNames" in set && typeof(set.bulletNames) == "array" && set.bulletNames.len())
      shortDescr = format(::loc(set.isBulletBelt ? "modification/ammo_pack_belt/desc" : "modification/ammo_pack/desc"), shortDescr)
    if (ammo_pack_len > 1)
    {
      res.desc = shortDescr
      return res
    }
  }

  //bullets description
  local annotation = ""
  local usedLocs = []
  local infoFunc = function(name, addName=null) {
    local txt = ::loc(name + "/name/short")
    if (addName) txt += ::loc(addName + "/name/short")
    txt += " - " + ::loc(name + "/name")
    if (addName) txt += " " + ::loc(addName + "/name")
    return txt
  }
  local separator = ::loc("bullet_type_separator/name")
  local setText = ""
  foreach(b in set.bullets)
  {
    setText += ((setText=="")? "" : separator)
    local part = b.indexof("@")
    if (part==null)
      setText+=::loc(b + "/name/short")
    else
      setText+=::loc(b.slice(0, part) + "/name/short") + ::loc(b.slice(part+1) + "/name/short")
    if (!::isInArray(b, usedLocs))
    {
      if (annotation != "")
        annotation += "\n"
      if (part==null)
        annotation += infoFunc(b)
      else
        annotation += infoFunc(b.slice(0, part), b.slice(part+1))
      usedLocs.append(b)
    }
  }

  if (ammo_pack_len)
    res.desc = shortDescr + "\n"
  if (set.bullets.len() > 1)
    res.desc += format(::loc("caliber_" + set.caliber + "/desc"), setText) + "\n\n"
  res.desc += annotation
  return res
}
//FIX ME: Needs to relocate to visual module
local function getModificationName(air, modifName, limitedName = false)
{
  return getModificationInfo(air, modifName, true, limitedName).desc
}
//**
local function appendOneBulletsItem(descr, modifName, air, amountText, genTexts, enabled = true)
{
  local item =  { enabled = enabled }
  descr.items.append(item)
  descr.values.append(modifName)

  if (!genTexts)
    return

  item.text    <- ::g_string.implode([ amountText, getModificationName(air, modifName) ], " ")
  item.tooltip <- ::g_string.implode([ amountText, getModificationInfo(air, modifName).desc ], " ")
}

local function getBulletsList(airName, groupIdx, params = BULLETS_LIST_PARAMS)
{
  params = BULLETS_LIST_PARAMS.__merge(params)
  local descr = {
    values = []
    isTurretBelt = false
    weaponType = WEAPON_TYPE.GUN
    caliber = 0
    duplicate = false //tank gun bullets can be duplicate to change bullets during the battle

    //only when genText
    items = []
  }
  local air = ::getAircraftByName(airName)
  if (!air || !("modifications" in air))
    return descr

  local canBeDuplicate = canBulletsBeDuplicate(air)
  local groupCount = getBulletsGroupCount(air, true)
  if (groupCount <= groupIdx && !canBeDuplicate)
    return descr

  local modTotal = getBulletsGroupCount(air, false)
  local bulletSetsQuantity = air.unitType.bulletSetsQuantity
  local firstFakeIdx = canBeDuplicate? bulletSetsQuantity : modTotal
  if (firstFakeIdx <= groupIdx)
  {
    local fakeIdx = groupIdx - firstFakeIdx
    local modifName = getFakeBulletName(fakeIdx)
    local bData = getBulletsSetData(air, modifName)
    if (bData)
    {
      descr.caliber = bData.caliber
      descr.weaponType = bData.weaponType
    }

    appendOneBulletsItem(descr, modifName, air, "", params.needTexts) //fake default bullet item
    return descr
  }

  local linked_index = ::get_linked_gun_index(groupIdx, modTotal, bulletSetsQuantity, canBeDuplicate)
  descr.duplicate = canBeDuplicate && groupIdx > 0 &&
    linked_index == ::get_linked_gun_index(groupIdx - 1, modTotal, bulletSetsQuantity, canBeDuplicate)

  local groups = []
  for (local modifNo = 0; modifNo < air.modifications.len(); modifNo++)
  {
    local modif = air.modifications[modifNo]
    local modifName = modif.name;

    local groupName = getModificationBulletsGroup(modifName)
    if (!groupName || groupName == "")
      continue;

    //get group index
    local currentGroup = ::find_in_array(groups, groupName)
    if (currentGroup == -1)
    {
      currentGroup = groups.len()
      groups.append(groupName)
    }
    if (currentGroup != linked_index)
      continue;

    if (descr.values.len()==0)
    {
      local bData = getBulletsSetData(air, modifName)
      if (!bData || bData.useDefaultBullet)
        appendOneBulletsItem(descr, groupName + "_default", air, "", params.needTexts) //default bullets
      if ("isTurretBelt" in modif)
        descr.isTurretBelt = modif.isTurretBelt
      if (bData)
      {
        descr.caliber = bData.caliber
        descr.weaponType = bData.weaponType
      }
    }

    if (params.needOnlyAvailable && !params.isForcedAvailable
        && !::is_mod_available_or_free(airName, modifName))
      continue

    local enabled = !params.isOnlyBought ||
      ::shop_is_modification_purchased(airName, modifName) != 0
    local amountText = params.needCheckUnitPurchase && ::is_game_mode_with_spendable_weapons() ?
      getAmmoAmountData(air, modifName, AMMO.MODIFICATION).text : ""

    appendOneBulletsItem(descr, modifName, air, amountText, params.needTexts, enabled)
  }
  return descr
}

local function getActiveBulletsGroupIntForDuplicates(unit, checkPurchased = true)
{
  local res = 0
  local groupsCount = getBulletsGroupCount(unit, false)
  local lastLinkedIdx = -1
  local duplicates = 0
  local lastIdxTotal = 0
  local maxCatridges = 0
  local bulletSetsQuantity = unit.unitType.bulletSetsQuantity
  for (local i = 0; i < bulletSetsQuantity; i++) {
    local linkedIdx = ::get_linked_gun_index(i, groupsCount, bulletSetsQuantity)
    if (linkedIdx == lastLinkedIdx) {
      duplicates++
    } else {
      local bullets = getBulletsList(unit.name, i, {
        isOnlyBought = checkPurchased, needCheckUnitPurchase = checkPurchased
      })
      lastIdxTotal = bullets.values.len()
      lastLinkedIdx = linkedIdx
      duplicates = 0

      local bInfo = getBulletsInfoForGun(unit, linkedIdx)
      maxCatridges = ::getTblValue("total", bInfo, 0)
    }

    if (lastIdxTotal > duplicates && duplicates < maxCatridges)
      res = res | (1 << i)
  }
  return res
}

local function getBulletGroupIndex(airName, bulletName)
{
  local group = -1
  local groupName = getModificationBulletsGroup(bulletName)
  if (!groupName || groupName == "")
    return -1

  local unit = ::getAircraftByName(airName)
  if (unit == null)
    return -1

  for (local groupIndex = 0; groupIndex < unit.unitType.bulletSetsQuantity; groupIndex++)
  {
    local bulletsList = getBulletsList(airName, groupIndex, {
      needCheckUnitPurchase = false, needOnlyAvailable = false })

    if (::find_in_array(bulletsList.values, bulletName) >= 0)
    {
      group = groupIndex
      break
    }
  }

  return group
}

local function getActiveBulletsGroupInt(air, checkPurchased = true)
{
  local primaryWeapon = ::get_last_primary_weapon(air)
  local secondaryWeapon = getLastWeapon(air.name)
  if (!(primaryWeapon in air.primaryBullets) || !(secondaryWeapon in air.secondaryBullets))
  {
    local weaponToFakeBulletMask = {}
    local lastFakeIdx = getLastFakeBulletsIndex(air)
    local total = getBulletsGroupCount(air, true) - getBulletsGroupCount(air, false)
    local fakeBulletsOffset = lastFakeIdx - total
    for(local i = 0; i < total; i++)
    {
      local bulSet = getBulletsSetData(air, getFakeBulletName(i))
      if (bulSet)
        weaponToFakeBulletMask[bulSet.weaponBlkName] <- 1 << (fakeBulletsOffset + i)
    }

    if (!(primaryWeapon in air.primaryBullets))
    {
      local primary = 0
      local primaryList = ::getPrimaryWeaponsList(air)
      if (primaryList.len() > 0)
      {
        local airBlk = ::get_full_unit_blk(air.name)
        if (airBlk)
        {
          local primaryBlk = ::getCommonWeaponsBlk(airBlk, primaryWeapon)
          primary = getActiveBulletsIntByWeaponsBlk(air, primaryBlk, weaponToFakeBulletMask)
        }
      }
      air.primaryBullets[primaryWeapon] <- primary
    }

    if (!(secondaryWeapon in air.secondaryBullets))
    {
      local secondary = 0
      local airBlk = ::get_full_unit_blk(air.name)
      if (airBlk?.weapon_presets)
        foreach (wp in (airBlk.weapon_presets % "preset"))
          if (wp.name == secondaryWeapon)
          {
            local wpBlk = ::DataBlock(wp.blk)
            if (wpBlk)
              secondary = getActiveBulletsIntByWeaponsBlk(air, wpBlk, weaponToFakeBulletMask)
          }
      air.secondaryBullets[secondaryWeapon] <- secondary
    }
  }

  local res = air.primaryBullets[primaryWeapon] | air.secondaryBullets[secondaryWeapon]
  if (canBulletsBeDuplicate(air))
  {
    res = res & ~((1 << air.unitType.bulletSetsQuantity) - 1) //use only fake bullets mask
    res = res | getActiveBulletsGroupIntForDuplicates(air, checkPurchased)
  }
  return res
}

local function isBulletGroupActive(air, group)
{
  local groupsActive = getActiveBulletsGroupInt(air)
  return (groupsActive & (1 << group)) != 0
}

local function isBulletsGroupActiveByMod(air, mod)
{
  local groupIdx = ::getTblValue("isDefaultForGroup", mod, -1)
  if (groupIdx < 0)
    groupIdx = getBulletGroupIndex(air.name, mod.name)
  return isBulletGroupActive(air, groupIdx)
}

//to get exact same bullets list as in standart options
local function getOptionsBulletsList(air, groupIndex, needTexts = false, isForcedAvailable = false)
{
  local checkPurchased = ::get_gui_options_mode() != ::OPTIONS_MODE_TRAINING
  local res = getBulletsList(air.name, groupIndex, {
    isOnlyBought = checkPurchased
    needCheckUnitPurchase = checkPurchased
    needTexts = needTexts
    isForcedAvailable = isForcedAvailable
  }) //only_bought=true

  local curModif = air.unitType.canUseSeveralBulletsForGun ?
    ::get_unit_option(air.name, ::USEROPT_BULLETS0 + groupIndex) :
    ::get_last_bullets(air.name, groupIndex)
  local value = curModif? ::find_in_array(res.values, curModif) : -1

  if (value < 0 || !res.items[value].enabled)
  {
    value = 0
    local canBeDuplicate = canBulletsBeDuplicate(air)
    local skipIndex = canBeDuplicate ? groupIndex : 0
    for(local i = 0; i < res.items.len(); i++)
      if (res.items[i].enabled)
      {
        value = i
        if (--skipIndex < 0)
          break
      }
  }

  res.value <- value
  return res
}

local function initBulletIcons(blk = null)
{
  if (bulletIcons.len())
    return

  if (!blk)
    blk = ::configs.GUI.get()

  local ib = blk?.bullet_icons
  if (ib)
    foreach(key, value in ib)
      bulletIcons[key] <- value

  local bf = blk?.bullets_features_icons
  if (bf)
    foreach(item in bulletsFeaturesImg)
      item.values = bf % item.id
}

return {
  getModificationBulletsGroup           = getModificationBulletsGroup
  isFakeBullet                          = isFakeBullet
  setUnitLastBullets                    = setUnitLastBullets
  getBulletsItemsList                   = getBulletsItemsList
  getBulletsSearchName                  = getBulletsSearchName
  getModificationBulletsEffect          = getModificationBulletsEffect
  getBulletsSetData                     = getBulletsSetData
  getBulletsGroupCount                  = getBulletsGroupCount
  getBulletsInfoForPrimaryGuns          = getBulletsInfoForPrimaryGuns
  getLastFakeBulletsIndex               = getLastFakeBulletsIndex
  getBulletsList                        = getBulletsList
  getBulletGroupIndex                   = getBulletGroupIndex
  getActiveBulletsGroupInt              = getActiveBulletsGroupInt
  isBulletGroupActive                   = isBulletGroupActive
  isBulletsGroupActiveByMod             = isBulletsGroupActiveByMod
  getOptionsBulletsList                 = getOptionsBulletsList
  initBulletIcons                       = initBulletIcons
  getModificationInfo                   = getModificationInfo
  getModificationName                   = getModificationName
  getBulletIcons                        = getBulletIcons
  getBulletsFeaturesImg                 = getBulletsFeaturesImg
}