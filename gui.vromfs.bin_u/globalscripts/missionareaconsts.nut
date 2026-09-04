let missionAreaConsts = require_optional("missionAreaConsts")
let consttable = getconsttable()

let fields = [
  "CAPTURE_ZONE_CAN_CAPTURE_ON_GROUND",
  "CAPTURE_ZONE_CAN_CAPTURE_IN_AIR",
  "CAPTURE_ZONE_CAN_CAPTURE_BY_GM",
  "AREA_TYPE_UNKNOWN",
  "AREA_TYPE_BOX",
  "AREA_TYPE_CYLINDER",
]

let export = {}
foreach (k in fields)
  export[k] <- missionAreaConsts?[k] ?? consttable[k]

return freeze(export)
