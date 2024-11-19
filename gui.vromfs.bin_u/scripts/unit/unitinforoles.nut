from "%scripts/dagui_library.nut" import *
let { getEsUnitType } = require("%scripts/unit/unitInfo.nut")
let u = require("%sqStdLibs/helpers/u.nut")

let basicUnitRoles = {
  [ES_UNIT_TYPE_AIRCRAFT] = ["type_fighter", "type_assault", "type_bomber"],
  [ES_UNIT_TYPE_TANK] = ["type_tank", "type_light_tank", "type_medium_tank", "type_heavy_tank",
    "type_tank_destroyer", "type_spaa", "type_lbv", "type_mbv", "type_hbv", "type_exoskeleton"],
  [ES_UNIT_TYPE_BOAT] = ["type_boat", "type_heavy_boat", "type_barge", "type_frigate"],
  [ES_UNIT_TYPE_SHIP] = ["type_ship", "type_destroyer", "type_light_cruiser",
    "type_heavy_cruiser", "type_battlecruiser", "type_battleship", "type_submarine"],
  [ES_UNIT_TYPE_HELICOPTER] = ["type_attack_helicopter", "type_utility_helicopter"],
}

let unitRoleFontIcons = {
  fighter                  = loc("icon/unitclass/fighter"),
  assault                  = loc("icon/unitclass/assault"),
  bomber                   = loc("icon/unitclass/bomber"),
  attack_helicopter        = loc("icon/unitclass/attack_helicopter"),
  utility_helicopter       = loc("icon/unitclass/utility_helicopter"),
  light_tank               = loc("icon/unitclass/light_tank"),
  medium_tank              = loc("icon/unitclass/medium_tank"),
  heavy_tank               = loc("icon/unitclass/heavy_tank"),
  tank_destroyer           = loc("icon/unitclass/tank_destroyer"),
  spaa                     = loc("icon/unitclass/spaa"),
  lbv                      = loc("icon/unitclass/light_tank")
  mbv                      = loc("icon/unitclass/medium_tank")
  hbv                      = loc("icon/unitclass/heavy_tank")
  exoskeleton              = loc("icon/unitclass/medium_tank"),
  ship                     = loc("icon/unitclass/ship"),
  boat                     = loc("icon/unitclass/gun_boat")
  heavy_boat               = loc("icon/unitclass/heavy_gun_boat")
  barge                    = loc("icon/unitclass/naval_ferry_barge")
  destroyer                = loc("icon/unitclass/destroyer")
  frigate                  = loc("icon/unitclass/destroyer")
  light_cruiser            = loc("icon/unitclass/light_cruiser")
  cruiser                  = loc("icon/unitclass/cruiser")
  heavy_cruiser            = loc("icon/unitclass/cruiser")
  battlecruiser            = loc("icon/unitclass/battlecruiser")
  battleship               = loc("icon/unitclass/battleship")
  submarine                = loc("icon/unitclass/submarine")
}

let getRoleText = @(role) loc($"mainmenu/type_{role}")

let getRoleName = @(role) role.slice(5)

function getUnitBasicRole(unit) {
  let unitType = getEsUnitType(unit)
  let basicRoles = basicUnitRoles?[unitType]
  if (!basicRoles || !basicRoles.len())
    return ""

  foreach (tag in unit.tags)
    if (isInArray(tag, basicRoles))
      return getRoleName(tag)
  return getRoleName(basicRoles[0])
}

function getUnitRoleIcon(source) {
  let role = u.isString(source) ? source
    : getUnitBasicRole(source)
  return unitRoleFontIcons?[role] ?? ""
}

return {
  getRoleText
  basicUnitRoles
  getUnitRoleIcon
  getUnitBasicRole
}