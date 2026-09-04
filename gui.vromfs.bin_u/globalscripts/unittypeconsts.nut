let unitTypeConsts = require_optional("unitTypeConsts")
let consttable = getconsttable()

let fields = [
  "ES_UNIT_TYPE_INVALID",
  "ES_UNIT_TYPE_AIRCRAFT",
  "ES_UNIT_TYPE_TANK",
  "ES_UNIT_TYPE_SHIP",
  "ES_UNIT_TYPE_HELICOPTER",
  "ES_UNIT_TYPE_BOAT",
  "ES_UNIT_TYPE_HUMAN",
  "ES_UNIT_TYPE_TRANSPORT",
  "ES_UNIT_TYPE_TOTAL",
]

let export = {}
foreach (k in fields)
  export[k] <- unitTypeConsts?[k] ?? consttable[k]

return freeze(export)
