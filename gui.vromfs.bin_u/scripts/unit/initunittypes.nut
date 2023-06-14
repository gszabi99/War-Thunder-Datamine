//checked for plus_string
from "%scripts/dagui_library.nut" import *

let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { INVALID, AIRCRAFT, TANK, SHIP, HELICOPTER, BOAT } = require("%scripts/unit/baseUnitTypes.nut")

unitTypes.addTypes([INVALID, AIRCRAFT, TANK, SHIP, HELICOPTER, BOAT])