from "eventbus" import eventbus_subscribe
from "%rGui/globals/ui_library.nut" import *

let battleLogState = mkWatched(persist, "battleLogState", [])

eventbus_subscribe("pushBattleLogEntry", @(logEntry) battleLogState.mutate(@(v) v.append(logEntry)))
eventbus_subscribe("clearBattleLog", @(_) battleLogState.set([]))

return battleLogState
