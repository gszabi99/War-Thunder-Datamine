let controls = require_optional("controls")
let consttable = getconsttable()

let fields = [
  "CONTROLS_ALLOW_ENGINE_AUTOSTART",
]

let export = {}
foreach (k in fields)
  export[k] <- controls?[k] ?? consttable[k]

return freeze(export)
