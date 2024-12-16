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
let { utf8ToUpper } = require("%sqstd/string.nut")
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

function getWeaponInfoText(unit, p = WEAPON_TEXT_PARAMS) {
  local text = ""
  unit = type(unit) == "string" ? getAircraftByName(unit) : unit
  if (!unit)
    return text

  let weapons = p?.weapons ?? getUnitWeaponry(unit, p)
  if (weapons == null)
    return text

  p = WEAPON_TEXT_PARAMS.__merge(p)
  let unitType = getEsUnitType(unit)
  if (u.isEmpty(weapons) && p.needTextWhenNoWeapons)
    text = $"{text}{getTextNoWeapons(unit, p.isPrimary)}"
  let stackableWeapons = [WEAPON_TYPE.TURRETS]
  foreach (weaponType, triggers in (weapons?.weaponsByTypes ?? {})) {
    triggers.sort(@(a, b) b.caliber <=> a.caliber)

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

    let isShortDesc = p.detail <= INFO_DETAIL.SHORT //for weapons SHORT == LIMITED_11
    local weapTypeCount = 0 //for shortDesc only
    let gunNames = {}     //for shortDesc only

    foreach (trigger in triggers) {
      local tText = ""
      let newWeaponBlocks = {}
      foreach (weaponName, weapon in trigger.weaponBlocks) {
        local hasWeapon = false
        foreach (newWeapon in newWeaponBlocks) {
          if (newWeapon?.bulletName && newWeapon.bulletName == weapon?.bulletName) {
            newWeapon.ammo += weapon.ammo
            hasWeapon = true
            break
          }
        }
        if (!hasWeapon) {
          newWeaponBlocks[weaponName] <- (weapon)
        }
      }

      foreach (weaponName, weapon in newWeaponBlocks) {
        if (tText != "" && weapTypeCount == 0)
          tText = $"{tText}{p.newLine}"

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
          if (isShortDesc) {
            if (!(TRIGGER_TYPE.TURRETS in trigger) && gunNames?[weaponName] == null)
              gunNames[weaponName] <- weapon.num
          }
          else {
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
      }

      if (isShortDesc)
        weapTypeCount += (TRIGGER_TYPE.TURRETS in trigger) ? trigger[TRIGGER_TYPE.TURRETS] : 0
      else {
        if (TRIGGER_TYPE.TURRETS in trigger) { // && !unit.unitType.canUseSeveralBulletsForGun)
          if (trigger[TRIGGER_TYPE.TURRETS] > 1)
            tText = "".concat(format(loc("weapons/turret_number"), trigger[TRIGGER_TYPE.TURRETS]), tText)
          else
            tText = "".concat(utf8ToUpper(loc("weapons_types/turrets"), 1), loc("ui/colon"), tText)
        }
      }

      if (tText != "")
        text = $"{text}{(text != "") ? p.newLine : ""}{tText}"
    }
    if (weapTypeCount == 0 && gunNames.len() == 0)
      continue

    text = text != "" ? "".concat(text, p.newLine) : ""
    if (isShortDesc) {
      if (weapTypeCount > 0) //Turrets
        text = "".concat(text, loc($"weapons_types/{weaponType}"), nbsp,
          format(loc("weapons/counter/right/short"), weapTypeCount))
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
        format(loc("weapons/counter"), weapTypeCount))
  }

  if (text == "" && p.needTextWhenNoWeapons)
    text = getTextNoWeapons(unit, p.isPrimary)

  return text
}

function getWeaponNameText(unit, isPrimary = null, weaponPreset = -1, newLine = ", ") {
  return getWeaponInfoText(unit,
    { isPrimary = isPrimary, weaponPreset = weaponPreset, newLine = newLine, detail = INFO_DETAIL.SHORT })
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
}