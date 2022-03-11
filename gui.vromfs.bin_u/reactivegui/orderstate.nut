local state = persist("orderState", @() {
  statusText = Watched("")
  statusTextBottom = Watched("")
  showOrder = Watched(false)
  scoresTable = Watched([])
})

::interop.orderStateUpdate <- function (params) {
    state.statusText(params.statusText)
    state.statusTextBottom(params.statusTextBottom)
    state.showOrder(params.showOrder)
    state.scoresTable(params.scoresTable)
}


return state
