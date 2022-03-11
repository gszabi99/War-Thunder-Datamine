let { blkOptFromPath } = require("sqStdLibs/helpers/datablockUtils.nut")
let { eachBlock } = require("std/datablock.nut")
let unitTypes = require("scripts/unit/unitTypesList.nut")
let { getModificationByName } = require("scripts/weaponry/modificationInfo.nut")
let { AMMO,
        getAmmoCost,
        getAmmoAmount,
        checkAmmoAmount,
        getAmmoMaxAmount } = require("scripts/weaponry/ammoInfo.nut")
let { saclosMissileBeaconIRSourceBand } = require("scripts/weaponry/weaponsParams.nut")
let { getMissionEditSlotbarBlk } = require("scripts/slotbar/slotbarOverride.nut")
let { getUnitPresets, getWeaponsByTypes,
  getWeaponsByPresetName } = require("scripts/weaponry/weaponryPresets.nut")

global const UNIT_WEAPONS_ZERO    = 0
global const UNIT_WEAPONS_WARNING = 1
global const UNIT_WEAPONS_READY   = 2
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
}

let WEAPON_TYPE = {
  GUNS            = "guns"
  CANNONS         = "cannons"
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
}

let CONSUMABLE_TYPES = [ WEAPON_TYPE.AAM, WEAPON_TYPE.AGM, WEAPON_TYPE.GUIDED_BOMBS,
  WEAPON_TYPE.ROCKETS, WEAPON_TYPE.TORPEDOES, WEAPON_TYPE.BOMBS, WEAPON_TYPE.MINES,
  WEAPON_TYPE.SMOKE, WEAPON_TYPE.FLARES, WEAPON_TYPE.CHAFFS, WEAPON_TYPE.COUNTERMEASURES]

let WEAPON_TAG = {
  ADD_GUN          = "additionalGuns"
  BULLET           = "bullet"
  ROCKET           = "rocket"
  BOMB             = "bomb"
  TORPEDO          = "torpedo"
  FRONT_GUN        = "frontGun"
  CANNON           = "cannon"
  ANTI_SHIP        = "antiShip"
  ANTI_SHIP_BOMB   = "antiShipBomb"
  ANTI_SHIP_ROCKET = "antiShipRocket"
  ANTI_TANK_BOMB   = "antiTankBomb"
  ANTI_TANK_ROCKET = "antiTankRocket"
  ANTI_HEAVY_TANK  = "antiHeavyTanks"
}

let WEAPON_TEXT_PARAMS = { //const
  isPrimary             = null //bool or null. When null return descripton for all weaponry.
  weaponPreset          = -1 //int weaponIndex or string weapon name
  newLine               ="\n" //weapons delimeter
  detail                = INFO_DETAIL.FULL
  needTextWhenNoWeapons = true
  ediff                 = null //int. when not set, uses get_current_ediff() function
  isLocalState          = true //should apply my local parameters to unit (modifications, crew skills, etc)
  weaponsFilterFunc     = null //function. When set, only filtered weapons are collected from weaponPreset.
}

let triggerGroupImageParameterById = {
  [TRIGGER_GROUP_PRIMARY]         = "triggerGroupPrimaryImage",
  [TRIGGER_GROUP_SECONDARY]       = "triggerGroupSecondaryImage",
  [TRIGGER_GROUP_MACHINE_GUN]     = "triggerGroupMachineGunImage"
}

let function isWeaponAux(weapon)
{
  local aux = false
  foreach (tag in weapon.tags)
    if (tag == "aux")
    {
      aux = true
      break
    }
  return aux
}

let function isWeaponEnabled(unit, weapon)
{
  return ::shop_is_weapon_available(unit.name, weapon.name, true, false) //no point to check purchased unit even in respawn screen
         //temporary hack: check ammo amount for forced units by mission,
         //because shop_is_weapon_available function work incorrect with them
         && (!::is_game_mode_with_spendable_weapons()
             || getAmmoAmount(unit, weapon.name, AMMO.WEAPON)
             || !getAmmoMaxAmount(unit, weapon.name, AMMO.WEAPON)
            )
         && (!::is_in_flight()
             || ::g_mis_custom_state.getCurMissionRules().isUnitWeaponAllowed(unit, weapon))
}

let function getWeaponDisabledMods(unit, weapon)
{
  return weapon?.reqModification.filter(@(n) !::shop_is_modification_enabled(unit.name, n)) ?? []
}

let function isWeaponVisible(unit, weapon, onlySelectable = true, weaponTags = null)
{
  if (isWeaponAux(weapon))
    return false

  if (weaponTags != null)
  {
    local hasTag = false
    foreach(t in weaponTags)
      if (weapon?[t])
      {
        hasTag = true
        break
      }
    if (!hasTag)
      return false
  }

  if (onlySelectable
      && ((!::shop_is_weapon_purchased(unit.name, weapon.name)
        && getAmmoCost(unit, weapon.name, AMMO.WEAPON) > ::zero_money)
        || getWeaponDisabledMods(unit, weapon).len() > 0))
    return false

  return true
}

let function getLastWeapon(unitName)
{
  let res = ::get_last_weapon(unitName)
  if (res != "")
    return res

  //validate last_weapon value
  let unit = ::getAircraftByName(unitName)
  if (!unit)
    return res
  foreach(weapon in unit.getWeapons())
    if (isWeaponVisible(unit, weapon)
        && isWeaponEnabled(unit, weapon))
    {
      ::set_last_weapon(unitName, weapon.name)
      return weapon.name
    }
  return res
}

let getWeaponByName = @(unit, weaponName) unit?.getWeapons().findvalue(@(w) w.name == weaponName)

let function validateLastWeapon(unitName)
{
  let weaponName = ::get_last_weapon(unitName)
  if (weaponName == "")
    return ""

  let unit = ::getAircraftByName(unitName)
  if (!unit)
    return ""

  let curWeapon = getWeaponByName(unit, weaponName)
  if (isWeaponVisible(unit, curWeapon) && isWeaponEnabled(unit, curWeapon))
    return weaponName

  foreach (weapon in unit.getWeapons())
    if (isWeaponVisible(unit, weapon) && isWeaponEnabled(unit, weapon))
    {
      ::set_last_weapon(unitName, weapon.name)
      return weapon.name
    }

  return ""
}

let function setLastWeapon(unitName, weaponName)
{
  if (weaponName == getLastWeapon(unitName))
    return

  ::set_last_weapon(unitName, weaponName)
  ::broadcastEvent("UnitWeaponChanged", { unitName = unitName, weaponName = weaponName })
}

let function getWeaponNameByBlkPath(weaponBlkPath)
{
  let idxLastSlash = ::g_string.lastIndexOf(weaponBlkPath, "/")
  let idxStart = idxLastSlash != ::g_string.INVALID_INDEX ? (idxLastSlash + 1) : 0
  let idxEnd = ::g_string.endsWith(weaponBlkPath, ".blk") ? -4 : weaponBlkPath.len()
  return weaponBlkPath.slice(idxStart, idxEnd)
}

let function isWeaponParamsEqual(item1, item2)
{
  if (typeof(item1) != "table" || typeof(item2) != "table" || !item1.len() || !item2.len())
    return false
  let skipParams = [ "num", "ammo" ]
  foreach (idx, val in item1)
    if (!::isInArray(idx, skipParams) && !::u.isEqual(val, item2?[idx]))
      return false
  return true
}

let function isCaliberCannon(caliber_mm)
{
  return caliber_mm >= 15
}

let function getWeaponBlkParams(weaponBlkPath, weaponBlkCache, bullets = null) {
  let self = callee()
  let weaponBlk = weaponBlkCache?[weaponBlkPath] ?? blkOptFromPath(weaponBlkPath)
  bullets = (bullets ?? 1) * (weaponBlk?.bullets ?? 1)
  weaponBlkCache[weaponBlkPath] <- weaponBlk
  if (weaponBlk?.container ?? false)
    return self(weaponBlk.blk, weaponBlkCache, bullets)
  return {
    weaponBlk
    weaponBlkPath
    bulletsCount = bullets
  }
}

let function addWeaponsFromBlk(weapons, weaponsArr, unit, weaponsFilterFunc = null, wConf = null) {
  let weaponBlkCache = {}
  let unitType = ::get_es_unit_type(unit)
  foreach (weapon in weaponsArr) {
    if (weapon?.dummy
      || (weapon?.triggerGroup == "commander" && weapon?.bullets == null))
      continue

    if (!weapon?.blk)
      continue

    let { weaponBlk, weaponBlkPath, bulletsCount } = getWeaponBlkParams(weapon.blk, weaponBlkCache)

    if (weaponsFilterFunc?(weaponBlkPath, weaponBlk) == false)
      continue

    local currentTypeName = WEAPON_TYPE.TURRETS
    local weaponTag = WEAPON_TAG.BULLET

    if (weaponBlk?.rocketGun)
    {
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
    else if (weaponBlk?.bombGun)
    {
      if (weapon?.trigger == TRIGGER_TYPE.MINES)
        currentTypeName = WEAPON_TYPE.MINES
      else if (weapon?.trigger == TRIGGER_TYPE.GUIDED_BOMBS)
        currentTypeName = WEAPON_TYPE.GUIDED_BOMBS
      else
        currentTypeName = WEAPON_TYPE.BOMBS
      weaponTag = WEAPON_TAG.BOMB
    }
    else if (weaponBlk?.torpedoGun)
    {
      currentTypeName = WEAPON_TYPE.TORPEDOES
      weaponTag = WEAPON_TAG.TORPEDO
    }
    else if (unitType == ::ES_UNIT_TYPE_TANK ||
      ::isInArray(weapon.trigger, [ TRIGGER_TYPE.MACHINE_GUN, TRIGGER_TYPE.CANNON,
        TRIGGER_TYPE.ADD_GUN, TRIGGER_TYPE.ROCKETS, TRIGGER_TYPE.AGM, TRIGGER_TYPE.AAM,
        TRIGGER_TYPE.GUIDED_BOMBS, TRIGGER_TYPE.BOMBS, TRIGGER_TYPE.TORPEDOES, TRIGGER_TYPE.SMOKE,
        TRIGGER_TYPE.FLARES, TRIGGER_TYPE.CHAFFS, TRIGGER_TYPE.COUNTERMEASURES]))
    { //not a turret
      currentTypeName = weapon.trigger == TRIGGER_TYPE.COUNTERMEASURES ? WEAPON_TYPE.COUNTERMEASURES : WEAPON_TYPE.GUNS
      if (weaponBlk?.bullet && typeof(weaponBlk?.bullet) == "instance"
          && isCaliberCannon(1000 * ::getTblValue("caliber", weaponBlk?.bullet, 0)))
        currentTypeName = WEAPON_TYPE.CANNONS
    }
    else if (weaponBlk?.fuelTankGun || weaponBlk?.boosterGun || weaponBlk?.airDropGun || weaponBlk?.undercarriageGun)
      continue

    let isTurret = currentTypeName == WEAPON_TYPE.TURRETS

    let item = {
      turret = null
      ammo = 0
      num = 0
      caliber = 0
      massKg = 0
      massLbs = 0
      explosiveType = null
      explosiveMass = 0
      dropSpeedRange = null
      dropHeightRange = null
      iconType = null
      amountPerTier = null
      isGun = null
      bulletType = null
      tiers = {}
      blk = ""
    }

    if (wConf)
      foreach (wc in (wConf % "Weapon"))
        if (weaponBlkPath.tolower() == wc.blk.tolower())
        {
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


    let needBulletParams = !::isInArray(currentTypeName,
      [WEAPON_TYPE.SMOKE, WEAPON_TYPE.FLARES, WEAPON_TYPE.CHAFFS, WEAPON_TYPE.COUNTERMEASURES])

    if (needBulletParams && weaponTag.len() && weaponBlk?[weaponTag])
    {
      let itemBlk = weaponBlk[weaponTag]
      let isGun = ::isInArray(currentTypeName, [WEAPON_TYPE.GUNS, WEAPON_TYPE.CANNONS])
      item.isGun = isGun
      item.caliber = itemBlk?.caliber ?? item.caliber
      item.massKg = itemBlk?.mass ?? item.massKg
      item.massLbs = itemBlk?.mass_lbs ?? item.massLbs
      item.explosiveType = itemBlk?.explosiveType ?? item.explosiveType
      item.explosiveMass = itemBlk?.explosiveMass ?? item.explosiveMass
      item.iconType = isGun ? weaponBlk?.iconType : item.iconType ?? itemBlk?.iconType
      item.amountPerTier = isGun ? weaponBlk?.amountPerTier
        : item.amountPerTier ?? itemBlk?.amountPerTier
      item.bulletType = itemBlk?.bulletType
      item.blk = weaponBlkPath

      if (::isInArray(currentTypeName, [ WEAPON_TYPE.ROCKETS, WEAPON_TYPE.AGM, WEAPON_TYPE.AAM, WEAPON_TYPE.GUIDED_BOMBS ]))
      {
        item.machMax  <- itemBlk?.machMax ?? 0
        item.maxSpeed <- (itemBlk?.maxSpeed ?? 0) || (itemBlk?.endSpeed ?? 0)
        if ((itemBlk?.guaranteedRange ?? 0) != 0)
          item.guaranteedRange <- itemBlk.guaranteedRange

        if (itemBlk?.guidance != null || itemBlk?.operated == true )
        {
          if (itemBlk?.operated == true)
          {
            item.autoAiming <- itemBlk?.autoAiming ?? false
            item.isBeamRider <- itemBlk?.isBeamRider ?? false
            if (itemBlk?.irBeaconBand)
              if (itemBlk.irBeaconBand != saclosMissileBeaconIRSourceBand.value)
                item.guidanceECCM <- true
          }
          else
            item.guidanceType <- itemBlk?.guidanceType

          if ((itemBlk?.rangeMax ?? 0) != 0)
            item.launchRange <- itemBlk.rangeMax

          if ((itemBlk?.timeLife ?? 0) != 0)
            item.timeLife <- itemBlk.timeLife

          if (itemBlk?.guidance != null)
          {
            if (itemBlk.guidance?.irSeeker != null)
            {
              if (itemBlk.guidance.irSeeker?.visibilityType == "optic")
                item.guidanceType <- "tv"
              else
                item.guidanceType <- "ir"
              let rangeRearAspect = itemBlk.guidance.irSeeker?.rangeBand0 ?? 0
              let rangeAllAspect  = itemBlk.guidance.irSeeker?.rangeBand1 ?? 0
              if (currentTypeName == WEAPON_TYPE.AAM)
              {
                item.seekerRangeRearAspect <- rangeRearAspect
                item.seekerRangeAllAspect  <- rangeAllAspect
                if (rangeRearAspect > 0 || rangeAllAspect > 0)
                  item.allAspect <- rangeAllAspect >= 1000.0
              }
              else if (currentTypeName == WEAPON_TYPE.AGM && (itemBlk.guidance.irSeeker?.groundVehiclesAsTarget ?? false))
              {
                if (rangeRearAspect > 0 || rangeAllAspect > 0)
                  item.seekerRange <- ::min(rangeRearAspect, rangeAllAspect)
              }
              if (itemBlk?.guidanceType == "ir" && (itemBlk.guidance.irSeeker?.bandMaskToReject ?? 0) != 0)
                item.seekerECCM <- true
            }
            else if (itemBlk.guidance?.opticalFlowSeeker != null)
            {
              if (itemBlk.guidance.opticalFlowSeeker?.visibilityType == "optic")
                item.guidanceType <- "tv"
              else
                item.guidanceType <- "ir"
            }
            if (itemBlk.guidance?.radarSeeker != null)
            {
              let active = itemBlk.guidance.radarSeeker?.active ?? false
              item.guidanceType <- active ? "ARH" : "SARH"
              local distanceGate = false
              local dopplerSpeedGate = false
              if (itemBlk.guidance.radarSeeker?.distance != null)
                distanceGate = itemBlk.guidance.radarSeeker.distance?.presents ?? false
              if (itemBlk.guidance.radarSeeker?.dopplerSpeed != null)
                dopplerSpeedGate = itemBlk.guidance.radarSeeker.dopplerSpeed?.presents ?? false
              if (distanceGate && dopplerSpeedGate)
                item.radarSignal <- "pulse_doppler"
              else if (distanceGate)
                item.radarSignal <- "pulse"
              else if (dopplerSpeedGate)
                item.radarSignal <- "CW"
              if (itemBlk.guidance.radarSeeker?.receiver != null)
              {
                let range = itemBlk.guidance.radarSeeker.receiver?.range ?? 0
                item.seekerRange <- range
              }
            }
          }
        }
        if (currentTypeName == WEAPON_TYPE.AAM)
        {
          item.loadFactorMax <- itemBlk?.loadFactorMax ?? 0
          if (weapon?.loadFactorLimit)
            item.loadFactorLimit <- weapon.loadFactorLimit
        }
        else if (currentTypeName == WEAPON_TYPE.AGM)
        {
          item.operatedDist <- itemBlk?.operatedDist ?? 0
        }
      }
      else  if (currentTypeName == WEAPON_TYPE.TORPEDOES)
      {
        item.dropSpeedRange = itemBlk.getPoint2("dropSpeedRange", Point2(0,0))
        if (item.dropSpeedRange.x == 0 && item.dropSpeedRange.y == 0)
          item.dropSpeedRange = null
        item.dropHeightRange = itemBlk.getPoint2("dropHeightRange", Point2(0,0))
        if (item.dropHeightRange.x == 0 && item.dropHeightRange.y == 0)
          item.dropHeightRange = null
        item.maxSpeedInWater <- itemBlk?.maxSpeedInWater ?? 0
        item.distToLive <- itemBlk?.distToLive ?? 0
        item.diveDepth <- itemBlk?.diveDepth ?? 0
        item.armDistance <- itemBlk?.armDistance ?? 0
      }
    }

    if(isTurret && (weapon?.turret != null))
    {
      let turretInfo = weapon.turret
      item.turret = ::u.isDataBlock(turretInfo) ? turretInfo.head : turretInfo
    }

    if (!(currentTypeName in weapons))
      weapons[ currentTypeName ] <- []

    local weaponName = getWeaponNameByBlkPath(weaponBlkPath)
    local trIdx = -1
    foreach(idx, t in weapons[currentTypeName])
      if (weapon.trigger == t.trigger ||
          ((weaponName in t) && isWeaponParamsEqual(item, t[weaponName])))
      {
        trIdx = idx
        break
      }

    // Merging duplicating weapons with different weaponName
    // (except guns, because there exists different guns with equal params)
    if (trIdx >= 0 && !(weaponName in weapons[currentTypeName][trIdx]) && weaponTag != WEAPON_TAG.BULLET)
      foreach (name, existingItem in weapons[currentTypeName][trIdx])
        if (isWeaponParamsEqual(item, existingItem))
        {
          weaponName = name
          break
        }

    if (trIdx < 0)
    {
      weapons[currentTypeName].append({ trigger = weapon.trigger, caliber = 0 })
      trIdx = weapons[currentTypeName].len() - 1
    }

    let currentType = weapons[currentTypeName][trIdx]

    if (!(weaponName in currentType))
    {
      currentType[weaponName] <- item
      if (item.caliber > currentType.caliber)
        currentType.caliber = item.caliber
    }
    currentType[weaponName].ammo += weapon?.bullets ?? bulletsCount
    currentType[weaponName].num += 1
  }

  return weapons
}

//weapon - is a weaponData gathered by addWeaponsFromBlk
local function getWeaponExtendedInfo(weapon, weaponType, unit, ediff, newLine)
{
  let res = []
  let colon = ::loc("ui/colon")

  local massText = null
  if (weapon.massLbs > 0)
    massText = format(::loc("mass/lbs"), weapon.massLbs)
  else if (weapon.massKg > 0)
    massText = format(::loc("mass/kg"), weapon.massKg)
  if (massText)
    res.append("".concat(::loc("shop/tank_mass"), " ", massText))

  if (::isInArray(weaponType, [ "rockets", "agm", "aam", "guided bombs" ]))
  {
    if (weapon?.guidanceType != null || weapon?.autoAiming != null)
    {
      let aimingType = weapon?.autoAiming == null ? ""
        : weapon.autoAiming && weapon.isBeamRider ? "beamRiding"
        : weapon.autoAiming ? "semiautomatic"
        : "manual"
      let guidanceTxt = aimingType != ""
        ? ::loc($"missile/aiming/{aimingType}")
        : ::loc($"missile/guidance/{weapon.guidanceType}")
      res.append("".concat(::loc("missile/guidance"), colon, guidanceTxt))
      if (weapon?.guidanceECCM)
        res.append("".concat(::loc("missile/eccm"), colon, ::loc("options/yes")))
    }
    if (weapon?.allAspect != null)
      res.append("".concat(::loc("missile/aspect"), colon,
        ::loc("missile/aspect/{0}".subst(weapon.allAspect ? "allAspect" : "rearAspect"))))
    if (weapon?.radarSignal)
    {
      let radarSignalTxt = ::loc($"missile/radarSignal/{weapon.radarSignal}")
      res.append("".concat(::loc("missile/radarSignal"), colon, radarSignalTxt))
    }
    if (weapon?.seekerRangeRearAspect)
      res.append("".concat(::loc("missile/seekerRange/rearAspect"), colon,
        ::g_measure_type.DISTANCE.getMeasureUnitsText(weapon.seekerRangeRearAspect)))
    if (weapon?.seekerRangeAllAspect)
      res.append("".concat(::loc("missile/seekerRange/allAspect"), colon,
        ::g_measure_type.DISTANCE.getMeasureUnitsText(weapon.seekerRangeAllAspect)))
    if (weapon?.seekerRange)
      res.append("".concat(::loc("missile/seekerRange"), colon,
        ::g_measure_type.DISTANCE.getMeasureUnitsText(weapon.seekerRange)))
    if (weapon?.seekerECCM)
      res.append("".concat(::loc("missile/eccm"), colon, ::loc("options/yes")))
    if (weapon?.launchRange)
      res.append("".concat(::loc("missile/launchRange"), colon,
        ::g_measure_type.DISTANCE.getMeasureUnitsText(weapon.launchRange)))
    if (weapon?.machMax)
      res.append("".concat(::loc("rocket/maxSpeed"), colon,
        ::format("%.1f %s", weapon.machMax, ::loc("measureUnits/machNumber"))))
    else if (weapon?.maxSpeed)
      res.append("".concat(::loc("rocket/maxSpeed"), colon,
        ::g_measure_type.SPEED_PER_SEC.getMeasureUnitsText(weapon.maxSpeed)))
    if (weapon?.loadFactorMax)
      res.append("".concat(::loc("missile/loadFactorMax"), colon,
        ::g_measure_type.GFORCE.getMeasureUnitsText(weapon.loadFactorMax)))
    if (weapon?.loadFactorLimit)
      res.append("".concat(::loc("missile/loadFactorLimit"), colon,
        ::g_measure_type.GFORCE.getMeasureUnitsText(weapon.loadFactorLimit)))
    if (weapon?.operatedDist)
      res.append("".concat(::loc("firingRange"), colon,
        ::g_measure_type.DISTANCE.getMeasureUnitsText(weapon.operatedDist)))
    if (weapon?.guaranteedRange)
      res.append("".concat(::loc("guaranteedRange"), colon,
        ::g_measure_type.DISTANCE.getMeasureUnitsText(weapon.guaranteedRange)))
    if (weapon?.timeLife)
    {
      if (weapon?.guidanceType != null || weapon?.autoAiming != null)
        res.append("".concat(::loc("missile/timeGuidance"), colon,
          ::format("%.1f %s", weapon.timeLife, ::loc("measureUnits/seconds"))))
      else
        res.append("".concat(::loc("missile/timeSelfdestruction"), colon,
          ::format("%.1f %s", weapon.timeLife, ::loc("measureUnits/seconds"))))
    }
  }
  else if (weaponType == "torpedoes")
  {
    let torpedoMod = "torpedoes_movement_mode"
    if (::shop_is_modification_enabled(unit.name, torpedoMod))
    {
      let mod = getModificationByName(unit, torpedoMod)
      let diffId = ::get_difficulty_by_ediff(ediff ?? ::get_current_ediff()).crewSkillName
      let effects = mod?.effects?[diffId]
      let torpedoAffected = effects?.torpedoAffected ?? ""
      if (effects && (torpedoAffected == "" || torpedoAffected == weapon.blk))
      {
        weapon = clone weapon
        foreach (k, v in weapon)
        {
          let kEffect = $"{k}Torpedo"
          if ((kEffect in effects) && type(v) == type(effects[kEffect]))
            weapon[k] += effects[kEffect]
        }
      }
    }

    if (weapon?.maxSpeedInWater)
      res.append("".concat(::loc("torpedo/maxSpeedInWater"), colon,
        ::g_measure_type.SPEED.getMeasureUnitsText(weapon?.maxSpeedInWater)))

    if (weapon?.distToLive)
      res.append("".concat(::loc("torpedo/distanceToLive"), colon,
        ::g_measure_type.DISTANCE.getMeasureUnitsText(weapon?.distToLive)))

    if (weapon?.diveDepth) {
      let diveDepth = unit.unitType == unitTypes.SHIP && !::get_option_torpedo_dive_depth_auto()
          ? ::get_option_torpedo_dive_depth()
          : weapon?.diveDepth
      res.append("".concat(::loc("bullet_properties/diveDepth"), colon,
        ::g_measure_type.DEPTH.getMeasureUnitsText(diveDepth)))
    }

    if (weapon?.armDistance)
      res.append("".concat(::loc("torpedo/armingDistance"), colon,
        ::g_measure_type.DEPTH.getMeasureUnitsText(weapon?.armDistance)))
  }

  if (weapon.explosiveType != null)
  {
    res.append("".concat(::loc("bullet_properties/explosiveType"), colon,
      ::loc($"explosiveType/{weapon.explosiveType}")))
    if (weapon.explosiveMass)
    {
      let measureType = ::g_measure_type.getTypeByName("kg", true)
      res.append("".concat(::loc("bullet_properties/explosiveMass"), colon,
        measureType.getMeasureUnitsText(weapon.explosiveMass)))
    }
    if (weapon.explosiveMass)
    {
      let tntEqText = ::g_dmg_model.getTntEquivalentText(weapon.explosiveType, weapon.explosiveMass)
      if (tntEqText.len())
        res.append("".concat(::loc("bullet_properties/explosiveMassInTNTEquivalent"), colon, tntEqText))
    }

    if (weaponType == "bombs" && unit.unitType != unitTypes.SHIP)
    {
      let destrTexts = ::g_dmg_model.getDestructionInfoTexts(weapon.explosiveType, weapon.explosiveMass, weapon.massKg)
      foreach (key in ["maxArmorPenetration", "destroyRadiusArmored", "destroyRadiusNotArmored"])
      {
        let valueText = destrTexts[$"{key}Text"]
        if (valueText.len())
          res.append("".concat(::loc($"bombProperties/{key}"), colon, valueText))
      }
    }
  }

  return "".concat(res.len() ? newLine : "", newLine.join(res))
}

let function getPrimaryWeaponsList(unit)
{
  if(unit.primaryWeaponMods)
    return unit.primaryWeaponMods

  unit.primaryWeaponMods = [""]

  let airBlk = ::get_full_unit_blk(unit.name)
  if(!airBlk?.modifications)
    return unit.primaryWeaponMods

  eachBlock(airBlk.modifications, function(modification, modName) {
    if (modification?.effects.commonWeapons)
      unit.primaryWeaponMods.append(modName)
  })

  return unit.primaryWeaponMods
}

let function getLastPrimaryWeapon(unit)
{
  let primaryList = getPrimaryWeaponsList(unit)
  foreach(modName in primaryList)
    if (modName!="" && ::shop_is_modification_enabled(unit.name, modName))
      return modName
  return ""
}

let function getCommonWeapons(unitBlk, primaryMod) {
  let res = []
  if (primaryMod == "" && unitBlk?.commonWeapons)
    return getWeaponsByTypes(unitBlk.commonWeapons, unitBlk)

  if (unitBlk?.modifications == null)
    return res

  let modificationsCount = unitBlk.modifications.blockCount()
  for (local i = 0; i < modificationsCount; i++) {
    let modification = unitBlk.modifications.getBlock(i)
    if (modification.getBlockName() == primaryMod){
      if (modification?.effects.commonWeapons)
        return getWeaponsByTypes(modification.effects.commonWeapons, unitBlk)

      break
    }
  }

  return res
}

local function getUnitWeaponry(unit, p = WEAPON_TEXT_PARAMS)
{
  if (!unit)
    return null

  let unitBlk = ::get_full_unit_blk(unit.name)
  if( !unitBlk )
    return null

  local weapons = {}
  p = WEAPON_TEXT_PARAMS.__merge(p)
  local primaryMod = ""
  local weaponPresetIdx = -1
  if ((typeof(p.weaponPreset) == "string") || p.weaponPreset < 0)
  {
    if (!p.isPrimary)
    {
      let curWeap = (typeof(p.weaponPreset) == "string") ? p.weaponPreset : getLastWeapon(unit.name)
      foreach(idx, w in unit.getWeapons())
        if (w.name == curWeap || (weaponPresetIdx < 0 && !isWeaponAux(w)))
          weaponPresetIdx = idx
      if (weaponPresetIdx < 0)
        return weapons
    }
    if (p.isPrimary && typeof(p.weaponPreset)=="string")
      primaryMod = p.weaponPreset
    else
      primaryMod = getLastPrimaryWeapon(unit)
  } else
    weaponPresetIdx = p.weaponPreset

  if (p.isPrimary || p.isPrimary==null)
    weapons = addWeaponsFromBlk({}, getCommonWeapons(unitBlk, primaryMod), unit, p.weaponsFilterFunc)

  if (!p.isPrimary) {
    let weaponName = unit.getWeapons()?[weaponPresetIdx].name
    let curPreset = getUnitPresets(unitBlk).findvalue(@(_) _.name == weaponName)
    if (curPreset)
      weapons = addWeaponsFromBlk(weapons, getWeaponsByPresetName(unitBlk, curPreset.name),
        unit, p.weaponsFilterFunc, curPreset?.weaponConfig)
  }

  return weapons
}

let function getSecondaryWeaponsList(unit)
{
  let weaponsList = []
  let unitName = unit.name
  let lastWeapon = ::get_last_weapon(unitName)
  foreach(weapon in unit.getWeapons())
  {
    if(isWeaponAux(weapon))
      continue

    weaponsList.append(weapon)
    if(lastWeapon=="" && ::shop_is_weapon_purchased(unitName, weapon.name))
      setLastWeapon(unitName, weapon.name)  //!!FIX ME: remove side effect from getter
  }

  return weaponsList
}

let function getPresetsList(unit, chooseMenuList)
{
  if (!chooseMenuList)
    return getSecondaryWeaponsList(unit)

  let weaponsList = []
  foreach (item in chooseMenuList)
    weaponsList.append(item.weaponryItem.__merge({isEnabled = item.enabled}))
  return weaponsList
}

let getWeaponsStatusName = @(weaponsStatus) weaponsStatusNameByStatusCode[weaponsStatus]

let function isWeaponUnlocked(unit, weapon)
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

let function isUnitHaveAnyWeaponsTags(unit, tags, checkPurchase = true)
{
  if (!unit)
    return false

  foreach(w in unit.getWeapons())
    if (::shop_is_weapon_purchased(unit.name, w.name) > 0 || !checkPurchase)
      foreach(tag in tags)
        if ((tag in w) && w[tag])
          return true
  return false
}

let function getLinkedGunIdx(groupIdx, totalGroups, bulletSetsQuantity, canBeDuplicate = true)
{
  if (!canBeDuplicate)
    return groupIdx
  return (groupIdx.tofloat() * totalGroups / bulletSetsQuantity + 0.001).tointeger()
}

let function checkUnitSecondaryWeapons(unit)
{
  foreach (weapon in getSecondaryWeaponsList(unit))
    if (isWeaponEnabled(unit, weapon) ||
      (::isUnitUsable(unit) && isWeaponUnlocked(unit, weapon)))
    {
      let res = checkAmmoAmount(unit, weapon.name, AMMO.WEAPON)
      if (res != UNIT_WEAPONS_READY)
        return res
    }

  return UNIT_WEAPONS_READY
}

let checkUnitLastWeapon = @(unit) checkAmmoAmount(unit, getLastWeapon(unit.name), AMMO.WEAPON)

let function checkUnitBullets(unit, isCheckAll = false, bulletSet = null)
{
  let setLen = bulletSet?.len() ?? unit.unitType.bulletSetsQuantity
  for (local i = 0; i < setLen; i++)
  {
    let modifName = bulletSet?[i] ?? ::get_last_bullets(unit.name, i)
    if((modifName ?? "") == "")
      continue

    if ((!isCheckAll && ::shop_is_modification_enabled(unit.name, modifName))//Current mod
      || (isCheckAll && isWeaponUnlocked(unit, getModificationByName(unit, modifName))))//All unlocked mods
    {
      let res = checkAmmoAmount(unit, modifName, AMMO.MODIFICATION)
      if (res != UNIT_WEAPONS_READY)
        return res
    }
  }

  return UNIT_WEAPONS_READY
}

let function checkUnitWeapons(unit, isCheckAll = false)
{
  let weaponsState = isCheckAll ? checkUnitSecondaryWeapons(unit) : checkUnitLastWeapon(unit)
  return weaponsState != UNIT_WEAPONS_READY ? weaponsState : checkUnitBullets(unit, isCheckAll)
}

let function checkBadWeapons()
{
  foreach(unit in ::all_units)
  {
    if (!unit.isUsable())
      continue

    let curWeapon = getLastWeapon(unit.name)
    if (curWeapon=="")
      continue

    if (!::shop_is_weapon_available(unit.name, curWeapon, false, false) && !::shop_is_weapon_purchased(unit.name, curWeapon))
      setLastWeapon(unit.name, "")
  }
}

let function getOverrideBullets(unit)
{
  if (!unit)
    return null
  let missionName = ::get_current_mission_name()
  if (missionName == "")
    return null
  let editSlotbarBlk = getMissionEditSlotbarBlk(missionName)
  let editSlotbarUnitBlk = editSlotbarBlk?[unit.shopCountry]?[unit.name]
  return editSlotbarUnitBlk?["bulletsCount0"] != null ? editSlotbarUnitBlk : null
}

let needSecondaryWeaponsWnd = @(unit) (unit.isAir() || unit.isHelicopter()) && ::has_feature("ShowWeapPresetsMenu")

let cachedTriggerGroupImageByUnitName = {}
let function getImageByTriggerFromUnit(unitName, triggerGroup) {
  if (unitName in cachedTriggerGroupImageByUnitName)
    return cachedTriggerGroupImageByUnitName[unitName]?[triggerGroup]
  let unitBlk = ::get_full_unit_blk(unitName)
  if (unitBlk == null)
    return null

  cachedTriggerGroupImageByUnitName[unitName] <- triggerGroupImageParameterById.map(@(name) unitBlk?[name])
  return cachedTriggerGroupImageByUnitName[unitName]?[triggerGroup]
}

::cross_call_api.getImageByTriggerFromUnit <- getImageByTriggerFromUnit

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
  checkBadWeapons
  getOverrideBullets
  needSecondaryWeaponsWnd
  getWeaponDisabledMods
}
