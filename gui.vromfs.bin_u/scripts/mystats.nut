from "%scripts/dagui_natives.nut" import get_player_public_stats, req_player_public_statinfo
from "%scripts/dagui_library.nut" import *
from "%scripts/mainConsts.nut" import SEEN

let u = require("%sqStdLibs/helpers/u.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { loadLocalByAccount, saveLocalByAccount
} = require("%scripts/clientState/localProfileDeprecated.nut")
let seenTitles = require("%scripts/seen/seenList.nut").get(SEEN.TITLES)
let { broadcastEvent, addListenersWithoutEnv
} = require("%sqStdLibs/helpers/subscriptions.nut")
let g_listener_priority = require("%scripts/g_listener_priority.nut")
let DataBlock = require("DataBlock")
let { getUnitClassTypesByEsUnitType } = require("%scripts/unit/unitClassType.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { getPlayerStatsFromBlk } = require("%scripts/user/userInfoStats.nut")
let { getFirstChosenUnitType } = require("%scripts/firstChoice/firstChoice.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { get_time_msec } = require("dagor.time")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { getUnitTypeByText } = require("%scripts/unit/unitInfo.nut")
let { getEsUnitType } = require("%scripts/unit/unitParams.nut")
let { userIdStr } = require("%scripts/user/profileStates.nut")
let { getSlotbarUnitTypes } = require("%scripts/slotbar/slotbarStateData.nut")
let { addBgTaskCb } = require("%scripts/tasker.nut")
let { getCrewUnit } = require("%scripts/crew/crew.nut")
let { getCrewsList } = require("%scripts/slotbar/crewsList.nut")
let { MAX_COUNTRY_RANK } = require("%scripts/ranks.nut")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let { isLoggedIn, isProfileReceived } = require("%appGlobals/login/loginState.nut")
let { register_command } = require("console")
let { getNewPlayersBattlesConfig } = require("%scripts/user/myStatsState.nut")









local summaryNameArray = [
  "pvp_played"
  "skirmish_played"
  "dynamic_played"
  "campaign_played"
  "builder_played"
  "other_played"
  "single_played"
]

const UPDATE_DELAY = 3600000 
let newbieByUnitType = {}
let newbieNextEvent = {}
let killsOnUnitTypes = {}
local needRecountNewbie = true
local myStats = null
local lastUpdate = -10000000
local isInUpdate = false
local resetStats = false
local maxUnitsUserRank = null
local newbie = null
local forcedIsNotNewbie = false

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
  if (!isLoggedIn.get())
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
  if (!isLoggedIn.get())
    return

  let time = get_time_msec()
  if (isInUpdate && time - lastUpdate < 45000)
    return
  if (!resetStats && myStats && time - lastUpdate < UPDATE_DELAY) 
    return

  isInUpdate = true
  lastUpdate = time
  addBgTaskCb(req_player_public_statinfo(userIdStr.get()),
    function () {
      isInUpdate = false
      resetStats = false
      needRecountNewbie = true
      updateMyStats()
    })
}






function getIsNewbie() {
  if (forcedIsNotNewbie)
    return false

  foreach (_esUnitType, isNewbie in newbieByUnitType)
    if (!isNewbie)
      return false
  return true
}

function loadLocalNewbieData() {
  if (!isProfileReceived.get())
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
  
  

  if (!needRecountNewbie || !statsLoaded) {
    if (!statsLoaded || (newbie ?? false))
      requestMyStats()
    return
  }

  needRecountNewbie = false

  let newbieEndByArmyId = isProfileReceived.get()
    ? loadLocalAccountSettings("myStats/newbieEndedByArmyId", {})
    : null

  newbieByUnitType.clear()
  let newPlayersBattles = getNewPlayersBattlesConfig()
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
      kills += getKillsOnUnitType(getUnitTypeByText(addEsUnitType))

    newbieByUnitType[unitType.esUnitType] <- (kills < killsReq)
    killsOnUnitTypes[unitType.esUnitType] <- {
      killsReq = killsReq
      kills = kills
    }

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
      kills += getKillsOnUnitType(getUnitTypeByText(addEsUnitType))
      timePlayed += getTimePlayedOnUnitType(getUnitTypeByText(addEsUnitType))
    }
    foreach (evData in config.battles) {
      if (kills >= evData.kills)
        continue
      if (timePlayed >= evData.timePlayed)
        continue
      if (evData.unitRank && checkUnitInSlot(evData.unitRank, unitType))
        continue
      event = events.getEvent(evData.event)
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

function getUserstat(paramName) {
  local res = 0
  foreach (_, block in myStats?.userstat ?? {})
    foreach (unitData in block?.total ?? [])
      res += (unitData?[paramName] ?? 0)

  return res
}



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
  if (forcedIsNotNewbie)
    return false
  checkRecountNewbie()
  if (newbie == null)
    loadLocalNewbieData()
  return newbie ?? false
}

function isMeNewbieOnUnitType(esUnitType) {
  if (forcedIsNotNewbie)
    return false
  checkRecountNewbie()
  if (newbie == null)
    loadLocalNewbieData()
  return newbieByUnitType?[esUnitType] ?? false
}

function getPvpPlayed() {
  return getUserstat("sessions")
}

function getNextNewbieEvent(country = null, unitType = null, checkSlotbar = true) { 
  if (forcedIsNotNewbie)
    return null

  checkRecountNewbie()
  if (!country)
    country = profileCountrySq.get()

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

seenTitles.setListGetter(@() getTitles())

addListenersWithoutEnv({
  ProfileUpdated = function(_) {
    markStatsReset()
    requestMyStats()
  }
  UnitBought = @(_) markStatsReset()
  AllModificationsPurchased = @(_) markStatsReset()
  EventsDataUpdated = @(_) needRecountNewbie = true
  SignOut = @(_) resetStatsParams()
  CrewTakeUnit = onEventCrewTakeUnit
}, g_listener_priority.LOGIN_PROCESS)


register_command(function() {
  forcedIsNotNewbie = !forcedIsNotNewbie
  broadcastEvent("MyStatsUpdated")
}, "debug.switch_forced_is_not_newbie")

return {
  getTitles
  isStatsLoaded
  isNewbieInited
  getMissionsComplete
  isMeNewbieOnUnitType
  getNextNewbieEvent
  getPvpPlayed
  isMeNewbie
  markStatsReset
  getPvpRespawns
  getPvpRespawnsOnUnitType
  getTimePlayedOnUnitType
  getStats
  clearStats
  getTotalTimePlayedSec
  killsOnUnitTypes
  newbieNextEvent
}
