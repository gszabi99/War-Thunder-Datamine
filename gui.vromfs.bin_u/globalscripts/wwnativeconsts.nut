let worldwarConst = require_optional("worldwarConst")
let consttable = getconsttable()

let fields = [
  "SIDE_NONE",
  "SIDE_1",
  "SIDE_2",
  "SIDE_3",
  "SIDE_TOTAL",
  "TT_NONE",
  "TT_GROUND",
  "TT_AIR",
  "TT_WATER",
  "TT_INFANTRY",
  "TT_TOTAL",
  "UT_AIR",
  "UT_GROUND",
  "UT_WATER",
  "UT_INFANTRY",
  "UT_ARTILLERY",
  "UT_TOTAL",
  "AUT_None",
  "AUT_ArtilleryFire",
  "AUT_TransportLoad",
  "AUT_TransportUnload",
  "AUT_Total",
  "EBS_WAITING",
  "EBS_ACTIVE_STARTING",
  "EBS_ACTIVE_MATCHING",
  "EBS_ACTIVE_CONFIRMED",
  "EBS_FINISHED",
  "EBS_FINISHED_APPLIED",
  "EBS_STALE",
  "EBS_ACTIVE_AUTO",
  "EBS_ACTIVE_FAKE",
  "EBS_CAN_BE_REMOVED",
  "EBS_TOTAL",
]

let export = {}
foreach (k in fields)
  export[k] <- worldwarConst?[k] ?? consttable[k]

return freeze(export)
