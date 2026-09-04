let changeAircraftErrConsts = require_optional("changeAircraftErrConsts")
let consttable = getconsttable()

let fields = [
  "ERR_ACCEPT",
  "ERR_REJECT_INTERNAL_ERROR",
  "ERR_REJECT_SESSION_FINISHED",
  "ERR_REJECT_ANOTHER_SESSION",
  "ERR_REJECT_SLOT_DISABLED",
  "ERR_REJECT_LIMITED_RESPAWN",
  "ERR_REJECT_NO_RESPAWN_BASE",
  "ERR_REJECT_AIRCRAFT_NOT_READY",
  "ERR_REJECT_DISCONNECTED",
  "ERR_REJECT_CANT_START_LOADING_PROFILE",
  "ERR_REJECT_PROFILE_LOADING_ERROR",
  "ERR_REJECT_REPAIR_ERROR",
  "ERR_REJECT_NOT_ENOUGH_WP_TO_REPAIR",
  "ERR_REJECT_NO_MISSION",
]

let export = {}
foreach (k in fields)
  export[k] <- changeAircraftErrConsts?[k] ?? consttable[k]

return freeze(export)
