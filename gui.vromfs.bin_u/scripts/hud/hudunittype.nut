from "%scripts/hud/hudConsts.nut" import HUD_TYPE

let unitTypes = require("%scripts/unit/unitTypesList.nut")

let HUD_UNIT_TYPE = {
  TANK             = "tank"
  SHIP             = "ship"
  SHIP_EX          = "shipEx"
  AIRCRAFT         = "aircraft"
  HELICOPTER       = "helicopter"
  HUMAN            = "human"



  HUMAN_DRONE      = "humanDrone"
  HUMAN_DRONE_HELI = "humanDroneHeli"
}

let { TANK, SHIP, SHIP_EX, AIRCRAFT, HELICOPTER, HUMAN



  , HUMAN_DRONE, HUMAN_DRONE_HELI
} = HUD_UNIT_TYPE

let unitTypeByHudUnitType = {
  [TANK]             = unitTypes.TANK,
  [SHIP]             = unitTypes.SHIP,
  [SHIP_EX]          = unitTypes.SHIP,
  [AIRCRAFT]         = unitTypes.AIRCRAFT,
  [HELICOPTER]       = unitTypes.HELICOPTER,
  [HUMAN]            = unitTypes.HUMAN,



  [HUMAN_DRONE]      = unitTypes.AIRCRAFT,
  [HUMAN_DRONE_HELI] = unitTypes.HELICOPTER,
}

let hudTypeByHudUnitType = {
  [TANK]             = HUD_TYPE.TANK,
  [SHIP]             = HUD_TYPE.SHIP,
  [SHIP_EX]          = HUD_TYPE.SHIP,
  [AIRCRAFT]         = HUD_TYPE.AIR,
  [HELICOPTER]       = HUD_TYPE.HELICOPTER,
  [HUMAN]            = HUD_TYPE.HUMAN,



  [HUMAN_DRONE]      = HUD_TYPE.HUMAN_DRONE,
  [HUMAN_DRONE_HELI] = HUD_TYPE.HUMAN_DRONE_HELI,
}

return {
  HUD_UNIT_TYPE
  unitTypeByHudUnitType
  hudTypeByHudUnitType
}
