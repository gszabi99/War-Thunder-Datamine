let replayConsts = require_optional("replayConsts")
let consttable = getconsttable()

let fields = [
  "REPLAY_LOAD_COCKPIT_NO_ONE",
  "REPLAY_LOAD_COCKPIT_AUTHOR",
  "REPLAY_LOAD_COCKPIT_ALL",
]

let export = {}
foreach (k in fields)
  export[k] <- replayConsts?[k] ?? consttable[k]

return freeze(export)
