from "%rGui/globals/ui_library.nut" import *

let { eventbus_subscribe } = require("eventbus")

let battleLogState = mkWatched(persist, "battleLogState", [])

eventbus_subscribe("pushBattleLogEntry", @(logEntry) battleLogState.mutate(@(v) v.append(logEntry)))
eventbus_subscribe("clearBattleLog", @(_) battleLogState([]))

return battleLogState
