const RESPAWN_COUNT_MODE = {
  UNLIMITED = -2
  ONE_FOR_EACH_CREW = -1
  SINGLE_SPAWN = 1
  
}

const function [pure] isRespawnAllowed(respawnCountMode) {
  return respawnCountMode != RESPAWN_COUNT_MODE.SINGLE_SPAWN
}

const function [pure] getSpawnsLimitByMissionParam(respawnCountMode) {
  return respawnCountMode >= RESPAWN_COUNT_MODE.SINGLE_SPAWN ? respawnCountMode : null
}

return const {
  RESPAWN_COUNT_MODE
  isRespawnAllowed
  getSpawnsLimitByMissionParam
}
