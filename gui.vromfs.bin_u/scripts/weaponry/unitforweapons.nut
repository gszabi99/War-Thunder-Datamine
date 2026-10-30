from "%scripts/dagui_library.nut" import *

let unitNameForWeapons = mkHardPersistWatched("weaponry.unitForWeapons")("unitNameForWeapons", "")

return freeze({
  unitNameForWeapons
})