import "%rGui/globals/extWatched.nut" as extWatched
from "%rGui/globals/ui_library.nut" import *

let measureUnitsNames = extWatched("measureUnitsNames", null)
let isInitializedMeasureUnits = Computed(@() measureUnitsNames.get() != null)

return {
  isInitializedMeasureUnits
  measureUnitsNames
}
