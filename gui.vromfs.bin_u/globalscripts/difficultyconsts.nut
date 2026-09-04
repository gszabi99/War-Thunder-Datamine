let difficultyConsts = require_optional("difficultyConsts")
let consttable = getconsttable()

let fields = [
  "EGD_NONE",
  "EGD_ARCADE",
  "EGD_HISTORICAL",
  "EGD_SIMULATION",
  "EGD_TOTAL",
  "DIFFICULTY_ARCADE",
  "DIFFICULTY_REALISTIC",
  "DIFFICULTY_HARDCORE",
  "DIFFICULTY_CUSTOM",
  "DIFFICULTY_LEVELS",
  "DIFFICULTY_BASE_LEVELS",
]

let export = {}
foreach (k in fields)
  export[k] <- difficultyConsts?[k] ?? consttable[k]

return freeze(export)
