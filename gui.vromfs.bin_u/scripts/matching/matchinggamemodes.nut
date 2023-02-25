//-file:plus-string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { get_time_msec } = require("dagor.time")
let { startLogout } = require("%scripts/login/logout.nut")
let { format } = require("string")

// -------------------------------------------------------
// Matching game modes managment
// -------------------------------------------------------

const MAX_FETCH_RETRIES = 5

let requestedGameModesTimeOut = 10000 //ms
local lastRequestTimeMsec = -requestedGameModesTimeOut
local requestedGameModes = []

::g_matching_game_modes <- {
  __gameModes = {} // game-mode unique id -> mode info

  __fetching = false
  __fetch_counter = 0

  function forceUpdateGameModes() {
    if (!::is_online_available())
      return

    this.__fetching = false
    this.__fetch_counter = 0
    this.fetchGameModes()
  }

  function fetchGameModes() {
    if (this.__fetching)
      return

    this.__gameModes.clear()
    this.__fetching = true
    this.__fetch_counter++
    ::fetch_game_modes_digest({ timeout = 60 },
      function (result) {
        if (!this)
          return

        this.__fetching = false

        let canRetry = this.__fetch_counter < MAX_FETCH_RETRIES
        if (::checkMatchingError(result, !canRetry)) {
          this.__loadGameModesFromList(result?.modes ?? [])
          this.__fetch_counter = 0
          return
        }

        if (!canRetry) {
          if (!::is_dev_version)
            startLogout()
        }
        else {
          log("fetch gamemodes error, retry - " + this.__fetch_counter)
          this.fetchGameModes()
        }
      }.bindenv(::g_matching_game_modes)
    )
  }

  function getModeById(gameModeId) {
    return this.__gameModes?[gameModeId]
  }

  function  onGameModesChangedNotify(added_list, removed_list, changed_list) {
    local needNotify = false
    let needToFetchGmList = []

    if (removed_list) {
      foreach (modeInfo in removed_list) {
        let { gameModeId = -1, name = "" } = modeInfo
        log($"matching game mode removed '{name}' [{gameModeId}]")
        this.__removeGameMode(gameModeId)
        needNotify = true
      }
    }

    if (added_list) {
      foreach (modeInfo in added_list) {
        let { gameModeId = -1, name = "" } = modeInfo
        log($"matching game mode added '{name}' [{gameModeId}]")
        needToFetchGmList.append(gameModeId)
      }
    }

    if (changed_list) {
      foreach (modeInfo in changed_list) {
        let gameModeId = modeInfo?.gameModeId
        if (gameModeId == null)
          continue

        let name     = modeInfo?.name ?? ""
        let disabled = modeInfo?.disabled
        let visible  = modeInfo?.visible
        let active   = modeInfo?.active

        log($"matching game mode {disabled ? "disabled" : "enabled"} '{name}' [{gameModeId}]")

        if (disabled && visible == false && active == false) {
          needNotify = true
          this.__removeGameMode(gameModeId)
          continue
        }

        needToFetchGmList.append(gameModeId) //need refresh full mode-info because may updated mode params

        if (disabled == null || visible == null || active == null
            || !(gameModeId in this.__gameModes))
          continue

        needNotify = true
        let fullModeInfo = this.__gameModes[gameModeId]
        fullModeInfo.disabled = disabled
        fullModeInfo.visible = visible
      }
    }

    if (needToFetchGmList.len() > 0)
      this.__loadGameModesFromList(needToFetchGmList)

    if (needNotify)
      this.__notifyGmChanged()
  }

// private section
  function __notifyGmChanged() {
    let gameEventsOldFormat = {}
    foreach (_gm_id, modeInfo in this.__gameModes) {
      if (::events.isCustomGameMode(modeInfo))
        continue
      if ("team" in modeInfo && !("teamA" in modeInfo) && !("teamB" in modeInfo))
        modeInfo.teamA <- modeInfo.team
      gameEventsOldFormat[modeInfo.name] <- modeInfo
    }
    ::events.updateEventsData(gameEventsOldFormat)
  }

  function __removeGameMode(game_mode_id) {
    if (game_mode_id in this.__gameModes)
      delete this.__gameModes[game_mode_id]
  }

  function __onGameModesUpdated(modes_list) {
    foreach (modeInfo in modes_list) {
      let gameModeId = modeInfo.gameModeId
      let idx = requestedGameModes.indexof(gameModeId)
      if (idx != null)
        requestedGameModes.remove(idx)
      log(format("matching game mode fetched '%s' [%d]",
                         modeInfo.name, gameModeId))
      this.__gameModes[gameModeId] <- modeInfo
    }
    this.__notifyGmChanged();
  }

  function __loadGameModesFromList(gm_list) {
    ::fetch_game_modes_info({ byId = gm_list, timeout = 60 },
      function (result) {
        if (!::checkMatchingError(result) || ("modes" not in result))
          return
        ::g_matching_game_modes.__onGameModesUpdated(result.modes)
      })
  }

  function onEventSignOut(_p) {
    this.__gameModes.clear()
    this.__fetching = false
    this.__fetch_counter = 0
  }

  function onEventScriptsReloaded(_p) {
    this.forceUpdateGameModes()
  }

  //no need to request gameModes before configs inited
  function onEventLoginComplete(_p) {
    this.forceUpdateGameModes()
  }

  function getGameModesByEconomicName(economicName) {
    return ::u.filter(this.__gameModes,
      (@(economicName) function(g) { return ::events.getEventEconomicName(g) == economicName })(economicName))
  }

  function requestGameModeById(gameModeId) {
    let isRequested = isInArray(gameModeId, requestedGameModes)
    if (isRequested
      && (get_time_msec() - lastRequestTimeMsec <= requestedGameModesTimeOut))
      return

    if (!isRequested)
      requestedGameModes.append(gameModeId)
    lastRequestTimeMsec = get_time_msec()
    this.__loadGameModesFromList([gameModeId])
  }

  function getGameModeIdsByEconomicName(economicName) {
    let res = []
    foreach (id, gm in this.__gameModes)
      if (::events.getEventEconomicName(gm) == economicName)
        res.append(id)
    return res
  }
}

::subscribe_handler(::g_matching_game_modes)
