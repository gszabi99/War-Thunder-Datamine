local { addListenersWithoutEnv } = require("sqStdLibs/helpers/subscriptions.nut")
local { invert } = require("std/underscore.nut")

local activityToGameMode = {
  air_event_arcade = "air_arcade"
  air_event_historical = "air_realistic"
  air_event_simulator = "custom_mode_fullreal"
  tank_event_arcade = "tank_event_in_random_battles_arcade"
  tank_event_historical = "tank_event_in_random_battles_historical"
  ship_event_arcade = "ship_event_in_random_battles_arcade"
  ship_event_historical = "ship_event_in_random_battles_realistic"
}

local gameModeToActivity = invert(activityToGameMode)
gameModeToActivity["air_simulation_timeDelay_battles"] <- "air_event_simulator"

local function getGameModeByActivity(activity) { return activity && activityToGameMode?[activity] }
local function getActivityByGameMode(mode) { return mode && gameModeToActivity?[mode] }

local function switchGameModeByGameIntent(intent) {
  local gameModeId = getGameModeByActivity(intent.activityId)
  if (gameModeId) {
    ::dagor.debug($"[PSGI] switching game mode to {gameModeId}")
    ::game_mode_manager.setCurrentGameModeById(gameModeId);
    return
  }
  ::dagor.debug($"[PSGI] game mode not found for {intent.activityId} ")
}

local function enableGameIntents() {
  addListenersWithoutEnv({
      GameIntentLaunchActivity = switchGameModeByGameIntent
      GameIntentLaunchMultiplayerActivity = switchGameModeByGameIntent
    })
}

return {
  enableGameIntents
  getGameModeByActivity
  getActivityByGameMode
}


