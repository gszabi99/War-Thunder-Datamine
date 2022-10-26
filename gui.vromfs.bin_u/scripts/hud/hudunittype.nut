//checked for explicitness
#no-root-fallback
#explicit-this

let unitTypes = require("%scripts/unit/unitTypesList.nut")

let HUD_UNIT_TYPE = {
  TANK             = "tank"
  SHIP             = "ship"
  SHIP_EX          = "shipEx"
  AIRCRAFT         = "aircraft"
  HELICOPTER       = "helicopter"
  //


}

let { TANK, SHIP, SHIP_EX, AIRCRAFT, HELICOPTER
//


} = HUD_UNIT_TYPE

let unitTypeByHudUnitType = {
  [TANK]             = unitTypes.TANK,
  [SHIP]             = unitTypes.SHIP,
  [SHIP_EX]          = unitTypes.SHIP,
  [AIRCRAFT]         = unitTypes.AIRCRAFT,
  [HELICOPTER]       = unitTypes.HELICOPTER,
  //


}

let hudTypeByHudUnitType = {
  [TANK]             = HUD_TYPE.TANK,
  [SHIP]             = HUD_TYPE.SHIP,
  [SHIP_EX]          = HUD_TYPE.SHIP,
  [AIRCRAFT]         = HUD_TYPE.AIR,
  [HELICOPTER]       = HUD_TYPE.HELICOPTER,
  //


}

return {
  HUD_UNIT_TYPE
  unitTypeByHudUnitType
  hudTypeByHudUnitType
}
