let deathReasonConsts = require_optional("deathReasonConsts")
let consttable = getconsttable()

let fields = [
  "DR_UNKNOWN",
  "DR_DROWN",
  "DR_AMMO_EXPLOSION",
  "DR_AMMO_FIRE",
  "DR_SHIP_BURN",
  "DR_SHIP_CREW_DEATH",
  "DR_SHIP_HULL_DESTRUCTION",
  "DR_SHIP_TORPEDO_HIT",
  "DR_SHIP_MINE_HIT",
  "DR_BULLET_HIT",
  "DR_MELEE_HIT",
  "DR_BLEED_OUT",
  "DR_FALL_DMG",
  "DR_RAN_OVER",
  "DR_NEARBY_EXPLOSION",
  "DR_HUMAN_DROWN",
  "DR_HEADSHOT_HIT",
]

let export = {}
foreach (k in fields)
  export[k] <- deathReasonConsts?[k] ?? consttable[k]

return freeze(export)
