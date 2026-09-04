let mpTeamConsts = require_optional("mpTeamConsts")
let consttable = getconsttable()

let fields = [
  "MP_TEAM_NEUTRAL",
  "MP_TEAM_A",
  "MP_TEAM_B",
]

let export = {}
foreach (k in fields)
  export[k] <- mpTeamConsts?[k] ?? consttable[k]

return freeze(export)
