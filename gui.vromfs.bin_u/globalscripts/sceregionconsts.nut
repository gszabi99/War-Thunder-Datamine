let ps4 = require_optional("ps4")
let consttable = getconsttable()

let fields = [
  "SCE_REGION_SCEE",
  "SCE_REGION_SCEA",
  "SCE_REGION_SCEJ",
]

let export = {}
foreach (k in fields)
  export[k] <- ps4?[k] ?? consttable[k]

return freeze(export)
