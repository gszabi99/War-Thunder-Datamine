from "%rGui/globals/ui_library.nut" import *

let { subscribe } = require("eventbus")

let state = persist("orderState", @() {
  statusText = Watched("")
  statusTextBottom = Watched("")
  showOrder = Watched(false)
  scoresTable = Watched([])
})

let function orderStateUpdate(params) {
  state.statusText(params.statusText)
  state.statusTextBottom(params.statusTextBottom)
  state.showOrder(params.showOrder)
  state.scoresTable(params.scoresTable)
}

subscribe("orderStateUpdate", orderStateUpdate)

return state
