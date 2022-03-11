local unitTypes = require("scripts/unit/unitTypesList.nut")
local { INVALID, AIRCRAFT, TANK, SHIP, HELICOPTER, BOAT } = require("scripts/unit/baseUnitTypes.nut")

unitTypes.addTypes([INVALID, AIRCRAFT, TANK, SHIP, HELICOPTER, BOAT])