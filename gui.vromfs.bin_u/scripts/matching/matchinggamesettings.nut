from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let logGM = log_with_prefix("[Matching_Game_Setting] ")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { setTimeout } = require("dagor.workcycle")

const MAX_FETCH_RETRIES = 5

let matchingGameSettings = persist("matchingGameSettings", @() Watched({}))
local isFetching = false
local failedFetches = 0

let function fetchMatchingGameSetting() {
  if (isFetching || !::is_online_available())
    return

  isFetching = true
  logGM($"fetchMatchingGameSetting (try {failedFetches})")
  let again = callee()
  ::matching.rpc_call("wtmm_static.fetch_game_settings",
    { timeout = 60 },
    function (result) {
      isFetching = false

      if (result.error == OPERATION_COMPLETE)
      {
        failedFetches = 0
        matchingGameSettings(result)
        return
      }

      if (++failedFetches <= MAX_FETCH_RETRIES)
        setTimeout(0.1, again)
    })
}

let function onMatchingConnect() {
  isFetching = false
  failedFetches = 0
  fetchMatchingGameSetting()
}

addListenersWithoutEnv({
  MatchingConnect = @(_) onMatchingConnect()
  ScriptsReloaded = @(_) fetchMatchingGameSetting()
  SignOut         = @(_) matchingGameSettings({})
})

::matching.subscribe("wtmm_static.notify_games_settings_changed",
  @(gSettings) matchingGameSettings(gSettings))

return matchingGameSettings
