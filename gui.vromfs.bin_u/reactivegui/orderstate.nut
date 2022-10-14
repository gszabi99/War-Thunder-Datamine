from "%rGui/globals/ui_library.nut" import *

let {interop} = require("%rGui/globals/interop.nut")

let state = persist("orderState", @() {
  statusText = Watched("")
  statusTextBottom = Watched("")
  showOrder = Watched(false)
  scoresTable = Watched([])
})

interop.orderStateUpdate <- function (params) {
    state.statusText(params.statusText)
    state.statusTextBottom(params.statusTextBottom)
    state.showOrder(params.showOrder)
    state.scoresTable(params.scoresTable)
}


return state
