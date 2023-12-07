//-file:plus-string
from "%scripts/dagui_library.nut" import *
from "%scripts/weaponry/weaponryConsts.nut" import weaponsItem

let u = require("%sqStdLibs/helpers/u.nut")
let { format } = require("string")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { blkFromPath, eachParam, copyParamsToTable } = require("%sqstd/datablock.nut")
let { ceil, change_bit } = require("%sqstd/math.nut")
let { WEAPON_TYPE, getLastWeapon, isCaliberCannon, getLinkedGunIdx, getCommonWeapons,
  getLastPrimaryWeapon, getPrimaryWeaponsList } = require("%scripts/weaponry/weaponryInfo.nut")
let { AMMO, getAmmoAmountData } = require("%scripts/weaponry/ammoInfo.nut")
let { isModResearched, isModAvailableOrFree, getModificationByName,
  updateRelationModificationList, getModificationBulletsGroup
} = require("%scripts/weaponry/modificationInfo.nut")
let { isModificationInTree } = require("%scripts/weaponry/modsTree.nut")
let { getGuiOptionsMode, set_unit_option } = require("guiOptions")
let { getSavedBullets } = require("%scripts/weaponry/savedWeaponry.nut")
let { unique } = require("%sqstd/underscore.nut")
let { getPresetWeapons, getUnitWeapons } = require("%scripts/weaponry/weaponryPresets.nut")
let { appendOnce } = u
let DataBlock = require("DataBlock")
let { set_last_bullets } = require("unitCustomization")
let { startsWith, slice } = require("%sqstd/string.nut")
let { OPTIONS_MODE_TRAINING, USEROPT_BULLETS0
} = require("%scripts/options/optionsExtNames.nut")
let { shopIsModificationPurchased } = require("chardResearch")
let { get_ranks_blk, get_modifications_blk } = require("blkGetters")

let BULLET_TYPE = {
  ROCKET_AIR          = "rocket_aircraft"
  AAM                 = "aam"
  TORPEDO             = "torpedo"
  ATGM_TANK           = "atgm_tank"
  AP_TANK             = "ap_tank"
  ATGM_TANDEM_TANK    = "atgm_tandem_tank"
}

let DEFAULT_PRIMARY_BULLETS_INFO = {
  guns                      = 1
  total                     = 0 //cartridges total
  cartridge                 = 1
  groupIndex                = -1
  forcedMaxBulletsInRespawn = false
}

let BULLETS_LIST_PARAMS = {
  isOnlyBought          = false
  needCheckUnitPurchase = true
  needOnlyAvailable     = true
  needTexts             = false
  isForcedAvailable     = false
}

const BULLETS_CALIBER_QUANTITY = 4
//



















let function isBullets(item) {
  return (("isDefaultForGroup" in item) && (item.isDefaultForGroup >= 0))
    || (item.type == weaponsItem.modification && getModificationBulletsGroup(item.name) != "")
}

let function isWeaponTierAvailable(unit, tierNum) {
  local isAvailable = ::is_tier_available(unit.name, tierNum)

  if (!isAvailable && tierNum > 1) { //make force check
    local reqMods = unit.needBuyToOpenNextInTier[tierNum - 2]
    foreach (mod in unit.modifications)
      if (mod.tier == (tierNum - 1)
        && isModificationInTree(unit, mod)
        && isModResearched(unit, mod)
      )
        reqMods--

    isAvailable = reqMods <= 0
  }

  return isAvailable
}

let function isFakeBullet(modName) {
  return startsWith(modName, ::fakeBullets_prefix)
}

let function setUnitLastBullets(unit, groupIndex, value) {
  let saveValue = getModificationByName(unit, value) ? value : "" //'' = default modification
  let curBullets = getSavedBullets(unit.name, groupIndex)
  if (curBullets != saveValue) {
    set_unit_option(unit.name, USEROPT_BULLETS0 + groupIndex, saveValue)
    log($"Bullets Info: {unit.name}: bullet {groupIndex}: Set unit last bullets: change from '{curBullets}' to '{saveValue}'")
    set_last_bullets(unit.name, groupIndex, saveValue)
    broadcastEvent("UnitBulletsChanged", { unit = unit,
      groupIdx = groupIndex, bulletName = value })
  }
}

let function getBulletsItemsList(unit, bulletsList, groupIndex) {
  let itemsList = []
  let curBulletsName = getSavedBullets(unit.name, groupIndex)
  local isCurBulletsValid = groupIndex >= unit.unitType.bulletSetsQuantity
  foreach (_i, value in bulletsList.values) {
    local bItem = getModificationByName(unit, value)
    isCurBulletsValid = isCurBulletsValid || value == curBulletsName
      || (!bItem && curBulletsName == "")
    if (!bItem) //default
      bItem = { name = value, isDefaultForGroup = groupIndex }
    itemsList.append(bItem)
  }
  if (!isCurBulletsValid)
    setUnitLastBullets(unit, groupIndex, itemsList[0].name)

  return itemsList
}

let function getBulletsSearchName(unit, modifName) { //need for default bullets, which not exist as modifications
  if (!("modifications" in unit))
    return ""
  if (getModificationByName(unit, modifName))
    return modifName  //not default modification

  let groupName = getModificationBulletsGroup(modifName)
  if (groupName != "")
    foreach (_i, modif in unit.modifications)
      if (getModificationBulletsGroup(modif.name) == groupName)
        return modif.name
  return ""
}

let function getModificationBulletsEffect(modifName) {
  let blk = get_modifications_blk()
  let modification = blk?.modifications?[modifName]
  if (modification?.effects) {
    for (local i = 0; i < modification.effects.paramCount(); i++) {
      let effectType = modification.effects.getParamName(i)
      if (effectType == "additiveBulletMod")
        return modification.effects.additiveBulletMod
      if (effectType == "bulletMod")
        return modification.effects.bulletMod
    }
  }
  return ""
}

let function getBulletsSetData(air, modifName, noModList = null) {
    //noModList!=null -> generate sets for fake bullets. return setsAmount
    //id of thoose sets = modifName + setNum + "_default"
  if ((modifName in air.bulletsSets) && !noModList)
    return air.bulletsSets[modifName] //all sets saved for no need analyze blk everytime when it need.

  local res = null
  let airBlk = ::get_full_unit_blk(air.name)
  if (!airBlk?.modifications)
    return res

  local searchName = ""
  local mod = null
  if (!noModList) {
    searchName = getBulletsSearchName(air, modifName)
    if (searchName == "")
      return res
    mod = getModificationByName(air, modifName)
  }

  let wpList = []
  let triggerList = []
  let primaryList = getPrimaryWeaponsList(air)
  foreach (primaryMod in primaryList)
    foreach (weapon in getCommonWeapons(airBlk, primaryMod))
      if (weapon?.blk && !weapon?.dummy && !isInArray(weapon.blk, wpList)) {
        wpList.append(weapon.blk)
        triggerList.append(weapon.trigger)
      }

  if (!noModList) { //not for fake bullets
    let weapons = getUnitWeapons(airBlk)
    foreach (weapon in weapons)
      if (weapon?.blk && !weapon?.dummy && !isInArray(weapon.blk, wpList)) {
        wpList.append(weapon.blk)
        triggerList.append(weapon.trigger)
      }
  }

  local bulSetForIconParam = null
  let fakeBulletsSets = []
  local index = -1
  foreach (wBlkName in wpList) {
    index++
    let wBlk = blkFromPath(wBlkName)
    if (u.isEmpty(wBlk) || (!wBlk?[getModificationBulletsEffect(searchName)] && !noModList))
      continue
    if (noModList) {
      local skip = false
      foreach (modName in noModList)
        if (wBlk?[getModificationBulletsEffect(modName)]) {
          skip = true
          break
        }
      if (skip)
        continue
    }

    let bulletsModBlk = wBlk?[getModificationBulletsEffect(modifName)]
    let bulletsBlk = bulletsModBlk ? bulletsModBlk : wBlk
    local bulletsList = bulletsBlk % "bullet"
    local weaponType = triggerList[index] == "countermeasures"
      ? WEAPON_TYPE.COUNTERMEASURES : WEAPON_TYPE.GUNS
    if (!bulletsList.len()) {
      bulletsList = bulletsBlk % "rocket"
      if (bulletsList.len()) {
        let rocket = bulletsList[0]
        if (rocket?.smokeShell == true)
          weaponType = WEAPON_TYPE.SMOKE
        else if ((rocket?.isFlare == true) || (rocket?.isChaff == true))
            weaponType = WEAPON_TYPE.COUNTERMEASURES
        else if (rocket?.smokeShell == false)
           weaponType = WEAPON_TYPE.FLARES
        else if (rocket?.operated || rocket?.guidanceType)
          weaponType = (rocket?.bulletType == BULLET_TYPE.ATGM_TANK)
            ? WEAPON_TYPE.AGM : WEAPON_TYPE.AAM
        else
          weaponType = WEAPON_TYPE.ROCKETS
      }
    }

    let isBulletBelt = (weaponType == WEAPON_TYPE.GUNS || weaponType == WEAPON_TYPE.COUNTERMEASURES)
      && ((wBlk?.isBulletBelt != false || (wBlk?.bulletsCartridge ?? 0) > 1) && !wBlk?.useSingleIconForBullet)

    foreach (b in bulletsList) {
      let paramsBlk = u.isDataBlock(b?.rocket) ? b.rocket : b
      let bulletAnimations = paramsBlk % "shellAnimation"
      if (!res)
        if (paramsBlk?.caliber) {
          res = { caliber = 1000.0 * paramsBlk.caliber,
                  bullets = [],
                  bulletDataByType = {}
                  isBulletBelt = isBulletBelt
                  cartridge = wBlk?.bulletsCartridge ?? 0
                  weaponType = weaponType
                  useDefaultBullet = !wBlk?.notUseDefaultBulletInGui,
                  weaponBlkName = wBlkName
                  maxToRespawn = mod?.maxToRespawn ?? 0
                  bulletAnimations = clone bulletAnimations
                }
        }
        else
          continue
      else
        foreach (anim in bulletAnimations)
          appendOnce(anim, res.bulletAnimations)

      if(paramsBlk?.guiArmorpower != null)
        res.guiArmorpower <- copyParamsToTable(paramsBlk.guiArmorpower)

      local bulletType = b?.bulletType ?? b.getBlockName()
      let _bulletType = bulletType
      if (paramsBlk?.selfDestructionInAir)
        bulletType += "@s_d"
      res.bullets.append(bulletType)
      res.bulletDataByType[_bulletType] <- {
        bulletAnimations
      }

      if (paramsBlk?.guiCustomIcon != null) {
        if (res?.customIconsMap == null)
          res.customIconsMap <- {}
        res.customIconsMap[bulletType] <- paramsBlk.guiCustomIcon
      }

      if ("bulletName" in b) {
        if (!("bulletNames" in res))
          res.bulletNames <- []
        res.bulletNames.append(b.bulletName)
      }

      foreach (param in ["explosiveType", "explosiveMass"])
        if (param in paramsBlk) {
          res[param] <- paramsBlk[param]
          res.bulletDataByType[_bulletType][param] <- paramsBlk[param]
        }

      foreach (param in ["smokeShellRad", "smokeActivateTime", "smokeTime"])
        if (param in paramsBlk)
          res[param] <- paramsBlk[param]

      if (paramsBlk?.proximityFuse) {
        res.proximityFuseArmDistance <- paramsBlk.proximityFuse?.armDistance ?? 0
        res.proximityFuseRadius      <- paramsBlk.proximityFuse?.radius ?? 0
      }

      if ("sonicDamage" in paramsBlk) {
        res.sonicDamage <- {
          distance  = paramsBlk.sonicDamage?.distance
          speed     = paramsBlk.sonicDamage?.speed
          horAngles = paramsBlk.sonicDamage?.horAngles
          verAngles = paramsBlk.sonicDamage?.verAngles
        }
      }
    }

    if (res) {
      if ((res?.bulletNames ?? []).len() > 1
        && res.bulletNames.filter(@(v) v == res.bulletNames[0]).len() == res.bulletNames.len()) {
          res.mass <- bulletsList[0].mass
          res.isUniform <- true
      }
      if (noModList) {
        if (!bulSetForIconParam && !noModList.len()
            && !res.isBulletBelt) //really first default bullet set. can have default icon params
          bulSetForIconParam = res
        fakeBulletsSets.append(res)
        res = null
      }
      else {
        bulSetForIconParam = res
        break
      }
    }
  }

  if (bulSetForIconParam) {
    local bIconParam = 0
    if (searchName == modifName) //not default bullet
      bIconParam = getTblValue("bulletsIconParam", mod, 0)
    else
      bIconParam = getTblValue("bulletsIconParam", air, 0)
    if (bIconParam)
      bulSetForIconParam.bIconParam <- {
        armor = bIconParam % 10 - 1
        damage = (bIconParam / 10).tointeger() - 1
      }
  }

  //res = { caliber = 0.00762, bullets = ["he_i", "i_t", "he_frag@s_d", "aphe"]}
  if (!noModList)
    air.bulletsSets[modifName] <- res
  else {
    fakeBulletsSets.sort(function(a, b) {
      if (a.caliber != b.caliber)
        return a.caliber > b.caliber ? -1 : 1
      return 0
    })
    for (local i = 0; i < fakeBulletsSets.len(); i++)
      air.bulletsSets[modifName + i + "_default"] <- fakeBulletsSets[i]
  }

  return noModList ? fakeBulletsSets.len() : res
}

let function getBulletsModListByGroups(air) {
  let modList = []
  let groups = []

  if ("modifications" in air)
    foreach (m in air.modifications) {
      let groupName = getModificationBulletsGroup(m.name)
      if (groupName != "" && !isInArray(groupName, groups)) {
        groups.append(groupName)
        modList.append(m.name)
      }
    }
  return modList
}

let function getActiveBulletsIntByWeaponsBlk(air, weaponsArr, weaponToFakeBulletMask) {
  local res = 0
  let wpList = []
  foreach (weapon in weaponsArr)
    if (weapon?.blk && !weapon?.dummy && !isInArray(weapon.blk, wpList))
      wpList.append(weapon.blk)

  if (wpList.len()) {
    let modsList = getBulletsModListByGroups(air)
    foreach (wBlkName in wpList) {
      if (wBlkName in weaponToFakeBulletMask) {
        res = res | weaponToFakeBulletMask[wBlkName]
        continue
      }

      let wBlk = blkFromPath(wBlkName)
      if (u.isEmpty(wBlk))
        continue

      foreach (idx, modName in modsList)
        if (wBlk?[getModificationBulletsEffect(modName)]) {
          res = change_bit(res, idx, 1)
          break
        }
    }
  }
  return res
}

let function getBulletsGroupCount(air, full = false) {
  if (!air)
    return 0
  if (air.bulGroups < 0) {
    let modList = []
    let groups = []

    foreach (m in air.modifications) {
      let groupName = getModificationBulletsGroup(m.name)
      if (groupName != "") {
        if (!isInArray(groupName, groups))
          groups.append(groupName)
        modList.append(m.name)
      }
    }
    air.bulModsGroups = groups.len()
    air.bulGroups     = groups.len()

    let bulletSetsQuantity = air.unitType.bulletSetsQuantity
    if (air.bulGroups < bulletSetsQuantity) {
      let add = getBulletsSetData(air, ::fakeBullets_prefix, modList) || 0
      air.bulGroups = min(air.bulGroups + add, bulletSetsQuantity)
    }
  }
  return full ? air.bulGroups : air.bulModsGroups
}

let function getWeaponModIdx(weaponBlk, modsList) {
  return modsList.findindex(@(modName) weaponBlk?[getModificationBulletsEffect(modName)]) ?? -1
}

let function findIdenticalWeapon(weapon, weaponList, modsList) {
  if (weapon in weaponList)
    return weapon

  let weaponBlk = blkFromPath(weapon)
  if (u.isEmpty(weaponBlk))
    return null

  let cartridgeSize = weaponBlk?.bulletsCartridge || 1
  let groupIdx = getWeaponModIdx(weaponBlk, modsList)

  foreach (blkName, info in weaponList) {
    if (info.groupIndex == groupIdx
      && cartridgeSize == info.cartridge)
      return blkName
  }

  return null
}

let function getBulletsInfoForPrimaryGuns(air) {
  if (air.primaryBulletsInfo)
    return air.primaryBulletsInfo

  let res = []
  air.primaryBulletsInfo = res
  if (!air.unitType.canUseSeveralBulletsForGun)
    return res

  let airBlk = ::get_full_unit_blk(air.name)
  if (!airBlk)
    return res

  let commonWeapons = getCommonWeapons(airBlk, "")
  if (commonWeapons.len() == 0)
    return res

  let modsList = getBulletsModListByGroups(air)
  let wpList = {} // name = amount
  foreach (weapon in commonWeapons)
    if (weapon?.blk && !weapon?.dummy) {
      let weapName = findIdenticalWeapon(weapon.blk, wpList, modsList)
      if (weapName) {
        wpList[weapName].guns++
      }
      else {
        wpList[weapon.blk] <- clone DEFAULT_PRIMARY_BULLETS_INFO
        if (!("bullets" in weapon))
          continue

        wpList[weapon.blk].total = weapon?.bullets ?? 0
        let wBlk = blkFromPath(weapon.blk)
        if (u.isEmpty(wBlk))
          continue

        wpList[weapon.blk].cartridge = wBlk?.bulletsCartridge || 1
        wpList[weapon.blk].total = ceil(wpList[weapon.blk].total * 1.0 /
          wpList[weapon.blk].cartridge).tointeger()

        wpList[weapon.blk].groupIndex = getWeaponModIdx(wBlk, modsList)
        wpList[weapon.blk].forcedMaxBulletsInRespawn = wBlk?.forcedMaxBulletsInRespawn ?? false
      }
    }

  foreach (idx, _modName in modsList) {
    local bInfo = null
    foreach (_blkName, info in wpList)
      if (info.groupIndex == idx) {
        bInfo = info
        break
      }
    res.append(bInfo || (clone DEFAULT_PRIMARY_BULLETS_INFO))
  }
  return res
}

let function getBulletsInfoForGun(unit, gunIdx) {
  let bulletsInfo = getBulletsInfoForPrimaryGuns(unit)
  return getTblValue(gunIdx, bulletsInfo)
}

let function canBulletsBeDuplicate(unit) {
  return unit?.unitType.canUseSeveralBulletsForGun ?? false
}

let function getLastFakeBulletsIndex(unit) {
  if (!canBulletsBeDuplicate(unit))
    return getBulletsGroupCount(unit, true)
  return BULLETS_CALIBER_QUANTITY - getBulletsGroupCount(unit, false) +
    getBulletsGroupCount(unit, true)
}

let function getFakeBulletName(bulletIdx) {
  return ::fakeBullets_prefix + bulletIdx + "_default"
}

let function getBulletAnnotation(name, addName = null) {
  local txt = loc(name + "/name/short")
  if (addName)
    txt = $"{txt}{loc(addName + "/name/short")}"
  txt = $"{txt} - {loc(name + "/name")}"
  if (addName)
    txt = $"{txt} {loc(addName + "/name")}"
  return txt
}

let function getUniqModificationText(modifName, isShortDesc) {
  if (modifName == "premExpMul") {
    let value = ::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText(
      (get_ranks_blk()?.goldPlaneExpMul ?? 1.0) - 1.0, false)
    let ending = isShortDesc ? "" : "/desc"
    return loc("modification/" + modifName + ending, "", { value = value })
  }
  return null
}

let function getNVDSightCrewText(sight) {
  if (sight.contains("commander"))
    return loc("crew/commander")
  if (sight.contains("gunner"))
    return loc("crew/tank_gunner")
  if (sight.contains("driver"))
    return loc("crew/driver")
  return ""
}

let function getNVDSightSystemText(sight) {
  if (sight.contains("Thermal"))
    return loc("modification/thermal_vision_system")
  if (sight.contains("Ir"))
    return loc("modification/night_vision_system")
  return ""
}

let function getNVDSightText(sight) {
  let crew = getNVDSightCrewText(sight)
  if (crew == "")
    return ""
  let system = getNVDSightSystemText(sight)
  if (system == "")
    return ""
  return colorize("goodTextColor", $"{crew}{loc("ui/colon")} {system}")
}

// Generate text description for air.modifications[modificationNo]
local function getModificationInfo(air, modifName, isShortDesc = false,
  limitedName = false, obj = null, itemDescrRewriteFunc = null) {
  let res = { desc = "", delayed = false }
  if (type(air) == "string")
    air = getAircraftByName(air)
  if (!air)
    return res

  let uniqText = getUniqModificationText(modifName, isShortDesc)
  if (uniqText) {
    res.desc = uniqText
    return res
  }

  local mod = getModificationByName(air, modifName)
  local ammo_pack_len = 0
  if (modifName.indexof("_ammo_pack") != null && mod) {
    updateRelationModificationList(air, modifName);
    if ("relationModification" in mod && mod.relationModification.len() > 0) {
      modifName = mod.relationModification[0];
      ammo_pack_len = mod.relationModification.len()
      mod = getModificationByName(air, modifName)
    }
  }

  let groupName = getModificationBulletsGroup(modifName)
  if (groupName == "") { //not bullets
    if (!isShortDesc && itemDescrRewriteFunc)
      res.delayed = ::calculate_mod_or_weapon_effect(air.name, modifName, true, obj,
        itemDescrRewriteFunc, null) ?? true

    local locId = modifName
    let ending = isShortDesc ? (limitedName ? "/short" : "") : "/desc"

    res.desc = loc("modification/" + locId + ending, "")
    if (res.desc == "" && isShortDesc && limitedName)
      res.desc = loc("modification/" + locId, "")

    if (!isShortDesc) {
      let nvdDescs = air.getNVDSights(modifName).map(@(s) getNVDSightText(s)).filter(@(s) s != "")
      if (nvdDescs.len() > 0)
        res.desc = $"{res.desc}\n\n{"\n".join(unique(nvdDescs))}"
    }

    if (res.desc == "") {
      local caliber = 0.0
      foreach (n in ::modifications_locId_by_caliber)
        if (locId.len() > n.len() && locId.slice(locId.len() - n.len()) == n) {
          locId = n
          caliber = ("caliber" in mod) ? mod.caliber : 0.0
          if (limitedName)
            caliber = caliber.tointeger()
          break
        }

      locId = "modification/" + locId
      if (isCaliberCannon(caliber))
        res.desc = ::locEnding(locId + "/cannon", ending, "")
      if (res.desc == "")
        res.desc = ::locEnding(locId, ending)
      if (caliber > 0)
        res.desc = format(res.desc, caliber.tostring())
    }
    return res //without effects atm
  }

  //bullets sets
  let set = getBulletsSetData(air, modifName)

  if (isShortDesc && !mod && set?.weaponType == WEAPON_TYPE.GUNS
    && !air.unitType.canUseSeveralBulletsForGun) {
    res.desc = loc("modification/default_bullets")
    return res
  }

  if (!set) {
    if (res.desc == "")
      res.desc = modifName + " not found bullets"
    return res
  }

  local shortDescr = "";
  if (isShortDesc || ammo_pack_len) { //bullets name
    local locId = modifName
    let caliber = limitedName ? set.caliber.tointeger() : set.caliber
    foreach (n in ::bullets_locId_by_caliber)
      if (locId.len() > n.len() && locId.slice(locId.len() - n.len()) == n) {
        locId = n
        break
      }
    if (limitedName)
      shortDescr = loc(locId + "/name/short", "")
    if (shortDescr == "")
      shortDescr = loc(locId + "/name")
    if (set?.bulletNames?[0] && set.weaponType != WEAPON_TYPE.COUNTERMEASURES
      && (set.weaponType != WEAPON_TYPE.GUNS || !set.isBulletBelt ||
      (isCaliberCannon(caliber) && air.unitType.canUseSeveralBulletsForGun))) {
      locId = set.bulletNames[0]
      shortDescr = loc(locId, loc("weapons/" + locId + "/short", locId))
    }
    if (!mod && air.unitType.canUseSeveralBulletsForGun && set.isBulletBelt)
      shortDescr = loc("modification/default_bullets")
    shortDescr = format(shortDescr, caliber.tostring())
  }
  if (isShortDesc) {
    res.desc = shortDescr
    return res
  }

  if (ammo_pack_len) {
    if ("bulletNames" in set && type(set.bulletNames) == "array"
      && set.bulletNames.len())
        shortDescr = format(loc(set.isBulletBelt
          ? "modification/ammo_pack_belt/desc" : "modification/ammo_pack/desc"), shortDescr)
    if (ammo_pack_len > 1) {
      res.desc = shortDescr
      return res
    }
  }

  //bullets description
  let separator = loc("bullet_type_separator/name")
  let usedLocs = []
  let annArr = []
  let txtArr = []
  foreach (b in set.bullets) {
    let part = b.indexof("@")
    txtArr.append("".join(part == null ? [loc($"{b}/name/short")]
      : [loc($"{b.slice(0, part)}/name/short"), loc($"{b.slice(part+1)}/name/short")]))
    if (!isInArray(b, usedLocs)) {
      annArr.append(part == null ? getBulletAnnotation(b)
        : getBulletAnnotation(b.slice(0, part), b.slice(part + 1)))
      usedLocs.append(b)
    }
  }
  let setText = separator.join(txtArr)
  let annotation = "\n".join(annArr)

  if (ammo_pack_len)
    res.desc = shortDescr + "\n"
  if (set.weaponType == WEAPON_TYPE.COUNTERMEASURES)
    res.desc += loc("countermeasures/desc") + "\n\n"
  else if (set.bullets.len() > 1)
    res.desc += format(loc("caliber_" + set.caliber + "/desc"), setText) + "\n\n"
  res.desc += annotation
  return res
}

let function getModificationName(air, modifName, limitedName = false) {
  return getModificationInfo(air, modifName, true, limitedName).desc
}

let function appendOneBulletsItem(descr, modifName, air, amountText, genTexts, enabled = true, saveValue = null) {
  let item =  { enabled = enabled }
  descr.items.append(item)
  descr.values.append(modifName)
  descr.saveValues.append(saveValue ?? modifName)

  if (!genTexts)
    return

  item.text    <- " ".join([ amountText, getModificationName(air, modifName) ])
  item.tooltip <- " ".join([ amountText, getModificationInfo(air, modifName).desc ])
}

local function getBulletsList(airName, groupIdx, params = BULLETS_LIST_PARAMS) {
  params = BULLETS_LIST_PARAMS.__merge(params)
  let descr = {
    values = []
    saveValues = []
    isTurretBelt = false
    weaponType = WEAPON_TYPE.GUNS
    caliber = 0
    duplicate = false //tank gun bullets can be duplicate to change bullets during the battle

    //only when genText
    items = []
  }
  let air = getAircraftByName(airName)
  if (!air || !("modifications" in air))
    return descr

  let canBeDuplicate = canBulletsBeDuplicate(air)
  let groupCount = getBulletsGroupCount(air, true)
  if (groupCount <= groupIdx && !canBeDuplicate)
    return descr

  let modTotal = getBulletsGroupCount(air, false)
  let bulletSetsQuantity = air.unitType.bulletSetsQuantity
  let firstFakeIdx = canBeDuplicate ? bulletSetsQuantity : modTotal
  if (firstFakeIdx <= groupIdx) {
    let fakeIdx = groupIdx - firstFakeIdx
    let modifName = getFakeBulletName(fakeIdx)
    let bData = getBulletsSetData(air, modifName)
    if (bData) {
      if (!bData.useDefaultBullet)
        return descr
      descr.caliber = bData.caliber
      descr.weaponType = bData.weaponType
    }

    appendOneBulletsItem(descr, modifName, air, "", params.needTexts) //fake default bullet item
    return descr
  }

  let linked_index = getLinkedGunIdx(groupIdx, modTotal, bulletSetsQuantity, canBeDuplicate)
  descr.duplicate = canBeDuplicate && groupIdx > 0 &&
    linked_index == getLinkedGunIdx(groupIdx - 1, modTotal, bulletSetsQuantity, canBeDuplicate)

  let groups = []
  for (local modifNo = 0; modifNo < air.modifications.len(); modifNo++) {
    let modif = air.modifications[modifNo]
    let modifName = modif.name;

    let groupName = getModificationBulletsGroup(modifName)
    if (!groupName || groupName == "")
      continue;

    //get group index
    local currentGroup = u.find_in_array(groups, groupName)
    if (currentGroup == -1) {
      currentGroup = groups.len()
      groups.append(groupName)
    }
    if (currentGroup != linked_index)
      continue;

    if (descr.values.len() == 0) {
      let bData = getBulletsSetData(air, modifName)
      if (!bData || bData.useDefaultBullet)
        appendOneBulletsItem(descr, $"{groupName}_default", air, "", params.needTexts, true, "") //default bullets
      if ("isTurretBelt" in modif)
        descr.isTurretBelt = modif.isTurretBelt
      if (bData) {
        descr.caliber = bData.caliber
        descr.weaponType = bData.weaponType
      }
    }

    if (params.needOnlyAvailable && !params.isForcedAvailable
        && !isModAvailableOrFree(airName, modifName))
      continue

    let enabled = !params.isOnlyBought ||
      shopIsModificationPurchased(airName, modifName) != 0
    let amountText = params.needCheckUnitPurchase && ::is_game_mode_with_spendable_weapons()
      ? getAmmoAmountData(air, modifName, AMMO.MODIFICATION).text : ""

    appendOneBulletsItem(descr, modifName, air, amountText, params.needTexts, enabled)
  }
  return descr
}

let function getActiveBulletsGroupIntForDuplicates(unit, params) {
  local res = 0
  let groupsCount = getBulletsGroupCount(unit, false)
  local lastLinkedIdx = -1
  local duplicates = 0
  local lastIdxTotal = 0
  local maxCatridges = 0
  let bulletSetsQuantity = unit.unitType.bulletSetsQuantity
  for (local i = 0; i < bulletSetsQuantity; i++) {
    let linkedIdx = getLinkedGunIdx(i, groupsCount, bulletSetsQuantity)
    if (linkedIdx == lastLinkedIdx) {
      duplicates++
    }
    else {
      let checkPurchased = params?.checkPurchased ?? true
      let bullets = getBulletsList(unit.name, i, {
        isOnlyBought = checkPurchased,
        needCheckUnitPurchase = checkPurchased,
        isForcedAvailable = params?.isForcedAvailable ?? false
      })
      lastIdxTotal = bullets.values.len()
      lastLinkedIdx = linkedIdx
      duplicates = 0

      let bInfo = getBulletsInfoForGun(unit, linkedIdx)
      maxCatridges = getTblValue("total", bInfo, 0)
    }

    if (lastIdxTotal > duplicates && duplicates < maxCatridges)
      res = res | (1 << i)
  }
  return res
}

let function getBulletGroupIndex(airName, bulletName) {
  local group = -1
  let groupName = getModificationBulletsGroup(bulletName)
  if (!groupName || groupName == "")
    return -1

  let unit = getAircraftByName(airName)
  if (unit == null)
    return -1

  for (local groupIndex = 0; groupIndex < unit.unitType.bulletSetsQuantity; groupIndex++) {
    let bulletsList = getBulletsList(airName, groupIndex, {
      needCheckUnitPurchase = false, needOnlyAvailable = false })

    if (u.find_in_array(bulletsList.values, bulletName) >= 0) {
      group = groupIndex
      break
    }
  }

  return group
}

let function getBulletSetNameByBulletName(unit, bulletName) {
  let setName = unit.bulletsSets.findindex(@(s) s?.bulletNames.contains(bulletName))
  if (setName != null)
    return setName

  let numGroups = getLastFakeBulletsIndex(unit)
  for (local groupIndex = 0; groupIndex < numGroups; groupIndex++) {
    let bulletsList = getBulletsList(unit.name, groupIndex, {
      needCheckUnitPurchase = false, needOnlyAvailable = false })
    foreach (value in bulletsList.values) {
      let bulletSet = getBulletsSetData(unit, value)
      if (bulletSet?.bulletNames.contains(bulletName))
        return value
    }
  }
  return null
}

let function getWeaponToFakeBulletMask(unit) {
  let res = {}
  let lastFakeIdx = getLastFakeBulletsIndex(unit)
  let total = getBulletsGroupCount(unit, true) - getBulletsGroupCount(unit, false)
  let fakeBulletsOffset = lastFakeIdx - total
  for (local i = 0; i < total; i++) {
    let bulSet = getBulletsSetData(unit, getFakeBulletName(i))
    if (bulSet)
      res[bulSet.weaponBlkName] <- 1 << (fakeBulletsOffset + i)
  }
  return res
}

let function updatePrimaryBullets(unit, primaryWeapon, weaponToFakeBulletMask) {
  local primary = 0
  let primaryList = getPrimaryWeaponsList(unit)
  if (primaryList.len() > 0) {
    let airBlk = ::get_full_unit_blk(unit.name)
    if (airBlk)
      primary = getActiveBulletsIntByWeaponsBlk(unit,
        getCommonWeapons(airBlk, primaryWeapon), weaponToFakeBulletMask)
  }
  unit.primaryBullets[primaryWeapon] <- primary
}

let function updateSecondaryBullets(unit, secondaryWeapon, weaponToFakeBulletMask) {
  let weapon = unit.getWeapons().findvalue(@(w) w.name == secondaryWeapon)
  unit.secondaryBullets[secondaryWeapon] <- getActiveBulletsIntByWeaponsBlk(unit,
    getPresetWeapons(::get_full_unit_blk(unit.name), weapon), weaponToFakeBulletMask)
}

let function getActiveBulletsGroupInt(unit, params = null) {
  let primaryWeapon = getLastPrimaryWeapon(unit)
  let secondaryWeapon = getLastWeapon(unit.name)
  if (!(primaryWeapon in unit.primaryBullets) || !(secondaryWeapon in unit.secondaryBullets)) {
    let weaponToFakeBulletMask = getWeaponToFakeBulletMask(unit)
    if (!(primaryWeapon in unit.primaryBullets))
      updatePrimaryBullets(unit, primaryWeapon, weaponToFakeBulletMask)
    if (!(secondaryWeapon in unit.secondaryBullets))
      updateSecondaryBullets(unit, secondaryWeapon, weaponToFakeBulletMask)
  }

  local res = unit.primaryBullets[primaryWeapon] | unit.secondaryBullets[secondaryWeapon]
  if (canBulletsBeDuplicate(unit)) {
    res = res & ~((1 << unit.unitType.bulletSetsQuantity) - 1) //use only fake bullets mask
    res = res | getActiveBulletsGroupIntForDuplicates(unit, params)
  }
  return res
}

let function isBulletGroupActive(air, group) {
  let groupsActive = getActiveBulletsGroupInt(air)
  return (groupsActive & (1 << group)) != 0
}

let function isBulletsGroupActiveByMod(air, mod) {
  local groupIdx = getTblValue("isDefaultForGroup", mod, -1)
  if (groupIdx < 0)
    groupIdx = getBulletGroupIndex(air.name, mod.name)
  return isBulletGroupActive(air, groupIdx)
}

//to get exact same bullets list as in standart options
let function getOptionsBulletsList(air, groupIndex, needTexts = false, isForcedAvailable = false) {
  let checkPurchased = getGuiOptionsMode() != OPTIONS_MODE_TRAINING
  let res = getBulletsList(air.name, groupIndex, {
    isOnlyBought = checkPurchased
    needCheckUnitPurchase = checkPurchased
    needTexts = needTexts
    isForcedAvailable = isForcedAvailable
  }) //only_bought=true

  let curModif = getSavedBullets(air.name, groupIndex)
  local value = curModif ? u.find_in_array(res.saveValues, curModif) : -1

  if (value < 0 || !res.items[value].enabled) {
    value = 0
    let canBeDuplicate = canBulletsBeDuplicate(air)
    local skipIndex = canBeDuplicate ? groupIndex : 0
    for (local i = 0; i < res.items.len(); i++)
      if (res.items[i].enabled) {
        value = i
        if (--skipIndex < 0)
          break
      }
  }

  res.value <- value
  return res
}

let function getFakeBulletsModByName(unit, modName) {
  if (isFakeBullet(modName)) {
    let groupIdxStr = slice(
      modName, ::fakeBullets_prefix.len(), ::fakeBullets_prefix.len() + 1)
    let groupIdx = to_integer_safe(groupIdxStr, -1)
    if (groupIdx < 0)
      return null
    return {
      name = modName
      isDefaultForGroup = groupIdx
    }
  }

  // Attempt to get modification from group index (e.g. default modification).
  let groupIndex = getBulletGroupIndex(unit.name, modName)
  if (groupIndex >= 0)
    return { name = modName, isDefaultForGroup = groupIndex }

  return null
}

let function getUnitLastBullets(unit) {
  let bulletsItemsList = []
  for (local groupIndex = 0; groupIndex < getLastFakeBulletsIndex(unit); groupIndex++) {
    bulletsItemsList.append(getSavedBullets(unit.name, groupIndex))
  }
  return bulletsItemsList
}

let function getModifIconItem(unit, item) {
  if (item.type == weaponsItem.modification) {
    updateRelationModificationList(unit, item.name)
    if ("relationModification" in item && item.relationModification.len() == 1)
      return getModificationByName(unit, item.relationModification[0])
  }
  return null
}

return {
  BULLET_TYPE
  //


  isFakeBullet
  setUnitLastBullets
  getBulletsItemsList
  getBulletsSearchName
  getModificationBulletsEffect
  getBulletsSetData
  getBulletsGroupCount
  getBulletsInfoForPrimaryGuns
  getLastFakeBulletsIndex
  getBulletsList
  getBulletGroupIndex
  getActiveBulletsGroupInt
  isBulletGroupActive
  isBulletsGroupActiveByMod
  getOptionsBulletsList
  isBullets
  isWeaponTierAvailable
  getFakeBulletsModByName
  getUnitLastBullets
  getModificationInfo
  getModificationName
  getBulletAnnotation
  getBulletSetNameByBulletName
  getModifIconItem
  getWeaponToFakeBulletMask
  updateSecondaryBullets
}
