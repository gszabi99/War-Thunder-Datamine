//checked for plus_string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")

//checked for explicitness
#no-root-fallback
#explicit-this

let seenTitles = require("%scripts/seen/seenList.nut").get(SEEN.TITLES)
let { subscribe_handler, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let DataBlock = require("DataBlock")
let { getUnitClassTypesByEsUnitType } = require("%scripts/unit/unitClassType.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { getPlayerStatsFromBlk } = require("%scripts/user/userInfoStats.nut")
let { getFirstChosenUnitType } = require("%scripts/firstChoice/firstChoice.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { get_time_msec } = require("dagor.time")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")

/*
my_stats API
   getStats()  - return stats or null if stats not recived yet, and request stats update when needed.
                 broadcast event "MyStatsUpdated" after result receive.
   markStatsReset() - mark stats to reset to update it with the next request.
   isStatsLoaded()

   isMeNewbie()   - bool, count is player newbie depends n stats
   isNewbieEventId(eventId) - bool  - is event in newbie events list in config
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

::my_stats <- {
  updateDelay = 3600000 //once per 1 hour, we have force update after each battle or debriefing.

  _my_stats = null
  _last_update = -10000000
  _is_in_update = false
  _resetStats = false

  _newPlayersBattles = {}

  newbie = null
  newbieByUnitType = {}
  newbieNextEvent = {}
  _needRecountNewbie = true
  _unitTypeByNewbieEventId = {}
  _maxUnitsUsedRank = null

  function getStats() {
    this.requestMyStats()
    return this._my_stats
  }

  function getTitles(showHidden = false) {
    let titles = getTblValue("titles", this._my_stats, [])
    if (showHidden)
      return titles

    for (local i = titles.len() - 1; i >= 0 ; i--) {
      let titleUnlock = getUnlockById(titles[i])
      if (!titleUnlock || titleUnlock?.hidden)
        titles.remove(i)
    }

    return titles
  }

  function requestMyStats() {
    if (!::g_login.isLoggedIn())
      return
    let time = get_time_msec()
    if (this._is_in_update && time - this._last_update < 45000)
      return
    if (!this._resetStats && this._my_stats && time - this._last_update < this.updateDelay) //once per 15min
      return

    this._is_in_update = true
    this._last_update = time
    ::add_bg_task_cb(::req_player_public_statinfo(::my_user_id_str),
                     function () {
                       this._is_in_update = false
                       this._resetStats = false
                       this._needRecountNewbie = true
                       this._update_my_stats()
                     }.bindenv(this))
  }

  function _update_my_stats() {
    if (!::g_login.isLoggedIn())
      return

    let blk = DataBlock()
    ::get_player_public_stats(blk)

    if (!blk)
      return

    this._my_stats = getPlayerStatsFromBlk(blk)

    seenTitles.onListChanged()
    broadcastEvent("MyStatsUpdated")
  }

  function isStatsLoaded() {
    return this._my_stats != null
  }

  function clearStats() {
    this._my_stats = null
  }

  function markStatsReset() {
    this._resetStats = true
  }

  function onEventUnitBought(_p) {
    //need update bought units list
    this.markStatsReset()
  }

  function onEventAllModificationsPurchased(_p) {
    this.markStatsReset()
  }

  //newbie stats
  function onEventInitConfigs(_p) {
    let settingsBlk = ::get_game_settings_blk()
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
        this._unitTypeByNewbieEventId[ev.event] <- unitType.esUnitType

        let kills = ev?.kills || 1
        data.battles.append({
          event       = ev?.event
          kills       = kills
          timePlayed  = ev?.timePlayed || 0
          unitRank    = ev?.unitRank || 0
        })
        data.minKills = max(data.minKills, kills)
      }
      let additionalUnitTypesBlk = blk?.additionalUnitTypes[unitType.lowerName]
      if (additionalUnitTypesBlk)
        data.additionalUnitTypes = additionalUnitTypesBlk % "type"
      if (data.minKills)
        this._newPlayersBattles[unitType.esUnitType] <- data
    }
  }

  function onEventScriptsReloaded(p) {
    this.onEventInitConfigs(p)
  }

  isNewbieInited = @() this.newbie != null

  function loadLocalNewbieData() {
    if (!::g_login.isProfileReceived())
      return

    let newbieEndByArmyId = ::load_local_account_settings("myStats/newbieEndedByArmyId", null)
    if (!newbieEndByArmyId)
      return

    foreach (unitType in unitTypes.types) {
      if (!unitType.isAvailable() || !unitType.isPresentOnMatching)
        continue

      let isNewbieEnded = newbieEndByArmyId?[unitType.armyId] ?? false
      if (isNewbieEnded)
        this.newbieByUnitType[unitType.esUnitType] <- false
    }

    this.newbie = this.__isNewbie()
  }

  function checkRecountNewbie() {
    let statsLoaded = this.isStatsLoaded()  //when change newbie recount, dont forget about check stats loaded for newbie tutor
    if (!this._needRecountNewbie || !statsLoaded) {
      if (!statsLoaded || (this.newbie ?? false))
        this.requestMyStats()
      return
    }
    this._needRecountNewbie = false

    let newbieEndByArmyId = ::g_login.isProfileReceived()
      ? ::load_local_account_settings("myStats/newbieEndedByArmyId", {})
      : null

    this.newbieByUnitType.clear()
    foreach (unitType in unitTypes.types) {
      if (!unitType.isAvailable() || !unitType.isPresentOnMatching)
        continue

      let isNewbieEnded = newbieEndByArmyId?[unitType.armyId] ?? false
      if (isNewbieEnded) {
        this.newbieByUnitType[unitType.esUnitType] <- false
        continue
      }

      let killsReq = this._newPlayersBattles?[unitType.esUnitType]?.minKills ?? 0
      if (killsReq <= 0)
        continue
      local kills = this.getKillsOnUnitType(unitType.esUnitType)
      let additionalUnitTypes = this._newPlayersBattles?[unitType.esUnitType].additionalUnitTypes ?? []
      foreach (addEsUnitType in additionalUnitTypes)
        kills += this.getKillsOnUnitType(::getUnitTypeByText(addEsUnitType))
      this.newbieByUnitType[unitType.esUnitType] <- kills < killsReq

      if (newbieEndByArmyId)
        newbieEndByArmyId[unitType.armyId] <- !this.newbieByUnitType[unitType.esUnitType]
    }

    if (newbieEndByArmyId)
      ::save_local_account_settings("myStats/newbieEndedByArmyId", newbieEndByArmyId)

    this.newbie = this.__isNewbie()

    this.newbieNextEvent.clear()
    foreach (unitType, config in this._newPlayersBattles) {
      local event = null
      local kills = this.getKillsOnUnitType(unitType)
      local timePlayed = this.getTimePlayedOnUnitType(unitType)
      let additionalUnitTypes = config?.additionalUnitTypes ?? []
      foreach (addEsUnitType in additionalUnitTypes) {
        kills += this.getKillsOnUnitType(::getUnitTypeByText(addEsUnitType))
        timePlayed += this.getTimePlayedOnUnitType(::getUnitTypeByText(addEsUnitType))
      }
      foreach (evData in config.battles) {
        if (kills >= evData.kills)
          continue
        if (timePlayed >= evData.timePlayed)
          continue
        if (evData.unitRank && this.checkUnitInSlot(evData.unitRank, unitType))
          continue
        event = ::events.getEvent(evData.event)
        if (event)
          break
      }
      if (event)
        this.newbieNextEvent[unitType] <- event
    }
  }

  function checkUnitInSlot(requiredUnitRank, unitType) {
    if (this._maxUnitsUsedRank == null)
      this._maxUnitsUsedRank = this.calculateMaxUnitsUsedRanks()

    if (requiredUnitRank <= getTblValue(unitType.tostring(), this._maxUnitsUsedRank, 0))
      return true

    return false
  }

  /**
   * Checks am i newbie, looking to my stats.
   *
   * Internal usage only. If there is no stats
   * result will be unconsistent.
   */
  function __isNewbie() {
    foreach (_esUnitType, isNewbie in this.newbieByUnitType)
      if (!isNewbie)
        return false
    return true
  }

  function onEventEventsDataUpdated(_params) {
    this._needRecountNewbie = true
  }

  function onEventCrewTakeUnit(params) {
    let unitType = ::get_es_unit_type(params.unit)
    let unitRank = params.unit?.rank ?? -1
    let lastMaxRank = getTblValue(unitType.tostring(), this._maxUnitsUsedRank, 0)
    if (lastMaxRank >= unitRank)
      return

    if (this._maxUnitsUsedRank == null)
      this._maxUnitsUsedRank = this.calculateMaxUnitsUsedRanks()

    this._maxUnitsUsedRank[unitType.tostring()] = unitRank
    ::saveLocalByAccount("tutor/newbieBattles/unitsRank", this._maxUnitsUsedRank)
    this._needRecountNewbie = true
  }

  function getUserstat(paramName) {
    local res = 0
    foreach (_diffName, block in this._my_stats?.userstat ?? {})
      foreach (unitData in block?.total ?? [])
        res += (unitData?[paramName] ?? 0)

    return res
  }

  function getPvpPlayed() {
    return this.getUserstat("sessions")
  }

  function getTotalTimePlayedSec() {
    local sec = 0
    foreach (modeBlock in this._my_stats?.summary ?? {})
      foreach (diffBlock in modeBlock)
        foreach (unitTypeBlock in diffBlock)
          sec += (unitTypeBlock?.timePlayed ?? 0)
    return sec
  }

  /**
   * Returns summ of specified fields in players statistic.
   * @summaryName - game mode. Available values:
   *  pvp_played
   *  skirmish_played
   *  dynamic_played
   *  campaign_played
   *  builder_played
   *  other_played
   *  single_played
   * @filter - table config.
   *   {
   *     addArray - array of fields to summ
   *     subtractArray - array of fields to subtract
   *     unitType - unit type filter; if not specified - get both
   *   }
   */
  function getSummary(summaryName, filter = {}) {
    local res = 0
    let pvpSummary = getTblValue(summaryName, getTblValue("summary", this._my_stats))
    if (!pvpSummary)
      return res

    let roles = u.map(getUnitClassTypesByEsUnitType(filter?.unitType),
       @(t) t.expClassName)

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
    return this.getSummary("pvp_played", { addArray = ["respawns"] })
  }

  function getPvpRespawnsOnUnitType(unitType) {
    return this.getSummary("pvp_played", {
      unitType
      addArray = ["respawns"]
    })
  }

  function getKillsOnUnitType(unitType) {
    return this.getSummary("pvp_played", {
      addArray = ["air_kills", "ground_kills", "naval_kills"],
      subtractArray = ["air_kills_ai", "ground_kills_ai", "naval_kills_ai"]
      unitType
    })
  }

  function getTimePlayedOnUnitType(unitType) {
    return this.getSummary("pvp_played", {
      addArray = ["timePlayed"]
      unitType
    })
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

  function getSummaryFromProfile(func, unitType = null, diff = null, mode = 1 /*domination*/ ) {
    local res = 0.0
    let classFlags = this.getClassFlags(unitType)
    for (local i = 0; i < EUCT_TOTAL; i++)
      if (classFlags & (1 << i)) {
        if (diff != null)
          res += func(diff, i, mode)
        else
          for (local d = 0; d < 3; d++)
            res += func(d, i, mode)
      }
    return res
  }

  function getTimePlayed(unitType = null, diff = null) {
    return this.getSummaryFromProfile(::stat_get_value_time_played, unitType, diff)
  }

  function isMeNewbie() { //used in code
    this.checkRecountNewbie()
    if (this.newbie == null)
      this.loadLocalNewbieData()
    return this.newbie ?? false
  }

  function isMeNewbieOnUnitType(esUnitType) {
    this.checkRecountNewbie()
    if (this.newbie == null)
      this.loadLocalNewbieData()
    return this.newbieByUnitType?[esUnitType] ?? false
  }

  function getNextNewbieEvent(country = null, unitType = null, checkSlotbar = true) { //return null when no newbie event
    this.checkRecountNewbie()
    if (!country)
      country = profileCountrySq.value

    if (unitType == null) {
      unitType = getFirstChosenUnitType(ES_UNIT_TYPE_AIRCRAFT)
      if (checkSlotbar) {
        let types = ::getSlotbarUnitTypes(country)
        if (types.len() && !isInArray(unitType, types))
          unitType = types[0]
      }
    }
    return getTblValue(unitType, this.newbieNextEvent)
  }

  function isNewbieEventId(eventName) {
    foreach (config in this._newPlayersBattles)
      foreach (evData in config.battles)
        if (eventName == evData.event)
          return true
    return false
  }

  function getUnitTypeByNewbieEventId(eventId) {
    return getTblValue(eventId, this._unitTypeByNewbieEventId, ES_UNIT_TYPE_INVALID)
  }

  function calculateMaxUnitsUsedRanks() {
    local needRecalculate = false
    let loadedBlk = ::loadLocalByAccount("tutor/newbieBattles/unitsRank", DataBlock())
    foreach (unitType in unitTypes.types)
      if (unitType.isAvailable()
        && (loadedBlk?[unitType.esUnitType.tostring()] ?? 0) < ::max_country_rank) {
        needRecalculate = true
        break
      }

    if (!needRecalculate)
      return loadedBlk

    let saveBlk = DataBlock()
    saveBlk.setFrom(loadedBlk)
    let countryCrewsList = ::g_crews_list.get()
    foreach (countryCrews in countryCrewsList)
      foreach (crew in getTblValue("crews", countryCrews, [])) {
        let unit = ::g_crew.getCrewUnit(crew)
        if (unit == null)
          continue

        let curUnitType = ::get_es_unit_type(unit)
        saveBlk[curUnitType.tostring()] = max(getTblValue(curUnitType.tostring(), saveBlk, 0), unit?.rank ?? -1)
      }

    if (!u.isEqual(saveBlk, loadedBlk))
      ::saveLocalByAccount("tutor/newbieBattles/unitsRank", saveBlk)

    return saveBlk
  }

  function getMissionsComplete(summaryArray = summaryNameArray) {
    local res = 0
    let myStats = this.getStats()
    foreach (summaryName in summaryArray) {
      let summary = myStats?.summary?[summaryName] ?? {}
      foreach (diffData in summary)
        res += diffData?.missionsComplete ?? 0
    }
    return res
  }

  function resetStatsParams() {
    this.clearStats()
    this._is_in_update = false
    this._resetStats = false
    this.newbie = null
    this.newbieNextEvent.clear()
    this._needRecountNewbie = true
    this._maxUnitsUsedRank = null
  }

  function onEventSignOut(_p) {
    this.resetStatsParams()
  }

  onEventLoginComplete = @(_) this.requestMyStats()
}

seenTitles.setListGetter(@() ::my_stats.getTitles())

subscribe_handler(::my_stats, ::g_listener_priority.DEFAULT_HANDLER)

::is_me_newbie <- function is_me_newbie() { //used in code
  return ::my_stats.isMeNewbie()
}
