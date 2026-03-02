from "%scripts/dagui_library.nut" import *

let { abs, sin, PI } = require("math")
let { format } = require("string")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getFullUnitBlk } = require("%scripts/unit/unitParams.nut")
let { blkOptFromPath } = require("%sqstd/datablock.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { get_modifications_blk } = require("blkGetters")
let { getBulletsList, getLastFakeBulletsIndex } = require("%scripts/weaponry/bulletsInfo.nut")
let { getPartType, getRadarSensorType, getPartLocNameByBlkFile, findBlockByNameWithParamValue,
  mkRwrTexts, mkMlwsTexts, findParamValue, getUnitSensorsList } = require("%globalScripts/modeXrayLib.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { xrayCommonGetters } = require("%scripts/dmViewer/modeXrayUtils.nut")

let notWaterVehicle = [ES_UNIT_TYPE_TANK, ES_UNIT_TYPE_AIRCRAFT, ES_UNIT_TYPE_HELICOPTER]
let airVehicle = [ES_UNIT_TYPE_AIRCRAFT, ES_UNIT_TYPE_HELICOPTER]
let importantEffects = ["enableNightVision", "diggingAvailable", "rangefinderMounted"]
let fireDirectingPartTypes = ["fire_director", "fire_control_room", "rangefinder"]

let newLine = "\n"

let unitDataCache = {}
let unitSystemsCache = {}

function addOnceUnitModification(unitName, modName, modNameLocKey = null) {
  if (unitSystemsCache[unitName].findindex(@(v) v.params == modName) != null)
    return

  unitSystemsCache[unitName].append({ name = $"modification/{modNameLocKey ?? modName}", ttype = "MODIFICATION", params = modName })
}

function findUnitSystemsByEffectName(unitName, modName, modData) {
  importantEffects.each(function(effectName) {
    if (modData?.effects[effectName] == true)
      addOnceUnitModification(unitName, modName)
  })
}

function findUnitSystemsLWS(unitName, modName, modData) {
  let sensors = modData?.effects.sensors
  if (sensors == null)
    return

  foreach (sensor in sensors % "sensor") {
    let sensorBlk = blkOptFromPath(sensor?.blk)
    let sensorType = sensorBlk?.type ?? ""
    if (sensorType != "lws")
      return
    addOnceUnitModification(unitName, modName)
  }
}

function findUnitSystemsESS(unitName, modName, modData) {
  let smokeScreenCount = modData?.effects.smokeScreenCount ?? 0
  if (smokeScreenCount == 0)
    return

  addOnceUnitModification(unitName, modName)
}

function findUnitSystemsInMods(unit) {
  let modifications = get_modifications_blk().modifications

  unit.modifications.each(function(mod) {
    let modData = modifications?[mod.name]
    if (modData == null)
      return

    findUnitSystemsByEffectName(unit.name, mod.name, modData)
    findUnitSystemsLWS(unit.name, mod.name, modData)
    findUnitSystemsESS(unit.name, mod.name, modData)
  })
}

function findUnitSystemsSmokeGrenades(unit) {
  for (local groupIndex = 0; groupIndex < getLastFakeBulletsIndex(unit); groupIndex++) {
    let bulletsList = getBulletsList(unit.name, groupIndex, { needCheckUnitPurchase = false, needOnlyAvailable = false })
    if (bulletsList.values.len() == 0 || bulletsList.duplicate)
      continue

    if (bulletsList.weaponType == "smoke") {
      let modName = bulletsList.values[0]
      addOnceUnitModification(unit.name, modName, "tank_smoke_screen_system_mod")
      return
    }
  }
}

function findUnitSystemsInSensors(unit, unitType) {
  let unitBlk = getFullUnitBlk(unit.name)
  let sensors = unitBlk?.sensors
  if (sensors == null)
    return

  foreach (sensor in sensors % "sensor") {
    let sensorBlk = blkOptFromPath(sensor?.blk)
    let sensorType = sensorBlk?.type ?? ""
    let sensorName = sensorBlk?.name ?? ""
    if (sensorType == "radar" && sensorName == "Auto tracker")
      unitSystemsCache[unit.name].append({ name = "info/att", ttype = "UNIT_SIMPLE_TOOLTIP",
        params = { unitId = unit.name, value = "att" } })

    foreach (dmPart in sensor % "dmPart") {
      if (dmPart.contains("antenna_target_location")) {
        local sens = unitSystemsCache[unit.name].findvalue(@(v) v?.sensorName == sensorName)
        if (sens == null) {
          sens = {
            name = "armor_class/antenna_target_location"
            ttype = "UNIT_DM_TOOLTIP"
            sensorName
            params = { unitId = unit.name, dmPart }
            count = 1
          }
          unitSystemsCache[unit.name].append(sens)
        }
        else
          sens.count++
      }
      else if (dmPart.contains("antenna_target_tagging")) {
        local sens = unitSystemsCache[unit.name].findvalue(@(v) v?.sensorName == sensorName)
        if (sens == null) {
          sens = {
            name = "armor_class/antenna_target_tagging"
            ttype = "UNIT_DM_TOOLTIP"
            sensorName
            params = { unitId = unit.name, dmPart }
            count = 1
          }
          unitSystemsCache[unit.name].append(sens)
        }
        else
          sens.count++
      }
    }
  }

  if (notWaterVehicle.contains(unitType))
    return

  let parts = []
  foreach (fireDirecting in sensors % "fireDirecting") {
    local partName = getPartType(fireDirecting.dmPartMain, null)
    local part = parts.findvalue(@(v) v.name == partName)
    if (part != null)
      part.count++
    else
      parts.append({ name = partName, dmPart = fireDirecting.dmPartMain, count = 1 })

    foreach (dmPartName in fireDirecting % "dmPart") {
      partName = getPartType(dmPartName, null)
      part = parts.findvalue(@(v) v.name == partName)
      if (part != null)
        part.count++
      else
        parts.append({ name = partName, dmPart = dmPartName, count = 1 })
    }
  }
  parts.each(function(value) {
    if (!fireDirectingPartTypes.contains(value.name))
      return
    let system = value.__merge({
      ttype = "UNIT_DM_TOOLTIP"
      params = { unitId = unit.name, dmPart = value.dmPart }
      name = $"armor_class/{value.name}"
    })
    unitSystemsCache[unit.name].append(system)
  })
}

function findNightVisionBlk(unitBlk) {
  for (local b = 0; b < (unitBlk?.modifications.blockCount() ?? 0); b++) {
    let modBlk = unitBlk.modifications.getBlock(b)
    let value = modBlk?.effects["nightVision"]
    if (value != null)
      return {
        blk = value
        modName = modBlk.getBlockName()
      }
  }
  return null
}

function getOpticsParams(zoomOutFov, zoomInFov) {
  let fovToZoom = @(fov) sin(2 * PI / 9) / sin(fov / 2 * PI / 180)
  let zoom = [zoomOutFov, zoomInFov]
    .filter(@(fov) fov > 0)
    .map(@(fov) fovToZoom(fov))
  if (zoom.len() == 2 && abs(zoom[0] - zoom[1]) < 0.1) {
    zoom.remove(0)
  }
  let zoomTexts = zoom.map(@(v) format("%.1fx", v))
  return loc("ui/mdash").join(zoomTexts, true)
}

function findAirSystems(unit, unitBlk, unitType) {
  if (unitBlk?.hasHelmetDesignator ?? false)
    unitSystemsCache[unit.name].append({ name = "radar_hms_mode", ttype = "UNIT_SIMPLE_TOOLTIP",
      params = { unitId = unit.name, textLoc = "radar_hms_mode/desc" } })
  if ((unitBlk?.havePointOfInterestDesignator ?? false) || unitType == ES_UNIT_TYPE_HELICOPTER)
    unitSystemsCache[unit.name].append({ name = "avionics_aim_spi", ttype = "UNIT_SIMPLE_TOOLTIP",
      params = { unitId = unit.name, textLoc = "avionics_aim_spi/desc" } })
  if (unitBlk?.laserDesignator ?? false)
    unitSystemsCache[unit.name].append({ name = "avionics_aim_laser_designator", ttype = "UNIT_SIMPLE_TOOLTIP",
      params = { unitId = unit.name, textLoc = "avionics_aim_laser_designator/desc" } })

  let sighting = [
    { keyPart = "Turret", locPart = "turret"},
    { keyPart = "Gun", locPart = "cannon"},
    { keyPart = "Rocket", locPart = "rocket"},
    { keyPart = "Bombs", locPart = "bomb"}
  ]

  sighting.each(function(s) {
    let res = []
    let tooltipParts = []
    if (unitBlk?[$"haveCCIPFor{s.keyPart}"] ?? false) {
      res.append("CCIP")
      tooltipParts.append("CCIP/desc")
    }
    if (unitBlk?[$"haveCCRPFor{s.keyPart}"] ?? false) {
      res.append("sight_AUTO")
      tooltipParts.append("sight_AUTO/desc")
    }
    if (res.len() > 0) {
      let text = $"{loc($"avionics_sight_{s.locPart}")}{loc("ui/colon")} {", ".join(res.map(@(v) loc(v)))}"
      let tooltipText = newLine.join(tooltipParts.map(@(v) loc(v)))
      unitSystemsCache[unit.name].append({ name = text, ttype = "UNIT_SIMPLE_TOOLTIP",
        params = { unitId = unit.name, text = tooltipText } })
    }
  })

  let { blk = null, modName = null } = findNightVisionBlk(unitBlk)
  if (blk?.pilotIr != null || blk?.gunnerIr != null) {
    addOnceUnitModification(unit.name, modName)
  }

  if (unitBlk?.cockpit.sightInFov != null || unitBlk?.cockpit.sightOutFov != null) {
    let sightInFov = unitBlk?.cockpit.sightInFov ?? 0
    let sightOutFov = unitBlk?.cockpit.sightOutFov ?? 0
    let zoom = getOpticsParams(sightOutFov, sightInFov)

    if (zoom != "") {
      let visionModes = loc("ui/comma").join([
        { mode = "tv",   have = blk?.sightIr != null || blk?.sightThermal != null }
        { mode = "lltv", have = blk?.sightIr != null }
        { mode = "flir", have = blk?.sightThermal != null }
      ].map(@(v) v.have ? loc($"avionics_sight_vision/{v.mode}") : ""), true)

      let desc = "".concat(loc("armor_class/optic"), loc("ui/colon"), zoom,
        visionModes != "" ? loc("ui/parentheses/space", { text = visionModes }) : "")

      unitSystemsCache[unit.name].append({ name = desc, ttype = "UNIT_SIMPLE_TOOLTIP",
        params = { unitId = unit.name, text = desc } })
    }
  }

  let commonData = {
    unitDataCache = unitDataCache[unit.name]
    unitBlk
    unitName = unit.name
    isDebugBatchExportProcess = false
  }.__update(xrayCommonGetters)

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
    autoCmMultiProgram = (autoCmBlk % "program").len()
  }

  foreach (sensorBlk in getUnitSensorsList(commonData)) {
    let sensorFilePath = sensorBlk?.blk ?? ""
    if (sensorFilePath == "")
      continue
    let sensorPropsBlk = blkOptFromPath(sensorFilePath)
    local sensorType = sensorPropsBlk?.type ?? ""
    let sensorName = sensorPropsBlk?.name ?? ""

    if (sensorType == "radar" && sensorName != "Auto tracker" && sensorBlk?.dmPart != null)
      unitSystemsCache[unit.name].append({
        name = "armor_class/radar"
        ttype = "UNIT_DM_TOOLTIP"
        sensorName
        count = 1
        params = { unitId = unit.name, dmPart = sensorBlk.dmPart }
      })

    else if (sensorType == "lws")
      unitSystemsCache[unit.name].append({ name = "avionics_sensor_lws", ttype = "UNIT_SIMPLE_TOOLTIP",
        params = { unitId = unit.name, text = sensorName } })

    else if (sensorType == "radar")
      sensorType = getRadarSensorType(sensorPropsBlk)

    if (sensorType == "lds" || sensorType == "radar")
      continue

    else if (sensorType == "irst") {
      unitSystemsCache[unit.name].append({ name = $"avionics_sensor_{sensorType}", ttype = "UNIT_SIMPLE_TOOLTIP",
          params = { unitId = unit.name, text = getPartLocNameByBlkFile("sensors", sensorFilePath, sensorPropsBlk) } })
    }
    else if (sensorType == "rwr") {
      let desc = [getPartLocNameByBlkFile("sensors", sensorFilePath, sensorPropsBlk)]
      desc.extend(mkRwrTexts(commonData, sensorPropsBlk, "  "))
      unitSystemsCache[unit.name].append({ name = $"avionics_sensor_{sensorType}", ttype = "UNIT_SIMPLE_TOOLTIP",
        params = { unitId = unit.name, text = newLine.join(desc) } })

      if (sensorPropsBlk.getBool("automaticCountermeasures", sensorPropsBlk.getBool("automaticFlares", false)))
        autoCmByRwr = true
      foreach (threatFlagName, _flag in threatFlagNames)
        if (findBlockByNameWithParamValue(sensorPropsBlk, "group", "threatFlag", threatFlagName)) {
          autoCmByRwr = true
          break
        }
    }
    else if (sensorType == "mlws") {
      let desc = [getPartLocNameByBlkFile("sensors", sensorFilePath, sensorPropsBlk)]
      desc.extend(mkMlwsTexts(commonData, sensorPropsBlk, "  "))
      unitSystemsCache[unit.name].append({ name = $"avionics_sensor_{sensorType}", ttype = "UNIT_SIMPLE_TOOLTIP",
        params = { unitId = unit.name, text = newLine.join(desc) } })

      if (sensorPropsBlk.getBool("automaticCountermeasures", sensorPropsBlk.getBool("automaticFlares", false)))
        autoCmByMlws = true
      foreach (threatFlagName, _flag in threatFlagNames)
        if (findParamValue(sensorPropsBlk, "threatFlag", threatFlagName)) {
          autoCmByMlws = true
          break
        }
    }
  }

  if (autoCmByRwr || autoCmByMlws) {
    local autoCmSensorsText = "".concat(loc("avionics_auto_cm_sensors"), loc("ui/colon"))
    if (autoCmByRwr && autoCmByMlws)
      autoCmSensorsText = "".concat(autoCmSensorsText, loc("avionics_auto_cm_by_rwr"), autoCmFusedSensors ? "+" : ", ", loc("avionics_auto_cm_by_mlws"))
    else if (autoCmByRwr)
      autoCmSensorsText = "".concat(autoCmSensorsText, loc("avionics_auto_cm_by_rwr"))
    else if (autoCmByMlws)
      autoCmSensorsText = "".concat(autoCmSensorsText, loc("avionics_auto_cm_by_mlws"))
    let desc = [autoCmSensorsText]
    if (autoCmMultiProgram > 0)
      desc.append("".concat(loc("avionics_auto_cm_programs"), loc("ui/colon"), autoCmMultiProgram))

    unitSystemsCache[unit.name].append({ name = "avionics_auto_cm", ttype = "UNIT_SIMPLE_TOOLTIP",
      params = { unitId = unit.name, text = newLine.join(desc) } })
  }

  let modifications = get_modifications_blk().modifications

  unit.modifications.each(function(mod) {
    let modData = modifications?[mod.name]
    if (modData == null)
      return

    if (["air_extinguisher", "automatic_air_extinguisher"].contains(mod.name))
      addOnceUnitModification(unit.name, mod.name)

    if (modData?.effects.enginesInfraRedBrightnessMult != null)
      addOnceUnitModification(unit.name, mod.name)
  })
}

function getUnitSystems(unitName, unitType) {
  if (unitName in unitSystemsCache)
    return unitSystemsCache[unitName]

  unitSystemsCache[unitName] <- []
  unitDataCache[unitName] <- {}

  let unit = getAircraftByName(unitName)
  if (!airVehicle.contains(unitType)) {
    findUnitSystemsInMods(unit)
    findUnitSystemsSmokeGrenades(unit)
    findUnitSystemsInSensors(unit, unitType)
  }
  else {
    let unitBlk = getFullUnitBlk(unitName)
    findAirSystems(unit, unitBlk, unitType)
  }

  return unitSystemsCache[unitName]
}

function hasUnitSystems(unitName, unitType) {
  return getUnitSystems(unitName, unitType).len() > 0
}

function getUnitSystemsMarkup(unitName, unitType) {
  let systems = getUnitSystems(unitName, unitType).map(function(data, idx, arr) {
    let { name, ttype = null, params = null, count = 1 } = data
    let isNotLastItem = idx != arr.len() - 1
    let itemName = count == 1 ? loc(name) : $"{loc(name)} - {count} {loc("measureUnits/pcs")}"
    return {
      itemName = isNotLastItem ? $"{itemName}, " : itemName
      tooltipId = getTooltipType(ttype).getTooltipId(unitName, params)
    }
  })
  return handyman.renderCached("%gui/unitInfo/unitSystems.tpl", { items = systems, isTooltipByHold = showConsoleButtons.get() })
}

addListenersWithoutEnv({
  GameLocalizationChanged = @(_) unitSystemsCache.clear()
})

return {
  hasUnitSystems
  getUnitSystemsMarkup
}
