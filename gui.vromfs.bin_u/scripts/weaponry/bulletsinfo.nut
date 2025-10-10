from "%scripts/dagui_natives.nut" import is_tier_available, calculate_mod_or_weapon_effect
from "%scripts/dagui_library.nut" import *
from "%scripts/weaponry/weaponryConsts.nut" import weaponsItem, fakeBullets_prefix

let { get_bullets_locId_by_caliber, get_modifications_locId_by_caliber } = require("%scripts/options/optionsStorage.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { format } = require("string")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { eventbus_subscribe } = require("eventbus")
let { blkFromPath, eachParam, copyParamsToTable, blkOptFromPath } = require("%sqstd/datablock.nut")
let { ceil, change_bit, interpolateArray } = require("%sqstd/math.nut")
let { WEAPON_TYPE, getLastWeapon, isCaliberCannon, getCommonWeapons,
  getLastPrimaryWeapon, getPrimaryWeaponsList, getWeaponNameByBlkPath,
  getBulletBeltShortLocId
} = require("%scripts/weaponry/weaponryInfo.nut")
let { AMMO, getAmmoAmountData } = require("%scripts/weaponry/ammoInfo.nut")
let { isModResearched, isModAvailableOrFree, getModificationByName,
  updateRelationModificationList, getModificationBulletsGroup
} = require("%scripts/weaponry/modificationInfo.nut")
let { isModificationInTree } = require("%scripts/weaponry/modsTree.nut")
let { getGuiOptionsMode, set_unit_option, get_gui_option } = require("guiOptions")
let { getSavedBullets } = require("%scripts/weaponry/savedWeaponry.nut")
let { unique } = require("%sqstd/underscore.nut")
let { getPresetWeapons, getUnitWeapons } = require("%scripts/weaponry/weaponryPresets.nut")
let { appendOnce } = u
let DataBlock = require("DataBlock")
let { set_last_bullets } = require("unitCustomization")
let { startsWith, slice } = require("%sqstd/string.nut")
let { OPTIONS_MODE_TRAINING, USEROPT_BULLETS0, USEROPT_MODIFICATIONS
} = require("%scripts/options/optionsExtNames.nut")
let { shopIsModificationPurchased } = require("chardResearch")
let { get_ranks_blk, get_modifications_blk } = require("blkGetters")
let { measureType } = require("%scripts/measureType.nut")
let { getFullUnitBlk } = require("%scripts/unit/unitParams.nut")
let { isGameModeWithSpendableWeapons } = require("%scripts/gameModes/gameModeManagerState.nut")
let { doesLocTextExist } = require("dagor.localize")
let { getSupportUnits } = require("%scripts/unit/supportUnits.nut")
let { floatToText } = require("%scripts/langUtils/textFormat.nut")

let BULLET_TYPE = {
  ROCKET_AIR          = "rocket_aircraft"
  AAM                 = "aam"
  TORPEDO             = "torpedo"
  ATGM_TANK           = "atgm_tank"
  AP_TANK             = "ap_tank"
  ATGM_TANDEM_TANK    = "atgm_tandem_tank"
}

let BULLETS_WITHOUT_ICON_PARAMS = [
  "smoke", "countermeasures"
]

let DEFAULT_PRIMARY_BULLETS_INFO = {
  weapName                  = ""
  guns                      = 1
  total                     = 0 
  isBulletBelt              = true
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

let unitsPrimaryBulletsInfo = {}

local squashArmorAnglesScale = {} 

let anglesToCalcDamageMultiplier = [0, 30, 60] 

function getSquashArmorAnglesScale() {
  if (squashArmorAnglesScale.len())
    return squashArmorAnglesScale

  let squashAnglesModelParams = [] 
  let blk = DataBlock()
  blk.load("gameData/damage_model/damage_system.blk")
  eachParam(blk?.splash.squashArmorAnglesScale, @(v) squashAnglesModelParams.append(v))

  foreach(angle in anglesToCalcDamageMultiplier)
    squashArmorAnglesScale[angle] <- interpolateArray(squashAnglesModelParams, angle)

  return squashArmorAnglesScale
}






















function isBullets(item) {
  return (("isDefaultForGroup" in item) && (item.isDefaultForGroup >= 0))
    || (item.type == weaponsItem.modification && getModificationBulletsGroup(item.name) != "")
}

function isFlameTowerBulletSet(bulletSet) {
  return bulletSet?.bullets.indexof("napalm_tank") != null
}

function isWeaponTierAvailable(unit, tierNum) {
  local isAvailable = is_tier_available(unit.name, tierNum)

  if (!isAvailable && tierNum > 1) { 
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

function isFakeBullet(modName) {
  return startsWith(modName, fakeBullets_prefix)
}

function setUnitLastBullets(unit, groupIndex, value) {
  let saveValue = getModificationByName(unit, value) ? value : "" 
  let curBullets = getSavedBullets(unit.name, groupIndex)
  if (curBullets != saveValue) {
    set_unit_option(unit.name, USEROPT_BULLETS0 + groupIndex, saveValue)
    log($"Bullets Info: {unit.name}: bullet {groupIndex}: Set unit last bullets: change from '{curBullets}' to '{saveValue}'")
    set_last_bullets(unit.name, groupIndex, saveValue)
    broadcastEvent("UnitBulletsChanged", { unit = unit,
      groupIdx = groupIndex, bulletName = value })
  }
}

function getBulletsItemsList(unit, bulletsList, groupIndex) {
  let itemsList = []
  let curBulletsName = getSavedBullets(unit.name, groupIndex)
  local isCurBulletsValid = groupIndex >= unit.unitType.bulletSetsQuantity
  foreach (_i, value in bulletsList.values) {
    local bItem = getModificationByName(unit, value)
    isCurBulletsValid = isCurBulletsValid || value == curBulletsName
      || (!bItem && curBulletsName == "")
    if (!bItem) 
      bItem = { name = value, isDefaultForGroup = groupIndex }
    itemsList.append(bItem)
  }
  if (!isCurBulletsValid)
    setUnitLastBullets(unit, groupIndex, itemsList[0].name)

  return itemsList
}

function getBulletsSearchName(unit, modifName) { 
  if (!("modifications" in unit))
    return ""
  if (getModificationByName(unit, modifName))
    return modifName  

  let groupName = getModificationBulletsGroup(modifName)
  if (groupName != "")
    foreach (_i, modif in unit.modifications)
      if (getModificationBulletsGroup(modif.name) == groupName)
        return modif.name
  return ""
}

function getModificationBulletsEffect(modifName) {
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

function getBulletSetIconParam(unit, bulletSet, mod = null) {
  if (bulletSet.isBulletBelt || isFlameTowerBulletSet(bulletSet)
    || (bulletSet?.weaponType && BULLETS_WITHOUT_ICON_PARAMS.contains(bulletSet.weaponType)))
    return null

  local bIconParam = 0
  if (mod) 
    bIconParam = mod?.bulletsIconParam ?? 0
  else {
    if (unit?.bulletsIconParams) {
      let weaponName = getWeaponNameByBlkPath(bulletSet.weaponBlkName).tolower()
      bIconParam = unit.bulletsIconParams?[weaponName] ?? 0
    }
    if (!bIconParam)
      return {errorData = {unit = unit.name}}
  }
  return bIconParam
    ? {
        armor = bIconParam % 10 - 1
        damage = (bIconParam / 10).tointeger() - 1
      }
    : null
}

function getBulletsSetData(air, modifName, noModList = null) {
    
    
  if ((modifName in air.bulletsSets) && !noModList)
    return air.bulletsSets[modifName] 
  local res = null
  let airBlk = getFullUnitBlk(air.name)
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
  let supportBlkIdx = {}
  foreach (supportName in getSupportUnits(air.name)) {
    let supportUnit = getAircraftByName(supportName)
    if (supportUnit == null)
      continue
    let supportUnitBlk = getFullUnitBlk(supportName)
    let primaryListSupport = getPrimaryWeaponsList(supportUnit)
    foreach (primaryMod in primaryListSupport) {
      let supportWeapons = getCommonWeapons(supportUnitBlk, primaryMod)
      foreach (weapon in supportWeapons)
        if (weapon?.blk && !weapon?.dummy && !wpList.contains(weapon.blk)) {
          let wBlkIdx = wpList.len()
          supportBlkIdx[wBlkIdx] <- supportName
          wpList.append(weapon.blk)
          triggerList.append(weapon.trigger)
        }
    }
  }

  if (!noModList) { 
    let weapons = getUnitWeapons(airBlk)
    foreach (weapon in weapons)
      if (weapon?.blk && !weapon?.dummy && !isInArray(weapon.blk, wpList)) {
        wpList.append(weapon.blk)
        triggerList.append(weapon.trigger)
      }
  }

  let fakeBulletsSets = []
  local index = -1
  foreach (wBlkIdx, wBlkName in wpList) {
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
    let weaponTrigger = triggerList[index]
    local weaponType = weaponTrigger == "countermeasures"
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
          weaponType = (rocket?.bulletType == BULLET_TYPE.ATGM_TANK
            || rocket?.bulletType == BULLET_TYPE.ATGM_TANDEM_TANK)
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
                  weaponTrigger = weaponTrigger
                  useDefaultBullet = !wBlk?.notUseDefaultBulletInGui,
                  weaponBlkName = wBlkName
                  maxToRespawn = mod?.maxToRespawn ?? 0
                  bulletAnimations = clone bulletAnimations
                  cumulativeDamage = paramsBlk?.cumulativeDamage.armorPower ?? 0
                  cumulativeByNormal = paramsBlk?.cumulativeByNormal ?? false
                  supportUnitName = supportBlkIdx?[wBlkIdx]
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
        bulletType = $"{bulletType}@s_d"
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
        res.bIconParam <- getBulletSetIconParam(air, res)
        fakeBulletsSets.append(res)
        res = null
      }
      else {
        res.bIconParam <- getBulletSetIconParam(air, res, mod)
        break
      }
    }
  }


  
  if (!noModList)
    air.bulletsSets[modifName] <- res
  else {
    fakeBulletsSets.sort(function(a, b) {
      if (a.caliber != b.caliber)
        return a.caliber > b.caliber ? -1 : 1
      return 0
    })
    for (local i = 0; i < fakeBulletsSets.len(); i++)
      air.bulletsSets[$"{modifName}{i}_default"] <- fakeBulletsSets[i]
  }

  return noModList ? fakeBulletsSets.len() : res
}

function getBulletsModListByGroups(air) {
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

function getActiveBulletsIntByWeaponsBlk(air, weaponsArr, weaponToFakeBulletMask) {
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

function getBulletsGroupCount(air, full = false) {
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
      let add = getBulletsSetData(air, fakeBullets_prefix, modList) ?? 0
      air.bulGroups = min(air.bulGroups + add, bulletSetsQuantity)
    }
  }
  return full ? air.bulGroups : air.bulModsGroups
}

function getWeaponModIdx(weaponBlk, modsList) {
  return modsList.findindex(@(modName) weaponBlk?[getModificationBulletsEffect(modName)]) ?? -1
}

function findIdenticalWeapon(weapon, weaponList, modsList) {
  if (weapon in weaponList)
    return weapon

  let weaponBlk = blkFromPath(weapon)
  if (u.isEmpty(weaponBlk))
    return null

  let cartridgeSize = max(weaponBlk?.bulletsCartridge ?? 1, 1)
  let groupIdx = getWeaponModIdx(weaponBlk, modsList)

  foreach (blkName, info in weaponList) {
    if (info.groupIndex == groupIdx
      && cartridgeSize == info.cartridge)
      return blkName
  }

  return null
}

eventbus_subscribe("clearCacheForBullets", @(_) unitsPrimaryBulletsInfo.clear())

function getBulletsInfoForPrimaryGuns(air) {
  if (!air.unitType.canUseSeveralBulletsForGun)
    return []

  let primaryWeapon = getLastPrimaryWeapon(air)
  let presetWeapon = getLastWeapon(air.name)

  let cachedWeapons = unitsPrimaryBulletsInfo?[air.name]?[primaryWeapon][presetWeapon]
  if (cachedWeapons != null)
    return cachedWeapons

  let res = []
  if (unitsPrimaryBulletsInfo?[air.name] == null)
    unitsPrimaryBulletsInfo[air.name] <- {}
  if (unitsPrimaryBulletsInfo?[air.name][primaryWeapon] == null)
    unitsPrimaryBulletsInfo[air.name][primaryWeapon] <- {}
  unitsPrimaryBulletsInfo[air.name][primaryWeapon][presetWeapon] <- res

  let airBlk = getFullUnitBlk(air.name)
  if (!airBlk)
    return res

  let commonWeapons = getCommonWeapons(airBlk, primaryWeapon)
  let secondaryWeapon = air.getWeapons().findvalue(@(w) w.name == presetWeapon)
  let presetWeapons = getPresetWeapons(airBlk, secondaryWeapon)

  local weapons = commonWeapons
  weapons.extend(presetWeapons)

  foreach (supportName in getSupportUnits(air.name)) {
    let supportUnit = getAircraftByName(supportName)
    if (supportUnit == null)
      continue
    let supportUnitBlk = getFullUnitBlk(supportName)
    let primaryWeaponSupport = getLastPrimaryWeapon(supportUnit)
    let supCommonWeapons = getCommonWeapons(supportUnitBlk, primaryWeaponSupport)
    foreach (weapon in supCommonWeapons)
      if (weapon?.blk && !weapon?.dummy)
        weapons.append(weapon)
  }

  if (weapons.len() == 0)
    return res

  let modsList = getBulletsModListByGroups(air)
  let wpList = {} 
  foreach (weapon in weapons)
    if (weapon?.blk && !weapon?.dummy) {
      let weapName = findIdenticalWeapon(weapon.blk, wpList, modsList)
      if (weapName) {
        wpList[weapName].guns++
      }
      else {
        wpList[weapon.blk] <- clone DEFAULT_PRIMARY_BULLETS_INFO
        wpList[weapon.blk].weapName = getWeaponNameByBlkPath(weapon.blk)
        if (!("bullets" in weapon))
          continue

        wpList[weapon.blk].total = weapon?.bullets ?? 0
        let wBlk = blkFromPath(weapon.blk)
        if (u.isEmpty(wBlk))
          continue

        wpList[weapon.blk].isBulletBelt = wBlk?.isBulletBelt ?? true
        wpList[weapon.blk].cartridge = max((weapon?.bulletsCartridge ?? wBlk?.bulletsCartridge ?? 1), 1)
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

function getBulletsInfoForGun(unit, gunIdx) {
  let bulletsInfo = getBulletsInfoForPrimaryGuns(unit)
  return getTblValue(gunIdx, bulletsInfo)
}

function canBulletsBeDuplicate(unit) {
  return unit?.unitType.canUseSeveralBulletsForGun ?? false
}

function getLinkedGunIdx(groupIdx, totalGroups, bulletSetsQuantity, unit, canBeDuplicate = true) {
  if (!canBeDuplicate)
    return groupIdx

  if (totalGroups * 2 <= bulletSetsQuantity)
    return (groupIdx.tofloat() * totalGroups / bulletSetsQuantity + 0.001).tointeger()

  
  
  let gunsInfo = getBulletsInfoForPrimaryGuns(unit)
  local groupCount = 0
  let gunIdxWithDupicate = []
  foreach (gunIdx, gunInfo in gunsInfo) {
    if (!gunInfo.isBulletBelt) {
      gunIdxWithDupicate.append(gunIdx)
      continue
    }
    if (groupIdx == groupCount)
      return gunIdx
    groupCount++
  }
  if (gunIdxWithDupicate.len() == 0)
    return groupIdx

  return gunIdxWithDupicate[((groupIdx.tofloat() - groupCount) * gunIdxWithDupicate.len()
    / (bulletSetsQuantity - groupCount) + 0.001).tointeger()]
}

function getLastFakeBulletsIndex(unit) {
  if (!canBulletsBeDuplicate(unit))
    return getBulletsGroupCount(unit, true)
  return unit.unitType.bulletSetsQuantity - getBulletsGroupCount(unit, false) +
    getBulletsGroupCount(unit, true)
}

function getFakeBulletName(bulletIdx) {
  return $"{fakeBullets_prefix}{bulletIdx}_default"
}

function getBulletAnnotation(name, addName = null) {
  local txt = loc($"{name}/name/short")
  if (addName)
    txt = $"{txt}{loc($"{addName}/name/short")}"
  txt = $"{txt} - {loc($"{name}/name")}"
  if (addName)
    txt = $"{txt} {loc($"{addName}/name")}"
  return txt
}

function getUniqModificationText(modifName, isShortDesc) {
  if (modifName == "premExpMul") {
    let value = measureType.PERCENT_FLOAT.getMeasureUnitsText(
      (get_ranks_blk()?.goldPlaneExpMul ?? 1.0) - 1.0, false)
    let ending = isShortDesc ? "" : "/desc"
    return loc($"modification/{modifName}{ending}", "", { value = value })
  }
  return null
}

function getNVDSightCrewText(sight) {
  if (sight.contains("commander"))
    return loc("crew/commander")
  if (sight.contains("gunner"))
    return loc("crew/tank_gunner")
  if (sight.contains("driver"))
    return loc("crew/driver")
  return ""
}

function getNVDSightSystemText(sight) {
  if (sight.contains("Thermal"))
    return loc("modification/thermal_vision_system")
  if (sight.contains("Ir"))
    return loc("modification/night_vision_system")
  return ""
}

function getNVDSightText(sight) {
  let crew = getNVDSightCrewText(sight)
  if (crew == "")
    return ""
  let system = getNVDSightSystemText(sight)
  if (system == "")
    return ""
  return colorize("goodTextColor", $"{crew}{loc("ui/colon")} {system}")
}

function getBulletsNamesBySet(set) {
  
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
  return {
    setText = separator.join(txtArr)
    annotation = "\n".join(annArr)
  }
}

function locEnding(locId, ending, defValue = null) {
  local res = loc($"{locId}{ending}", "")
  if (res == "" && ending != "")
    res = loc(locId, defValue)
  return res
}

function getModWeaponsList(unit, modifName) {
  let weaponList = []
  let weaponsBlk = unit.getUnitWpCostBlk()?.weapons
  if (!weaponsBlk)
    return weaponList
  let weaponsCount = weaponsBlk.blockCount()
  for (local i = 0; i < weaponsCount; i++) {
    let weapon = weaponsBlk.getBlock(i)
    if (weapon?.reqModification == modifName) {
      local weapName = weapon.getBlockName()
      let isContainer = weapName.indexof("containers_") == 0
      let weaponTypeSeparator = weapName.indexof("_")
      if (weaponTypeSeparator)
        weapName = weapName.slice(weaponTypeSeparator + 1, weapName.len())

      if (isContainer) {
        let container = blkOptFromPath($"gameData/Weapons/containers/{weapName}")
        let containerWeapons = container % "blk"
        foreach (weaponBlkPatch in containerWeapons) {
          weapName = getWeaponNameByBlkPath(weaponBlkPatch)
          if (!weaponList.contains(weapName))
            weaponList.append(weapName)
        }
        continue
      }
      if (!weaponList.contains(weapName))
        weaponList.append(weapName)
    }
  }
  return weaponList
}

function getLocalizedModWeapons(unit, modifName) {
  let list = getModWeaponsList(unit, modifName)
  return ", ".join(list.map(@(weapName) loc($"weapons/{weapName}/short")))
}


function getModificationInfo(air, modifName, p = {}) {
  let { isShortDesc = false, isLimitedName = false, obj = null, itemDescrRewriteFunc = null, needAddName = true } = p
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

  local needAddNameToDesc = needAddName
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
  if (groupName == "") { 
    if (!isShortDesc && itemDescrRewriteFunc)
      res.delayed = calculate_mod_or_weapon_effect(air.name, modifName, true, obj,
        itemDescrRewriteFunc, null) ?? true

    local locId = modifName
    let ending = isShortDesc ? (isLimitedName ? "/short" : "") : "/desc"

    let locKey = $"modification/{locId}{ending}"
    if (doesLocTextExist(locKey)) {
      let locParams = {}
      if (!isLimitedName)
        locParams.unlockWeapons <- getLocalizedModWeapons(air, modifName)
      res.desc = loc(locKey, "", locParams)
    }

    if (res.desc == "" && isShortDesc && isLimitedName)
      res.desc = loc($"modification/{locId}", "")

    if (!isShortDesc) {
      let nvdDescs = air.getNVDSights(modifName).map(@(s) getNVDSightText(s)).filter(@(s) s != "")
      if (nvdDescs.len() > 0)
        res.desc = $"{res.desc}\n\n{"\n".join(unique(nvdDescs))}"
    }

    if (res.desc == "") {
      local caliber = 0.0
      foreach (n in get_modifications_locId_by_caliber())
        if (locId.len() > n.len() && locId.slice(locId.len() - n.len()) == n) {
          locId = n
          caliber = ("caliber" in mod) ? mod.caliber : 0.0
          if (isLimitedName)
            caliber = caliber.tointeger()
          break
        }

      locId = $"modification/{locId}"
      if (isCaliberCannon(caliber))
        res.desc = locEnding($"{locId}/cannon", ending, "")
      if (res.desc == "")
        res.desc = locEnding(locId, ending)
      if (caliber > 0)
        res.desc = format(res.desc, caliber.tostring())
    }
    return res 
  }

  
  let set = getBulletsSetData(air, modifName)

  if (isShortDesc && !mod && set?.weaponType == WEAPON_TYPE.GUNS
    && !air.unitType.canUseSeveralBulletsForGun) {
    res.desc = loc("modification/default_bullets")
    return res
  }

  if (!set) {
    if (res.desc == "")
      res.desc =$"{modifName} not found bullets"
    return res
  }

  local shortDescr = "";
  if (isShortDesc || ammo_pack_len) { 
    local locId = modifName
    let caliber = isLimitedName ? set.caliber.tointeger() : set.caliber
    if (!doesLocTextExist($"{locId}/name")) {
      foreach (n in get_bullets_locId_by_caliber())
        if (locId.len() > n.len() && locId.slice(locId.len() - n.len()) == n) {
          locId = n
          break
        }
    }
    if (isLimitedName)
      shortDescr = loc($"{locId}/name/short", "")
    if (shortDescr == "")
      shortDescr = loc($"{locId}/name")
    if (set?.bulletNames?[0] && set.weaponType != WEAPON_TYPE.COUNTERMEASURES
      && (set.weaponType != WEAPON_TYPE.GUNS || !set.isBulletBelt ||
      (isCaliberCannon(caliber) && air.unitType.canUseSeveralBulletsForGun))) {
      locId = set.bulletNames[0]
      shortDescr = loc(locId, loc($"weapons/{locId}/short", locId))
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
      && set.bulletNames.len()) {
        shortDescr = format(loc(set.isBulletBelt
          ? "modification/ammo_pack_belt/desc" : "modification/ammo_pack/desc"), shortDescr)
        needAddNameToDesc = true
      }
    if (ammo_pack_len > 1) {
      res.desc = shortDescr
      return res
    }
  }

  let { setText, annotation } = getBulletsNamesBySet(set)

  if (ammo_pack_len && needAddNameToDesc)
    res.desc = $"{shortDescr}\n"
  if (set.weaponType == WEAPON_TYPE.COUNTERMEASURES)
    res.desc = $"{res.desc}{loc("countermeasures/desc")}\n\n"
  else if (set.bullets.len() > 1)
    res.desc = "".concat(res.desc, format(loc($"caliber_{set.caliber}/desc"), setText), "\n\n")
  res.desc = $"{res.desc}{annotation}"
  return res
}

function getModificationName(air, modifName, limitedName = false) {
  return getModificationInfo(air, modifName,
    { isShortDesc = true, isLimitedName = limitedName }).desc
}

function appendOneBulletsItem(descr, modifName, air, amountText, genTexts, enabled = true, saveValue = null) {
  let item =  { enabled = enabled }
  descr.items.append(item)
  descr.values.append(modifName)
  descr.saveValues.append(saveValue ?? modifName)

  if (!genTexts)
    return

  item.text    <- " ".join([ amountText, getModificationName(air, modifName) ])
  item.tooltip <- " ".join([ amountText, getModificationInfo(air, modifName).desc ])
}

function getBulletsList(airName, groupIdx, params = BULLETS_LIST_PARAMS) {
  params = BULLETS_LIST_PARAMS.__merge(params)
  let descr = {
    values = []
    saveValues = []
    isTurretBelt = false
    isBulletBelt = true
    weaponType = WEAPON_TYPE.GUNS
    caliber = 0
    duplicate = false 
    supportUnitName = null

    
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
      descr.isBulletBelt = bData?.isBulletBelt ?? true
      descr.supportUnitName = bData?.supportUnitName
    }

    appendOneBulletsItem(descr, modifName, air, "", params.needTexts) 
    return descr
  }

  let linked_index = getLinkedGunIdx(groupIdx, modTotal, bulletSetsQuantity, air, canBeDuplicate)
  descr.duplicate = canBeDuplicate && groupIdx > 0 &&
    linked_index == getLinkedGunIdx(groupIdx - 1, modTotal, bulletSetsQuantity, air, canBeDuplicate)

  let groups = []
  for (local modifNo = 0; modifNo < air.modifications.len(); modifNo++) {
    let modif = air.modifications[modifNo]
    let modifName = modif.name;

    let groupName = getModificationBulletsGroup(modifName)
    if (!groupName || groupName == "")
      continue;

    
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
        appendOneBulletsItem(descr, $"{groupName}_default", air, "", params.needTexts, true, "") 
      if ("isTurretBelt" in modif)
        descr.isTurretBelt = modif.isTurretBelt
      if (bData) {
        descr.caliber = bData.caliber
        descr.weaponType = bData.weaponType
        descr.isBulletBelt = bData?.isBulletBelt ?? true
        descr.supportUnitName = bData?.supportUnitName
      }
    }

    if (params.needOnlyAvailable && !params.isForcedAvailable
        && !isModAvailableOrFree(airName, modifName))
      continue

    let enabled = !params.isOnlyBought ||
      shopIsModificationPurchased(airName, modifName) != 0
    let amountText = params.needCheckUnitPurchase && isGameModeWithSpendableWeapons()
      ? getAmmoAmountData(air, modifName, AMMO.MODIFICATION).text : ""

    appendOneBulletsItem(descr, modifName, air, amountText, params.needTexts, enabled)
  }
  return descr
}

function getActiveBulletsGroupIntForDuplicates(unit, params) {
  local res = 0
  let groupsCount = getBulletsGroupCount(unit, false)
  local lastLinkedIdx = -1
  local duplicates = 0
  local lastIdxTotal = 0
  local maxCatridges = 0
  let bulletSetsQuantity = unit.unitType.bulletSetsQuantity
  for (local i = 0; i < bulletSetsQuantity; i++) {
    let linkedIdx = getLinkedGunIdx(i, groupsCount, bulletSetsQuantity, unit)
    if (linkedIdx == lastLinkedIdx) {
      duplicates++
    }
    else {
      let bInfo = getBulletsInfoForGun(unit, linkedIdx)
      if (getTblValue("isBulletBelt", bInfo, true))
        lastIdxTotal = 1
      else {
        let checkPurchased = params?.checkPurchased ?? true
        let bullets = getBulletsList(unit.name, i, {
          isOnlyBought = checkPurchased,
          needCheckUnitPurchase = checkPurchased,
          isForcedAvailable = params?.isForcedAvailable ?? false
        })
        lastIdxTotal = bullets.values.len()
      }
      lastLinkedIdx = linkedIdx
      duplicates = 0
      maxCatridges = getTblValue("total", bInfo, 0)
    }
    if (lastIdxTotal > duplicates && duplicates < maxCatridges)
      res = res | (1 << i)
  }
  return res
}

function getBulletGroupIndex(airName, bulletName) {
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

function getBulletSetNameByBulletName(unit, bulletName) {
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
      if (bulletSet?.bullets.findindex(@(b) b.split("@")[0] == bulletName) != null)
        return value
    }
  }
  return null
}

function getWeaponToFakeBulletMask(unit) {
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

function updatePrimaryBullets(unit, primaryWeapon, weaponToFakeBulletMask) {
  local primary = 0
  let primaryList = getPrimaryWeaponsList(unit)
  if (primaryList.len() > 0) {
    let airBlk = getFullUnitBlk(unit.name)
    if (airBlk)
      primary = getActiveBulletsIntByWeaponsBlk(unit,
        getCommonWeapons(airBlk, primaryWeapon), weaponToFakeBulletMask)
  }
  unit.primaryBullets[primaryWeapon] <- primary
}

function updateSecondaryBullets(unit, secondaryWeapon, weaponToFakeBulletMask) {
  let weapon = unit.getWeapons().findvalue(@(w) w.name == secondaryWeapon)
  unit.secondaryBullets[secondaryWeapon] <- getActiveBulletsIntByWeaponsBlk(unit,
    getPresetWeapons(getFullUnitBlk(unit.name), weapon), weaponToFakeBulletMask)
}

function getActiveBulletsGroupInt(unit, params = null) {
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
    res = res & ~((1 << unit.unitType.bulletSetsQuantity) - 1) 
    res = res | getActiveBulletsGroupIntForDuplicates(unit, params)
  }
  return res
}

function isBulletGroupActive(air, group) {
  let groupsActive = getActiveBulletsGroupInt(air)
  return (groupsActive & (1 << group)) != 0
}

function isBulletsGroupActiveByMod(air, mod) {
  local groupIdx = getTblValue("isDefaultForGroup", mod, -1)
  if (groupIdx < 0)
    groupIdx = getBulletGroupIndex(air.name, mod.name)
  return isBulletGroupActive(air, groupIdx)
}

function isBulletsWithoutTracer(unit, item) {
  if (item?.hasTracer == false)
    return true

  if (!isBullets(item))
    return false

  let bulletsSet = getBulletsSetData(unit, item.name)
  let weaponName = getWeaponNameByBlkPath(bulletsSet?.weaponBlkName ?? "")
  return unit?.defaultBeltParam[weaponName].hasTracer == false
}


function getOptionsBulletsList(air, groupIndex, needTexts = false, isForcedAvailable = false) {
  let checkPurchased = getGuiOptionsMode() != OPTIONS_MODE_TRAINING
    || get_gui_option(USEROPT_MODIFICATIONS)
  let res = getBulletsList(air.name, groupIndex, {
    isOnlyBought = checkPurchased
    needCheckUnitPurchase = checkPurchased
    needTexts = needTexts
    isForcedAvailable = isForcedAvailable
  }) 

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

function getFakeBulletsModByName(unit, modName) {
  if (isFakeBullet(modName)) {
    let groupIdxStr = slice(
      modName, fakeBullets_prefix.len(), fakeBullets_prefix.len() + 1)
    let groupIdx = to_integer_safe(groupIdxStr, -1)
    if (groupIdx < 0)
      return null

    let canBeDuplicate = canBulletsBeDuplicate(unit)
    let modTotal = getBulletsGroupCount(unit, false)
    let bulletSetsQuantity = unit.unitType.bulletSetsQuantity
    let firstFakeIdx = canBeDuplicate ? bulletSetsQuantity : modTotal
    return {
      name = modName
      isDefaultForGroup = groupIdx + firstFakeIdx
    }
  }

  
  let groupIndex = getBulletGroupIndex(unit.name, modName)
  if (groupIndex >= 0)
    return { name = modName, isDefaultForGroup = groupIndex }

  return null
}

function getWeaponBlkNameByGroupIdx(unit, groupIndex) {
  let bulletsList = getBulletsList(unit.name, groupIndex, {
    needCheckUnitPurchase = false, needOnlyAvailable = false
  })
  let firstBulletName = bulletsList.values?[0] ?? ""
  let bulletsSet = getBulletsSetData(unit, firstBulletName)
  return getWeaponNameByBlkPath(bulletsSet?.weaponBlkName ?? "")
}

function getUnitLastBullets(unit) {
  let bulletsItemsList = []
  let numBulletsGroups = getLastFakeBulletsIndex(unit);
  for (local groupIndex = 0; groupIndex < numBulletsGroups; groupIndex++) {
    if (!isBulletGroupActive(unit, groupIndex))
      continue

    bulletsItemsList.append({
      name = getSavedBullets(unit.name, groupIndex),
      weapon = getWeaponBlkNameByGroupIdx(unit, groupIndex)
    })
  }
  return bulletsItemsList
}

function getModifIconItem(unit, item) {
  if (item?.type == weaponsItem.modification) {
    updateRelationModificationList(unit, item.name)
    if ("relationModification" in item && item.relationModification.len() == 1)
      return getModificationByName(unit, item.relationModification[0])
  }
  return null
}

function getAmmoStowageConstraintsByTrigger(unit) {
  let constraintsByTrigger = {}
  let unitBlk = getFullUnitBlk(unit.name)
  if (!unitBlk?.ammoStowages || !(unitBlk.ammoStowages?.enablePerAmmoTypesAndConstraints ?? false))
    return constraintsByTrigger
  let stowagesBlk = unitBlk.ammoStowages
  for (local iStowage = 0; iStowage < stowagesBlk.blockCount(); iStowage++) {
    let stowageBlk = stowagesBlk.getBlock(iStowage)
    foreach (triggerName in stowageBlk % "weaponTrigger") {
      if (!(triggerName in constraintsByTrigger))
        constraintsByTrigger[triggerName] <- {
          total = 0,
          explosive = 0
        }
      let constraints = constraintsByTrigger[triggerName]

      foreach (clusterBlk in stowageBlk % "shells") {
        for (local iSlot = 0; iSlot < clusterBlk.blockCount(); iSlot++) {
          let slotBlk = clusterBlk.getBlock(iSlot)
          if (!slotBlk)
            continue
          let numAmmo = slotBlk?.count ?? 0
          constraints.total += numAmmo
          if (slotBlk?.type != "inert")
            constraints.explosive += numAmmo
        }
      }
    }
  }
  return constraintsByTrigger
}

function getBulletsSetMaxAmmoWithConstraints(constraintsByTrigger, bulletsSet) {
  if (!(bulletsSet?.weaponTrigger && bulletsSet.weaponTrigger in constraintsByTrigger))
    return 0
  let constraints = constraintsByTrigger[bulletsSet.weaponTrigger]
  if (constraints.total == 0)
    return 0
  local ammo = constraints.total;
  if (bulletsSet?.explosiveMass && bulletsSet.explosiveMass > 0)
    ammo = min(constraints.explosive, ammo)
  return ammo
}


let isPairBulletsGroup = @(bullets) bullets.values.len() == 2
  && bullets.weaponType == WEAPON_TYPE.COUNTERMEASURES
  && !(bullets?.isBulletBelt ?? true)

function getModBulletSet(unit, mod) {
  let modName = getModifIconItem(unit, mod)?.name ?? mod?.name
  return !modName ? null : getBulletsSetData(unit, modName)
}

function isShell(bulletsSet) {
  return bulletsSet?.weaponType != WEAPON_TYPE.COUNTERMEASURES
}

function isModificationIsShell(unit, mod) {
  let bulletsSet = getModBulletSet(unit, mod)
  return bulletsSet != null && isShell(bulletsSet)
}

const ROCKET_STRIKING_PART_SUFFIX = "^strikpart"
let stripProjectileStrikPartSuffix = @(name) name.endswith(ROCKET_STRIKING_PART_SUFFIX)
  ? name.replace(ROCKET_STRIKING_PART_SUFFIX, "")
  : name

function getProjectileNameLoc(projectileName, needToUseBulletTypeName = false, unit = null) {
  projectileName = stripProjectileStrikPartSuffix(projectileName)
  if (projectileName == "artillery")
    return loc("multiplayer/artillery")
  if (doesLocTextExist(projectileName))
    return loc(projectileName)
  if (doesLocTextExist($"weapons/{projectileName}/short"))
    return loc($"weapons/{projectileName}/short")

  if (needToUseBulletTypeName) {
    if (doesLocTextExist($"{projectileName}/name"))
      return loc($"{projectileName}/name")
    if (unit) {
      let caliber = (unit?.modifications.findvalue(@(m) m.name == projectileName).caliber ?? 0) * 1000
      let bulletLocId = getBulletBeltShortLocId(projectileName)
      if (caliber && doesLocTextExist(bulletLocId)) {
        let caliberString = caliber % 1 != 0
          ? format(loc("caliber/mm_decimals"), floatToText(caliber))
          : format(loc("caliber/mm"), caliber)
        return $"{caliberString} {loc(bulletLocId)}"
      }
    }
    if (projectileName != "")
      logerr($"Can't find localization for projectile {projectileName}")
  }
  return ""
}

local projectileNameToIconsBlk = null
function getProjectileIconLayers(projectileName) {
  if (projectileNameToIconsBlk == null) {
    projectileNameToIconsBlk = DataBlock()
    projectileNameToIconsBlk.tryLoad("config/killer_projectile_icon.blk")
  }

  return projectileNameToIconsBlk.getStr(stripProjectileStrikPartSuffix(projectileName), "")
    .split_by_chars(";", true)
    .map(@(layeredIconSrc) { layeredIconSrc })
}

return {
  BULLET_TYPE
  


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
  isBulletsWithoutTracer
  getOptionsBulletsList
  isBullets
  isWeaponTierAvailable
  getFakeBulletsModByName
  getWeaponBlkNameByGroupIdx
  getUnitLastBullets
  getModificationInfo
  getModificationName
  getBulletAnnotation
  getBulletSetNameByBulletName
  getModifIconItem
  getWeaponToFakeBulletMask
  updateSecondaryBullets
  getAmmoStowageConstraintsByTrigger
  getBulletsSetMaxAmmoWithConstraints
  getBulletsNamesBySet
  isPairBulletsGroup
  getLinkedGunIdx
  isModificationIsShell
  getSquashArmorAnglesScale
  anglesToCalcDamageMultiplier
  getProjectileNameLoc
  getProjectileIconLayers
  stripProjectileStrikPartSuffix
}
