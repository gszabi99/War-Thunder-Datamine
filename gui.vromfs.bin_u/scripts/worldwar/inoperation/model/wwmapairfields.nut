//checked for plus_string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")
let { wwGetPlayerSide } = require("worldwar")

local savedAirfields = {}

let function reset() {
  savedAirfields = {}
}

let function updateMapIcons() {
  if (!::g_world_war.haveManagementAccessForAnyGroup())
    return

  let curAirfields = {}
  let airfields = ::g_world_war.getAirfieldsArrayBySide(wwGetPlayerSide())
  foreach (airfield in airfields)
    if (airfield.isValid())
      curAirfields[airfield.getIndex()] <- {
        hasUnitsToFly = airfield.hasEnoughUnitsToFly()
        unitsAmount = airfield.getUnitsNumber(false)
        zoneName = ::ww_get_zone_name(::ww_get_zone_idx_world(airfield.getPos()))
        spriteType = airfield.airfieldType.spriteType
      }

  foreach (idx, airfield in curAirfields) {
    let lastAirfield = savedAirfields?[idx] ?? {}
    if (u.isEqual(airfield, lastAirfield))
      continue

    let spriteType = airfield.spriteType
    if ((airfield.hasUnitsToFly && airfield.hasUnitsToFly != lastAirfield?.hasUnitsToFly)
         || (airfield.unitsAmount > (lastAirfield?.unitsAmount ?? 0)))
      ::ww_turn_on_sector_sprites(spriteType, [airfield.zoneName], 5000)
    else if (!airfield.hasUnitsToFly && airfield.hasUnitsToFly != lastAirfield?.hasUnitsToFly)
      ::ww_turn_off_sector_sprites(spriteType, [airfield.zoneName])
  }

  savedAirfields = curAirfields
}

return {
  reset
  updateMapIcons
}
