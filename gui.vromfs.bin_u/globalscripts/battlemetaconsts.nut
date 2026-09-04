let battleMetaConsts = require_optional("battleMetaConsts")
let consttable = getconsttable()

let fields = [
  "STATS_RESULT_IN_PROGRESS",
  "STATS_RESULT_SUCCESS",
  "STATS_RESULT_FAIL",
  "STATS_RESULT_ABORTED_BY_KICK",
  "STATS_RESULT_ABORTED_BY_ANTICHEAT",
  "BMS_OUT_OF_AMMO",
  "BMS_OUT_OF_BOMBS",
  "BMS_OUT_OF_ROCKETS",
  "BMS_OUT_OF_TORPEDOES",
  "BMS_ENGINE_BROKEN",
  "BMS_TRACK_BROKEN",
  "BMS_MAIN_GUN_BROKEN",
  "ETTI_VALUE_TOTAL",
  "ETTI_VALUE_INHISORY",
  "SNT_MY_STREAK_HEADER",
  "SNT_MY_STREAK_DESCRIPTION",
  "SNT_OTHER_STREAK_TEXT",
  "ES_UNIT_ELITE_NONE",
  "ES_UNIT_ELITE_STAGE1",
  "ES_UNIT_ELITE_STAGE2",
]

let export = {}
foreach (k in fields)
  export[k] <- battleMetaConsts?[k] ?? consttable[k]

return freeze(export)
