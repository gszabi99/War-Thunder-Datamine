from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { file_exists } = require("dagor.fs")
let { floor, round_by_value, roundToDigits, round, pow } = require("%sqstd/math.nut")
let { copyParamsToTable } = require("%sqstd/datablock.nut")
let {
      //


        getBulletsSetData,
        getBulletAnnotation,
        getBulletsSearchName,
        getModifIconItem,
        getModificationBulletsEffect } = require("%scripts/weaponry/bulletsInfo.nut")
let { WEAPON_TYPE,
  isCaliberCannon, getWeaponNameByBlkPath } = require("%scripts/weaponry/weaponryInfo.nut")
let { saclosMissileBeaconIRSourceBand } = require("%scripts/weaponry/weaponsParams.nut")
let { getMeasuredExplosionText, getTntEquivalentText, getRicochetData, getTntEquivalentDmg
} = require("%scripts/weaponry/dmgModel.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { format } = require("string")

local bulletIcons = {}
local bulletAspectRatio = {}

let bulletsFeaturesImg = [
  { id = "damage", values = [] }
  { id = "armor",  values = [] }
]

let getBulletsFeaturesImg = @() bulletsFeaturesImg

const MAX_BULLETS_ON_ICON = 4
const DEFAULT_BULLET_IMG_ASPECT_RATIO = 0.2

let function resetBulletIcons() {
  bulletIcons.clear()
  bulletAspectRatio.clear()
  foreach (v in bulletsFeaturesImg)
    v.values.clear()
}

addListenersWithoutEnv({
  GuiSceneCleared = @(_p) resetBulletIcons() // Resolution or UI Scale could change
})

let function initBulletIcons(blk = null)
{
  if (bulletIcons.len())
    return

  if (!blk)
    blk = GUI.get()

  copyParamsToTable(blk?.bullet_icons, bulletIcons)
  copyParamsToTable(blk?.bullet_icon_aspect_ratio, bulletAspectRatio)

  let bf = blk?.bullets_features_icons
  if (bf)
    foreach(item in bulletsFeaturesImg)
      item.values = bf % item.id
}

let function getBulletImage(bulletsSet, bulletIndex, needFullPath = true)
{
  local imgId = bulletsSet.bullets[bulletIndex]
  if (bulletsSet?.customIconsMap[imgId] != null)
    imgId = bulletsSet.customIconsMap[imgId]
  if (imgId.indexof("@") != null)
    imgId = imgId.slice(0, imgId.indexof("@"))
  let defaultImgId = isCaliberCannon(1000 * (bulletsSet?.caliber ?? 0.0))
    ? "default_shell" : "default_ball"
  let textureId = bulletIcons?[imgId] ?? bulletIcons?[defaultImgId]
  return needFullPath ? $"#ui/gameuiskin#{textureId}.png" : textureId
}

let function getBulletsIconView(bulletsSet, tooltipId = null, tooltipDelayed = false)
{
  let view = {}
  if (!bulletsSet || !("bullets" in bulletsSet))
    return view

  initBulletIcons()
  view.bullets <- (@(bulletsSet, tooltipId, tooltipDelayed) function () {
      let res = []

      let length = bulletsSet.bullets.len()
      let isBelt = bulletsSet?.isBulletBelt ?? true

      local ratio = 1.0
      local count = 1
      if (isBelt)
      {
        ratio = bulletAspectRatio?[getBulletImage(bulletsSet, 0, false)]
          ?? bulletAspectRatio?["default"]
          ?? DEFAULT_BULLET_IMG_ASPECT_RATIO
        local maxAmountInView = (bulletsSet?.weaponType == WEAPON_TYPE.COUNTERMEASURES)
          ? 1 : min(MAX_BULLETS_ON_ICON, (1.0 / ratio).tointeger())
        if (bulletsSet.catridge)
          maxAmountInView = min(bulletsSet.catridge, maxAmountInView)
        count = length * max(1, floor(maxAmountInView / length))
      }

      let totalWidth = 100.0
      let itemWidth = totalWidth * ratio
      let itemHeight = totalWidth
      let space = totalWidth - itemWidth * count
      let separator = (space > 0)
        ? (space / (count + 1))
        : (count == 1 ? space : (space / (count - 1)))
      let start = (space > 0) ? separator : 0.0

      for (local i = 0; i < count; i++)
      {
        let item = {
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

  let bIconParam = bulletsSet?.bIconParam
  let isBelt = bulletsSet?.isBulletBelt ?? true
  if (bIconParam && !isBelt)
  {
    let addIco = []
    foreach(item in getBulletsFeaturesImg())
    {
      let idx = bIconParam?[item.id] ?? -1
      if (idx in item.values)
        addIco.append({ img = item.values[idx] })
    }
    if (addIco.len())
      view.addIco <- addIco
  }
  return view
}

let function getBulletsIconData(bulletsSet)
{
  if (!bulletsSet)
    return ""
  return ::handyman.renderCached(("%gui/weaponry/bullets.tpl"), getBulletsIconView(bulletsSet))
}

let function getArmorPiercingViewData(armorPiercing, dist)
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
      let headRow = {
        text = ""
        values = ::u.map(angles, function(v) { return { value = v + loc("measureUnits/deg") } })
      }
      res.append(headRow)
    }

    let row = {
      text = dist[ind] + loc("measureUnits/meters_alt")
      values = []
    }
    foreach(angle in angles)
      row.values.append({ value = $"{armorTbl?[angle] ?? 0}{loc("measureUnits/mm")}" })
    res.append(row)
  }
  return res
}

let function addArmorPiercingToDesc(bulletsData, descTbl)
{
  let { armorPiercing, armorPiercingDist } = bulletsData
  let props = getArmorPiercingViewData(armorPiercing, armorPiercingDist)
  if (props == null)
    return

  local currWeaponName = "weaponBlkPath" in bulletsData
    ? getWeaponNameByBlkPath(bulletsData.weaponBlkPath)
    : ""

  let bulletName = currWeaponName != "" ? loc($"weapons/{currWeaponName}") : ""
  let header = "\n".concat(
    "".concat(loc("bullet_properties/armorPiercing"),
      bulletName != "" ? $"{loc("ui/colon")}{bulletName}" : "")
    format("(%s / %s)", loc("distance"), loc("bullet_properties/hitAngle"))
  )

  descTbl.bulletParams <- (descTbl?.bulletParams ?? []).append({props, header})
}

let function addAdditionalBulletsInfoToDesc(bulletsData, descTbl) {
  let p = []
  let addProp = function(arr, text, value)
  {
    arr.append({
      text = text
      value = value
    })
  }

  if ("sonicDamage" in bulletsData) {
    let { distance, speed, horAngles, verAngles } = bulletsData.sonicDamage
    let props = []
    if (distance != null)
      addProp(props, loc("sonicDamage/distance"), ::g_measure_type.DEPTH.getMeasureUnitsText(distance))
    if (speed != null)
      addProp(props, loc("sonicDamage/speed"), ::g_measure_type.SPEED_PER_SEC.getMeasureUnitsText(speed))
    let degText = loc("measureUnits/deg")
    if (horAngles != null)
      addProp(props, loc("sonicDamage/horAngles"),
        format("%+d%s/%+d%s", horAngles.x, degText, horAngles.y, degText))
    if (verAngles != null)
      addProp(props, loc("sonicDamage/verAngles"),
        format("%+d%s/%+d%s", horAngles.x, degText, horAngles.y, degText))
    descTbl.bulletParams <- (descTbl?.bulletParams ?? []).append({ props })
  }

  if ("mass" not in bulletsData)
    return

  if (bulletsData?.kineticDmg && bulletsData.kineticDmg > 0)
    addProp(p, loc("bullet_properties/kineticDmg"), round_by_value(bulletsData.kineticDmg, 10))
  if (bulletsData?.explosiveDmg && bulletsData.explosiveDmg > 0)
    addProp(p, loc("bullet_properties/explosiveDmg"), round_by_value(bulletsData.explosiveDmg, 10))
  if (bulletsData?.cumulativeDmg && bulletsData.cumulativeDmg > 0)
    addProp(p, loc("bullet_properties/cumulativeDmg"), round_by_value(bulletsData.cumulativeDmg, 10))
  if (bulletsData.caliber > 0)
    addProp(p, loc("bullet_properties/caliber"), round_by_value(bulletsData.caliber,
      isCaliberCannon(bulletsData.caliber) ? 1 : 0.01) + " " + loc("measureUnits/mm"))
  if (bulletsData.mass > 0)
    addProp(p, loc("bullet_properties/mass"),
      ::g_measure_type.getTypeByName("kg", true).getMeasureUnitsText(bulletsData.mass))
  if (bulletsData.speed > 0)
    addProp(p, loc("bullet_properties/speed"),
      format("%.0f %s", bulletsData.speed, loc("measureUnits/metersPerSecond_climbSpeed")))

  let maxSpeed = (bulletsData?.maxSpeed ?? 0) || (bulletsData?.endSpeed ?? 0)
  if (bulletsData?.machMax)
    addProp(p, loc("rocket/maxSpeed"),
      format("%.1f %s", bulletsData.machMax, loc("measureUnits/machNumber")))
  else if (maxSpeed)
    addProp(p, loc("rocket/maxSpeed"),
      ::g_measure_type.SPEED_PER_SEC.getMeasureUnitsText(maxSpeed))

  if (bulletsData?.bulletType == "aam" || bulletsData?.bulletType == "sam_tank")
  {
    if ("loadFactorMax" in bulletsData)
      addProp(p, loc("missile/loadFactorMax"),
        ::g_measure_type.GFORCE.getMeasureUnitsText(bulletsData.loadFactorMax))
  }

  if ("autoAiming" in bulletsData)
  {
    let isBeamRider = bulletsData?.isBeamRider ?? false
    let aimingTypeLocId = "".concat("guidanceSystemType/",
      !bulletsData.autoAiming ? "handAim"
      : isBeamRider ? "beamRider"
      : "semiAuto")
    addProp(p, loc("guidanceSystemType/header"), loc(aimingTypeLocId))
    if ("irBeaconBand" in bulletsData)
      if (bulletsData.irBeaconBand != saclosMissileBeaconIRSourceBand.value)
        addProp(p, loc("missile/eccm"), loc("options/yes"))
  }

  if ("guidanceType" in bulletsData)
  {
    if (bulletsData.guidanceType == "ir" || bulletsData.guidanceType == "optical" )
    {
      let targetSignatureType = bulletsData?.targetSignatureType != null ? bulletsData?.targetSignatureType : bulletsData?.visibilityType
      addProp(p, loc("missile/guidance"),
        loc($"missile/guidance/{targetSignatureType == "optic" ? "tv" : "ir"}"))
      if (bulletsData?.bulletType == "aam" || bulletsData?.bulletType == "sam_tank")
      {
        if (bulletsData.bandMaskToReject != 0)
          addProp(p, loc("missile/eccm"), loc("options/yes"))
        addProp(p, loc("missile/aspect"), bulletsData.rangeBand1 > 0 ?
          loc("missile/aspect/allAspect") : loc("missile/aspect/rearAspect"))
        addProp(p, loc("missile/seekerRange/rearAspect"),
          ::g_measure_type.DISTANCE.getMeasureUnitsText(bulletsData.rangeBand0))
        if (bulletsData.rangeBand1 > 0)
          addProp(p, loc("missile/seekerRange/allAspect"),
            ::g_measure_type.DISTANCE.getMeasureUnitsText(bulletsData.rangeBand1))
      }
      else
      {
        if(bulletsData.rangeBand0 > 0 && bulletsData.rangeBand1 > 0)
          addProp(p, loc("missile/seekerRange"),
            ::g_measure_type.DISTANCE.getMeasureUnitsText(min(bulletsData.rangeBand0, bulletsData.rangeBand1)))
      }
    }
    else if (bulletsData.guidanceType == "radar")
    {
      addProp(p, loc("missile/guidance"),
        loc($"missile/guidance/{bulletsData.activeRadar ? "ARH" : "SARH"}"))
      if (bulletsData.distanceGate || bulletsData.dopplerSpeedGate)
        addProp(p, loc("missile/radarSignal"),
          loc($"missile/radarSignal/{bulletsData.dopplerSpeedGate ? (bulletsData.distanceGate ? "pulse_doppler" : "CW") : "pulse"}"))
      if ("radarRange" in bulletsData)
        addProp(p, loc("missile/seekerRange"),
          ::g_measure_type.DISTANCE.getMeasureUnitsText(bulletsData.radarRange))
    }
    else
    {
      addProp(p, loc("missile/guidance"),
        loc($"missile/guidance/{bulletsData.guidanceType}"))
      if ("laserRange" in bulletsData)
        addProp(p, loc("missile/seekerRange"),
          ::g_measure_type.DISTANCE.getMeasureUnitsText(bulletsData.laserRange))
    }
  }

  let operatedDist = bulletsData?.operatedDist ?? 0
  if (operatedDist)
    addProp(p, loc("firingRange"), ::g_measure_type.DISTANCE.getMeasureUnitsText(operatedDist))

  if ("rangeMax" in bulletsData)
    addProp(p, loc("launchRange"), ::g_measure_type.DISTANCE.getMeasureUnitsText(bulletsData.rangeMax))

  if ("guaranteedRange" in bulletsData)
    addProp(p, loc("guaranteedRange"), ::g_measure_type.DISTANCE.getMeasureUnitsText(bulletsData.guaranteedRange))

  if ("timeLife" in bulletsData)
  {
    if ("guidanceType" in bulletsData || "autoAiming" in bulletsData)
      addProp(p, loc("missile/timeGuidance"),
        format("%.1f %s", bulletsData.timeLife, loc("measureUnits/seconds")))
    else
      addProp(p, loc("missile/timeSelfdestruction"),
        format("%.1f %s", bulletsData.timeLife, loc("measureUnits/seconds")))
  }

  let explosiveType = bulletsData?.explosiveType
  if (explosiveType)
    addProp(p, loc("bullet_properties/explosiveType"), loc("explosiveType/" + explosiveType))
  let explosiveMass = bulletsData?.explosiveMass
  if (explosiveMass)
    addProp(p, loc("bullet_properties/explosiveMass"),
      getMeasuredExplosionText(explosiveMass))

  if (explosiveType && explosiveMass)
  {
    let tntEqText = getTntEquivalentText(explosiveType, explosiveMass)
    if (tntEqText.len())
      addProp(p, loc("bullet_properties/explosiveMassInTNTEquivalent"), tntEqText)
  }

  let fuseDelayDist = roundToDigits(bulletsData.fuseDelayDist, 2)
  if (fuseDelayDist > 0)
    addProp(p, loc("bullet_properties/fuseDelayDist"),
      $"{fuseDelayDist} {loc("measureUnits/meters_alt")}")
  let fuseDelay = roundToDigits(bulletsData.fuseDelay, 2)
  if (fuseDelay > 0)
    addProp(p, loc("bullet_properties/fuseDelayDist"),
     $"{fuseDelay} {loc("measureUnits/seconds")}")
  let explodeTreshold = roundToDigits(bulletsData.explodeTreshold, 2)
  if (explodeTreshold)
    addProp(p, loc("bullet_properties/explodeTreshold"),
               explodeTreshold + " " + loc("measureUnits/mm"))

  let proximityFuseArmDistance = round(bulletsData?.proximityFuseArmDistance ?? 0)
  if (proximityFuseArmDistance)
    addProp(p, loc("torpedo/armingDistance"),
      proximityFuseArmDistance + " " + loc("measureUnits/meters_alt"))
  let proximityFuseRadius = round(bulletsData?.proximityFuseRadius ?? 0)
  if (proximityFuseRadius)
    addProp(p, loc("bullet_properties/proximityFuze/triggerRadius"),
      proximityFuseRadius + " " + loc("measureUnits/meters_alt"))

  let ricochetData = !bulletsData.isCountermeasure && getRicochetData(bulletsData?.ricochetPreset)
  if (ricochetData)
    foreach(item in ricochetData.angleProbabilityMap)
      addProp(p, loc("bullet_properties/angleByProbability",
        { probability = roundToDigits(100.0 * item.probability, 2) }),
          roundToDigits(item.angle, 2) + loc("measureUnits/deg"))

  if ("reloadTimes" in bulletsData)
  {
    let currentDiffficulty = ::is_in_flight() ? ::get_mission_difficulty_int()
      : ::get_current_shop_difficulty().diffCode
    let reloadTime = bulletsData.reloadTimes[currentDiffficulty]
    if(reloadTime > 0)
      addProp(p, colorize("badTextColor", loc("bullet_properties/cooldown")),
        colorize("badTextColor", roundToDigits(reloadTime, 2)
          + " " + loc("measureUnits/seconds")))
  }

  if ("smokeShellRad" in bulletsData)
    addProp(p, loc("bullet_properties/smokeShellRad"),
      roundToDigits(bulletsData.smokeShellRad, 2) + " " + loc("measureUnits/meters_alt"))

  if ("smokeActivateTime" in bulletsData)
    addProp(p, loc("bullet_properties/smokeActivateTime"),
      roundToDigits(bulletsData.smokeActivateTime, 2) + " " + loc("measureUnits/seconds"))

  if ("smokeTime" in bulletsData)
    addProp(p, loc("bullet_properties/smokeTime"),
               roundToDigits(bulletsData.smokeTime, 2) + " " + loc("measureUnits/seconds"))

  let bTypeDesc = loc(bulletsData.bulletType, "")
  if (bTypeDesc != "")
    descTbl.bulletsDesc <- bTypeDesc

  descTbl.bulletParams <- (descTbl?.bulletParams ?? []).append({ props = p })
}

let function buildBulletsData(bullet_parameters, bulletsSet = null) {
  let needAddParams = bullet_parameters.len() == 1 || (bulletsSet?.isUniform ?? false)

  let isSmokeShell = bulletsSet?.weaponType == WEAPON_TYPE.GUNS
    && bulletsSet?.bullets?[0] == "smoke_tank"
  let isSmokeGenerator = isSmokeShell || bulletsSet?.weaponType == WEAPON_TYPE.SMOKE
  let isCountermeasure = isSmokeGenerator || bulletsSet?.weaponType == WEAPON_TYPE.FLARES
  let bulletsData = {
    armorPiercing = []
    armorPiercingDist = []
    isCountermeasure
  }

  if (bulletsSet?.bullets?[0] == "napalm_tank") {
    return bulletsData  //hide all bullet description for flamethrower bullet
  }

  if (bulletsSet?.sonicDamage != null) {
    bulletsData.sonicDamage <- bulletsSet.sonicDamage
    return bulletsData  //hide all bullet description for sonicDamage bullet
  }

  if (isCountermeasure)
  {
    let whitelistParams = [ "bulletType" ]
    if (isSmokeShell)
      whitelistParams.append("mass", "speed", "weaponBlkPath")
    let filteredBulletParameters = []
    foreach (p in bullet_parameters)
    {
      let params = p ? {} : null
      if (p)
      {
        foreach (key in whitelistParams)
          if (key in p)
            params[key] <- p[key]

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
      if (bulletsData.armorPiercingDist.len() < bullet_params.armorPiercingDist.len())
      {
        bulletsData.armorPiercing.resize(bullet_params.armorPiercingDist.len());
        bulletsData.armorPiercingDist = bullet_params.armorPiercingDist;
      }
      foreach(ind, d in bulletsData.armorPiercingDist)
      {
        for (local i = 0; i < bullet_params.armorPiercingDist.len(); i++)
        {
          local armor = null;
          let idist = bullet_params.armorPiercingDist[i].tointeger()
          if (type(bullet_params.armorPiercing[i]) != "table")
            continue

          if (d == idist || (d < idist && !i))
            armor = ::u.map(bullet_params.armorPiercing[i], @(f) round(f).tointeger())
          else if (d < idist && i)
          {
            let prevDist = bullet_params.armorPiercingDist[i-1].tointeger()
            if (d > prevDist)
              armor = ::u.tablesCombine(bullet_params.armorPiercing[i-1], bullet_params.armorPiercing[i],
                        (@(d, prevDist, idist) function(prev, next) {
                          return (prev + (next - prev) * (d - prevDist.tointeger()) / (idist - prevDist)).tointeger()
                        })(d, prevDist, idist), 0)
          }
          if (armor == null)
            continue

          bulletsData.armorPiercing[ind] = (!bulletsData.armorPiercing[ind])
            ? armor : ::u.tablesCombine(bulletsData.armorPiercing[ind], armor, max)
        }
      }
    }

    if (!needAddParams)
      continue

    foreach(p in ["mass", "kineticDmg", "explosiveDmg", "cumulativeDmg", "speed", "fuseDelay", "fuseDelayDist", "explodeTreshold", "operatedDist",
      "machMax", "endSpeed", "maxSpeed", "rangeBand0", "rangeBand1", "bandMaskToReject"])
      bulletsData[p] <- bullet_params?[p] ?? 0

    foreach(p in ["reloadTimes", "autoAiming", "irBeaconBand", "isBeamRider", "timeLife", "guaranteedRange", "rangeMax",
      "weaponBlkPath", "guidanceType", "targetSignatureType", "radarRange", "laserRange", "loadFactorMax"])
    {
      if(p in bullet_params)
        bulletsData[p] <- bullet_params[p]
    }

    foreach(p in ["activeRadar", "dopplerSpeedGate", "distanceGate"])
      bulletsData[p] <- bullet_params?[p] ?? false

    if(bulletsSet)
    {
      foreach(p in ["caliber", "explosiveType", "explosiveMass",
        "proximityFuseArmDistance", "proximityFuseRadius" ])
      if (p in bulletsSet)
        bulletsData[p] <- bulletsSet[p]

      if (isSmokeGenerator)
        foreach(p in ["smokeShellRad", "smokeActivateTime", "smokeTime"])
          if (p in bulletsSet)
            bulletsData[p] <- bulletsSet[p]
    }

    bulletsData.bulletType <- bullet_params?.bulletType ?? ""
    bulletsData.ricochetPreset <- bullet_params?.ricochetPreset
  }

  return bulletsData
}

let function addBulletAnimationsToDesc(descTbl, bulletAnimations) {
  if (!hasFeature("BulletAnimation") || bulletAnimations == null)
    return

  descTbl.bulletAnimations <- bulletAnimations
    .filter(@(fileName) file_exists(fileName))
    .map(@(fileName, idx) {
      fileName
      loadIdPosfix = idx == 0 ? "" : idx.tostring()
    })
  descTbl.hasBulletAnimation <- descTbl.bulletAnimations.len() > 0
}

//





































let function addBulletsParamToDesc(descTbl, unit, item)
{
  if (!unit.unitType.canUseSeveralBulletsForGun && !hasFeature("BulletParamsForAirs"))
    return

  let modName = getModifIconItem(unit, item)?.name ?? item.name
  if (!modName)
    return

  let bulletsSet = getBulletsSetData(unit, modName)
  if (!bulletsSet)
    return

  addBulletAnimationsToDesc(descTbl, bulletsSet?.bulletAnimations)
  let bIconParam = bulletsSet?.bIconParam
  let isBelt = bulletsSet?.isBulletBelt ?? true
  if (bIconParam && !isBelt)
  {
    descTbl.bulletActions <- []
    let setClone = clone bulletsSet
    foreach(p in ["armor", "damage"])
    {
      let value = bIconParam?[p] ?? -1
      if (value < 0)
        continue

      setClone.bIconParam = { [p] = value }
      descTbl.bulletActions.append({
        text = loc("bulletAction/" + p)
        visual = getBulletsIconData(setClone)
      })
    }
  }
  else
    descTbl.bulletActions <- [{ visual = getBulletsIconData(bulletsSet) }]

  if (bulletsSet.weaponType == WEAPON_TYPE.COUNTERMEASURES)
    return

  let searchName = getBulletsSearchName(unit, modName)
  let useDefaultBullet = searchName != modName
  let bullet_parameters = ::calculate_tank_bullet_parameters(unit.name,
    useDefaultBullet && "weaponBlkName" in bulletsSet ?
      bulletsSet.weaponBlkName :
      getModificationBulletsEffect(searchName),
    useDefaultBullet, false)

  let bulletsData = buildBulletsData(bullet_parameters, bulletsSet)
  //





  addAdditionalBulletsInfoToDesc(bulletsData, descTbl)
  addArmorPiercingToDesc(bulletsData, descTbl)
}

let function getSingleBulletParamToDesc(unit, locName, bulletName, bulletsSet, bulletParams)
{
  let descTbl = { name = colorize("activeTextColor", locName), desc = "", bulletActions = []}
  addBulletAnimationsToDesc(descTbl, bulletsSet?.bulletAnimations)
  let part = bulletName.indexof("@")
    descTbl.desc = part == null ? getBulletAnnotation(bulletName)
      : getBulletAnnotation(bulletName.slice(0, part), bulletName.slice(part+1))

  if (!unit.unitType.canUseSeveralBulletsForGun && !hasFeature("BulletParamsForAirs"))
    return descTbl

  descTbl.bulletActions = [{ visual = getBulletsIconData(bulletsSet) }]
  let bulletsData = buildBulletsData([bulletParams], bulletsSet)
  addAdditionalBulletsInfoToDesc(bulletsData, descTbl)
  addArmorPiercingToDesc(bulletsData, descTbl)
  return descTbl
}

return {
  initBulletIcons
  addBulletsParamToDesc
  buildBulletsData
  addArmorPiercingToDesc
  getBulletsIconView
  getSingleBulletParamToDesc
}
