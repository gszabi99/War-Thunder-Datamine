let externalPlayerListConsts = require_optional("externalPlayerListConsts")
let consttable = getconsttable()

let fields = [
  "EPL_FRIENDLIST",
  "EPL_BLOCKLIST",
  "EPL_PLAYERSMET",
  "EPL_RECENT_SQUAD",
  "EPL_STEAM",
  "EPL_PSN",
  "EPL_XBOXONE",
]

let export = {}
foreach (k in fields)
  export[k] <- externalPlayerListConsts?[k] ?? consttable[k]

return freeze(export)
