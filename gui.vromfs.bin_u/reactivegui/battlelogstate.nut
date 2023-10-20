from "%rGui/globals/ui_library.nut" import *

let { subscribe } = require("eventbus")

let battleLogState = mkWatched(persist, "battleLogState", [])

subscribe("pushBattleLogEntry", @(logEntry) battleLogState.mutate(@(v) v.append(logEntry)))
subscribe("clearBattleLog", @(_) battleLogState([]))

return battleLogState
