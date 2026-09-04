let userStatsConsts = require_optional("userStatsConsts")
let consttable = getconsttable()

let fields = [
  "BLK_USER_STATS",
  "BLK_USER_PLACES",
  "BLK_USER_PLACES_INFO_PLACE",
  "BULK_WINS_AND_DEFEATS_INFO",
  "EVENT_STAT_ACTIVITY",
  "EVENT_STAT_PLATFORM",
  "EVENT_STAT_AKILLS",
  "EVENT_STAT_GKILLS",
  "EVENT_STAT_NKILLS",
  "EVENT_STAT_AKILLS_AI",
  "EVENT_STAT_GKILLS_AI",
  "EVENT_STAT_NKILLS_AI",
  "EVENT_STAT_DEATHS",
  "EVENT_STAT_TIMES_PLAYED",
  "EVENT_STAT_SCORE",
  "EVENT_STAT_FLYOUTS",
]

let export = {}
foreach (k in fields)
  export[k] <- userStatsConsts?[k] ?? consttable[k]

return freeze(export)
