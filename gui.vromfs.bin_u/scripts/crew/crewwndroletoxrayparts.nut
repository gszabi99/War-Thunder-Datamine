from "%scripts/dagui_library.nut" import *
let { getFullUnitBlk } = require("%scripts/unit/unitParams.nut")
let { eachBlock } = require("%sqstd/datablock.nut")
let regexp2 = require("regexp2")

let tankRolesToParts = {
  driver = ["engine_dm", "transmission_dm"]
  tank_gunner = [
    "drive_turret_v_dm",
    @"^drive_turret_v_\d{2}_dm$",
    "drive_turret_h_dm",
    @"^drive_turret_h_\d{2}_dm$"
  ]
  commander = [
    
  ]
  loader = [
    
    
    
    
    
    
    
    
    
    
    
    
  ]
  radio_gunner = ["radio_station_dm"]
  groundService = []
}

let aircraftRolesToParts = {
  pilot = ["pilot_dm", @"^pilot\d{1}_dm$"]
  gunner = ["gunner_dm", @"^gunner\d{1}_dm$", @"^gun\d{1}_dm$"]
  groundService = [@"^cannon\d{1}_dm$", @"^mgun\d{1}_dm$"]
}

let shipToRolesParts = {
  ship_commander = ["radio_station_dm", @"^radio_station_\d{2}_dm$"]
  ship_look_out_station = []
  ship_engine_room = [
    @"^engine_\d{2}_dm$",
    @"^funnel_\d{2}_dm$",
    @"^steering_gear_\d{2}_dm$",
    @"^shaft_\d{2}_dm$",
    @"^engine_room_\d{2}_dm$",
    @"^transmission_\d{2}_dm$",
    @"^rudder_\d{2}_dm$"
  ]
  ship_artillery = [
    @"^main_caliber_gun_\d{2}_dm$",
    @"^main_caliber_turret_\d{2}_dm$",
    @"^auxiliary_caliber_gun_\d{2}_dm$",
    @"^auxiliary_caliber_turret_\d{2}_dm$",
    @"^aa_gun_\d{2}_dm$",
    @"^aa_gun_\d{3}_dm$",
    @"^aa_turret_\d{2}_dm$",
    @"^aa_turret_\d{3}_dm$",
    "gun_barrel_dm",
    @"^gun_barrel_\d{2}_dm$"
  ]
  ship_damage_control =  [@"^pump_\d{2}_dm$"]
  groundService = []
}

function getPartsForUnitsFromBlk(unit, partsRegexpForRole) {
  let uBlk = getFullUnitBlk(unit.name)
  let res = []
  if (uBlk?.DamageParts == null)
    return res
  eachBlock(uBlk.DamageParts, function(damageArea) {
    eachBlock(damageArea, function(_b, partName) {
      foreach (regExpRole in partsRegexpForRole) {
        if (regExpRole.match(partName)) {
          res.append(partName)
          break
        }
      }
    })
  })
  return res
}

function getPartsForAircrafts(unit, role) {
  let res = []
  let partsRegexpForRole = (aircraftRolesToParts?[role] ?? []).map(@(r) regexp2(r))
  if (partsRegexpForRole.len() == 0)
    return res

  res.extend(getPartsForUnitsFromBlk(unit, partsRegexpForRole))
  return res
}

function getPartsForNavals(unit, role) {
  let res = []
  let partsRegexpForRole = (shipToRolesParts?[role] ?? []).map(@(r) regexp2(r))
  if (partsRegexpForRole.len() == 0)
    return res

  res.extend(getPartsForUnitsFromBlk(unit, partsRegexpForRole))
  return res
}

let partsForTanksOtherRoles = {}
function getPartsForTanksForOtherRole(unit, role) {
  if (partsForTanksOtherRoles?[unit.name][role])
    return partsForTanksOtherRoles[unit.name][role]

  if (partsForTanksOtherRoles?[unit.name] == null)
    partsForTanksOtherRoles[unit.name] <- {}

  let res = []
  partsForTanksOtherRoles[unit.name][role] <- res

  let partsRegexpForRole = (tankRolesToParts?[role] ?? []).map(@(r) regexp2(r))
  if (partsRegexpForRole.len() == 0)
    return res

  res.extend(getPartsForUnitsFromBlk(unit, partsRegexpForRole))
  return res
}

let isPartIsLoaderStowagePart = @(partName)
  regexp2(@"^ammo_turret_\d{2}_dm$").match(partName) ||
  regexp2(@"^ammo_body_\d{2}_dm$").match(partName) ||
  regexp2(@"^ammo_body_l_\d{2}_dm$").match(partName) ||
  regexp2(@"^ammo_body_r_\d{2}_dm$").match(partName)

const TRIGGER_GROUPS_TO_SKIP = ["machinegun", "coaxial"]

let partsForTanksForLoader = {}
function getPartsForTanksForLoader(unit) {
  if (partsForTanksForLoader?[unit.name])
    return partsForTanksForLoader[unit.name]

  let res = []
  partsForTanksForLoader[unit.name] <- res

  let triggersList = []
  let uBlk = getFullUnitBlk(unit.name)
  let weaponsBlk = uBlk?.commonWeapons
  if (weaponsBlk != null) {
    foreach (w in (weaponsBlk % "Weapon")) {
      if (w?.autoLoader)
        continue
      if (TRIGGER_GROUPS_TO_SKIP.contains(w?.triggerGroup))
        continue
      triggersList.append(w.trigger)
      let barrelDP = w?.barrelDP
      if (barrelDP != null)
        res.append(barrelDP)
      let breechDP = w?.breechDP
      if (breechDP != null)
        res.append(breechDP)
    }
  }

  let stowageBlk = uBlk?.ammoStowages
  if (triggersList.len() && stowageBlk != null) {
    res.append("ammo_turret_dm", "ammo_body_dm")
    eachBlock(stowageBlk, function(s) {
      if (triggersList.contains(s.weaponTrigger)) {
        foreach (blockName in const ["shells", "charges"]) {
          foreach (block in (s % blockName)) {
            eachBlock(block, function(_b, name) {
              if (isPartIsLoaderStowagePart(name))
                res.append(name)
            })
          }
        }
      }
    })
  }

  return res
}

function getPartsForTanksForCommander(unit) {
  let res = []
  foreach (role, _ in tankRolesToParts) {
    let parts = getPartsForTanksForOtherRole(unit, role)
    if (parts.len())
      res.extend(parts)
  }
  res.extend(getPartsForTanksForLoader(unit))
  return res
}

function getPartsForTanks(unit, role) {
  let res = []

  
  if (role == "commander")
    res.extend(getPartsForTanksForCommander(unit))
  
  else if (role == "loader")
    res.extend(getPartsForTanksForLoader(unit))
  
  else
    res.extend(getPartsForTanksForOtherRole(unit, role))

  return res
}

function getPartsByChosenRole(unit, role) {
  if (unit.isAir() || unit.isHelicopter())
    return getPartsForAircrafts(unit, role)

  if (unit.isShipOrBoat())
    return getPartsForNavals(unit, role)

  if (unit.isTank())
    return getPartsForTanks(unit, role)

  return []
}

function getMemberPartsWithSameRole(unit, role) {
  let res = []
  let crewBlk = getFullUnitBlk(unit.name)?.tank_crew
  if (crewBlk) {
    let needAddAllMembers = role == "commander"
    let l = crewBlk.blockCount()
    for (local i = 0; i < l; i++) {
      let memberBlk = crewBlk.getBlock(i)
      let roles = memberBlk % "role"
      let dmPart = memberBlk?.dmPart
      if (dmPart != null && (needAddAllMembers || roles.contains(role)))
        res.append(dmPart)
    }
  }
  return res
}

let partsForUnitCache = {}
function getPartsListToHighlight(unit, role) {
  if (partsForUnitCache?[unit.name][role])
    return partsForUnitCache[unit.name][role]

  if (partsForUnitCache?[unit.name] == null)
    partsForUnitCache[unit.name] <- {}

  let res = []
  partsForUnitCache[unit.name][role] <- res

  let partsByChosenRole = getPartsByChosenRole(unit, role)
  if (partsByChosenRole.len())
    res.extend(partsByChosenRole)

  
  if (unit.isTank()) {
    let memberPartsWithSameRole = getMemberPartsWithSameRole(unit, role)
    foreach (part in memberPartsWithSameRole) {
      if (!res.contains(part))
        res.append(part)
    }
  }

  return res
}

return {
  getPartsListToHighlight
}