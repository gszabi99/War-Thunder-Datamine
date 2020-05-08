local time = require("scripts/time.nut")
local systemMsg = require("scripts/utils/systemMsg.nut")
local seenEvents = require("scripts/seen/seenList.nut").get(SEEN.EVENTS)
local crossplayModule = require("scripts/social/crossplay.nut")
local platformModule = require("scripts/clientState/platform.nut")
local stdMath = require("std/math.nut")
local { getUnitRole } = require("scripts/unit/unitInfoTexts.nut")
local { getFeaturePack } = require("scripts/user/features.nut")
local { getEntitlementConfig, getEntitlementName } = require("scripts/onlineShop/entitlements.nut")
local unitTypes = require("scripts/unit/unitTypesList.nut")

::event_ids_for_main_game_mode_list <- [
  "tank_event_in_random_battles_arcade"
  "air_arcade"
]

const EVENTS_OUT_OF_DATE_DAYS = 15
global const EVENTS_SHORT_LB_VISIBLE_ROWS = 3
global const EVENTS_SHORT_LB_REQUIRED_PARTICIPANTS_TO_SHOW = 50
const EVENT_DEFAULT_TEAM_SIZE = 16

const SQUAD_NOT_READY_LOC_TAG = "#snr"

global enum UnitRelevance
{
  NONE,
  MEDIUM,
  BEST,
}

::events <- null

::allUnitTypesMask <- (1 << ::ES_UNIT_TYPE_TOTAL_RELEASED) - 1

systemMsg.registerLocTags({ [SQUAD_NOT_READY_LOC_TAG] = "msgbox/squad_not_ready_for_event" })

class Events
{
  __game_events        = {}
  lastUpdate           = 0
  chapters             = null
  eventsLoaded         = false
  langCompatibility    = true //compatibility with version without gui_regional

  _leaderboards = null

  fullTeamsList        = [Team.A, Team.B]

  brToTier = {}

  diffTable =
  {
    arcade    = 0
    realistic = 2
    hardcore  = 4
  }

  _is_in_update = false
  _last_update_time = 0

  eventsTableConfig = [
    ::g_lb_category.EVENTS_PERSONAL_ELO
    ::g_lb_category.EVENTS_SUPERIORITY
    ::g_lb_category.EVENTS_EACH_PLAYER_FASTLAP
    ::g_lb_category.EVENTS_EACH_PLAYER_VICTORIES
    ::g_lb_category.EVENTS_EACH_PLAYER_SESSION
    ::g_lb_category.EVENT_STAT_TOTALKILLS
    ::g_lb_category.EVENTS_WP_TOTAL_GAINED
    ::g_lb_category.CLANDUELS_CLAN_ELO
    ::g_lb_category.EVENT_FOOTBALL_MATCHES
    ::g_lb_category.EVENT_FOOTBALL_GOALS
    ::g_lb_category.EVENT_FOOTBALL_ASSISTS
  ]

  standardChapterNames = [
    "basic_events"
    "clan_events"
    "tournaments"
  ]

  constructor()
  {
    __game_events        = {}
    chapters = EventChaptersManager()
    initBrToTierConformity()
    ::subscribe_handler(this, ::g_listener_priority.DEFAULT_HANDLER)
  }

  function initBrToTierConformity()
  {
    local brToTierBlk = ::configs.GUI.get()?.events_br_to_tier_conformity
    if (!brToTierBlk)
      return

    brToTier.clear()
    foreach(p2 in brToTierBlk % "brToTier")
      if (::u.isPoint2(p2))
        brToTier[p2.x] <- p2.y.tointeger()
  }

  function getTableConfigShortRowByEvent(event)
  {
    foreach (row in eventsTableConfig)
      if (row.isDefaultSortRowInEvent(event))
        return row
    return null
  }

  function getLbCategoryByField(field)
  {
    local category = ::g_lb_category.getTypeByField(field)
    return ::isInArray(category, eventsTableConfig) ? category : null
  }

  function updateEventsData(newEventsData)
  {
    __game_events = mergeEventsInfo(__game_events, newEventsData)
    chapters.updateChapters()
    eventsLoaded = true
    seenEvents.setDaysToUnseen(EVENTS_OUT_OF_DATE_DAYS)
    seenEvents.onListChanged()
    ::broadcastEvent("EventsDataUpdated")
  }

  function isTankEventActive(eventPrefix)
  {
    foreach (event in __game_events)
    {
      if (event.name.len() >= eventPrefix.len() &&
          event.name.slice(0, eventPrefix.len()) == eventPrefix &&
          isEventEnabled(event))
        return true
    }
    return false
  }

  function getTankEvent(eventPrefix)
  {
    foreach (event in __game_events)
      if (event.name.len() >= eventPrefix.len() &&
          event.name.slice(0, eventPrefix.len()) == eventPrefix &&
          isEventEnabled(event))
        return event
    return null
  }

  function getTankEventName(eventPrefix)
  {
    local event = getTankEvent(eventPrefix)
    return event && event.name
  }

  function setDifficultyWeight(event)
  {
    local diffWeight = null
    if (!("mission_decl" in event) ||
        !("difficulty" in event.mission_decl) ||
        event.mission_decl.difficulty == ""
       )
      diffWeight = -1
    else
    {
      diffWeight = diffTable[event.mission_decl.difficulty]
      if(isDifficultyCustom(event))
        diffWeight++
    }
    return diffWeight
  }

  function getEventDisplayType(event)
  {
    return ::getTblValue("_displayType", event, ::g_event_display_type.NONE)
  }

  function setEventDisplayType(event, displayType)
  {
    event._displayType <- displayType
  }

  function isEventEnableOnDebug(event)
  {
    return ::getTblValue("enableOnDebug", event, false) && !hasEventEndTime(event)
  }

  function isEventNeedInfoButton(event)
  {
    if (!event)
      return false
    return isEventForClan(event) || isEventWithLobby(event) || isEventEnableOnDebug(event)
  }

  function openEventInfo(event)
  {
    if (isEventWithLobby(event))
      ::gui_handlers.EventRoomsHandler.open(event)
    else
      ::gui_start_modal_wnd(::gui_handlers.EventDescriptionWindow, { event = event })
  }

  /**
   * Returns "true" if event is not debug or client
   * has specific feature: ShowDebugEvents
   */
  function checkEnableOnDebug(event)
  {
    return !isEventEnableOnDebug(event) || ::has_feature("ShowDebugEvents")
  }

  function isEventDisplayWide(event)
  {
    return ::getTblValue("displayWide", event, false) && !isEventEnableOnDebug(event)
  }

  function checkTankEvents()
  {
    foreach (event in __game_events)
    {
      if (isEventRandomBattles(event) && isEventEnabled(event))
        return true
    }
    return false
  }

  function isUnitTypeAvailable(event, unitType)
  {
    return (getEventUnitTypesMask(event) & (1 << unitType)) != 0
  }

  function isUnitTypeRequired(event, unitType, valueWhenNoRequiredUnits = false)
  {
    local reqUnitTypesMask = getEventRequiredUnitTypesMask(event)
    return reqUnitTypesMask != 0 ? reqUnitTypesMask & (1 << unitType) : valueWhenNoRequiredUnits
  }

  function getEventUnitTypesMask(event)
  {
    if (!("unitTypesMask" in event))
      event.unitTypesMask <- countAvailableUnitTypes(event)
    return event.unitTypesMask
  }

  function getEventRequiredUnitTypesMask(event)
  {
    if (!("reqUnitTypesMask" in event))
      event.reqUnitTypesMask <- countRequiredUnitTypesMask(event)
    return event.reqUnitTypesMask
  }

  function getBaseUnitTypefromRule(rule, checkAllAvailable)
  {
    if (!("class" in rule))
      return ::ES_UNIT_TYPE_INVALID
    if (checkAllAvailable)
      foreach(key in ["name", "type"])
        if (key in rule)
          return ::ES_UNIT_TYPE_INVALID
    return ::getUnitTypeByText(rule["class"])
  }

  /**
   * Supports event objects and session lobby info as parameter.
   */
  function countAvailableUnitTypes(teamDataByTeamName)
  {
    local resMask = 0
    foreach(team in getSidesList())
    {
      local teamData = getTeamData(teamDataByTeamName, team)
      if (!teamData || !isTeamDataPlayable(teamData))
        continue

      local teamUnitTypes = 0
      foreach(rule in getAlowedCrafts(teamData))
      {
        local unitType = getBaseUnitTypefromRule(rule, false)
        if ("name" in rule)
        {
          local unit = ::getAircraftByName(rule.name)
          if (unit)
            unitType = ::get_es_unit_type(unit)
        }
        if (unitType >= 0)
          teamUnitTypes = teamUnitTypes | (1 << unitType)
      }
      if (!teamUnitTypes)
        teamUnitTypes = ::allUnitTypesMask

      foreach(rule in getForbiddenCrafts(teamData))
      {
        local unitType = getBaseUnitTypefromRule(rule, true)
        if (unitType >= 0)
          teamUnitTypes = teamUnitTypes & ~(1 << unitType)
      }

      resMask = resMask | teamUnitTypes
      if (resMask == ::allUnitTypesMask)
        break
    }
    return resMask
  }

  function getUnitTypesByTeamDataAndName(teamData, teamName)
  {
    if (teamData == null)
      return ::allUnitTypesMask
    return countAvailableUnitTypes({ [teamName]=teamData })
  }

  //result 0 - no required crafts
  function countRequiredUnitTypesMaskByTeamData(teamData)
  {
    local res = 0
    local reqCrafts = getRequiredCrafts(teamData)
    foreach(rule in reqCrafts)
    {
      local unitType = getBaseUnitTypefromRule(rule, false)
      if ("name" in rule)
      {
        local unit = ::getAircraftByName(rule.name)
        if (unit)
          unitType = ::get_es_unit_type(unit)
      }
      if (unitType != ::ES_UNIT_TYPE_INVALID)
        res = res | (1 << unitType)
    }
    return res
  }

  function countRequiredUnitTypesMask(event)
  {
    local res = 0
    foreach(team in getSidesList())
    {
      local teamData = getTeamData(event, team)
      if (!teamData || !isTeamDataPlayable(teamData))
        continue

      res = res | countRequiredUnitTypesMaskByTeamData(teamData)
    }
    return res
  }

  /**
   * Returns list of events for game mode select menu
   */
  function getEventsForGcDrawer()
  {
    return getEventsList(EVENT_TYPE.ANY & (~EVENT_TYPE.NEWBIE_BATTLES),
      @(event) getEventDisplayType(event).showInGamercardDrawer && isEventActive(event))
  }

  function getVisibleEventsList()
  {
    return getEventsList(EVENT_TYPE.ANY,
      @(event) (checkEnableOnDebug(event) || getEventIsVisible(event)))
  }

  function getEventsForEventsWindow()
  {
    return getEventsList(EVENT_TYPE.ANY_BASE_EVENTS,  isEventVisibleInEventsWindow)
  }

  function getEventType(event)
  {
    if (!("_type" in event))
      event._type <- detectEventType(event)
    return event._type
  }

  function detectEventType(event_data)
  {
    local result = 0
    if (::my_stats.isNewbieEventId(event_data.name))
      result = EVENT_TYPE.NEWBIE_BATTLES
    else if (::getTblValue("tournament", event_data, false)
      && getEventTournamentMode(event_data) != GAME_EVENT_TYPE.TM_NONE_RACE)
        result = EVENT_TYPE.TOURNAMENT
    else
      result = EVENT_TYPE.SINGLE

    if (::getTblValue("clanBattle", event_data, false))
      result = result | EVENT_TYPE.CLAN
    return result
  }

  function getEventTournamentMode(event)
  {
    return ::getTblValue("tournament_mode", event, GAME_EVENT_TYPE.TM_NONE)
  }

  function _initEventViewData(eventData)
  {
    if (!("view_data" in eventData))
      return

    //override event params by predefined config by designers.
    //!!FIX ME: teporary support of multi events before it will be done in more correct way, without strange data.
    local sourceInfo = {}
    foreach(key, value in eventData.view_data)
    {
      if (key == "teamA" || key == "teamB")
      {
        if (key in eventData)
        {
          sourceInfo[key] <- eventData[key]
          eventData[key] = clone eventData[key]
        } else
          eventData[key] <- {}

        foreach(key2, value2 in value)
          eventData[key][key2] <- value2
        continue
      }

      if (key in eventData)
        sourceInfo[key] <- eventData[key]
      eventData[key] <- value
    }
    if (sourceInfo.len())
      eventData._source_overrided <- sourceInfo
  }

  function _calcEventDisplayType(event)
  {
    if (!::g_difficulty.isDiffCodeAvailable(getEventDiffCode(event), ::GM_DOMINATION))
      return ::g_event_display_type.NONE

    local res = ::g_event_display_type.REGULAR
    local checkNewbieEvent = ::my_stats.isNewbieEventId(event.name)
    local checkBasicArcade = ::isInArray(event.name, ::event_ids_for_main_game_mode_list)
    if (checkNewbieEvent || checkBasicArcade)
      res = ::g_event_display_type.RANDOM_BATTLE
    else if (!isEventVisibleByFeature(event))
      res = ::g_event_display_type.NONE
    else
    {
      local displayTypeName = ::getTblValue("displayType", event)
      if (::u.isString(displayTypeName))
        res = ::g_event_display_type.getTypeByName(displayTypeName)
    }
    return res
  }

  function _initEventParams(eventData)
  {
    if (!("teamA" in eventData) && "team" in eventData)
    {
      eventData.teamA <- eventData.team
      delete eventData.team
    }

    _initEventViewData(eventData)

    eventData.diffWeight <- setDifficultyWeight(eventData)
    if ("event_access" in eventData && ::u.isString(eventData.event_access))
      eventData.event_access <- ::split(eventData.event_access, "; ")

    setEventDisplayType(eventData, _calcEventDisplayType(eventData))

    eventData.enableOnDebug <- ::getTblValue("enableOnDebug", eventData, false)
    if (("specialRequirements" in eventData) && !::u.isArray(eventData.specialRequirements))
      eventData.specialRequirements <- [eventData.specialRequirements]

    if (("loc_name" in eventData) && !::u.isString(eventData.loc_name))
    {
      ::dagor.assertf(false, "Bad event loc_name. eventName = " + eventData.name + ", " +
                             "economicName = " + getEventEconomicName(eventData) + ", loc_name = " + ::toString(eventData.loc_name))
      delete eventData.loc_name
    }

    return eventData
  }

  function mergeEventsInfo(curEventsData, newEventsData)
  {
    local activeEvents = getActiveEventsList(EVENT_TYPE.ANY)
    foreach(event in activeEvents)
      curEventsData.rawdelete(event)
    foreach(eventId, eventData in newEventsData)
    {
      if (isCustomGameMode(eventData))
        continue

      local event = _initEventParams(clone eventData)
      if (checkEventAccess(event))
        curEventsData[eventId] <- event
    }
    return curEventsData
  }

  function checkEventAccess(eventData)
  {
    if (!::has_feature("Tanks") && isUnitTypeAvailable(eventData, ::ES_UNIT_TYPE_TANK))
      return false
    if (::use_touchscreen && eventData.diffWeight >= diffTable.hardcore)
      return false

    if (!("event_access" in eventData))
      return true
    if (::isInArray("AccessTest", eventData.event_access) && !::has_entitlement("AccessTest"))
      return false
    if (::isInArray("tankAccess", eventData.event_access) && !::has_feature("Tanks")) //temporary here while not everywhere used new types
      return false
    if (::isInArray("ps4", eventData.event_access) && !::is_platform_ps4)
      return false
    if (::isInArray("pc", eventData.event_access) && !::is_platform_pc)
      return false
    return true
  }

  function recalcAllEventsDisplayType()
  {
    local isChanged = false
    foreach(event in __game_events)
    {
      local displayType = _calcEventDisplayType(event)
      if (displayType == getEventDisplayType(event))
        continue

      setEventDisplayType(event, displayType)
      isChanged = true
    }

    if (isChanged)
    {
      chapters.updateChapters()
      ::broadcastEvent("EventsDataUpdated")
    }
  }

  function checkEventId(eventId)
  {
    if(eventId in __game_events && __game_events[eventId] != null)
      return true
    return false
  }

  function getEvent(event_id)
  {
    return checkEventId(event_id)? __game_events[event_id] : null
  }

  function getMGameMode(event, room)
  {
    return (room && ::SessionLobby.getMGameMode(room)) || event
  }

  function getEventEconomicName(event)
  {
    return ::getTblValue("economicName", event, "");
  }

  function getEventByEconomicName(economicName)
  {
    foreach (event in __game_events)
      if (getEventEconomicName(event) == economicName)
        return event
    return null
  }

  function getLastPlayedEvent()
  {
    local eventData = ::loadLocalByAccount("lastPlayedEvent", null)
    if (eventData == null)
      return null
    local eventId = ::getTblValue("eventName", eventData, null)
    local event = getEvent(eventId)
    if (event != null)
      return event
    local economicName = ::getTblValue("economicName", eventData, null)
    return getEventByEconomicName(economicName)
  }

  /**
   * returns true if events queue multiclustered
   */
  function isMultiCluster(event)
  {
    return ::getTblValue("multiCluster", event, false)
  }

  function getEDiffByEvent(event)
  {
    if (!("ediff" in event))
    {
      local difficulty = getEventDifficulty(event)
      event.ediff <- difficulty.getEdiffByUnitMask(getEventUnitTypesMask(event))
    }
    return event.ediff
  }

  function getUnitEconomicRankByEvent(event, unit)
  {
    local ediff = getEDiffByEvent(event)
    return unit.getEconomicRank(ediff)
  }

  function getTeamData(eventData, team)
  {
    return ::getTblValue(getTeamName(team), eventData)
  }

  function getTeamDataWithRoom(event, team, room)
  {
    if (room)
      return ::SessionLobby.getTeamData(team, room)
    return getTeamData(event, team)
  }

  //check is team data allowed to play in this event.
  //doesnt depend on any player parameters.
  function isTeamDataPlayable(teamData)
  {
    return ::getTblValue("maxTeamSize", teamData, 1) > 0
  }

  function initSidesOnce(event)
  {
    if (::getTblValue("_isSidesInited", event))
      return

    local sides = []
    foreach(team in fullTeamsList)
      if (isTeamDataPlayable(getTeamData(event, team)))
        sides.append(team)

    local isFreeForAll = event?.ffa ?? false
    local isSymmetric = isFreeForAll || (event?.isSymmetric ?? false) || sides.len() <= 1
    //no point to save duplicate array, just link on fullTeamsList
    if (!isSymmetric)
    {
      local teamDataA = getTeamData(event, sides[0])
      local teamDataB = getTeamData(event, sides[1])
      if (teamDataA == null || teamDataB == null)
      {
        local economicName = event?.economicName  // warning disable: -declared-never-used
        ::script_net_assert_once("not found event teamdata", "missing teamdata in event")
      } else
        isSymmetric = isSymmetric || isTeamsEqual(teamDataA, teamDataB)
    }
    if (isSymmetric && sides.len() > 1)
      sides = [sides[0]]

    event.sidesList <- sides
    event.isSymmetric <- isSymmetric
    event.isFreeForAll <- isFreeForAll
  }

  function isTeamsEqual(teamAData, teamBData)
  {
    if (teamAData.len() != teamBData.len())
      return false

    foreach(key, value in teamAData)
    {
      if (key == "forcedCountry")
        continue

      if (!(key in teamBData) || !::u.isEqual(value, teamBData[key]))
        return false
    }

    return true
  }

  function getSidesList(event = null)
  {
    if (!event)
      return fullTeamsList
    initSidesOnce(event)
    return event.sidesList
  }

  function isEventSymmetricTeams(event)
  {
    initSidesOnce(event)
    return event.isSymmetric
  }

  function needRankInfoInQueue(event)
  {
    return event?.balancerMode == "mrank"
  }

  function isEventFreeForAll(event)
  {
    initSidesOnce(event)
    return event.isFreeForAll
  }

  function getTeamName(teamCode)
  {
    return ::g_team.getTeamByCode(teamCode).name
  }

  function isEventXboxOnlyAllowed(event)
  {
    return (event?.xboxOnlyAllowed ?? false) && ::is_platform_xboxone
  }

  function isEventPS4OnlyAllowed(event)
  {
    return (event?.ps4OnlyAllowed ?? false) && ::is_platform_ps4
  }

  function isEventPlatformOnlyAllowed(event)
  {
    return isEventXboxOnlyAllowed(event) || isEventPS4OnlyAllowed(event)
  }

  /**
   * Returns name of suitable image for game mode selection menu.
   * Name could be got from events config or generated by difiiculty level and
   * available unit type
   */
  function getEventTileImageName(event, isWide = false)
  {
    if ("eventImage" in event)
    {
      local eventImageTemplate = event.eventImage
      return ::format(eventImageTemplate, isWide ? "wide" : "thin")
    }

    local res = ""
    if (isUnitTypeAvailable(event, ::ES_UNIT_TYPE_TANK) && isUnitTypeAvailable(event, ::ES_UNIT_TYPE_AIRCRAFT))
      res += "mixed"
    else if (isUnitTypeAvailable(event, ::ES_UNIT_TYPE_SHIP))
      res += "ship"
    else if (!isUnitTypeAvailable(event, ::ES_UNIT_TYPE_TANK))
      res += "air"
    else if (!isUnitTypeAvailable(event, ::ES_UNIT_TYPE_AIRCRAFT))
      res += "tank"
    return wrapImageName(getEventDiffName(event.name, true) + "_" + res, isWide)
  }

  function wrapImageName(imageName, isWide)
  {
    return ::format("#ui/images/game_modes_tiles/%s.jpg?P1", imageName + (isWide ? "_wide" : "_thin"))
  }

  function getEventPreviewVideoName(event, isWide)
  {
    //We can't check is video exist. For now, there is no wide videos.
    //So, this function return null in this case.
    if (isWide)
      return null

    local isEventNeedPreview = isEventMatchesType(event, EVENT_TYPE.ANY & (~EVENT_TYPE.NEWBIE_BATTLES)) &&
      (::isInArray(event.name, ::event_ids_for_main_game_mode_list) ||
      (::events.getEventDisplayType(event).showInGamercardDrawer && isEventActive(event)))

    if (!isEventNeedPreview)
      return null

    local customVideoPreviewName = getCustomVideioPreviewName(event)
    if (customVideoPreviewName)
      return customVideoPreviewName == "" ? null : customVideoPreviewName

    local unitTypeName = ""
    if (isUnitTypeAvailable(event, ::ES_UNIT_TYPE_SHIP))
      unitTypeName += "ship"
    else if (isUnitTypeAvailable(event, ::ES_UNIT_TYPE_TANK))
      unitTypeName += "tank"
    else if (isUnitTypeAvailable(event, ::ES_UNIT_TYPE_AIRCRAFT))
      unitTypeName += "air"

    return "video/gameModes/" + unitTypeName + "_" + getEventDiffName(event.name, true) + ".ogv"
  }

  function getCustomVideioPreviewName(event)
  {
    return ::getTblValue("customVideoPreviewName", event)
  }

  function isEventEnabled(event)
  {
    return event ? (::getTblValue("disabled", event, false) == false) : false
  }

  function isEventMatchesType(event, typeMask)
  {
    return event ? (getEventType(event) & typeMask) != 0 : false
  }

  function getEventsList(typeMask = EVENT_TYPE.ANY_BASE_EVENTS, testFunc = function (event){return true})
  {
    local result = []
    if (__game_events == null)
      return result
    foreach (event in __game_events)
      if (isEventMatchesType(event, typeMask) && testFunc(event))
        result.append(event.name)
    return result
  }

  function __countEventsList(typeMask = EVENT_TYPE.ANY_BASE_EVENTS, testFunc = function (event){return true})
  {
    local result = 0
    if (__game_events == null)
      return result
    foreach (event in __game_events)
      if (isEventMatchesType(event, typeMask) && testFunc(event))
        result++
    return result
  }

  function getEventsCount(typeMask = EVENT_TYPE.ANY_BASE_EVENTS)
  {
    return __countEventsList(typeMask, isEventEnabled)
  }

  function isEventActive(event)
  {
    return isEventEnabled(event)
  }

  function isEventEnded(event)
  {
    return !isEventEnabled(event) && getEventEndTime(event) < 0
  }

  //return true if it possible to join this event.
  function isEventAllowed(event)
  {
    return getEventDisplayType(event) != ::g_event_display_type.NONE
           && checkEventFeature(event, true)
           && isEventAllowedByComaptibilityMode(event)
  }

  isEventAllowedByComaptibilityMode = @(event) event?.isAllowedForCompatibility != false || !sysopt.isCompatibiliyMode()

  function getEventsVisibleInEventsWindowCount()
  {
    return __countEventsList(EVENT_TYPE.ANY, isEventVisibleInEventsWindow)
  }

  function getActiveEventsList(typeMask = EVENT_TYPE.ANY_BASE_EVENTS)
  {
    local result = getEventsList(typeMask, function (event) {
      return ::events.getEventDisplayType(event).showInEventsWindow && isEventActive(event)
    }.bindenv(this))
    result.sort(function (a, b)
      {
        return sortEventsByDiff(a, b)
      }.bindenv(this))
    return result
  }

  function getEndedEventsCount(filterType = EVENT_TYPE.ANY_BASE_EVENTS)
  {
    return __countEventsList(typeMask, function (event) {
      return ::events.getEventDisplayType(event).showInEventsWindow && isEventEnded(event)
      }.bindenv(this))
  }

  function getEndedEventsList(typeMask = EVENT_TYPE.ANY_BASE_EVENTS)
  {
    local result = getEventsList(typeMask, function (event) {
      return ::events.getEventDisplayType(event).showInEventsWindow && isEventEnded(event)
    }.bindenv(this))
    result.sort(function (a, b)
      {
        return sortEventsByDiff(a, b)
      }.bindenv(this))
    return result
  }

  function getUnallowedEventEconomicNames()
  {
    local res = []
    foreach(event in __game_events)
      if (!isEventAllowed(event))
        ::u.appendOnce(getEventEconomicName(event), res, true)
    return res
  }

  function getCountries(teamData)
  {
    if (!teamData)
      return []
    return teamData.countries
  }

  function getCountriesByTeams(event)
  {
    local res = []
    foreach(team in getSidesList(event))
      res.append(getCountries(getTeamData(event, team)))
    return res
  }

  /*
    getAllCountriesSets result format:
    [
      {
        countries = [["country_usa", "country_ussr"], ["country_germany"]]
        gameModeIds = [164, 165] //gamemodes ids with such country list
        allCountries = {
          country_usa = 0
          country_ussr = 0
          country_germany = 1
        }
      }
    ]
  */
  function getAllCountriesSets(event)
  {
    if ("_allCountriesSets" in event)
      return event._allCountriesSets

    local res = []
    local mgmList = ::g_matching_game_modes.getGameModesByEconomicName(getEventEconomicName(event))
    mgmList.sort(function(a,b) { return a.gameModeId - b.gameModeId }) //same order on all clients
    foreach(mgm in mgmList)
    {
      if (isCustomGameMode(mgm))
        continue

      local countries = getCountriesByTeams(mgm)
      local cSet = ::u.search(res,
        (@(countries) function(set) { return ::u.isEqual(set.countries, countries) })(countries))

      if (!cSet)
      {
        cSet = {
          countries = countries
          gameModeIds = []
          allCountries = {}
        }
        foreach(team, teamCountries in countries)
          foreach(country in teamCountries)
            cSet.allCountries[country] <- team
        res.append(cSet)
      }

      cSet.gameModeIds.append(mgm.gameModeId)
    }

    event._allCountriesSets <- res
    return event._allCountriesSets
  }

  function getAvailableTeams(event, room = null)
  {
    local availableTeams = []
    if (!event)
      return availableTeams
    local playersCurCountry = ::get_profile_country_sq()
    if(!playersCurCountry || playersCurCountry.len() <= 0)
      return availableTeams

    local mgm = getMGameMode(event, room)
    foreach(team in getSidesList(isLobbyGameMode(mgm) ? null : mgm))
    {
      local teamData = getTeamDataWithRoom(event, team, room)
      if (::isInArray(playersCurCountry, getCountries(teamData)))
        availableTeams.append(team)
    }
    return availableTeams
  }

  function isCountryAvailable(event, country)
  {
    local sidesList = getSidesList(event)
    foreach(team in sidesList)
    {
      local countries = ::getTblValue("countries", getTeamData(event, team))
      if (countries && ::isInArray(country, countries))
        return true
    }
    return false
  }

  /**
   * Returns list of available countries for @event
   * If all countries available returns empty array
   * Don't use this method for checking country.
   * There is isCountryAvailable() for this purpose
   */
  function getAvailableCountriesByEvent(event)
  {
    local result = []
    foreach (country in ::shopCountriesList)
      if (isCountryAvailable(event, country))
        result.append(country)

    return result.len() < ::shopCountriesList.len() ? result : []
  }

  function isUnitMatchesRule(unit, rulesList, defReturn = false, ediff = -1)
  {
    if(rulesList.len() <= 0)
      return defReturn

    if (::u.isString(unit))
      unit = ::getAircraftByName(unit)
    if (!unit)
      return false

    foreach (rule in rulesList)
    {
      if ("name" in rule)
      {
        if (rule.name == unit.name)
          return true
        continue
      }

      if ("mranks" in rule)
      {
        local unitMRank = ediff != -1 ? unit.getEconomicRank(ediff) : 0
        if (unitMRank < (rule.mranks?.min ?? 0) || (rule.mranks?.max ?? ::MAX_ECONOMIC_RANK) < unitMRank)
          continue
      }

      if (("ranks" in rule)
          && (unit.rank < ::getTblValue("min", rule.ranks, 0) || ::getTblValue("max", rule.ranks, ::max_country_rank) < unit.rank))
        continue

      local unitType = getBaseUnitTypefromRule(rule, false)
      if (unitType != ::ES_UNIT_TYPE_INVALID && unitType != ::get_es_unit_type(unit))
        continue
      if (("type" in rule) && (::getWpcostUnitClass(unit.name) != "exp_" + rule.type))
        continue

      return true
    }
    return false
  }

  function getTierByMaxBr(maxBR)
  {
    local res = -1
    local foundBr = 0
    foreach (br, tier in brToTier)
      if (br == maxBR)
        return tier
      else if ((br < 0 && !foundBr) || (br > maxBR && (br < foundBr || foundBr <= 0)))
      {
        foundBr = br
        res = tier
      }
    return res
  }

  //return -1 if not tier detected
  function getTierNumByRule(rule)
  {
    if (!("mranks" in rule))
      return -1

    local maxBR = ::calc_battle_rating_from_rank(rule.mranks?.max ?? ::MAX_ECONOMIC_RANK)
    return getTierByMaxBr(maxBR)
  }

  function getTierTextByRules(rules)
  {
    if (rules)
      foreach(rule in rules)
      {
        local tier = ::events.getTierNumByRule(rule)
        if (tier != -1)
          return ::loc("ui/tier", { text = tier })
      }
    return ""
  }

  function isUnitAllowedForEvent(event, unit)
  {
    foreach(team in ::events.getSidesList(event))
      if (isUnitAllowed(event, team, unit.name))
        return true

    return false
  }

  function isUnitAllowedForEventRoom(event, room, unit)
  {
    local roomSpecialRules = room && ::SessionLobby.getRoomSpecialRules(room)
    if (roomSpecialRules && !isUnitMatchesRoomSpecialRules(unit, roomSpecialRules, getEDiffByEvent(event)))
      return false

    local mGameMode = ::events.getMGameMode(event, room)
    return isUnitAllowedForEvent(mGameMode, unit)
  }

  function isUnitAllowed(event, team, airName)
  {
    local teamData = getTeamData(event, team)
    local ediff = getEDiffByEvent(event)
    return teamData? isUnitAllowedByTeamData(teamData, airName, ediff) : false
  }

  function isUnitMatchesRoomSpecialRules(unit, roomSpecialRules, ediff)
  {
    return !roomSpecialRules || isUnitMatchesRule(unit, roomSpecialRules, true, ediff)
  }

  function isCurUnitMatchesRoomRules(event, room)
  {
    local unit = ::get_cur_slotbar_unit()
    if (!unit)
      return false

    local roomSpecialRules = room && ::SessionLobby.getRoomSpecialRules(room)
    return !roomSpecialRules || isUnitMatchesRoomSpecialRules(unit, roomSpecialRules, getEDiffByEvent(event))
  }

  function checkRequiredUnits(event, room = null, country = null)
  {
    if (!event)
      return false

    local playersCurCountry = country ? country : ::get_profile_country_sq()
    local ediff = getEDiffByEvent(event)

    foreach (team in getSidesList(event))
    {
      local teamData = getTeamDataWithRoom(event, team, room)
      if (!getRequiredCrafts(teamData).len()
          || !::isInArray(playersCurCountry, teamData.countries))
       continue

      local crews = ::get_crews_list_by_country(playersCurCountry)
      foreach(crew in crews)
      {
        if (::is_crew_locked_by_prev_battle(crew))
          continue

        local unit = ::g_crew.getCrewUnit(crew)
        if (unit && isAirRequiredAndAllowedByTeamData(teamData, unit.name, ediff))
          return true
      }
      return false //is it correct that we check only first teamData with requirements?
    }
    return true
  }

  function isAirRequiredAndAllowedByTeamData(teamData, airName, ediff)
  {
    return (isUnitMatchesRule(airName, getRequiredCrafts(teamData), true, ediff)
        && isUnitAllowedByTeamData(teamData, airName, ediff))
  }

  function isUnitAllowedByTeamData(teamData, airName, ediff = -1)
  {
    local unit = ::getAircraftByName(airName)
    if (!unit || unit.disableFlyout)
      return false
    if (!::isInArray(unit.shopCountry, getCountries(teamData)))
      return false

    local airInAllowedList = isUnitMatchesRule(unit, getAlowedCrafts(teamData), true, ediff)
    local airInForbidenList = isUnitMatchesRule(unit, getForbiddenCrafts(teamData), false, ediff)
    return !airInForbidenList && airInAllowedList
  }

  function checkUnitRelevanceForEvent(eventId, unit)
  {
    local event = getEvent(eventId)
    return (!event || !unit) ? UnitRelevance.NONE
     : isUnitAllowedForEvent(event, unit) ? UnitRelevance.BEST
     : isUnitTypeAvailable(event, unit.unitType.esUnitType) ? UnitRelevance.MEDIUM
     : UnitRelevance.NONE
  }

  function getSpecialRequirements(event)
  {
    return ::getTblValue("specialRequirements", event)
  }

  function checkSpecialRequirements(event)
  {
    local requirements = getSpecialRequirements(event)
    if (!requirements)
      return true

    local ediff = getEDiffByEvent(event)
    foreach(unit in ::all_units)
       if (::isUnitUsable(unit) && isUnitMatchesRule(unit, requirements, true, ediff))
         return true
    return false
  }

  function checkPlayerCountryCrafts(country, teamData, ediff, roomSpecialRules = null)
  {
    local crews = ::get_crews_list_by_country(country)
    foreach(crew in crews)
    {
      if (::is_crew_locked_by_prev_battle(crew))
        continue

      local unit = ::g_crew.getCrewUnit(crew)
      if (unit
          && (!roomSpecialRules || isUnitMatchesRule(unit, roomSpecialRules, true, ediff))
          && isUnitAllowedByTeamData(teamData, crew.aircraft, ediff)
         )
        return true
    }
    return false
  }

  function checkPlayersCrafts(event, room = null)
  {
    local mGameMode = ::events.getMGameMode(event, room)
    local roomSpecialRules = room && ::SessionLobby.getRoomSpecialRules(room)
    local playersCurCountry = ::get_profile_country_sq()
    local ediff = getEDiffByEvent(event)
    foreach (team in getSidesList(mGameMode))
    {
      local teamData = getTeamDataWithRoom(mGameMode, team, room)
      if (teamData && ::isInArray(playersCurCountry, teamData.countries)
          && checkPlayerCountryCrafts(playersCurCountry, teamData, ediff, roomSpecialRules))
          return true
    }
    return false
  }

  function checkPlayersCraftsRoomRules(event, room)
  {
    local roomSpecialRules = ::SessionLobby.getRoomSpecialRules(room)
    if (!roomSpecialRules)
      return true
    local ediff = getEDiffByEvent(event)
    foreach(crew in ::get_crews_list_by_country(::get_profile_country_sq()))
    {
      local unit = ::g_crew.getCrewUnit(crew)
      if (unit && isUnitMatchesRoomSpecialRules(unit, roomSpecialRules, ediff))
        return true
    }
    return false
  }

  function getSlotbarRank(event, country, idInCountry)
  {
    local res = 0
    local isMultiSlotEnabled = isEventMultiSlotEnabled(event)
    foreach(idx, crew in ::get_crews_list_by_country(country))
    {
      if (!isMultiSlotEnabled && idInCountry != idx)
        continue

      local unit = ::g_crew.getCrewUnit(crew)
      if (!unit)
        continue
      if (!isUnitAllowedForEvent(event, unit))
        continue
      if (::isUnitBroken(unit))
        continue

      res = ::max(res, unit.rank)
    }
    return res
  }

  function getCountryRepairInfo(event, room, country)
  {
    local mGameMode = ::events.getMGameMode(event, room)
    local roomSpecialRules = room && ::SessionLobby.getRoomSpecialRules(room)
    local teams = getAvailableTeams(mGameMode)
    local ediff = getEDiffByEvent(event)
    local teamsData = []
    foreach(t in teams)
      teamsData.append(getTeamData(mGameMode, t))

    return ::getBrokenAirsInfo([country], isEventMultiSlotEnabled(event),
      function(unit) {
        if (roomSpecialRules
            && !isUnitMatchesRule(unit, roomSpecialRules, true, ediff))
          return false
        foreach(td in teamsData)
          if (isUnitAllowedByTeamData(td, unit.name, ediff))
            return true
        return false
      }.bindenv(this))
  }

  function stackMemberErrors(members)
  {
    local res = []
    foreach(member in members)
    {
      local stack = ::u.search(res, @(s) s.status == member.status)
      if (stack)
        stack.names.append(platformModule.getPlayerName(member.name))
      else
        res.append({
          names = [platformModule.getPlayerName(member.name)]
          status = member.status
        })
    }
    return res
  }

  function showCantFlyMembersMsgBox(teamData, continueQueueFunc = null, cancelFunc = null)
  {
    local langConfig = [SQUAD_NOT_READY_LOC_TAG]
    local langConfigByTeam = {}
    local singleLangConfig = null

    foreach(idx, membersData in teamData.cantFlyData)
    {
      local teamCode = ::getTblValue("team", membersData, idx)
      local stacks = stackMemberErrors(membersData.members)
      local teamLangConfig = ::u.map(
        stacks,
        @(s) [
          systemMsg.makeColoredValue(COLOR_TAG.USERLOG, ::g_string.implode(s.names, ", ")),
          "ui/colon",
          ::g_squad_utils.getMemberStatusLocTag(s.status)
        ]
      )
      langConfigByTeam[teamCode] <- teamLangConfig
      if (idx == 0)
        singleLangConfig = teamLangConfig
      else if (!::u.isEqual(teamLangConfig, singleLangConfig))
        singleLangConfig = null
    }

    if (singleLangConfig)
      langConfig.extend(singleLangConfig)
    else
      foreach(teamCode, teamLangConfig in langConfigByTeam)
      {
        langConfig.append({ [systemMsg.LOC_ID] = "events/" + ::g_team.getTeamByCode(teamCode).name })
        langConfig.extend(teamLangConfig)
      }

    local buttons = [ ["no", cancelFunc ] ]
    if (teamData.haveRestrictions && teamData.canFlyout)
      buttons.insert(0, ["yes", continueQueueFunc ])

    ::scene_msg_box("members_cant_fly",
                    null,
                    systemMsg.configToLang(langConfig, null, "\n"),
                    buttons,
                    "no",
                    { cancel_fn = cancelFunc })

    ::g_chat.sendLocalizedMessageToSquadRoom(langConfig)
  }

  function getMembersTeamsData(event, room, teams)
  {
    if (!::g_squad_manager.isSquadLeader())
      return null

    local bestTeamsData = null
    if (room)
      bestTeamsData = getMembersFlyoutEventDataImpl(event, room, teams)
    else
    {
      local myCountry = ::get_profile_country_sq()
      local allSets = getAllCountriesSets(event)
      foreach(countrySet in allSets)
      {
        local mgmTeams = []
        foreach(idx, countries in countrySet.countries)
          if (::isInArray(myCountry, countries))
            mgmTeams.append(idx + 1) //idx to Team enum
        if (!mgmTeams.len())
          continue

        foreach(gameModeId in countrySet.gameModeIds)
        {
          local mgm = ::g_matching_game_modes.getModeById(gameModeId)
          if (!mgm)
            continue
          local teamsData = getMembersFlyoutEventDataImpl(mgm, null, mgmTeams)
          local compareTeamData = !!teamsData <=> !!bestTeamsData
            || !teamsData.haveRestrictions <=> !bestTeamsData.haveRestrictions
            || bestTeamsData.bestCountriesChanged <=> teamsData.bestCountriesChanged
          if (compareTeamData == 0 && teamsData.haveRestrictions)
            compareTeamData = bestTeamsData.cantFlyData.len() <=> teamsData.cantFlyData.len()

          if (compareTeamData > 0)
          {
            bestTeamsData = teamsData
            if (!bestTeamsData.haveRestrictions && bestTeamsData.bestCountriesChanged == 0)
              break
          }
        }
        if (bestTeamsData && !bestTeamsData.haveRestrictions && bestTeamsData.bestCountriesChanged == 0)
          break
      }
    }

    if (bestTeamsData && bestTeamsData.teamsData.len() > 1)
      bestTeamsData.teamsData = ::u.filter(bestTeamsData.teamsData, @(t) t.countriesChanged == bestTeamsData.bestCountriesChanged)

    return bestTeamsData
  }

  function getMembersFlyoutEventDataImpl(roomMgm, room, teams)
  {
    local res = {
      teamsData = []
      cantFlyData = []
      canFlyout = false
      haveRestrictions = true
      bestCountriesChanged = -1
    }
    foreach(team in teams)
    {
      local data = getMembersFlyoutEventData(roomMgm, room, team)
      data.team <- team

      if (data.canFlyout)
      {
        res.teamsData.append(data)
        res.canFlyout = true
        res.haveRestrictions = res.haveRestrictions && data.haveRestrictions
        if (data.haveRestrictions)
          res.cantFlyData.append(data)

        if (res.bestCountriesChanged < 0 || res.bestCountriesChanged > data.countriesChanged)
          res.bestCountriesChanged = data.countriesChanged
      }
      else
        res.cantFlyData.append(data)
    }
    return res
  }

  function getMembersFlyoutEventData(event, room, team)
  {
    local mGameMode = getMGameMode(event, room)
    local teamData = getTeamDataWithRoom(mGameMode, team, room)
    local canChangeMemberCountry = !room //can choose members country by queue params
    return ::g_squad_utils.getMembersFlyoutData(teamData, event, canChangeMemberCountry)
  }

  function prepareMembersForQueue(membersData)
  {
    local membersQuery = {}
    local leaderCountry = ::get_profile_country_sq()
    foreach(m in membersData.members)
    {
      local country = leaderCountry
      if (m.countries.len() && !::isInArray(leaderCountry, m.countries))
        country = m.countries[::math.rnd() % m.countries.len()]  //choose random country atm
      local slot = (country in m.selSlots) ? m.selSlots[country] : 0

      membersQuery[m.uid] <- {
        country = country
        slots = {
          [country] = slot
        }
        dislikedMissions = m?.dislikedMissions ?? []
        bannedMissions = m?.bannedMissions ?? []
      }
    }
    return membersQuery
  }

  function getAlowedCrafts(teamData, roomSpecialRules = null)
  {
    local res = ::getTblValue("allowedCrafts", teamData, [])
    if (roomSpecialRules)
    {
      res = clone res
      res.extend(roomSpecialRules)
    }
    return res
  }

  function getForbiddenCrafts(teamData)
  {
    return ::getTblValue("forbiddenCrafts", teamData, [])
  }

  function getRequiredCrafts(teamData)
  {
    return ::getTblValue("requiredCrafts", teamData, [])
  }

  function hasUnitRequirements(teamData)
  {
    return getRequiredCrafts(teamData).len() > 0
  }

  function isRespawnAvail(event)
  {
    if (event == null)
      return true

    if ("maxRespawns" in event.mission_decl &&
        event.mission_decl.maxRespawns != 1)
      return true
    return false
  }

  function getRespawnsText(event)
  {
    if (!isEventRespawnEnabled(event))
      return ::loc("template/noRespawns")
    local availRespawns = ::events.getEventMaxRespawns(event)
    if (availRespawns > 1)
      return ::loc("template/limitedRespawns/num/plural", { num = availRespawns })
    return ""
  }

  /**
   * Returns false if event does not support respawning at all.
   * (Player returns to hangar after death.)
   */
  function isEventRespawnEnabled(event)
  {
    return ::getTblValue("respawn", event, false)
  }

  /**
   * Returns true if player can select from several during respawn.
   * False means that player has only slot that was selected in hangar.
   */
  function isEventMultiSlotEnabled(event)
  {
    return ::getTblValue("multiSlot", event, false)
  }

  /**
   * Returns max possible respawn count.
   * Ignored if isEventRespawnEnabled(event) == false.
   */
  function getEventMaxRespawns(event)
  {
    if (event == null)
      return 0
    return ::getTblValue("maxRespawns", event.mission_decl, 0)
  }

  function getEventRewardMuls(eventId)
  {
    local res = { wp = 1.0, exp = 1.0 }
    if (!checkEventId(eventId))
      return res

    if ("reward_mul_wp" in __game_events[eventId])
      res.wp = __game_events[eventId].reward_mul_wp
    if ("reward_mul_exp" in __game_events[eventId])
      res.exp = __game_events[eventId].reward_mul_exp
    return res
  }

  function getEventDifficulty(event)
  {
    return g_difficulty.getDifficultyByMatchingName(getTblValue("difficulty", event, "arcade"))
  }

  function getEventDiffCode(event)
  {
    return getEventDifficulty(event).diffCode
  }

  function getEventDiffName(eventId, baseOnly = false)
  {
    if (!checkEventId(eventId))
      return ""
    local diffName = ""
    if ("difficulty" in __game_events[eventId].mission_decl)
      diffName = __game_events[eventId].mission_decl.difficulty

    if (isDifficultyCustom(__game_events[eventId]) && !baseOnly)
      diffName = "custom_" + diffName

    return diffName
  }

  function isDifficultyCustom(event)
  {
    return false
  }

  function getCustomDifficultyChanges(eventId)
  {
    local diffChanges = ""
    if (!checkEventId(eventId) || !isDifficultyCustom(__game_events[eventId]))
      return ""

    foreach(name, flag in __game_events[eventId].mission_decl.customDifficulty)
    {
      diffChanges += diffChanges.len()? "\n" : ""
      diffChanges += ::format("%s - %s", ::loc("options/" + name), ::loc("options/" + (flag? "enabled" : "disabled")))
    }

    return diffChanges
  }

  function getTeamSize(teamData)
  {
    return ::getTblValue("maxTeamSize", teamData, EVENT_DEFAULT_TEAM_SIZE)
  }

  function hasTeamSizeHandicap(event)
  {
    local sides = getSidesList(event)
    if (sides.len() < 2)
      return false
    local size = 0
    foreach(idx, team in sides)
    {
      local teamData = getTeamData(event, team)
      local teamSize = getTeamSize(teamData)
      if (!idx)
        size = teamSize
      else if (size != teamSize)
        return true
    }
    return false
  }

  function getMaxTeamSize(event)
  {
    local maxTeamSize = 0
    foreach(team in getSidesList(event))
    {
      local teamSize = getTeamSize(getTeamData(event, team))
      maxTeamSize = ::max(maxTeamSize, teamSize)
    }
    return maxTeamSize
  }

  function getMinTeamSize(event)
  {
    return ::getTblValue("minTeamSize", event) || 1
  }

  function countEventTime(eventTime)
  {
    return (eventTime - ::get_matching_server_time())
  }

  function getEventStartTime(event)
  {
    return ("startTime" in event)? countEventTime(event.startTime) : 0
  }

  function getEventEndTime(event)
  {
    return ("endTime" in event)? countEventTime(event.endTime) : 0
  }

  function getEventUiSortPriority(event)
  {
    return ::getTblValue("uiSortPriority", event, 0)
  }

  function hasEventEndTime(event)
  {
    return "endTime" in event
  }

  function onEventSignOut(p)
  {
    __game_events.clear()
    eventsLoaded = false
    chapters.updateChapters()
  }

  function getEventMission(eventId)
  {
    if (!checkEventId(eventId))
      return ""
    local list = __game_events[eventId].mission_decl.missions_list
    if(list.len() == 1)
      if (typeof(list) == "array" && typeof(list[0]) == "string")
        return list[0]
      else if (typeof(list) == "table")
        foreach(key, value in list)
          if (typeof(key) == "string")
            return key
    return ""
  }

  function getFeaturedEvent()
  {
    if (__game_events == null)
      return ""
    local diff = ::get_current_shop_difficulty()
    foreach(eventName, event in __game_events)
      if (getEventDifficulty(eventName) == diff &&
          isEventEnabled(event))
        return eventName
    return ""
  }

  function getTextsBlock(economicName)
  {
    return ::get_gui_regional_blk()?.eventsTexts?[economicName]
  }

  //!!! function only for compatibility with version without gui_regional
  function getNameLocOldStyle(event, economicName)
  {
    return ::getTblValue("loc_name", event, "events/" + economicName + "/name")
  }

  function getEventNameText(event)
  {
    local economicName = getEventEconomicName(event)
    local res = ::g_language.getLocTextFromConfig(getTextsBlock(economicName), "name", "")
    if (res.len())
      return res

    if (langCompatibility)
      return ::loc(getNameLocOldStyle(event, economicName), economicName)

    return ::loc("events/" + economicName + "/name", ::loc("events/" + economicName))
  }

  function getNameByEconomicName(economicName)
  {
    return getEventNameText(::events.getEventByEconomicName(economicName))
  }

  function getEventShortNameText(event)
  {
    local economicName = getEventEconomicName(event)
    local res = ::g_language.getLocTextFromConfig(getTextsBlock(economicName), "nameShort", "")
    if (res.len())
      return res

    if (langCompatibility)
    {
      local locId = getNameLocOldStyle(economicName)
      res = ::loc(locId + "/short", "")
      return (res != "") ? res : ::loc(locId, ::loc("events/" + economicName + "/short"))
    }
    return getEventNameText(event)
  }

  function getBaseDescByEconomicName(economicName)
  {
    local res = ::g_language.getLocTextFromConfig(getTextsBlock(economicName), "desc", "")
    if (res.len())
      return res

    if (langCompatibility)
    {
      local event = ::events.getEventByEconomicName(economicName)
      return ::loc(::getTblValue("loc_desc", event, "events/" + economicName + "/desc"), "")
    }
    return ::loc("events/" + economicName + "/desc")
  }

  function isEventForClan(event)
  {
    return isEventMatchesType(event, EVENT_TYPE.CLAN)
  }

  function isEventRandomBattles(event)
  {
    if (getEventType(event) & EVENT_TYPE.NEWBIE_BATTLES)
      return false
    if (::isInArray(event.name, ::event_ids_for_main_game_mode_list))
      return true
    return getEventDisplayType(event).canBeSelectedInGcDrawer()
  }

  function isEventRandomBattlesById(eventId)
  {
    local event = getEvent(eventId)
    return event != null && isEventRandomBattles(event)
  }

  function isRaceEvent(event_data)
  {
    if (!("templates" in event_data))
      return false

    return ::isInArray("races_template", event_data.templates)
  }

  function isEventLastManStanding(event)
  {
    return ("mission_decl" in event) && ("br_area_change_time" in event.mission_decl)
  }

  function isEventTanksCompatible(eventId)
  {
    local event = getEvent(eventId)
    return event? isUnitTypeAvailable(event, ::ES_UNIT_TYPE_TANK) : false
  }

  function getMainLbRequest(event)
  {
    return _leaderboards.getMainLbRequest(event)
  }

  /**
   * Function requests leaderboards asynchronously and puts result
   * as argument to callback function
   */
  function requestLeaderboard(requestData, id, callback = null, context = null)
  {
    _leaderboards.requestLeaderboard(requestData, id, callback, context)
  }

  /**
   * Function requests self leaderboard row asynchronously and puts result
   * as argument to callback function
   */
  function requestSelfRow(requestData, id, callback = null, context = null)
  {
    _leaderboards.requestSelfRow(requestData, id, callback, context)
  }

  function lbBlkToArray(blk)
  {
    return _leaderboards.lbBlkToArray(blk)
  }

  function isClanLbRequest(requestData)
  {
    return _leaderboards.isClanLbRequest(requestData)
  }

  function validateRequestData(requestData)
  {
    return _leaderboards.validateRequestData(requestData)
  }

  function compareRequests(req1, req2)
  {
    return _leaderboards.compareRequests(req1, req2)
  }

  function checkLbRowVisibility(row, params = {})
  {
    if (!::leaderboardModel.checkLbRowVisibility(row, params))
      return false

    local event = ::events.getEvent(::getTblValue("eventId", params))
    return row.isVisibleInEvent(event)
  }

  function fillAirsList(handler, teamObj, teamData, allowedUnitTypes, roomSpecialRules = null)
  {
    local allowedAirsObj = teamObj.findObject("allowed_crafts")
    local haveAllowedRules = generateRulesText(handler, getAlowedCrafts(teamData, roomSpecialRules), allowedAirsObj, true)
    allowedAirsObj.show(haveAllowedRules)

    local forbiddenAirsObj = teamObj.findObject("forbidden_crafts")
    local haveForbiddenRules = generateRulesText(handler, getForbiddenCrafts(teamData), forbiddenAirsObj)
    forbiddenAirsObj.show(haveForbiddenRules)

    local requiredAirsObj = teamObj.findObject("required_crafts")
    local haveRequiredRules = generateRulesText(handler, getRequiredCrafts(teamData), requiredAirsObj, true, true)
    requiredAirsObj.show(haveRequiredRules)

    local needTypeText = (!haveAllowedRules && !haveForbiddenRules && !haveRequiredRules) || allowedUnitTypes != ::allUnitTypesMask
    local allowedUnitTypesObj = teamObj.findObject("allowed_unit_types")
    allowedUnitTypesObj.show(needTypeText)
    if (!needTypeText)
      return

    local allowId = "all_units_allowed"
    local allowText = ""
    if (stdMath.number_of_set_bits(allowedUnitTypes)==1)
      allowId = "allowed_only/" + getUnitTypeText(stdMath.number_of_set_bits(allowedUnitTypes - 1))
    if (stdMath.number_of_set_bits(allowedUnitTypes)==2)
    {
      local masksArray = unitTypes.getArrayBybitMask(allowedUnitTypes)
      if (masksArray && masksArray.len() == 2)
      {
        local allowUnitId = "events/allowed_units"
        allowText = ::loc(allowUnitId, {
          unitType = ::loc(allowUnitId + "/" + masksArray[0].name),
          unitType2 = ::loc(allowUnitId + "/" + masksArray[1].name) })
        allowText = ::g_string.toUpper(allowText, 1)
      }
    }
    allowText = allowText == "" ? ::loc("events/" + allowId) : allowText
    allowedUnitTypesObj.findObject("allowed_unit_types_text").setValue(allowText)
  }

  function generateRulesText(handler, rules, rulesObj, highlightRules = false, checkAllRules = false)
  {
    // Using special container 'tdiv' for proper 'rulesObj' reuse.
    local craftsListObj = rulesObj.findObject("crafts_list")
    if (!::checkObj(craftsListObj))
    {
      craftsListObj = handler.guiScene.createElement(rulesObj, "tdiv", handler)
      craftsListObj["id"] = "crafts_list"
      craftsListObj["flow"] = "vertical"
    }
    handler.guiScene.replaceContentFromText(craftsListObj, "", 0, handler)

    local haveRules = false
    local blk = "gui/events/airRuleItem.blk"
    foreach(rule in rules)
    {
      if (!checkAllRules && ("class" in rule) && rule.len()==1)
        continue

      haveRules = true
      local ruleObj = handler.guiScene.createElementByObject(craftsListObj, blk, "tdiv", handler)
      local ruleTextObj = ruleObj.findObject("rule_text")
      local ruleString = generateEventRule(rule, false, ruleObj)
      ruleTextObj.setValue(ruleString)
    }
    return haveRules
  }

  function generateEventRule(rule, onlyText = false, ruleObj = null)
  {
    local ruleString =""
    if ("name" in rule)
    {
      local air = ::getAircraftByName(rule.name)
      if (!air)
      {
        dagor.assertf(false, "Wrong air name '" + rule.name + "'")
        dagor.debug("rule:")
        debugTableData(rule)
      }
      if (onlyText || !air)
        ruleString = ::getUnitName(air, true)

      if (air && ::checkObj(ruleObj))
      {
        local airNameObj = ruleObj.findObject("air_name")
        airNameObj.setValue(::loc(rule.name + "_shop"))

        if (::isUnitUsable(air))
          airNameObj.airBought = "yes"
        else if (air && ::canBuyUnit(air))
          airNameObj.airCanBuy = "yes"
        else {
          local reason = ::getCantBuyUnitReason(air, true)
          airNameObj.airCanBuy = reason == "" ? "yes" : "no"
        }

        local airIconObj = ruleObj.findObject("air_icon")
        airIconObj["background-image"] = ::getUnitClassIco(rule.name)
        airIconObj.shopItemType = getUnitRole(rule.name)

        ruleObj.findObject("tooltip_obj").tooltipId = ::g_tooltip.getIdUnit(air.name, { needShopInfo = true })
      }
    }
    else if ("type" in rule)
      ruleString += ::loc("mainmenu/type_" + rule.type)
    else if ("class" in rule)
      ruleString += ::loc("mainmenu/type_" + rule["class"])
    if ("ranks" in rule)
    {
      local minRank = ::max(1, ::getTblValue("min", rule.ranks, 1))
      local maxRank = ::getTblValue("max", rule.ranks, ::max_country_rank)
      local rankText = ::get_roman_numeral(minRank)
                     + ((minRank != maxRank) ? " - " + ::get_roman_numeral(maxRank) : "")
      rankText = ::format(::loc("events/rank"), rankText)
      if (ruleString.len())
        ruleString += ::loc("ui/parentheses/space", { text = rankText })
      else
        ruleString = rankText
    }

    if ("mranks" in rule)
    {
      local mranks = rule.mranks
      local minBR = ::format("%.1f", ::calc_battle_rating_from_rank(mranks?.min ?? 0))
      local maxBR = ::format("%.1f", ::calc_battle_rating_from_rank(mranks?.max ?? ::MAX_ECONOMIC_RANK))
      local brText = minBR + ((minBR != maxBR) ? " - " + maxBR : "")
      brText = ::format(::loc("events/br"), brText)
      if (ruleString.len())
        ruleString += ::loc("ui/parentheses/space", { text = brText })
      else
        ruleString = brText
    }
    return ruleString
  }

  function getRulesText(rules, separator = "\n")
  {
    local textsList = ::u.map(rules, function(rule) { return generateEventRule(rule, true) }.bindenv(this))
    return ::g_string.implode(textsList, separator)
  }

  function getSpecialRequirementsText(event, separator = "\n")
  {
    local requirements = getSpecialRequirements(event)
    return requirements ? getRulesText(requirements, separator) : ""
  }

  function getPlayersRangeTextData(event)
  {
    local minSize = getMinTeamSize(event)
    local maxSize = getMaxTeamSize(event)
    local isEqual = minSize == maxSize
    local res = {
      label = isEqual ? ::loc("events/players_range_single") : ::loc("events/players_short")
      value = minSize + (isEqual ? "" : " - " + maxSize)
      isValid = minSize > 0 && maxSize > 0
    }
    return res
  }

  function checkCurrentCraft(event, room = null)
  {
    local unit = get_cur_slotbar_unit()
    if (!unit)
      return false

    local ediff = getEDiffByEvent(event)
    if (room)
    {
      local roomSpecialRules = room && ::SessionLobby.getRoomSpecialRules(room)
      if (roomSpecialRules && !isUnitMatchesRule(unit, roomSpecialRules, true, ediff))
        return false
    }

    local mGameMode = ::events.getMGameMode(event, room)
    foreach(team in getSidesList(mGameMode))
    {
      local teamData = getTeamDataWithRoom(mGameMode, team, room)
      if (teamData && isUnitAllowedByTeamData(teamData, unit.name, ediff))
        return true
    }
    return false
  }

  function isAllowedByRoomBalance(mGameMode, room)
  {
    if (!room)
      return true
    local maxDisbalance = getMaxLobbyDisbalance(mGameMode)
    if (maxDisbalance >= ::global_max_players_versus)
      return true
    local teams = getSidesList(mGameMode)
    local availTeams = getAvailableTeams(mGameMode, room)
    if (availTeams.len() != 1 || availTeams.len() == teams.len())
      return true

    local membersCount = ::g_squad_manager.getOnlineMembersCount()
    local myTeam = availTeams[0]
    local otherTeam = ::u.search(teams, function(t) { return t != myTeam })
    local countTbl = ::SessionLobby.getMembersCountByTeams(room)
    return ::getTblValue(myTeam, countTbl, 0) + membersCount <= ::getTblValue(otherTeam, countTbl, 0) + maxDisbalance
  }

  function hasPlaceInMyTeam(mGameMode, room)
  {
    if (!room)
      return true
    local availTeams = getAvailableTeams(mGameMode, room)
    if (availTeams.len() != 1)
      return true

    local membersCount = ::g_squad_manager.getOnlineMembersCount()
    local countTbl = ::SessionLobby.getMembersCountByTeams(room)
    return countTbl[availTeams[0]] + membersCount <= getMaxTeamSize(mGameMode)
  }

  function getCantJoinReasonData(event, room = null, params = null)
  {
    local data = {
      activeJoinButton = false
      reasonText = null
      checkStatus = false
      actionFunc = null
      event = event // Used to backtrack event in actionFunc.
      room = room
    }
    if (params != null)
    {
      foreach (paramKey, paramValue in params)
        data[paramKey] <- paramValue
    }

    local isFullText = ::getTblValue("isFullText", params, false)
    local isCreationCheck = ::getTblValue("isCreationCheck", params, false)
    local mGameMode = ::events.getMGameMode(event, room)
    if (event == null)
      data.reasonText = ::loc("events/no_selected_event")
    else if (!checkEventFeature(event, true))
    {
      local purchData = ::OnlineShopModel.getFeaturePurchaseData(getEventReqFeature(event))
      data.activeJoinButton = purchData.canBePurchased
      data.reasonText = getEventFeatureReasonText(event)
    }
    else if (!isEventAllowedByComaptibilityMode(event))
      data.reasonText = ::loc("events/noCompatibilityMode")
    else if (!isCreationCheck && !isEventEnabled(event))
    {
      local startTime = ::events.getEventStartTime(event)
      if (startTime > 0)
        data.reasonText = ::loc("events/event_not_started_yet")
      else
        data.reasonText = ::loc("events/event_disabled")
      data.actionFunc = function (reasonData) {
        local messageText = reasonData.reasonText
        startTime = ::events.getEventStartTime(reasonData.event)
        if (startTime > 0)
          messageText +=  "\n" + ::format(::loc("events/event_starts_in"), ::colorize("activeTextColor",
            time.hoursToString(time.secondsToHours(startTime))))
        ::scene_msg_box("cant_join", null, messageText,
            [["ok", function() {}]], "ok")
      }
    }
    else if (!checkSpecialRequirements(event))
    {
      if (isFullText)
        data.reasonText = ::loc("events/specialRequirements") + ::loc("ui/colon") + "\n"
                        + getSpecialRequirementsText(event)
      else
        data.reasonText = ::loc("events/no_specialRequirements")
    }
    else if (!getAvailableTeams(mGameMode, room).len())
      data.reasonText = ::loc("events/no_selected_country")
    else if (!checkPlayersCrafts(mGameMode, room))
      data.reasonText = ::loc("events/no_allowed_crafts")
    else if (isEventForClan(event) && !::my_clan_info)
      data.reasonText = ::loc("events/clan_only")
    else if (!isCreationCheck && isEventEnded(event))
      data.reasonText = ::loc("events/event_disabled")
    else if (!checkRequiredUnits(mGameMode, room))
      data.reasonText = ::loc("events/no_required_crafts") + ::loc("ui/dot")
    else if (!isEventMultiSlotEnabled(event) && !checkCurrentCraft(mGameMode, room))
      data.reasonText = ::loc("events/selected_craft_is_not_allowed")
    else if (!checkClan(event))
      data.reasonText = ::loc("events/wrong_clan_for_this_tornament")
    else if (eventRequiresTicket(event) && getEventActiveTicket(event) == null)
    {
      data.activeJoinButton = true
      data.reasonText = ::loc("ticketBuyWindow/mainText")
      data.actionFunc = function (reasonData) {
        local continueFunc = ::getTblValue("continueFunc", reasonData, null)
        ::events.checkAndBuyTicket(event, continueFunc)
      }
    }
    else if (getEventActiveTicket(event) != null && !getEventActiveTicket(event).getTicketTournamentData(getEventEconomicName(event)).canJoinTournament)
    {
      data.reasonText = ::loc("events/wait_for_sessions_to_finish/main")
      data.actionFunc = function (reasonData)
      {
        ::g_event_ticket_buy_offer.offerTicket(reasonData.event)
      }
    }
    else if (::g_squad_manager.getOnlineMembersCount() < getMinSquadSize(event))
      data.reasonText = ::loc("events/minSquadSize", { minSize = getMinSquadSize(event) })
    else if (::g_squad_manager.getOnlineMembersCount() > getMaxSquadSize(event))
      data.reasonText = ::loc("events/maxSquadSize", { maxSize = getMaxSquadSize(event) })
    else if (!hasPlaceInMyTeam(mGameMode, room))
    {
      local myTeam = getAvailableTeams(mGameMode, room)[0]
      data.reasonText = ::loc("multiplayer/chosenTeamIsFull",
        {
          chosenTeam = ::colorize("teamBlueColor", ::g_team.getTeamByCode(myTeam).getShortName())
        })
    }
    else if (!isAllowedByRoomBalance(mGameMode, room))
    {
      local teamsCnt = ::SessionLobby.getMembersCountByTeams(room)
      local myTeam = getAvailableTeams(mGameMode, room)[0]
      local otherTeam = ::u.search(getSidesList(mGameMode), (@(myTeam) function(t) { return t != myTeam })(myTeam))
      local membersCount = ::g_squad_manager.getOnlineMembersCount()
      local locParams = {
        chosenTeam = ::colorize("teamBlueColor", ::g_team.getTeamByCode(myTeam).getShortName())
        otherTeam =  ::colorize("teamRedColor", ::g_team.getTeamByCode(otherTeam).getShortName())
        chosenTeamCount = teamsCnt[myTeam]
        otherTeamCount =  teamsCnt[otherTeam]
        reqOtherteamCount = teamsCnt[myTeam] - getMaxLobbyDisbalance(mGameMode) + membersCount
      }
      local locKey = "multiplayer/enemyTeamTooLowMembers" + (isFullText ? "" : "/short")
      data.reasonText = ::loc(locKey, locParams)
    }
    else if (!haveEventAccessByCost(event))
    {
      data.reasonText = ::loc("events/notEnoughMoney")
    }
    else if (!isEventPlatformOnlyAllowed(mGameMode) && !crossplayModule.isCrossPlayEnabled())
    {
      data.reasonText = ::loc("xbox/crossPlayRequired")
    }
    else
    {
      data.reasonText = ""
      data.checkStatus = true
      data.activeJoinButton = true
    }

    if (data.actionFunc == null && !data.checkStatus)
    {
      data.actionFunc = function (reasonData) {
        ::scene_msg_box("cant_join", null, reasonData.reasonText,
            [["ok", function() {}]], "ok")
      }
    }

    return data
  }

  function getEventStartTimeText(event)
  {
    if (::events.isEventEnabled(event))
    {
      local startTime = ::events.getEventStartTime(event)
      if (startTime > 0)
        return ::format(::loc("events/event_started_at"), ::colorize("activeTextColor", time.hoursToString(time.secondsToHours(startTime))))
    }
    return ""
  }

  function getEventTimeText(event)
  {
    if (::events.isEventEnabled(event))
    {
      local endTime = ::events.getEventEndTime(event)
      if (endTime > 0)
        return ::format(::loc("events/event_ends_in"), ::colorize("activeTextColor", time.hoursToString(time.secondsToHours(endTime))))
      else
        return ""
    }
    local startTime = ::events.getEventStartTime(event)
    if (startTime > 0)
      return ::format(::loc("events/event_starts_in"), ::colorize("activeTextColor", time.hoursToString(time.secondsToHours(startTime))))
    return ::loc("events/event_disabled")
  }

  //
  // Sort/compare functions.
  //

  function sortEventsByDiff(a, b)
  {
    local diffA = (typeof a == "string" ? __game_events[a] : a).diffWeight
    local diffB = (typeof b == "string" ? __game_events[b] : b).diffWeight
    if(diffA > diffB)
      return 1
    else if(diffA < diffB)
      return -1
    return 0
  }

  function gameModeCompare(gm1, gm2)
  {
    local cmp = forClanCompare(gm1.forClan, gm2.forClan)
    if (cmp != 0) return cmp
    cmp = displayTypeCompare(gm1.displayType, gm2.displayType)
    if (cmp != 0) return cmp
    cmp = diffCodeCompare(gm1.diffCode, gm2.diffCode)
    if (cmp != 0) return cmp
    return unitTypesCompare(gm1.unitTypes, gm2.unitTypes)
  }

  function displayTypeCompare(dt1, dt2)
  {
    if (dt1 == dt2)
      return 0
    return dt1.showInEventsWindow ? 1 : -1
  }

  function diffCodeCompare(d1, d2)
  {
    if (d1 > d2)
      return 1
    if (d1 < d2)
      return -1
    return 0
  }

  function unitTypesCompare(uts1, uts2)
  {
    if (uts1.len() == 1 && uts2.len() == 1)
    {
      if (uts1[0] > uts2[0])
        return 1
      if (uts1[0] < uts2[0])
        return -1
    }
    if (uts1.len() == uts2.len())
      return 0
    return uts1.len() > uts2.len() ? 1 : -1
  }

  function forClanCompare(fc1, fc2)
  {
    if (fc1 == fc2)
      return 0
    return fc1 ? 1 : -1
  }

  /** Returns tickets available for purchase. */
  function getEventTickets(event, canBuyOnly = false)
  {
    local eventId = getEventEconomicName(event)
    local tickets = ::ItemsManager.getItemsList(itemType.TICKET, (@(eventId, canBuyOnly) function (item) {
      return item.isForEvent(eventId) && (!canBuyOnly || item.canBuy)
    })(eventId, canBuyOnly))
    return tickets
  }

  /** Returns null if no such ticket found. */
  function getEventActiveTicket(event)
  {
    local eventId = event.economicName
    if (!::have_you_valid_tournament_ticket(eventId))
      return null
    local tickets = ::ItemsManager.getInventoryList(itemType.TICKET, (@(eventId) function (item) {
      return item.isForEvent(eventId) && item.isActive()
    })(eventId))
    return tickets.len() > 0 ? tickets[0] : null
  }

  function getEventActiveTicketText(event, valueColor = "activeTextColor")
  {
    local ticket = getEventActiveTicket(event)
    if (!ticket)
      return ""

    local text = ""
    if (ticket.getCost() > ::zero_money)
      text += ::loc("events/ticket_cost", { cost = ::colorize(valueColor, ticket.getCost(true).getTextAccordingToBalance()) })
    local specialText = ticket.getAvailableDefeatsText(::events.getEventEconomicName(event))
    if (specialText != "")
      text += "\n" + specialText
    return text
  }

  /**
   * @param useShortText Setting to true will
   * return only price with no text label.
   */
  function getEventBattleCostText(event, valueColor = "activeTextColor", useShortText = false, colored = true)
  {
    local cost = getEventBattleCost(event)
    if (cost <= ::zero_money)
      return ""
    local shortText = colored
      ? cost.getTextAccordingToBalance()
      : cost.getUncoloredText()
    if (useShortText)
      return shortText
    return ::loc("events/battle_cost", { cost = ::colorize(valueColor, shortText) })
  }

  function getEventBattleCost(event)
  {
    if (event == null)
      return ::Cost()
    return ::Cost().setFromTbl(::get_tournament_battle_cost(event.economicName))
  }

  function haveEventAccessByCost(event)
  {
    return ::get_gui_balance() >= getEventBattleCost(event)
  }

  function hasEventTicket(event)
  {
    return getEventActiveTicket(event) != null
  }

  function eventRequiresTicket(event)
  {
    // Event has at least one ticket available in shop.
    return getEventTickets(event).len() != 0
  }

  function checkAndBuyTicket(event, afterBuyFunc = null)
  {
    if (!eventRequiresTicket(event))
      return ::call_for_handler(null, afterBuyFunc)
    local ticket = getEventActiveTicket(event)
    if (ticket != null)
      return ::call_for_handler(null, afterBuyFunc)
    local purchasableTickets = getEventTickets(event, true)
    if (purchasableTickets.len() == 0)
    {
      local locParams = {
        eventName = getEventNameText(event)
      }
      local message = ::loc("msgbox/need_ticket/no_tickets", locParams)
      ::showInfoMsgBox(message, "no_tickets")
    }
    // Player has to purchase one of available tickets via special window.
    else
    {
      local windowParams = {
        afterBuyFunc = afterBuyFunc,
        event = event
        tickets = purchasableTickets
      }
      ::gui_start_modal_wnd(::gui_handlers.TicketBuyWindow, windowParams)
    }
  }

  /**
   * Some clan tournaments dont allow to take a part for differnt clan.
   * This function returns true if current clan (if exists) is the same as clan
   * you first time took part in this tournamnet you was in.
   */
  function checkClan(event)
  {
    local clanTournament = ::get_blk_value_by_path(::get_tournaments_blk(), event.name + "/clanTournament", false)
    if (!clanTournament)
      return true
    if (!::is_in_clan())
      return false
    if (::get_blk_value_by_path(::get_tournaments_blk(), event.name + "/allowToSwitchClan"))
      return true
    local tournamentBlk = ::EventRewards.getTournamentInfoBlk(event)
    return tournamentBlk?.clanId ? ::clan_get_my_clan_id() == tournamentBlk.clanId.tostring() : true
  }

  function checkMembersForQueue(event, room = null, continueQueueFunc = null, cancelFunc = null)
  {
    if (!::g_squad_manager.isInSquad())
      return continueQueueFunc && continueQueueFunc(null)

    local teams = getAvailableTeams(event, room)
    local membersTeams = getMembersTeamsData(event, room, teams)
    if (!membersTeams) //we are become squad member or gamemod data is missing
      return cancelFunc && cancelFunc()

    local membersInfo = getMembersInfo(teams, membersTeams.teamsData)

    if (membersTeams.haveRestrictions)
    {
      local func = @() continueQueueFunc && continueQueueFunc(membersInfo.data)
      showCantFlyMembersMsgBox(membersTeams, func, cancelFunc)
    }

    if (membersInfo.delayed)
      return

    if (!membersInfo.result)
      return cancelFunc && cancelFunc()

    if (continueQueueFunc)
      continueQueueFunc(membersInfo.data)
  }

  function getMembersInfo(teams, membersTeams)
  {
    local membersQuery = null
    local team = null

    if (!membersTeams && teams.len()) //not a squad leader
      team = teams[::math.rnd() % teams.len()]
    else if (membersTeams && membersTeams.len())
    {
      local membersData = membersTeams[::math.rnd() % membersTeams.len()]
      team = membersData.team
      membersQuery = prepareMembersForQueue(membersData)
    }
    else
    {
      return {
        result = false
        delayed = false
        data = null
        team = null
      }
    }

    return {
      result = true
      delayed = membersTeams && ::u.search(membersTeams, @(member) member.haveRestrictions && member.canFlyout ) != null
      data = membersQuery
      team = team
    }
  }

  function getEventsChapter(event)
  {
    if (::events.isEventEnableOnDebug(event))
      return "test_events"
    local chapterName = ::getTblValue("chapter", event, "basic_events")
    if (::events.isEventEnded(event) && ::isInArray(chapterName, ::events.standardChapterNames))
      chapterName += "/ended"
    return chapterName
  }

  function getChapters()
  {
    return chapters.getChapters()
  }

  function checkEventDisableSquads(handler, eventId)
  {
    if (!::g_squad_manager.isNotAloneOnline())
      return false
    local event = ::events.getEvent(eventId)
    if (event == null)
      return false
    local disableSquads = ::getTblValue("disableSquads", event, false)
    if (disableSquads)
    {
      handler.msgBox("squads_disabled", ::loc("events/squads_disabled"),
        [
          ["ok", function() {}]
        ], "ok")
      return true
    }
    return false
  }

  function getEventRankCalcMode(event)
  {
    return ::getTblValue("rankCalcMode", event, null)
  }

  function getEventIsVisible(event)
  {
    if (isEventEnabled(event))
      return true
    return ::getTblValue("visible", event, true)
  }

  function isEventVisibleInEventsWindow(event)
  {
    return getEventDisplayType(event).showInEventsWindow
           && (checkEnableOnDebug(event) || getEventIsVisible(event))
  }

  /**
   * @param teamDataByTeamName This can be event or session info.
   */
  function isEventAllUnitAllowed(teamDataByTeamName)
  {
    foreach (team in ::events.getSidesList())
    {
      local teamName = getTeamName(team)
      local teamData = ::getTblValue(teamName, teamDataByTeamName, null)
      if (!teamData || !isTeamDataPlayable(teamData))
        continue
      local types = getUnitTypesByTeamDataAndName(teamData, teamName)
      if (stdMath.number_of_set_bits(types) < ::ES_UNIT_TYPE_TOTAL_RELEASED)
        return false
      if (getAlowedCrafts(teamData).len() > 0)
        return false
      if (getForbiddenCrafts(teamData).len() > 0)
        return false
      if (getRequiredCrafts(teamData).len() > 0)
        return false
    }
    return true
  }

  function descFormat(name, value)
  {
    if (::u.isEmpty(value))
      return ""
    return name + ::loc("ui/colon") + ::colorize("@activeTextColor", value)
  }

  function getEventRewardText(event)
  {
    local muls = ::events.getEventRewardMuls(event.name)
    local wpText = buildBonusText((100.0 * (muls.wp  - 1.0) + 0.5).tointeger(), "% " + ::loc("warpoints/short/colored"))
    local expText = buildBonusText((100.0 * (muls.exp - 1.0) + 0.5).tointeger(), "% " + ::loc("currency/researchPoints/sign/colored"))
    return wpText + ((wpText.len() && expText.len())? ", " : "") + expText
  }

  function buildBonusText(value, endingText)
  {
    if (!value || value <= 0)
      return ""
    return "+" + value + endingText
  }

  function getEventDescriptionText(event, mroom = null, hasEventFeatureReasonText = false)
  {
    local textsList = []

    textsList.append(getCustomRulesDesc(event))
    textsList.append(getBaseDescByEconomicName(getEventEconomicName(event)))
    textsList.append(descFormat(::loc("reward"), getEventRewardText(event)))
    textsList.append(descFormat(::loc("events/specialRequirements"), getSpecialRequirementsText(event, ", ")))
    textsList.append(getUnlockProgress(event))

    if (mroom)
      textsList.append(descFormat(::loc("options/cluster"),
        ::g_clusters.getClusterLocName(::SessionLobby.getClusterName(mroom))))

    local isTesting = ("event_access" in event) ? ::isInArray("AccessTest", event.event_access) : false
    if (isTesting)
      textsList.append(::colorize("@yellow", ::loc("events/event_is_testing")))

    if (hasEventFeatureReasonText && !checkEventFeature(event, true))
      textsList.append(getEventFeatureReasonText(event))

    return ::g_string.implode(textsList, "\n")
  }

  function isEventAllowSwitchClan(event)
  {
    return ::getTblValue("allowSwitchClan", event, false)
  }

  function getDifficultyImg(eventId)
  {
    local diffName = getEventDiffName(eventId)
    return getDifficultyIcon(diffName)
  }

  function getDifficultyIcon(diffName)
  {
    local difficulty = ::g_difficulty.getDifficultyByName(diffName)
    if (!::u.isEmpty(difficulty.icon))
      return difficulty.icon

    if (diffName.len() > 6 && diffName.slice(0, 6) == "custom")
      return "#ui/gameuiskin#mission_" + diffName

    return ""
  }

  function getDifficultyTooltip(eventId)
  {
    local custChanges = getCustomDifficultyChanges(eventId)
    custChanges = (custChanges.len()? "\n" : "") + custChanges
    return ::events.descFormat(::loc("multiplayer/difficulty"), getDifficultyText(eventId)) + custChanges
  }

  function getDifficultyText(eventId)
  {
    local difficulty = getEventDiffName(eventId)
    if(difficulty.len())
      return ::loc("options/" + difficulty)
    return ""
  }

  function getCustomRules(event)
  {
    return ::getTblValue("customRules", event.mission_decl)
  }

  function getCustomRulesSetName(event)
  {
    local customRules = getCustomRules(event)
    return customRules?.guiName ?? customRules?.name
  }

  function getCustomRulesDesc(event)
  {
    local rulesName = getCustomRulesSetName(event)
    if (::u.isEmpty(rulesName))
      return ""

    local rulesClass = ::g_mis_custom_state.findRulesClassByName(rulesName)
    return rulesClass().getEventDescByRulesTbl(getCustomRules(event))
  }

  function getUnlockProgress(event)
  {
    if (::getTblValue("gt_use_unlocks", event.mission_decl, true))
      return ""
    return ::loc("events/no_unlock_progress")
  }

  function isEventForClanGlobalLb(event)
  {
    local tournamentMode = getEventTournamentMode(event)
    local forClans = _leaderboards.isClanLeaderboard(event)

    return tournamentMode == GAME_EVENT_TYPE.TM_NONE && forClans
  }

  function isEnableFriendsJoin(event)
  {
    return ::getTblValue("enableFriendsJoin", event, false)
  }

  function isEventWithLobby(event)
  {
    return ::getTblValue("withLobby", event, false)
  }

  function getMaxLobbyDisbalance(event)
  {
    return ::getTblValue("maxLobbyDisbalance", event, ::global_max_players_versus)
  }

  function getEventReqFeature(event)
  {
    return ::getTblValue("reqFeature", event, "")
  }

  function getEventPVETrophyName(event)
  {
    return ::getTblValue("pveTrophyName", event, "")
  }

  function isEventVisibleByFeature(event)
  {
    local feature = getEventReqFeature(event)
    if (::u.isEmpty(feature) || ::has_feature(feature))
      return true
    return ::has_feature("OnlineShopPacks") && ::OnlineShopModel.getFeaturePurchaseData(feature).canBePurchased
  }

  function checkEventFeature(event, isSilent = false)
  {
    local feature = getEventReqFeature(event)
    if (::u.isEmpty(feature) || ::has_feature(feature))
      return true

    if (isSilent)
      return false

    local purchData = ::OnlineShopModel.getFeaturePurchaseData(feature)
    if (!purchData.canBePurchased)
      return ::showInfoMsgBox(::loc("msgbox/notAvailbleYet"))

    local entitlementItem = getEntitlementConfig(purchData.sourceEntitlement)
    local msg = ::loc("msg/eventAccess/needEntitlements",
                      {
                        event = ::colorize("activeTextColor", getEventNameText(event))
                        entitlement = ::colorize("userlogColoredText", getEntitlementName(entitlementItem))
                      })
    ::gui_handlers.ReqPurchaseWnd.open({
      purchaseData = purchData
      checkPackage = getFeaturePack(feature)
      header = getEventNameText(event)
      text = msg
      btnStoreText = ::loc("msgbox/btn_onlineShop_unlockEvent")
    })
    return false
  }

  //when @checkFeature return pack only if player has feature access to event.
  function getEventReqPack(event, checkFeature = false)
  {
    local feature = getEventReqFeature(event)
    if (::u.isEmpty(feature) || (checkFeature && !::has_feature(feature)))
      return null
    return getFeaturePack(feature)
  }

  //return true if me and all my squad members has packs requeired by event feature
  //show msgBox askingdownload when no silent
  function checkEventFeaturePacks(event, isSilent = false)
  {
    local pack = getEventReqPack(event)
    if (!pack)
      return true
    return ::check_package_full(pack, isSilent)
  }

  function onEventEntitlementsPriceUpdated(p)
  {
    recalcAllEventsDisplayType()
  }

  // game mode allows to join either from queue or from rooms list
  function isLobbyGameMode(mGameMode)
  {
    return mGameMode?.withLobby ?? false
  }

  // it is lobby game mode but with sessions that can be created by players
  function isCustomGameMode(mGameMode)
  {
    return mGameMode?.forCustomLobby ?? false
  }

  function getCustomGameMode(event)
  {
    return ::u.search(
      ::g_matching_game_modes.getGameModesByEconomicName(getEventEconomicName(event)),
      isCustomGameMode
    )
  }

  function canCreateCustomRoom(event)
  {
    return ::has_feature("CreateEventRoom") && !!getCustomGameMode(event)
  }

  function openCreateRoomWnd(event)
  {
    local customMgm = getCustomGameMode(event)
    if (!customMgm)
      return

    ::handlersManager.loadHandler(::gui_handlers.CreateEventRoomWnd,
      { mGameMode = customMgm })
  }

  function getMaxSquadSize(event)
  {
    return ::getTblValue("maxSquadSize", event, 4)
  }

  function getMinSquadSize(event)
  {
    return ::getTblValue("minSquadSize", event, 1)
  }

  function isGameTypeOfEvent(event, gameTypeName)
  {
    return !!event && !!::get_meta_mission_info_by_name(getEventMission(event.name))?[gameTypeName]
  }

  function onEventEventBattleEnded(params)
  {
    local event = ::events.getEvent(::getTblValue("eventId", params))
    if (!event)
      return

    _leaderboards.dropLbCache(event)
  }

  function getEventFeatureReasonText(event)
  {
    local purchData = ::OnlineShopModel.getFeaturePurchaseData(getEventReqFeature(event))
    local reasonText = ""
    if (!purchData.canBePurchased)
      reasonText = ::loc("msgbox/notAvailbleYet")
    else
    {
      local entitlementItem = getEntitlementConfig(purchData.sourceEntitlement)
      reasonText = ::loc("events/no_entitlement",
        { entitlement = ::colorize("userlogColoredText", getEntitlementName(entitlementItem)) })
    }

    return reasonText
  }

  function isPveEvent(event)
  {
    return event?.pveMode ?? false
  }
}

::events = Events()

seenEvents.setListGetter(@() ::events.getVisibleEventsList())

seenEvents.setSubListGetter(SEEN.S_EVENTS_WINDOW,
  @() ::events.getEventsForEventsWindow())

seenEvents.setCompatibilityLoadData(function()
  {
    local res = {}
    local savePath = "seen/events"
    local blk = ::loadLocalByAccount(savePath)
    if (!::u.isDataBlock(blk))
      return res

    for (local i = 0; i < blk.paramCount(); i++)
      res[blk.getParamName(i)] <- blk.getParamValue(i)
    ::saveLocalByAccount(savePath, null)
    return res
  })
