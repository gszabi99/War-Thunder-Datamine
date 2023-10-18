from "%rGui/globals/ui_library.nut" import *

let { isEqual } = require("%sqstd/underscore.nut")
let { subscribe } = require("eventbus")

let statusText = mkWatched(persist, "statusText", "")
let statusTextBottom = mkWatched(persist, "statusTextBottom", "")
let showOrder = mkWatched(persist, "showOrder", false)
let scoresTable = mkWatched(persist, "scoresTable", [])

let function orderStateUpdate(params) {
  statusText(params.statusText)
  statusTextBottom(params.statusTextBottom)
  showOrder(params.showOrder)
  if (!isEqual(params.scoresTable, scoresTable.value))
    scoresTable(params.scoresTable)
}

subscribe("orderStateUpdate", orderStateUpdate)

return {
  statusText
  statusTextBottom
  showOrder
  scoresTable
}
