let hangarMiscConsts = require_optional("hangarMiscConsts")
let consttable = getconsttable()

let fields = [
  "TRICOLOR_INDEX",
  "NUM_FAVORITE_VOICE_MESSAGES",
  "NUM_FAST_VOICE_MESSAGES",
  "BULLETS_SETS_QUANTITY",
  "MSG_FREE_EXP_DENOMINATE_OLD",
]

let export = {}
foreach (k in fields)
  export[k] <- hangarMiscConsts?[k] ?? consttable[k]

return freeze(export)
