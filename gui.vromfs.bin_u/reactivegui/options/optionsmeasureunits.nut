from "%rGui/globals/ui_library.nut" import *
let extWatched = require("%rGui/globals/extWatched.nut")

let measureUnitsNames = extWatched("measureUnitsNames", null)
let isInitializedMeasureUnits = Computed(@() measureUnitsNames.value != null)

return {
  isInitializedMeasureUnits
  measureUnitsNames
}
