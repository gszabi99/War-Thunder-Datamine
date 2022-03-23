let seenTitles = require("%scripts/seen/seenList.nut").get(SEEN.TITLES)
let { getUnitClassTypesByEsUnitType } = require("%scripts/unit/unitClassType.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { getPlayerStatsFromBlk } = require("%scripts/user/userInfoStats.nut")
let { getFirstChosenUnitType } = require("%scripts/firstChoice/firstChoice.nut")

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

::my_stats <-{
  updateDelay = 3600000 //once per 1 hour, we have force update after each battle or debriefing.

  _my_stats = null
  _last_update = -10000000
  _is_in_update = false
  _resetStats = false

  _newPlayersBattles = {}

  newbie = false
  newbieByUnitType = {}
  newbieNextEvent = {}
  _needRecountNewbie = true
  _unitTypeByNewbieEventId = {}
  _maxUnitsUsedRank = null

  function getStats()
  {
    updateMyPublicStatsData()
    return _my_stats
  }

  function getTitles(showHidden = false)
  {
    let titles = ::getTblValue("titles", _my_stats, [])
    if (showHidden)
      return titles

    for (local i = titles.len() - 1; i >= 0 ; i--)
    {
      let titleUnlock = ::g_unlocks.getUnlockById(titles[i])
      if (!titleUnlock || titleUnlock?.hidden)
        titles.remove(i)
    }

    return titles
  }

  function updateMyPublicStatsData()
  {
    if (!::g_login.isLoggedIn())
      return
    let time = ::dagor.getCurTime()
    if (_is_in_update && time - _last_update < 45000)
      return
    if (!_resetStats && _my_stats && time - _last_update < updateDelay) //once per 15min
      return

    _is_in_update = true
    _last_update = time
    ::add_bg_task_cb(::req_player_public_statinfo(::my_user_id_str),
                     function () {
                       _is_in_update = false
                       _resetStats = false
                       _needRecountNewbie = true
                       _update_my_stats()
                     }.bindenv(this))
  }

  function _update_my_stats()
  {
    if (!::g_login.isLoggedIn())
      return

    let blk = ::DataBlock()
    ::get_player_public_stats(blk)

    if (!blk)
      return

    _my_stats = getPlayerStatsFromBlk(blk)

    seenTitles.onListChanged()
    ::broadcastEvent("MyStatsUpdated")
  }

  function isStatsLoaded()
  {
    return _my_stats != null
  }

  function clearStats()
  {
    _my_stats = null
  }

  function markStatsReset()
  {
    _resetStats = true
  }

  function onEventUnitBought(p)
  {
    //need update bought units list
    markStatsReset()
  }

  function onEventAllModificationsPurchased(p)
  {
    markStatsReset()
  }

  //newbie stats
  function onEventInitConfigs(p)
  {
    let settingsBlk = ::get_game_settings_blk()
    let blk = settingsBlk?.newPlayersBattles
    if (!blk)
      return

    foreach (unitType in unitTypes.types)
    {
      let data = {
        minKills = 0
        battles = []
        additionalUnitTypes = []
      }
      let list = blk % unitType.lowerName
      foreach(ev in list)
      {
        if (!ev.event)
          continue
        _unitTypeByNewbieEventId[ev.event] <- unitType.esUnitType

        let kills = ev?.kills || 1
        data.battles.append({
          event       = ev?.event
          kills       = kills
          timePlayed  = ev?.timePlayed || 0
          unitRank    = ev?.unitRank || 0
        })
        data.minKills = ::max(data.minKills, kills)
      }
      let additionalUnitTypesBlk = blk?.additionalUnitTypes[unitType.lowerName]
      if (additionalUnitTypesBlk)
        data.additionalUnitTypes = additionalUnitTypesBlk % "type"
      if (data.minKills)
        _newPlayersBattles[unitType.esUnitType] <- data
    }
  }

  function onEventScriptsReloaded(p)
  {
    onEventInitConfigs(p)
  }

  function checkRecountNewbie()
  {
    let statsLoaded = isStatsLoaded()  //when change newbie recount, dont forget about check stats loaded for newbie tutor
    if (!_needRecountNewbie || !statsLoaded)
    {
      if (!statsLoaded || newbie)
        updateMyPublicStatsData()
      return
    }
    _needRecountNewbie = false

    newbieByUnitType.clear()
    foreach (unitType in unitTypes.types)
    {
      if (!unitType.isAvailable() || !unitType.isPresentOnMatching)
        continue
      let killsReq = _newPlayersBattles?[unitType.esUnitType]?.minKills ?? 0
      if (killsReq <= 0)
        continue
      local kills = getKillsOnUnitType(unitType.esUnitType)
      let additionalUnitTypes = _newPlayersBattles?[unitType.esUnitType].additionalUnitTypes ?? []
      foreach (addEsUnitType in additionalUnitTypes)
        kills += getKillsOnUnitType(::getUnitTypeByText(addEsUnitType))
      newbieByUnitType[unitType.esUnitType] <- kills < killsReq
    }
    newbie = __isNewbie()

    newbieNextEvent.clear()
    foreach(unitType, config in _newPlayersBattles)
    {
      local event = null
      local kills = getKillsOnUnitType(unitType)
      local timePlayed = getTimePlayedOnUnitType(unitType)
      let additionalUnitTypes = config?.additionalUnitTypes ?? []
      foreach (addEsUnitType in additionalUnitTypes) {
        kills += getKillsOnUnitType(::getUnitTypeByText(addEsUnitType))
        timePlayed += getTimePlayedOnUnitType(::getUnitTypeByText(addEsUnitType))
      }
      foreach(evData in config.battles)
      {
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

  function checkUnitInSlot(requiredUnitRank, unitType)
  {
    if (_maxUnitsUsedRank == null)
      _maxUnitsUsedRank = calculateMaxUnitsUsedRanks()

    if (requiredUnitRank <= ::getTblValue(unitType.tostring(), _maxUnitsUsedRank, 0))
      return true

    return false
  }

  /**
   * Checks am i newbie, looking to my stats.
   *
   * Internal usage only. If there is no stats
   * result will be unconsistent.
   */
  function __isNewbie()
  {
    foreach (esUnitType, isNewbie in newbieByUnitType)
      if (!isNewbie)
        return false
    return true
  }

  function onEventEventsDataUpdated(params)
  {
    _needRecountNewbie = true
  }

  function onEventCrewTakeUnit(params)
  {
    let unitType = ::get_es_unit_type(params.unit)
    let unitRank = params.unit?.rank ?? -1
    let lastMaxRank = ::getTblValue(unitType.tostring(), _maxUnitsUsedRank, 0)
    if (lastMaxRank >= unitRank)
      return

    if (_maxUnitsUsedRank == null)
      _maxUnitsUsedRank = calculateMaxUnitsUsedRanks()

    _maxUnitsUsedRank[unitType.tostring()] = unitRank
    ::saveLocalByAccount("tutor/newbieBattles/unitsRank", _maxUnitsUsedRank)
    _needRecountNewbie = true
  }

  function getUserstat(paramName) {
    local res = 0
    foreach (diffName, block in _my_stats?.userstat ?? {})
      foreach (unitData in block?.total ?? [])
        res += (unitData?[paramName] ?? 0)

    return res
  }

  function getPvpPlayed()
  {
    return getUserstat("sessions")
  }

  function getTotalTimePlayedSec()
  {
    local sec = 0
    foreach (modeBlock in _my_stats?.summary ?? {})
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
  function getSummary(summaryName, filter = {})
  {
    local res = 0
    let pvpSummary = ::getTblValue(summaryName, ::getTblValue("summary", _my_stats))
    if (!pvpSummary)
      return res

    let roles = ::u.map(getUnitClassTypesByEsUnitType(filter?.unitType),
       @(t) t.expClassName)

    foreach(idx, diffData in pvpSummary)
      foreach(unitRole, data in diffData)
      {
        if (!::isInArray(unitRole, roles))
          continue

        foreach(param in ::getTblValue("addArray", filter, []))
          res += ::getTblValue(param, data, 0)
        foreach(param in ::getTblValue("subtractArray", filter, []))
          res -= ::getTblValue(param, data, 0)
      }
    return res
  }

  function getPvpRespawns()
  {
    return getSummary("pvp_played", {addArray = ["respawns"]})
  }

  function getKillsOnUnitType(unitType)
  {
    return getSummary("pvp_played", {
                                      addArray = ["air_kills", "ground_kills", "naval_kills"],
                                      subtractArray = ["air_kills_ai", "ground_kills_ai", "naval_kills_ai"]
                                      unitType = unitType
                                    })
  }

  function getTimePlayedOnUnitType(unitType)
  {
    return getSummary("pvp_played", {
                                      addArray = ["timePlayed"]
                                      unitType = unitType
                                    })
  }

  function getClassFlags(unitType)
  {
    if (unitType == ::ES_UNIT_TYPE_AIRCRAFT)
      return ::CLASS_FLAGS_AIRCRAFT
    if (unitType == ::ES_UNIT_TYPE_TANK)
      return ::CLASS_FLAGS_TANK
    if (unitType == ::ES_UNIT_TYPE_SHIP)
      return ::CLASS_FLAGS_SHIP
    if (unitType == ::ES_UNIT_TYPE_HELICOPTER)
      return ::CLASS_FLAGS_HELICOPTER
    if (unitType == ::ES_UNIT_TYPE_BOAT)
      return ::CLASS_FLAGS_BOAT
    return (1 << ::EUCT_TOTAL) - 1
  }

  function getSummaryFromProfile(func, unitType = null, diff = null, mode = 1 /*domination*/)
  {
    local res = 0.0
    let classFlags = getClassFlags(unitType)
    for(local i = 0; i < ::EUCT_TOTAL; i++)
      if (classFlags & (1 << i))
      {
        if (diff != null)
          res += func(diff, i, mode)
        else
          for(local d = 0; d < 3; d++)
            res += func(d, i, mode)
      }
    return res
  }

  function getTimePlayed(unitType = null, diff = null)
  {
    return getSummaryFromProfile(stat_get_value_time_played, unitType, diff)
  }

  function isMeNewbie() //used in code
  {
    checkRecountNewbie()
    return newbie
  }

  function isMeNewbieOnUnitType(esUnitType, defVal = false)
  {
    checkRecountNewbie()
    return newbieByUnitType?[esUnitType] ?? defVal
  }

  function getNextNewbieEvent(country = null, unitType = null, checkSlotbar = true) //return null when no newbie event
  {
    checkRecountNewbie()
    if (!country)
      country = ::get_profile_country_sq()

    if (unitType == null)
    {
      unitType = getFirstChosenUnitType(::ES_UNIT_TYPE_AIRCRAFT)
      if (checkSlotbar)
      {
        let types = getSlotbarUnitTypes(country)
        if (types.len() && !::isInArray(unitType, types))
          unitType = types[0]
      }
    }
    return ::getTblValue(unitType, newbieNextEvent)
  }

  function isNewbieEventId(eventName)
  {
    foreach(config in _newPlayersBattles)
      foreach(evData in config.battles)
        if (eventName == evData.event)
          return true
    return false
  }

  function getUnitTypeByNewbieEventId(eventId)
  {
    return ::getTblValue(eventId, _unitTypeByNewbieEventId, ::ES_UNIT_TYPE_INVALID)
  }

  function calculateMaxUnitsUsedRanks()
  {
    local needRecalculate = false
    let loadedBlk = ::loadLocalByAccount("tutor/newbieBattles/unitsRank", ::DataBlock())
    foreach (unitType in unitTypes.types)
      if (unitType.isAvailable()
        && (loadedBlk?[unitType.esUnitType.tostring()] ?? 0) < ::max_country_rank)
      {
        needRecalculate = true
        break
      }

    if (!needRecalculate)
      return loadedBlk

    let saveBlk = ::DataBlock()
    saveBlk.setFrom(loadedBlk)
    let countryCrewsList = ::g_crews_list.get()
    foreach(countryCrews in countryCrewsList)
      foreach (crew in ::getTblValue("crews", countryCrews, []))
      {
        let unit = ::g_crew.getCrewUnit(crew)
        if (unit == null)
          continue

        let curUnitType = ::get_es_unit_type(unit)
        saveBlk[curUnitType.tostring()] = ::max(::getTblValue(curUnitType.tostring(), saveBlk, 0), unit?.rank ?? -1)
      }

    if (!::u.isEqual(saveBlk, loadedBlk))
      ::saveLocalByAccount("tutor/newbieBattles/unitsRank", saveBlk)

    return saveBlk
  }

  function getMissionsComplete(summaryArray = summaryNameArray)
  {
    local res = 0
    let myStats = getStats()
    foreach (summaryName in summaryArray)
    {
      let summary = myStats?.summary?[summaryName] ?? {}
      foreach(diffData in summary)
        res += diffData?.missionsComplete ?? 0
    }
    return res
  }

  function resetStatsParams()
  {
    clearStats()
    _is_in_update = false
    _resetStats = false
    newbie = false
    newbieNextEvent.clear()
    _needRecountNewbie = true
    _maxUnitsUsedRank = null
  }

  function onEventSignOut(p)
  {
    resetStatsParams()
  }
}

seenTitles.setListGetter(@() ::my_stats.getTitles())

::subscribe_handler(::my_stats, ::g_listener_priority.DEFAULT_HANDLER)

::is_me_newbie <- function is_me_newbie() //used in code
{
  return ::my_stats.isMeNewbie()
}
