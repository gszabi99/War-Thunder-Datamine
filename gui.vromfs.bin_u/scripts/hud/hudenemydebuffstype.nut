local enums = require("sqStdlibs/helpers/enums.nut")
local stdMath = require("std/math.nut")
local unitTypes = require("scripts/unit/unitTypesList.nut")

enum PART_STATE
{
  OFF      = "off"
  HEALTHY  = "healthy"
  GOOD     = "good"
  CRITICAL = "critical"
  KILLED   = "killed"
}

::g_hud_enemy_debuffs <- {
  types = []
  cache = {
    byId = {}
  }
}

// ----------------------------------------------------------------------------------------------

local getStateByBrokenDmAny = function(unitInfo, partName, partsArray)
{
  if (unitInfo.isKilled)
    return PART_STATE.KILLED
  if (partName && ::isInArray(partName, partsArray))
    return PART_STATE.KILLED
  foreach (partId in partsArray)
  {
    local dmParts = unitInfo.parts?[partId].dmParts ?? {}
    foreach (dmPart in dmParts)
      if (dmPart._hp == 0)
        return PART_STATE.KILLED
  }
  return PART_STATE.OFF
}

local getStateByBrokenDmMain = function(unitInfo, partName, partsArray, mainDmArray)
{
  if (unitInfo.isKilled)
    return PART_STATE.KILLED
  if (partName && !::isInArray(partName, partsArray))
    return PART_STATE.OFF
  foreach (partId in partsArray)
  {
    local dmParts = unitInfo.parts?[partId].dmParts ?? {}
    local isSingleDm = dmParts.len() == 1
    local mainDms = isSingleDm ? [] : mainDmArray
    foreach (dmPart in dmParts)
      if ((isSingleDm || ::isInArray(dmPart.partDmName, mainDms)) && dmPart._hp == 0)
        return PART_STATE.KILLED
  }
  return PART_STATE.OFF
}

local countPartsAlive = function(partsArray, partsCfg)
{
  local count = 0
  foreach (partId in partsArray)
  {
    local dmParts = partsCfg?[partId].dmParts ?? {}
    foreach (dmPart in dmParts)
      if (dmPart._hp > 0)
        count++
  }
  return count
}

local countPartsTotal = function(partsArray, partsCfg)
{
  local count = 0
  foreach (partId in partsArray)
    count += (partsCfg?[partId].dmParts ?? {}).len()
  return count
}

local getPercentValueByCounts = function(alive, total, aliveMin)
{
  return ::clamp(stdMath.lerp(aliveMin - 1, total, 0.0, 1.0, alive), 0.0, 1.0)
}

local getStateByValue = function(cur, vMax, crit, vMin)
{
  return cur < vMin ? PART_STATE.KILLED
       : cur < crit ? PART_STATE.CRITICAL
       : cur < vMax ? PART_STATE.GOOD
       :              PART_STATE.HEALTHY
}

// ----------------------------------------------------------------------------------------------

::g_hud_enemy_debuffs.template <- {
  id = "" // filled by type name
  unitTypesMask = 0
  parts         = []
  isUpdateOnKnownPartKillsOnly = true
  getInfo = @(camInfo, unitInfo, partName = null, dmgParams = null) null
}

enums.addTypesByGlobalName("g_hud_enemy_debuffs", {
  UNKNOWN = {
  }

  TANK_ENGINE = {
    unitTypesMask = unitTypes.TANK.bit
    parts    = [ "tank_engine", "tank_transmission" ]
    getInfo  = @(camInfo, unitInfo, partName = null, dmgParams = null) {
      state = getStateByBrokenDmAny(unitInfo, partName, parts)
      label = ""
    }
   }

  TANK_GUN = {
    unitTypesMask = unitTypes.TANK.bit
    parts    = [ "tank_gun_barrel", "tank_cannon_breech" ]
    mainDm   = [ "gun_barrel_dm", "gun_barrel_01_dm", "cannon_breech_dm", "cannon_breech_01_dm" ]
    getInfo  = @(camInfo, unitInfo, partName = null, dmgParams = null) {
      state = getStateByBrokenDmMain(unitInfo, partName, parts, mainDm)
      label = ""
    }
  }

  TANK_DRIVE_TURRET = {
    unitTypesMask = unitTypes.TANK.bit
    parts    = [ "tank_drive_turret_h", "tank_drive_turret_v" ]
    mainDm   = [ "drive_turret_h_dm", "drive_turret_h_01_dm", "drive_turret_v_dm", "drive_turret_v_01_dm" ]
    getInfo  = @(camInfo, unitInfo, partName = null, dmgParams = null) {
      state = getStateByBrokenDmMain(unitInfo, partName, parts, mainDm)
      label = ""
    }
  }

  TANK_TRACKS = {
    unitTypesMask = unitTypes.TANK.bit
    parts    = [ "tank_track" ]
    getInfo  = @(camInfo, unitInfo, partName = null, dmgParams = null) {
      state = getStateByBrokenDmAny(unitInfo, partName, parts)
      label = ""
    }
  }

  TANK_CREW = {
    unitTypesMask = unitTypes.TANK.bit
    parts    = [ "tank_commander", "tank_driver", "tank_gunner", "tank_loader", "tank_machine_gunner" ]
    getInfo = function(camInfo, unitInfo, partName = null, dmgParams = null)
    {
      local total = ::getTblValue("crewTotal", camInfo, 0)
      if (!total)
        return null
      local alive = dmgParams ? ::getTblValue("crewAliveCount", dmgParams, 0)
        : ::getTblValue("crewAlive", camInfo, 0)
      local aliveMin = ::getTblValue("crewAliveMin", camInfo, 0)

      local isKill = unitInfo.isKilled
      local totalText = ::loc("ui/slash") + total
      if (!isKill)
        totalText = ::colorize("hitCamFadedColor", totalText)

      return {
        state = isKill ? PART_STATE.KILLED : getStateByValue(alive, total, aliveMin + 1, aliveMin)
        label = alive + totalText
      }
    }
  }

  SHIP_BUOYANCY = {
    unitTypesMask = unitTypes.SHIP.bit
    getInfo = function(camInfo, unitInfo, partName = null, dmgParams = null)
    {
      local value = ::getTblValue("buoyancy", camInfo)
      if (value == null)
        return null
      if (value > 0.995)
        return null
      return {
        state = getStateByValue(value, 0.995, 0.505, 0.005)
        label = ::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText(value)
      }
    }
  }

  SHIP_COMPARTMENTS = {
    unitTypesMask = unitTypes.SHIP.bit
    parts = [ "ship_compartment" ]
    getInfo = function(camInfo, unitInfo, partName = null, dmgParams = null)
    {
      local total = ::getTblValue("compartmentsTotal", camInfo, 0)
      if (!total)
        return null
      local canUpdateFromParts = dmgParams != null && countPartsTotal(parts, unitInfo.parts) == total
      local alive = canUpdateFromParts ? countPartsAlive(parts, unitInfo.parts)
        : ::getTblValue("compartmentsAlive", camInfo, 0)
      local aliveMin = ::getTblValue("compartmentsAliveMin", camInfo, 0)
      if (aliveMin > total)
        return null

      local value = getPercentValueByCounts(alive, total, aliveMin)
      return {
        state = getStateByValue(alive, total, aliveMin + 1, aliveMin)
        label = ::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText(value)
      }
    }
  }

  SHIP_CREW = {
    unitTypesMask = unitTypes.SHIP.bit
    isUpdateOnKnownPartKillsOnly = false
    getInfo = function(camInfo, unitInfo, partName = null, dmgParams = null)
    {
      local total = ::getTblValue("crewTotal", camInfo, 0)
      if (!total)
        return null
      local alive = dmgParams ? ::getTblValue("crewAliveCount", dmgParams, 0)
        : ::getTblValue("crewAlive", camInfo, 0)
      local minCrewCount = camInfo?.crewAliveMin ?? 0
      local bestMinCrewCount = camInfo?.bestMinCrewCount ?? minCrewCount

      local maxCrewLeftPercent = 1.0 + (bestMinCrewCount.tofloat() - minCrewCount) / total
      local percent = ::clamp(stdMath.lerp(minCrewCount - 1, total, 0, maxCrewLeftPercent, alive), 0, 1)
      return {
        state = getStateByValue(alive, total, minCrewCount + 1, minCrewCount)
        label = ::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText(percent)
      }
    }
  }
}, null, "id")

g_hud_enemy_debuffs.getTypeById <- function getTypeById(id)
{
  return enums.getCachedType("id", id, cache.byId, this, UNKNOWN)
}

g_hud_enemy_debuffs.getTypesArrayByUnitType <- function getTypesArrayByUnitType(unitType)
{
  local unitTypeBit = unitTypes.getByEsUnitType(unitType).bit
  local list = []
  foreach (item in types)
    if (unitTypeBit & item.unitTypesMask)
      list.append(item)
  return list
}

g_hud_enemy_debuffs.getTrackedPartNamesByUnitType <- function getTrackedPartNamesByUnitType(unitType)
{
  local unitTypeBit = unitTypes.getByEsUnitType(unitType).bit
  local list = []
  foreach (item in types)
    if (unitTypeBit & item.unitTypesMask)
      foreach (partName in item.parts)
        ::u.appendOnce(partName, list)
  return list
}
