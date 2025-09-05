from "%scripts/dagui_library.nut" import *










let { EII_SMOKE_GRENADE, EII_SMOKE_SCREEN, EII_ARTILLERY_TARGET, EII_SPECIAL_UNIT,
  EII_MEDICALKIT, EII_TERRAFORM, EII_WINCH, EII_WINCH_ATTACH, EII_WINCH_DETACH,
  EII_EXTINGUISHER, EII_TOOLKIT, EII_REPAIR_BREACHES, EII_SPEED_BOOSTER,
  EII_SUBMARINE_SONAR, EII_TORPEDO_SENSOR,
  EII_AUTO_TURRET, EII_SUPPORT_PLANE, EII_SUPPORT_PLANE_2, EII_SUPPORT_PLANE_3, EII_SUPPORT_PLANE_4,
  EII_SUPPORT_PLANE_CHANGE, EII_SUPPORT_PLANE_GROUP_ATTACK, EII_STEALTH, EII_LOCK, EII_NIGHT_VISION,
  EII_SIGHT_STABILIZATION, EII_SIGHT_STABILIZATION_OFF, EII_SUPPORT_PLANE_ORBITING, EII_UGV, EII_UNLIMITED_CONTROL,
  EII_GUIDANCE_MODE, EII_DESIGNATE_TARGET, EII_ROCKET_AIR, EII_AGM_AIR, EII_AAM_AIR, EII_BOMB_AIR,
  EII_GUIDED_BOMB_AIR, EII_PERISCOPE, EII_EMERGENCY_SURFACING, EII_SELECT_SPECIAL_WEAPON,
  EII_MISSION_SUPPORT_PLANE, EII_SUPPORT_PLANE_GROUP_RETURN, EII_BUILDING, EII_SLAVE_UNIT_SPAWN,
  EII_SLAVE_UNIT_SWITCH, EII_ANTI_AIR_COMPLEX_MENU, EII_SHIP_DAMAGE_CONTROL, EII_SLAVE_UNIT_STATUS
} = require("hudActionBarConst")
let { HUD_UNIT_TYPE } = require("%scripts/hud/hudUnitType.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")

const ITEMS_PER_PAGE = 8



let cfgMenuTank = [
  
    EII_SMOKE_GRENADE,
    EII_SMOKE_SCREEN,
    EII_ARTILLERY_TARGET,
    { type = EII_SPECIAL_UNIT, killStreakTag = "fighter" },
    { type = EII_SPECIAL_UNIT, killStreakTag = "attacker" },
    { type = EII_SPECIAL_UNIT, killStreakTag = "bomber" },
    EII_MEDICALKIT,
    [ EII_WINCH, EII_WINCH_ATTACH, EII_WINCH_DETACH ],
  
    EII_TERRAFORM,
    EII_UGV,
    EII_SELECT_SPECIAL_WEAPON,
    EII_NIGHT_VISION,
    EII_SUPPORT_PLANE,
    EII_SUPPORT_PLANE_2,
    EII_SUPPORT_PLANE_3,
    EII_SUPPORT_PLANE_4,
    
    EII_GUIDANCE_MODE,
    EII_MISSION_SUPPORT_PLANE,
    EII_BUILDING,
    EII_SLAVE_UNIT_SPAWN,
    EII_SLAVE_UNIT_SWITCH,
    { type = EII_SLAVE_UNIT_STATUS, innerIdx = 0 },
    { type = EII_SLAVE_UNIT_STATUS, innerIdx = 1 },
    EII_ANTI_AIR_COMPLEX_MENU,
    
    EII_LOCK,           
    EII_STEALTH,        
    EII_AUTO_TURRET,    
    EII_UNLIMITED_CONTROL, 
]


let cfgMenuTankArachisCombatTrack = [
  
    EII_SMOKE_GRENADE,
    EII_SMOKE_SCREEN,
    EII_ARTILLERY_TARGET,
    null,
    EII_LOCK,           
    null,
    EII_MEDICALKIT,
    [ EII_WINCH, EII_WINCH_ATTACH, EII_WINCH_DETACH ],
]

let cfgMenuHuman = [
  
    EII_SMOKE_GRENADE,
    EII_LOCK,
    EII_ARTILLERY_TARGET,
    EII_NIGHT_VISION,
    { type = EII_SPECIAL_UNIT, killStreakTag = "fighter" },
    { type = EII_SPECIAL_UNIT, killStreakTag = "attacker" },
    { type = EII_SPECIAL_UNIT, killStreakTag = "bomber" },
    EII_SUPPORT_PLANE,
]

let cfgMenuShip = [
  
    EII_SMOKE_GRENADE,
    EII_SMOKE_SCREEN,
    EII_ARTILLERY_TARGET,
    EII_EXTINGUISHER,
    EII_TOOLKIT,
    EII_REPAIR_BREACHES,
    [ EII_WINCH, EII_WINCH_ATTACH, EII_WINCH_DETACH ],
    EII_GUIDANCE_MODE,
  
    EII_SUPPORT_PLANE,
    EII_SUPPORT_PLANE_2,
    EII_SUPPORT_PLANE_3,
    EII_SUPPORT_PLANE_4,
    { type = EII_SHIP_DAMAGE_CONTROL, userHandle = @(v) (v >> 3) == 1 },
    { type = EII_SHIP_DAMAGE_CONTROL, userHandle = @(v) (v >> 3) == 2 },
    { type = EII_SHIP_DAMAGE_CONTROL, userHandle = @(v) (v >> 3) == 3 },
    EII_LOCK,
  
    EII_SPEED_BOOSTER,  
]

let cfgMenuSubmarine = [
  
    EII_TORPEDO_SENSOR,
    EII_SMOKE_SCREEN,
    EII_SUBMARINE_SONAR,
    EII_EXTINGUISHER,
    EII_TOOLKIT,
    EII_REPAIR_BREACHES,
    EII_PERISCOPE,
    EII_EMERGENCY_SURFACING,
]

let cfgMenuAircraft = [
  
    EII_SUPPORT_PLANE,
    EII_SUPPORT_PLANE_CHANGE,
    EII_SUPPORT_PLANE_GROUP_ATTACK,
    EII_SUPPORT_PLANE_GROUP_RETURN,
    EII_SMOKE_SCREEN,
    EII_NIGHT_VISION,
    EII_DESIGNATE_TARGET,
    [EII_SIGHT_STABILIZATION, EII_SIGHT_STABILIZATION_OFF],
  
    EII_SUPPORT_PLANE_ORBITING,
    EII_SUPPORT_PLANE_2,
    EII_SUPPORT_PLANE_3,
    EII_SUPPORT_PLANE_4,
    EII_ROCKET_AIR,
    EII_AGM_AIR,
    EII_AAM_AIR,
    EII_BOMB_AIR,
  
    EII_GUIDED_BOMB_AIR,
    null,
    null,
]



function getCfgByUnit(unitId, hudUnitType) {
  return [ "combat_track_a", "combat_track_h" ].contains(unitId) ? cfgMenuTankArachisCombatTrack
       : hudUnitType == HUD_UNIT_TYPE.TANK       ? cfgMenuTank
       : hudUnitType == HUD_UNIT_TYPE.SHIP_EX    ? cfgMenuSubmarine
       : hudUnitType == HUD_UNIT_TYPE.SHIP       ? cfgMenuShip
       : hudUnitType == HUD_UNIT_TYPE.AIRCRAFT   ? cfgMenuAircraft
       : hudUnitType == HUD_UNIT_TYPE.HELICOPTER ? cfgMenuAircraft
       : hudUnitType == HUD_UNIT_TYPE.HUMAN      ? cfgMenuHuman
       : []
}

function isActionMatch(cfgItem, action) {
  let t = type(cfgItem)
  if (t == "array") {
    foreach (c in cfgItem)
      if (isActionMatch(c, action))
        return true
    return false
  }
  if (t == "integer")
    return cfgItem == action?.type
  if (t == "table") {
    foreach (k, v in cfgItem) {
      let vType = type(v)
      if (vType == "function" ? !v(action?[k]) : v != action?[k])
        return false
    }
    return true
  }
  return false
}

function arrangeStreakWheelActions(unitId, hudUnitType, actions) {
  local res = getCfgByUnit(unitId, hudUnitType).map(@(c) c != null ? actions.findvalue(@(a) isActionMatch(c, a)) : null)
  let actionsByPage = []
  foreach (idx, action in res) {
    let pageIdx = idx / ITEMS_PER_PAGE
    if (pageIdx not in actionsByPage)
      actionsByPage.append([])
    actionsByPage[pageIdx].append(action)
  }
  for (local idx = actionsByPage.len() - 1; idx >= 0; idx--)
    if (actionsByPage[idx].findvalue(@(action) action != null) == null)
      actionsByPage.remove(idx)
  res = actionsByPage.reduce(@(resActions, page) resActions.extend(page), [])
  foreach (a in actions)
    if (res.indexof(a) == null)
      script_net_assert_once("action not mapped", $"Actionbar action type {a?.type} not mapped in wheelmenu")

  res.resize(actionsByPage.len() * ITEMS_PER_PAGE, null)
  return res
}

return {
  arrangeStreakWheelActions
}
