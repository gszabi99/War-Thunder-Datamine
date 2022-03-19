local extWatched = require("reactiveGui/globals/extWatched.nut")

local isInitializedMeasureUnits =
  extWatched("isInitializedMeasureUnits", @() ::cross_call.measureUnits.isInitialized())

return {
  isInitializedMeasureUnits
}
