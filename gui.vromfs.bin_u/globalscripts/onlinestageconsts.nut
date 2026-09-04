let onlineStageConsts = require_optional("onlineStageConsts")
let consttable = getconsttable()

let fields = [
  "CIRCUIT",
  "ONLINE_BINARIES_INITED",
  "HANGAR_ENTERED",
  "CHAR_PROFILE_RECEIVED",
  "MATCHING_CONNECTED",
]

let export = {}
foreach (k in fields)
  export[k] <- onlineStageConsts?[k] ?? consttable[k]

return freeze(export)
