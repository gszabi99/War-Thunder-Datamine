let gameTypeConsts = require_optional("gameTypeConsts")
let consttable = getconsttable()

let fields = [
  "GT_TRAINING",
  "GT_COOPERATIVE",
  "GT_VERSUS",
  "GT_USE_LB",
  "GT_USE_REPLAY",
  "GT_USE_STATS",
  "GT_MP_SCORE",
  "GT_MP_TICKETS",
  "GT_MP_CAPTURE",
  "GT_MP_SOLO",
  "GT_SP_RESTART",
  "GT_SP_USE_SKIN",
  "GT_DYNAMIC",
  "GT_USE_WP",
  "GT_USE_XP",
  "GT_RELOAD_EXPLOSIVES",
  "GT_TRUSTED_HOST",
  "GT_GAMEPLAY_EVENTS",
  "GT_FFA_DEATHMATCH",
  "GT_RACE",
  "GT_USE_UNLOCKS",
  "GT_USE_ORDERS",
  "GT_AUTO_SPAWN",
  "GT_FFA",
  "GT_LAST_MAN_STANDING",
  "GT_HANGAR",
  "GT_FOOTBALL",
]

let export = {}
foreach (k in fields)
  export[k] <- gameTypeConsts?[k] ?? consttable[k]

return freeze(export)
