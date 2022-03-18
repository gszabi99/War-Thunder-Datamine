let extWatched = require("reactiveGui/globals/extWatched.nut")

let isInitializedMeasureUnits =
  extWatched("isInitializedMeasureUnits", @() ::cross_call.measureUnits.isInitialized())

return {
  isInitializedMeasureUnits
}
