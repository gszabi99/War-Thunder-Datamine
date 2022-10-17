from "%rGui/globals/ui_library.nut" import *

let {interop} = require("%rGui/globals/interop.nut")

let state = persist("battleLogState", @(){
  log = Watched([])
})

interop.pushBattleLogEntry <- function (log_entry) {
  state.log.value.append(log_entry)
  state.log.trigger()
}

interop.clearBattleLog <- function () {
  state.log.update([])
}

return state
