from "%scripts/dagui_natives.nut" import is_light_dm
from "%scripts/dagui_library.nut" import *

let { getCurrentShopDifficulty } = require("%scripts/gameModes/gameModeManagerState.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { file_exists } = require("dagor.fs")
let { calculate_tank_bullet_parameters } = require("unitCalculcation")
let { floor, round_by_value, roundToDigits, round, pow } = require("%sqstd/math.nut")
let { cos, PI } = require("math")
let { copyParamsToTable } = require("%sqstd/datablock.nut")
let { stripTags } = require("%sqstd/string.nut")
let {
      


        getBulletsSetData,
        getBulletAnnotation,
        getBulletsSearchName, anglesToCalcDamageMultiplier,
        getModifIconItem, getSquashArmorAnglesScale,
        getModificationBulletsEffect } = require("%scripts/weaponry/bulletsInfo.nut")
let { WEAPON_TYPE,
  isCaliberCannon, getWeaponNameByBlkPath } = require("%scripts/weaponry/weaponryInfo.nut")
let { saclosMissileBeaconIRSourceBand } = require("%scripts/weaponry/weaponsParams.nut")
let { getMeasuredExplosionText, getTntEquivalentText, getRicochetData, getTntEquivalentDmg,
  getMaxArmorPiercing
} = require("%scripts/weaponry/dmgModel.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { format } = require("string")
let { get_mission_difficulty_int } = require("guiMission")
let { isInFlight } = require("gameplayBinding")
let { measureType, getMeasureTypeByName } = require("%scripts/measureType.nut")

local bulletIcons = {}
local bulletAspectRatio = {}

let bulletsFeaturesImg = [
  { id = "damage", values = [] }
  { id = "armor",  values = [] }
]

let getBulletsFeaturesImg = @() bulletsFeaturesImg

const MAX_BULLETS_ON_ICON = 4
const DEFAULT_BULLET_IMG_ASPECT_RATIO = 0.2
const MAX_BLOCK_IN_MAIN_SHELLS_PARAMS_TOOLTIP = 3

let bulletArmorPiercingMainParamDesc = @"
  tdiv {
    pos:t='0.5pw-0.5w, 0'
    position:t='relative'
    textareaNoTab {
      text:t='{baseText}'
      valign:t='center'
      tinyFont:t='yes'
      overlayTextColor:t='minor'
    }
    img {
      size:t='1@sIco, 1@sIco'
      pos:t='0, 0.5ph-0.5h'
      position:t='relative'
      margin:t='1@blockInterval, 0'
      background-image:t='!#ui/gameuiskin#{armorPiercingIconId}.svg'
      background-svg-size:t='1@sIco, 1@sIco'
    }
    {distanceTextObj}
  }
"

let bulletArmorPiercingMainParamDistanceText = @"
  textareaNoTab {
    text:t='{distanceText}'
    valign:t='center'
    tinyFont:t='yes'
    overlayTextColor:t='minor'
  }
"

let DEG_TO_RAD = PI / 180.0

function resetBulletIcons() {
  bulletIcons.clear()
  bulletAspectRatio.clear()
  foreach (v in bulletsFeaturesImg)
    v.values.clear()
}

addListenersWithoutEnv({
  GuiSceneCleared = @(_p) resetBulletIcons() 
})

function initBulletIcons(blk = null) {
  if (bulletIcons.len())
    return

  if (!blk)
    blk = GUI.get()

  copyParamsToTable(blk?.bullet_icons, bulletIcons)
  copyParamsToTable(blk?.bullet_icon_aspect_ratio, bulletAspectRatio)

  let bf = blk?.bullets_features_icons
  if (bf)
    foreach (item in bulletsFeaturesImg)
      item.values = bf % item.id
}

function getBulletImage(bulletsSet, bulletIndex, needFullPath = true) {
  local imgId = bulletsSet.bullets[bulletIndex]
  if (bulletsSet?.customIconsMap[imgId] != null)
    imgId = bulletsSet.customIconsMap[imgId]
  if (imgId.indexof("@") != null)
    imgId = imgId.slice(0, imgId.indexof("@"))
  let defaultImgId = isCaliberCannon(1000 * (bulletsSet?.caliber ?? 0.0))
    ? "default_shell" : "default_ball"
  let textureId = bulletIcons?[imgId] ?? bulletIcons?[defaultImgId]
  return needFullPath ? $"#ui/gameuiskin#{textureId}" : textureId
}

function getBulletsIconView(bulletsSet, tooltipId = null, tooltipDelayed = false) {
  let view = {}
  if (!bulletsSet || !("bullets" in bulletsSet))
    return view

  initBulletIcons()
  view.bullets <- function() {
      let res = []

      let length = bulletsSet.bullets.len()
      let isBelt = bulletsSet?.isBulletBelt ?? true

      local ratio = 1.0
      local count = 1
      if (isBelt) {
        ratio = bulletAspectRatio?[getBulletImage(bulletsSet, 0, false)]
          ?? bulletAspectRatio?["default"]
          ?? DEFAULT_BULLET_IMG_ASPECT_RATIO
        local maxAmountInView = (bulletsSet?.weaponType == WEAPON_TYPE.COUNTERMEASURES)
          ? 1 : min(MAX_BULLETS_ON_ICON, (1.0 / ratio).tointeger())
        if (bulletsSet.cartridge)
          maxAmountInView = min(bulletsSet.cartridge, maxAmountInView)
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

      for (local i = 0; i < count; i++) {
        let item = {
          image           = getBulletImage(bulletsSet, i % length)
          posx            = $"{start + (itemWidth + separator) * i}%pw"
          sizex           = $"{itemWidth}%pw"
          sizey           = $"{itemHeight}%pw"
          useTooltip      = tooltipId != null
          tooltipId       = tooltipId
          tooltipDelayed  = tooltipId != null && tooltipDelayed
        }
        res.append(item)
      }

      return res
    }

  let bIconParam = bulletsSet?.bIconParam
  if (bIconParam && !bIconParam?.errorData) {
    let addIco = []
    foreach (item in getBulletsFeaturesImg()) {
      let idx = bIconParam?[item.id] ?? -1
      if (idx in item.values)
        addIco.append({ img = item.values[idx] })
    }
    if (addIco.len())
      view.addIco <- addIco
  }
  if (bIconParam && bIconParam?.errorData)
    logerr($"Not found default bullets icons param for unit {bIconParam.errorData.unit} && {bulletsSet.weaponBlkName}")

  return view
}

function getBulletsIconData(bulletsSet) {
  if (!bulletsSet)
    return ""
  return handyman.renderCached(("%gui/weaponry/bullets.tpl"), getBulletsIconView(bulletsSet))
}

function getArmorPiercingViewData(armorPiercing, dist) {
  local res = null
  if (armorPiercing.len() <= 0 || !armorPiercing?[0].len())
    return { props = res, baseArmorPiercing = 0, baseDistance = 0 }

  let angles = (armorPiercing?[0] ?? {}).keys().sort(@(a, b) a <=> b)
  local ranges = null
  foreach (angle in angles) {
    if (!ranges) {
      res = []
      ranges = u.values(dist)
      ranges.sort(@(a, b) a <=> b)
      let headRow = {
        text = "-"
        values = ranges.map(@(r) { value = format("%.0f %s", r, loc("measureUnits/meters_alt"))})
        firstRow = true
      }
      res.append(headRow)
    }

    let row = {
      text = $"{angle}{loc("measureUnits/deg")}"
      values = []
    }

    foreach(idx, _range in ranges) {
      row.values.append({ value = $"{armorPiercing?[idx][angle] ?? 0} {loc("measureUnits/mm")}"})
    }
    res.append(row)
  }

  let baseArmorPiercingIndex = 1
  let baseDistance = ranges[baseArmorPiercingIndex] ?? 0
  let baseArmorPiercingFloat = armorPiercing?[baseArmorPiercingIndex][0]
    ?? armorPiercing?[baseArmorPiercingIndex]["0"] ?? 0 
  let baseArmorPiercing = round(baseArmorPiercingFloat).tointeger()
  return { props = res, baseArmorPiercing, baseDistance }
}

function addArmorPiercingToDesc(bulletsData, descTbl) {
  let { armorPiercing, armorPiercingDist } = bulletsData
  let { props } = getArmorPiercingViewData(armorPiercing, armorPiercingDist)
  if (props == null)
    return

  local currWeaponName = "weaponBlkPath" in bulletsData
    ? getWeaponNameByBlkPath(bulletsData.weaponBlkPath)
    : ""

  let bulletName = currWeaponName != "" ? loc($"weapons/{currWeaponName}") : ""
  let header = "\n".concat(
    "".concat(loc("bullet_properties/armorPiercing"),
      bulletName != "" ? $"{loc("ui/colon")}{bulletName}" : ""),
    $"({loc("distance")} / {loc("bullet_properties/hitAngle")})"
  )

  descTbl.bulletParams <- (descTbl?.bulletParams ?? []).append({ props, header })
}

function addArmorPiercingToDescForBullets(bulletsData, descTbl) {
  let { armorPiercingDist, armorPiercingKinetic, cumulativeDamage = 0, explosiveType = null,
    explosiveMass = 0, cumulativeByNormal = false } = bulletsData
  let { props, baseArmorPiercing, baseDistance } = getArmorPiercingViewData(armorPiercingKinetic, armorPiercingDist)
  let highEnergyPenetration = explosiveType == null || explosiveMass == 0 ? 0
    : round_by_value(getMaxArmorPiercing(explosiveType, explosiveMass), 0.1)

  let cumulativeDamageInt = round(cumulativeDamage).tointeger()
  let maxPenetartion = max(highEnergyPenetration, cumulativeDamageInt, baseArmorPiercing)
  if (maxPenetartion == 0)
    return

  let isKineticDmg = maxPenetartion == baseArmorPiercing
  let armorPiercingIconId = isKineticDmg ? "penetration_kinetic_icon"
    : maxPenetartion == cumulativeDamageInt && !cumulativeByNormal ? "penetration_cumulative_jet_icon"
    : "penetration_high_explosive_fragmentation_icon"

  let bulletBaseArmorPiercing = {
    value = " ".concat(maxPenetartion, loc("measureUnits/mm"))
    customDesc = bulletArmorPiercingMainParamDesc.subst({
      baseText = stripTags(loc("bullet_properties/armorPiercing_short"))
      armorPiercingIconId
      distanceTextObj = !isKineticDmg ? ""
        : bulletArmorPiercingMainParamDistanceText.subst({
            distanceText = stripTags($"| {baseDistance}{loc("measureUnits/meters_alt")}") })
    })
  }
  if (descTbl?.bulletMainParams && descTbl.bulletMainParams.len() > 1)
    descTbl.bulletMainParams.insert(1, bulletBaseArmorPiercing)
  else
    descTbl.bulletMainParams <- (descTbl?.bulletMainParams ?? []).append(bulletBaseArmorPiercing)

  let degText = loc("measureUnits/deg")

  local cumulativePenetration = null
  if (cumulativeDamageInt != 0) {
    cumulativePenetration = {}
    cumulativePenetration.icon <- cumulativeByNormal ? "!#ui/gameuiskin#penetration_high_explosive_fragmentation_icon.svg"
      : "!#ui/gameuiskin#penetration_cumulative_jet_icon.svg"
    cumulativePenetration.cumulativeTitle <- cumulativeByNormal ? loc("bullet_properties/armorPiercing/affected_armor")
      : loc("bullet_properties/armorPiercing/cumulative")

    cumulativePenetration.props <- []

    let multipliers = getSquashArmorAnglesScale()
    foreach(idx, angle in anglesToCalcDamageMultiplier) {
      cumulativePenetration.props.append({
        value = $"{round(cumulativeDamage * (cumulativeByNormal ? (multipliers?[angle] ?? 1)
          : cos(angle*DEG_TO_RAD))).tointeger()} {loc("measureUnits/mm")}"
        angle = $"{angle}{degText}"
        isLastRow = idx == anglesToCalcDamageMultiplier.len() - 1
      })
    }
  }

  descTbl.bulletPenetrationData <- (descTbl?.bulletPenetrationData ?? {}).__update({
    highEnergyPenetration = highEnergyPenetration == 0 ? null
      : $"{highEnergyPenetration} {loc("measureUnits/mm")}"
    kineticPenetration = baseArmorPiercing != 0 ? { props } : null
    cumulativePenetration
  })
}

function addAdditionalBulletsInfoToDesc(bulletsData, descTbl, isBulletCard = false) {
  let p = []
  let isSmokeBullet = !!bulletsData?.smokeShellRad
  
  
  let needAddDividingLine = !!bulletsData?.rangeMax && !!bulletsData?.guidanceType
  let listDividerLineIndexes = {
    first = 0
    second = 0
  }
  let bulletMainParams = []
  let bulletRicochetData = {
    text = loc("bullet_properties/angleWithRicochet")
    data = []
  }
  let addProp = function(arr, text, value) {
    arr.append({
      text = text
      value = value
    })
  }
  if ("sonicDamage" in bulletsData) {
    let { distance, speed, horAngles, verAngles } = bulletsData.sonicDamage
    let props = []
    if (distance != null)
      addProp(props, loc("sonicDamage/distance"), measureType.DEPTH.getMeasureUnitsText(distance))
    if (speed != null)
      addProp(props, loc("sonicDamage/speed"), measureType.SPEED_PER_SEC.getMeasureUnitsText(speed))
    let degText = loc("measureUnits/deg")
    if (horAngles != null)
      addProp(props, loc("sonicDamage/horAngles"),
        format("%+d%s/%+d%s", horAngles.x, degText, horAngles.y, degText))
    if (verAngles != null)
      addProp(props, loc("sonicDamage/verAngles"),
        format("%+d%s/%+d%s", verAngles.x, degText, verAngles.y, degText))
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
    addProp(p, loc("bullet_properties/caliber"), " ".concat(round_by_value(bulletsData.caliber,
      isCaliberCannon(bulletsData.caliber) ? 1 : 0.01), loc("measureUnits/mm")))
  if (bulletsData.mass > 0) {
    addProp(p, loc("bullet_properties/mass"),
      getMeasureTypeByName("kg", true).getMeasureUnitsText(bulletsData.mass))
  }
  if (needAddDividingLine)
    listDividerLineIndexes.first = p.len()
  if (bulletsData.speed > 0) {
    if (!isBulletCard)
      addProp(p, loc("bullet_properties/speed"),
        format("%.0f %s", bulletsData.speed, loc("measureUnits/metersPerSecond_climbSpeed")))
    else
      bulletMainParams.append({
        text = loc("bullet_properties/speed")
        value = format("%.0f %s", bulletsData.speed, loc("measureUnits/metersPerSecond_climbSpeed"))
      })
  }

  let maxSpeed = (bulletsData?.maxSpeed ?? 0) || (bulletsData?.endSpeed ?? 0)
  if (bulletsData?.machMax) {
    if (!isBulletCard)
    addProp(p, loc("rocket/maxSpeed"),
      format("%.1f %s", bulletsData.machMax, loc("measureUnits/machNumber")))
    else
      bulletMainParams.append({
        text = loc("rocket/maxSpeed")
        value = format("%.1f %s", bulletsData.machMax, loc("measureUnits/machNumber"))
      })
  }
  else if (maxSpeed) {
    if (!isBulletCard)
      addProp(p, loc("rocket/maxSpeed"),
        measureType.SPEED_PER_SEC.getMeasureUnitsText(maxSpeed))
    else
      bulletMainParams.append({
        text = loc("rocket/maxSpeed")
        value = measureType.SPEED_PER_SEC.getMeasureUnitsText(maxSpeed)
      })
  }

  if (bulletsData?.bulletType == "aam" || bulletsData?.bulletType == "sam_tank") {
    if ("loadFactorMax" in bulletsData)
      addProp(p, loc("missile/loadFactorMax"),
        measureType.GFORCE.getMeasureUnitsText(bulletsData.loadFactorMax))
  }

  if ("autoAiming" in bulletsData) {
    let isBeamRider = bulletsData?.isBeamRider ?? false
    let aimingTypeLocId = "".concat("guidanceSystemType/",
      !bulletsData.autoAiming ? "handAim"
      : isBeamRider ? "beamRider"
      : "semiAuto")
    addProp(p, loc("guidanceSystemType/header"), loc(aimingTypeLocId))
    if ("irBeaconBand" in bulletsData)
      if (bulletsData.irBeaconBand != saclosMissileBeaconIRSourceBand.get())
        addProp(p, loc("missile/irccm"), loc("options/yes"))
  }

  if ("guidanceType" in bulletsData) {
    local missileGuidanceFeature = bulletsData?.inertialNavigation ? "+IOG" : ""
    if (bulletsData?.inertialNavigationDriftSpeed == 0)
      missileGuidanceFeature = "".concat(missileGuidanceFeature, "+GNSS")
    if (bulletsData?.datalink)
      missileGuidanceFeature = "".concat(missileGuidanceFeature, "+DL")
    if (bulletsData.guidanceType == "ir" || bulletsData.guidanceType == "optical") {
      let targetSignatureType = bulletsData?.targetSignatureType != null ? bulletsData?.targetSignatureType : "infraRed"
      addProp(p, loc("missile/guidance"),
        loc($"missile/guidance/{ "".concat(targetSignatureType == "optic" ? "tv" : "ir", missileGuidanceFeature)}"))
      if (bulletsData?.bulletType == "aam" || bulletsData?.bulletType == "sam_tank") {
        if ((bulletsData?.gateWidth != null && bulletsData.gateWidth < bulletsData.fov) ||
             bulletsData.bandMaskToReject != 0)
          addProp(p, loc("missile/irccm"), loc("options/yes"))
        addProp(p, loc("missile/aspect"), bulletsData.rangeBand1 > 0 ?
          loc("missile/aspect/allAspect") : loc("missile/aspect/rearAspect"))
        addProp(p, loc("missile/seekerRange/rearAspect"),
          measureType.DISTANCE.getMeasureUnitsText(bulletsData.rangeBand0))
        if (bulletsData.rangeBand1 > 0)
          addProp(p, loc("missile/seekerRange/allAspect"),
            measureType.DISTANCE.getMeasureUnitsText(bulletsData.rangeBand1))
      }
      else {
        if (bulletsData.rangeBand0 > 0 && bulletsData.rangeBand1 > 0)
          addProp(p, loc("missile/seekerRange"),
            measureType.DISTANCE.getMeasureUnitsText(min(bulletsData.rangeBand0, bulletsData.rangeBand1)))
      }
    }
    else if (bulletsData.guidanceType == "radar") {
      addProp(p, loc("missile/guidance"),
        loc($"missile/guidance/{ "".concat(bulletsData.activeRadar ? "ARH" : "SARH", missileGuidanceFeature)}"))

      if (bulletsData?.groundClutter != null && bulletsData?.dopplerSpeed != null)
        if (!bulletsData.groundClutter || bulletsData.dopplerSpeed)
          addProp(p, loc("missile/shootDown"), !bulletsData.groundClutter ? loc("missile/shootDown/allAspects") : loc("missile/shootDown/headOnAspect"))
      if ("radarRange" in bulletsData)
        addProp(p, loc("missile/seekerRange"),
          measureType.DISTANCE.getMeasureUnitsText(bulletsData.radarRange))
    }
    else if (bulletsData.guidanceType == "saclos") {
      addProp(p, loc("missile/guidance"),
        loc($"missile/guidance/{bulletsData?.isBeamRider ? "beamRiding" : "saclos"}"))
      if ("irBeaconBand" in bulletsData) {
        if (bulletsData.irBeaconBand != saclosMissileBeaconIRSourceBand.get())
          addProp(p, loc("missile/irccm"), loc("options/yes"))
      }
    }
    else {
      addProp(p, loc("missile/guidance"),
        loc($"missile/guidance/{"".concat(bulletsData.guidanceType, missileGuidanceFeature)}"))
      if ("laserRange" in bulletsData)
        addProp(p, loc("missile/seekerRange"),
          measureType.DISTANCE.getMeasureUnitsText(bulletsData.laserRange))
    }
  }

  let operatedDist = bulletsData?.operatedDist ?? 0
  if (operatedDist)
    addProp(p, loc("firingRange"), measureType.DISTANCE.getMeasureUnitsText(operatedDist))

  if ("rangeMax" in bulletsData)
    addProp(p, loc("launchRange"), measureType.DISTANCE.getMeasureUnitsText(bulletsData.rangeMax))

  if ("guaranteedRange" in bulletsData)
    addProp(p, loc("guaranteedRange"), measureType.DISTANCE.getMeasureUnitsText(bulletsData.guaranteedRange))

  if ("timeLife" in bulletsData) {
    if ("guidanceType" in bulletsData || "autoAiming" in bulletsData)
      addProp(p, loc("missile/timeGuidance"),
        format("%.1f %s", bulletsData.timeLife, loc("measureUnits/seconds")))
    else
      addProp(p, loc("missile/timeSelfdestruction"),
        format("%.1f %s", bulletsData.timeLife, loc("measureUnits/seconds")))
  }
  if (needAddDividingLine)
    listDividerLineIndexes.second = p.len()

  let explosiveType = bulletsData?.explosiveType
  if (explosiveType)
    addProp(p, loc("bullet_properties/explosiveType"), loc($"explosiveType/{explosiveType}"))
  let explosiveMass = bulletsData?.explosiveMass
  if (explosiveMass) {
    if (explosiveType == "tnt" && isBulletCard) {
      bulletMainParams.append({
        text = loc("bullet_properties/explosiveMass_short")
        value = getMeasuredExplosionText(explosiveMass)
      })
    }
    else
      addProp(p, loc("bullet_properties/explosiveMass"),
        getMeasuredExplosionText(explosiveMass))
  }
  if (explosiveType && explosiveMass) {
    let tntEqText = getTntEquivalentText(explosiveType, explosiveMass)
    if (tntEqText.len()) {
      if (isSmokeBullet || !isBulletCard)
        addProp(p, loc("bullet_properties/explosiveMassInTNTEquivalent"), tntEqText)
      else
        bulletMainParams.append({
          text = loc("bullet_properties/explosiveMassInTNTEquivalent")
          value = tntEqText
        })
    }
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
               $"{explodeTreshold} {loc("measureUnits/mm")}")

  let proximityFuseArmDistance = round(bulletsData?.proximityFuseArmDistance ?? 0)
  if (proximityFuseArmDistance)
    addProp(p, loc("torpedo/armingDistance"),
      $"{proximityFuseArmDistance} {loc("measureUnits/meters_alt")}")
  let proximityFuseRadius = round(bulletsData?.proximityFuseRadius ?? 0)
  if (proximityFuseRadius)
    addProp(p, loc("bullet_properties/proximityFuze/triggerRadius"),
      $"{proximityFuseRadius} {loc("measureUnits/meters_alt")}")

  let ricochetData = !bulletsData.isCountermeasure && getRicochetData(bulletsData?.ricochetPreset)
  if (ricochetData)
    foreach (index, item in ricochetData.angleProbabilityMap) {
      if (!isBulletCard)
        addProp(p, loc("bullet_properties/angleByProbability",
          { probability = roundToDigits(100.0 * item.probability, 2) }),
          "".concat(roundToDigits(item.angle, 2), loc("measureUnits/deg")))
      else {
        bulletRicochetData.data.append({
          value = $"{roundToDigits(100.0 * item.probability, 2)}%"
          angle = "".concat(roundToDigits(item.angle, 2), loc("measureUnits/deg"))
        })
        if (index < ricochetData.angleProbabilityMap.len() - 1)
          bulletRicochetData.data[index].rightBorder <- true
      }
    }

  if ("reloadTimes" in bulletsData) {
    let currentDiffficulty = isInFlight() ? get_mission_difficulty_int()
      : getCurrentShopDifficulty().diffCode
    let reloadTime = bulletsData.reloadTimes[currentDiffficulty]
    if (reloadTime > 0) {
      let value = isBulletCard ? " ".concat(roundToDigits(reloadTime, 2), loc("measureUnits/seconds"))
        : colorize("badTextColor", " ".concat(roundToDigits(reloadTime, 2), loc("measureUnits/seconds")))
      let text = isBulletCard ? loc("bullet_properties/cooldown")
        : colorize("badTextColor", loc("bullet_properties/cooldown"))
      addProp(p, text, value)
    }
  }

  if ("smokeShellRad" in bulletsData) {
    if (isBulletCard && isSmokeBullet)
      bulletMainParams.append({
        text = loc("bullet_properties/smokeShellRad_short")
        value = " ".concat(roundToDigits(bulletsData.smokeShellRad, 2), loc("measureUnits/meters_alt"))
      })
    else
      addProp(p, loc("bullet_properties/smokeShellRad"),
        " ".concat(roundToDigits(bulletsData.smokeShellRad, 2), loc("measureUnits/meters_alt")))
  }

  if ("smokeActivateTime" in bulletsData)
    addProp(p, loc("bullet_properties/smokeActivateTime"),
      " ".concat(roundToDigits(bulletsData.smokeActivateTime, 2), loc("measureUnits/seconds")))

  if ("smokeTime" in bulletsData) {
    if (isBulletCard && isSmokeBullet)
      bulletMainParams.append({
        text = loc("bullet_properties/smokeTime_short")
        value = " ".concat(roundToDigits(bulletsData.smokeTime, 2), loc("measureUnits/seconds"))
      })
    else
      addProp(p, loc("bullet_properties/smokeTime"),
        " ".concat(roundToDigits(bulletsData.smokeTime, 2), loc("measureUnits/seconds")))
  }

  if (listDividerLineIndexes.first > 0 && p.len() > 1) {
    p.insert(listDividerLineIndexes.first, { divider = true })
    listDividerLineIndexes.second = listDividerLineIndexes.second + 1

    if (listDividerLineIndexes.second > 1 && p.len() > 2)
      p.insert(listDividerLineIndexes.second, { divider = true })
  }

  let bTypeDesc = loc(bulletsData.bulletType, "")
  if (bTypeDesc != "")
    descTbl.bulletsDesc <- bTypeDesc

  descTbl.bulletParams <- (descTbl?.bulletParams ?? []).append({ props = p })

  if (bulletMainParams.len()) {
    descTbl.bulletMainParams <- bulletMainParams
  }
  if (bulletRicochetData.data.len())
    descTbl.bulletRicochetData <- bulletRicochetData
}

function buildBulletsData(bullet_parameters, bulletsSet = null) {
  let needAddParams = bullet_parameters.len() == 1 || (bulletsSet?.isUniform ?? false)

  let isSmokeShell = bulletsSet?.weaponType == WEAPON_TYPE.GUNS
    && bulletsSet?.bullets?[0] == "smoke_tank"
  let isSmokeGenerator = isSmokeShell || bulletsSet?.weaponType == WEAPON_TYPE.SMOKE
  let isCountermeasure = isSmokeGenerator || bulletsSet?.weaponType == WEAPON_TYPE.FLARES
  let bulletsData = {
    armorPiercing = []
    armorPiercingDist = []
    armorPiercingKinetic = []
    isCountermeasure
    cumulativeDamage = 0
    cumulativeByNormal = false
  }

  if (bulletsSet?.bullets?[0] == "napalm_tank") {
    return bulletsData  
  }

  if (bulletsSet?.sonicDamage != null) {
    bulletsData.sonicDamage <- bulletsSet.sonicDamage
    return bulletsData  
  }

  bulletsData.cumulativeDamage = bulletsSet?.cumulativeDamage ?? 0
  bulletsData.cumulativeByNormal = bulletsSet?.cumulativeByNormal ?? false

  if (isCountermeasure) {
    let whitelistParams = [ "bulletType" ]
    if (isSmokeShell)
      whitelistParams.append("mass", "speed", "weaponBlkPath")
    let filteredBulletParameters = []
    foreach (p in bullet_parameters) {
      let params = p ? {} : null
      if (params) {
        foreach (key in whitelistParams)
          if (key in p)
            params[key] <- p[key]

        params.armorPiercing     <- []
        params.armorPiercingDist <- []
        params.armorPiercingKinetic <- []
      }
      filteredBulletParameters.append(params)
    }
    bullet_parameters = filteredBulletParameters
  }

  foreach (bullet_params in bullet_parameters) {
    if (!bullet_params)
      continue

    if (bullet_params?.bulletType != "aam") {
      if (bulletsData.armorPiercingDist.len() < bullet_params.armorPiercingDist.len()) {
        bulletsData.armorPiercing.resize(bullet_params.armorPiercingDist.len())
        bulletsData.armorPiercingDist = bullet_params.armorPiercingDist
      }
      if (bulletsData.armorPiercingKinetic.len() < bullet_params.armorPiercingDist.len())
        bulletsData.armorPiercingKinetic.resize(bullet_params.armorPiercingDist.len())

      foreach (ind, d in bulletsData.armorPiercingDist) {
        for (local i = 0; i < bullet_params.armorPiercingDist.len(); i++) {
          let idist = bullet_params.armorPiercingDist[i].tointeger()
          foreach (tableName in ["armorPiercing", "armorPiercingKinetic"]) {
            if (type(bullet_params[tableName][i]) != "table")
              continue
            local armor = null
            if (d == idist || (d < idist && !i))
              armor = bullet_params[tableName][i].map(@(f) round(f).tointeger())
            else if (d < idist && i) {
              let prevDist = bullet_params.armorPiercingDist[i - 1].tointeger()
              if (d > prevDist) {
                let newDist = d
                let idx = i
                armor = u.tablesCombine(bullet_params[tableName][idx - 1], bullet_params[tableName][idx],
                  @(prev, next) (prev + (next - prev) * (newDist - prevDist.tointeger()) / (idist - prevDist)).tointeger(),
                  0)
              }
            }

            if (armor == null)
              continue

            bulletsData[tableName][ind] = (!bulletsData[tableName][ind])
              ? armor : u.tablesCombine(bulletsData[tableName][ind], armor, max)
          }
        }
      }
    }

    if (!needAddParams)
      continue

    foreach (p in ["mass", "speed", "fuseDelay", "fuseDelayDist", "explodeTreshold", "operatedDist",
      "machMax", "endSpeed", "maxSpeed", "rangeBand0", "rangeBand1", "fov", "gateWidth", "bandMaskToReject"])
      bulletsData[p] <- bullet_params?[p] ?? 0

    foreach (p in ["reloadTimes", "autoAiming", "irBeaconBand", "isBeamRider", "timeLife", "guaranteedRange", "rangeMax",
      "weaponBlkPath", "guidanceType", "targetSignatureType", "radarRange", "laserRange", "loadFactorMax",
      "inertialNavigation", "inertialNavigationDriftSpeed", "datalink"]) {
      if (p in bullet_params)
        bulletsData[p] <- bullet_params[p]
    }

    foreach (p in ["activeRadar", "dopplerSpeed"])
      bulletsData[p] <- bullet_params?[p] ?? false
    foreach (p in ["groundClutter"])
      bulletsData[p] <- bullet_params?[p] ?? true

    if (bulletsSet) {
      foreach (p in ["caliber", "explosiveType", "explosiveMass",
        "proximityFuseArmDistance", "proximityFuseRadius" ])
      if (p in bulletsSet)
        bulletsData[p] <- bulletsSet[p]

      if (isSmokeGenerator)
        foreach (p in ["smokeShellRad", "smokeActivateTime", "smokeTime"])
          if (p in bulletsSet)
            bulletsData[p] <- bulletsSet[p]
    }

    bulletsData.bulletType <- bullet_params?.bulletType ?? ""
    bulletsData.ricochetPreset <- bullet_params?.ricochetPreset
  }

  return bulletsData
}

function addBulletAnimationsToDesc(descTbl, bulletAnimations) {
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













































function addBulletsParamToDesc(descTbl, unit, item, isBulletCard) {
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
  if (bIconParam && !bIconParam?.errorData) {
    descTbl.bulletActions <- []
    let setClone = clone bulletsSet
    foreach (p in ["armor", "damage"]) {
      let value = bIconParam?[p] ?? -1
      if (value < 0)
        continue

      setClone.bIconParam = { [p] = value }
      descTbl.bulletActions.append({
        text = loc($"bulletAction/{p}")
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
  let bullet_parameters = calculate_tank_bullet_parameters(bulletsSet?.supportUnitName ?? unit.name,
    useDefaultBullet && "weaponBlkName" in bulletsSet ?
      bulletsSet.weaponBlkName :
      getModificationBulletsEffect(searchName),
    useDefaultBullet, false)

  let bulletsData = buildBulletsData(bullet_parameters, bulletsSet)

  if(bulletsSet?.guiArmorpower != null) {
    let res = []
    foreach(value in bulletsSet.guiArmorpower) {
      let armorPiercing = { [0] = value.x, [30] = value.y, [60] = value.z}
      res.append({ armorPiercingDist = value.w, armorPiercing })
    }
    res.sort(@(v1, v2) v1.armorPiercingDist <=> v2.armorPiercingDist)
    bulletsData.armorPiercingDist.clear()
    bulletsData.armorPiercing.clear()
    res.each(function(v) {
      bulletsData.armorPiercingDist.append(v.armorPiercingDist)
      bulletsData.armorPiercing.append(v.armorPiercing)
    })
  }

  





  addAdditionalBulletsInfoToDesc(bulletsData, descTbl, isBulletCard)
  if (isBulletCard)
    addArmorPiercingToDescForBullets(bulletsData, descTbl)
  else
    addArmorPiercingToDesc(bulletsData, descTbl)
}

function checkBulletParamsBeforeRender(descTbl) {
  if (!descTbl?.bulletMainParams)
    return

  descTbl.showBulletMainParams <- descTbl.bulletMainParams.len() > 0

  if (descTbl.bulletMainParams.len() > MAX_BLOCK_IN_MAIN_SHELLS_PARAMS_TOOLTIP) {
    let extraProps = []
    while (descTbl.bulletMainParams.len() > MAX_BLOCK_IN_MAIN_SHELLS_PARAMS_TOOLTIP) {
      let extraBlock = descTbl.bulletMainParams.pop()
      extraProps.append(extraBlock)
    }
    if (extraProps.len()) {
      descTbl.bulletParams <- (descTbl?.bulletParams ?? [])
      if (descTbl.bulletParams?[0].props)
        descTbl.bulletParams[0].props.extend(extraProps)
      else {
        descTbl.bulletParams.append({ props = extraProps})
      }
    }
  }
  foreach(idx, param in descTbl.bulletMainParams) {
    param.idx <- idx
  }
  descTbl.bulletMainParamsCount <- descTbl.bulletMainParams.len()
  descTbl.bulletMainParamsDividers <- descTbl.bulletMainParamsCount - 1

  if (descTbl?.bulletPenetrationData)
    descTbl.bulletPenetrationData.__update({
      title = loc("bullet_properties/armorPiercing")
  })
}

function getSingleBulletParamToDesc(unit, locName, bulletName, bulletsSet, bulletParams) {
  let descTbl = { name = colorize("activeTextColor", locName), desc = "", bulletActions = [] }
  addBulletAnimationsToDesc(descTbl, bulletsSet?.bulletAnimations)
  let part = bulletName.indexof("@")
  descTbl.desc = part == null ? getBulletAnnotation(bulletName)
    : getBulletAnnotation(bulletName.slice(0, part), bulletName.slice(part + 1))

  if (!unit.unitType.canUseSeveralBulletsForGun && !hasFeature("BulletParamsForAirs"))
    return descTbl

  descTbl.bulletActions = [{ visual = getBulletsIconData(bulletsSet) }]
  let bulletsData = buildBulletsData([bulletParams], bulletsSet)
  addAdditionalBulletsInfoToDesc(bulletsData, descTbl, true)
  addArmorPiercingToDescForBullets(bulletsData, descTbl)
  checkBulletParamsBeforeRender(descTbl)
  return descTbl
}

return {
  initBulletIcons
  addBulletsParamToDesc
  buildBulletsData
  addArmorPiercingToDesc
  getBulletsIconView
  getSingleBulletParamToDesc
  checkBulletParamsBeforeRender
  addArmorPiercingToDescForBullets
}
