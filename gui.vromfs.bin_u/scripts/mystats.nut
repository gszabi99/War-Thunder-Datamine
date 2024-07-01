from "%scripts/dagui_natives.nut" import stat_get_value_time_played, get_player_public_stats, req_player_public_statinfo
from "%scripts/dagui_library.nut" import *
from "%scripts/mainConsts.nut" import SEEN
let u = require("%sqStdLibs/helpers/u.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { loadLocalByAccount, saveLocalByAccount
} = require("%scripts/clientState/localProfileDeprecated.nut")
let seenTitles = require("%scripts/seen/seenList.nut").get(SEEN.TITLES)
let { broadcastEvent, addListenersWithoutEnv, CONFIG_VALIDATION
} = require("%sqStdLibs/helpers/subscriptions.nut")
let DataBlock = require("DataBlock")
let { getUnitClassTypesByEsUnitType } = require("%scripts/unit/unitClassType.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { getPlayerStatsFromBlk } = require("%scripts/user/userInfoStats.nut")
let { getFirstChosenUnitType } = require("%scripts/firstChoice/firstChoice.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { get_time_msec } = require("dagor.time")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { getEsUnitType } = require("%scripts/unit/unitInfo.nut")
let { get_game_settings_blk } = require("blkGetters")
let { userIdStr } = require("%scripts/user/profileStates.nut")
let { getSlotbarUnitTypes } = require("%scripts/slotbar/slotbarState.nut")
let { addBgTaskCb } = require("%scripts/tasker.nut")
let { getCrewUnit } = require("%scripts/crew/crew.nut")
let { getCrewsList } = require("%scripts/slotbar/crewsList.nut")
let { MAX_COUNTRY_RANK } = require("%scripts/ranks.nut")

/*
  getStats() - Returns stats or null if stats have not been received yet. Requests stats update when needed.
    Broadcasts the event "MyStatsUpdated" after receiving the result.
  markStatsReset() - Marks stats for resetting to update them with the next request.
  isStatsLoaded() - Returns a boolean indicating whether the stats are loaded.
  isMeNewbie() - Returns a boolean indicating whether the player is a newbie based on stats.
  isNewbieEventId(eventId) - Returns a boolean indicating whether the event is in the newbie events list in the config.
*/

local summaryNameArray = [
  "pvp_played"
  "skirmish_played"
  "dynamic_played"
  "campaign_played"
  "builder_played"
  "other_played"
  "single_played"
]

const UPDATE_DELAY = 3600000 //once per hour, we have to force update after each battle or debriefing.
let newPlayersBattles = {}
let newbieByUnitType = {}
let newbieNextEvent = {}
let unitTypeByNewbieEventId = {}
local needRecountNewbie = true
local myStats = null
local lastUpdate = -10000000
local isInUpdate = false
local resetStats = false
local maxUnitsUserRank = null
local newbie = null

function getTitles(showHidden = false) {
  let titles = getTblValue("titles", myStats, [])
  if (showHidden)
    return titles

  for (local i = titles.len() - 1; i >= 0 ; --i) {
    let titleUnlock = getUnlockById(titles[i])
    if (!titleUnlock || titleUnlock?.hidden)
      titles.remove(i)
  }

  return titles
}

function updateMyStats() {
  if (!::g_login.isLoggedIn())
    return

  let blk = DataBlock()
  get_player_public_stats(blk)

  if (!blk)
    return

  myStats = getPlayerStatsFromBlk(blk)
  seenTitles.onListChanged()
  broadcastEvent("MyStatsUpdated")
}

function requestMyStats() {
  if (!::g_login.isLoggedIn())
    return

  let time = get_time_msec()
  if (isInUpdate && time - lastUpdate < 45000)
    return
  if (!resetStats && myStats && time - lastUpdate < UPDATE_DELAY) //once per 15min
    return

  isInUpdate = true
  lastUpdate = time
  addBgTaskCb(req_player_public_statinfo(userIdStr.value),
    function () {
      isInUpdate = false
      resetStats = false
      needRecountNewbie = true
      updateMyStats()
    })
}

/**
 * Determines whether the user is a newbie based on their stats.
 * Note: This function is for internal use only.
 * The result may be inconsistent if there are no stats available.
 */
function getIsNewbie() {
  foreach (_esUnitType, isNewbie in newbieByUnitType)
    if (!isNewbie)
      return false
  return true
}

function loadLocalNewbieData() {
  if (!::g_login.isProfileReceived())
    return

  let newbieEndByArmyId = loadLocalAccountSettings("myStats/newbieEndedByArmyId", null)
  if (!newbieEndByArmyId)
    return

  foreach (unitType in unitTypes.types) {
    if (!unitType.isAvailable() || !unitType.isPresentOnMatching)
      continue

    let isNewbieEnded = newbieEndByArmyId?[unitType.armyId] ?? false
    if (isNewbieEnded)
      newbieByUnitType[unitType.esUnitType] <- false
  }

  newbie = getIsNewbie()
}

function isStatsLoaded() {
  return myStats != null
}

function clearStats() {
  myStats = null
}

function getStats() {
  requestMyStats()
  return myStats
}

function getClassFlags(unitType) {
  if (unitType == ES_UNIT_TYPE_AIRCRAFT)
    return CLASS_FLAGS_AIRCRAFT
  if (unitType == ES_UNIT_TYPE_TANK)
    return CLASS_FLAGS_TANK
  if (unitType == ES_UNIT_TYPE_SHIP)
    return CLASS_FLAGS_SHIP
  if (unitType == ES_UNIT_TYPE_HELICOPTER)
    return CLASS_FLAGS_HELICOPTER
  if (unitType == ES_UNIT_TYPE_BOAT)
    return CLASS_FLAGS_BOAT
  return (1 << EUCT_TOTAL) - 1
}

/**
  * Returns the sum of specified fields in player statistics.
  *
  *  summaryName - The game mode. Available values:
  *  - pvp_played
  *  - skirmish_played
  *  - dynamic_played
  *  - campaign_played
  *   -builder_played
  *  - other_played
  *  - single_played

  *  filter - Table configuration {
  *    addArray - array of fields to sum
  *    subtractArray - array of fields to subtract
  *    unitType - unit type filter; if not specified, getting both
  *  }
  */
function getSummary(summaryName, filter = {}) {
  local res = 0
  let pvpSummary = getTblValue(summaryName, getTblValue("summary", myStats))
  if (!pvpSummary)
    return res

  let roles = getUnitClassTypesByEsUnitType(filter?.unitType).map(@(t) t.expClassName)

  foreach (_idx, diffData in pvpSummary)
    foreach (unitRole, data in diffData) {
      if (!isInArray(unitRole, roles))
        continue

      foreach (param in getTblValue("addArray", filter, []))
        res += getTblValue(param, data, 0)
      foreach (param in getTblValue("subtractArray", filter, []))
        res -= getTblValue(param, data, 0)
    }
  return res
}

function getPvpRespawns() {
  return getSummary("pvp_played", { addArray = ["respawns"] })
}

function getPvpRespawnsOnUnitType(unitType) {
  return getSummary("pvp_played", {
    unitType
    addArray = ["respawns"]
  })
}

function getKillsOnUnitType(unitType) {
  return getSummary("pvp_played", {
    addArray = ["air_kills", "ground_kills", "naval_kills"],
    subtractArray = ["air_kills_ai", "ground_kills_ai", "naval_kills_ai"]
    unitType
  })
}

function getTimePlayedOnUnitType(unitType) {
  return getSummary("pvp_played", {
    addArray = ["timePlayed"]
    unitType
  })
}

function calculateMaxUnitsUsedRanks() {
  local needRecalculate = false
  let loadedBlk = loadLocalByAccount("tutor/newbieBattles/unitsRank", DataBlock())
  foreach (unitType in unitTypes.types)
    if (unitType.isAvailable()
        && (loadedBlk?[unitType.esUnitType.tostring()] ?? 0) < MAX_COUNTRY_RANK) {
      needRecalculate = true
      break
    }

  if (!needRecalculate)
    return loadedBlk

  let saveBlk = DataBlock()
  saveBlk.setFrom(loadedBlk)
  let countryCrewsList = getCrewsList()
  foreach (countryCrews in countryCrewsList)
    foreach (crew in getTblValue("crews", countryCrews, [])) {
      let unit = getCrewUnit(crew)
      if (unit == null)
        continue

      let curUnitType = getEsUnitType(unit)
      saveBlk[curUnitType.tostring()] = max(getTblValue(curUnitType.tostring(), saveBlk, 0), unit?.rank ?? -1)
    }

  if (!u.isEqual(saveBlk, loadedBlk))
    saveLocalByAccount("tutor/newbieBattles/unitsRank", saveBlk)

  return saveBlk
}

function checkUnitInSlot(requiredUnitRank, unitType) {
  if (maxUnitsUserRank == null)
    maxUnitsUserRank = calculateMaxUnitsUsedRanks()

  return requiredUnitRank <= getTblValue(unitType.tostring(), maxUnitsUserRank, 0)
}

function checkRecountNewbie() {
  let statsLoaded = isStatsLoaded()
  // When modifying the newbie recount,
  // remember to check if the stats are loaded for the newbie tutor.

  if (!needRecountNewbie || !statsLoaded) {
    if (!statsLoaded || (newbie ?? false))
      requestMyStats()
    return
  }

  needRecountNewbie = false

  let newbieEndByArmyId = ::g_login.isProfileReceived()
    ? loadLocalAccountSettings("myStats/newbieEndedByArmyId", {})
    : null

  newbieByUnitType.clear()
  foreach (unitType in unitTypes.types) {
    if (!unitType.isAvailable() || !unitType.isPresentOnMatching)
      continue

    let isNewbieEnded = newbieEndByArmyId?[unitType.armyId] ?? false
    if (isNewbieEnded) {
      newbieByUnitType[unitType.esUnitType] <- false
      continue
    }

    let killsReq = newPlayersBattles?[unitType.esUnitType]?.minKills ?? 0
    if (killsReq <= 0)
      continue

    local kills = getKillsOnUnitType(unitType.esUnitType)
    let additionalUnitTypes = newPlayersBattles?[unitType.esUnitType].additionalUnitTypes ?? []
    foreach (addEsUnitType in additionalUnitTypes)
      kills += getKillsOnUnitType(::getUnitTypeByText(addEsUnitType))

    newbieByUnitType[unitType.esUnitType] <- (kills < killsReq)

    if (newbieEndByArmyId)
      newbieEndByArmyId[unitType.armyId] <- !newbieByUnitType[unitType.esUnitType]
  }

  if (newbieEndByArmyId)
    saveLocalAccountSettings("myStats/newbieEndedByArmyId", newbieEndByArmyId)

  newbie = getIsNewbie()
  newbieNextEvent.clear()

  foreach (unitType, config in newPlayersBattles) {
    local event = null
    local kills = getKillsOnUnitType(unitType)
    local timePlayed = getTimePlayedOnUnitType(unitType)
    let additionalUnitTypes = config?.additionalUnitTypes ?? []
    foreach (addEsUnitType in additionalUnitTypes) {
      kills += getKillsOnUnitType(::getUnitTypeByText(addEsUnitType))
      timePlayed += getTimePlayedOnUnitType(::getUnitTypeByText(addEsUnitType))
    }
    foreach (evData in config.battles) {
      if (kills >= evData.kills)
        continue
      if (timePlayed >= evData.timePlayed)
        continue
      if (evData.unitRank && checkUnitInSlot(evData.unitRank, unitType))
        continue
      event = ::events.getEvent(evData.event)
      if (event)
        break
    }
    if (event)
      newbieNextEvent[unitType] <- event
  }
}

function resetStatsParams() {
  clearStats()
  isInUpdate = false
  resetStats = false
  newbie = null
  newbieNextEvent.clear()
  needRecountNewbie = true
  maxUnitsUserRank = null
}

function getSummaryFromProfile(func, unitType = null, diff = null, mode = 1 /*domination*/ ) {
  local res = 0.0
  let classFlags = getClassFlags(unitType)
  for (local i = 0; i < EUCT_TOTAL; ++i)
    if (classFlags & (1 << i)) {
      if (diff != null)
        res += func(diff, i, mode)
      else
        for (local d = 0; d < 3; ++d)
          res += func(d, i, mode)
    }
  return res
}

function getUserstat(paramName) {
  local res = 0
  foreach (_, block in myStats?.userstat ?? {})
    foreach (unitData in block?.total ?? [])
      res += (unitData?[paramName] ?? 0)

  return res
}

// public

function getTotalTimePlayedSec() {
  local sec = 0
  foreach (modeBlock in myStats?.summary ?? {})
    foreach (diffBlock in modeBlock)
      foreach (unitTypeBlock in diffBlock)
        sec += (unitTypeBlock?.timePlayed ?? 0)
  return sec
}

function markStatsReset() {
  resetStats = true
}

let isNewbieInited = @() newbie != null

function isMeNewbie() {
  checkRecountNewbie()
  if (newbie == null)
    loadLocalNewbieData()
  return newbie ?? false
}

function isMeNewbieOnUnitType(esUnitType) {
  checkRecountNewbie()
  if (newbie == null)
    loadLocalNewbieData()
  return newbieByUnitType?[esUnitType] ?? false
}

function getPvpPlayed() {
  return getUserstat("sessions")
}

function getTimePlayed(unitType = null, diff = null) {
  return getSummaryFromProfile(stat_get_value_time_played, unitType, diff)
}

function isNewbieEventId(eventName) {
  foreach (config in newPlayersBattles)
    foreach (evData in config.battles)
      if (eventName == evData.event)
        return true
  return false
}

function getUnitTypeByNewbieEventId(eventId) {
  return getTblValue(eventId, unitTypeByNewbieEventId, ES_UNIT_TYPE_INVALID)
}

function getNextNewbieEvent(country = null, unitType = null, checkSlotbar = true) { //return null when no newbie event
  checkRecountNewbie()
  if (!country)
    country = profileCountrySq.value

  if (unitType == null) {
    unitType = getFirstChosenUnitType(ES_UNIT_TYPE_AIRCRAFT)
    if (checkSlotbar) {
      let types = getSlotbarUnitTypes(country)
      if (types.len() && !isInArray(unitType, types))
        unitType = types[0]
    }
  }
  return getTblValue(unitType, newbieNextEvent)
}

function onEventInitConfigs(_) {
  let settingsBlk = get_game_settings_blk()
  let blk = settingsBlk?.newPlayersBattles
  if (!blk)
    return

  foreach (unitType in unitTypes.types) {
    let data = {
      minKills = 0
      battles = []
      additionalUnitTypes = []
    }

    let list = blk % unitType.lowerName
    foreach (ev in list) {
      if (!ev.event)
        continue

      unitTypeByNewbieEventId[ev.event] <- unitType.esUnitType
      let kills = ev?.kills || 1
      data.battles.append({
        event       = ev?.event
        kills       = kills
        timePlayed  = ev?.timePlayed ?? 0
        unitRank    = ev?.unitRank ?? 0
      })
      data.minKills = max(data.minKills, kills)
    }

    let additionalUnitTypesBlk = blk?.additionalUnitTypes[unitType.lowerName]
    if (additionalUnitTypesBlk)
      data.additionalUnitTypes = additionalUnitTypesBlk % "type"
    if (data.minKills)
      newPlayersBattles[unitType.esUnitType] <- data
  }
}

function getMissionsComplete(summaryArray = summaryNameArray) {
  local res = 0
  let stasts = getStats()
  foreach (summaryName in summaryArray) {
    let summary = stasts?.summary?[summaryName] ?? {}
    foreach (diffData in summary)
      res += diffData?.missionsComplete ?? 0
  }
  return res
}

function onEventCrewTakeUnit(params) {
  let unitType = getEsUnitType(params.unit)
  let unitRank = params.unit?.rank ?? -1
  let lastMaxRank = maxUnitsUserRank?[unitType.tostring()] ?? 0
  if (lastMaxRank >= unitRank)
    return

  if (maxUnitsUserRank == null)
    maxUnitsUserRank = calculateMaxUnitsUsedRanks()

  maxUnitsUserRank[unitType.tostring()] = unitRank
  saveLocalByAccount("tutor/newbieBattles/unitsRank", maxUnitsUserRank)
  needRecountNewbie = true
}

::my_stats <- {
  getTimePlayed // fixme circ ref
  isNewbieEventId // fixme circ ref
}

seenTitles.setListGetter(@() getTitles())

addListenersWithoutEnv({
  LoginComplete = @(_) requestMyStats()
  UnitBought = @(_) markStatsReset()
  AllModificationsPurchased = @(_) markStatsReset()
  EventsDataUpdated = @(_) needRecountNewbie = true
  SignOut = @(_) resetStatsParams()
  InitConfigs = onEventInitConfigs
  ScriptsReloaded = onEventInitConfigs
  CrewTakeUnit = onEventCrewTakeUnit
}, CONFIG_VALIDATION)

return {
  getTitles
  isStatsLoaded
  isNewbieInited
  getMissionsComplete
  isMeNewbieOnUnitType
  getNextNewbieEvent
  isNewbieEventId
  getUnitTypeByNewbieEventId
  getPvpPlayed
  isMeNewbie
  markStatsReset
  getPvpRespawns
  getPvpRespawnsOnUnitType
  getTimePlayedOnUnitType
  getStats
  clearStats
  getTotalTimePlayedSec

}
