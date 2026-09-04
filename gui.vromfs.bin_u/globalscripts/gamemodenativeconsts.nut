let gameModeNativeConsts = require_optional("gameModeNativeConsts")
let consttable = getconsttable()

let fields = [
  "GM_CAMPAIGN",
  "GM_TRAINING",
  "GM_TEST_FLIGHT",
  "GM_SINGLE_MISSION",
  "GM_DYNAMIC",
  "GM_BUILDER",
  "GM_CREDITS",
  "GM_BENCHMARK",
  "GM_EVENT",
  "GM_USER_MISSION",
  "GM_TEAMBATTLE",
  "GM_DOMINATION",
  "GM_SKIRMISH",
  "GM_TOURNAMENT",
  "GM_COUNT",
]

let export = {}
foreach (k in fields)
  export[k] <- gameModeNativeConsts?[k] ?? consttable[k]

return freeze(export)
