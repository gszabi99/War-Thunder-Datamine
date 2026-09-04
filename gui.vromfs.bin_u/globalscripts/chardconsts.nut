let chardConst = require_optional("chardConst")
let consttable = getconsttable()

let fields = [
  "TP_UNKNOWN",
  "TP_PS4",
  "TP_XBOXONE",
  "TP_XBOX_SCARLETT",
  "TP_PS5",

  "INVENTORY_STATE_SENDING",
]

let export = {}
foreach (k in fields)
  export[k] <- chardConst?[k] ?? consttable[k]

return freeze(export)
