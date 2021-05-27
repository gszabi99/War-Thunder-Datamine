local stdMath = require("std/math.nut")
local { copyParamsToTable } = require("std/datablock.nut")
local { WEAPON_TYPE,
        isCaliberCannon,
        getWeaponNameByBlkPath } = require("scripts/weaponry/weaponryInfo.nut")
local { getModificationByName, updateRelationModificationList,
  getModificationBulletsGroup } = require("scripts/weaponry/modificationInfo.nut")

local bulletIcons = {}
local bulletAspectRatio = {}

local bulletsFeaturesImg = [
  { id = "damage", values = [] }
  { id = "armor",  values = [] }
]

local getBulletsFeaturesImg = @() bulletsFeaturesImg

const MAX_BULLETS_ON_ICON = 4
const DEFAULT_BULLET_IMG_ASPECT_RATIO = 0.2

local function getUniqModificationText(modifName, isShortDesc)
{
  if (modifName == "premExpMul")
  {
    local value = ::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText(
      (::get_ranks_blk()?.goldPlaneExpMul ?? 1.0) - 1.0, false)
    local ending = isShortDesc? "" : "/desc"
    return ::loc("modification/" + modifName + ending, "", { value = value })
  }
  return null
}

local function getBulletAnnotation(name, addName=null)
{
  local txt = ::loc(name + "/name/short")
  if (addName)
    txt = $"{txt}{::loc(addName + "/name/short")}"
  txt = $"{txt} - {::loc(name + "/name")}"
  if (addName)
    txt = $"{txt} {::loc(addName + "/name")}"
  return txt
}

// Generate text description for air.modifications[modificationNo]
local function getModificationInfo(air, modifName, bulletsSet, isShortDesc=false,
  limitedName = false, obj = null, itemDescrRewriteFunc = null)
{
  local res = {desc = "", delayed = false}
  if (typeof(air) == "string")
    air = getAircraftByName(air)
  if (!air)
    return res

  local uniqText = getUniqModificationText(modifName, isShortDesc)
  if (uniqText)
  {
    res.desc = uniqText
    return res
  }

  local mod = getModificationByName(air, modifName)
  local ammo_pack_len = 0
  if (modifName.indexof("_ammo_pack") != null && mod)
  {
    updateRelationModificationList(air, modifName);
    if ("relationModification" in mod && mod.relationModification.len() > 0)
    {
      modifName = mod.relationModification[0];
      ammo_pack_len = mod.relationModification.len()
    }
  }

  local groupName = getModificationBulletsGroup(modifName)
  if (groupName=="") //not bullets
  {
    if (!isShortDesc && itemDescrRewriteFunc)
      res.delayed = ::calculate_mod_or_weapon_effect(air.name, modifName, true, obj,
        itemDescrRewriteFunc, null) ?? true

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
      if (isCaliberCannon(caliber))
        res.desc = ::locEnding(locId + "/cannon", ending, "")
      if (res.desc=="")
        res.desc = ::locEnding(locId, ending)
      if (caliber > 0)
        res.desc = ::format(res.desc, caliber.tostring())
    }
    return res //without effects atm
  }

  //bullets sets

  if (isShortDesc && !mod && bulletsSet?.weaponType == WEAPON_TYPE.GUNS
    && !air.unitType.canUseSeveralBulletsForGun)
  {
    res.desc = ::loc("modification/default_bullets")
    return res
  }

  if (!bulletsSet)
  {
    if (res.desc == "")
      res.desc = modifName + " not found bullets"
    return res
  }

  local shortDescr = "";
  if (isShortDesc || ammo_pack_len) //bullets name
  {
    local locId = modifName
    local caliber = limitedName? bulletsSet.caliber.tointeger() : bulletsSet.caliber
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
    if (bulletsSet?.bulletNames?[0] && bulletsSet.weaponType != WEAPON_TYPE.COUNTERMEASURES
      && (bulletsSet.weaponType != WEAPON_TYPE.GUNS || !bulletsSet.isBulletBelt ||
      (isCaliberCannon(caliber) && air.unitType.canUseSeveralBulletsForGun)))
    {
      locId = bulletsSet.bulletNames[0]
      shortDescr = ::loc(locId, ::loc("weapons/" + locId + "/short", locId))
    }
    if (!mod && air.unitType.canUseSeveralBulletsForGun && bulletsSet.isBulletBelt)
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
    if ("bulletNames" in bulletsSet && typeof(bulletsSet.bulletNames) == "array"
      && bulletsSet.bulletNames.len())
        shortDescr = format(::loc(bulletsSet.isBulletBelt
          ? "modification/ammo_pack_belt/desc" : "modification/ammo_pack/desc"), shortDescr)
    if (ammo_pack_len > 1)
    {
      res.desc = shortDescr
      return res
    }
  }

  //bullets description
  local separator = ::loc("bullet_type_separator/name")
  local usedLocs = []
  local annArr = []
  local txtArr = []
  foreach(b in bulletsSet.bullets)
  {
    local part = b.indexof("@")
    txtArr.append("".join(part == null ? [::loc($"{b}/name/short")]
      : [::loc($"{b.slice(0, part)}/name/short"), ::loc($"{b.slice(part+1)}/name/short")]))
    if (!::isInArray(b, usedLocs))
    {
      annArr.append(part == null ? getBulletAnnotation(b)
        : getBulletAnnotation(b.slice(0, part), b.slice(part+1)))
      usedLocs.append(b)
    }
  }
  local setText = separator.join(txtArr)
  local annotation = "\n".join(annArr)

  if (ammo_pack_len)
    res.desc = shortDescr + "\n"
  if (bulletsSet.weaponType == WEAPON_TYPE.COUNTERMEASURES)
    res.desc += ::loc("countermeasures/desc") + "\n\n"
  else if (bulletsSet.bullets.len() > 1)
    res.desc += format(::loc("caliber_" + bulletsSet.caliber + "/desc"), setText) + "\n\n"
  res.desc += annotation
  return res
}

local function getModificationName(air, modifName,  bulletsSet, limitedName = false)
{
  return getModificationInfo(air, modifName, bulletsSet, true, limitedName).desc
}

local function initBulletIcons(blk = null)
{
  if (bulletIcons.len())
    return

  if (!blk)
    blk = ::configs.GUI.get()

  copyParamsToTable(blk?.bullet_icons, bulletIcons)
  copyParamsToTable(blk?.bullet_icon_aspect_ratio, bulletAspectRatio)

  local bf = blk?.bullets_features_icons
  if (bf)
    foreach(item in bulletsFeaturesImg)
      item.values = bf % item.id
}

local function getBulletImage(bulletsSet, bulletIndex, needFullPath = true)
{
  local imgId = bulletsSet.bullets[bulletIndex]
  if (bulletsSet?.customIconsMap[imgId] != null)
    imgId = bulletsSet.customIconsMap[imgId]
  if (imgId.indexof("@") != null)
    imgId = imgId.slice(0, imgId.indexof("@"))
  local defaultImgId = isCaliberCannon(1000 * (bulletsSet?.caliber ?? 0.0))
    ? "default_shell" : "default_ball"
  local textureId = bulletIcons?[imgId] ?? bulletIcons?[defaultImgId]
  return needFullPath ? $"#ui/gameuiskin#{textureId}" : textureId
}

local function getBulletsIconView(bulletsSet, tooltipId = null, tooltipDelayed = false)
{
  local view = {}
  if (!bulletsSet || !("bullets" in bulletsSet))
    return view

  initBulletIcons()
  view.bullets <- (@(bulletsSet, tooltipId, tooltipDelayed) function () {
      local res = []

      local length = bulletsSet.bullets.len()
      local isBelt = bulletsSet?.isBulletBelt ?? true

      local ratio = 1.0
      local count = 1
      if (isBelt)
      {
        ratio = bulletAspectRatio?[getBulletImage(bulletsSet, 0, false)]
          ?? bulletAspectRatio?["default"]
          ?? DEFAULT_BULLET_IMG_ASPECT_RATIO
        local maxAmountInView = (bulletsSet?.weaponType == WEAPON_TYPE.COUNTERMEASURES)
          ? 1 : ::min(MAX_BULLETS_ON_ICON, (1.0 / ratio).tointeger())
        if (bulletsSet.catridge)
          maxAmountInView = ::min(bulletsSet.catridge, maxAmountInView)
        count = length * ::max(1, ::floor(maxAmountInView / length))
      }

      local totalWidth = 100.0
      local itemWidth = totalWidth * ratio
      local itemHeight = totalWidth
      local space = totalWidth - itemWidth * count
      local separator = (space > 0)
        ? (space / (count + 1))
        : (count == 1 ? space : (space / (count - 1)))
      local start = (space > 0) ? separator : 0.0

      for (local i = 0; i < count; i++)
      {
        local item = {
          image           = getBulletImage(bulletsSet, i % length)
          posx            = (start + (itemWidth + separator) * i) + "%pw"
          sizex           = itemWidth + "%pw"
          sizey           = itemHeight + "%pw"
          useTooltip      = tooltipId != null
          tooltipId       = tooltipId
          tooltipDelayed  = tooltipId != null && tooltipDelayed
        }
        res.append(item)
      }

      return res
    })(bulletsSet, tooltipId, tooltipDelayed)

  local bIconParam = bulletsSet?.bIconParam
  local isBelt = bulletsSet?.isBulletBelt ?? true
  if (bIconParam && !isBelt)
  {
    local addIco = []
    foreach(item in getBulletsFeaturesImg())
    {
      local idx = bIconParam?[item.id] ?? -1
      if (idx in item.values)
        addIco.append({ img = item.values[idx] })
    }
    if (addIco.len())
      view.addIco <- addIco
  }
  return view
}

local function getBulletsIconData(bulletsSet)
{
  if (!bulletsSet)
    return ""
  return ::handyman.renderCached(("gui/weaponry/bullets"), getBulletsIconView(bulletsSet))
}

local function getArmorPiercingViewData(armorPiercing, dist)
{
  local res = null
  if (armorPiercing.len() <= 0)
    return res

  local angles = null
  foreach(ind, armorTbl in armorPiercing)
  {
    if (armorTbl == null)
      continue
    if (!angles)
    {
      res = []
      angles = ::u.keys(armorTbl)
      angles.sort(@(a,b) a <=> b)
      local headRow = {
        text = ""
        values = ::u.map(angles, function(v) { return { value = v + ::loc("measureUnits/deg") } })
      }
      res.append(headRow)
    }

    local row = {
      text = dist[ind] + ::loc("measureUnits/meters_alt")
      values = []
    }
    foreach(angle in angles)
      row.values.append({ value = $"{armorTbl?[angle] ?? 0}{::loc("measureUnits/mm")}" })
    res.append(row)
  }
  return res
}

local buildPiercingData = ::kwarg(function buildPiercingData(bullet_parameters, descTbl,
  bulletsSet = null, needAdditionalInfo = false, weaponName = "")
{
  local param = { armorPiercing = array(0, null) , armorPiercingDist = array(0, null)}
  local needAddParams = bullet_parameters.len() == 1

  local isSmokeShell = bulletsSet?.weaponType == WEAPON_TYPE.GUNS
    && bulletsSet?.bullets?[0] == "smoke_tank"
  local isSmokeGenerator = isSmokeShell || bulletsSet?.weaponType == WEAPON_TYPE.SMOKE
  local isCountermeasure = isSmokeGenerator || bulletsSet?.weaponType == WEAPON_TYPE.FLARES

  if (isCountermeasure)
  {
    local whitelistParams = [ "bulletType" ]
    if (isSmokeShell)
      whitelistParams.append("mass", "speed", "weaponBlkPath")
    local filteredBulletParameters = []
    foreach (_params in bullet_parameters)
    {
      local params = _params ? {} : null
      if (_params)
      {
        foreach (key in whitelistParams)
          if (key in _params)
            params[key] <- _params[key]

        params.armorPiercing     <- []
        params.armorPiercingDist <- []
      }
      filteredBulletParameters.append(params)
    }
    bullet_parameters = filteredBulletParameters
  }

  foreach (bullet_params in bullet_parameters)
  {
    if (!bullet_params)
      continue

    if (bullet_params?.bulletType != "aam")
    {
      if (param.armorPiercingDist.len() < bullet_params.armorPiercingDist.len())
      {
        param.armorPiercing.resize(bullet_params.armorPiercingDist.len());
        param.armorPiercingDist = bullet_params.armorPiercingDist;
      }
      foreach(ind, d in param.armorPiercingDist)
      {
        for (local i = 0; i < bullet_params.armorPiercingDist.len(); i++)
        {
          local armor = null;
          local idist = bullet_params.armorPiercingDist[i].tointeger()
          if (typeof(bullet_params.armorPiercing[i]) != "table")
            continue

          if (d == idist || (d < idist && !i))
            armor = ::u.map(bullet_params.armorPiercing[i], @(f) stdMath.round(f).tointeger())
          else if (d < idist && i)
          {
            local prevDist = bullet_params.armorPiercingDist[i-1].tointeger()
            if (d > prevDist)
              armor = ::u.tablesCombine(bullet_params.armorPiercing[i-1], bullet_params.armorPiercing[i],
                        (@(d, prevDist, idist) function(prev, next) {
                          return (prev + (next - prev) * (d - prevDist.tointeger()) / (idist - prevDist)).tointeger()
                        })(d, prevDist, idist), 0)
          }
          if (armor == null)
            continue

          param.armorPiercing[ind] = (!param.armorPiercing[ind])
            ? armor : ::u.tablesCombine(param.armorPiercing[ind], armor, ::max)
        }
      }
    }

    if (!needAddParams)
      continue

    foreach(p in ["mass", "speed", "fuseDelayDist", "explodeTreshold", "operatedDist", "machMax",
      "endSpeed", "maxSpeed", "rangeBand0", "rangeBand1"])
      param[p] <- bullet_params?[p] ?? 0

    foreach(p in ["reloadTimes", "autoAiming", "weaponBlkPath"])
    {
      if(p in bullet_params)
        param[p] <- bullet_params[p]
    }

    if(bulletsSet)
    {
      foreach(p in ["caliber", "explosiveType", "explosiveMass",
        "proximityFuseArmDistance", "proximityFuseRadius" ])
      if (p in bulletsSet)
        param[p] <- bulletsSet[p]

      if (isSmokeGenerator)
        foreach(p in ["smokeShellRad", "smokeActivateTime", "smokeTime"])
          if (p in bulletsSet)
            param[p] <- bulletsSet[p]
    }

    param.bulletType <- bullet_params?.bulletType ?? ""
    param.ricochetPreset <- bullet_params?.ricochetPreset
  }

  descTbl.bulletParams <- []
  local p = []
  local addProp = function(arr, text, value)
  {
    arr.append({
      text = text
      value = value
    })
  }
  if (needAdditionalInfo && "mass" in param)
  {
    if (param.caliber > 0)
      addProp(p, ::loc("bullet_properties/caliber"), stdMath.round_by_value(param.caliber,
        isCaliberCannon(param.caliber) ? 1 : 0.01) + " " + ::loc("measureUnits/mm"))
    if (param.mass > 0)
      addProp(p, ::loc("bullet_properties/mass"),
        ::g_measure_type.getTypeByName("kg", true).getMeasureUnitsText(param.mass))
    if (param.speed > 0)
      addProp(p, ::loc("bullet_properties/speed"),
        ::format("%.0f %s", param.speed, ::loc("measureUnits/metersPerSecond_climbSpeed")))

    local maxSpeed = (param?.maxSpeed ?? 0) || (param?.endSpeed ?? 0)
    if (param?.machMax)
      addProp(p, "".concat(::loc("rocket/maxSpeed"),
        ::format("%.1f %s", param.machMax, ::loc("measureUnits/machNumber"))))
    else if (maxSpeed)
      addProp(p, ::loc("rocket/maxSpeed"),
        ::g_measure_type.SPEED_PER_SEC.getMeasureUnitsText(maxSpeed))

    if ("autoAiming" in param)
    {
      local aimingTypeLocId = "guidanceSystemType/" + (param.autoAiming ? "semiAuto" : "handAim")
      addProp(p, ::loc("guidanceSystemType/header"), ::loc(aimingTypeLocId))
    }

    local operatedDist = param?.operatedDist ?? 0
    if (operatedDist)
      addProp(p, ::loc("firingRange"), ::g_measure_type.DISTANCE.getMeasureUnitsText(operatedDist))

    local explosiveType = param?.explosiveType
    if (explosiveType)
      addProp(p, ::loc("bullet_properties/explosiveType"), ::loc("explosiveType/" + explosiveType))
    local explosiveMass = param?.explosiveMass
    if (explosiveMass)
      addProp(p, ::loc("bullet_properties/explosiveMass"),
        ::g_dmg_model.getMeasuredExplosionText(explosiveMass))

    if (explosiveType && explosiveMass)
    {
      local tntEqText = ::g_dmg_model.getTntEquivalentText(explosiveType, explosiveMass)
      if (tntEqText.len())
        addProp(p, ::loc("bullet_properties/explosiveMassInTNTEquivalent"), tntEqText)
    }

    local fuseDelayDist = stdMath.roundToDigits(param.fuseDelayDist, 2)
    if (fuseDelayDist)
      addProp(p, ::loc("bullet_properties/fuseDelayDist"),
                 fuseDelayDist + " " + ::loc("measureUnits/meters_alt"))
    local explodeTreshold = stdMath.roundToDigits(param.explodeTreshold, 2)
    if (explodeTreshold)
      addProp(p, ::loc("bullet_properties/explodeTreshold"),
                 explodeTreshold + " " + ::loc("measureUnits/mm"))
    local rangeBand0 = param?.rangeBand0
    if (rangeBand0)
      addProp(p, ::loc("missile/seekerRange/rearAspect"),
        ::g_measure_type.DISTANCE.getMeasureUnitsText(rangeBand0))
    local rangeBand1 = param?.rangeBand1
    if (rangeBand1)
      addProp(p, ::loc("missile/seekerRange/allAspect"),
        ::g_measure_type.DISTANCE.getMeasureUnitsText(rangeBand1))

    local proximityFuseArmDistance = stdMath.round(param?.proximityFuseArmDistance ?? 0)
    if (proximityFuseArmDistance)
      addProp(p, ::loc("torpedo/armingDistance"),
        proximityFuseArmDistance + " " + ::loc("measureUnits/meters_alt"))
    local proximityFuseRadius = stdMath.round(param?.proximityFuseRadius ?? 0)
    if (proximityFuseRadius)
      addProp(p, ::loc("bullet_properties/proximityFuze/triggerRadius"),
        proximityFuseRadius + " " + ::loc("measureUnits/meters_alt"))

    local ricochetData = !isCountermeasure && ::g_dmg_model.getRicochetData(param?.ricochetPreset)
    if (ricochetData)
      foreach(item in ricochetData.angleProbabilityMap)
        addProp(p, ::loc("bullet_properties/angleByProbability",
          { probability = stdMath.roundToDigits(100.0 * item.probability, 2) }),
            stdMath.roundToDigits(item.angle, 2) + ::loc("measureUnits/deg"))

    if ("reloadTimes" in param)
    {
      local currentDiffficulty = ::is_in_flight() ? ::get_mission_difficulty_int()
        : ::get_current_shop_difficulty().diffCode
      local reloadTime = param.reloadTimes[currentDiffficulty]
      if(reloadTime > 0)
        addProp(p, ::colorize("badTextColor", ::loc("bullet_properties/cooldown")),
          ::colorize("badTextColor", stdMath.roundToDigits(reloadTime, 2)
            + " " + ::loc("measureUnits/seconds")))
    }

    if ("smokeShellRad" in param)
      addProp(p, ::loc("bullet_properties/smokeShellRad"),
        stdMath.roundToDigits(param.smokeShellRad, 2) + " " + ::loc("measureUnits/meters_alt"))

    if ("smokeActivateTime" in param)
      addProp(p, ::loc("bullet_properties/smokeActivateTime"),
        stdMath.roundToDigits(param.smokeActivateTime, 2) + " " + ::loc("measureUnits/seconds"))

    if ("smokeTime" in param)
      addProp(p, ::loc("bullet_properties/smokeTime"),
                 stdMath.roundToDigits(param.smokeTime, 2) + " " + ::loc("measureUnits/seconds"))

    local bTypeDesc = ::loc(param.bulletType, "")
    if (bTypeDesc != "")
      descTbl.bulletsDesc <- bTypeDesc
  }
  descTbl.bulletParams.append({ props = p })

  local currWeaponName = ""
  if("weaponBlkPath" in param)
    currWeaponName = getWeaponNameByBlkPath(param.weaponBlkPath)

  local bulletName = currWeaponName != "" ? ::loc("weapons/{0}".subst(currWeaponName)) : ""
  local apData = null
  if ((weaponName != "" ? weaponName : currWeaponName) == currWeaponName)
    apData = getArmorPiercingViewData(param.armorPiercing, param.armorPiercingDist)

  if (apData)
  {
    local header = ::loc("bullet_properties/armorPiercing")
      + (::u.isEmpty(bulletName) ? "" : ( ": " + bulletName))
      + "\n" + ::format("(%s / %s)", ::loc("distance"), ::loc("bullet_properties/hitAngle"))
    descTbl.bulletParams.append({ props = apData, header = header })
  }
})

local function getSingleBulletParamToDesc(unit, locName, bulletName, bulletsSet, bulletParams)
{
  local descTbl = { name = ::colorize("activeTextColor", locName), desc = "", bulletActions = []}
  local part = bulletName.indexof("@")
    descTbl.desc = part == null ? getBulletAnnotation(bulletName)
      : getBulletAnnotation(bulletName.slice(0, part), bulletName.slice(part+1))

  if (!unit.unitType.canUseSeveralBulletsForGun && !::has_feature("BulletParamsForAirs"))
    return descTbl

  descTbl.bulletActions = [{ visual = getBulletsIconData(bulletsSet) }]
  buildPiercingData({
    bulletsSet = bulletsSet,
    bullet_parameters = [bulletParams],
    descTbl = descTbl,
    needAdditionalInfo = true
  })
  return descTbl
}

local function addBulletsParamToDesc(descTbl, unit, item, bulletsSet, searchName, modEffect)
{
  if (!unit.unitType.canUseSeveralBulletsForGun && !::has_feature("BulletParamsForAirs"))
    return

  if (!bulletsSet)
    return

  if (::has_feature("BulletAnimation") && bulletsSet?.bulletAnimation != null
      && ::dd_file_exist(bulletsSet.bulletAnimation))
    descTbl.bulletAnimation <- bulletsSet?.bulletAnimation
  local bIconParam = bulletsSet?.bIconParam
  local isBelt = bulletsSet?.isBulletBelt ?? true
  if (bIconParam && !isBelt)
  {
    descTbl.bulletActions <- []
    local setClone = clone bulletsSet
    foreach(p in ["armor", "damage"])
    {
      local value = bIconParam?[p] ?? -1
      if (value < 0)
        continue

      setClone.bIconParam = { [p] = value }
      descTbl.bulletActions.append({
        text = ::loc("bulletAction/" + p)
        visual = getBulletsIconData(setClone)
      })
    }
  }
  else
    descTbl.bulletActions <- [{ visual = getBulletsIconData(bulletsSet) }]

  if (bulletsSet.weaponType == WEAPON_TYPE.COUNTERMEASURES)
    return

  local useDefaultBullet = searchName != item.name
  local bullet_parameters = ::calculate_tank_bullet_parameters(unit.name,
    useDefaultBullet && "weaponBlkName" in bulletsSet ?
      bulletsSet.weaponBlkName :
      modEffect,
    useDefaultBullet, false)

  buildPiercingData({
    bullet_parameters = bullet_parameters,
    descTbl = descTbl,
    bulletsSet = bulletsSet,
    needAdditionalInfo = true})
}

return {
  initBulletIcons
  getModificationInfo
  getModificationName
  addBulletsParamToDesc
  buildPiercingData
  getBulletsIconView
  getSingleBulletParamToDesc
}
