let extWatched = require("%rGui/globals/extWatched.nut")

let isInitializedMeasureUnits =
  extWatched("isInitializedMeasureUnits", @() ::cross_call.measureUnits.isInitialized())

return {
  isInitializedMeasureUnits
}
