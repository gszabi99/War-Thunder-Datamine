//-file:plus-string
from "%scripts/dagui_library.nut" import *


let enums = require("%sqStdLibs/helpers/enums.nut")
::g_player_state <- {
  types = []
  cache = {
    byState = {}
  }

  template = {
    stateText = ""
    spectatorIcon = "player_spectator"
    state = -1
    constantColor = "white"
    getIconColor = @() get_main_gui_scene().getConstantValue(this.constantColor) || ""
    getIcon = @(playerInfo) $"#ui/gameuiskin#{this.isSpectator(playerInfo) ? this.spectatorIcon : this.stateText}.svg"

    isSpectator = @(playerInfo) getTblValue("spectator", playerInfo, false)
    getText = function(playerInfo = {}) {
      let stateLoc = this.stateText.len() ? loc("multiplayer/state/" + this.stateText) : ""
      let roleLoc = this.isSpectator(playerInfo) ? loc("multiplayer/state/player_referee") : ""
      return loc("ui/semicolon").join([ roleLoc, stateLoc ], true)
    }
  }
}

enums.addTypesByGlobalName("g_player_state", {
  UNKNOWN = {
    getIcon = @(_playerInfo) ""
    getText = @(_playerInfo) ""
  }
  BOT = {
    stateText = "bot_ready"
  }
  NOT_EXIST = {
    stateText = "player_not_ready"
    state = PLAYER_NOT_EXISTS
    constantColor = "playerNotReadyColor"
  }
  HAS_LEAVED_GAME = {
    stateText = "player_not_ready"
    state = PLAYER_HAS_LEAVED_GAME
    constantColor = "playerNotReadyColor"
  }
  IN_LOBBY_NOT_READY = {
    stateText = "player_not_ready"
    state = PLAYER_IN_LOBBY_NOT_READY
    constantColor = "playerNotReadyColor"
  }
  IN_LOBBY_READY = {
    stateText = "player_ready"
    constantColor = "playerReadyColor"
    state = PLAYER_IN_LOBBY_READY
  }
  IN_LOADING = {
    stateText = "player_not_ready"
    state = PLAYER_IN_LOADING
    constantColor = "playerNotReadyColor"
  }
  IN_STATISTICS_BEFORE_LOBBY = {
    stateText = "player_stats"
    state = PLAYER_IN_STATISTICS_BEFORE_LOBBY
    constantColor = "playerStatsColor"
  }
  READY_TO_START = {
    stateText = "player_ready"
    constantColor = "playerReadyColor"
    state = PLAYER_READY_TO_START
  }
  IN_FLIGHT = {
    stateText = "player_in_game"
    state = PLAYER_IN_FLIGHT
  }
  IN_RESPAWN = {
    stateText = "player_in_game"
    state = PLAYER_IN_RESPAWN
  }
}, null, "name")

::g_player_state.getStateByPlayerInfo <- function getStateByPlayerInfo(playerInfo) {
  if (getTblValue("isBot", playerInfo, false))
    return ::g_player_state.BOT

  return enums.getCachedType("state",
                                      getTblValue("state", playerInfo, ""),
                                      ::g_player_state.cache.byState,
                                      ::g_player_state,
                                      ::g_player_state.UNKNOWN)
}
