enum RespawnOptUpdBit {
  NEVER         = 0x00
  UNIT_ID       = 0x01
  UNIT_WEAPONS  = 0x02
  RESPAWN_BASES = 0x04
  SMOKE_TYPE    = 0x08
  SQUAD_RESPAWN = 0x10
}

enum RespawnBaseType {
  AUTO = "auto"
  AIRFIELD = "airfield"
  AIR = "air"
  CARRIER_CATAPULT = "carrier_catapult"
  CARRIER_TRAMPOLINE = "carrier_trampline"
}

const CATAPULT_CARRIER_SPAWN_NAME = "missions/catapult_carriers_spawn"
const TRAMPOLINE_CARRIER_SPAWN_NAME = "missions/trampline_carriers_spawn"

return { RespawnOptUpdBit, RespawnBaseType, CATAPULT_CARRIER_SPAWN_NAME, TRAMPOLINE_CARRIER_SPAWN_NAME }