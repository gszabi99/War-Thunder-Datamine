from "%rGui/globals/ui_library.nut" import *

let { subscribe } = require("eventbus")

let state = persist("battleLogState", @(){
  log = Watched([])
})

subscribe("pushBattleLogEntry", @(logEntry) state.log.mutate(@(v) v.append(logEntry)))
subscribe("clearBattleLog", @(_) state.log([]))

return state
