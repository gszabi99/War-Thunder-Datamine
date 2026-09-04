let unitClassConsts = require_optional("unitClassConsts")
let consttable = getconsttable()

let fields = [
  "EUCT_FIGHTER",
  "EUCT_BOMBER",
  "EUCT_ASSAULT",
  "EUCT_TANK",
  "EUCT_HEAVY_TANK",
  "EUCT_TANK_DESTROYER",
  "EUCT_SPAA",
  "EUCT_SHIP",
  "EUCT_TORPEDO_BOAT",
  "EUCT_GUN_BOAT",
  "EUCT_TORPEDO_GUN_BOAT",
  "EUCT_SUBMARINE_CHASER",
  "EUCT_DESTROYER",
  "EUCT_NAVAL_FERRY_BARGE",
  "EUCT_HELICOPTER",
  "EUCT_CRUISER",
  "EUCT_HUMAN",
  "EUCT_TRANSPORT",
  "EUCT_TOTAL",
  "CLASS_FLAGS_AIRCRAFT",
  "CLASS_FLAGS_TANK",
  "CLASS_FLAGS_SHIP",
  "CLASS_FLAGS_HELICOPTER",
  "CLASS_FLAGS_BOAT",
  "CUT_INVALID",
  "CUT_AIRCRAFT",
  "CUT_TANK",
  "CUT_SHIP",
  "CUT_HUMAN",
  "CUT_TOTAL",
]

let export = {}
foreach (k in fields)
  export[k] <- unitClassConsts?[k] ?? consttable[k]

return freeze(export)
