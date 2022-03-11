local state = persist("battleLogState", @(){
  log = Watched([])
})

::interop.pushBattleLogEntry <- function (log_entry) {
  state.log.value.append(log_entry)
  state.log.trigger()
}

::interop.clearBattleLog <- function () {
  state.log.update([])
}

return state
