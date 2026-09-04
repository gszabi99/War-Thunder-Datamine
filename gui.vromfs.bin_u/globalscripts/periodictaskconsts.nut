let periodicTaskConsts = require_optional("periodicTaskConsts")
let consttable = getconsttable()

let fields = [
  "EPTT_BEST_EFFORT",
  "EPTT_EXEC_MISSED",
  "EPTT_SKIP_MISSED",
  "EPTF_EXECUTE_IMMEDIATELY",
  "EPTF_IN_FLIGHT",
]

let export = {}
foreach (k in fields)
  export[k] <- periodicTaskConsts?[k] ?? consttable[k]

return freeze(export)
