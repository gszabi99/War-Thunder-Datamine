from "%scripts/dagui_natives.nut" import is_online_available
from "app" import is_dev_version
from "%scripts/dagui_library.nut" import *

let { checkMatchingError } = require("%scripts/matching/api.nut")
let { appendOnce } = require("%sqStdLibs/helpers/u.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { startLogout } = require("%scripts/login/logout.nut")
let { fetchGameModesDigest, fetchGameModesInfo
} = require("%scripts/matching/serviceNotifications/match.nut")
let { getEventEconomicName } = require("%scripts/events/eventInfo.nut")
let { startswith }=require("string")

// -------------------------------------------------------
// Matching game modes managment
// -------------------------------------------------------

const MAX_FETCH_RETRIES = 5

const MAX_GAME_MODES_FOR_REQUEST_INFO = 50

const NIGHT_GAME_MODE_TAG_PREFIX = "regular_with_night_"

let gameModes = {} // game-mode unique id -> mode info
local queueGameModesForRequest = []
local fetching = false
local fetchingInfo = false
local fetch_counter = 0

function notifyGmChanged() {
  let gameEventsOldFormat = {}
  foreach (_gm_id, modeInfo in gameModes) {
    if (::events.isCustomGameMode(modeInfo))
      continue
    if ("team" in modeInfo && !("teamA" in modeInfo) && !("teamB" in modeInfo))
      modeInfo.teamA <- modeInfo.team
    gameEventsOldFormat[modeInfo.name] <- modeInfo
  }
  ::events.updateEventsData(gameEventsOldFormat)
}

function onGameModesUpdated(modes_list) {
  foreach (modeInfo in modes_list) {
    let gameModeId = modeInfo.gameModeId
    log($"matching game mode fetched '{modeInfo.name}' [{gameModeId}]")
    gameModes[gameModeId] <- modeInfo
  }
}

function addGmListToQueue(gmList) {
  if (queueGameModesForRequest.len() == 0) {
    queueGameModesForRequest = gmList
    return
  }
  foreach (mode in gmList)
    appendOnce(mode, queueGameModesForRequest)
}

function getGmListFromQueue() {
  let res = queueGameModesForRequest.slice(0, MAX_GAME_MODES_FOR_REQUEST_INFO)
  queueGameModesForRequest = queueGameModesForRequest.slice(MAX_GAME_MODES_FOR_REQUEST_INFO)
  return res
}

function loadGameModesFromList(gm_list) {
  if (fetchingInfo) {
    addGmListToQueue(gm_list)
    return
  }
  fetchingInfo = true
  let self = callee()
  if (gm_list.len() > MAX_GAME_MODES_FOR_REQUEST_INFO) {
    addGmListToQueue(gm_list.slice(MAX_GAME_MODES_FOR_REQUEST_INFO))
    gm_list = gm_list.slice(0, MAX_GAME_MODES_FOR_REQUEST_INFO)
  }
  fetchGameModesInfo({ byId = gm_list, timeout = 60 },
    function (result) {
      fetchingInfo = false
      if (!checkMatchingError(result, false)) {
        queueGameModesForRequest.clear()
        return
      }

      if ("modes" in result)
        onGameModesUpdated(result.modes)
      if (queueGameModesForRequest.len() == 0) {
        notifyGmChanged()
        return
      }

      self(getGmListFromQueue())
    })
}

function fetchGameModes() {
  if (fetching)
    return

  gameModes.clear()
  fetching = true
  fetch_counter++
  let self = callee()
  fetchGameModesDigest({ timeout = 60 },
    function (result) {
      fetching = false
      let canRetry = fetch_counter < MAX_FETCH_RETRIES
      if (checkMatchingError(result, false)) {
        loadGameModesFromList(result?.modes ?? [])
        fetch_counter = 0
        return
      }

      if (!canRetry) {
        if (!is_dev_version())
          startLogout()
      }
      else {
        log($"fetch gamemodes error, retry - {fetch_counter}")
        self()
      }
    }
  )
}

function forceUpdateGameModes() {
  if (!is_online_available())
    return

  fetching = false
  fetch_counter = 0
  fetchGameModes()
}

function removeGameMode(game_mode_id) {
  gameModes?.$rawdelete(game_mode_id)
}

function onGameModesChangedNotify(added_list, removed_list, changed_list) {
  local needNotify = false
  let needToFetchGmList = []

  if (removed_list) {
    foreach (modeInfo in removed_list) {
      let { gameModeId = -1, name = "" } = modeInfo
      log($"matching game mode removed '{name}' [{gameModeId}]")
      removeGameMode(gameModeId)
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
        removeGameMode(gameModeId)
        continue
      }

      needToFetchGmList.append(gameModeId) //need refresh full mode-info because may updated mode params

      if (disabled == null || visible == null || active == null
          || !(gameModeId in gameModes))
        continue

      needNotify = true
      let fullModeInfo = gameModes[gameModeId]
      fullModeInfo.disabled = disabled
      fullModeInfo.visible = visible
    }
  }

  if (needToFetchGmList.len() > 0)
    loadGameModesFromList(needToFetchGmList)

  if (needNotify)
    notifyGmChanged()
}

function getGameModesByEconomicName(economicName) {
  return gameModes.filter(@(g) getEventEconomicName(g) == economicName).values()
}

function getGameModeIdsByEconomicName(economicName) {
  let res = []
  foreach (id, gm in gameModes)
    if (getEventEconomicName(gm) == economicName)
      res.append(id)
  return res
}

function getGameModeIdsByEconomicNameWithoutNight(economicName) {
  let res = []
  foreach (id, gm in gameModes) {
    if (getEventEconomicName(gm) != economicName)
      continue

    let tag = gm?.tag ?? ""
    if (!startswith(tag, NIGHT_GAME_MODE_TAG_PREFIX))
      res.append(id)
  }
  return res
}

function getModeById(gameModeId) {
  return gameModes?[gameModeId]
}

addListenersWithoutEnv({
  function SignOut(_) {
    gameModes.clear()
    queueGameModesForRequest.clear()
    fetching = false
    fetchingInfo = false
    fetch_counter = 0
  }
  ScriptsReloaded = @(_) forceUpdateGameModes()
  //no need to request gameModes before configs inited
  LoginComplete   = @(_) forceUpdateGameModes()
  NotifyGameModesChanged = @(p) onGameModesChangedNotify(p?.added, p?.removed, p?.changed)
})

return {
  forceUpdateGameModes
  getModeById
  getGameModesByEconomicName
  getGameModeIdsByEconomicName
  getGameModeIdsByEconomicNameWithoutNight
}
