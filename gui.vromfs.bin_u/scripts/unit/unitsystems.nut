from "%scripts/dagui_library.nut" import *

let { getFullUnitBlk } = require("%scripts/unit/unitParams.nut")
let { blkOptFromPath } = require("%sqstd/datablock.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { get_modifications_blk } = require("blkGetters")
let { getBulletsList, getLastFakeBulletsIndex } = require("%scripts/weaponry/bulletsInfo.nut")
let { getPartType } = require("%globalScripts/modeXrayLib.nut")

let notWaterVehicle = [ES_UNIT_TYPE_TANK, ES_UNIT_TYPE_AIRCRAFT, ES_UNIT_TYPE_HELICOPTER]
let importantEffects = ["enableNightVision", "diggingAvailable", "rangefinderMounted"]
let fireDirectingPartTypes = ["fire_director", "fire_control_room", "rangefinder"]

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

function findUnitSystemsATTAndRadar(unit, unitType) {
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

function getUnitSystems(unitName, unitType) {
  if (unitName in unitSystemsCache)
    return unitSystemsCache[unitName]

  unitSystemsCache[unitName] <- []

  let unit = getAircraftByName(unitName)
  findUnitSystemsInMods(unit)
  findUnitSystemsSmokeGrenades(unit)
  findUnitSystemsATTAndRadar(unit, unitType)
  return unitSystemsCache[unitName]
}

function hasUnitSystems(unitName, unitType) {
  return getUnitSystems(unitName, unitType).len() > 0
}

function getUnitSystemsMarkup(unitName, unitType) {
  let systems = getUnitSystems(unitName, unitType).map(function(data) {
    let { name, ttype = null, params = null, count = 1 } = data
    return {
      itemName = count == 1 ? loc(name) : $"{loc(name)} - {count} {loc("measureUnits/pcs")}"
      tooltipId = getTooltipType(ttype).getTooltipId(unitName, params)
    }
  })
  return handyman.renderCached("%gui/unitInfo/unitSystems.tpl", { items = systems })
}

return {
  hasUnitSystems
  getUnitSystemsMarkup
}
