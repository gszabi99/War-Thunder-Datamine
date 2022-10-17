from "%rGui/globals/ui_library.nut" import *
let extWatched = require("%rGui/globals/extWatched.nut")
let { send } = require("eventbus")

let isInitializedMeasureUnits = extWatched("isInitializedMeasureUnits", false)

send("updateIsInitializedMeasureUnits", {})

return {
  isInitializedMeasureUnits
}
