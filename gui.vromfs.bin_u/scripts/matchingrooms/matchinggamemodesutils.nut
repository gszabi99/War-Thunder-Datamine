//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let function isGameModeCoop(gm) {
  return gm == -1 || gm == GM_SINGLE_MISSION || gm == GM_BUILDER
}

let function isGameModeVersus(gm) {
  return gm == -1 || gm == GM_SKIRMISH || gm == GM_DOMINATION
}

return {
  isGameModeCoop
  isGameModeVersus
}

