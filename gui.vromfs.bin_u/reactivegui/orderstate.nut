from "%rGui/globals/ui_library.nut" import *

let { isEqual } = require("%sqstd/underscore.nut")
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
  if (!isEqual(params.scoresTable, state.scoresTable.value))
    state.scoresTable(params.scoresTable)
}

subscribe("orderStateUpdate", orderStateUpdate)

return state
