global const KGF_TO_NEWTON        = 9.807
global const UNIT_WEAPONS_ZERO    = 0
global const UNIT_WEAPONS_WARNING = 1
global const UNIT_WEAPONS_READY   = 2

local WEAPON_TYPE = {
  GUN             = 0
  ROCKET          = 1 // Rocket
  AAM             = 2 // Air-to-Air Missile
  AGM             = 3 // Air-to-Ground Missile, Anti-Tank Guided Missile
  FLARES          = 4 // Flares (countermeasure)
  SMOKE_SCREEN    = 5
  TORPEDO         = 6
  DEPTH_CHARGE    = 7
}

local WEAPON_TEXT_PARAMS = { //const
  isPrimary             = null //bool or null. When null return descripton for all weaponry.
  weaponPreset          = -1 //int weaponIndex or string weapon name
  newLine               ="\n" //weapons delimeter
  detail                = INFO_DETAIL.FULL
  needTextWhenNoWeapons = true
  ediff                 = null //int. when not set, uses get_current_ediff() function
  isLocalState          = true //should apply my local parameters to unit (modifications, crew skills, etc)
  weaponsFilterFunc     = null //function. When set, only filtered weapons are collected from weaponPreset.
}

local function getLastWeapon(unitName)
{
  local res = ::get_last_weapon(unitName)
  if (res != "")
    return res

  //validate last_weapon value
  local unit = ::getAircraftByName(unitName)
  if (!unit)
    return res
  foreach(weapon in unit.weapons)
    if (::is_weapon_visible(unit, weapon)
        && ::is_weapon_enabled(unit, weapon))
    {
      ::set_last_weapon(unitName, weapon.name)
      return weapon.name
    }
  return res
}

local function setLastWeapon(unitName, weaponName)
{
  if (weaponName == getLastWeapon(unitName))
    return

  ::set_last_weapon(unitName, weaponName)
  ::broadcastEvent("UnitWeaponChanged", { unitName = unitName, weaponName = weaponName })
}

local function getSecondaryWeaponsList(unit)
{
  local weaponsList = []
  local unitName = unit.name
  local lastWeapon = ::get_last_weapon(unitName)
  foreach(weapon in unit.weapons)
  {
    if (::isWeaponAux(weapon))
      continue

    weaponsList.append(weapon)
    if (lastWeapon=="" && ::shop_is_weapon_purchased(unitName, weapon.name))
      setLastWeapon(unitName, weapon.name)
  }

  return weaponsList
}

local function addWeaponsFromBlk(weapons, block, unit, weaponsFilterFunc = null)
{
  local unitType = ::get_es_unit_type(unit)

  foreach (weapon in (block % "Weapon"))
  {
    if (weapon?.dummy)
      continue

    if (!weapon?.blk)
      continue

    local weaponBlk = ::DataBlock( weapon.blk )
    if (!weaponBlk)
      continue

    if (weaponsFilterFunc?(weapon.blk, weaponBlk) == false)
      continue

    local currentTypeName = "turrets"
    local unitName = "bullet"

    if (weaponBlk?.rocketGun)
    {
      currentTypeName = ""
      switch (weapon?.trigger)
      {
        case "atgm":
        case "agm":     currentTypeName = "agm";      break
        case "aam":     currentTypeName = "aam";      break
        case "flares":  currentTypeName = "flares";   break
        default:        currentTypeName = "rockets"
      }
      if (weapon?.triggerGroup == "smoke")
        currentTypeName = "smoke"
      unitName = "rocket"
    }
    else if (weaponBlk?.bombGun)
    {
      currentTypeName = "bombs"
      unitName = "bomb"
    }
    else if (weaponBlk?.torpedoGun)
    {
      currentTypeName = "torpedoes"
      unitName = "torpedo"
    }
    else if (unitType == ::ES_UNIT_TYPE_TANK
             || ::isInArray(weapon.trigger, [ "machine gun", "cannon", "additional gun", "rockets",
                  "agm", "aam", "bombs", "torpedoes", "smoke", "flares" ]))
    { //not a turret
      currentTypeName = "guns"
      if (weaponBlk?.bullet && typeof(weaponBlk?.bullet) == "instance"
          && ::isCaliberCannon(1000 * ::getTblValue("caliber", weaponBlk?.bullet, 0)))
        currentTypeName = "cannons"
    }
    else if (weaponBlk?.fuelTankGun || weaponBlk?.boosterGun || weaponBlk?.airDropGun || weaponBlk?.undercarriageGun)
      continue

    local isTurret = currentTypeName == "turrets"

    local bullets = weapon?.bullets ?? 0
    if (bullets <= 0)
      bullets = ::max(weaponBlk?.bullets, 0)

    local item = {
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
    }

    local needBulletParams = !::isInArray(currentTypeName, [ "smoke", "flares" ])

    if (needBulletParams && unitName.len() && weaponBlk?[unitName])
    {
      local itemBlk = weaponBlk[unitName]
      item.caliber = itemBlk?.caliber ?? item.caliber
      item.massKg = itemBlk?.mass ?? item.massKg
      item.massLbs = itemBlk?.mass_lbs ?? item.massLbs
      item.explosiveType = itemBlk?.explosiveType ?? item.explosiveType
      item.explosiveMass = itemBlk?.explosiveMass ?? item.explosiveMass

      if (::isInArray(currentTypeName, [ "rockets", "agm", "aam" ]))
      {
        item.maxSpeed <- itemBlk?.maxSpeed ?? itemBlk?.endSpeed ?? 0

        if (currentTypeName == "aam" || currentTypeName == "agm")
        {
          if (itemBlk?.operated == true)
            item.autoAiming <- itemBlk?.autoAiming ?? false
          else
            item.guidanceType <- itemBlk?.guidanceType
        }
        if (currentTypeName == "aam")
        {
          item.loadFactorMax <- itemBlk?.loadFactorMax ?? 0
          item.seekerRangeRearAspect <- itemBlk?.irSeeker?.rangeBand0 ?? 0
          item.seekerRangeAllAspect  <- itemBlk?.irSeeker?.rangeBand1 ?? 0
          if (item.seekerRangeRearAspect > 0 || item.seekerRangeAllAspect > 0)
            item.allAspect <- item.seekerRangeAllAspect * 1.0 >= 0.2 * item.seekerRangeRearAspect
          if (itemBlk?.guidanceType == "ir" && (itemBlk?.irSeeker?.bandMaskToReject ?? 0) != 0)
            item.seekerECCM <- true
        }
        else if (currentTypeName == "agm")
        {
          item.operatedDist <- itemBlk?.operatedDist ?? 0
        }
      }
      else  if (currentTypeName == "torpedoes")
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

    if(isTurret && weapon.turret)
    {
      local turretInfo = weapon.turret
      item.turret = ::u.isDataBlock(turretInfo) ? turretInfo.head : turretInfo
    }

    if (!(currentTypeName in weapons))
      weapons[ currentTypeName ] <- []

    local weaponName = ::get_weapon_name_by_blk_path(weapon.blk)
    local trIdx = -1
    foreach(idx, t in weapons[currentTypeName])
      if (weapon.trigger == t.trigger ||
          ((weaponName in t) && ::is_weapon_params_equal(item, t[weaponName])))
      {
        trIdx = idx
        break
      }

    // Merging duplicating weapons with different weaponName
    // (except guns, because there exists different guns with equal params)
    if (trIdx >= 0 && !(weaponName in weapons[currentTypeName][trIdx]) && unitName != "bullet")
      foreach (name, existingItem in weapons[currentTypeName][trIdx])
        if (::is_weapon_params_equal(item, existingItem))
        {
          weaponName = name
          break
        }

    if (trIdx < 0)
    {
      weapons[currentTypeName].append({ trigger = weapon.trigger, caliber = 0 })
      trIdx = weapons[currentTypeName].len() - 1
    }

    local currentType = weapons[currentTypeName][trIdx]

    if (!(weaponName in currentType))
    {
      currentType[weaponName] <- item
      if (item.caliber > currentType.caliber)
        currentType.caliber = item.caliber
    }
    currentType[weaponName].ammo += bullets
    currentType[weaponName].num += 1
  }

  return weapons
}

//weapon - is a weaponData gathered by addWeaponsFromBlk
local function getWeaponExtendedInfo(weapon, weaponType, unit, ediff, newLine)
{
  local res = ""

  local massText = null
  if (weapon.massLbs > 0)
    massText = format(::loc("mass/lbs"), weapon.massLbs)
  else if (weapon.massKg > 0)
    massText = format(::loc("mass/kg"), weapon.massKg)
  if (massText)
    res += newLine + ::loc("shop/tank_mass") + " " + massText

  if (::isInArray(weaponType, [ "rockets", "agm", "aam" ]))
  {
    if (weapon?.guidanceType != null || weapon?.autoAiming != null)
    {
      local guidanceTxt = weapon?.autoAiming != null
        ? ::loc("missile/aiming/{0}".subst(weapon.autoAiming ? "semiautomatic" : "manual"))
        : ::loc("missile/guidance/{0}".subst(weapon.guidanceType))
      res += newLine + ::loc("missile/guidance") + ::loc("ui/colon") + guidanceTxt
    }
    if (weapon?.allAspect != null)
      res += newLine + ::loc("missile/aspect") + ::loc("ui/colon")
        + ::loc("missile/aspect/{0}".subst(weapon.allAspect ? "allAspect" : "rearAspect"))
    if (weapon?.seekerRangeRearAspect)
      res += newLine + ::loc("missile/seekerRange/rearAspect") + ::loc("ui/colon")
             + ::g_measure_type.DISTANCE.getMeasureUnitsText(weapon.seekerRangeRearAspect)
    if (weapon?.seekerRangeAllAspect)
      res += newLine + ::loc("missile/seekerRange/allAspect") + ::loc("ui/colon")
             + ::g_measure_type.DISTANCE.getMeasureUnitsText(weapon.seekerRangeAllAspect)
    if (weapon?.seekerECCM)
      res += newLine + ::loc("missile/eccm") + ::loc("ui/colon") + ::loc("options/yes")

    if (weapon?.maxSpeed)
      res += newLine + ::loc("rocket/maxSpeed") + ::loc("ui/colon")
        + ::g_measure_type.SPEED_PER_SEC.getMeasureUnitsText(weapon.maxSpeed)
    if (weapon?.loadFactorMax)
      res += newLine + ::loc("missile/loadFactorMax") + ::loc("ui/colon")
             + ::g_measure_type.GFORCE.getMeasureUnitsText(weapon.loadFactorMax)
    if (weapon?.operatedDist)
      res += newLine + ::loc("firingRange") + ::loc("ui/colon")
             + ::g_measure_type.DISTANCE.getMeasureUnitsText(weapon.operatedDist)
  }
  else if (weaponType == "torpedoes")
  {
    local torpedoMod = "torpedoes_movement_mode"
    if (::shop_is_modification_enabled(unit.name, torpedoMod))
    {
      local mod = ::getModificationByName(unit, torpedoMod)
      local diffId = ::get_difficulty_by_ediff(ediff ?? ::get_current_ediff()).crewSkillName
      local effects = mod?.effects?[diffId]
      if (effects)
      {
        weapon = clone weapon
        foreach (k, v in weapon)
        {
          local kEffect = k + "Torpedo"
          if ((kEffect in effects) && type(v) == type(effects[kEffect]))
            weapon[k] += effects[kEffect]
        }
      }
    }

    if (weapon?.maxSpeedInWater)
      res += newLine + ::loc("torpedo/maxSpeedInWater") + ::loc("ui/colon")
             + ::g_measure_type.SPEED.getMeasureUnitsText(weapon?.maxSpeedInWater)

    if (weapon?.distToLive)
      res += newLine + ::loc("torpedo/distanceToLive") + ::loc("ui/colon")
             + ::g_measure_type.DISTANCE.getMeasureUnitsText(weapon?.distToLive)

    if (weapon?.diveDepth)
      res += newLine + ::loc("bullet_properties/diveDepth") + ::loc("ui/colon")
             + ::g_measure_type.DEPTH.getMeasureUnitsText(weapon?.diveDepth)

    if (weapon?.armDistance)
      res += newLine + ::loc("torpedo/armingDistance") + ::loc("ui/colon")
             + ::g_measure_type.DEPTH.getMeasureUnitsText(weapon?.armDistance)
  }

  if (!weapon.explosiveType)
    return res

  res += newLine + ::loc("bullet_properties/explosiveType") + ::loc("ui/colon")
         + ::loc("explosiveType/" + weapon.explosiveType)
  if (weapon.explosiveMass)
  {
    local measureType = ::g_measure_type.getTypeByName("kg", true)
    res += newLine + ::loc("bullet_properties/explosiveMass") + ::loc("ui/colon")
             + measureType.getMeasureUnitsText(weapon.explosiveMass)
  }
  if (weapon.explosiveType && weapon.explosiveMass)
  {
    local tntEqText = ::g_dmg_model.getTntEquivalentText(weapon.explosiveType, weapon.explosiveMass)
    if (tntEqText.len())
      res += newLine + ::loc("bullet_properties/explosiveMassInTNTEquivalent") + ::loc("ui/colon") + tntEqText
  }

  if (/*weaponType == "rockets" || */ (weaponType == "bombs" && unit.unitType != ::g_unit_type.SHIP))
  {
    local destrTexts = ::g_dmg_model.getDestructionInfoTexts(weapon.explosiveType, weapon.explosiveMass, weapon.massKg)
    foreach(name in ["maxArmorPenetration", "destroyRadiusArmored", "destroyRadiusNotArmored"])
    {
      local valueText = destrTexts[name + "Text"]
      if (valueText.len())
        res += newLine + ::loc("bombProperties/" + name) + ::loc("ui/colon") + valueText
    }
  }

  return res
}

local function getPresetsWeaponry(unit, p = WEAPON_TEXT_PARAMS)
{
  if (!unit)
    return null

  local unitBlk = ::get_full_unit_blk(unit.name)
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
      local curWeap = (typeof(p.weaponPreset) == "string") ? p.weaponPreset : getLastWeapon(unit.name)
      foreach(idx, w in unit.weapons)
        if (w.name == curWeap || (weaponPresetIdx < 0 && !::isWeaponAux(w)))
          weaponPresetIdx = idx
      if (weaponPresetIdx < 0)
        return weapons
    }
    if (p.isPrimary && typeof(p.weaponPreset)=="string")
      primaryMod = p.weaponPreset
    else
      primaryMod = ::get_last_primary_weapon(unit)
  } else
    weaponPresetIdx = p.weaponPreset

  if (p.isPrimary || p.isPrimary==null)
  {
    local primaryBlk = ::getCommonWeaponsBlk(unitBlk, primaryMod)
    if (primaryBlk)
      weapons = addWeaponsFromBlk({}, primaryBlk, unit, p.weaponsFilterFunc)
  }

  if (unitBlk?.weapon_presets != null && !p.isPrimary)
  {
    local wpBlk = null
    foreach (wp in (unitBlk.weapon_presets % "preset"))
    {
      if (wp.name == unit.weapons?[weaponPresetIdx]?.name)
      {
        wpBlk = ::DataBlock(wp.blk)
        break
      }
    }

    if (!wpBlk)
      return weapons
    weapons = addWeaponsFromBlk(weapons, wpBlk, unit, p.weaponsFilterFunc)
  }

  return weapons
}

return {
  WEAPON_TYPE             = WEAPON_TYPE
  WEAPON_TEXT_PARAMS      = WEAPON_TEXT_PARAMS
  getLastWeapon           = getLastWeapon
  setLastWeapon           = setLastWeapon
  getSecondaryWeaponsList = getSecondaryWeaponsList
  addWeaponsFromBlk       = addWeaponsFromBlk
  getWeaponExtendedInfo   = getWeaponExtendedInfo
  getPresetsWeaponry      = getPresetsWeaponry
}