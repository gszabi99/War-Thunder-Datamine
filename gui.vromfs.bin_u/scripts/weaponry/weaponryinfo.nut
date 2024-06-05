from "%scripts/dagui_natives.nut" import get_option_torpedo_dive_depth_auto, shop_is_weapon_purchased, shop_is_weapon_available, get_option_torpedo_dive_depth
from "%scripts/dagui_library.nut" import *
from "%scripts/weaponry/weaponryConsts.nut" import UNIT_WEAPONS_ZERO, UNIT_WEAPONS_READY, UNIT_WEAPONS_WARNING, INFO_DETAIL

let { get_difficulty_by_ediff } = require("%scripts/difficulty.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { Point2 } = require("dagor.math")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { format } = require("string")
let { get_current_mission_name } = require("mission")
let { set_last_weapon } = require("unitCustomization")
let { eachBlock } = require("%sqstd/datablock.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { getModificationByName, isModificationEnabled } = require("%scripts/weaponry/modificationInfo.nut")
let { AMMO,
        getAmmoCost,
        getAmmoAmount,
        checkAmmoAmount,
        getAmmoMaxAmount } = require("%scripts/weaponry/ammoInfo.nut")
let { saclosMissileBeaconIRSourceBand } = require("%scripts/weaponry/weaponsParams.nut")
let { getMissionEditSlotbarBlk } = require("%scripts/slotbar/slotbarOverride.nut")
let { getUnitPresets, getWeaponsByTypes, getPresetWeapons, getWeaponBlkParams
} = require("%scripts/weaponry/weaponryPresets.nut")
let { getTntEquivalentText, getDestructionInfoTexts } = require("%scripts/weaponry/dmgModel.nut")
let { set_unit_option } = require("guiOptions")
let { getSavedWeapon, getSavedBullets } = require("%scripts/weaponry/savedWeaponry.nut")
let { lastIndexOf, INVALID_INDEX, endsWith } = require("%sqstd/string.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { USEROPT_WEAPONS } = require("%scripts/options/optionsExtNames.nut")
let { shopIsModificationPurchased } = require("chardResearch")
let { getEsUnitType } = require("%scripts/unit/unitInfo.nut")
let { isInFlight } = require("gameplayBinding")
let { getCurMissionRules } = require("%scripts/misCustomRules/missionCustomState.nut")
let { getCurrentGameModeEdiff } = require("%scripts/gameModes/gameModeManagerState.nut")
let { measureType, getMeasureTypeByName } = require("%scripts/measureType.nut")

const KGF_TO_NEWTON = 9.807

let weaponsStatusNameByStatusCode = {
  [UNIT_WEAPONS_ZERO]    = "zero",
  [UNIT_WEAPONS_WARNING] = "warning",
  [UNIT_WEAPONS_READY]   = "ready"
}

let TRIGGER_TYPE = {
  MACHINE_GUN     = "machine gun"
  CANNON          = "cannon"
  ADD_GUN         = "additional gun"
  TURRETS         = "turrets"
  SMOKE           = "smoke"
  FLARES          = "flares"
  CHAFFS          = "chaffs"
  COUNTERMEASURES = "countermeasures"
  BOMBS           = "bombs"
  MINES           = "mines"
  TORPEDOES       = "torpedoes"
  ROCKETS         = "rockets"
  AAM             = "aam"
  AGM             = "agm"
  ATGM            = "atgm"
  GUIDED_BOMBS    = "guided bombs"
  GUNNER          = "gunner"
}

let WEAPON_TYPE = {
  GUNS            = "guns"
  CANNON          = "cannon"
  TURRETS         = "turrets"
  SMOKE           = "smoke"
  FLARES          = "flares"    // Flares (countermeasure)
  CHAFFS          = "chaffs"
  COUNTERMEASURES = "countermeasures"
  BOMBS           = "bombs"
  MINES           = "mines"
  TORPEDOES       = "torpedoes"
  ROCKETS         = "rockets"   // Rockets
  AAM             = "aam"       // Air-to-Air Missiles
  AGM             = "agm"       // Air-to-Ground Missile, Anti-Tank Guided Missiles
  GUIDED_BOMBS    = "guided bombs"
  CONTAINER_ITEM  = "container_item"
}

let CONSUMABLE_TYPES = [ TRIGGER_TYPE.AAM, TRIGGER_TYPE.AGM, TRIGGER_TYPE.ATGM, TRIGGER_TYPE.GUIDED_BOMBS,
  TRIGGER_TYPE.ROCKETS, TRIGGER_TYPE.TORPEDOES, TRIGGER_TYPE.BOMBS, TRIGGER_TYPE.MINES,
  TRIGGER_TYPE.SMOKE, TRIGGER_TYPE.FLARES, TRIGGER_TYPE.CHAFFS, TRIGGER_TYPE.COUNTERMEASURES]

let WEAPON_TAG = {
  ADD_GUN          = "additionalGuns"
  BULLET           = "bullet"
  ROCKET           = "rocket"
  BOMB             = "bomb"
  TORPEDO          = "torpedo"
  FRONT_GUN        = "frontGun"
  CANNON           = "cannon"
}

let WEAPON_TEXT_PARAMS = { //const
  isPrimary             = null //bool or null. When null return descripton for all weaponry.
  weaponPreset          = -1 //int weaponIndex or string weapon name
  newLine               = "\n" //weapons delimeter
  detail                = INFO_DETAIL.FULL
  needTextWhenNoWeapons = true
  ediff                 = null //int. when not set, uses getCurrentGameModeEdiff() function
  isLocalState          = true //should apply my local parameters to unit (modifications, crew skills, etc)
  weaponsFilterFunc     = null //function. When set, only filtered weapons are collected from weaponPreset.
  isSingle              = false //should ignore ammo count
}

function isWeaponAux(weapon) {
  local aux = false
  foreach (tag in weapon.tags)
    if (tag == "aux") {
      aux = true
      break
    }
  return aux
}

function isWeaponEnabled(unit, weapon) {
  return shop_is_weapon_available(unit.name, weapon.name, true, false) //no point to check purchased unit even in respawn screen
         //temporary hack: check ammo amount for forced units by mission,
         //because shop_is_weapon_available function work incorrect with them
         && (!::is_game_mode_with_spendable_weapons()
             || getAmmoAmount(unit, weapon.name, AMMO.WEAPON)
             || !getAmmoMaxAmount(unit, weapon.name, AMMO.WEAPON)
            )
         && (!isInFlight() || getCurMissionRules().isUnitWeaponAllowed(unit, weapon))
}

let getWeaponDisabledMods = @(unit, weapon)
  shop_is_weapon_available(unit.name, weapon.name, true, false)
    ? []
    : (weapon?.reqModification.filter(@(n) !isModificationEnabled(unit.name, n)) ?? [])

let isDefaultTorpedoes = @(weapon) weapon?.reqModification.contains("ship_torpedoes") ?? false

function isWeaponVisible(unit, weapon, onlySelectable = true, weaponTags = null) {
  if (isWeaponAux(weapon))
    return false

  if (weaponTags != null) {
    local hasTag = false
    foreach (t in weaponTags)
      if (weapon?[t]) {
        hasTag = true
        break
      }
    if (!hasTag)
      return false
  }

  if (onlySelectable
      && ((!shop_is_weapon_purchased(unit.name, weapon.name)
        && getAmmoCost(unit, weapon.name, AMMO.WEAPON) > ::zero_money)
        || getWeaponDisabledMods(unit, weapon).len() > 0))
    return false

  return true
}

function getLastWeapon(unitName) {
  let res = getSavedWeapon(unitName)
  if (res != "")
    return res

  //validate last_weapon value
  let unit = getAircraftByName(unitName)
  if (!unit)
    return res
  foreach (weapon in unit.getWeapons())
    if (isWeaponVisible(unit, weapon)
        && isWeaponEnabled(unit, weapon)) {
      set_unit_option(unitName, USEROPT_WEAPONS, weapon.name)
      set_last_weapon(unitName, weapon.name)
      return weapon.name
    }
  return res
}

let getWeaponByName = @(unit, weaponName) unit?.getWeapons().findvalue(@(w) w.name == weaponName)

function validateLastWeapon(unitName) {
  let weaponName = getSavedWeapon(unitName)
  if (weaponName == "")
    return ""

  let unit = getAircraftByName(unitName)
  if (!unit)
    return ""

  let curWeapon = getWeaponByName(unit, weaponName)
  if (curWeapon != null && isWeaponVisible(unit, curWeapon) && isWeaponEnabled(unit, curWeapon))
    return weaponName

  foreach (weapon in unit.getWeapons())
    if (isWeaponVisible(unit, weapon) && isWeaponEnabled(unit, weapon)) {
      set_unit_option(unitName, USEROPT_WEAPONS, weapon.name)
      set_last_weapon(unitName, weapon.name)
      return weapon.name
    }

  return ""
}

function setLastWeapon(unitName, weaponName) {
  if (weaponName == getLastWeapon(unitName))
    return

  set_unit_option(unitName, USEROPT_WEAPONS, weaponName)
  set_last_weapon(unitName, weaponName)
  broadcastEvent("UnitWeaponChanged", { unitName = unitName, weaponName = weaponName })
}

function getWeaponNameByBlkPath(weaponBlkPath) {
  let idxLastSlash = lastIndexOf(weaponBlkPath, "/")
  let idxStart = idxLastSlash != INVALID_INDEX ? (idxLastSlash + 1) : 0
  let idxEnd = endsWith(weaponBlkPath, ".blk") ? -4 : weaponBlkPath.len()
  return weaponBlkPath.slice(idxStart, idxEnd)
}

let skipWeaponParams = { num = true, ammo = true, tiers = true, additionalMassKg = true }
function isWeaponParamsEqual(item1, item2) {
  if (!item1?.len() || !item2?.len())
    return false
  foreach (key, val in item1)
    if ((key not in skipWeaponParams) && !u.isEqual(val, item2?[key]))
      return false
  return true
}

function isCaliberCannon(caliber_mm) {
  return caliber_mm >= 15
}

function addWeaponsFromBlk(weapons, weaponsArr, unit, weaponsFilterFunc = null, wConf = null) {
  let weaponBlkCache = {}
  let unitType = getEsUnitType(unit)
  if (weapons?.hasSweepRange == null)
    weapons.hasSweepRange <- false

  foreach (weapon in weaponsArr) {
    if (weapon?.dummy
      || (weapon?.triggerGroup == "commander" && weapon?.bullets == null))
      continue

    if (!weapon?.blk)
      continue

    let { weaponBlk, weaponBlkPath, bulletsCount, containerMassKg } = getWeaponBlkParams(weapon.blk, weaponBlkCache)

    if (weaponsFilterFunc?(weaponBlkPath, weaponBlk) == false)
      continue
    let bulletName = weaponBlk?.rocket?.bulletName
      ?? weaponBlk?.payload?.bulletName
      ?? weaponBlk?.bomb?.bulletName

    local currentTypeName =  weapon?.turret != null ? WEAPON_TYPE.TURRETS : WEAPON_TYPE.CONTAINER_ITEM
    local weaponTag = WEAPON_TAG.BULLET

    if (weaponBlk?.rocketGun) {
      currentTypeName = ""
      if (weapon?.trigger)
        if (weapon.trigger == TRIGGER_TYPE.AGM || weapon.trigger == TRIGGER_TYPE.ATGM)
          currentTypeName = WEAPON_TYPE.AGM
        else if (weapon.trigger == TRIGGER_TYPE.AAM)
          currentTypeName = WEAPON_TYPE.AAM
        else if (weapon.trigger == TRIGGER_TYPE.FLARES)
          currentTypeName = WEAPON_TYPE.FLARES
        else if (weapon.trigger == TRIGGER_TYPE.CHAFFS)
          currentTypeName = WEAPON_TYPE.CHAFFS
        else if (weapon.trigger == TRIGGER_TYPE.COUNTERMEASURES)
          currentTypeName = WEAPON_TYPE.COUNTERMEASURES
        else
          currentTypeName = WEAPON_TYPE.ROCKETS

      if (weapon?.triggerGroup == "smoke")
        currentTypeName = WEAPON_TYPE.SMOKE
      weaponTag = WEAPON_TAG.ROCKET
    }
    else if (weaponBlk?.bombGun) {
      if (weapon?.trigger == TRIGGER_TYPE.MINES)
        currentTypeName = WEAPON_TYPE.MINES
      else if (weapon?.trigger == TRIGGER_TYPE.GUIDED_BOMBS)
        currentTypeName = WEAPON_TYPE.GUIDED_BOMBS
      else
        currentTypeName = WEAPON_TYPE.BOMBS
      weaponTag = WEAPON_TAG.BOMB
    }
    else if (weaponBlk?.torpedoGun) {
      currentTypeName = WEAPON_TYPE.TORPEDOES
      weaponTag = WEAPON_TAG.TORPEDO
    }
    else if (unitType == ES_UNIT_TYPE_TANK ||
      isInArray(weapon.trigger, [ TRIGGER_TYPE.MACHINE_GUN, TRIGGER_TYPE.CANNON,
        TRIGGER_TYPE.ADD_GUN, TRIGGER_TYPE.ROCKETS, TRIGGER_TYPE.AGM, TRIGGER_TYPE.AAM,
        TRIGGER_TYPE.GUIDED_BOMBS, TRIGGER_TYPE.BOMBS, TRIGGER_TYPE.TORPEDOES, TRIGGER_TYPE.SMOKE,
        TRIGGER_TYPE.FLARES, TRIGGER_TYPE.CHAFFS, TRIGGER_TYPE.COUNTERMEASURES])) { //not a turret
      currentTypeName = weapon.trigger == TRIGGER_TYPE.COUNTERMEASURES ? WEAPON_TYPE.COUNTERMEASURES : WEAPON_TYPE.GUNS
      if (weaponBlk?.bullet && type(weaponBlk?.bullet) == "instance"
          && isCaliberCannon(1000 * getTblValue("caliber", weaponBlk?.bullet, 0)))
        currentTypeName = WEAPON_TYPE.CANNON
    }
    else if (!(weapon?.showInWeaponMenu ?? false)
        && (weaponBlk?.fuelTankGun || weaponBlk?.boosterGun || weaponBlk?.airDropGun || weaponBlk?.undercarriageGun))
      continue

    let isTurret = currentTypeName == WEAPON_TYPE.TURRETS

    let item = {
      turret = null
      ammo = 0
      num = 0
      caliber = 0
      // masses of ammo
      massKg = 0
      massLbs = 0
      // mass of a weapon itself (container, gun, etc)
      additionalMassKg = 0
      explosiveType = null
      explosiveMass = 0
      hasAdditionalExplosiveInfo = true
      dropSpeedRange = null
      dropHeightRange = null
      iconType = null
      amountPerTier = null
      isGun = null
      bulletType = null
      presetId = null
      tiers = {}
      dependentWeaponPreset = {}
      bannedWeaponPreset = {}
      blk = ""
      bulletName
    }


    if ( weapon?.sweepRange )
      weapons.hasSweepRange = true

    if (wConf)
      foreach (wc in (wConf % "Weapon"))
        if (weaponBlkPath.tolower() == wc.blk.tolower()) {
          item.iconType <- wc?.iconType
          item.amountPerTier <- wc?.amountPerTier
          foreach (t in (wc % "tier"))
            item.tiers[t.idx] <- {
              amountPerTier = t?.amountPerTier
              iconType = t?.iconType
              tooltipLang = t?.tooltipLang
            }
          break
        }

    let bulletCount = weapon?.bullets ?? bulletsCount
    let hasWeaponSlots = "slot" in weapon
    let additionalMassKg = (weapon?.mass ?? weaponBlk?.mass ?? 0) + containerMassKg
    if (hasWeaponSlots) {
      item.presetId = weapon.presetId
      item.tiers[weapon.tier] <- {
        presetId = weapon.presetId
        slot = weapon.slot
        iconType = weapon?.iconType
        amountPerTier = bulletCount
        reqModification = weapon?.reqModification
        additionalMassKg
      }
      foreach (dependentWeapon in (weapon % "dependentWeaponPreset")) {
        let dependentWeapons = item.dependentWeaponPreset?[dependentWeapon.preset] ?? []
        item.dependentWeaponPreset[dependentWeapon.preset] <- dependentWeapons.append({
          slot = dependentWeapon.slot
          reqForPresetId = weapon.presetId
          reqForTier = weapon.tier
        })
      }
      foreach (bannedWeapon in (weapon % "bannedWeaponPreset")) {
        let bannedWeapons = item.bannedWeaponPreset?[bannedWeapon.preset] ?? []
        item.bannedWeaponPreset[bannedWeapon.preset] <- bannedWeapons.append({
          slot = bannedWeapon.slot
          bannedByPresetId = weapon.presetId
          bannedByTier = weapon.tier
        })
      }
    }
    let needBulletParams = !isInArray(currentTypeName,
      [WEAPON_TYPE.SMOKE, WEAPON_TYPE.FLARES, WEAPON_TYPE.CHAFFS, WEAPON_TYPE.COUNTERMEASURES])

    // targeting pods
    if (weaponBlk?.payload) {
      item.massKg = weaponBlk.payload?.mass ?? item.massKg
      item.massLbs = weaponBlk.payload?.mass_lbs ?? item.massLbs
    }

    if (currentTypeName == WEAPON_TYPE.COUNTERMEASURES)
      item.massKg = weaponBlk?.mass ?? item.massKg

    if (needBulletParams && weaponTag.len() && weaponBlk?[weaponTag]) {
      let itemBlk = weaponBlk[weaponTag]
      let isGun = isInArray(currentTypeName, [WEAPON_TYPE.GUNS, WEAPON_TYPE.CANNON])
      item.isGun = isGun
      item.caliber = itemBlk?.caliber ?? item.caliber
      item.massKg = itemBlk?.mass ?? item.massKg
      item.massLbs = itemBlk?.mass_lbs ?? item.massLbs
      item.explosiveType = itemBlk?.explosiveType ?? item.explosiveType
      item.explosiveMass = itemBlk?.explosiveMass ?? item.explosiveMass
      item.hasAdditionalExplosiveInfo = itemBlk?.fireDamage == null
      item.iconType = isGun ? weaponBlk?.iconType : item.iconType ?? itemBlk?.iconType
      item.amountPerTier = isGun ? weaponBlk?.amountPerTier
        : item.amountPerTier ?? itemBlk?.amountPerTier
      item.bulletType = itemBlk?.bulletType
      item.blk = weaponBlkPath

      item.armDistance <- itemBlk?.armDistance ?? 0
      if (isInArray(currentTypeName, [ WEAPON_TYPE.ROCKETS, WEAPON_TYPE.AGM, WEAPON_TYPE.AAM, WEAPON_TYPE.GUIDED_BOMBS ])) {
        item.machMax  <- itemBlk?.machMax ?? 0
        item.maxSpeed <- (itemBlk?.maxSpeed ?? 0) || (itemBlk?.endSpeed ?? 0)
        if ((itemBlk?.guaranteedRange ?? 0) != 0)
          item.guaranteedRange <- itemBlk.guaranteedRange

        if (itemBlk?.guidance != null || itemBlk?.operated == true) {
          if (itemBlk?.operated == true) {
            item.autoAiming <- itemBlk?.autoAiming ?? false
            item.isBeamRider <- itemBlk?.isBeamRider ?? false
            if (itemBlk?.irBeaconBand)
              if (itemBlk.irBeaconBand != saclosMissileBeaconIRSourceBand.value)
                item.guidanceIRCCM <- true
          }
          else
            item.guidanceType <- itemBlk?.guidanceType

          if ((itemBlk?.rangeMax ?? 0) != 0)
            item.launchRange <- itemBlk.rangeMax

          if ((itemBlk?.timeLife ?? 0) != 0)
            item.timeLife <- itemBlk.timeLife

          if (itemBlk?.guidance != null) {
            if (itemBlk.guidance?.lineOfSightAutopilot != null) {
              if (itemBlk?.guidance.beamRider)
                item.guidanceType <- "beamRiding"
              if (itemBlk?.guidance.beaconBand)
                if (itemBlk?.guidance.beaconBand != saclosMissileBeaconIRSourceBand.value)
                  item.guidanceIRCCM <- true
            }
            if (itemBlk.guidance?.irSeeker != null) {
              let targetSignatureType = itemBlk.guidance.irSeeker?.targetSignatureType != null ?
                itemBlk.guidance.irSeeker?.targetSignatureType : itemBlk.guidance.irSeeker?.visibilityType
              if (targetSignatureType == "optic")
                item.guidanceType <- "tv"
              else
                item.guidanceType <- "ir"
              let rangeRearAspect = itemBlk.guidance.irSeeker?.rangeBand0 ?? 0
              let rangeAllAspect  = itemBlk.guidance.irSeeker?.rangeBand1 ?? 0
              if (currentTypeName == WEAPON_TYPE.AAM) {
                item.seekerRangeRearAspect <- rangeRearAspect
                item.seekerRangeAllAspect  <- rangeAllAspect
                if (rangeRearAspect > 0 || rangeAllAspect > 0)
                  item.allAspect <- rangeAllAspect >= 1000.0
              }
              else if (currentTypeName == WEAPON_TYPE.AGM && (itemBlk.guidance.irSeeker?.groundVehiclesAsTarget ?? false)) {
                if (rangeRearAspect > 0 || rangeAllAspect > 0)
                  item.seekerRange <- min(rangeRearAspect, rangeAllAspect)
              }
              if ((itemBlk?.guidanceType == "ir" || itemBlk?.guidanceType == "tv") &&
                  itemBlk.guidance.irSeeker?.gateWidth != null && itemBlk.guidance.irSeeker.gateWidth < itemBlk.guidance.irSeeker.fov)
                item.seekerIRCCM <- true
              if (itemBlk?.guidanceType == "ir" && (itemBlk.guidance.irSeeker?.bandMaskToReject ?? 0) != 0)
                item.seekerIRCCM <- true
            }
            else if (itemBlk.guidance?.opticalFlowSeeker != null) {
              let targetSignatureType = itemBlk.guidance?.opticalFlowSeeker != null ?
                itemBlk.guidance?.opticalFlowSeeker?.targetSignatureType : itemBlk.guidance?.opticalFlowSeeker?.visibilityType
              if (targetSignatureType == "optic")
                item.guidanceType <- "tv"
              else
                item.guidanceType <- "ir"
            }
            if (itemBlk.guidance?.radarSeeker != null) {
              let active = itemBlk.guidance.radarSeeker?.active ?? false
              item.guidanceType <- active ? "ARH" : "SARH"
              item.radarBand <- itemBlk.guidance.radarSeeker?.band ?? 8
              item.groundClutter <- itemBlk.guidance.radarSeeker?.groundClutter ?? true
              item.sideLobesSensitivity <- itemBlk.guidance.radarSeeker?.receiver.antenna.sideLobesSensitivity ?? 0.0
              local dopplerSpeed = false
              if (itemBlk.guidance.radarSeeker?.dopplerSpeed != null)
                dopplerSpeed = itemBlk.guidance.radarSeeker.dopplerSpeed?.presents ?? false
              item.dopplerSpeed <- dopplerSpeed
              if (itemBlk.guidance.radarSeeker?.receiver != null) {
                let range = itemBlk.guidance.radarSeeker.receiver?.range ?? 0
                item.seekerRange <- range
              }
            }
            else {
              item.groundClutter <- true
              item.sideLobesSensitivity <- 0.0
              item.dopplerSpeed <- false
            }
            if (itemBlk.guidance?.inertialNavigation)
              item.guidanceType = "".concat(item.guidanceType, "+IOG")
            if (itemBlk.guidance?.inertialGuidance.datalink != null)
              item.guidanceType = "".concat(item.guidanceType, "+DL")
          }
        }
        if (currentTypeName == WEAPON_TYPE.AAM) {
          item.loadFactorMax <- itemBlk?.loadFactorMax ?? 0
          if (weapon?.loadFactorLimit)
            item.loadFactorLimit <- weapon.loadFactorLimit
        }
        else if (currentTypeName == WEAPON_TYPE.AGM) {
          item.operatedDist <- itemBlk?.operatedDist ?? 0
        }
      }
      else  if (currentTypeName == WEAPON_TYPE.TORPEDOES) {
        item.dropSpeedRange = itemBlk.getPoint2("dropSpeedRange", Point2(0, 0))
        if (item.dropSpeedRange.x == 0 && item.dropSpeedRange.y == 0)
          item.dropSpeedRange = null
        item.dropHeightRange = itemBlk.getPoint2("dropHeightRange", Point2(0, 0))
        if (item.dropHeightRange.x == 0 && item.dropHeightRange.y == 0)
          item.dropHeightRange = null
        item.maxSpeedInWater <- itemBlk?.maxSpeedInWater ?? 0
        item.distToLive <- itemBlk?.distToLive ?? 0
        item.diveDepth <- itemBlk?.diveDepth ?? 0
      }

      if (weapon?.machLimit) {
        if (currentTypeName == WEAPON_TYPE.BOMBS || currentTypeName == WEAPON_TYPE.GUIDED_BOMBS)
          item.machLimit <- weapon.machLimit
        if (weapon?.trigger == TRIGGER_TYPE.ROCKETS || weapon?.trigger == TRIGGER_TYPE.ATGM)
          item.machLimitRockets <- weapon.machLimit
      }

      if ([ WEAPON_TYPE.AGM, WEAPON_TYPE.ROCKETS].contains(currentTypeName)) {
        if (itemBlk?.strikingPart != null)
          item.warhead <- "multidart"
        else if (itemBlk?.smokeShell == true)
          item.warhead <- "smoke"
        else if (itemBlk?.cumulativeDamage.armorPower != null)
          item.warhead <- itemBlk?.kineticDamage.damageType == "tandemPrecharge" ? "tandem" : "heat"
        else if (item.explosiveType != null)
          item.warhead <- itemBlk?.armorpower != null ? "aphe" : "he"
        else if (itemBlk?.armorpower != null)
          item.warhead <- "ap"
      }
    }

    if (isTurret && (weapon?.turret != null)) {
      let turretInfo = weapon.turret
      item.turret = u.isDataBlock(turretInfo) ? turretInfo.head : turretInfo
    }

    weapons.weaponsByTypes <- weapons?.weaponsByTypes ?? {}
    if (!(currentTypeName in weapons.weaponsByTypes))
      weapons.weaponsByTypes[ currentTypeName ] <- []

    local weaponName = getWeaponNameByBlkPath(weaponBlkPath)
    local trIdx = -1
    foreach (idx, t in weapons.weaponsByTypes[currentTypeName])
      if (weapon.trigger == t.trigger || isWeaponParamsEqual(item, t?.weaponBlocks[weaponName])) {
        trIdx = idx
        break
      }

    // Merging duplicating weapons with different weaponName
    // (except guns, because there exists different guns with equal params)
    if (trIdx >= 0 && (weaponName not in weapons.weaponsByTypes[currentTypeName][trIdx]?.weaponBlocks) && weaponTag != WEAPON_TAG.BULLET)
      foreach (name, existingItem in weapons.weaponsByTypes[currentTypeName][trIdx].weaponBlocks)
        if (isWeaponParamsEqual(item, existingItem)) {
          weaponName = name
          break
        }

    if (trIdx < 0) {
      weapons.weaponsByTypes[currentTypeName].append({ trigger = weapon.trigger, caliber = 0 })
      trIdx = weapons.weaponsByTypes[currentTypeName].len() - 1
    }

    let currentType = weapons.weaponsByTypes[currentTypeName][trIdx]

    if (weaponName not in currentType?.weaponBlocks) {
      currentType.weaponBlocks <- currentType?.weaponBlocks ?? {}
      currentType.weaponBlocks[weaponName] <- item
      if (item.caliber > currentType.caliber)
        currentType.caliber = item.caliber
    }
    else if (hasWeaponSlots) {
      foreach (tierIdx, tier in item.tiers) {
        let tierPreset = currentType.weaponBlocks[weaponName].tiers?[tierIdx]
        if (tierPreset == null) {
          currentType.weaponBlocks[weaponName].tiers[tierIdx] <- tier
          continue
        }

        if (tierPreset.presetId == tier.presetId && tierPreset.slot == tier.slot && tierPreset.iconType == tier.iconType)
          tierPreset.amountPerTier += tier.amountPerTier
      }
      foreach (dependentWeaponName, dependentWeapon in item.dependentWeaponPreset) {
        let dependentWeaponPreset = currentType.weaponBlocks[weaponName].dependentWeaponPreset?[dependentWeaponName] ?? []
        currentType.weaponBlocks[weaponName].dependentWeaponPreset[dependentWeaponName] <-
          dependentWeaponPreset.extend(dependentWeapon)
      }
      foreach (bannedWeaponName, bannedWeapon in item.bannedWeaponPreset) {
        let bannedWeaponPreset = currentType.weaponBlocks[weaponName].bannedWeaponPreset?[bannedWeaponName] ?? []
        currentType.weaponBlocks[weaponName].bannedWeaponPreset[bannedWeaponName] <-
          bannedWeaponPreset.extend(bannedWeapon)
      }
    }

    currentType.weaponBlocks[weaponName].additionalMassKg += additionalMassKg
    currentType.weaponBlocks[weaponName].num += 1
    currentType.weaponBlocks[weaponName].ammo += bulletCount
  }

  return weapons
}

//weapon - is a weaponData gathered by addWeaponsFromBlk
local function getWeaponExtendedInfo(weapon, weaponType, unit, ediff, newLine) {
  let res = []
  let colon = loc("ui/colon")

  local massText = null
  if (weapon.massLbs > 0)
    massText = getMeasureTypeByName("lbs", true).getMeasureUnitsText(weapon.massLbs)
  else if (weapon.massKg > 0)
    massText = getMeasureTypeByName("kg", true).getMeasureUnitsText(weapon.massKg)
  if (massText)
    res.append("".concat(loc("shop/tank_mass"), " ", massText))

  if (isInArray(weaponType, [ "rockets", "agm", "aam", "guided bombs" ])) {
    if (weapon?.guidanceType != null || weapon?.autoAiming != null) {
      let aimingType = weapon?.autoAiming == null ? ""
        : weapon.autoAiming && weapon.isBeamRider ? "beamRiding"
        : weapon.autoAiming ? "semiautomatic"
        : "manual"
      let guidanceTxt = aimingType != ""
        ? loc($"missile/aiming/{aimingType}")
        : loc($"missile/guidance/{weapon.guidanceType}")
      res.append("".concat(loc("missile/guidance"), colon, guidanceTxt))
      if (weapon?.guidanceIRCCM)
        res.append("".concat(loc("missile/irccm"), colon, loc("options/yes")))
    }
    if (weapon?.allAspect != null)
      res.append("".concat(loc("missile/aspect"), colon,
        loc("missile/aspect/{0}".subst(weapon.allAspect ? "allAspect" : "rearAspect"))))
    if (weapon?.radarBand)
      res.append("".concat(loc("missile/radarBand"), colon, loc($"radar_freq_band_{weapon.radarBand}")))
    if (weapon?.groundClutter != null && weapon?.dopplerSpeed != null)
      if (!weapon.groundClutter || weapon.dopplerSpeed) {
        let allAspects = !weapon?.groundClutter || (weapon?.sideLobesSensitivity != null && weapon.sideLobesSensitivity < -26.0)
        res.append("".concat(loc("missile/shootDown"), colon, allAspects ? loc("missile/shootDown/allAspects") : loc("missile/shootDown/headOnAspect")))
      }
    if (weapon?.seekerRangeRearAspect)
      res.append("".concat(loc("missile/seekerRange/rearAspect"), colon,
        measureType.DISTANCE.getMeasureUnitsText(weapon.seekerRangeRearAspect)))
    if (weapon?.seekerRangeAllAspect)
      res.append("".concat(loc("missile/seekerRange/allAspect"), colon,
        measureType.DISTANCE.getMeasureUnitsText(weapon.seekerRangeAllAspect)))
    if (weapon?.seekerRange)
      res.append("".concat(loc("missile/seekerRange"), colon,
        measureType.DISTANCE.getMeasureUnitsText(weapon.seekerRange)))
    if (weapon?.seekerIRCCM)
      res.append("".concat(loc("missile/irccm"), colon, loc("options/yes")))
    if (weapon?.launchRange)
      res.append("".concat(loc("missile/launchRange"), colon,
        measureType.DISTANCE.getMeasureUnitsText(weapon.launchRange)))
    if (weapon?.machMax)
      res.append("".concat(loc("rocket/maxSpeed"), colon,
        format("%.1f %s", weapon.machMax, loc("measureUnits/machNumber"))))
    else if (weapon?.maxSpeed)
      res.append("".concat(loc("rocket/maxSpeed"), colon,
        measureType.SPEED_PER_SEC.getMeasureUnitsText(weapon.maxSpeed)))
    if (weapon?.loadFactorMax)
      res.append("".concat(loc("missile/loadFactorMax"), colon,
        measureType.GFORCE.getMeasureUnitsText(weapon.loadFactorMax)))
    if (weapon?.loadFactorLimit)
      res.append("".concat(loc("missile/loadFactorLimit"), colon,
        measureType.GFORCE.getMeasureUnitsText(weapon.loadFactorLimit)))
    if (weapon?.operatedDist)
      res.append("".concat(loc("firingRange"), colon,
        measureType.DISTANCE.getMeasureUnitsText(weapon.operatedDist)))
    if (weapon?.guaranteedRange)
      res.append("".concat(loc("guaranteedRange"), colon,
        measureType.DISTANCE.getMeasureUnitsText(weapon.guaranteedRange)))
    if (weapon?.timeLife) {
      if (weapon?.guidanceType != null || weapon?.autoAiming != null)
        res.append("".concat(loc("missile/timeGuidance"), colon,
          format("%.1f %s", weapon.timeLife, loc("measureUnits/seconds"))))
      else
        res.append("".concat(loc("missile/timeSelfdestruction"), colon,
          format("%.1f %s", weapon.timeLife, loc("measureUnits/seconds"))))
    }
    if (weapon?.armDistance)
      res.append("".concat(loc("missile/armingDistance"), colon,
        measureType.DEPTH.getMeasureUnitsText(weapon?.armDistance)))
  }
  else if (weaponType == "torpedoes") {
    let torpedoMod = "torpedoes_movement_mode"
    if (isModificationEnabled(unit.name, torpedoMod)) {
      let mod = getModificationByName(unit, torpedoMod)
      let diffId = get_difficulty_by_ediff(ediff ?? getCurrentGameModeEdiff()).crewSkillName
      let effects = mod?.effects?[diffId]
      let weaponEffects = effects?.weapons
      if (weaponEffects) {
        weapon = clone weapon
        foreach (weaponMod in weaponEffects) {
          let torpedoAffected = weaponMod?.torpedoAffected ?? ""
          if (weaponMod && (torpedoAffected == "" || torpedoAffected == weapon.blk)) {
            foreach (k, v in weapon) {
              let kEffect = $"{k}Torpedo"
              if ((kEffect in weaponMod) && type(v) == type(weaponMod[kEffect]))
                weapon[k] += weaponMod[kEffect]
            }
          }
        }
      }
    }

    if (weapon?.maxSpeedInWater)
      res.append("".concat(loc("torpedo/maxSpeedInWater"), colon,
        measureType.SPEED.getMeasureUnitsText(weapon?.maxSpeedInWater)))

    if (weapon?.distToLive)
      res.append("".concat(loc("torpedo/distanceToLive"), colon,
        measureType.DISTANCE.getMeasureUnitsText(weapon?.distToLive)))

    if (weapon?.diveDepth) {
      let diveDepth = [unitTypes.SHIP, unitTypes.BOAT].contains(unit.unitType) && !get_option_torpedo_dive_depth_auto()
          ? get_option_torpedo_dive_depth()
          : weapon?.diveDepth
      res.append("".concat(loc("bullet_properties/diveDepth"), colon,
        measureType.DEPTH.getMeasureUnitsText(diveDepth)))
    }

    if (weapon?.armDistance)
      res.append("".concat(loc("torpedo/armingDistance"), colon,
        measureType.DEPTH.getMeasureUnitsText(weapon?.armDistance)))
  }

  if (weapon?.machLimit)
    res.append("".concat(loc("bombProperties/machLimit"), colon,
      format("%.1f %s", weapon.machLimit, loc("measureUnits/machNumber"))))

  if (weapon?.machLimitRockets)
    res.append("".concat(loc("rocketProperties/machLimit"), colon,
      format("%.1f %s", weapon.machLimitRockets, loc("measureUnits/machNumber"))))

  if (weapon.explosiveType != null) {
    let { explosiveType, explosiveMass, massKg, hasAdditionalExplosiveInfo } = weapon
    res.append("".concat(loc("bullet_properties/explosiveType"), colon,
      loc($"explosiveType/{explosiveType}")))
    if (explosiveMass) {
      let kg = getMeasureTypeByName("kg", true)
      res.append("".concat(loc("bullet_properties/explosiveMass"), colon,
        kg.getMeasureUnitsText(explosiveMass)))
      if (hasAdditionalExplosiveInfo) {
        let tntEqText = getTntEquivalentText(explosiveType, explosiveMass)
        if (tntEqText.len())
          res.append("".concat(loc("bullet_properties/explosiveMassInTNTEquivalent"), colon, tntEqText))

        if (weaponType == "bombs" && unit.unitType != unitTypes.SHIP) {
          let destrTexts = getDestructionInfoTexts(explosiveType, explosiveMass, massKg)
          foreach (key in ["maxArmorPenetration", "destroyRadiusArmored", "destroyRadiusNotArmored"]) {
            let valueText = destrTexts[$"{key}Text"]
            if (valueText.len())
              res.append("".concat(loc($"bombProperties/{key}"), colon, valueText))
          }
        }
      }
    }
  }
  if (weapon?.warhead)
    res.append("".concat(loc("rocket/warhead"), colon,
      loc("rocket/warhead/{0}".subst(weapon.warhead))))
  return "".concat(res.len() ? newLine : "", newLine.join(res))
}

function getPrimaryWeaponsList(unit) {
  if (unit.primaryWeaponMods)
    return unit.primaryWeaponMods

  unit.primaryWeaponMods = [""]

  let airBlk = ::get_full_unit_blk(unit.name)
  if (!airBlk?.modifications)
    return unit.primaryWeaponMods

  eachBlock(airBlk.modifications, function(modification, modName) {
    if (modification?.effects.commonWeapons)
      unit.primaryWeaponMods.append(modName)
  })

  return unit.primaryWeaponMods
}

function getLastPrimaryWeapon(unit) {
  let primaryList = getPrimaryWeaponsList(unit)
  foreach (modName in primaryList)
    if (modName != "" && isModificationEnabled(unit.name, modName))
      return modName
  return ""
}

function getCommonWeapons(unitBlk, primaryMod) {
  let res = []
  if (primaryMod == "" && unitBlk?.commonWeapons)
    return getWeaponsByTypes(unitBlk, unitBlk.commonWeapons)

  if (unitBlk?.modifications == null)
    return res

  let modificationsCount = unitBlk.modifications.blockCount()
  for (local i = 0; i < modificationsCount; i++) {
    let modification = unitBlk.modifications.getBlock(i)
    if (modification.getBlockName() == primaryMod) {
      if (modification?.effects.commonWeapons)
        return getWeaponsByTypes(unitBlk, modification.effects.commonWeapons)

      break
    }
  }

  return res
}

local function getUnitWeaponry(unit, p = WEAPON_TEXT_PARAMS) {
  if (!unit)
    return null

  let unitBlk = ::get_full_unit_blk(unit.name)
  if (!unitBlk)
    return null

  local weapons = {}
  p = WEAPON_TEXT_PARAMS.__merge(p)
  local primaryMod = ""
  local weaponPresetIdx = -1
  if ((type(p.weaponPreset) == "string") || p.weaponPreset < 0) {
    if (!p.isPrimary) {
      let curWeap = (type(p.weaponPreset) == "string") ? p.weaponPreset : getLastWeapon(unit.name)
      foreach (idx, w in unit.getWeapons())
        if (w.name == curWeap || (weaponPresetIdx < 0 && !isWeaponAux(w)))
          weaponPresetIdx = idx
      if (weaponPresetIdx < 0)
        return weapons
    }
    if (p.isPrimary && type(p.weaponPreset) == "string")
      primaryMod = p.weaponPreset
    else
      primaryMod = getLastPrimaryWeapon(unit)
  }
  else
    weaponPresetIdx = p.weaponPreset

  if (p.isPrimary || p.isPrimary == null)
    weapons = addWeaponsFromBlk({}, getCommonWeapons(unitBlk, primaryMod), unit, p.weaponsFilterFunc)

  if (!p.isPrimary) {
    let weapon = unit.getWeapons()?[weaponPresetIdx]
    let curPreset = weapon != null ? getUnitPresets(unitBlk).findvalue(@(v) v.name == weapon.name) : null
    weapons = addWeaponsFromBlk(weapons, getPresetWeapons(unitBlk, weapon),
      unit, p.weaponsFilterFunc, curPreset?.weaponConfig)
  }

  return weapons
}

function getSecondaryWeaponsList(unit) {
  let weaponsList = []
  let unitName = unit.name
  let lastWeapon = getSavedWeapon(unitName)
  foreach (weapon in unit.getWeapons()) {
    if (isWeaponAux(weapon))
      continue

    weaponsList.append(weapon)
    if (lastWeapon == "" && shop_is_weapon_purchased(unitName, weapon.name))
      setLastWeapon(unitName, weapon.name)  //!!FIX ME: remove side effect from getter
  }

  return weaponsList
}

function getPresetsList(unit, chooseMenuList) {
  if (!chooseMenuList)
    return getSecondaryWeaponsList(unit)

  let weaponsList = []
  foreach (item in chooseMenuList)
    weaponsList.append(item.weaponryItem.__merge({ isEnabled = item.enabled }))
  return weaponsList
}

let getWeaponsStatusName = @(weaponsStatus) weaponsStatusNameByStatusCode[weaponsStatus]

function isWeaponUnlocked(unit, weapon) {
  foreach (rp in ["reqWeapon", "reqModification"])
      if (rp in weapon)
        foreach (req in weapon[rp])
          if (rp == "reqWeapon" && !shop_is_weapon_purchased(unit.name, req))
            return false
          else if (rp == "reqModification" && !shopIsModificationPurchased(unit.name, req))
            return false
  return true
}

function isUnitHaveAnyWeaponsTags(unit, tags, checkPurchase = true) {
  if (!unit)
    return false

  foreach (w in unit.getWeapons())
    if (shop_is_weapon_purchased(unit.name, w.name) > 0 || !checkPurchase)
      foreach (tag in tags)
        if ((tag in w) && w[tag])
          return true
  return false
}

function getLinkedGunIdx(groupIdx, totalGroups, bulletSetsQuantity, canBeDuplicate = true) {
  if (!canBeDuplicate)
    return groupIdx
  return (groupIdx.tofloat() * totalGroups / bulletSetsQuantity + 0.001).tointeger()
}

function checkUnitSecondaryWeapons(unit) {
  foreach (weapon in getSecondaryWeaponsList(unit))
    if (isWeaponEnabled(unit, weapon) ||
      (::isUnitUsable(unit) && isWeaponUnlocked(unit, weapon))) {
      let res = checkAmmoAmount(unit, weapon.name, AMMO.WEAPON)
      if (res != UNIT_WEAPONS_READY)
        return res
    }

  return UNIT_WEAPONS_READY
}

let checkUnitLastWeapon = @(unit) checkAmmoAmount(unit, getLastWeapon(unit.name), AMMO.WEAPON)

function checkUnitBullets(unit, isCheckAll = false, bulletSet = null) {
  let setLen = bulletSet?.len() ?? unit.unitType.bulletSetsQuantity
  for (local i = 0; i < setLen; i++) {
    let modifName = bulletSet?[i] ?? getSavedBullets(unit.name, i)
    if (modifName == "")
      continue

    if ((!isCheckAll && isModificationEnabled(unit.name, modifName)) //Current mod
      || (isCheckAll && isWeaponUnlocked(unit, getModificationByName(unit, modifName)))) { //All unlocked mods
      let res = checkAmmoAmount(unit, modifName, AMMO.MODIFICATION)
      if (res != UNIT_WEAPONS_READY)
        return res
    }
  }

  return UNIT_WEAPONS_READY
}

function checkUnitWeapons(unit, isCheckAll = false) {
  let weaponsState = isCheckAll ? checkUnitSecondaryWeapons(unit) : checkUnitLastWeapon(unit)
  return weaponsState != UNIT_WEAPONS_READY ? weaponsState : checkUnitBullets(unit, isCheckAll)
}

function checkBadWeapons() {
  foreach (unit in getAllUnits()) {
    if (!unit.isUsable())
      continue

    let curWeapon = getLastWeapon(unit.name)
    if (curWeapon == "")
      continue

    if (!::shop_is_weapon_available(unit.name, curWeapon, false, false) && !shop_is_weapon_purchased(unit.name, curWeapon))
      setLastWeapon(unit.name, "")
  }
}

function getOverrideBullets(unit) {
  if (!unit || !isInFlight())
    return null
  let missionName = get_current_mission_name()
  if (missionName == "")
    return null
  let editSlotbarBlk = getMissionEditSlotbarBlk(missionName)
  let editSlotbarUnitBlk = editSlotbarBlk?[unit.shopCountry]?[unit.name]
  return editSlotbarUnitBlk?["bulletsCount0"] != null ? editSlotbarUnitBlk : null
}

let needSecondaryWeaponsWnd = @(unit) unit.isAir() || unit.isHelicopter()

let getTriggerType = @(w) (w?.triggerGroup == "torpedoes" || w?.triggerGroup == "commander")
  ? w.triggerGroup
  : w?.weaponType ?? w?.trigger ?? ""

let isGunnerTrigger = @(trigger) trigger.indexof(TRIGGER_TYPE.GUNNER, 0) == 0

return {
  KGF_TO_NEWTON
  TRIGGER_TYPE
  WEAPON_TYPE
  WEAPON_TAG
  CONSUMABLE_TYPES
  WEAPON_TEXT_PARAMS
  getLastWeapon
  validateLastWeapon
  setLastWeapon
  getSecondaryWeaponsList
  getPresetsList
  addWeaponsFromBlk
  getWeaponExtendedInfo
  isWeaponAux
  getUnitWeaponry
  getWeaponsStatusName
  getWeaponNameByBlkPath
  isCaliberCannon
  getPrimaryWeaponsList
  getLastPrimaryWeapon
  getCommonWeapons
  isWeaponUnlocked
  getWeaponByName
  isUnitHaveAnyWeaponsTags
  getLinkedGunIdx
  checkUnitWeapons
  checkUnitSecondaryWeapons
  checkUnitBullets
  isWeaponEnabled
  isWeaponVisible
  isDefaultTorpedoes
  checkBadWeapons
  getOverrideBullets
  needSecondaryWeaponsWnd
  getWeaponDisabledMods
  getTriggerType
  isGunnerTrigger
}
