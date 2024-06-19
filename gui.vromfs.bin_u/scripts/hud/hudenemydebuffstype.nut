from "%scripts/dagui_library.nut" import *

let u = require("%sqStdLibs/helpers/u.nut")
let { enumsGetCachedType, enumsAddTypes } = require("%sqStdLibs/helpers/enums.nut")
let { lerp } = require("%sqstd/math.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { measureType } = require("%scripts/measureType.nut")
let { format } =  require("string")

enum PART_STATE {
  OFF      = "off"
  HEALTHY  = "healthy"
  GOOD     = "good"
  CRITICAL = "critical"
  KILLED   = "killed"
}

let g_hud_enemy_debuffs = {
  types = []
  cache = {
    byId = {}
  }
}

// ----------------------------------------------------------------------------------------------

let getStateByBrokenDmAny = function(unitInfo, partName, partsArray) {
  if (unitInfo.isKilled)
    return PART_STATE.KILLED
  if (partName && isInArray(partName, partsArray))
    return PART_STATE.KILLED
  foreach (partId in partsArray) {
    let dmParts = unitInfo.parts?[partId].dmParts ?? {}
    foreach (dmPart in dmParts)
      if (dmPart._hp == 0)
        return PART_STATE.KILLED
  }
  return PART_STATE.OFF
}

let getStateByBrokenDmMain = function(unitInfo, partName, partsArray, mainDmArray) {
  if (unitInfo.isKilled)
    return PART_STATE.KILLED
  if (partName && !isInArray(partName, partsArray))
    return PART_STATE.OFF
  foreach (partId in partsArray) {
    let dmParts = unitInfo.parts?[partId].dmParts ?? {}
    let isSingleDm = dmParts.len() == 1
    let mainDms = isSingleDm ? [] : mainDmArray
    foreach (dmPart in dmParts)
      if ((isSingleDm || isInArray(dmPart.partDmName, mainDms)) && dmPart._hp == 0)
        return PART_STATE.KILLED
  }
  return PART_STATE.OFF
}

let countPartsAlive = function(partsArray, partsCfg) {
  local count = 0
  foreach (partId in partsArray) {
    let dmParts = partsCfg?[partId].dmParts ?? {}
    foreach (dmPart in dmParts)
      if (dmPart._hp > 0)
        count++
  }
  return count
}

let countPartsTotal = function(partsArray, partsCfg) {
  local count = 0
  foreach (partId in partsArray)
    count += (partsCfg?[partId].dmParts ?? {}).len()
  return count
}

let getPercentValueByCounts = function(alive, total, aliveMin) {
  return clamp(lerp(aliveMin - 1, total, 0.0, 1.0, alive), 0.0, 1.0)
}

let getStateByValue = function(cur, vMax, crit, vMin) {
  return cur < vMin ? PART_STATE.KILLED
       : cur < crit ? PART_STATE.CRITICAL
       : cur < vMax ? PART_STATE.GOOD
       :              PART_STATE.HEALTHY
}

let getTurretDriveParts = function() {
  local parts = ["drive_turret_h_dm", "drive_turret_v_dm"]
  foreach (i in [1, 2, 3, 4, 5]) {
    foreach (c in ['h', 'v'])
      parts.append(format("drive_turret_%c_0%d_dm", c, i))
  }
  return parts
}

// ----------------------------------------------------------------------------------------------

g_hud_enemy_debuffs.template <- {
  id = "" // filled by type name
  unitTypesMask = 0
  parts         = []
  isUpdateByEnemyDamageState = false
  getInfo = @(_camInfo, _unitInfo, _partName = null, _dmgParams = null) null
}

enumsAddTypes(g_hud_enemy_debuffs, {
  UNKNOWN = {
  }

  TANK_ENGINE = {
    unitTypesMask = unitTypes.TANK.bit
    parts    = [ "tank_engine", "tank_transmission" ]
    getInfo  = @(_camInfo, unitInfo, partName = null, _dmgParams = null) {
      state = getStateByBrokenDmAny(unitInfo, partName, this.parts)
      label = ""
    }
   }

  TANK_GUN = {
    unitTypesMask = unitTypes.TANK.bit
    parts    = [ "tank_gun_barrel", "tank_cannon_breech" ]
    mainDm   = [ "gun_barrel_dm", "gun_barrel_01_dm", "cannon_breech_dm", "cannon_breech_01_dm" ]
    getInfo  = @(_camInfo, unitInfo, partName = null, _dmgParams = null) {
      state = getStateByBrokenDmMain(unitInfo, partName, this.parts, this.mainDm)
      label = ""
    }
  }

  TANK_DRIVE_TURRET = {
    unitTypesMask = unitTypes.TANK.bit
    parts    = [ "tank_drive_turret_h", "tank_drive_turret_v" ]
    mainDm   = getTurretDriveParts()
    getInfo  = @(_camInfo, unitInfo, partName = null, _dmgParams = null) {
      state = getStateByBrokenDmMain(unitInfo, partName, this.parts, this.mainDm)
      label = ""
    }
  }

  TANK_TRACKS = {
    unitTypesMask = unitTypes.TANK.bit
    parts    = [ "tank_track" ]
    getInfo  = @(_camInfo, unitInfo, partName = null, _dmgParams = null) {
      state = getStateByBrokenDmAny(unitInfo, partName, this.parts)
      label = ""
    }
  }

  TANK_CREW = {
    unitTypesMask = unitTypes.TANK.bit
    isUpdateByEnemyDamageState = true
    getInfo = function(camInfo, unitInfo, _partName = null, dmgParams = null) {
      let total = dmgParams?.crewTotalCount ?? camInfo?.crewTotal ?? 0
      if (!total)
        return null
      let alive = dmgParams?.crewAliveCount ?? camInfo?.crewAlive ?? 0
      let aliveMin = dmgParams?.crewAliveMin ?? camInfo?.crewAliveMin ?? 0
      let isKill = unitInfo.isKilled
      local totalText = "".concat(loc("ui/slash"), total)
      if (!isKill)
        totalText = colorize("hitCamFadedColor", totalText)

      return {
        state = isKill ? PART_STATE.KILLED : getStateByValue(alive, total, aliveMin + 1, aliveMin)
        label = $"{alive}{totalText}"
      }
    }
  }

  SHIP_BUOYANCY = {
    unitTypesMask = unitTypes.SHIP.bit | unitTypes.BOAT.bit
    isUpdateByEnemyDamageState = true
    getInfo = function(camInfo, _unitInfo, _partName = null, dmgParams = null) {
      let value = dmgParams?.buoyancy ?? camInfo?.buoyancy
      if (value == null)
        return null
      if (value > 0.995)
        return null
      return {
        state = getStateByValue(value, 0.995, 0.505, 0.005)
        label = measureType.PERCENT_FLOAT.getMeasureUnitsText(value)
      }
    }
  }

  SHIP_COMPARTMENTS = {
    unitTypesMask = unitTypes.SHIP.bit | unitTypes.BOAT.bit
    parts = [ "ship_compartment" ]
    getInfo = function(camInfo, unitInfo, _partName = null, dmgParams = null) {
      let total = getTblValue("compartmentsTotal", camInfo, 0)
      if (!total)
        return null
      let canUpdateFromParts = dmgParams != null && countPartsTotal(this.parts, unitInfo.parts) == total
      let alive = canUpdateFromParts ? countPartsAlive(this.parts, unitInfo.parts)
        : getTblValue("compartmentsAlive", camInfo, 0)
      let aliveMin = getTblValue("compartmentsAliveMin", camInfo, 0)
      if (aliveMin > total)
        return null

      let value = getPercentValueByCounts(alive, total, aliveMin)
      return {
        state = getStateByValue(alive, total, aliveMin + 1, aliveMin)
        label = measureType.PERCENT_FLOAT.getMeasureUnitsText(value)
      }
    }
  }

  SHIP_CREW = {
    unitTypesMask = unitTypes.SHIP.bit | unitTypes.BOAT.bit
    isUpdateByEnemyDamageState = true
    needShowChange = true
    getInfo = function(camInfo, unitInfo, _partName = null, dmgParams = null) {
      let total = dmgParams?.crewTotalCount ?? camInfo?.crewTotal ?? 0
      if (!total)
        return null
      let alive = dmgParams?.crewAliveCount ?? camInfo?.crewAlive ?? 0
      let minCrewCount = dmgParams?.crewAliveMin ?? camInfo?.crewAliveMin ?? 0
      let bestMinCrewCount = camInfo?.bestMinCrewCount ?? minCrewCount
      if (!alive && !unitInfo.isKilled)
        return null

      let maxCrewLeftPercent = 1.0 + (bestMinCrewCount.tofloat() - minCrewCount) / total
      let minPercent = alive >= minCrewCount ? 0.01 : 0
      let percent = clamp(lerp(minCrewCount - 1, total, 0, maxCrewLeftPercent, alive), minPercent, 1)
      return {
        state = getStateByValue(alive, total, minCrewCount + 1, minCrewCount)
        value = percent * 100
        label = measureType.PERCENT_FLOAT.getMeasureUnitsText(percent)
      }
    }
  }
}, null, "id")

g_hud_enemy_debuffs.getTypeById <- function getTypeById(id) {
  return enumsGetCachedType("id", id, this.cache.byId, this, this.UNKNOWN)
}

g_hud_enemy_debuffs.getTypesArrayByUnitType <- function getTypesArrayByUnitType(unitType) {
  let unitTypeBit = unitTypes.getByEsUnitType(unitType).bit
  let list = []
  foreach (item in this.types)
    if (unitTypeBit & item.unitTypesMask)
      list.append(item)
  return list
}

g_hud_enemy_debuffs.getTrackedPartNamesByUnitType <- function getTrackedPartNamesByUnitType(unitType) {
  let unitTypeBit = unitTypes.getByEsUnitType(unitType).bit
  let list = []
  foreach (item in this.types)
    if (unitTypeBit & item.unitTypesMask)
      foreach (partName in item.parts)
        u.appendOnce(partName, list)
  return list
}

return {
  g_hud_enemy_debuffs
}