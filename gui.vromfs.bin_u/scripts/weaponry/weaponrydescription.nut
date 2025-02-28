from "%scripts/dagui_natives.nut" import shop_is_weapon_purchased
from "%scripts/dagui_library.nut" import *
from "%scripts/weaponry/weaponryConsts.nut" import INFO_DETAIL

let { g_difficulty, get_difficulty_by_ediff } = require("%scripts/difficulty.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { format } = require("string")
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
let { utf8Capitalize } = require("%sqstd/string.nut")
let { shopIsModificationPurchased } = require("chardResearch")
let { getEsUnitType, getFullUnitBlk } = require("%scripts/unit/unitParams.nut")
let { isInFlight } = require("gameplayBinding")
let { getCurMissionRules } = require("%scripts/misCustomRules/missionCustomState.nut")
let { getCurrentGameModeEdiff } = require("%scripts/gameModes/gameModeManagerState.nut")

function getReloadTimeByCaliber(caliber, ediff = null) {
  let diff = get_difficulty_by_ediff(ediff ?? getCurrentGameModeEdiff())
  if (diff != g_difficulty.ARCADE)
    return null
  return reloadCooldownTimeByCaliber.value?[caliber]
}

let getTextNoWeapons = @(unit, isPrimary) isPrimary ? loc("weapon/noPrimaryWeapon")
  : (unit.isAir() || unit.isHelicopter()) ? loc("weapon/noSecondaryWeapon")
  : loc("weapon/noAdditionalWeapon")

let stackableWeapons = [WEAPON_TYPE.TURRETS]

function stackWeaponsData(weaponType, triggers) {
  if (isInArray(weaponType, stackableWeapons)) {  //merge stackable in one
    for (local i = 0; i < triggers.len(); i++) {
      triggers[i][weaponType] <- 1
      local sameIdx = -1
      for (local j = 0; j < i; j++)
        if (triggers[i].weaponBlocks.len() == triggers[j].weaponBlocks.len()) {
          local same = true
          foreach (wName, w in triggers[j].weaponBlocks)
            if ((wName not in triggers[i].weaponBlocks) || triggers[i].weaponBlocks[wName].num != w.num) {
              same = false
              break
            }
          if (same) {
            sameIdx = j
            break
          }
        }
      if (sameIdx >= 0) {
        triggers[sameIdx][weaponType]++
        foreach (wName, w in triggers[i].weaponBlocks)
          triggers[sameIdx].weaponBlocks[wName].ammo += w.ammo
        triggers.remove(i)
        i--
      }
    }
  }
}

function updateWeaponBlocks(resultWeaponBlocks, turretsData, trigger, weaponType) {
  foreach (weaponName, weapon in trigger.weaponBlocks) {
    let isTurret = TRIGGER_TYPE.TURRETS in trigger

    local hasWeapon = false
    weapon.weaponType <- weaponType
    foreach (newWeapon in resultWeaponBlocks) {
      if (newWeapon?.bulletName && newWeapon.bulletName == weapon?.bulletName) {
        newWeapon.ammo += weapon.ammo
        hasWeapon = true
        break
      }
    }
    if (!hasWeapon) {
      if (isTurret)
        turretsData[weaponName] <- weapon
      else
        resultWeaponBlocks[weaponName] <- (weapon)
    }
    if (isTurret)
      turretsData[weaponName][TRIGGER_TYPE.TURRETS] <- trigger[TRIGGER_TYPE.TURRETS]
  }
}

function countGunNames(gunNames, weaponBlocks) {
  foreach (weaponName, weapon in weaponBlocks)
      gunNames[weaponName] <- (gunNames?[weaponName] ?? 0) + weapon.num
}

function makeWeaponInfoData(unit, p = WEAPON_TEXT_PARAMS) {
  let updatedParams = WEAPON_TEXT_PARAMS.__merge(p)
  let res = {
    p = updatedParams
  }
  unit = type(unit) == "string" ? getAircraftByName(unit) : unit
  if (!unit)
    return res

  let weapons = updatedParams?.weapons ?? getUnitWeaponry(unit, updatedParams)
  if (weapons == null)
    return res

  let isShortDesc = updatedParams.detail <= INFO_DETAIL.SHORT //for weapons SHORT == LIMITED_11
  res.isShortDesc <- isShortDesc
  res.weapons <- weapons

  let weaponsData = {}
  let turretsData = {} // to add turrets at the end

  // params for shortDesc only:
  let weapTypeCount = {}
  let gunNames = {}

  foreach (weaponType, triggers in (weapons?.weaponsByTypes ?? {})) {
    stackWeaponsData(weaponType, triggers)

    foreach (trigger in triggers) {
      updateWeaponBlocks(weaponsData, turretsData, trigger, weaponType)
      let isTurret = TRIGGER_TYPE.TURRETS in trigger
      let needToCountGuns =
        isShortDesc &&
        !isTurret &&
        !(isInArray(weaponType, CONSUMABLE_TYPES) || weaponType == WEAPON_TYPE.CONTAINER_ITEM)
      if (needToCountGuns)
        countGunNames(gunNames, trigger.weaponBlocks)

      if (isShortDesc) {
        weapTypeCount[weaponType] <- (weapTypeCount?[weaponType] ?? 0 ) + ( isTurret ? trigger[TRIGGER_TYPE.TURRETS] : 0 )
      }

    }
  }
  res.weapTypeCount <- weapTypeCount
  res.gunNames <- gunNames

  let resultTurretBlocks = turretsData
    .topairs()
    .sort(@(a,b) b[1].caliber <=> a[1].caliber)
    .map(@(block) { [block[0]] = block[1] })

  let resultWeaponBlocks = weaponsData
    .topairs()
    .sort(@(a,b) b[1].caliber <=> a[1].caliber)
    .map(@(block) { [block[0]] = block[1] })
    .extend(resultTurretBlocks)
  res.resultWeaponBlocks <- resultWeaponBlocks

  return res
}

function getWeaponInfoText(unit, weaponInfoData) {
  let { resultWeaponBlocks = null, weapons = null, weapTypeCount, gunNames,
    isShortDesc = false, p } = weaponInfoData

  local text = ""
  if (resultWeaponBlocks == null || weapons == null)
    return text

  let unitType = getEsUnitType(unit)
  if (u.isEmpty(weapons) && p.needTextWhenNoWeapons)
    text = $"{text}{getTextNoWeapons(unit, p.isPrimary)}"

  foreach(weaponBlock in (resultWeaponBlocks ?? [])) {
    let weaponName = weaponBlock.findindex(@(_) true)
    if (!weaponName)
      continue
    let weapon = weaponBlock[weaponName]
    local tText = ""
    let weaponType = weapon.weaponType

    if (isInArray(weaponType, CONSUMABLE_TYPES) || weaponType == WEAPON_TYPE.CONTAINER_ITEM) {
      if (isShortDesc) {
        tText = "".concat(tText, loc($"weapons/{weaponName}/short"))
        if (!p.isSingle && weapon.ammo > 1)
          tText = "".concat(tText, " ", format(loc("weapons/counter/right/short"), weapon.ammo))
      }
      else {
        tText = "".concat(tText, loc($"weapons/{weaponName}"),
          p.isSingle ? "" : format(loc("weapons/counter"), weapon.ammo))
        if (weaponType == "torpedoes" && p.isPrimary != null &&
            isInArray(unitType, [ES_UNIT_TYPE_AIRCRAFT, ES_UNIT_TYPE_HELICOPTER])) { // torpedoes drop for unit only
          if (weapon.dropSpeedRange) {
            let speedKmph = countMeasure(0, [weapon.dropSpeedRange.x, weapon.dropSpeedRange.y])
            let speedMps  = countMeasure(3, [weapon.dropSpeedRange.x, weapon.dropSpeedRange.y])
            tText = "".concat(tText, "\n", format(loc("weapons/drop_speed_range"),
              "{0} {1}".subst(speedKmph, loc("ui/parentheses", { text = speedMps }))))
          }
          if (weapon.dropHeightRange)
            tText = "".concat(tText, "\n", format(loc("weapons/drop_height_range"),
              countMeasure(1, [weapon.dropHeightRange.x, weapon.dropHeightRange.y])))
        }
        if (p.detail >= INFO_DETAIL.EXTENDED && unitType != ES_UNIT_TYPE_TANK)
          tText = "".concat(tText, getWeaponExtendedInfo(weapon, weaponType, unit, p.ediff, $"{p.newLine}{nbsp}{nbsp}{nbsp}{nbsp}"))
      }
    }
    else {
      if (!isShortDesc) {
        tText = $"{tText}{loc($"weapons/{weaponName}")}"
        if (weapon.num > 1)
          tText = $"{tText}{format(loc("weapons/counter"), weapon.num)}"

        if (!p.isSingle && weapon.ammo > 0)
          tText = "".concat(tText, " (", loc("shop/ammo"), loc("ui/colon"), weapon.ammo, ")")

        if (!unit.unitType.canUseSeveralBulletsForGun) {
          local rTime = getReloadTimeByCaliber(weapon.caliber, p.ediff)
          if (rTime) {
            if (p.isLocalState) {
              let difficulty = get_difficulty_by_ediff(p.ediff ?? getCurrentGameModeEdiff())
              let key = isCaliberCannon(weapon.caliber) ? "cannonReloadSpeedK" : "gunReloadSpeedK"
              let speedK = unit.modificators?[difficulty.crewSkillName]?[key] ?? 1.0
              if (speedK)
                rTime = round_by_value(rTime / speedK, 1.0).tointeger()
            }
            tText = " ".concat(tText, loc("bullet_properties/cooldown"), secondsToString(rTime, true, true))
          }
        }
      }
    }

    if (!isShortDesc) {
      if (TRIGGER_TYPE.TURRETS in weapon) { // && !unit.unitType.canUseSeveralBulletsForGun)
        if (weapon[TRIGGER_TYPE.TURRETS] > 1)
          tText = "".concat(format(loc("weapons/turret_number"), weapon[TRIGGER_TYPE.TURRETS]), tText)
        else
          tText = "".concat(utf8Capitalize(loc("weapons_types/turrets")), loc("ui/colon"), tText)
      }
    }

    if (tText != "")
      text = $"{text}{(text != "") ? p.newLine : ""}{tText}"

    if ((weapTypeCount?[weaponType] ?? 0) == 0 && gunNames.len() == 0)
      continue

    text = text != "" ? "".concat(text, p.newLine) : ""
    if (isShortDesc) {
      if ((weapTypeCount?[weaponType] ?? 0) > 0) { //Turrets
        text = "".concat(text, loc($"weapons_types/{weaponType}"), nbsp,
          format(loc("weapons/counter/right/short"), weapTypeCount[weaponType]))
        weapTypeCount.rawdelete(weaponType)
      }
      if (gunNames.len() > 0) { //Guns
        let gunsTxt = []
        foreach (name, count in gunNames)
          gunsTxt.append("".concat(loc($"weapons/{name}"), count > 1
            ? $"{nbsp}{format(loc("weapons/counter/right/short"), count)}" : ""))
        text = $"{text}{(loc("ui/comma")).join(gunsTxt)}"
      }
    }
    else
      text = "".concat(text, loc($"weapons_types/{weaponType}"),
        format(loc("weapons/counter"), weapTypeCount[weaponType]))
  }

  if (text == "" && p.needTextWhenNoWeapons)
    text = getTextNoWeapons(unit, p.isPrimary)

  return text
}

function getWeaponNameText(unit, isPrimary = null, weaponPreset = -1, newLine = ", ") {
  let weaponInfoParams = {
    isPrimary
    weaponPreset
    newLine
    detail = INFO_DETAIL.SHORT
  }
  return getWeaponInfoText(unit, makeWeaponInfoData(unit, weaponInfoParams))
}


function getWeaponXrayDescText(weaponBlk, unit, ediff) {
  let weaponsArr = []
  u.appendOnce((u.copy(weaponBlk)), weaponsArr)
  let weaponTypes = addWeaponsFromBlk({}, weaponsArr, unit)
  foreach (weaponType, weaponTypeList in (weaponTypes?.weaponsByTypes ?? {}))
    foreach (weapons in weaponTypeList)
      foreach (weapon in weapons.weaponBlocks)
        return getWeaponExtendedInfo(weapon, weaponType, unit, ediff, "\n") // -unconditional-terminated-loop
  return ""
}


function getWeaponDescTextByTriggerGroup(triggerGroup, unit, ediff) {
  let unitBlk = getFullUnitBlk(unit.name)
  let primaryWeapon = getLastPrimaryWeapon(unit)
  let secondaryWeapon = getLastWeapon(unit.name)

  local weaponTypes = {}
  weaponTypes = addWeaponsFromBlk(weaponTypes, getCommonWeapons(unitBlk, primaryWeapon), unit)
  let curWeapon = unit.getWeapons().findvalue(@(w) w.name == secondaryWeapon)
  weaponTypes = addWeaponsFromBlk(weaponTypes, getPresetWeapons(unitBlk, curWeapon), unit)

  foreach (weapons in (weaponTypes?.weaponsByTypes[triggerGroup] ?? []))
    foreach (weaponName, weapon in weapons.weaponBlocks)
      return "".concat( // -unconditional-terminated-loop
        loc($"weapons/{weaponName}"),
        format(loc("weapons/counter"), weapon.ammo),
        getWeaponExtendedInfo(weapon, triggerGroup, unit, ediff, "\n{0}{0}{0}{0}".subst(nbsp))
      )
  return ""
}

// return short desc of unit.weapons[weaponPresetNo], like M\C\B\T
function getWeaponShortType(_unit, weapon) {
  let textArr = []
  if (weapon.frontGun)
    textArr.append(loc("weapons_types/short/guns"))
  if (weapon.cannon)
    textArr.append(loc("weapons_types/short/cannons"))
  if (weapon.bomb)
    textArr.append(loc("weapons_types/short/bombs"))
  if (weapon.rocket)
    textArr.append(loc("weapons_types/short/rockets"))
  if (weapon.torpedo)
    textArr.append(loc("weapons_types/short/torpedoes"))

  return loc("weapons_types/short/separator").join(textArr)
}

function getWeaponShortTypeFromWpName(wpName, unit = null) {
  if (!wpName || type(wpName) != "string")
    return ""

  if (type(unit) == "string")
    unit = getAircraftByName(unit)

  if (!unit)
    return ""

  foreach (weapon in unit.getWeapons()) {
    if (wpName == weapon.name)
      return getWeaponShortType(unit, weapon)
  }

  return ""
}

function getDefaultBulletName(unit) {
  if (!("modifications" in unit))
    return ""

  let ignoreGroups = [null, ""]
  for (local modifNo = 0; modifNo < unit.modifications.len(); modifNo++) {
    let modif = unit.modifications[modifNo]
    let modifName = modif.name;

    let groupName = getModificationBulletsGroup(modifName);
    if (isInArray(groupName, ignoreGroups))
      continue

    let bData = getBulletsSetData(unit, modifName)
    if (!bData || bData?.useDefaultBullet)
      return $"{groupName}_default"

    ignoreGroups.append(groupName)
  }
  return ""
}

function getModItemName(unit, item, limitedName = true) {
  return ::g_weaponry_types.getUpgradeTypeByItem(item).getLocName(unit, item, limitedName)
}

function getReqModsText(unit, item) {
  let reqText = []
  foreach (rp in ["reqWeapon", "reqModification"])
      if (rp in item)
        foreach (req in item[rp])
          if (rp == "reqWeapon" && !shop_is_weapon_purchased(unit.name, req))
            reqText.append("".concat(loc(rp), loc("ui/colon"), getWeaponNameText(unit.name, false, req, ", ")))
          else if (rp == "reqModification" && !shopIsModificationPurchased(unit.name, req))
            reqText.append("".concat(loc(rp), loc("ui/colon"), getModificationName(unit, req)))
  return "\n".join(reqText)
}

function getBulletsListHeader(unit, bulletsList) {
  local locId = ""
  if (bulletsList.weaponType == WEAPON_TYPE.ROCKETS)
    locId = "modification/_rockets"
  else if (isInArray(bulletsList.weaponType, [ WEAPON_TYPE.AAM, WEAPON_TYPE.AGM ]))
    locId = "modification/_missiles"
  else if (bulletsList.weaponType == WEAPON_TYPE.FLARES)
    locId = "modification/_flares"
  else if (bulletsList.weaponType == WEAPON_TYPE.SMOKE)
    locId = "modification/_smoke_screen"
  else if (bulletsList.weaponType == WEAPON_TYPE.GUNS) {
    if (unit.unitType.canUseSeveralBulletsForGun)
      locId = isCaliberCannon(bulletsList.caliber) ? "modification/_tank_gun_pack" : "modification/_tank_minigun_pack"
    else
      locId = bulletsList.isTurretBelt ? "modification/_turret_belt_pack/short" : "modification/_belt_pack/short"
  }
  else if (bulletsList.weaponType == WEAPON_TYPE.COUNTERMEASURES)
    locId = "modification/_countermeasures"
  return format(loc(locId), bulletsList.caliber.tostring())
}

//include spawn score cost
function getFullItemCostText(unit, item, spawnScoreOnly = false) {
  let res = []
  let wType = ::g_weaponry_types.getUpgradeTypeByItem(item)
  let misRules = getCurMissionRules()

  if ((!isInFlight() || misRules.isWarpointsRespawnEnabled) && !spawnScoreOnly)
    res.append(wType.getCost(unit, item).tostring())

  if (isInFlight() && misRules.isScoreRespawnEnabled) {
    let scoreCostText = wType.getScoreCostText(unit, item)
    if (scoreCostText.len())
      res.append(scoreCostText)
  }
  return ", ".join(res)
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
  makeWeaponInfoData
}