import "%sqStdLibs/helpers/u.nut" as u
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv, broadcastEvent
from "%globalScripts/clientState/initialState.nut" import disableNetwork
from "string" import startswith
from "dagor.workcycle" import clearTimer, resetTimeout
from "json" import parse_json
from "%scripts/dagui_natives.nut" import is_online_available
from "app" import is_dev_version
from "%scripts/dagui_library.nut" import *

let { isCustomGameMode } = require("%scripts/events/eventsState.nut")
let { getCountriesByTeams } = require("%scripts/events/eventTeamsInfo.nut")
let { getEventEconomicName } = require("%scripts/events/eventInfo.nut")
let { checkMatchingError } = require("%scripts/matching/api.nut")
let { MATCHING_EVENTS_DATA_RECEIVED } = require("%scripts/crossModuleEvents.nut")
let { startLogout } = require("%scripts/login/logout.nut")
let { fetchGameModesDigest, fetchGameModesInfo } = require("%scripts/matching/serviceNotifications/match.nut")





const MAX_FETCH_RETRIES = 5

const MAX_GAME_MODES_FOR_REQUEST_INFO = 5

const NIGHT_GAME_MODE_TAG_PREFIX = "regular_with_night_"
const SMALL_TEAMS_GAME_MODE_TAG_PREFIX = "small_teams_"
const BULLET_HELL_GAME_MODE_TAG_PREFIX = "bullet_hell_"
const NAVAL_EC_AB_GAME_MODE_TAG_PREFIX = "naval_ec_ab_"
const NAVAL_EC_RB_GAME_MODE_TAG_PREFIX = "naval_ec_rb_"
const NUCLEAR_ESCALATION_GAME_MODE_TAG_PREFIX = "nuclear_escalation_"

const SUB_GAME_MODE_TAG_PREFIXES = [
  BULLET_HELL_GAME_MODE_TAG_PREFIX,
  NAVAL_EC_AB_GAME_MODE_TAG_PREFIX,
  NAVAL_EC_RB_GAME_MODE_TAG_PREFIX,
  NUCLEAR_ESCALATION_GAME_MODE_TAG_PREFIX,
  SMALL_TEAMS_GAME_MODE_TAG_PREFIX,
  NIGHT_GAME_MODE_TAG_PREFIX,
]

const BOT_FALLBACK_GAME_MODE_TAGS = [
  "all_v_all_bot",
  "player_v_bots",
]

let isSubGameMode = @(gameMode) gameMode?.tag != null
  && SUB_GAME_MODE_TAG_PREFIXES.findindex(@(prefix) startswith(gameMode.tag, prefix)) != null

let isBotFallbackGameMode = @(gameMode) isInArray(gameMode?.tag, BOT_FALLBACK_GAME_MODE_TAGS)

let gameModes = {} 
local queueGameModesForRequest = []
local fetching = false
local fetchingInfo = false
local fetch_counter = 0
local needForceUpdateOnReconnect = false
let needShowGameModesNotLoadedMsg = Watched(false)

let hideModesNotLoadedHelpMessage = @() needShowGameModesNotLoadedMsg.set(false)

let showModesNotLoadedHelpMessage = @() needShowGameModesNotLoadedMsg.set(true)

function notifyGmChanged() {
  let gameEventsOldFormat = {}
  let modes = gameModes.values()
  modes.sort(@(a, b) a.gameModeId - b.gameModeId)
  foreach (modeInfo in modes) {
    let name = modeInfo.name
    if (name in gameEventsOldFormat)
      continue
    if (isCustomGameMode(modeInfo) || isSubGameMode(modeInfo) || isBotFallbackGameMode(modeInfo))
      continue
    if ("team" in modeInfo && !("teamA" in modeInfo) && !("teamB" in modeInfo))
      modeInfo.teamA <- modeInfo.team
    gameEventsOldFormat[name] <- modeInfo
  }
  broadcastEvent(MATCHING_EVENTS_DATA_RECEIVED, { eventsData = gameEventsOldFormat })
}

function onGameModesUpdated(modes_list_str) {
  let modes_list = parse_json(modes_list_str)
  foreach (modeInfo in modes_list) {
    let gameModeId = modeInfo.gameModeId
    log($"matching game mode fetched '{modeInfo.name}.{modeInfo.tag}' [{gameModeId}] chapter {modeInfo?.chapter}")
    gameModes[gameModeId] <- modeInfo
  }
}

function addGmListToQueue(gmList) {
  if (queueGameModesForRequest.len() == 0) {
    queueGameModesForRequest = gmList
    return
  }
  foreach (mode in gmList)
    u.appendOnce(mode, queueGameModesForRequest)
}

function getGmListFromQueue() {
  let res = queueGameModesForRequest.slice(0, MAX_GAME_MODES_FOR_REQUEST_INFO)
  queueGameModesForRequest = queueGameModesForRequest.slice(MAX_GAME_MODES_FOR_REQUEST_INFO)
  return res
}

function loadGameModesFromList(gm_list) {
  if (fetchingInfo || !is_online_available()) {
    addGmListToQueue(gm_list)
    return
  }
  fetchingInfo = true
  let self = callee()
  if (gm_list.len() > MAX_GAME_MODES_FOR_REQUEST_INFO) {
    addGmListToQueue(gm_list.slice(MAX_GAME_MODES_FOR_REQUEST_INFO))
    gm_list = gm_list.slice(0, MAX_GAME_MODES_FOR_REQUEST_INFO)
  }
  fetchGameModesInfo({ byId = gm_list, asString = true, timeout = 60 },
    function (result) {
      fetchingInfo = false
      if (!checkMatchingError(result, false)) {
        self(gm_list)
        return
      }
      if ("modes_str" in result)
        onGameModesUpdated(result.modes_str)
      if (queueGameModesForRequest.len() == 0) {
        notifyGmChanged()
        clearTimer(showModesNotLoadedHelpMessage)
        hideModesNotLoadedHelpMessage()
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
        if (!is_online_available()) {
          needForceUpdateOnReconnect = true
          return
        }
        log($"fetch gamemodes error, retry - {fetch_counter}")
        self()
      }
    }
  )
  resetTimeout(30, showModesNotLoadedHelpMessage)
}

function forceUpdateGameModes() {
  if (!is_online_available() || disableNetwork) {
    needForceUpdateOnReconnect = true
    return
  }

  fetching = false
  fetch_counter = 0
  fetchGameModes()
}

forceUpdateGameModes()

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
      let tag      = modeInfo?.tag ?? ""
      let disabled = modeInfo?.disabled
      let visible  = modeInfo?.visible
      let active   = modeInfo?.active

      log($"matching game mode {disabled ? "disabled" : "enabled"} '{name}.{tag}' [{gameModeId}]")

      if (disabled && visible == false && active == false) {
        needNotify = true
        removeGameMode(gameModeId)
        continue
      }

      needToFetchGmList.append(gameModeId) 

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

function getGameModeIdsByEconomicNameWithTagFilter(economicName, tagPrefixes, shouldKeepTags) {
  let res = []
  foreach (id, gm in gameModes) {
    if (getEventEconomicName(gm) != economicName)
      continue

    let tag = gm?.tag ?? ""
    let hasPrefix = tagPrefixes.findindex(@(t) startswith(tag, t)) != null
    if (hasPrefix == shouldKeepTags)
      res.append(id)
  }
  return res
}

let getGameModeIdsByEconomicNameWithoutTags = @(economicName, tagsToEcxlude)
  getGameModeIdsByEconomicNameWithTagFilter(economicName, tagsToEcxlude, false)

let getGameModeIdsByEconomicNameWithOnlyTags = @(economicName, tagsToKeep)
  getGameModeIdsByEconomicNameWithTagFilter(economicName, tagsToKeep, true)

function getGameModeWithTagContains(tag) {
  foreach (gm in gameModes)
    if (gm?.tag != null && gm.tag.contains(tag))
      return gm
  return null
}

function getModeById(gameModeId) {
  return gameModes?[gameModeId]
}

addListenersWithoutEnv({
  function MatchingConnect(_) {
    if (needForceUpdateOnReconnect) {
      needForceUpdateOnReconnect = false
      queueGameModesForRequest.clear()
      forceUpdateGameModes()
      return
    }

    if (queueGameModesForRequest.len() > 0 && !fetchingInfo)
      loadGameModesFromList(getGmListFromQueue())
  }
  function SignOut(_) {
    gameModes.clear()
    queueGameModesForRequest.clear()
    fetching = false
    fetchingInfo = false
    fetch_counter = 0
  }
  
  LoginComplete   = @(_) forceUpdateGameModes()
  NotifyGameModesChanged = @(p) onGameModesChangedNotify(p?.added, p?.removed, p?.changed)
})















function getAllCountriesSets(event) {
  if ("_allCountriesSets" in event)
    return event._allCountriesSets

  let res = []
  let mgmList = getGameModesByEconomicName(getEventEconomicName(event))
  mgmList.sort(function(a, b) { return a.gameModeId - b.gameModeId }) 
  foreach (mgm in mgmList) {
    if (isCustomGameMode(mgm))
      continue

    let countries = getCountriesByTeams(mgm)
    local cSet = u.search(res, @(set) u.isEqual(set.countries, countries))

    if (!cSet) {
      cSet = {
        countries = countries
        gameModeIds = []
        allCountries = {}
      }
      foreach (team, teamCountries in countries)
        foreach (country in teamCountries)
          cSet.allCountries[country] <- team
      res.append(cSet)
    }

    cSet.gameModeIds.append(mgm.gameModeId)
  }

  event._allCountriesSets <- res
  return event._allCountriesSets
}

return {
  getAllCountriesSets
  forceUpdateGameModes
  getModeById
  getGameModesByEconomicName
  getGameModeIdsByEconomicName
  getGameModeIdsByEconomicNameWithoutTags
  getGameModeIdsByEconomicNameWithOnlyTags
  getGameModeWithTagContains
  isSubGameMode
  NIGHT_GAME_MODE_TAG_PREFIX
  SMALL_TEAMS_GAME_MODE_TAG_PREFIX
  BULLET_HELL_GAME_MODE_TAG_PREFIX
  NAVAL_EC_AB_GAME_MODE_TAG_PREFIX
  NAVAL_EC_RB_GAME_MODE_TAG_PREFIX
  NUCLEAR_ESCALATION_GAME_MODE_TAG_PREFIX
  needShowGameModesNotLoadedMsg
}
