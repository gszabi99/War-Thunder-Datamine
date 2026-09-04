let autoSaveFlagConsts = require_optional("autoSaveFlagConsts")
let consttable = getconsttable()

let fields = [
  "AUTO_SAVE_FLG_LOGIN",
  "AUTO_SAVE_FLG_PASS",
  "AUTO_SAVE_FLG_DISABLE",
  "AUTO_SAVE_FLG_NOSSLCERT",
]

let export = {}
foreach (k in fields)
  export[k] <- autoSaveFlagConsts?[k] ?? consttable[k]

return freeze(export)
