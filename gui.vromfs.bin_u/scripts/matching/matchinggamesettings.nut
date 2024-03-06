from "%scripts/dagui_natives.nut" import is_online_available
from "%scripts/dagui_library.nut" import *

let { OPERATION_COMPLETE } = require("matching.errors")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { setTimeout } = require("dagor.workcycle")
let { matchingApiFunc, matchingRpcSubscribe } = require("%scripts/matching/api.nut")

let logGM = log_with_prefix("[Matching_Game_Setting] ")

const MAX_FETCH_RETRIES = 5

let matchingGameSettings = mkWatched(persist, "matchingGameSettings", {})
local isFetching = false
local failedFetches = 0

function fetchMatchingGameSetting() {
  if (isFetching || !is_online_available())
    return

  isFetching = true
  logGM($"fetchMatchingGameSetting (try {failedFetches})")
  let again = callee()
  matchingApiFunc("wtmm_static.fetch_game_settings",
    function (result) {
      isFetching = false

      if (result.error == OPERATION_COMPLETE) {
        failedFetches = 0
        matchingGameSettings(result)
        return
      }

      if (++failedFetches <= MAX_FETCH_RETRIES)
        setTimeout(0.1, again)
    },
    { timeout = 60 })
}

function onMatchingConnect() {
  isFetching = false
  failedFetches = 0
  fetchMatchingGameSetting()
}

addListenersWithoutEnv({
  MatchingConnect = @(_) onMatchingConnect()
  ScriptsReloaded = @(_) fetchMatchingGameSetting()
  SignOut         = @(_) matchingGameSettings({})
})

matchingRpcSubscribe("wtmm_static.notify_games_settings_changed",
  @(gSettings) matchingGameSettings(gSettings))

return matchingGameSettings
