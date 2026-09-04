let soundOptions = require_optional("soundOptions")
let consttable = getconsttable()

let fields = [
  "CACHED_MUSIC_MENU",
  "CACHED_MUSIC_MISSION",
]

let export = {}
foreach (k in fields)
  export[k] <- soundOptions?[k] ?? consttable[k]

return freeze(export)
