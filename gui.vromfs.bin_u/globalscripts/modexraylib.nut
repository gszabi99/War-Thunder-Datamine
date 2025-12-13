from "%globalScripts/logs.nut" import *
let { min, max, abs, round, sin, PI } = require("math")
let { format } = require("string")
let regexp2 = require("regexp2")
let DataBlock = require("DataBlock")
let { get_unittags_blk } = require("blkGetters")
let { loc, doesLocTextExist } = require("dagor.localize")
let { round_by_value } = require("%sqstd/math.nut")
let { utf8Capitalize, utf8ToLower, toIntegerSafe } = require("%sqstd/string.nut")
let { blkOptFromPath } = require("%sqstd/datablock.nut")
let { fileName } = require("%sqstd/path.nut")
let { isEqual, isFloat, isPoint2, isIPoint2, unique, appendOnce, tablesCombine } = require("%sqStdLibs/helpers/u.nut")






let KGF_TO_NEWTON = 9.807



let S_UNDEFINED = ""
let S_AIRCRAFT = "aircraft"
let S_HELICOPTER = "helicopter"
let S_TANK = "tank"
let S_SHIP = "ship"
let S_BOAT = "boat"
let S_SUBMARINE = "submarine"



let preparePartType = [
  { pattern = regexp2(@"_l_|_r_"),   replace = "_" },
  { pattern = regexp2(@"[0-9]|dm$"), replace = "" },
  { pattern = regexp2(@"__+"),       replace = "_" },
  { pattern = regexp2(@"_+$"),       replace = "" },
]

let rePartIdx = regexp2("_([0-9]+)(_dm)?$")

function getPartType(name, xrayRemap) {
  if (name == "")
    return ""
  local partType = xrayRemap?[name] ?? name
  foreach (re in preparePartType)
    partType = re.pattern.replace(re.replace, partType)
  return partType
}



function getPartNameLocText(partType, simUnitType) {
  local res = ""
  let locPrefixes = [ "armor_class/", "dmg_msg_short/", "weapons_types/" ]
  let checkKeys = [ partType ]
  let idxSeparator = partType.indexof("_")
  if (idxSeparator)
    checkKeys.append(partType.slice(0, idxSeparator))
  checkKeys.append("_".concat(simUnitType, partType))
  if (simUnitType == S_BOAT)
    checkKeys.append($"ship_{partType}")

  foreach (prefix in locPrefixes)
    foreach (key in checkKeys) {
      let locId = "".concat(prefix, key)
      res = doesLocTextExist(locId) ? loc(locId) : ""
      if (res != "")
        return utf8Capitalize(res)
    }

  return partType
}

function getPartLocNameByBlkFile(locKeyPrefix, blkFilePath, propsBlk) {
  let nameLocId = "/".concat(locKeyPrefix, propsBlk?.nameLocId ?? fileName(blkFilePath).slice(0, -4))
  return doesLocTextExist(nameLocId) ? loc(nameLocId) : (propsBlk?.name ?? nameLocId)
}

function trimBetween(source, from, to, strict = true) {
  local beginIndex = source.indexof(from) ?? -1
  let endIndex = source.indexof(to) ?? -1
  if (strict && (beginIndex == -1 || endIndex == -1 || beginIndex >= endIndex))
    return null
  if (beginIndex == -1)
    beginIndex = 0
  beginIndex += from.len()
  if (endIndex == -1)
    beginIndex = source.len()
  return source.slice(beginIndex, endIndex)
}



let nbsp = "\u00A0"
let colon = loc("ui/colon")
let comma = loc("ui/comma")
let mdash = loc("ui/mdash")
let bullet = loc("ui/bullet")

let unitsDeg = loc("measureUnits/deg")
let unitsSec = loc("measureUnits/seconds")
let unitsDegPerSec = loc("measureUnits/deg_per_sec")
let unitsRoundsPerMin = loc("measureUnits/rounds_per_min")
let unitsMm = loc("measureUnits/mm")
let unitsPcs = loc("measureUnits/pcs")
let unitsPercent = loc("measureUnits/percent")

let getSign = @(n) n < 0 ? -1 : 1

function getUnitTagsBlk(commonData) {
  let { unitDataCache, unitName } = commonData
  if ("unitTags" not in unitDataCache)
    unitDataCache.unitTags <- get_unittags_blk()?[unitName]
  return unitDataCache.unitTags
}

function findBlockByName(blk, name) {
  let subBlk = blk.getBlockByName(name)
  if (subBlk != null)
    return subBlk
  for (local b = 0; b < blk.blockCount(); b++) {
    let childBlk = callee()(blk.getBlock(b), name)
    if (childBlk != null)
      return childBlk
  }
  return null
}

function countBlocksByName(blk, name) {
  local count = 0
  for (local b = 0; b < blk.blockCount(); b++) {
    let block = blk.getBlock(b)
    if (block.getBlockName() == name)
      ++count
  }
  return count
}

function findParamValue(blk, paramName, paramValue) {
  for (local p = 0; p < blk.paramCount(); ++p)
    if (blk.getParamName(p) == paramName)
      if (blk.getParamValue(p) == paramValue)
        return true
  return false
}

function findBlockByNameWithParamValue(blk, blockName, paramName, paramValue) {
  for (local b = 0; b < blk.blockCount(); b++) {
    let block = blk.getBlock(b)
    if (block.getBlockName() == blockName)
      if (block?[paramName] == paramValue)
        return true
  }
  for (local b = 0; b < blk.blockCount(); b++)
    if (callee()(blk.getBlock(b), blockName, paramName, paramValue))
      return true
  return false
}

function getFirstFound(sourceBlkArray, getter, defValue = null) {
  local result = null
  foreach (sourceBlk in sourceBlkArray) {
    result = getter(sourceBlk)
    if (result != null)
      break
  }
  return result ?? defValue
}

let extractIndexFromDmPartName = @(partName) rePartIdx.multiExtract("\\1", partName)?[0].tointeger() ?? -1

function getXrayViewerDataByDmPartName(partName, commonData) {
  let { unitBlk } = commonData
  let dataBlk = unitBlk?.xray_viewer_data
  local partIdx = null
  if (dataBlk != null)
    for (local b = 0; b < dataBlk.blockCount(); b++) {
      let blk = dataBlk.getBlock(b)
      if (blk?.xrayDmPart == partName)
        return blk
      if (blk?.xrayDmPartFmt != null) {
        partIdx = partIdx ?? extractIndexFromDmPartName(partName)
        if (partIdx != -1
            && partIdx >= (blk?.xrayDmPartRange.x ?? -1) && partIdx <= (blk?.xrayDmPartRange.y ?? -1)
            && format(blk.xrayDmPartFmt, partIdx) == partName)
          return blk
      }
    }
  return null
}

function getDamagePartParamsByDmPartName(unitBlk, partName, paramsTbl) {
  local res = clone paramsTbl
  let dmPartsBlk = unitBlk?.DamageParts
  if (dmPartsBlk == null)
    return res
  res = tablesCombine(res, dmPartsBlk, @(a, b) b == null ? a : b, null, false)
  for (local i = 0; i < dmPartsBlk.blockCount(); i++) {
    let groupBlk = dmPartsBlk.getBlock(i)
    if (!groupBlk || !groupBlk?[partName])
      continue
    res = tablesCombine(res, groupBlk, @(a, b) b == null ? a : b, null, false)
    res = tablesCombine(res, groupBlk[partName], @(a, b) b == null ? a : b, null, false)
    break
  }
  return res
}

function getInfoBlk(partName, unitTagsBlk, unitBlk) {
  local infoBlk = getFirstFound([ unitTagsBlk, unitBlk ], @(b) b?.info[partName])
  if (infoBlk?.alias != null)
    infoBlk = callee()(infoBlk.alias, unitTagsBlk, unitBlk)
  return infoBlk
}

function getMassInfo(sourceBlk) {
  let massPatterns = [
    { variants = ["mass", "Mass"], langKey = "mass/kg" },
    { variants = ["mass_lbs", "Mass_lbs"], langKey = "mass/lbs" }
  ]
  foreach (pattern in massPatterns)
    foreach (nameVariant in pattern.variants)
      if (nameVariant in sourceBlk)
        return format(" ".concat(loc("shop/tank_mass"), loc(pattern.langKey)), round(sourceBlk[nameVariant]))
  return ""
}

function mkAnglesRangeText(rawX, rawY, isNegativeZeroForX = false, needToRound = true) {
  let x = (needToRound || rawX == 0) ? round(rawX).tointeger() : rawX
  let y = (needToRound || rawY == 0) ? round(rawY).tointeger() : rawY
  let xStr = (needToRound || rawX == 0) ? format("%d", x) : format("%.1f", x)
  let yStr = (needToRound || rawY == 0) ? format("%d", y) : format("%.1f", y)
  if (x + y == 0)
    return $"±{yStr}{unitsDeg}"
  let signX = isNegativeZeroForX && x == 0 ? "-" : (x >= 0 ? "+" : "")
  let signY = y >= 0 ? "+" : ""
  return $"{signX}{xStr}{unitsDeg}/{signY}{yStr}{unitsDeg}"
}



function getTankCrewMemberBlk(crewBlk, dmPart) {
  let l = crewBlk.blockCount()
  for (local i = 0; i < l; i++) {
    let memberBlk = crewBlk.getBlock(i)
    if (dmPart == memberBlk.dmPart)
      return memberBlk
  }
  return null
}

let tankCrewMemberToRole = {
  commander = "commander"
  driver = "driver"
  gunner = "tank_gunner"
  loader = "loader"
  machine_gunner = "radio_gunner"
}

function mkTankCrewMemberDesc(partType, params, commonData) {
  let { unitBlk, simUnitType } = commonData
  let partName = params.name
  let desc = []
  if (simUnitType == S_TANK && unitBlk?.tank_crew) {
    let memberBlk = getTankCrewMemberBlk(unitBlk.tank_crew, partName)
    if (memberBlk != null) {
      let memberRole = tankCrewMemberToRole[partType]
      let alternativeRoles = (memberBlk % "role")
        .filter(@(r) r != memberRole)
        .map(@(r) loc($"duplicate_role/{r}"))
        .filter(@(n) n != "")
      desc.extend(alternativeRoles)
    }
  }
  return { desc }
}



let AFTERBURNER_CHAMBER = 3

function getEngineModelName(infoBlk) {
  return " ".join([
    infoBlk?.manufacturer ? loc($"engine_manufacturer/{infoBlk.manufacturer}") : ""
    infoBlk?.model ? loc($"engine_model/{infoBlk.model}") : ""
  ], true)
}

function mkEngineDesc(_partType, params, commonData) {
  let { unitBlk, getUnitFmBlk, simUnitType, findAnyModEffectValueBlk,
    getProp_horsePowers, getProp_maxHorsePowersRPM, getProp_thrust, toStr_horsePowers, toStr_thrustKgf,
    isSecondaryModsValid
  } = commonData
  let partName = params.name
  let desc = []
  if (simUnitType == S_TANK) {
    let infoBlk = findAnyModEffectValueBlk(commonData, "engine") ?? unitBlk?.VehiclePhys.engine
    if (infoBlk) {
      let engineModelName = getEngineModelName(infoBlk)
      let addEngineName = params?.isAddEngineName ?? true
      if (addEngineName)
        desc.append(engineModelName)

      let engineConfig = []
      let engineType = infoBlk?.type ?? (engineModelName != "" ? "diesel" : "")
      if (engineType != "")
        engineConfig.append(loc($"engine_type/{engineType}"))
      if (infoBlk?.configuration)
        engineConfig.append(loc($"engine_configuration/{infoBlk.configuration}"))
      let typeText = comma.join(engineConfig, true)
      if (typeText != "")
        desc.append("".concat(loc("plane_engine_type"), colon, typeText))

      if (infoBlk?.displacement)
        desc.append("".concat(loc("engine_displacement"), colon,
          loc("measureUnits/displacement", { num = infoBlk.displacement.tointeger() })))
    }

    let horsePowers = getProp_horsePowers(commonData)
    let maxHorsePowersRPM = getProp_maxHorsePowersRPM(commonData)
    if (isSecondaryModsValid && horsePowers != 0 && maxHorsePowersRPM != 0) {
      let atRpmText = " ".concat(loc("shop/unitValidCondition"),
        round(maxHorsePowersRPM), loc("measureUnits/rpm"))
      desc.append("".concat(loc("engine_power"), colon, " ", toStr_horsePowers(horsePowers),
        loc("ui/parentheses/space", { text = atRpmText })))
    }
    if (infoBlk)
      desc.append(getMassInfo(infoBlk))
  }
  else if (simUnitType == S_AIRCRAFT || simUnitType == S_HELICOPTER) {
    local partIndex = toIntegerSafe(trimBetween(partName, "engine", "_"), -1, false)
    if (partIndex > 0) {
      let fmBlk = getUnitFmBlk(commonData)
      if (fmBlk != null) {
        partIndex-- 

        let infoBlk = getInfoBlk(partName, getUnitTagsBlk(commonData), unitBlk)
        let addEngineName = params?.isAddEngineName ?? true
        if (addEngineName)
          desc.append(getEngineModelName(infoBlk))

        let enginePartId = infoBlk?.part_id ?? $"Engine{partIndex}"
        let engineTypeId = "".concat("EngineType", fmBlk?[enginePartId].Type ?? -1)
        local engineBlk = fmBlk?[engineTypeId] ?? fmBlk?[enginePartId]
        if (!engineBlk) { 
          local numEngines = 0
          while ($"Engine{numEngines}" in fmBlk)
            numEngines++
          let boosterPartIndex = partIndex - numEngines 
          engineBlk = fmBlk?[$"Booster{boosterPartIndex}"]
        }
        let engineMainBlk = engineBlk?.Main

        if (engineMainBlk != null) {
          let engineInfo = []
          local engineType = getFirstFound([infoBlk, engineMainBlk], @(b) b?.Type ?? b?.type, "").tolower()
          if (simUnitType == S_HELICOPTER && engineType == "turboprop")
            engineType = "turboshaft"
          if (engineType != "")
            engineInfo.append(loc($"plane_engine_type/{engineType}"))
          if (engineType == "inline" || engineType == "radial") {
            let cylinders = getFirstFound([infoBlk, engineMainBlk], @(b) b?.Cylinders ?? b?.cylinders, 0)
            if (cylinders > 0)
              engineInfo.append("".concat(cylinders, loc("engine_cylinders_postfix")))
          }
          let typeText = comma.join(engineInfo, true)
          if (typeText != "")
            desc.append("".concat(loc("plane_engine_type"), colon, typeText))

          
          if ((engineType == "inline" || engineType == "radial")
              && "IsWaterCooled" in engineMainBlk) { 
            let coolingKey = engineMainBlk?.IsWaterCooled ? "water" : "air"
            desc.append("".concat(loc("plane_engine_cooling_type"), colon,
              loc($"plane_engine_cooling_type_{coolingKey}")))
          }

          if (isSecondaryModsValid) {
            
            local powerMax = 0
            local powerTakeoff = 0
            local thrustMax = 0
            local thrustTakeoff = 0
            local thrustMaxCoef = 1
            local afterburneThrustMaxCoef = 1
            let engineThrustMaxBlk = engineMainBlk?.ThrustMax

            if (engineThrustMaxBlk) {
              thrustMaxCoef = engineThrustMaxBlk?.ThrustMaxCoeff_0_0 ?? 1
              afterburneThrustMaxCoef = engineThrustMaxBlk?.ThrAftMaxCoeff_0_0 ?? 1
            }

            let horsePowerValue = getFirstFound([infoBlk, engineMainBlk],
              @(b) b?.ThrustMax.PowerMax0 ?? b?.HorsePowers ?? b?.Power, 0)
            let thrustValue = getFirstFound([infoBlk, engineMainBlk], @(b) b?.ThrustMax.ThrustMax0, 0)

            local thrustMult = 1.0
            local thrustTakeoffMult = 1.0
            local modeIdx = 0
            while (true) {
              let modeBlk = engineMainBlk?[$"Mode{++modeIdx}"]
              if (modeBlk?.ThrustMult == null)
                break
              if (modeBlk?.Throttle != null && modeBlk.Throttle <= 1.0)
                thrustMult = modeBlk.ThrustMult
              thrustTakeoffMult = modeBlk.ThrustMult
            }

            let throttleBoost = getFirstFound([infoBlk, engineMainBlk], @(b) b?.ThrottleBoost, 0)
            let afterburnerBoost = getFirstFound([infoBlk, engineMainBlk], @(b) b?.AfterburnerBoost, 0)
            
            let thrustModDelta = getProp_thrust(commonData) / KGF_TO_NEWTON
            let horsepowerModDelta = getProp_horsePowers(commonData)
            if (engineType == "inline" || engineType == "radial") {
              if (throttleBoost > 1) {
                powerMax = horsePowerValue
                powerTakeoff = horsePowerValue * throttleBoost * afterburnerBoost
              }
              else
                powerTakeoff = horsePowerValue
            }
            else if (engineType == "rocket") {
              let sources = [infoBlk, engineMainBlk]
              let boosterMainBlk = fmBlk?[$"Booster{partIndex}"].Main
              if (boosterMainBlk)
                sources.insert(1, boosterMainBlk)
              thrustTakeoff = getFirstFound(sources, @(b) b?.Thrust ?? b?.thrust, 0)
            }
            else if (engineType == "turboprop" || engineType == "turboshaft") {
              powerMax = horsePowerValue
              thrustMax = thrustValue * thrustMult
            }
            else {
              if (throttleBoost > 1 && afterburnerBoost > 1) {
                thrustTakeoff = thrustValue * thrustTakeoffMult * afterburnerBoost
                thrustMax = thrustValue * thrustMult
              }
              else
                thrustTakeoff = thrustValue * thrustTakeoffMult
            }

            
            powerMax = infoBlk?.power_max ?? powerMax
            powerTakeoff = infoBlk?.power_takeoff ?? powerTakeoff
            thrustMax = infoBlk?.thrust_max ?? thrustMax
            thrustTakeoff = infoBlk?.thrust_takeoff ?? thrustTakeoff

            
            if (powerMax > 0) {
              powerMax += horsepowerModDelta
              desc.append("".concat(loc("engine_power_max"), colon, toStr_horsePowers(powerMax)))
            }
            if (powerTakeoff > 0) {
              powerTakeoff += horsepowerModDelta
              desc.append("".concat(loc("engine_power_takeoff"), colon, toStr_horsePowers(powerTakeoff)))
            }
            if (thrustMax > 0) {
              thrustMax += thrustModDelta
              thrustMax *= thrustMaxCoef
              desc.append("".concat(loc("engine_thrust_max"), colon, toStr_thrustKgf(thrustMax)))
            }
            if (thrustTakeoff > 0) {
              let afterburnerBlk = engineBlk?.Afterburner
              let thrustTakeoffLocId = (afterburnerBlk?.Type == AFTERBURNER_CHAMBER &&
                  (afterburnerBlk?.IsControllable ?? false))
                ? "engine_thrust_afterburner"
                : "engine_thrust_takeoff"

              thrustTakeoff += thrustModDelta
              thrustTakeoff *= thrustMaxCoef * afterburneThrustMaxCoef
              desc.append("".concat(loc(thrustTakeoffLocId), colon, toStr_thrustKgf(thrustTakeoff)))
            }

            
            desc.append(getMassInfo(infoBlk))
          }
        }
      }
    }
  }
  return { desc }
}

function mkTransmissionDesc(_partType, _params, commonData) {
  let { unitBlk, getProp_maxSpeed, toStr_speed } = commonData
  let desc = []
  let info = unitBlk?.VehiclePhys.mechanics
  if (info != null) {
    let manufacturer = info?.manufacturer
      ? loc($"transmission_manufacturer/{info.manufacturer}",
        loc($"engine_manufacturer/{info.manufacturer}", ""))
      : ""
    let model = info?.model ? loc($"transmission_model/{info.model}", "") : ""
    let props = info?.type ? utf8ToLower(loc($"transmission_type/{info.type}", "")) : ""
    desc.append("".concat(" ".join([ manufacturer, model ], true),
      props == "" ? "" : loc("ui/parentheses/space", { text = props })))

    let maxSpeed = getProp_maxSpeed(commonData)
    if (maxSpeed != 0 && info?.gearRatios) {
      local gearsF = 0
      local gearsB = 0
      local ratioF = 0
      local ratioB = 0
      foreach (gear in (info.gearRatios % "ratio")) {
        if (gear > 0) {
          gearsF++
          ratioF = ratioF ? min(ratioF, gear) : gear
        }
        else if (gear < 0) {
          gearsB++
          ratioB = ratioB ? min(ratioB, -gear) : -gear
        }
      }
      let maxSpeedF = maxSpeed
      let maxSpeedB = ratioB ? (maxSpeed * ratioF / ratioB) : 0
      if (maxSpeedF && gearsF)
        desc.append("".concat(loc("xray/transmission/maxSpeed/forward"), colon,
          toStr_speed(maxSpeedF), comma, loc("xray/transmission/gears")
          colon, gearsF))
      if (maxSpeedB && gearsB)
        desc.append("".concat(loc("xray/transmission/maxSpeed/backward"), colon,
          toStr_speed(maxSpeedB), comma, loc("xray/transmission/gears"),
          colon, gearsB))
    }
  }
  return  { desc }
}

let compareWeaponFunc = @(w1, w2) isEqual(w1?.trigger ?? "", w2?.trigger ?? "")
  && isEqual(w1?.blk ?? "", w2?.blk ?? "")
  && isEqual(w1?.bullets ?? "", w2?.bullets ?? "")
  && isEqual(w1?.gunDm ?? "", w2?.gunDm ?? "")
  && isEqual(w1?.barrelDP ?? "", w2?.barrelDP ?? "")
  && isEqual(w1?.breechDP ?? "", w2?.breechDP ?? "")
  && isEqual(w1?.ammoDP ?? "", w2?.ammoDP ?? "")
  && isEqual(w1?.dm ?? "", w2?.dm ?? "")
  && isEqual(w1?.turret.head ?? "", w2?.turret.head ?? "")
  && isEqual(w1?.flash ?? "", w2?.flash ?? "")
  && isEqual(w1?.emitter ?? "", w2?.emitter ?? "")

function getWeaponByXrayPartName(unitWeaponsList, weaponPartName, linkedPartName = null) {
  let turretLinkedParts = [ "horDriveDm", "verDriveDm" ]
  let partLinkSources = [ "dm", "barrelDP", "breechDP", "maskDP", "gunDm", "ammoDP", "emitter" ]
  let partLinkSourcesGenFmt = [ "emitterGenFmt", "ammoDpGenFmt" ]
  foreach (weapon in unitWeaponsList) {
    if (linkedPartName != null && weapon?.turret != null)
      foreach (partKey in turretLinkedParts)
        if (weapon.turret?[partKey] == linkedPartName)
          return weapon
    foreach (linkKey in partLinkSources)
      if (weapon?[linkKey] == weaponPartName)
        return weapon
  }
  foreach (weapon in unitWeaponsList) {
    if (weapon?.turret.gunnerDm == weaponPartName)
      return weapon
    if (weapon?.turret.head != null && $"{weapon.turret.head}_dm" == weaponPartName)
      return weapon
    if (weapon?.turret.gun != null && $"{weapon.turret.gun}_dm" == weaponPartName)
      return weapon
  }
  foreach (weapon in unitWeaponsList) {
    if (isIPoint2(weapon?.emitterGenRange)) {
      let rangeMin = min(weapon.emitterGenRange.x, weapon.emitterGenRange.y)
      let rangeMax = max(weapon.emitterGenRange.x, weapon.emitterGenRange.y)
      foreach (linkKeyFmt in partLinkSourcesGenFmt)
        if (weapon?[linkKeyFmt]) {
          if (weapon[linkKeyFmt].indexof("%02d") == null) {
            assert(false, $"Bad weapon param {linkKeyFmt} = \"{weapon[linkKeyFmt]}\"")
            continue
          }
          for (local i = rangeMin; i <= rangeMax; i++)
            if (format(weapon[linkKeyFmt], i) == weaponPartName)
              return weapon
        }
    }
    if ("partsDP" in weapon && weapon["partsDP"].indexof(weaponPartName) != null)
      return weapon
  }

  if (weaponPartName.startswith("auxiliary_caliber_turret")) {
    let turretIdx = extractIndexFromDmPartName(weaponPartName)
    foreach (weapon in unitWeaponsList)
      if (weapon?.turret.head.startswith("auxiliary_caliber_turret") && isIPoint2(weapon?.emitterGenRange)) {
        let turretStartIdx = extractIndexFromDmPartName(weapon.turret.head)
        let rangeLen = abs(weapon.emitterGenRange.x - weapon.emitterGenRange.y) + 1
        if (turretIdx >= turretStartIdx && turretIdx < turretStartIdx + rangeLen)
          return weapon
      }
  }

  return null
}

function getWeaponStatusImpl(weaponPartName, weaponInfoBlk, commonData) {
  let  { unitBlk, simUnitType, getCommonWeapons, isCaliberCannon } = commonData
  if (simUnitType == S_TANK) {
    let blkPath = weaponInfoBlk?.blk ?? ""
    let blk = blkOptFromPath(blkPath)
    let isRocketGun = blk?.rocketGun
    let isMachinegun = !!blk?.bullet.caliber && !isCaliberCannon(1000 * blk.bullet.caliber)
    local isPrimary = !isRocketGun && !isMachinegun
    if (!isPrimary)
      foreach (weapon in getCommonWeapons(unitBlk, "")) {
        if (!weapon?.blk || weapon?.dummy)
          continue
        isPrimary = weapon.blk == blkPath
        break
      }

    let isSecondary = !isPrimary && !isMachinegun
    return { isPrimary = isPrimary, isSecondary = isSecondary, isMachinegun = isMachinegun }
  }
  if (simUnitType == S_BOAT || simUnitType == S_SHIP) {
    let isPrimaryName       = weaponPartName.startswith("main")
    let isSecondaryName     = weaponPartName.startswith("auxiliary")
    let isPrimaryTrigger    = weaponInfoBlk?.triggerGroup == "primary"
    let isSecondaryTrigger  = weaponInfoBlk?.triggerGroup == "secondary"
    let isMachinegun        = weaponInfoBlk?.triggerGroup == "machinegun"
    return {
      isPrimary     = isPrimaryTrigger   || (isPrimaryName   && !isSecondaryTrigger && !isMachinegun)
      isSecondary   = isSecondaryTrigger || (isSecondaryName && !isPrimaryTrigger && !isMachinegun)
      isMachinegun  = isMachinegun
    }
  }
  if (simUnitType == S_AIRCRAFT || simUnitType == S_HELICOPTER)
    return { isPrimary = true, isSecondary = false, isMachinegun = false }

  return { isPrimary = true, isSecondary = false, isMachinegun = false }
}

function getWeaponStatus(weaponPartName, weaponInfoBlk, commonData) {
  let { unitDataCache } = commonData
  if ("weapStatus" not in unitDataCache)
    unitDataCache.weapStatus <- {}
  let cacheId = $"{weaponPartName}_{weaponInfoBlk}"
  if (cacheId not in unitDataCache.weapStatus)
    unitDataCache.weapStatus[cacheId] <- getWeaponStatusImpl(weaponPartName, weaponInfoBlk, commonData)
  return unitDataCache.weapStatus[cacheId]
}

function getWeaponDriveTurretTexts(commonData, weaponPartName, weaponInfoBlk, needAxisX, needAxisY) {
  let { simUnitType, getUnitWeaponsList
    getProp_tankMainTurretSpeedYaw, getProp_tankMainTurretSpeedYawTop,
    getProp_tankMainTurretSpeedPitch, getProp_tankMainTurretSpeedPitchTop,
    getMul_shipTurretMainSpeedYaw, getMul_shipTurretAuxSpeedYaw, getMul_shipTurretAaSpeedYaw,
    getMul_shipTurretMainSpeedPitch, getMul_shipTurretAuxSpeedPitch, getMul_shipTurretAaSpeedPitch
  } = commonData
  let desc = []
  let needSingleAxis = !needAxisX || !needAxisY
  let status = getWeaponStatus(weaponPartName, weaponInfoBlk, commonData)
  if (!needSingleAxis && simUnitType == S_TANK && !status.isPrimary && !status.isSecondary)
    return desc

  let isInverted = weaponInfoBlk?.invertedLimitsInViewer ?? false
  let isSwaped = weaponInfoBlk?.swapLimitsInViewer ?? false
  let verticalLabel = "shop/angleVerticalGuidance"
  let horizontalLabel = "shop/angleHorizontalGuidance"

  foreach (g in [
    { need = needAxisX, angles = weaponInfoBlk?.limits.yaw,   label = isInverted ? verticalLabel   : horizontalLabel, canSwap = true  }
    { need = needAxisY, angles = weaponInfoBlk?.limits.pitch, label = isInverted ? horizontalLabel : verticalLabel,   canSwap = false }
  ]) {
    if (!g.need || (!g.angles?.x && !g.angles?.y))
      continue

    let { x, y } = g.angles
    let needSwap = isSwaped && g.canSwap
    let degX = needSwap ? abs(y) * getSign(x) : x
    let degY = needSwap ? abs(x) * getSign(y) : y
    desc.append(" ".concat(loc(g.label), mkAnglesRangeText(degX, degY, true, false)))
  }

  if (needSingleAxis || status.isPrimary || [S_SHIP, S_BOAT].contains(simUnitType)) {
    foreach (a in [
      { need = needAxisX, blkName = "speedYaw",
        modifName = "turnTurretSpeed",
        getTankMainTurretSpeed = getProp_tankMainTurretSpeedYaw
        getTankTopVal = getProp_tankMainTurretSpeedYawTop,
        getShipMul = [ getMul_shipTurretMainSpeedYaw, getMul_shipTurretAuxSpeedYaw, getMul_shipTurretAaSpeedYaw ]
      },
      { need = needAxisY, blkName = "speedPitch",
        modifName = "turnTurretSpeedPitch",
        getTankMainTurretSpeed = getProp_tankMainTurretSpeedPitch
        getTankTopVal = getProp_tankMainTurretSpeedPitchTop,
        getShipMul = [ getMul_shipTurretMainSpeedPitch, getMul_shipTurretAuxSpeedPitch, getMul_shipTurretAaSpeedPitch ]
      },
    ]) {
      if (!a.need)
        continue

      local speed = 0
      local speedMul = 1
      if (simUnitType == S_TANK) {
        let mainTurretSpeed = a.getTankMainTurretSpeed(commonData)
        let value = weaponInfoBlk?[a.blkName] ?? 0
        let unitWeaponsList = getUnitWeaponsList(commonData)
        let mainTurretValue = unitWeaponsList[0]?[a.blkName] ?? 0
        if (mainTurretValue != 0)
          speedMul = value / mainTurretValue
        speed = mainTurretSpeed * speedMul
      }
      else if ([S_SHIP, S_BOAT].contains(simUnitType)) {
        let getMul = status.isPrimary ? a.getShipMul[0]
          : status.isSecondary  ? a.getShipMul[1]
          : status.isMachinegun ? a.getShipMul[2]
          : @(_) 1.0
        let baseSpeed = weaponInfoBlk?[a.blkName] ?? 0
        let mul = getMul(commonData)
        speed = baseSpeed * mul
      }

      if (speed != 0) {
        let speedTxt = format("%.1f", speed)
        let res = { value = "".concat(loc($"crewSkillParameter/{a.modifName}"), colon, speedTxt, unitsDegPerSec) }
        if (simUnitType == S_TANK) {
          let topVal = a.getTankTopVal(commonData) * speedMul
          if (topVal > speed)
            res.topValue <- "".concat(format("%.1f", topVal), unitsDegPerSec)
        }
        desc.append(res)
      }
    }
  }

  if (simUnitType == S_TANK) {
    let gunStabilizer = weaponInfoBlk?.gunStabilizer
    let isStabilizerX = needAxisX && gunStabilizer?.hasHorizontal
    let isStabilizerY = needAxisY && gunStabilizer?.hasVertical
    if (isStabilizerX || isStabilizerY) {
      let valueLoc = needSingleAxis ? "options/yes"
        : (isStabilizerX ? "shop/gunStabilizer/twoPlane" : "shop/gunStabilizer/vertical")
      desc.append(" ".concat(loc("shop/gunStabilizer"), loc(valueLoc)))
    }
  }

  return desc
}

function mkDriveTurretDesc(partType, params, commonData) {
  let { getUnitWeaponsList } = commonData
  let partName = params.name
  let desc = []
  let weaponPartName = partName.replace(partType, "gun_barrel")
  let unitWeaponsList = getUnitWeaponsList(commonData)
  let weaponInfoBlk = getWeaponByXrayPartName(unitWeaponsList, weaponPartName, partName)
  if (weaponInfoBlk != null) {
    let isHorizontal = partType == "drive_turret_h"
    desc.extend(getWeaponDriveTurretTexts(commonData, weaponPartName, weaponInfoBlk, isHorizontal, !isHorizontal))
  }
  return { desc }
}

function mkAircraftFuelTankDesc(partType, params, commonData) {
  let { getAircraftFuelTankPartInfo } = commonData
  let partName = params.name
  let desc = []
  local partLocId = partType
  let tankInfoTable = getAircraftFuelTankPartInfo(commonData, partName)
  if (tankInfoTable != null) {
    if (tankInfoTable?.manufacturer)
      partLocId = tankInfoTable.manufacturer
    let tankInfo = []
    if ("protected" in tankInfoTable)
      tankInfo.append(loc(tankInfoTable.protected ? "fuelTank/selfsealing" : "fuelTank/not_selfsealing"))
    if ("protected_boost" in tankInfoTable)
      tankInfo.append(loc("fuelTank/neutralGasSystem"))
    if ("filling_polyurethane" in tankInfoTable)
      tankInfo.append(loc("fuelTank/fillingPolyurethane"))
    if (tankInfo.len())
      desc.append(comma.join(tankInfo, true))
  }
  return { desc, partLocId }
}



function mkWeaponPartLocId(partType, partName, weaponInfoBlk, commonData) {
  let { simUnitType } = commonData
  if (simUnitType == S_TANK) {
    if (partType == "gun_barrel" && weaponInfoBlk?.blk) {
      let status = getWeaponStatus(partName, weaponInfoBlk, commonData)
      return status.isPrimary ? "weapon/primary"
        : status.isMachinegun ? "weapon/machinegun"
        : "weapon/secondary"
    }
  }
  else if (simUnitType == S_BOAT || simUnitType == S_SHIP) {
    if (partType.startswith("main") && weaponInfoBlk?.triggerGroup == "secondary")
      return partType.replace("main", "auxiliary")
    if (partType.startswith("auxiliary") && weaponInfoBlk?.triggerGroup == "primary")
      return partType.replace("auxiliary", "main")
  }
  else if (simUnitType == S_HELICOPTER) {
    if ([ "gun", "cannon" ].contains(partType))
      return (weaponInfoBlk?.trigger ?? "").startswith("gunner") ? "turret" : "cannon"
  }
  return partType
}

let getWeaponLocName = @(weaponName, commonData)
  commonData?.getWeaponLocNameCustom(weaponName, commonData) ?? loc($"weapons/{weaponName}")

function getWeaponTotalBulletCount(unitWeaponsList, partType, weaponInfoBlk) {
  if (partType == "cannon_breech") {
    local result = 0
    let currentBreechDp = weaponInfoBlk?.breechDP
    if (!currentBreechDp)
      return result
    foreach (weapon in unitWeaponsList) {
      if (weapon?.breechDP == currentBreechDp)
        result += weapon?.bullets ?? 0
    }
    return result
  }
  else if (partType == "gun" && weaponInfoBlk?.turret)
    return unitWeaponsList
      .filter(@(weapon) weapon?.turret.head && weapon.turret.head == weaponInfoBlk?.turret.head)
      .reduce(@(bulletCount, weapon) bulletCount + (weapon?.bullets ?? 0), 0)
  else
    return weaponInfoBlk?.bullets ?? 0
}

function getGunReloadTimeMax(weaponInfoBlk) {
  let weaponInfo = blkOptFromPath(weaponInfoBlk?.blk)
  let reloadTime = weaponInfoBlk?.reloadTime ?? weaponInfo?.reloadTime
  if (reloadTime)
    return reloadTime

  let shotFreq = weaponInfoBlk?.shotFreq ?? weaponInfo?.shotFreq
  if (shotFreq)
    return 1 / shotFreq

  return null
}

function getShipArtilleryReloadTime(commonData, weaponName) {
  let { getProp_shipReloadTimeMainCur, getProp_shipReloadTimeMainTop,
    getProp_shipReloadTimeAuxCur, getProp_shipReloadTimeAuxTop,
    getProp_shipReloadTimeAaCur, getProp_shipReloadTimeAaTop
  } = commonData
  foreach (c in [
    { getCur = getProp_shipReloadTimeMainCur, getTop = getProp_shipReloadTimeMainTop },
    { getCur = getProp_shipReloadTimeAuxCur,  getTop = getProp_shipReloadTimeAuxTop  },
    { getCur = getProp_shipReloadTimeAaCur,   getTop = getProp_shipReloadTimeAaTop   },
  ]) {
    let reloadTime = c.getCur(commonData, weaponName)
    if (reloadTime != 0) {
      let reloadTimeTop = c.getTop(commonData, weaponName)
      return { reloadTime, reloadTimeTop }
    }
  }
  return { reloadTime = 0, reloadTimeTop = 0 }
}

function getShipArtilleryReloadTimeBase(commonData, weaponName) {
  let { getProp_shipReloadTimeMainBase, getProp_shipReloadTimeAuxBase, getProp_shipReloadTimeAaBase } = commonData
  foreach (getBase in [ getProp_shipReloadTimeMainBase, getProp_shipReloadTimeAuxBase, getProp_shipReloadTimeAaBase ]) {
    let reloadTimeBase = getBase(commonData, weaponName)
    if (reloadTimeBase != 0)
      return reloadTimeBase
  }
  return 0
}

function getAmmoStowageBlockByParam(unitBlk, trigger, paramName) {
  if (!unitBlk?.ammoStowages || !trigger)
    return null

  let ammoCount = unitBlk.ammoStowages.blockCount()
  for (local i = 0; i < ammoCount; i++) {
    let ammo = unitBlk.ammoStowages.getBlock(i)
    if ((ammo % "weaponTrigger").findvalue(@(inst) inst == trigger))
      return (ammo % "shells").findvalue(@(inst) inst?[paramName])
  }
  return null
}

let getAmmoStowageReloadTimeMult = @(unitBlk, trigger)
  getAmmoStowageBlockByParam(unitBlk, trigger, "reloadTimeMult")?.reloadTimeMult ?? 1

let haveFirstStageShells = @(unitBlk, trigger)
  getAmmoStowageBlockByParam(unitBlk, trigger, "firstStage") ?? false

function getWeaponShotFreqAndReloadTimeDesc(weaponName, weaponInfoBlk, status, commonData) {
  let { unitBlk, crewId, simUnitType, getUnitWeaponsList,
    getProp_tankReloadTime, getProp_tankReloadTimeTop,
    getProp_shipReloadTimeMainDef, getProp_shipReloadTimeAuxDef, getProp_shipReloadTimeAaDef
  } = commonData

  local shotFreqRPM = 0.0 
  local reloadTimeS = 0 
  local firstStageShotFreq = 0.0
  local topValue = 0.0
  local firstStageShotFreqTop = 0.0
  local shotFreqRPMTop = 0.0

  let weaponBlk = blkOptFromPath(weaponInfoBlk?.blk)
  let isCartridge = weaponBlk?.reloadTime != null
  local cyclicShotFreqS = weaponBlk?.shotFreq ?? 0.0 

  if (simUnitType == S_AIRCRAFT || simUnitType == S_HELICOPTER) {
    shotFreqRPM = cyclicShotFreqS * 60
  }
  else if (simUnitType == S_TANK) {
    if (status.isPrimary) {
      let mainWeaponInfoBlk = getUnitWeaponsList(commonData)?[0]
      if (mainWeaponInfoBlk != null) {
        let mainGunReloadTime = getProp_tankReloadTime(commonData)

        if (weaponInfoBlk.blk == mainWeaponInfoBlk.blk) {
          reloadTimeS = mainGunReloadTime
        }
        else {
          let thisGunReloadTimeMax = getGunReloadTimeMax(weaponInfoBlk)
          if (thisGunReloadTimeMax) {
            if (weaponInfoBlk?.autoLoader) {
              reloadTimeS = thisGunReloadTimeMax
            }
            else {
              let mainGunReloadTimeMax = getGunReloadTimeMax(mainWeaponInfoBlk)
              if (mainGunReloadTimeMax)
                reloadTimeS = mainGunReloadTime * thisGunReloadTimeMax / mainGunReloadTimeMax
            }
            topValue = round_by_value(thisGunReloadTimeMax, 0.1)
          }
        }
        if(topValue == 0)
          topValue = getProp_tankReloadTimeTop(commonData)
      }
    }
  }
  else if (simUnitType == S_BOAT || simUnitType == S_SHIP) {
    if (isCartridge) {
      if (crewId != -1) {
        let { reloadTime, reloadTimeTop } = getShipArtilleryReloadTime(commonData, weaponName)
        reloadTimeS = reloadTime
        topValue = reloadTimeTop
      }
      else {
        foreach (getDef in [ getProp_shipReloadTimeMainDef, getProp_shipReloadTimeAuxDef, getProp_shipReloadTimeAaDef ]) {
          reloadTimeS = getDef(commonData, weaponName)
          if (reloadTimeS) {
            let reloadTimeBase = getShipArtilleryReloadTimeBase(commonData, weaponName)
            if(reloadTimeBase != 0) {
              topValue = reloadTimeS
              reloadTimeS = reloadTimeBase
            }
            break
          }
        }
      }
    }

    if (!reloadTimeS) {
      cyclicShotFreqS = weaponInfoBlk?.shotFreq ?? cyclicShotFreqS
      shotFreqRPM = cyclicShotFreqS * 60

      if (haveFirstStageShells(unitBlk, weaponInfoBlk?.trigger)) {
        firstStageShotFreq = shotFreqRPM
        shotFreqRPM *= 1 / getAmmoStowageReloadTimeMult(unitBlk, weaponInfoBlk?.trigger)
      }

      if (crewId != -1) {
        let { reloadTime, reloadTimeTop } = getShipArtilleryReloadTime(commonData, weaponName)
        if (reloadTime != 0 && reloadTimeTop != 0) {
          let coeff = reloadTimeTop / reloadTime
          firstStageShotFreqTop = firstStageShotFreq
          shotFreqRPMTop = shotFreqRPM
          firstStageShotFreq *= coeff
          shotFreqRPM *= coeff
        }
      }
      else {
        let reloadTimeBase = getShipArtilleryReloadTimeBase(commonData, weaponName)
        if (reloadTimeBase) {
          if (firstStageShotFreq) {
            firstStageShotFreqTop = firstStageShotFreq
            shotFreqRPMTop = shotFreqRPM
            firstStageShotFreq = 60 / reloadTimeBase
            shotFreqRPM = firstStageShotFreq * shotFreqRPMTop / firstStageShotFreqTop
          }
          else {
            shotFreqRPMTop = shotFreqRPM
            shotFreqRPM = 60 / reloadTimeBase
          }
        }
      }
    }
  }

  let desc = []
  if (firstStageShotFreq) {
    let res = { value = " ".concat(loc("shop/shotFreq/firstStage"), round(firstStageShotFreq), unitsRoundsPerMin) }
    if (firstStageShotFreq < firstStageShotFreqTop)
      res.topValue <- " ".concat(round(firstStageShotFreqTop), unitsRoundsPerMin)
    desc.append(res)
  }

  if (shotFreqRPM) {
    shotFreqRPM = round_by_value(shotFreqRPM, shotFreqRPM > 600 ? 10
      : shotFreqRPM < 10 ? 0.1
      : 1)
    shotFreqRPMTop = round_by_value(shotFreqRPMTop, shotFreqRPMTop > 600 ? 10
      : shotFreqRPMTop < 10 ? 0.1
      : 1)
    let res = { value = " ".concat(loc("shop/shotFreq"), shotFreqRPM, unitsRoundsPerMin) }
    if (shotFreqRPM < shotFreqRPMTop)
      res.topValue <- " ".concat(shotFreqRPMTop, unitsRoundsPerMin)
    desc.append(res)
  }
  if (reloadTimeS) {
    reloadTimeS = round_by_value(reloadTimeS, 0.1)
    topValue = round_by_value(topValue, 0.1)
    let reloadTimeSTxt = (reloadTimeS % 1) ? format("%.1f", reloadTimeS) : format("%d", reloadTimeS)
    let res = { value = " ".concat(loc("shop/reloadTime"), reloadTimeSTxt, unitsSec) }
    if (topValue != 0 && topValue < reloadTimeS)
      res.topValue <- " ".concat(topValue, unitsSec)
    desc.append(res)
  }
  return desc
}



function getAmmoStowageInfo(unitBlk, weaponTrigger, ammoStowageId = null, collectOnlyThisStowage = false) {
  let res = { firstStageCount = 0, isAutoLoad = false, isCharges = false }
  for (local ammoNum = 1; ammoNum <= 20; ammoNum++) { 
    let ammoId = $"ammo{ammoNum}"
    let stowage = unitBlk?.ammoStowages[ammoId]
    if (!stowage)
      break
    if (weaponTrigger && stowage.weaponTrigger != weaponTrigger)
      continue
    if ((unitBlk.ammoStowages % ammoId).len() > 1)
      assert(false, $"ammoStowages contains non-unique ammo")
    foreach (blockName in [ "shells", "charges" ]) {
      foreach (block in (stowage % blockName)) {
        if (ammoStowageId && !block?[ammoStowageId])
          continue
        res.isCharges = blockName == "charges"
        if (block?.autoLoad)
          res.isAutoLoad = true
        if (block?.firstStage || block?.autoLoad) {
          if (ammoStowageId && collectOnlyThisStowage)
            res.firstStageCount += block?[ammoStowageId].count ?? 0
          else
            for (local i = 0; i < block.blockCount(); i++)
              res.firstStageCount += block.getBlock(i)?.count ?? 0
        }
        return res
      }
    }
  }
  return res
}

function mkWeaponDesc(partType, params, commonData) {
  let { unitBlk, getUnitWeaponsList, simUnitType, getWeaponNameByBlkPath, getWeaponDescTextByWeaponInfoBlk,
    shouldShowAmmoAndShotFreq = null
  } = commonData
  let partName = params.name
  let weaponTrigger = params?.weapon_trigger
  let desc = []
  local partLocId = partType

  let weaponPartName = partName
  let turretWeaponsNames = {} 
  if (partType == "main_caliber_turret" || partType == "auxiliary_caliber_turret" || partType == "aa_turret") {
    let unitWeaponsList = getUnitWeaponsList(commonData)
    foreach (weapon in unitWeaponsList)
      if (weapon?.turret.gunnerDm == partName) {
        let weaponName = getWeaponNameByBlkPath(weapon?.blk ?? "")
        if (weaponName == "")
          continue
        if (!turretWeaponsNames?[weaponName])
          turretWeaponsNames[weaponName] <- 0
        turretWeaponsNames[weaponName] += 1
      }

    if (turretWeaponsNames.len() > 0)
      foreach(weaponName, weaponsCount in turretWeaponsNames)
        desc.append("".concat(getWeaponLocName(weaponName, commonData),
          weaponsCount > 1 ? format(loc("weapons/counter"), weaponsCount) : ""))
  }
  local weaponInfoBlk = null
  let triggerParam = "trigger"
  if (weaponTrigger != null) {
    let unitWeaponsList = getUnitWeaponsList(commonData)
    foreach (weapon in unitWeaponsList) {
      if (triggerParam not in weapon || weapon[triggerParam] != weaponTrigger)
        continue
      if (weapon?.turret.gunnerDm == partName) {
        weaponInfoBlk = weapon
        break
      }
    }
  }

  if (weaponInfoBlk == null) {
    let unitWeaponsList = getUnitWeaponsList(commonData)
    weaponInfoBlk = getWeaponByXrayPartName(unitWeaponsList, weaponPartName, null)
  }

  if (weaponInfoBlk != null) {
    let isSpecialBullet = [ "torpedo", "depth_charge", "mine" ].contains(partType)
    let isSpecialBulletEmitter = [ "tt" ].contains(partType)

    let weaponBlkLink = weaponInfoBlk?.blk ?? ""
    let weaponName = getWeaponNameByBlkPath(weaponBlkLink)
    let weaponNameStr = weaponName != "" && turretWeaponsNames.len() == 0
      ? getWeaponLocName(weaponName, commonData)
      : ""
    let unitWeaponsList = getUnitWeaponsList(commonData)
    let ammo = isSpecialBullet ? 1 : getWeaponTotalBulletCount(unitWeaponsList, partType, weaponInfoBlk)

    if (isSpecialBullet || isSpecialBulletEmitter) {
      let ammoTxt = ammo > 1 ? format(loc("weapons/counter"), ammo) : ""
      desc.append("".concat(weaponNameStr, ammoTxt,
        getWeaponDescTextByWeaponInfoBlk(commonData, weaponInfoBlk)))
    }
    else {
      if (weaponNameStr != "")
        desc.append(weaponNameStr)
      let status = getWeaponStatus(weaponPartName, weaponInfoBlk, commonData)
      if (shouldShowAmmoAndShotFreq?(weaponInfoBlk, commonData) ?? true) {
        if (ammo > 1)
          desc.append("".concat(loc("shop/ammo"), colon, ammo))
        desc.extend(getWeaponShotFreqAndReloadTimeDesc(weaponName, weaponInfoBlk, status, commonData))
      }
      desc.append(getMassInfo(blkOptFromPath(weaponBlkLink)))
      if (status?.isPrimary || status?.isSecondary) {
        if (weaponInfoBlk?.autoLoader)
          desc.append(loc("xray/ammo/auto_load"))
        let firstStageCount = getAmmoStowageInfo(unitBlk, weaponInfoBlk?.trigger).firstStageCount
        if (firstStageCount)
          desc.append("".concat(loc([S_SHIP, S_BOAT].contains(simUnitType) ? "xray/ammo/first_stage_ship" : "xray/ammo/first_stage"),
            colon, firstStageCount))
      }
      desc.extend(getWeaponDriveTurretTexts(commonData, weaponPartName, weaponInfoBlk, true, true))
    }

    partLocId = mkWeaponPartLocId(partType, partName, weaponInfoBlk, commonData)
  }

  return { desc, partLocId }
}



function getAmmoStowageSlotInfo(unitBlk, partName) {
  let res = {
    count = 0,
    isConstrainedInert = false
  }
  let ammoStowages = unitBlk?.ammoStowages
  if (ammoStowages)
    for (local i = 0; i < ammoStowages.blockCount(); i++) {
      let blk = ammoStowages.getBlock(i)
      foreach (blockName in [ "shells", "charges" ])
        foreach (shells in blk % blockName) {
          let slotBlk = shells?[partName]
          if (slotBlk) {
            res.count = slotBlk.count
            res.isConstrainedInert = slotBlk?.type == "inert"
            return res
          }
        }
    }
  return res
}

function mkAmmoDesc(partType, params, commonData) {
  let { unitBlk, simUnitType } = commonData
  let partName = params.name
  let desc = []
  local partLocId = partType
  let isShipOrBoat = [S_SHIP, S_BOAT].contains(simUnitType)
  let ammoSlotInfo = getAmmoStowageSlotInfo(unitBlk, partName)
  if (isShipOrBoat && ammoSlotInfo.count > 1)
    desc.append("".concat(loc("shop/ammo"), colon, ammoSlotInfo.count))
  let stowageInfo = getAmmoStowageInfo(unitBlk, null, partName, isShipOrBoat)
  if (stowageInfo.isCharges)
    partLocId = isShipOrBoat ? "ship_charges_storage" : "ammo_charges"
  if (stowageInfo.firstStageCount) {
    local txt = loc(isShipOrBoat ? "xray/ammo/first_stage_ship" : "xray/ammo/first_stage")
    if (simUnitType == S_TANK)
      txt = "".concat(txt, comma, stowageInfo.firstStageCount, " ", unitsPcs)
    desc.append(txt)
  }
  if (stowageInfo.isAutoLoad)
    desc.append(loc("xray/ammo/mechanized_ammo_rack"))
  if (ammoSlotInfo.isConstrainedInert)
    desc.append(loc("xray/ammo/constrained_inert"))
  return { desc, partLocId }
}



function getModernArmorParamsByDmPartName(partName, commonData) {
  let { unitBlk } = commonData
  local res = {
    isComposite = partName.startswith("composite_armor") || partName.startswith("firewall_armor")
    titleLoc = ""
    armorClass = ""
    referenceProtectionArray = []
    layersArray = []
  }

  let blk = getXrayViewerDataByDmPartName(partName, commonData)
  if (blk) {
    res.titleLoc = blk?.titleLoc ?? ""

    let referenceProtectionBlocks = blk?.referenceProtectionTable ? (blk.referenceProtectionTable % "i")
      : (blk?.kineticProtectionEquivalent || blk?.cumulativeProtectionEquivalent) ? [ blk ]
      : []
    res.referenceProtectionArray = referenceProtectionBlocks.map(@(b) {
      angles = b?.angles
      kineticProtectionEquivalent    = b?.kineticProtectionEquivalent    ?? 0
      cumulativeProtectionEquivalent = b?.cumulativeProtectionEquivalent ?? 0
    })

    let armorParams = { armorClass = "", armorThickness = 0.0 }
    let armorLayersArray = (blk?.armorArrayText ?? DataBlock()) % "layer"

    foreach (layer in armorLayersArray) {
      let info = getDamagePartParamsByDmPartName(unitBlk, layer?.dmPart, armorParams)
      if (layer?.xrayTextThickness != null)
        info.armorThickness = layer.xrayTextThickness
      if (layer?.xrayArmorClass != null)
        info.armorClass = layer.xrayArmorClass
      res.layersArray.append(info)
    }
  }
  else {
    let armorParams = { armorClass = "", kineticProtectionEquivalent = 0, cumulativeProtectionEquivalent = 0 }
    let info = getDamagePartParamsByDmPartName(unitBlk, partName, armorParams)
    res.referenceProtectionArray = [{
      angles = null
      kineticProtectionEquivalent    = info.kineticProtectionEquivalent
      cumulativeProtectionEquivalent = info.cumulativeProtectionEquivalent
    }]
    res = tablesCombine(res, info, @(a, b) b == null ? a : b, null, false)
  }

  return res
}

function mkTankArmorPartDesc(partType, params, commonData) {
  let { simUnitType } = commonData
  let partName = params.name
  let desc = []
  local partLocId = partType
  let strUnits = "".concat(nbsp, unitsMm)
  let info = getModernArmorParamsByDmPartName(partName, commonData)

  if (info.titleLoc != "")
    partLocId = info.titleLoc

  if (partName.startswith("firewall_armor")) {
    let descLocId = "armor_class/desc/firewall_armor"
    if (doesLocTextExist(descLocId))
      desc.append(loc(descLocId))
  }

  foreach (data in info.referenceProtectionArray) {
    if (isPoint2(data.angles))
      desc.append(loc("shop/armorThicknessEquivalent/angles",
        { angle1 = abs(data.angles.y), angle2 = abs(data.angles.x) }))
    else
      desc.append(loc("shop/armorThicknessEquivalent"))

    if (data.kineticProtectionEquivalent)
      desc.append("".concat(bullet, loc("shop/armorThicknessEquivalent/kinetic"), colon,
        round(data.kineticProtectionEquivalent), strUnits))
    if (data.cumulativeProtectionEquivalent)
      desc.append("".concat(bullet, loc("shop/armorThicknessEquivalent/cumulative"), colon,
        round(data.cumulativeProtectionEquivalent), strUnits))
  }

  let blockSep = desc.len() ? "\n" : ""

  if (info.isComposite && info.layersArray.len() != 0) { 
    let texts = []
    foreach (layer in info.layersArray) {
      local thicknessText = ""
      if (isFloat(layer?.armorThickness) && layer.armorThickness > 0)
        thicknessText = round(layer.armorThickness).tostring()
      else if (isPoint2(layer?.armorThickness) && layer.armorThickness.x > 0 && layer.armorThickness.y > 0)
        thicknessText = "".concat(round(layer.armorThickness.x), mdash,
          round(layer.armorThickness.y))
      if (thicknessText != "")
        thicknessText = loc("ui/parentheses/space", { text = $"{thicknessText}{strUnits}" })
      texts.append("".concat(bullet, getPartNameLocText(layer?.armorClass, simUnitType), thicknessText))
    }
    desc.append("".concat(blockSep, loc("xray/armor_composition"), colon, "\n", "\n".join(texts, true)))
  }
  else if (!info.isComposite && info.armorClass != "") 
    desc.append("".concat(blockSep, loc("plane_engine_type"), colon, getPartNameLocText(info.armorClass, simUnitType)))

  return { desc, partLocId }
}

function mkCoalBunkerDesc(_partType, _params, commonData) {
  let { armorClassToSteel } = commonData
  let desc = []
  let coalToSteelMul = armorClassToSteel?["ships_coal_bunker"] ?? 0
  if (coalToSteelMul != 0)
    desc.append(loc("shop/armorThicknessEquivalent/coal_bunker",
      { thickness = "".concat(round(coalToSteelMul * 1000).tostring(), " ", unitsMm) }))
  return { desc }
}



function getUnitSensorsList(commonData) {
  let { unitDataCache } = commonData
  if ("sensorBlkList" not in unitDataCache) {
    let { unitBlk, unitName, findAnyModEffectValueBlk, isModAvailableOrFree,
      isDebugBatchExportProcess
    } = commonData
    let sensorBlkList = []
    if (unitBlk != null) {
      local sensorsBlk = findAnyModEffectValueBlk(commonData, "sensors")
      let isMod = sensorsBlk != null
      sensorsBlk = sensorsBlk ?? unitBlk?.sensors

      for (local b = 0; b < (sensorsBlk?.blockCount() ?? 0); b++)
        sensorBlkList.append(sensorsBlk.getBlock(b))

      if (isDebugBatchExportProcess && isMod && unitBlk?.sensors != null)
        for (local b = 0; b < unitBlk.sensors.blockCount(); b++)
          appendOnce(unitBlk.sensors.getBlock(b), sensorBlkList, false, isEqual)

      if (unitBlk?.WeaponSlots)
        foreach (slotBlk in unitBlk.WeaponSlots % "WeaponSlot")
          foreach (slotPresetBlk in (slotBlk % "WeaponPreset"))
            if (slotPresetBlk?.sensors != null) {
              if (isDebugBatchExportProcess || slotPresetBlk?.reqModification == null
                  || isModAvailableOrFree(unitName, slotPresetBlk.reqModification))
                for (local b = 0; b < slotPresetBlk.sensors.blockCount(); b++)
                  appendOnce(slotPresetBlk.sensors.getBlock(b), sensorBlkList, false, isEqual)
            }
    }
    unitDataCache.sensorBlkList <- sensorBlkList
  }
  return unitDataCache.sensorBlkList
}

function getRadarSensorType(sensorPropsBlk) {
  local isRadar = false
  local isIrst = false
  local isTv = false
  let transiversBlk = sensorPropsBlk.getBlockByName("transivers")
  for (local t = 0; t < (transiversBlk?.blockCount() ?? 0); t++) {
    let transiverBlk = transiversBlk.getBlock(t)
    let targetSignatureType = transiverBlk?.targetSignatureType ?? transiverBlk?.visibilityType
    if (targetSignatureType == "infraRed")
      isIrst = true
    else if (targetSignatureType == "optic")
      isTv = true
    else
      isRadar = true
  }
  return isRadar && isIrst ? "radar_irst"
    : isRadar ? "radar"
    : isIrst ? "irst"
    : isTv ? "tv"
    : "radar"
}

function mkRadarTexts(commonData, sensorPropsBlk, indent) {
  let { simUnitType, toStr_distance } = commonData
  let desc = []
  local isRadar = false
  local isIrst = false
  local isTv = false
  local rangeMax = 0.0
  local radarFreqBand = 8
  local searchZoneAzimuthWidth = 0.0
  local searchZoneElevationWidth = 0.0
  let transiversBlk = sensorPropsBlk.getBlockByName("transivers")
  for (local t = 0; t < (transiversBlk?.blockCount() ?? 0); t++) {
    let transiverBlk = transiversBlk.getBlock(t)
    let range = transiverBlk.getReal("range", 0.0)
    rangeMax = max(rangeMax, range)
    let targetSignatureType = transiverBlk?.targetSignatureType ?? transiverBlk?.visibilityType
    if (targetSignatureType == "infraRed")
      isIrst = true
    else if (targetSignatureType == "optic")
      isTv = true
    else {
      isRadar = true
      radarFreqBand = transiverBlk.getInt("band", 8)
    }
    if (transiverBlk?.antenna != null) {
      if (transiverBlk.antenna?.azimuth != null && transiverBlk.antenna?.elevation != null) {
        let azimuthWidth = 2.0 * (transiverBlk.antenna.azimuth?.angleHalfSens ?? 0.0)
        let elevationWidth = 2.0 * (transiverBlk.antenna.elevation?.angleHalfSens ?? 0.0)
        searchZoneAzimuthWidth = max(searchZoneAzimuthWidth, azimuthWidth)
        searchZoneElevationWidth = max(searchZoneElevationWidth, elevationWidth)
      }
      else {
        let width = 2.0 * (transiverBlk.antenna?.angleHalfSens ?? 0.0)
        searchZoneAzimuthWidth = max(searchZoneAzimuthWidth, width)
        searchZoneElevationWidth = max(searchZoneElevationWidth, width)
      }
    }
  }

  let isSearchRadar = findBlockByName(sensorPropsBlk, "addTarget") != null

  local anglesFinder = false
  local iff = false

  local lookUp = false
  local lookDownHeadOn = false
  local lookDownHeadOnVelocity = false
  local lookDownAllAspects = false

  local airSearch = false
  local gmti = false
  local gtm = false
  local sea = false
  local gtmAndSea = false

  let signalsBlk = sensorPropsBlk.getBlockByName("signals")
  for (local s = 0; s < (signalsBlk?.blockCount() ?? 0); s++) {
    let signalBlk = signalsBlk.getBlock(s)
    if (isSearchRadar && signalBlk.getBool("track", false))
      continue

    let aircraftAsTarget = signalBlk.getBool("aircraftAsTarget", true)
    let groundVehiclesAsTarget = signalBlk.getBool("groundVehiclesAsTarget", false)
    let shipsAsTarget = signalBlk.getBool("shipsAsTarget", false)

    anglesFinder = anglesFinder || signalBlk.getBool("anglesFinder", true)
    iff = iff || signalBlk.getBool("friendFoeId", false)
    let groundClutter = signalBlk.getBool("groundClutter", false)

    if (groundVehiclesAsTarget || shipsAsTarget) {
      let dopplerSpeedBlk = signalBlk.getBlockByName("dopplerSpeed")
      if (dopplerSpeedBlk && dopplerSpeedBlk.getBool("presents", false) && dopplerSpeedBlk.getReal("minValue", 0.0) > 0.2)
        gmti = true
      else if (groundVehiclesAsTarget != shipsAsTarget) {
        if (groundVehiclesAsTarget)
          gtm = true
        else
          sea = true
      }
      else
        gtmAndSea = true
    }
    else if (aircraftAsTarget) {
      airSearch = true
      let distanceBlk = signalBlk.getBlockByName("distance")
      let dopplerSpeedBlk = signalBlk.getBlockByName("dopplerSpeed")
      if (dopplerSpeedBlk && dopplerSpeedBlk.getBool("presents", false)) {
        let dopplerSpeedMin = dopplerSpeedBlk.getReal("minValue", 0.0)
        let dopplerSpeedMax = dopplerSpeedBlk.getReal("maxValue", 0.0)
        if (( signalBlk.getBool("mainBeamDopplerSpeed", false) &&
              !signalBlk.getBool("absDopplerSpeed", false) &&
              dopplerSpeedMax > 0.0 && (dopplerSpeedMin > 0.0 || dopplerSpeedMax > -dopplerSpeedMin * 0.25)) ||
             groundClutter) {
          if (!signalBlk.getBool("rangeFinder", true) && signalBlk.getBool("dopplerSpeedFinder", false) )
            lookDownHeadOnVelocity = true
          else
            lookDownHeadOn = true
        }
        else
          lookDownAllAspects = true
      }
      else if (distanceBlk && distanceBlk.getBool("presents", false))
        lookUp = true
    }
  }

  let surfaceSearch = gtm || sea || gmti || gtmAndSea

  let hasRam = findBlockByName(sensorPropsBlk, "ram") != null

  local processTargetsOfInterestBlk = null
  local hasTwsEsa = false
  if (!hasRam) {
    let addTargetTrackBlk = findBlockByName(sensorPropsBlk, "addTargetTrack")
    if (addTargetTrackBlk != null) {
      processTargetsOfInterestBlk = addTargetTrackBlk.getBlockByName("actions")?.getBlockByName("updateTargetOfInterest")
      if (processTargetsOfInterestBlk != null)
        hasTwsEsa = true;
    }
  }
  local hasTwsPlus = false
  if (!hasRam && !hasTwsEsa) {
    processTargetsOfInterestBlk = findBlockByName(sensorPropsBlk, "matchTargetsOfInterest")
    if (processTargetsOfInterestBlk != null)
      hasTwsPlus = true
  }
  local hasTws = false
  if (!hasRam && !hasTwsEsa && !hasTwsPlus) {
    processTargetsOfInterestBlk = findBlockByName(sensorPropsBlk, "updateTargetOfInterest")
    if (processTargetsOfInterestBlk != null)
      hasTws = true
  }
  let twsTargetsMax = processTargetsOfInterestBlk?.getInt("limit", 0) ?? 0

  let isTrackRadar = findBlockByName(sensorPropsBlk, "updateActiveTargetOfInterest") != null
  let hasSARH = findBlockByName(sensorPropsBlk, "setIllumination") != null
  let hasMG = findBlockByName(sensorPropsBlk, "setWeaponRcTransmissionTimeOut") != null
  let datalinkChannelsNum = sensorPropsBlk.getInt("weaponTargetsMax", 0)
  let launchedMissilesPredictedPositionsMax = sensorPropsBlk.getInt("launchedMissilesPredictedPositionsMax", 0)

  local radarType = ""
  if (isRadar)
    radarType = "radar"
  if (isIrst) {
    if (radarType != "")
      radarType =$"{radarType}_"
    radarType =$"{radarType}irst"
  }
  if (isTv) {
    if (radarType != "")
      radarType =$"{radarType}_"
    radarType =$"{radarType}tv"
  }
  if (isSearchRadar && isTrackRadar)
    radarType = $"{radarType}"
  else if (isSearchRadar)
    radarType = $"search_{radarType}"
  else if (isTrackRadar) {
    if (anglesFinder)
      radarType = $"track_{radarType}"
    else
      radarType =$"{radarType}_range_finder"
  }
  desc.append("".concat(indent, loc("plane_engine_type"), colon, loc(radarType)))
  if (isRadar)
    desc.append("".concat(indent, loc("radar_freq_band"), colon, loc($"radar_freq_band_{radarFreqBand}")))
  desc.append("".concat(indent, loc("radar_range_max"), colon, toStr_distance(rangeMax)))

  let scanPatternsBlk = sensorPropsBlk.getBlockByName("scanPatterns")
  for (local p = 0; p < (scanPatternsBlk?.blockCount() ?? 0); p++) {
    let scanPatternBlk = scanPatternsBlk.getBlock(p)
    let scanPatternType = scanPatternBlk.getStr("type", "")
    local major = 0.0
    local minor = 0.0
    local rowMajor = true
    if (scanPatternType == "cylinder") {
      major = 360.0
      minor = scanPatternBlk.getReal("barHeight", 0.0) * scanPatternBlk.getInt("barsCount", 0)
      rowMajor = scanPatternBlk.getBool("rowMajor", true)
    }
    else if (scanPatternType == "pyramide") {
      major = 2.0 * scanPatternBlk.getReal("width", 0.0)
      minor = scanPatternBlk.getReal("barHeight", 0.0) * scanPatternBlk.getInt("barsCount", 0)
      rowMajor = scanPatternBlk.getBool("rowMajor", true)
    }
    else if (scanPatternType == "cone") {
      major = 2.0 * scanPatternBlk.getReal("width", 0.0)
      minor = major
    }
    if (major * minor > searchZoneAzimuthWidth * searchZoneElevationWidth) {
      if (rowMajor) {
        searchZoneAzimuthWidth = major
        searchZoneElevationWidth = minor
      }
      else {
        searchZoneAzimuthWidth = minor
        searchZoneElevationWidth = major
      }
    }
  }

  if (isSearchRadar)
    desc.append("".concat(indent, loc("radar_search_zone_max"), colon,
      round(searchZoneAzimuthWidth), unitsDeg, loc("ui/multiply"),
      round(searchZoneElevationWidth), unitsDeg))

  if (airSearch) {
    local airSearchIndent = ""
    if (surfaceSearch) {
      desc.append("".concat(indent, loc("radar_air_search")))
      airSearchIndent = "  "
    }
    if ([S_TANK, S_SHIP, S_BOAT].contains(simUnitType)) {
      if (lookDownAllAspects)
        desc.append("".concat(indent, airSearchIndent, loc("radar_ld")))
    }
    else if (lookDownHeadOn || lookDownHeadOnVelocity || lookDownAllAspects) {
      desc.append("".concat(indent, airSearchIndent, loc("radar_ld"), colon))
      if (lookDownHeadOn)
        desc.append("".concat(indent, airSearchIndent, "  ", loc("radar_ld_head_on")))
      if (lookDownHeadOnVelocity)
        desc.append("".concat(indent, airSearchIndent, "  ", loc("radar_ld_head_on_velocity")))
      if (lookDownAllAspects)
        desc.append("".concat(indent, airSearchIndent, "  ", loc("radar_ld_all_aspects")))
      if ((lookDownHeadOn || lookDownHeadOnVelocity || lookDownAllAspects) && lookUp)
        desc.append("".concat(indent, airSearchIndent, loc("radar_lu")))
    }
  }

  if (surfaceSearch) {
    desc.append("".concat(indent, loc("radar_surface_search")))
    if (gtm)
      desc.append("".concat(indent, "  ", loc("radar_gtm")))
    if (sea)
      desc.append("".concat(indent, "  ", loc("radar_sea")))
    if (gmti)
      desc.append("".concat(indent, "  ", loc("radar_gmti")))
  }

  if (iff)
    desc.append("".concat(indent, loc("radar_iff")))
  if (isSearchRadar && hasTws)
    desc.append("".concat(indent, loc("radar_tws"), colon, twsTargetsMax))
  if (isSearchRadar && hasTwsPlus)
    desc.append("".concat(indent, loc("radar_tws_plus"), colon, twsTargetsMax))
  if (isSearchRadar && hasTwsEsa)
    desc.append("".concat(indent, loc("radar_tws_esa"), colon, twsTargetsMax))
  if (isSearchRadar && hasRam)
    desc.append("".concat(indent, loc("radar_ram")))
  if (isTrackRadar) {
    let hasBVR = findBlockByNameWithParamValue(sensorPropsBlk, "setDistGatePos", "source", "targetDesignation")
    if (hasBVR)
      desc.append("".concat(indent, loc("radar_bvr_mode")))
    let hasACM = findBlockByNameWithParamValue(sensorPropsBlk, "setDistGatePos", "source", "constRange")
    if (hasACM)
      desc.append("".concat(indent, loc("radar_acm_mode")))
    let hasHMD = (findBlockByName(sensorPropsBlk, "designateHelmetTarget") != null)
    if (hasHMD)
      desc.append("".concat(indent, loc("radar_hms_mode")))
    let nctrTargetTypes = countBlocksByName(sensorPropsBlk, "targetTypeId")
    if (nctrTargetTypes > 0)
      desc.append("".concat(indent, loc("radar_nctr"), colon, nctrTargetTypes))
    if (hasSARH)
      desc.append("".concat(indent, loc("radar_sarh")))
    if (hasMG)
      desc.append("".concat(indent, loc("radar_mg")))
    if (datalinkChannelsNum > 0)
      desc.append("".concat(indent, loc("radar_dl_channels"), colon, round(datalinkChannelsNum)))
    if (launchedMissilesPredictedPositionsMax > 0)
      desc.append("".concat(indent, loc("radar_predicted_missiles"), colon, round(launchedMissilesPredictedPositionsMax)))
  }

  return desc
}

function mkApsTexts(infoBlk) {
  let desc = []

  let {
    model = null, reactionTime = null,
    reloadTime = null, targetSpeed = null,
    shotCount = null, horAngles = null,
    verAngles = null
  } = infoBlk

  if (model)
    desc.append("".concat(loc("xray/model"), colon, loc($"aps/{model}")))
  if (horAngles)
    desc.append("".concat(loc("xray/aps/protected_sector/hor"), colon,
      mkAnglesRangeText(horAngles.x, horAngles.y)))
  if (verAngles)
    desc.append("".concat(loc("xray/aps/protected_sector/vert"), colon,
      mkAnglesRangeText(verAngles.x, verAngles.y)))
  if (reloadTime)
    desc.append("".concat(loc("xray/aps/reloadTime"), colon,
      reloadTime, " ", unitsSec))
  if (reactionTime)
    desc.append("".concat(loc("xray/aps/reactionTime"), colon,
      reactionTime * 1000, " ", loc("measureUnits/milliseconds")))
  if (targetSpeed)
    desc.append("".concat(loc("xray/aps/targetSpeed"), colon,
      $"{targetSpeed.x}-{targetSpeed.y}", " ", loc("measureUnits/metersPerSecond_climbSpeed")))
  if (shotCount)
    desc.append("".concat(loc("xray/aps/shotCount"), colon,
      shotCount, " ", unitsPcs))
  return desc
}

function mkRwrTexts(commonData, sensorPropsBlk, indent) {
  let { toStr_distance } = commonData
  let desc = []
  local bandsIndexes = []
  for (local band = 0; band < 16; ++band)
    if (sensorPropsBlk.getBool($"band{band}", false))
      bandsIndexes.append(band)

  let bandsTxtArr = [ indent, loc("radar_freq_band"), colon ]
  if (bandsIndexes.len() > 1) {
    local bandStart = null
    for (local i = 0; i < bandsIndexes.len(); ++i) {
      let band = bandsIndexes[i]
      if (bandStart == null)
        bandStart = band
      else {
        let bandPrev = bandsIndexes[i - 1]
        if (band > bandPrev + 1) {
          if (bandPrev > bandStart)
            bandsTxtArr.append(loc($"radar_freq_band_{bandStart}"), "-",
              loc($"radar_freq_band_{bandPrev}"), comma)
          else
            bandsTxtArr.append(loc($"radar_freq_band_{bandStart}"), comma)
          bandStart = band
        }
      }
    }
    let bandLast = bandsIndexes[bandsIndexes.len() - 1]
    if (bandLast > bandStart)
      bandsTxtArr.append(loc($"radar_freq_band_{bandStart}"), "-",
        loc($"radar_freq_band_{bandLast}"), " ")
    else
      bandsTxtArr.append(loc($"radar_freq_band_{bandStart}"), " ")
  }
  else
    bandsTxtArr.append(loc($"radar_freq_band_{bandsIndexes[0]}"))
  desc.append("".join(bandsTxtArr))

  let rangeMax = sensorPropsBlk.getReal("range", 0.0)
  desc.append("".concat(indent, loc("radar_range_max"), colon, toStr_distance(rangeMax)))

  local targetsDirectionGroups = {}
  let targetsDirectionGroupsBlk = sensorPropsBlk.getBlockByName("targetsDirectionGroups")
  for (local d = 0; d < (targetsDirectionGroupsBlk?.blockCount() ?? 0); d++) {
    let targetsDirectionGroupBlk = targetsDirectionGroupsBlk.getBlock(d)
    let targetsDirectionGroupText = targetsDirectionGroupBlk.getStr("text", "")
    if (!targetsDirectionGroups?[targetsDirectionGroupText])
      targetsDirectionGroups[targetsDirectionGroupText] <- true
  }
  if (targetsDirectionGroups.len() > 1)
    desc.append("".concat(indent, loc("rwr_scope_id_threats_types"), colon, targetsDirectionGroups.len()))

  let targetsPresenceGroupsBlk = sensorPropsBlk.getBlockByName("targetsPresenceGroups")
  let targetsPresenceGroupsCount = targetsPresenceGroupsBlk?.blockCount() ?? 0
  if (targetsPresenceGroupsCount > 1)
    desc.append("".concat(indent, loc("rwr_present_id_threats_types"), colon, targetsPresenceGroupsCount))

  if (sensorPropsBlk.getBool("targetTracking", false))
    desc.append("".concat(indent, loc("rwr_tracked_threats_max"), colon, sensorPropsBlk.getInt("trackedTargetsMax", 16)))

  if (sensorPropsBlk.getBool("detectTracking", true))
    desc.append("".concat(indent, loc("rwr_tracking_detection")))

  let detectLaunch = sensorPropsBlk.getBool("detectLaunch", false)
  local launchingThreatTypes = {}

  if (!detectLaunch) {
    local groupsMap = {}
    let groupsBlk = sensorPropsBlk.getBlockByName("groups")
    for (local g = 0; g < (groupsBlk?.blockCount() ?? 0); g++) {
      let groupBlk = groupsBlk.getBlock(g)
      groupsMap[groupBlk.getStr("name", "")] <- groupBlk
    }

    for (local d = 0; d < (targetsDirectionGroupsBlk?.blockCount() ?? 0); d++) {
      let targetsDirectionGroupBlk = targetsDirectionGroupsBlk.getBlock(d)
      let targetsDirectionGroupText = targetsDirectionGroupBlk.getStr("text", "")
      for (local g = 0; g < targetsDirectionGroupBlk.paramCount(); ++g)
        if (targetsDirectionGroupBlk.getParamName(g) == "group") {
          let groupName = targetsDirectionGroupBlk.getParamValue(g)
          if (groupsMap?[groupName].getBool("detectLaunch", false) ?? false)
            if (!launchingThreatTypes?[targetsDirectionGroupText]) {
              launchingThreatTypes[targetsDirectionGroupText] <- true
              break
            }
        }
    }

    for (local p = 0; p < (targetsPresenceGroupsBlk?.blockCount() ?? 0); p++) {
      let targetsPresenceGroupBlk = targetsPresenceGroupsBlk.getBlock(p)
      let targetsPresenceGroupText = targetsPresenceGroupBlk.getStr("text", "")
      for (local g = 0; g < targetsPresenceGroupBlk.paramCount(); ++g)
        if (targetsPresenceGroupBlk.getParamName(g) == "group") {
          let groupName = targetsPresenceGroupBlk.getParamValue(g)
          if (groupsMap?[groupName].getBool("detectLaunch", false) ?? false)
            if (!launchingThreatTypes?[targetsPresenceGroupText]) {
              launchingThreatTypes[targetsPresenceGroupText] <- true
              break
            }
        }
    }
  }

  if (detectLaunch)
    desc.append("".concat(indent, loc("rwr_launch_detection")))
  else if (launchingThreatTypes.len() > 1)
    desc.append("".concat(indent, loc("rwr_launch_detection"), colon, launchingThreatTypes.len()))

  local rangeFinder = false
  foreach (rangeFinderParamName in ["targetRangeFinder", "searchRangeFinder", "trackRangeFinder", "launchRangeFinder"])
    if (sensorPropsBlk.getBool(rangeFinderParamName, false)) {
      rangeFinder = true
      break
    }
  if (rangeFinder)
    desc.append("".concat(indent, loc("rwr_signal_strength")))

  if (sensorPropsBlk.getBool("friendFoeId", false))
    desc.append("".concat(indent, loc("rwr_iff")))

  return desc
}

function mkMlwsTexts(commonData, sensorPropsBlk, indent) {
  let { toStr_distance } = commonData
  let desc = []

  let targetSignatureType = sensorPropsBlk.getStr("targetSignatureType", "infraRed")
  desc.append("".concat(indent, loc($"mlws_type"), colon, targetSignatureType == "radar" ? loc($"mlws_type_radar") : loc($"mlws_type_ir")))
  desc.append("".concat(indent, loc("mlws_range_max"), colon, toStr_distance(sensorPropsBlk.getReal("range", 0.0))))
  if (sensorPropsBlk.getBool("targetRangeFinder", false))
    desc.append("".concat(indent, loc($"mlws_range_finder")))

  return desc
}

function getOpticsParams(zoomOutFov, zoomInFov) {
  let fovToZoom = @(fov) sin(80 / 2 * PI / 180) / sin(fov / 2 * PI / 180)
  let fovOutIn = [zoomOutFov, zoomInFov].filter(@(fov) fov > 0)
  let zoom = fovOutIn.map(@(fov) fovToZoom(fov))
  if (zoom.len() == 2 && abs(zoom[0] - zoom[1]) < 0.1) {
    zoom.remove(0)
    fovOutIn.remove(0)
  }
  let zoomTexts = zoom.map(@(v) format("%.1fx", v))
  let fovTexts = fovOutIn.map(@(fov) "".concat(round(fov), unitsDeg))
  return {
    zoom = mdash.join(zoomTexts, true)
    fov  = mdash.join(fovTexts,  true)
  }
}

function mkOpticsTexts(infoBlk, modBlk = null) {
  let desc = []
  let sightName = modBlk?.sightName ?? infoBlk?.sightName
  if (sightName)
    desc.append(loc($"sight_model/{sightName}", ""))
  let zoomOutFov = modBlk?.zoomOutFov ?? infoBlk?.zoomOutFov ?? 0
  let zoomInFov = modBlk?.zoomInFov ?? infoBlk?.zoomInFov ?? 0
  let optics = getOpticsParams(zoomOutFov, zoomInFov)
  if (optics.zoom != "")
    desc.append("".concat(loc("optic/zoom"), colon, optics.zoom))
  if (optics.fov != "")
    desc.append("".concat(loc("optic/fov"), colon, optics.fov))
  return desc
}

function mkSensorDesc(partType, params, commonData) {
  let { unitBlk, simUnitType, findAnyModEffectValueBlk } = commonData
  let partName = params.name
  let desc = []
  foreach (sensorBlk in getUnitSensorsList(commonData)) {
    if ((sensorBlk % "dmPart").findindex(@(v) v == partName) == null)
      continue
    let sensorFilePath = sensorBlk.getStr("blk", "")
    if (sensorFilePath == "")
      continue
    let sensorPropsBlk = DataBlock()
    sensorPropsBlk.load(sensorFilePath)
    let sensorType = sensorPropsBlk.getStr("type", "")
    if (sensorType == "radar") {
      desc.append("".concat(loc("xray/model"), colon,
        getPartLocNameByBlkFile("sensors", sensorFilePath, sensorPropsBlk)))
      
      if ([S_SHIP, S_BOAT].contains(simUnitType))
        continue
      desc.extend(mkRadarTexts(commonData, sensorPropsBlk, ""))
    }
  }
  if (partType == "optic_gun" && ![S_SHIP, S_BOAT].contains(simUnitType)) {
    let info = unitBlk?.cockpit
    let cockpitMod = findAnyModEffectValueBlk(commonData, "cockpit")
    if (info?.sightName || cockpitMod?.sightName)
      desc.extend(mkOpticsTexts(info, cockpitMod))
  }
  return { desc }
}

function mkApsSensorDesc(_partType, _params, commonData) {
  let { unitBlk } = commonData
  let desc = []
  let activeProtectionSystemBlk = unitBlk?.ActiveProtectionSystem
  if (activeProtectionSystemBlk)
    desc.extend(mkApsTexts(activeProtectionSystemBlk))
  return { desc }
}

function mkApsLauncherDesc(_partType, params, commonData) {
  let { unitBlk } = commonData
  let partName = params.name
  let desc = []
  let activeProtectionSystemBlk = unitBlk?.ActiveProtectionSystem
  if (activeProtectionSystemBlk) {
    for (local i = 0; i < activeProtectionSystemBlk.blockCount(); i++) {
      let moduleBlk = activeProtectionSystemBlk.getBlock(i)
      if (moduleBlk?.launcherDmPart == partName) {
        desc.extend(mkApsTexts(moduleBlk))
        break
      }
    }
  }
  return { desc }
}


function mkPilotOrHelicopterGunnerDesc(partType, _params, commonData) {
  let { unitBlk, simUnitType, findAnyModEffectValueBlk } = commonData
  let desc = []
  foreach (cfg in [
    { label = "avionics_sight_turret", ccipKey = "haveCCIPForTurret", autoKey = "haveCCRPForTurret"  }
    { label = "avionics_sight_cannon", ccipKey = "haveCCIPForGun",    autoKey = "haveCCRPForGun"     }
    { label = "avionics_sight_rocket", ccipKey = "haveCCIPForRocket", autoKey = "haveCCRPForRocket"  }
    { label = "avionics_sight_bomb",   ccipKey = "haveCCIPForBombs",  ccrpKey = "haveCCRPForBombs"   }
  ]) {
    let haveCcip = unitBlk?[cfg.ccipKey] ?? false
    let haveAuto = unitBlk?[cfg?.autoKey] ?? false
    let haveCcrp = unitBlk?[cfg?.ccrpKey] ?? false
    if (haveCcip || haveAuto || haveCcrp)
      desc.append("".concat(loc(cfg.label), colon,
        comma.join([ haveCcip ? loc("CCIP") : "",
        haveAuto ? loc("sight_AUTO") : "", haveCcrp ? loc("CCRP") : "" ], true)))
  }

  let nightVisionBlk = findAnyModEffectValueBlk(commonData, "nightVision")
  if ((partType == "pilot" && nightVisionBlk?.pilotIr != null)
      || (partType == "gunner" && nightVisionBlk?.gunnerIr != null))
    desc.append(loc("modification/night_vision_system"))

  if ((unitBlk?.haveOpticTurret || simUnitType == S_HELICOPTER) && unitBlk?.gunnerOpticFps != null)
    if (unitBlk?.cockpit.sightOutFov != null || unitBlk?.cockpit.sightInFov != null) {
      let optics = getOpticsParams(unitBlk?.cockpit.sightOutFov ?? 0, unitBlk?.cockpit.sightInFov ?? 0)
      if (optics.zoom != "") {
        let visionModes = comma.join([
          { mode = "tv",   have = nightVisionBlk?.sightIr != null || nightVisionBlk?.sightThermal != null }
          { mode = "lltv", have = nightVisionBlk?.sightIr != null }
          { mode = "flir", have = nightVisionBlk?.sightThermal != null }
        ].map(@(v) v.have ? loc($"avionics_sight_vision/{v.mode}") : ""), true)
        desc.append("".concat(loc("armor_class/optic"), colon, optics.zoom,
          visionModes != "" ? loc("ui/parentheses/space", { text = visionModes }) : ""))
      }
    }

  local autoCmByRwr = false
  local autoCmByMlws = false
  local autoCmFusedSensors = false
  local autoCmMultiProgram = 0

  local threatFlagNames = {}
  let autoCmBlk = unitBlk.getBlockByName("countermeasure")
  if (autoCmBlk != null) {
    for (local b = 0; b < autoCmBlk.blockCount(); b++) {
      let block = autoCmBlk.getBlock(b)
      if (block.getBlockName() == "threatId") {
        for (local p = 0; p < block.paramCount(); ++p)
          if (block.getParamName(p) == "threatFlag") {
            let threatFlagName = block.getParamValue(p)
            if (!threatFlagNames?[threatFlagName])
              threatFlagNames[threatFlagName] <- true
          }
      }
    }
    autoCmFusedSensors = autoCmBlk.getBool("sensorsFusion", false)
    autoCmMultiProgram = countBlocksByName(autoCmBlk, "program")
  }

  foreach (sensorBlk in getUnitSensorsList(commonData)) {
    let sensorFilePath = sensorBlk.getStr("blk", "")
    if (sensorFilePath == "")
      continue
    let sensorPropsBlk = DataBlock()
    sensorPropsBlk.load(sensorFilePath)
    local sensorType = sensorPropsBlk.getStr("type", "")
    if (sensorType == "radar")
      sensorType = getRadarSensorType(sensorPropsBlk)
    else if (sensorType == "lds")
      continue
    desc.append("".concat(loc($"avionics_sensor_{sensorType}"), colon,
      getPartLocNameByBlkFile("sensors", sensorFilePath, sensorPropsBlk)))
    if (sensorType == "rwr") {
      desc.extend(mkRwrTexts(commonData, sensorPropsBlk, "  "))
      if (sensorPropsBlk.getBool("automaticCountermeasures", sensorPropsBlk.getBool("automaticFlares", false)))
        autoCmByRwr = true
      foreach (threatFlagName, _flag in threatFlagNames)
        if (findBlockByNameWithParamValue(sensorPropsBlk, "group", "threatFlag", threatFlagName)) {
          autoCmByRwr = true
          break
        }
    }
    else if (sensorType == "mlws") {
      desc.extend(mkMlwsTexts(commonData, sensorPropsBlk, "  "))
      if (sensorPropsBlk.getBool("automaticCountermeasures", sensorPropsBlk.getBool("automaticFlares", false)))
        autoCmByMlws = true
      foreach (threatFlagName, _flag in threatFlagNames)
        if (findParamValue(sensorPropsBlk, "threatFlag", threatFlagName)) {
          autoCmByMlws = true
          break
        }
    }
  }

  if (unitBlk.getBool("hasHelmetDesignator", false))
    desc.append(loc("avionics_hmd"))
  if (unitBlk.getBool("havePointOfInterestDesignator", false) || simUnitType == S_HELICOPTER)
    desc.append(loc("avionics_aim_spi"))
  if (unitBlk.getBool("laserDesignator", false))
    desc.append(loc("avionics_aim_laser_designator"))

  if (autoCmByRwr || autoCmByMlws) {
    desc.append(loc("avionics_auto_cm"))
    local autoCmSensorsText = "".concat(loc("avionics_auto_cm_sensors"), colon)
    if (autoCmByRwr && autoCmByMlws)
      autoCmSensorsText = "".concat(autoCmSensorsText, loc("avionics_auto_cm_by_rwr"), autoCmFusedSensors ? "+" : ", ", loc("avionics_auto_cm_by_mlws"))
    else if (autoCmByRwr)
      autoCmSensorsText = "".concat(autoCmSensorsText, loc("avionics_auto_cm_by_rwr"))
    else if (autoCmByMlws)
      autoCmSensorsText = "".concat(autoCmSensorsText, loc("avionics_auto_cm_by_mlws"))
    desc.append("".concat("  ", autoCmSensorsText))
    if (autoCmMultiProgram > 0)
      desc.append("".concat("  ", loc("avionics_auto_cm_programs"), colon, autoCmMultiProgram))
  }

  let slots = unitBlk?.WeaponSlots
  if (slots) {
    let commonSlot = (slots % "WeaponSlot")?[0]
    if (commonSlot) {
      let counterMeasures = (commonSlot % "WeaponPreset").findvalue(
        @(v) v?.counterMeasures)?.counterMeasures

      for (local b = 0; b < (counterMeasures?.blockCount() ?? 0); b++) {
        let counterMeasureBlk = counterMeasures.getBlock(b)
        let counterMeasureFilePath = counterMeasureBlk?.blk ?? ""
        if (counterMeasureFilePath == "")
          continue

        let counterMeasurePropsBlk = blkOptFromPath(counterMeasureFilePath)
        let counterMeasureType = counterMeasurePropsBlk?.type ?? ""
        desc.append("".concat(loc($"avionics_countermeasure_{counterMeasureType}"),
          colon,
          getPartLocNameByBlkFile("counterMeasures", counterMeasureFilePath,
            counterMeasurePropsBlk)))
      }
    }
  }
  return { desc }
}

function mkGunnerDesc(partType, params, commonData) {
  let { simUnitType } = commonData
  if (simUnitType == S_AIRCRAFT)
    return { partLocId = "gunner_aircraft" }
  if (simUnitType == S_HELICOPTER)
    return mkPilotOrHelicopterGunnerDesc(partType, params, commonData)
  return mkTankCrewMemberDesc(partType, params, commonData).__update({ partLocId = "gunner_tank" })
}

let mkPilotDesc = mkPilotOrHelicopterGunnerDesc



function mkAvionicsDesc(partType, params, commonData) {
  let { unitBlk } = commonData
  let partName = params.name
  let desc = []
  desc.append(loc($"armor_class/desc/{partType}"))
  let damagePartsToAvionicsPartsMap = unitBlk?.damagePartsToAvionicsPartsMap
  let avionicsParts = damagePartsToAvionicsPartsMap == null ? [] : (damagePartsToAvionicsPartsMap % "avionics")
  let parts = []
  foreach (part in avionicsParts)
    if (part?.health.dm == partName)
      parts.append(loc($"xray/{part.avionics}"))
  desc.append("\n".join(parts, true))
  return { desc }
}

function mkCountermeasureDesc(_partType, params, commonData) {
  let { unitBlk } = commonData
  let partName = params.name
  let desc = []
  let counterMeasuresBlk = unitBlk?.counterMeasures
  if (counterMeasuresBlk) {
    for (local i = 0; i < counterMeasuresBlk.blockCount(); i++) {
      let cmBlk = counterMeasuresBlk.getBlock(i)
      if (cmBlk?.dmPart != partName || (cmBlk?.blk ?? "") == "")
        continue
      let info = DataBlock()
      info.load(cmBlk.blk)

      desc.append("".concat(loc("xray/model"), colon,
        getPartLocNameByBlkFile("counterMeasures", cmBlk.blk, info)))

      foreach (cfg in [
        { label = "xray/ircm_protected_sector/hor",  sectorKey = "azimuthSector",   directionKey = "azimuth"   }
        { label = "xray/ircm_protected_sector/vert", sectorKey = "elevationSector", directionKey = "elevation" }
      ]) {
        let sector = round(info?[cfg.sectorKey] ?? 0.0)
        local direction = round((info?[cfg.directionKey] ?? 0.0) * 2.0) / 2
        if (sector == 0)
          continue
        local comment = ""
        if (direction != 0 && sector < 360) {
          direction %= 360
          if (direction < 0)
            direction += 360
          local angles = [
            direction - sector / 2
            direction + sector / 2
          ].map(function(a) {
            a %= 360
            if (a >= 180)
              a -= 360
            return "".concat(a >= 0 ? "+" : "", a, unitsDeg)
          })
          comment = loc("ui/parentheses/space", { text = "/".join(angles) })
        }
        desc.append("".concat(loc(cfg.label), colon, sector, unitsDeg, comment))
      }
      break
    }
  }
  return { desc }
}

function mkCommanderPanoramicSightDesc(_partType, _params, commonData) {
  let { unitBlk } = commonData
  let desc = []
  if (unitBlk?.commanderView)
    desc.extend(mkOpticsTexts(unitBlk.commanderView))
  return { desc }
}

let getFireControlSystems = @(unitSensorsList, key, node) unitSensorsList
  .filter(@(blk) blk.getBlockName() == "fireDirecting" && (blk % key).findvalue(@(v) v == node) != null)

let getNumFireControlNodes = @(unitSensorsList, mainNode, nodeId)
  getFireControlSystems(unitSensorsList, "dmPartMain", mainNode)
    .map(@(fcBlk) fcBlk % "dmPart")
    .map(@(nodes) nodes.filter(@(node) node.indexof(nodeId) == 0).len())
    .reduce(@(sum, num) sum + num, 0)

function getFireControlTriggerGroups(fcBlk) {
  let res = []
  let groupsBlk = fcBlk?.triggerGroupUse
  if (!groupsBlk)
    return res
  for (local i = 0; i < groupsBlk.paramCount(); ++i)
    if (groupsBlk.getParamValue(i))
      res.append(groupsBlk.getParamName(i))
  return res
}

function getFireControlWeaponNames(unitWeaponsList, fcBlk, getWeaponNameByBlkPath) {
  let triggerGroups = getFireControlTriggerGroups(fcBlk)
  let weapons = unitWeaponsList.filter(@(w) triggerGroups.contains(w?.triggerGroup) && w?.blk)
  return unique(weapons, @(w) w.blk).map(@(w) getWeaponNameByBlkPath(w.blk))
}

function getFireControlAccuracyPercent(fcBlk, shipDistancePrecisionErrorMult) {
  let accuracy = fcBlk?.measureAccuracy
  let multiply = shipDistancePrecisionErrorMult == 0 ? 1 : shipDistancePrecisionErrorMult
  return accuracy
    ? round(accuracy / multiply * 100).tointeger()
    : -1
}

function mkFireDirecirOrRangefinderDesc(_partType, params, commonData) {
  let { getUnitWeaponsList, getWeaponNameByBlkPath, getMul_shipDistancePrecisionError } = commonData
  let partName = params.name
  let desc = []
  let unitSensorsList = getUnitSensorsList(commonData)
  
  let fcBlk = getFireControlSystems(unitSensorsList, "dmPart", partName)?[0]
  if (fcBlk != null) {
    
    let unitWeaponsList = getUnitWeaponsList(commonData)
    let weaponNames = getFireControlWeaponNames(unitWeaponsList, fcBlk, getWeaponNameByBlkPath)
    if (weaponNames.len() != 0) {
      desc.append(loc("xray/fire_control/weapons"))
      desc.extend(weaponNames
        .map(@(n) getWeaponLocName(n, commonData))
        .map(@(n) "".concat(bullet, n)))

      
      let shipDistancePrecisionErrorMul = getMul_shipDistancePrecisionError(commonData)
      let accuracy = getFireControlAccuracyPercent(fcBlk, shipDistancePrecisionErrorMul)
      if (accuracy != -1)
        desc.append("".concat(loc("xray/fire_control/accuracy"), " ", accuracy, unitsPercent))

      
      let lockTime = fcBlk?.targetLockTime
      if (lockTime)
        desc.append("".concat(loc("xray/fire_control/lock_time"), " ", lockTime, unitsSec))

      
      let calcTime = fcBlk?.calcTime
      if (calcTime)
        desc.append("".concat(loc("xray/fire_control/calc_time"), " ", calcTime, unitsSec))
    }
  }
  return { desc }
}

function mkFireControlRoomOrBridgeDesc(_partType, params, commonData) {
  let partName = params.name
  let desc = []
  let unitSensorsList = getUnitSensorsList(commonData)
  let numRangefinders = getNumFireControlNodes(unitSensorsList, partName, "rangefinder")
  let numFireDirectors = getNumFireControlNodes(unitSensorsList, partName, "fire_director")
  if (numRangefinders != 0 || numFireDirectors != 0) {
    desc.append(loc("xray/fire_control/devices"))
    if (numRangefinders > 0)
      desc.append("".concat(bullet, loc("xray/fire_control/num_rangefinders", {n = numRangefinders})))
    if (numFireDirectors > 0)
      desc.append("".concat(bullet, loc("xray/fire_control/num_fire_directors", {n = numFireDirectors})))
  }
  return { desc }
}

function mkFireControlSystemDesc(partType, params, commonData) {
  let { getUnitWeaponsList, findAnyModEffectValueBlk, findModEffectValuesString = @(...) [], unitBlk } = commonData
  let partName = params.name
  let desc = []
  let partsList = []
  let unitWeaponsList = getUnitWeaponsList(commonData)

  foreach (cfg in [
    { key = "stabilizerDmPart", locId = "armor_class/gun_stabilizer" }
    { key = "guidedWeaponControlsDmPart", locId = "armor_class/guided_weapon_controls" }
  ]) {
    foreach (weapon in unitWeaponsList)
      if ((weapon % cfg.key).findindex(@(v) v == partName) != null) {
        partsList.append(loc(cfg.locId))
        break
      }
  }

  foreach (cfg in [
    { key = "verDriveDm", locId = "armor_class/drive_turret_v" }
    { key = "horDriveDm", locId = "armor_class/drive_turret_h" }
    { key = "shootingDmPart", locId = "xray/firing" }
  ]) {
    foreach (weapon in unitWeaponsList) {
      let turretBlk = weapon?.turret
      if (turretBlk != null && (turretBlk % cfg.key).findindex(@(v) v == partName) != null) {
        partsList.append(loc(cfg.locId))
        break
      }
    }
  }

  let rangefinderDmParts = findModEffectValuesString(commonData, "rangefinderDmPart")
  if (rangefinderDmParts.contains(partName))
    partsList.append(loc("modification/laser_rangefinder_lws"))

  let nightVisionBlk = findAnyModEffectValueBlk(commonData, "nightVision")
  let unitNightVisionBlk = unitBlk?.nightVision
  if ((!!nightVisionBlk && (nightVisionBlk % "nightVisionDmPart").contains(partName))
    || (!!unitNightVisionBlk && (unitNightVisionBlk % "nightVisionDmPart").contains(partName)))
      partsList.append(loc("modification/night_vision_system"))

  if (partsList.len())
    desc.append(loc($"armor_class/desc/{partType}", { partsList = "\n".join(partsList) }))
  return { desc }
}

function mkHydraulicsSystemDesc(partType, params, commonData) {
  let { getUnitWeaponsList } = commonData
  let partName = params.name
  let desc = []
  let partsList = []
  let unitWeaponsList = getUnitWeaponsList(commonData)

  foreach (cfg in [
    { key = "stabilizerDmPart", locId = "armor_class/gun_stabilizer" }
  ]) {
    foreach (weapon in unitWeaponsList)
      if (weapon?[cfg.key] == partName) {
        partsList.append(loc(cfg.locId))
        break
      }
  }

  foreach (cfg in [
    { key = "verDriveDm", locId = "armor_class/drive_turret_v" }
    { key = "horDriveDm", locId = "armor_class/drive_turret_h" }
  ]) {
    foreach (weapon in unitWeaponsList) {
      let turretBlk = weapon?.turret
      if (turretBlk != null && (turretBlk % cfg.key).findindex(@(v) v == partName) != null) {
        partsList.append(loc(cfg.locId))
        break
      }
    }
  }

  if (partsList.len())
    desc.append(loc($"armor_class/desc/{partType}", { partsList = "\n".join(partsList) }))
  return { desc }
}

function mkElectronicEquipmentDesc(partType, params, commonData) {
  let partName = params.name
  let desc = []
  let partsList = []
  foreach (sensorBlk in getUnitSensorsList(commonData)) {
    if ((sensorBlk % "dmPart").findindex(@(v) v == partName) == null)
      continue

    let sensorFilePath = sensorBlk.getStr("blk", "")
    if (sensorFilePath == "")
      continue
    let sensorPropsBlk = DataBlock()
    sensorPropsBlk.load(sensorFilePath)
    local sensorType = sensorPropsBlk.getStr("type", "")
    if (sensorType == "radar")
      sensorType = getRadarSensorType(sensorPropsBlk)
    else if (sensorType == "lds")
      continue
    partsList.append("".concat(loc($"avionics_sensor_{sensorType}"), colon,
      getPartLocNameByBlkFile("sensors", sensorFilePath, sensorPropsBlk)))
  }
  desc.append(loc($"armor_class/desc/{partType}", { partsList = "\n".join(partsList, true) }))
  return { desc }
}

function mkPowerSystemDesc(partType, _params, _commonData) {
  let partsList = "\n".concat(
    loc("armor_class/fire_control_system"),
    loc("armor_class/gun_stabilizer"),
    loc("armor_class/radar"))
  return { desc = [ loc($"armor_class/desc/{partType}", { partsList }) ] }
}

let mkSimpleDescByPartType = @(partType, _params, _commonData)
  { desc = [ loc($"armor_class/desc/{partType}") ] }


function mkSupportPlaneDesc(partType, _params, commonData) {
  let weaponInfoData = commonData?.makeWeaponInfoData(commonData.supportPlane)
  let weaponsInfoText = weaponInfoData ? commonData.getWeaponInfoText(commonData.supportPlane, weaponInfoData) : null

  return {
    partLocId = " ".concat(
      loc($"armor_class/{partType}"),
      loc($"{commonData.supportPlane.name}_shop")
    ),
    desc = weaponsInfoText ? [weaponsInfoText] : null
  }
}



return {
  
  S_UNDEFINED
  S_AIRCRAFT
  S_HELICOPTER
  S_TANK
  S_SHIP
  S_BOAT
  S_SUBMARINE

  getPartType
  getPartNameLocText

  
  mkTankCrewMemberDesc
  mkGunnerDesc
  mkPilotDesc
  
  mkEngineDesc
  mkTransmissionDesc
  mkDriveTurretDesc
  mkAircraftFuelTankDesc
  
  compareWeaponFunc
  mkWeaponDesc
  
  mkAmmoDesc
  
  mkTankArmorPartDesc
  mkCoalBunkerDesc
  
  mkSensorDesc
  mkApsSensorDesc
  mkApsLauncherDesc
  
  mkAvionicsDesc
  mkCountermeasureDesc
  mkCommanderPanoramicSightDesc
  mkFireDirecirOrRangefinderDesc
  mkFireControlRoomOrBridgeDesc
  mkFireControlSystemDesc
  mkHydraulicsSystemDesc
  mkElectronicEquipmentDesc
  mkPowerSystemDesc
  mkSimpleDescByPartType
  mkSupportPlaneDesc
  getInfoBlk
}
