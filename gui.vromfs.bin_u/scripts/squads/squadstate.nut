from "%scripts/dagui_library.nut" import *

let { INVALID_SQUAD_ID } = require("matching.errors")

function isEqualSquadId(squadId1, squadId2) {
  return squadId1 != INVALID_SQUAD_ID && squadId1 == squadId2
}

return {
  isEqualSquadId
}
