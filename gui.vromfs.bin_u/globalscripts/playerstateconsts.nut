let playerStateConsts = require_optional("playerStateConsts")
let consttable = getconsttable()

let fields = [
  "PLAYER_NOT_EXISTS",
  "PLAYER_HAS_LEAVED_GAME",
  "PLAYER_IN_STATISTICS_BEFORE_LOBBY",
  "PLAYER_IN_LOBBY_NOT_READY",
  "PLAYER_IN_LOBBY_READY",
  "PLAYER_IN_LOADING",
  "PLAYER_READY_TO_START",
  "PLAYER_IN_FLIGHT",
  "PLAYER_IN_RESPAWN",
]

let export = {}
foreach (k in fields)
  export[k] <- playerStateConsts?[k] ?? consttable[k]

return freeze(export)
