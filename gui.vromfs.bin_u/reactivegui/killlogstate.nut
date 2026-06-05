from "%rGui/globals/ui_library.nut" import *

let { eventbus_subscribe } = require("eventbus")

let killLogState = mkWatched(persist, "killLogState", [])

function addKillLogMessage(logEntry) {
  killLogState.mutate(@(v) v.append(logEntry))
}

eventbus_subscribe("pushKillLogEntry", addKillLogMessage )
eventbus_subscribe("clearBattleLog", @(_) killLogState.set([]))

return killLogState