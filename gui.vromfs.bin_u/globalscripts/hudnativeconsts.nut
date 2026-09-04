let hudConsts = require_optional("hudNativeConsts")
let consttable = getconsttable()

let fields = [
  "HUD_INDICATORS_SHOW",
  "HUD_INDICATORS_SELECT",
  "HUD_INDICATORS_CENTER",
  "HUD_INDICATORS_ALL",
  "HUD_INDICATORS_TEXT_NICK_ALL",
  "HUD_INDICATORS_TEXT_NICK_SQUAD",
  "HUD_INDICATORS_TEXT_TITLE",
  "HUD_INDICATORS_TEXT_AIRCRAFT",
  "HUD_INDICATORS_TEXT_DIST",
  "HUD_GAME_MODE_DEFAULT",
  "HUD_GAME_MODE_FULL",
  "HUD_GAME_MODE_MINIMAL",
  "HUD_GAME_MODE_DISABLED",
  "NUM_HUD_GAME_MODES",
  "HUD_TYPE_AIRPLANE",
  "HUD_TYPE_TANK",
  "HUD_TYPE_INFANTRY",
  "HUD_TYPE_UNKNOWN",
]

let export = {}
foreach (k in fields)
  export[k] <- hudConsts?[k] ?? consttable[k]

return freeze(export)
