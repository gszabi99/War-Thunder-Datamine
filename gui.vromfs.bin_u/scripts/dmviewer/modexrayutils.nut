from "%scripts/dagui_library.nut" import *
let { S_UNDEFINED, S_AIRCRAFT, S_HELICOPTER, S_TANK, S_SHIP, S_BOAT
} = require("%globalScripts/modeXrayLib.nut")

let unitTypeToSimpleUnitTypeMap = {
  [ES_UNIT_TYPE_AIRCRAFT] = S_AIRCRAFT,
  [ES_UNIT_TYPE_HELICOPTER] = S_HELICOPTER,
  [ES_UNIT_TYPE_TANK] = S_TANK,
  [ES_UNIT_TYPE_SHIP] = S_SHIP,
  [ES_UNIT_TYPE_BOAT] = S_BOAT,
}

let getSimpleUnitType = @(unit) unitTypeToSimpleUnitTypeMap?[unit?.esUnitType] ?? S_UNDEFINED

return {
  getSimpleUnitType
}
