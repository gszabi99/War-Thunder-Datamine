//-file:plus-string
from "%scripts/dagui_natives.nut" import have_you_valid_tournament_ticket, clan_get_my_clan_id, get_tournament_battle_cost, has_entitlement, get_tournaments_blk
from "%scripts/dagui_library.nut" import *
from "%scripts/teamsConsts.nut" import Team
from "%scripts/events/eventsConsts.nut" import EVENTS_SHORT_LB_VISIBLE_ROWS, UnitRelevance, EVENT_TYPE, GAME_EVENT_TYPE
from "%scripts/items/itemsConsts.nut" import itemType
from "%scripts/mainConsts.nut" import COLOR_TAG, SEEN

let { g_team } = require("%scripts/teams.nut")
let { getCurrentShopDifficulty } = require("%scripts/gameModes/gameModeManagerState.nut")
let { g_difficulty } = require("%scripts/difficulty.nut")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { Cost } = require("%scripts/money.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { format, split_by_chars } = require("string")
let { addListenersWithoutEnv, CONFIG_VALIDATION, subscribe_handler, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { rnd } = require("dagor.random")
let { getBlkValueByPath } = require("%sqstd/datablock.nut")
let time = require("%scripts/time.nut")
let systemMsg = require("%scripts/utils/systemMsg.nut")
let seenEvents = require("%scripts/seen/seenList.nut").get(SEEN.EVENTS)
let crossplayModule = require("%scripts/social/crossplay.nut")
let { isPlatformSony, isPlatformXboxOne, isPlatformPC
} = require("%scripts/clientState/platform.nut")
let stdMath = require("%sqstd/math.nut")
let { getUnitRole } = require("%scripts/unit/unitInfoTexts.nut")
let { getFeaturePack } = require("%scripts/user/features.nut")
let { getEntitlementConfig, getEntitlementName } = require("%scripts/onlineShop/entitlements.nut")
let { getFeaturePurchaseData } = require("%scripts/onlineShop/onlineShopState.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { isCompatibiliyMode } = require("%scripts/options/systemOptions.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { getWpcostUnitClass, getMaxEconomicRank, calcBattleRatingFromRank } = require("%appGlobals/ranks_common_shared.nut")
let { useTouchscreen } = require("%scripts/clientState/touchScreen.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { checkAndShowMultiplayerPrivilegeWarning, checkAndShowCrossplayWarning,
  isMultiplayerPrivilegeAvailable } = require("%scripts/user/xboxFeatures.nut")
let { getTournamentInfoBlk } = require("%scripts/events/eventRewards.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { isShowGoldBalanceWarning } = require("%scripts/user/balanceFeatures.nut")
let { get_meta_mission_info_by_name } = require("guiMission")
let { toUpper } = require("%sqstd/string.nut")
let { getGameModesByEconomicName, getModeById } = require("%scripts/matching/matchingGameModes.nut")
let { debug_dump_stack } = require("dagor.debug")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let { loadLocalByAccount, saveLocalByAccount
} = require("%scripts/clientState/localProfileDeprecated.nut")
let { getEsUnitType, getUnitName, canBuyUnit } = require("%scripts/unit/unitInfo.nut")
let { get_gui_regional_blk } = require("blkGetters")
let { getClusterShortName } = require("%scripts/onlineInfo/clustersManagement.nut")
let { get_gui_balance } = require("%scripts/user/balance.nut")
let { getLocTextFromConfig } = require("%scripts/langUtils/language.nut")
let { getEventEconomicName, getEventTournamentMode, isEventMatchesType, isEventForClan,
  getEventDisplayType, setEventDisplayType, eventIdsForMainGameModeList, isEventRandomBattles,
  isEventWithLobby, getMaxLobbyDisbalance, getEventReqFeature, isEventVisibleByFeature
} = require("%scripts/events/eventInfo.nut")
let { getLbCategoryTypeByField, eventsTableConfig } = require("%scripts/leaderboard/leaderboardCategoryType.nut")
let { isCrewLockedByPrevBattle } = require("%scripts/crew/crewInfo.nut")
let { findRulesClassByName } = require("%scripts/misCustomRules/missionCustomState.nut")
let { getCurSlotbarUnit, getCrewsListByCountry } = require("%scripts/slotbar/slotbarState.nut")
let { get_time_msec } = require("dagor.time")
let { requestEventLeaderboardData, requestEventLeaderboardSelfRow,
  requestCustomEventLeaderboardData, convertLeaderboardData
} = require("%scripts/leaderboard/requestLeaderboardData.nut")
let { userIdInt64 } = require("%scripts/user/profileStates.nut")
let { isNewbieEventId } = require("%scripts/myStats.nut")
let { g_event_display_type } = require("%scripts/events/eventDisplayType.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { getCrewUnit } = require("%scripts/crew/crew.nut")

const EVENTS_OUT_OF_DATE_DAYS = 15
const EVENT_DEFAULT_TEAM_SIZE = 16

const SQUAD_NOT_READY_LOC_TAG = "#snr"

const ES_UNIT_TYPE_TOTAL_RELEASED = 3

let diffTable = {
  arcade    = 0
  realistic = 2
  hardcore  = 4
}

let standardChapterNames = [
  "basic_events"
  "clan_events"
  "tournaments"
]

let fullTeamsList = [Team.A, Team.B]

let eventNameText = {}

local __game_events = {}
local chapters = null
local eventsLoaded  = false
let brToTier = {}
let unallowedEventEconomicNames = []
local unallowedEventEconomicNamesNeedUpdate = true

local events

let allUnitTypesMask = (ES_UNIT_TYPE_AIRCRAFT | ES_UNIT_TYPE_TANK | ES_UNIT_TYPE_SHIP | ES_UNIT_TYPE_BOAT)

systemMsg.registerLocTags({ [SQUAD_NOT_READY_LOC_TAG] = "msgbox/squad_not_ready_for_event" })

let _leaderboards = {
  cashLifetime = 60000
  __cache = {
    leaderboards = {}
    selfRow      = {}
  }

/** This is used in eventsHandler.nut. */
  shortLbrequest = {
    economicName = null,
    lbField = "",
    pos = 0,
    rowsInPage = EVENTS_SHORT_LB_VISIBLE_ROWS
    inverse = false,
    forClans = false,
    tournament = false,
    tournament_mode = GAME_EVENT_TYPE.TM_NONE

    lbTable = null
    lbMode = null
  }

  defaultRequest = {
    economicName = null,
    lbField = "wins",
    pos = 0,
    rowsInPage = 1,
    inverse = false,
    forClans = false
    tournament = false,
    tournament_mode = -1

    lbTable = null
    lbMode = null
  }

  canRequestEventLb    = true
  leaderboardsRequestStack = []

  /**
   * Function requests leaderboards asynchronously and puts result
   * as argument to callback function
   */
  function requestLeaderboard(requestData, id, callback, context) {
    if (type(id) == "function") {
      context  = callback
      callback = id
      id = null
    }

    requestData = this.validateRequestData(requestData)

    let cachedData = this.getCachedLbResult(requestData, "leaderboards")

    //trigging callback if data is lready here
    if (cachedData) {
      if (context)
        callback.call(context, cachedData)
      else
        callback(cachedData)
      return
    }

    requestData.callBack <- Callback(callback, context)
    this.updateEventLb(requestData, id)
  }

  /**
   * Function requests self leaderboard row asynchronously and puts result
   * as argument to callback function
   */
  function requestSelfRow(requestData, id, callback, context) {
    if (type(id) == "function") {
      context  = callback
      callback = id
      id = null
    }

    requestData = this.validateRequestData(requestData)

    let cachedData = this.getCachedLbResult(requestData, "selfRow")

    //trigging callback if data is lready here
    if (cachedData) {
      if (context)
        callback.call(context, cachedData)
      else
        callback(cachedData)
      return
    }

    requestData.callBack <- Callback(callback, context)
    this.updateEventLbSelfRow(requestData, id)
  }

  function updateEventLbInternal(requestData, id, requestFunc, handleFunc) {
    let requestAction = Callback(function() {
      requestFunc(
        requestData,
        Callback(function(successData) {
          this.canRequestEventLb = false
          handleFunc(requestData, id, successData)

          if (this.leaderboardsRequestStack.len())
            this.leaderboardsRequestStack.remove(0).fn()
          else
            this.canRequestEventLb = true
        }, this),
        Callback(function(_errorId) {
          this.canRequestEventLb = true
        }, this)
      ) }, this)

    if (this.canRequestEventLb)
      return requestAction()

    if (id) {
      let lrs = this.leaderboardsRequestStack
      let l = lrs.len()
      for (local index=l-1; index>=0; --index) {
        if (id == lrs[index])
          lrs.remove(index)
      }
    }

    this.leaderboardsRequestStack.append({ fn = requestAction, id = id })
  }

  function updateEventLb(requestData, id) {
    this.updateEventLbInternal(requestData, id, this.requestUpdateEventLb, this.handleLbRequest)
  }

  function updateEventLbSelfRow(requestData, id) {
    this.updateEventLbInternal(requestData, id, this.requestEventLbSelfRow, this.handleLbSelfRowRequest)
  }

  /**
   * To request persoanl data for clan tournaments (TM_ELO_GROUP)
   * need to override tournament_mode by TM_ELO_GROUP_DETAIL
   */
  function requestUpdateEventLb(requestData, onSuccessCb, onErrorCb) {
    if (requestData.lbTable == null) {
      requestEventLeaderboardData(requestData, onSuccessCb, onErrorCb)
      return
    }
    requestCustomEventLeaderboardData(requestData, onSuccessCb, onErrorCb)
  }

  /**
   * to request persoanl data for clan tournaments (TM_ELO_GROUP)
   * need to override tournament_mode by TM_ELO_GROUP_DETAIL
   */
  function requestEventLbSelfRow(requestData, onSuccessCb, onErrorCb) {
    if (requestData.lbTable == null) {
      requestEventLeaderboardSelfRow(requestData, onSuccessCb, onErrorCb)
      return
    }

    requestCustomEventLeaderboardData(
      requestData.__merge({
        pos = null
        rowsInPage = 0
        userId = userIdInt64.value
      }),
      onSuccessCb, onErrorCb)
  }

  /**
   * Function generates hash string from leaderboard request data
   */
  function hashLbRequest(request_data) {
    local res = ""
    res += request_data.lbField
    res += getTblValue("rowsInPage", request_data, "")
    res += getTblValue("inverse", request_data, false)
    res += getTblValue("rowsInPage", request_data, "")
    res += getTblValue("pos", request_data, "")
    res += getTblValue("tournament_mode", request_data, "")
    return res
  }

  function handleLbRequest(requestData, id, requestResult) {
    let lbData = this.getLbDataFromBlk(requestResult, requestData)

    if (!(requestData.economicName in this.__cache.leaderboards))
      this.__cache.leaderboards[requestData.economicName] <- {}

    this.__cache.leaderboards[requestData.economicName][this.hashLbRequest(requestData)] <- {
      data = lbData
      timestamp = get_time_msec()
    }

    if (id)
      foreach (request in this.leaderboardsRequestStack)
        if (request.id == id)
          return

    if ("callBack" in requestData)
      if ("handler" in requestData)
        requestData.callBack.call(requestData.handler, lbData)
      else
        requestData.callBack(lbData)
  }

  function handleLbSelfRowRequest(requestData, id, requestResult) {
    let lbData = this.getSelfRowDataFromBlk(requestResult, requestData)

    if (!(requestData.economicName in this.__cache.selfRow))
      this.__cache.selfRow[requestData.economicName] <- {}

    this.__cache.selfRow[requestData.economicName][this.hashLbRequest(requestData)] <- {
      data = lbData
      timestamp = get_time_msec()
    }

    if (id)
      foreach (request in this.leaderboardsRequestStack)
        if (request.id == id)
          return

    if ("callBack" in requestData)
      if ("handler" in requestData)
        requestData.callBack.call(requestData.handler, lbData)
      else
        requestData.callBack(lbData)
  }

  /**
   * Checks cached response and if response exists and fresh returns it.
   * Otherwise returns null.
   */
  function getCachedLbResult(request_data, storage_name) {
    if (!(request_data.economicName in this.__cache[storage_name]))
      return null

    let hash = this.hashLbRequest(request_data)
    if (!(hash in this.__cache[storage_name][request_data.economicName]))
      return null

    if (get_time_msec() - this.__cache[storage_name][request_data.economicName][hash].timestamp > this.cashLifetime) {
      this.__cache[storage_name][request_data.economicName].$rawdelete(hash)
      return null
    }
    return this.__cache[storage_name][request_data.economicName][hash].data
  }

  function getMainLbRequest(event) {
    let newRequest = {}
    foreach (name, item in this.shortLbrequest)
      newRequest[name] <- (name in this) ? this[name] : item

    if (!event)
      return newRequest

    newRequest.economicName <- getEventEconomicName(event)
    newRequest.tournament <- getTblValue("tournament", event, false)
    newRequest.tournament_mode <- getEventTournamentMode(event)
    newRequest.forClans <- this.isClanLeaderboard(event)

    let sortLeaderboard = getTblValue("sort_leaderboard", event, null)
    let shortRow = (sortLeaderboard != null)
                      ? getLbCategoryTypeByField(sortLeaderboard)
                      : events.getTableConfigShortRowByEvent(event)
    newRequest.inverse = shortRow.inverse
    newRequest.lbField = shortRow.field
    if (event?.leaderboardEventTable ?? false) {
      newRequest.lbTable = event.leaderboardEventTable
      newRequest.lbMode = "stats"
      newRequest.lbField = event?.leaderboardEventBestStat ?? shortRow.field
    }

    return newRequest
  }

  function isClanLbRequest(requestData) {
    return getTblValue("forClans", requestData, false)
  }

  function validateRequestData(requestData) {
    foreach (name, field in this.defaultRequest)
      if (!(name in requestData))
        requestData[name] <- field
    return requestData
  }

  function compareRequests(req1, req2) {
    foreach (name, _field in this.defaultRequest) {
      if ((name in req1) != (name in req2))
        return false
      if (!(name in req1)) //no name in both req
        continue
      if (req1[name] != req2[name])
        return false
    }
    return true
  }

  function dropLbCache(event) {
    let economicName = getEventEconomicName(event)

    if (economicName in this.__cache.leaderboards)
      this.__cache.leaderboards.$rawdelete(economicName)

    if (economicName in this.__cache.selfRow)
      this.__cache.selfRow.$rawdelete(economicName)

    broadcastEvent("EventlbDataRenewed", { eventId = event.name })
  }

  function getLbDataFromBlk(blk, requestData) {
    let lbRows = this.lbBlkToArray(blk)
    if (this.isClanLbRequest(requestData))
      foreach (lbRow in lbRows)
        this.postProcessClanLbRow(lbRow)

    let superiorityBattlesThreshold = blk?.superiorityBattlesThreshold ?? 0
    if (superiorityBattlesThreshold > 0)
      foreach (lbRow in lbRows)
        lbRow["superiorityBattlesThreshold"] <- superiorityBattlesThreshold

    let res = {
      rows = lbRows
      updateTime = (blk?.lastUpdateTime ?? "0").tointeger()
    }
    return res
  }

  function getSelfRowDataFromBlk(blk, requestData) {
    let res = this.lbBlkToArray(blk)
    if (this.isClanLbRequest(requestData))
      foreach (lbRow in res)
        this.postProcessClanLbRow(lbRow)
    return res
  }

  function lbBlkToArray(blk) {
    if (type(blk) == "table") {
      return convertLeaderboardData(blk).rows
    }
    let res = []
    foreach (row in blk % "event") {
      let table = {}
      for (local i = 0; i < row.paramCount(); i++)
        table[row.getParamName(i)] <- row.getParamValue(i)
      res.append(table)
    }
    return res
  }

  function isClanLeaderboard(event) {
    if (!getTblValue("tournament", event, false))
      return isEventForClan(event)
    return getEventTournamentMode(event) == GAME_EVENT_TYPE.TM_ELO_GROUP
  }

  function postProcessClanLbRow(lbRow) {
    //check clan name for tag.
    //new leaderboards name param is in forma  "<tag> <name>"
    //old only "<name>"
    //but even with old leaderboards we need something to write in tag for short lb
    let name = getTblValue("name", lbRow)
    if (!u.isString(name) || !name.len())
      return

    local searchIdx = -1
    for (local skipSpaces = 0; skipSpaces >= 0; skipSpaces--) {
      searchIdx = name.indexof(" ", searchIdx + 1)
      if (searchIdx == null) { //no tag at all
        lbRow.tag <- name
        break
      }
      //tag dont have spaces, but it decoaration can be double space
      if (searchIdx == 0) {
        skipSpaces = 2
        continue
      }
      if (skipSpaces > 0)
        continue

      lbRow.tag <- name.slice(0, searchIdx)

      //code to cut tag from name, but need to new leaderboards mostly updated before this change
      //or old leaderboards rows will look broken.
      //char commit appear on test server 12.05.2015
      //if (searchIdx + 1 < name.len())
      //  lbRow.name <- name.slice(searchIdx + 1)
    }
  }

  function resetLbCache() {
    this.__cache.leaderboards.clear()
    this.__cache.selfRow.clear()
  }
}

let Events = class {
  constructor() {
    chapters = ::EventChaptersManager()
    this.initBrToTierConformity()
    subscribe_handler(this, g_listener_priority.DEFAULT_HANDLER)
  }

  function initBrToTierConformity() {
    let brToTierBlk = GUI.get()?.events_br_to_tier_conformity
    if (!brToTierBlk)
      return

    brToTier.clear()
    foreach (p2 in brToTierBlk % "brToTier")
      if (u.isPoint2(p2))
        brToTier[p2.x] <- p2.y.tointeger()
  }

  function getTableConfigShortRowByEvent(event) {
    foreach (row in eventsTableConfig)
      if (row.isDefaultSortRowInEvent(event))
        return row
    return null
  }

  function getLbCategoryByField(field) {
    let category = getLbCategoryTypeByField(field)
    return isInArray(category, eventsTableConfig) ? category : null
  }

  function updateEventsData(newEventsData) {
    __game_events = this.mergeEventsInfo(__game_events, newEventsData)
    chapters.updateChapters()
    eventsLoaded = true
    seenEvents.setDaysToUnseen(EVENTS_OUT_OF_DATE_DAYS)
    seenEvents.onListChanged()
    broadcastEvent("EventsDataUpdated")
    unallowedEventEconomicNamesNeedUpdate = true
  }

  function isTankEventActive(eventPrefix) {
    foreach (event in __game_events) {
      if (event.name.len() >= eventPrefix.len() &&
          event.name.slice(0, eventPrefix.len()) == eventPrefix &&
          this.isEventEnabled(event))
        return true
    }
    return false
  }

  function getTankEvent(eventPrefix) {
    foreach (event in __game_events)
      if (event.name.len() >= eventPrefix.len() &&
          event.name.slice(0, eventPrefix.len()) == eventPrefix &&
          this.isEventEnabled(event))
        return event
    return null
  }

  function getTankEventName(eventPrefix) {
    let event = this.getTankEvent(eventPrefix)
    return event && event.name
  }

  function setDifficultyWeight(event) {
    local diffWeight = null
    if (!("mission_decl" in event) ||
        !("difficulty" in event.mission_decl) ||
        event.mission_decl.difficulty == ""
       )
      diffWeight = -1
    else {
      diffWeight = diffTable[event.mission_decl.difficulty]
      if (this.isDifficultyCustom(event))
        diffWeight++
    }
    return diffWeight
  }

  function isEventEnableOnDebug(event) {
    return (event?.enableOnDebug  ?? false) && !this.hasEventEndTime(event)
  }

  function isEventNeedInfoButton(event) {
    if (!isMultiplayerPrivilegeAvailable.value)
      return false

    if (!event)
      return false
    return isEventForClan(event) || isEventWithLobby(event) || this.isEventEnableOnDebug(event)
  }

  function openEventInfo(event) {
    if (isEventWithLobby(event))
      gui_handlers.EventRoomsHandler.open(event)
    else
      loadHandler(gui_handlers.EventDescriptionWindow, { event = event })
  }

  /**
   * Returns "true" if event is not debug or client
   * has specific feature: ShowDebugEvents
   */
  function checkEnableOnDebug(event) {
    return !this.isEventEnableOnDebug(event) || hasFeature("ShowDebugEvents")
  }

  function isEventDisplayWide(event) {
    return (event?.displayWide ?? false) && !this.isEventEnableOnDebug(event)
  }

  function checkTankEvents() {
    foreach (event in __game_events) {
      if (isEventRandomBattles(event) && this.isEventEnabled(event))
        return true
    }
    return false
  }

  function isUnitTypeAvailable(event, unitType) {
    return (this.getEventUnitTypesMask(event) & (1 << unitType)) != 0
  }

  function isUnitTypeRequired(event, unitType, valueWhenNoRequiredUnits = false) {
    let reqUnitTypesMask = this.getEventRequiredUnitTypesMask(event)
    return reqUnitTypesMask != 0 ? ((reqUnitTypesMask & (1 << unitType)) != 0) : valueWhenNoRequiredUnits
  }

  function getEventUnitTypesMask(event) {
    if (!("unitTypesMask" in event))
      event.unitTypesMask <- this.countAvailableUnitTypes(event)
    return event.unitTypesMask
  }

  function getEventRequiredUnitTypesMask(event) {
    if (!("reqUnitTypesMask" in event))
      event.reqUnitTypesMask <- this.countRequiredUnitTypesMask(event)
    return event.reqUnitTypesMask
  }

  function getBaseUnitTypefromRule(rule, checkAllAvailable) {
    if (!("class" in rule))
      return ES_UNIT_TYPE_INVALID
    if (checkAllAvailable)
      foreach (key in ["name", "type"])
        if (key in rule)
          return ES_UNIT_TYPE_INVALID
    return ::getUnitTypeByText(rule["class"])
  }

  function getMatchingUnitType(unit) {
    let matchingUnitType = getEsUnitType(unit)
    // override boats as ships because there are no boats on the matching
    if (matchingUnitType == ES_UNIT_TYPE_BOAT)
      return ES_UNIT_TYPE_SHIP
    return matchingUnitType
  }

  /**
   * Supports event objects and session lobby info as parameter.
   */
  function countAvailableUnitTypes(teamDataByTeamName) {
    local resMask = 0
    foreach (team in this.getSidesList()) {
      let teamData = this.getTeamData(teamDataByTeamName, team)
      if (!teamData || !this.isTeamDataPlayable(teamData))
        continue

      local teamUnitTypes = 0
      foreach (rule in this.getAlowedCrafts(teamData)) {
        local unitType = this.getBaseUnitTypefromRule(rule, false)
        if ("name" in rule) {
          let unit = getAircraftByName(rule.name)
          if (unit)
            unitType = this.getMatchingUnitType(unit)
        }
        if (unitType >= 0)
          teamUnitTypes = teamUnitTypes | (1 << unitType)
        if (unitType == ES_UNIT_TYPE_SHIP)
          teamUnitTypes = teamUnitTypes | (1 << ES_UNIT_TYPE_BOAT)
      }
      if (!teamUnitTypes)
        teamUnitTypes = allUnitTypesMask

      foreach (rule in this.getForbiddenCrafts(teamData)) {
        let unitType = this.getBaseUnitTypefromRule(rule, true)
        if (unitType >= 0)
          teamUnitTypes = teamUnitTypes & ~(1 << unitType)
        if (unitType == ES_UNIT_TYPE_SHIP)
          teamUnitTypes = teamUnitTypes & ~(1 << ES_UNIT_TYPE_BOAT)
      }

      resMask = resMask | teamUnitTypes
      if (resMask == allUnitTypesMask)
        break
    }
    return resMask
  }

  function getUnitTypesByTeamDataAndName(teamData, teamName) {
    if (teamData == null)
      return allUnitTypesMask
    return this.countAvailableUnitTypes({ [teamName] = teamData })
  }

  //result 0 - no required crafts
  function countRequiredUnitTypesMaskByTeamData(teamData) {
    local res = 0
    let reqCrafts = this.getRequiredCrafts(teamData)
    foreach (rule in reqCrafts) {
      local unitType = this.getBaseUnitTypefromRule(rule, false)
      if ("name" in rule) {
        let unit = getAircraftByName(rule.name)
        if (unit)
          unitType = this.getMatchingUnitType(unit)
      }
      if (unitType != ES_UNIT_TYPE_INVALID)
        res = res | (1 << unitType)
      if (unitType == ES_UNIT_TYPE_SHIP)
        res = res | (1 << ES_UNIT_TYPE_BOAT)
    }
    return res
  }

  function countRequiredUnitTypesMask(event) {
    local res = 0
    foreach (team in this.getSidesList()) {
      let teamData = this.getTeamData(event, team)
      if (!teamData || !this.isTeamDataPlayable(teamData))
        continue

      res = res | this.countRequiredUnitTypesMaskByTeamData(teamData)
    }
    return res
  }

  /**
   * Returns list of events for game mode select menu
   */
  function getEventsForGcDrawer() {
    return this.getEventsList(EVENT_TYPE.ANY & (~EVENT_TYPE.NEWBIE_BATTLES),
      @(event) getEventDisplayType(event).showInGamercardDrawer && this.isEventActive(event))
  }

  function getVisibleEventsList() {
    return this.getEventsList(EVENT_TYPE.ANY,
      @(event) (this.checkEnableOnDebug(event) || this.getEventIsVisible(event)))
  }

  function getEventsForEventsWindow() {
    return this.getEventsList(EVENT_TYPE.ANY_BASE_EVENTS,  this.isEventVisibleInEventsWindow)
  }

  function _initEventViewData(eventData) {
    if (!("view_data" in eventData))
      return

    //override event params by predefined config by designers.
    //!!FIX ME: teporary support of multi events before it will be done in more correct way, without strange data.
    let sourceInfo = {}
    foreach (key, value in eventData.view_data) {
      if (key == "teamA" || key == "teamB") {
        if (key in eventData) {
          sourceInfo[key] <- eventData[key]
          eventData[key] = clone eventData[key]
        }
        else
          eventData[key] <- {}

        foreach (key2, value2 in value)
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

  function _calcEventDisplayType(event) {
    if (!g_difficulty.isDiffCodeAvailable(this.getEventDiffCode(event), GM_DOMINATION))
      return g_event_display_type.NONE

    local res = g_event_display_type.REGULAR
    let checkNewbieEvent = isNewbieEventId(event.name)
    let checkBasicArcade = isInArray(event.name, eventIdsForMainGameModeList)
    if (checkNewbieEvent || checkBasicArcade)
      res = g_event_display_type.RANDOM_BATTLE
    else if (!isEventVisibleByFeature(event))
      res = g_event_display_type.NONE
    else {
      let displayTypeName = event?.displayType
      if (displayTypeName != null)
        res = g_event_display_type.getTypeByName(displayTypeName)
    }
    return res
  }

  function _initEventParams(eventData) {
    if (!("teamA" in eventData) && "team" in eventData) {
      eventData.teamA <- eventData.team
      eventData.$rawdelete("team")
    }

    this._initEventViewData(eventData)

    eventData.diffWeight <- this.setDifficultyWeight(eventData)
    if ("event_access" in eventData && u.isString(eventData.event_access))
      eventData.event_access <- split_by_chars(eventData.event_access, "; ")

    setEventDisplayType(eventData, this._calcEventDisplayType(eventData))

    eventData.enableOnDebug <- eventData?.enableOnDebug ?? false
    if (("specialRequirements" in eventData) && !u.isArray(eventData.specialRequirements))
      eventData.specialRequirements <- [eventData.specialRequirements]

    if (("loc_name" in eventData) && !u.isString(eventData.loc_name)) {
      assert(false, "Bad event loc_name. eventName = " + eventData.name + ", " +
                             "economicName = " + getEventEconomicName(eventData) + ", loc_name = " + toString(eventData.loc_name))
      eventData.$rawdelete("loc_name")
    }

    return eventData
  }

  function mergeEventsInfo(curEventsData, newEventsData) {
    let activeEvents = this.getActiveEventsList(EVENT_TYPE.ANY)
    foreach (event in activeEvents)
      curEventsData.$rawdelete(event)
    foreach (eventId, eventData in newEventsData) {
      if (this.isCustomGameMode(eventData))
        continue

      let event = this._initEventParams(clone eventData)
      if (this.checkEventAccess(event))
        curEventsData[eventId] <- event
    }
    return curEventsData
  }

  function checkEventAccess(eventData) {
    if (useTouchscreen && eventData.diffWeight >= diffTable.hardcore)
      return false

    if (!("event_access" in eventData))
      return true
    if (isInArray("AccessTest", eventData.event_access) && !has_entitlement("AccessTest"))
      return false
    if (isInArray("ps4", eventData.event_access) && !isPlatformSony)
      return false
    if (isInArray("pc", eventData.event_access) && !isPlatformPC)
      return false
    return true
  }

  function recalcAllEventsDisplayType() {
    local isChanged = false
    foreach (event in __game_events) {
      let displayType = this._calcEventDisplayType(event)
      if (displayType == getEventDisplayType(event))
        continue

      setEventDisplayType(event, displayType)
      isChanged = true
    }

    if (isChanged) {
      chapters.updateChapters()
      broadcastEvent("EventsDataUpdated")
    }
  }

  function checkEventId(eventId) {
    if (__game_events?[eventId] != null)
      return true
    return false
  }

  function getEvent(event_id) {
    return this.checkEventId(event_id) ? __game_events[event_id] : null
  }

  function getMGameMode(event, room) {
    return (room && ::SessionLobby.getMGameMode(room)) || event
  }

  function getEventByEconomicName(economicName) {
    foreach (event in __game_events)
      if (getEventEconomicName(event) == economicName)
        return event
    return null
  }

  function getLastPlayedEvent() {
    let eventData = loadLocalByAccount("lastPlayedEvent", null)
    if (eventData == null)
      return null
    let event = this.getEvent(eventData?.eventName)
    if (event != null)
      return event
    return this.getEventByEconomicName(eventData?.economicName)
  }

  /**
   * returns true if events queue multiclustered
   */
  function isMultiCluster(event) {
    return event?.multiCluster ?? false
  }

  function getEDiffByEvent(event) {
    if (!("ediff" in event)) {
      let difficulty = this.getEventDifficulty(event)
      event.ediff <- difficulty.getEdiffByUnitMask(this.getEventUnitTypesMask(event))
    }
    return event.ediff
  }

  function getUnitEconomicRankByEvent(event, unit) {
    let ediff = this.getEDiffByEvent(event)
    return unit.getEconomicRank(ediff)
  }

  function getTeamData(eventData, team) {
    return eventData?[this.getTeamName(team)]
  }

  function getTeamDataWithRoom(event, team, room) {
    if (room)
      return ::SessionLobby.getTeamData(team, room)
    return this.getTeamData(event, team)
  }

  //check is team data allowed to play in this event.
  //doesnt depend on any player parameters.
  function isTeamDataPlayable(teamData) {
    return (teamData?.maxTeamSize ?? 1) > 0
  }

  function initSidesOnce(event) {
    if (event?._isSidesInited)
      return

    local sides = []
    foreach (team in fullTeamsList)
      if (this.isTeamDataPlayable(this.getTeamData(event, team)))
        sides.append(team)

    let isFreeForAll = event?.ffa ?? false
    local isSymmetric = isFreeForAll || (event?.isSymmetric ?? false) || sides.len() <= 1
    //no point to save duplicate array, just link on fullTeamsList
    if (!isSymmetric) {
      let teamDataA = this.getTeamData(event, sides[0])
      let teamDataB = this.getTeamData(event, sides[1])
      if (teamDataA == null || teamDataB == null) {
        let economicName = event?.economicName  // warning disable: -declared-never-used
        script_net_assert_once("not found event teamdata", "missing teamdata in event")
      }
      else
        isSymmetric = isSymmetric || this.isTeamsEqual(teamDataA, teamDataB)
    }
    if (isSymmetric && sides.len() > 1)
      sides = [sides[0]]

    event.sidesList <- sides
    event.isSymmetric <- isSymmetric
    event.isFreeForAll <- isFreeForAll
  }

  function isTeamsEqual(teamAData, teamBData) {
    if (teamAData.len() != teamBData.len())
      return false

    foreach (key, value in teamAData) {
      if (key == "forcedCountry")
        continue

      if (!(key in teamBData) || !u.isEqual(value, teamBData[key]))
        return false
    }

    return true
  }

  function getSidesList(event = null) {
    if (!event)
      return fullTeamsList
    this.initSidesOnce(event)
    return event.sidesList
  }

  function isEventSymmetricTeams(event) {
    this.initSidesOnce(event)
    return event.isSymmetric
  }

  function needRankInfoInQueue(event) {
    return event?.balancerMode == "mrank"
  }

  function isEventFreeForAll(event) {
    this.initSidesOnce(event)
    return event.isFreeForAll
  }

  function getTeamName(teamCode) {
    return g_team.getTeamByCode(teamCode).name
  }

  function isEventXboxOnlyAllowed(event) {
    return (event?.xboxOnlyAllowed ?? false) && isPlatformXboxOne
  }

  function isEventPS4OnlyAllowed(event) {
    return (event?.ps4OnlyAllowed ?? false) && isPlatformSony
  }

  function isEventPlatformOnlyAllowed(event) {
    return this.isEventXboxOnlyAllowed(event) || this.isEventPS4OnlyAllowed(event)
  }

  /**
   * Returns name of suitable image for game mode selection menu.
   * Name could be got from events config or generated by difiiculty level and
   * available unit type
   */
  function getEventTileImageName(event, isWide = false) {
    if ("eventImage" in event) {
      let eventImageTemplate = event.eventImage
      return format(eventImageTemplate, isWide ? "wide" : "thin")
    }

    local res = ""
    if (this.isUnitTypeAvailable(event, ES_UNIT_TYPE_TANK) && this.isUnitTypeAvailable(event, ES_UNIT_TYPE_AIRCRAFT))
      res += "mixed"
    else if (this.isUnitTypeAvailable(event, ES_UNIT_TYPE_SHIP))
      res += "ship"
    else if (!this.isUnitTypeAvailable(event, ES_UNIT_TYPE_TANK))
      res += "air"
    else if (!this.isUnitTypeAvailable(event, ES_UNIT_TYPE_AIRCRAFT))
      res += "tank"
    return this.wrapImageName(this.getEventDiffName(event.name, true) + "_" + res, isWide)
  }

  function wrapImageName(imageName, isWide) {
    return format("#ui/images/game_modes_tiles/%s?P1", imageName + (isWide ? "_wide" : "_thin"))
  }

  function getEventPreviewVideoName(event, isWide) {
    //We can't check is video exist. For now, there is no wide videos.
    //So, this function return null in this case.
    if (isWide)
      return null

    let isEventNeedPreview = (isInArray(event.name, eventIdsForMainGameModeList) ||
      (getEventDisplayType(event).showInGamercardDrawer && this.isEventActive(event)))

    if (!isEventNeedPreview)
      return null

    let customVideoPreviewName = this.getCustomVideioPreviewName(event)
    if (customVideoPreviewName)
      return customVideoPreviewName == "" ? null : customVideoPreviewName

    local unitTypeName = ""
    if (this.isUnitTypeAvailable(event, ES_UNIT_TYPE_SHIP))
      unitTypeName += "ship"
    else if (this.isUnitTypeAvailable(event, ES_UNIT_TYPE_TANK))
      unitTypeName += "tank"
    else if (this.isUnitTypeAvailable(event, ES_UNIT_TYPE_AIRCRAFT))
      unitTypeName += "air"

    return $"video/gameModes/{unitTypeName}_{this.getEventDiffName(event.name, true)}.ivf"
  }

  function getCustomVideioPreviewName(event) {
    return event?.customVideoPreviewName
  }

  function isEventEnabled(event) {
    return !!event
      && !event?.disabled
      && (!this.hasEventEndTime(event) || this.getEventEndTime(event) > 0)
  }

  function getEventsList(typeMask = EVENT_TYPE.ANY_BASE_EVENTS, testFunc = function (_event) { return true }) {
    let result = []
    foreach (event in __game_events)
      if (isEventMatchesType(event, typeMask) && testFunc(event))
        result.append(event.name)
    return result
  }

  function __countEventsList(typeMask = EVENT_TYPE.ANY_BASE_EVENTS, testFunc = function (_event) { return true }) {
    local result = 0
    foreach (event in __game_events)
      if (isEventMatchesType(event, typeMask) && testFunc(event))
        result++
    return result
  }

  function getEventsCount(typeMask = EVENT_TYPE.ANY_BASE_EVENTS) {
    return this.__countEventsList(typeMask, this.isEventEnabled)
  }

  function isEventActive(event) {
    return this.isEventEnabled(event)
  }

  function isEventEnded(event) {
    return !this.isEventEnabled(event) && this.getEventEndTime(event) < 0
  }

  //return true if it possible to join this event.
  function isEventAllowed(event) {
    return getEventDisplayType(event) != g_event_display_type.NONE
      && this.checkEventFeature(event, true)
      && this.isEventAllowedByComaptibilityMode(event)
      && (!this.eventRequiresTicket(event) || this.getEventActiveTicket(event) != null)
  }

  isEventAllowedByComaptibilityMode = @(event) event?.isAllowedForCompatibility != false || !isCompatibiliyMode()

  function getEventsVisibleInEventsWindowCount() {
    return this.__countEventsList(EVENT_TYPE.ANY, this.isEventVisibleInEventsWindow)
  }

  function getActiveEventsList(typeMask = EVENT_TYPE.ANY_BASE_EVENTS) {
    let result = this.getEventsList(typeMask, function (event) {
      return getEventDisplayType(event).showInEventsWindow && this.isEventActive(event)
    }.bindenv(this))
    result.sort(function (a, b) {
        return this.sortEventsByDiff(a, b)
      }.bindenv(this))
    return result
  }

  function getEndedEventsCount(_filterType = EVENT_TYPE.ANY_BASE_EVENTS) {
    return this.__countEventsList(this.typeMask, function (event) {
      return getEventDisplayType(event).showInEventsWindow && this.isEventEnded(event)
      }.bindenv(this))
  }

  function getEndedEventsList(typeMask = EVENT_TYPE.ANY_BASE_EVENTS) { //disable: -similar-function
    let result = this.getEventsList(typeMask, function (event) {
      return getEventDisplayType(event).showInEventsWindow && this.isEventEnded(event)
    }.bindenv(this))
    result.sort(function (a, b) {
        return this.sortEventsByDiff(a, b)
      }.bindenv(this))
    return result
  }

  onEventInventoryUpdate = @(_p) unallowedEventEconomicNamesNeedUpdate = true

  function getUnallowedEventEconomicNames() {
    if (!unallowedEventEconomicNamesNeedUpdate)
      return unallowedEventEconomicNames

    unallowedEventEconomicNames.clear()
    foreach (event in __game_events)
      if (!this.isEventAllowed(event))
        u.appendOnce(getEventEconomicName(event), unallowedEventEconomicNames, true)
    unallowedEventEconomicNamesNeedUpdate = false
    return unallowedEventEconomicNames
  }

  function getCountries(teamData) {
    if (!teamData)
      return []
    return teamData.countries
  }

  function getCountriesByTeams(event) {
    let res = []
    foreach (team in this.getSidesList(event))
      res.append(this.getCountries(this.getTeamData(event, team)))
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
  function getAllCountriesSets(event) {
    if ("_allCountriesSets" in event)
      return event._allCountriesSets

    let res = []
    let mgmList = getGameModesByEconomicName(getEventEconomicName(event))
    mgmList.sort(function(a, b) { return a.gameModeId - b.gameModeId }) //same order on all clients
    foreach (mgm in mgmList) {
      if (this.isCustomGameMode(mgm))
        continue

      let countries = this.getCountriesByTeams(mgm)
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

  function getAvailableTeams(event, room = null) {
    let availableTeams = []
    if (!event)
      return availableTeams
    let playersCurCountry = profileCountrySq.value
    if (!playersCurCountry || playersCurCountry.len() <= 0)
      return availableTeams

    let mgm = this.getMGameMode(event, room)
    foreach (team in this.getSidesList(this.isLobbyGameMode(mgm) ? null : mgm)) {
      let teamData = this.getTeamDataWithRoom(event, team, room)
      if (isInArray(playersCurCountry, this.getCountries(teamData)))
        availableTeams.append(team)
    }
    return availableTeams
  }

  function isCountryAvailable(event, country) {
    let sidesList = this.getSidesList(event)
    foreach (team in sidesList) {
      let countries = this.getTeamData(event, team)?.countries
      if (countries && isInArray(country, countries))
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
  function getAvailableCountriesByEvent(event) {
    let result = []
    foreach (country in shopCountriesList)
      if (this.isCountryAvailable(event, country))
        result.append(country)

    return result.len() < shopCountriesList.len() ? result : []
  }

  function isUnitMatchesRule(unit, rulesList, defReturn = false, ediff = -1) {
    if (rulesList.len() <= 0)
      return defReturn

    if (u.isString(unit))
      unit = getAircraftByName(unit)
    if (!unit)
      return false

    let maxEconomicRank = getMaxEconomicRank()
    foreach (rule in rulesList) {
      if ("name" in rule) {
        if (rule.name == unit.name)
          return true
        continue
      }

      if ("mranks" in rule) {
        let unitMRank = ediff != -1 ? unit.getEconomicRank(ediff) : 0
        if (unitMRank < (rule.mranks?.min ?? 0) || (rule.mranks?.max ?? maxEconomicRank) < unitMRank)
          continue
      }

      if (("ranks" in rule)
          && (unit.rank < (rule.ranks?.min ?? 0) || (rule.ranks?.max ?? ::max_country_rank) < unit.rank))
        continue

      let unitType = this.getBaseUnitTypefromRule(rule, false)
      if (unitType != ES_UNIT_TYPE_INVALID && unitType != this.getMatchingUnitType(unit))
        continue
      if (("type" in rule) && (getWpcostUnitClass(unit.name) != "exp_" + rule.type))
        continue

      return true
    }
    return false
  }

  function getTierByMaxBr(maxBR) {
    local res = -1
    local foundBr = 0
    foreach (br, tier in brToTier)
      if (br == maxBR)
        return tier
      else if ((br < 0 && !foundBr) || (br > maxBR && (br < foundBr || foundBr <= 0))) {
        foundBr = br
        res = tier
      }
    return res
  }

  //return -1 if not tier detected
  function getTierNumByRule(rule) {
    if (!("mranks" in rule))
      return -1

    let maxBR = calcBattleRatingFromRank(rule.mranks?.max ?? getMaxEconomicRank())
    return this.getTierByMaxBr(maxBR)
  }

  function getBrTextByRules(rules) {
    let rule = rules?[0]
    if (rule == null)
      return ""

    let mranks = rule.mranks
    let minBR = calcBattleRatingFromRank(mranks?.min ?? 0)
    let maxBR = calcBattleRatingFromRank(mranks?.max ?? getMaxEconomicRank())
    let brText = "".concat(format("%.1f", minBR),
      ((minBR != maxBR) ? "".concat(" - ", format("%.1f", maxBR)) : ""))
    return loc("ui/tier", { text = brText })
  }

  function isUnitAllowedForEvent(event, unit) {
    foreach (team in events.getSidesList(event))
      if (this.isUnitAllowed(event, team, unit.name))
        return true

    return false
  }

  function isUnitAllowedForEventRoom(event, room, unit) {
    let roomSpecialRules = room && ::SessionLobby.getRoomSpecialRules(room)
    if (roomSpecialRules && !this.isUnitMatchesRoomSpecialRules(unit, roomSpecialRules, this.getEDiffByEvent(event)))
      return false

    let mGameMode = events.getMGameMode(event, room)
    return this.isUnitAllowedForEvent(mGameMode, unit)
  }

  function isUnitAllowed(event, team, airName) {
    let teamData = this.getTeamData(event, team)
    let ediff = this.getEDiffByEvent(event)
    return teamData ? this.isUnitAllowedByTeamData(teamData, airName, ediff) : false
  }

  function isUnitMatchesRoomSpecialRules(unit, roomSpecialRules, ediff) {
    return !roomSpecialRules || this.isUnitMatchesRule(unit, roomSpecialRules, true, ediff)
  }

  function isCurUnitMatchesRoomRules(event, room) {
    let unit = getCurSlotbarUnit()
    if (!unit)
      return false

    let roomSpecialRules = room && ::SessionLobby.getRoomSpecialRules(room)
    return !roomSpecialRules || this.isUnitMatchesRoomSpecialRules(unit, roomSpecialRules, this.getEDiffByEvent(event))
  }

  function checkRequiredUnits(event, room = null, country = null) {
    if (!event)
      return false

    let playersCurCountry = country ?? profileCountrySq.value
    let ediff = this.getEDiffByEvent(event)

    foreach (team in this.getSidesList(event)) {
      let teamData = this.getTeamDataWithRoom(event, team, room)
      if (!this.getRequiredCrafts(teamData).len()
          || !isInArray(playersCurCountry, teamData.countries))
       continue

      let crews = getCrewsListByCountry(playersCurCountry)
      foreach (crew in crews) {
        if (isCrewLockedByPrevBattle(crew))
          continue

        let unit = getCrewUnit(crew)
        if (unit && this.isAirRequiredAndAllowedByTeamData(teamData, unit.name, ediff))
          return true
      }
      return false //is it correct that we check only first teamData with requirements?
    }
    return true
  }

  function isAirRequiredAndAllowedByTeamData(teamData, airName, ediff) {
    return (this.isUnitMatchesRule(airName, this.getRequiredCrafts(teamData), true, ediff)
        && this.isUnitAllowedByTeamData(teamData, airName, ediff))
  }

  function isUnitAllowedByTeamData(teamData, airName, ediff = -1) {
    let unit = getAircraftByName(airName)
    if (!unit || unit.disableFlyout)
      return false
    if (!isInArray(unit.shopCountry, this.getCountries(teamData)))
      return false

    let airInAllowedList = this.isUnitMatchesRule(unit, this.getAlowedCrafts(teamData), true, ediff)
    let airInForbidenList = this.isUnitMatchesRule(unit, this.getForbiddenCrafts(teamData), false, ediff)
    return !airInForbidenList && airInAllowedList
  }

  function checkUnitRelevanceForEvent(eventId, unit) {
    let event = this.getEvent(eventId)
    return (!event || !unit) ? UnitRelevance.NONE
     : this.isUnitAllowedForEvent(event, unit) ? UnitRelevance.BEST
     : this.isUnitTypeAvailable(event, unit.unitType.esUnitType) ? UnitRelevance.MEDIUM
     : UnitRelevance.NONE
  }

  function getSpecialRequirements(event) {
    return event?.specialRequirements
  }

  function checkSpecialRequirements(event) {
    let requirements = this.getSpecialRequirements(event)
    if (!requirements)
      return true

    let ediff = this.getEDiffByEvent(event)
    foreach (unit in getAllUnits())
       if (::isUnitUsable(unit) && this.isUnitMatchesRule(unit, requirements, true, ediff))
         return true
    return false
  }

  function checkPlayerCountryCrafts(country, teamData, ediff, roomSpecialRules = null) {
    let crews = getCrewsListByCountry(country)
    foreach (crew in crews) {
      if (isCrewLockedByPrevBattle(crew))
        continue

      let unit = getCrewUnit(crew)
      if (unit
          && (!roomSpecialRules || this.isUnitMatchesRule(unit, roomSpecialRules, true, ediff))
          && this.isUnitAllowedByTeamData(teamData, crew.aircraft, ediff)
         )
        return true
    }
    return false
  }

  function checkPlayersCrafts(event, room = null) {
    let mGameMode = events.getMGameMode(event, room)
    let roomSpecialRules = room && ::SessionLobby.getRoomSpecialRules(room)
    let playersCurCountry = profileCountrySq.value
    let ediff = this.getEDiffByEvent(event)
    foreach (team in this.getSidesList(mGameMode)) {
      let teamData = this.getTeamDataWithRoom(mGameMode, team, room)
      if (teamData && isInArray(playersCurCountry, teamData.countries)
          && this.checkPlayerCountryCrafts(playersCurCountry, teamData, ediff, roomSpecialRules))
          return true
    }
    return false
  }

  function checkPlayersCraftsRoomRules(event, room) {
    let roomSpecialRules = ::SessionLobby.getRoomSpecialRules(room)
    if (!roomSpecialRules)
      return true
    let ediff = this.getEDiffByEvent(event)
    foreach (crew in getCrewsListByCountry(profileCountrySq.value)) {
      let unit = getCrewUnit(crew)
      if (unit && this.isUnitMatchesRoomSpecialRules(unit, roomSpecialRules, ediff))
        return true
    }
    return false
  }

  function getSlotbarRank(event, country, idInCountry) {
    local res = 0
    let isMultiSlotEnabled = this.isEventMultiSlotEnabled(event)
    foreach (idx, crew in getCrewsListByCountry(country)) {
      if (!isMultiSlotEnabled && idInCountry != idx)
        continue

      let unit = getCrewUnit(crew)
      if (!unit)
        continue
      if (!this.isUnitAllowedForEvent(event, unit))
        continue
      if (::isUnitBroken(unit))
        continue

      res = max(res, unit.rank)
    }
    return res
  }

  function getCountryRepairInfo(event, room, country) {
    let mGameMode = events.getMGameMode(event, room)
    let roomSpecialRules = room && ::SessionLobby.getRoomSpecialRules(room)
    let teams = this.getAvailableTeams(mGameMode)
    let ediff = this.getEDiffByEvent(event)
    let teamsData = []
    foreach (t in teams)
      teamsData.append(this.getTeamData(mGameMode, t))

    return ::getBrokenAirsInfo([country], this.isEventMultiSlotEnabled(event),
      function(unit) {
        if (roomSpecialRules
            && !this.isUnitMatchesRule(unit, roomSpecialRules, true, ediff))
          return false
        foreach (td in teamsData)
          if (this.isUnitAllowedByTeamData(td, unit.name, ediff))
            return true
        return false
      }.bindenv(this))
  }

  function stackMemberErrors(members) {
    let res = []
    foreach (member in members) {
      let stack = u.search(res, @(s) s.status == member.status)
      if (stack)
        stack.names.append(getPlayerName(member.name))
      else
        res.append({
          names = [getPlayerName(member.name)]
          status = member.status
        })
    }
    return res
  }

  function showCantFlyMembersMsgBox(teamData, continueQueueFunc = null, cancelFunc = null) {
    let langConfig = [SQUAD_NOT_READY_LOC_TAG]
    let langConfigByTeam = {}
    local singleLangConfig = null

    foreach (idx, membersData in teamData.cantFlyData) {
      let teamCode = membersData?.team ?? idx
      let stacks = this.stackMemberErrors(membersData.members)
      let teamLangConfig = stacks.map(@(s) [
        systemMsg.makeColoredValue(COLOR_TAG.USERLOG, ", ".join(s.names, true)),
        "ui/colon",
        ::g_squad_utils.getMemberStatusLocTag(s.status)
      ])
      langConfigByTeam[teamCode] <- teamLangConfig
      if (idx == 0)
        singleLangConfig = teamLangConfig
      else if (!u.isEqual(teamLangConfig, singleLangConfig))
        singleLangConfig = null
    }

    if (singleLangConfig)
      langConfig.extend(singleLangConfig)
    else
      foreach (teamCode, teamLangConfig in langConfigByTeam) {
        langConfig.append({ [systemMsg.LOC_ID] = "events/" + g_team.getTeamByCode(teamCode).name })
        langConfig.extend(teamLangConfig)
      }

    let buttons = [ ["no", cancelFunc ] ]
    if (teamData.haveRestrictions && teamData.canFlyout)
      buttons.insert(0, ["yes", continueQueueFunc ])

    scene_msg_box("members_cant_fly",
                    null,
                    systemMsg.configToLang(langConfig, null, "\n"),
                    buttons,
                    "no",
                    { cancel_fn = cancelFunc })

    ::g_chat.sendLocalizedMessageToSquadRoom(langConfig)
  }

  function getMembersTeamsData(event, room, teams) {
    if (!g_squad_manager.isSquadLeader())
      return null

    local bestTeamsData = null
    if (room)
      bestTeamsData = this.getMembersFlyoutEventDataImpl(event, room, teams)
    else {
      let myCountry = profileCountrySq.value
      let allSets = this.getAllCountriesSets(event)
      foreach (countrySet in allSets) {
        let mgmTeams = []
        foreach (idx, countries in countrySet.countries)
          if (isInArray(myCountry, countries))
            mgmTeams.append(idx + 1) //idx to Team enum
        if (!mgmTeams.len())
          continue

        foreach (gameModeId in countrySet.gameModeIds) {
          let mgm = getModeById(gameModeId)
          if (!mgm)
            continue
          let teamsData = this.getMembersFlyoutEventDataImpl(mgm, null, mgmTeams)
          local compareTeamData = !!teamsData <=> !!bestTeamsData
            || !teamsData.haveRestrictions <=> !bestTeamsData.haveRestrictions
            || bestTeamsData.bestCountriesChanged <=> teamsData.bestCountriesChanged
          if (compareTeamData == 0 && teamsData.haveRestrictions)
            compareTeamData = bestTeamsData.cantFlyData.len() <=> teamsData.cantFlyData.len()

          if (compareTeamData > 0) {
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
      bestTeamsData.teamsData = bestTeamsData.teamsData.filter(@(t) t.countriesChanged == bestTeamsData.bestCountriesChanged)

    return bestTeamsData
  }

  function getMembersFlyoutEventDataImpl(roomMgm, room, teams) {
    let res = {
      teamsData = []
      cantFlyData = []
      canFlyout = false
      haveRestrictions = true
      bestCountriesChanged = -1
    }
    foreach (team in teams) {
      let data = this.getMembersFlyoutEventData(roomMgm, room, team)
      data.team <- team

      if (data.canFlyout) {
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

  function getMembersFlyoutEventData(event, room, team) {
    let mGameMode = this.getMGameMode(event, room)
    let teamData = this.getTeamDataWithRoom(mGameMode, team, room)
    let canChangeMemberCountry = !room //can choose members country by queue params
    return ::g_squad_utils.getMembersFlyoutData(teamData, event, canChangeMemberCountry)
  }

  function prepareMembersForQueue(membersData) {
    let membersQuery = {}
    let leaderCountry = profileCountrySq.value
    foreach (m in membersData.members) {
      local country = leaderCountry
      if (m.countries.len() && !isInArray(leaderCountry, m.countries))
        country = m.countries[rnd() % m.countries.len()]  //choose random country atm
      let slot = (country in m.selSlots) ? m.selSlots[country] : 0

      membersQuery[m.uid] <- {
        queueProfileJwt = m?.queueProfileJwt ?? ""
        country = country
        slots = {
          [country] = slot
        }
        dislikedMissions = m?.dislikedMissions ?? []
        bannedMissions = m?.bannedMissions ?? []
        fakeName = m?.fakeName ?? false
      }
    }
    return membersQuery
  }

  function getAlowedCrafts(teamData, roomSpecialRules = null) {
    local res = teamData?.allowedCrafts ?? []
    if (roomSpecialRules) {
      res = clone res
      res.extend(roomSpecialRules)
    }
    return res
  }

  function getForbiddenCrafts(teamData) {
    return teamData?.forbiddenCrafts ?? []
  }

  function getRequiredCrafts(teamData) {
    return teamData?.requiredCrafts ?? []
  }

  function hasUnitRequirements(teamData) {
    return this.getRequiredCrafts(teamData).len() > 0
  }

  function isRespawnAvail(event) {
    if (event == null)
      return true

    if ("maxRespawns" in event.mission_decl &&
        event.mission_decl.maxRespawns != 1)
      return true
    return false
  }

  function getRespawnsText(event) {
    if (!this.isEventRespawnEnabled(event))
      return loc("template/noRespawns")
    let availRespawns = events.getEventMaxRespawns(event)
    if (availRespawns > 1)
      return loc("template/limitedRespawns/num/plural", { num = availRespawns })
    return ""
  }

  /**
   * Returns false if event does not support respawning at all.
   * (Player returns to hangar after death.)
   */
  function isEventRespawnEnabled(event) {
    return event?.respawn ?? false
  }

  /**
   * Returns true if player can select from several during respawn.
   * False means that player has only slot that was selected in hangar.
   */
  function isEventMultiSlotEnabled(event) {
    return event?.multiSlot ?? false
  }

  /**
   * Returns max possible respawn count.
   * Ignored if isEventRespawnEnabled(event) == false.
   */
  function getEventMaxRespawns(event) {
    return event?.mission_decl.maxRespawns ?? 0
  }

  function getEventRewardMuls(eventId) {
    let res = { wp = 1.0, exp = 1.0 }
    if (!this.checkEventId(eventId))
      return res

    if ("reward_mul_wp" in __game_events[eventId])
      res.wp = __game_events[eventId].reward_mul_wp
    if ("reward_mul_exp" in __game_events[eventId])
      res.exp = __game_events[eventId].reward_mul_exp
    return res
  }

  function getEventDifficulty(event) {
    return g_difficulty.getDifficultyByMatchingName(event?.difficulty ?? "arcade")
  }

  function getEventDiffCode(event) {
    return this.getEventDifficulty(event).diffCode
  }

  function getEventDiffName(eventId, baseOnly = false) {
    if (!this.checkEventId(eventId))
      return ""
    local diffName = ""
    if ("difficulty" in __game_events[eventId].mission_decl)
      diffName = __game_events[eventId].mission_decl.difficulty

    if (this.isDifficultyCustom(__game_events[eventId]) && !baseOnly)
      diffName = "custom_" + diffName

    return diffName
  }

  function isDifficultyCustom(_event) {
    return false
  }

  function getCustomDifficultyChanges(eventId) {
    local diffChanges = ""
    if (!this.checkEventId(eventId) || !this.isDifficultyCustom(__game_events[eventId]))
      return ""

    foreach (name, flag in __game_events[eventId].mission_decl.customDifficulty) {
      diffChanges += diffChanges.len() ? "\n" : ""
      diffChanges += format("%s - %s", loc("options/" + name), loc("options/" + (flag ? "enabled" : "disabled")))
    }

    return diffChanges
  }

  function getTeamSize(teamData) {
    return teamData?.maxTeamSize ?? EVENT_DEFAULT_TEAM_SIZE
  }

  function hasTeamSizeHandicap(event) {
    let sides = this.getSidesList(event)
    if (sides.len() < 2)
      return false
    local size = 0
    foreach (idx, team in sides) {
      let teamData = this.getTeamData(event, team)
      let teamSize = this.getTeamSize(teamData)
      if (!idx)
        size = teamSize
      else if (size != teamSize)
        return true
    }
    return false
  }

  function getMaxTeamSize(event) {
    local maxTeamSize = 0
    foreach (team in this.getSidesList(event)) {
      let teamSize = this.getTeamSize(this.getTeamData(event, team))
      maxTeamSize = max(maxTeamSize, teamSize)
    }
    return maxTeamSize
  }

  function getMinTeamSize(event) {
    return (event?.minTeamSize ?? 1) || 1
  }

  function countEventTime(eventTime) {
    return (eventTime - ::get_matching_server_time())
  }

  function getEventStartTime(event) {
    return ("startTime" in event) ? this.countEventTime(event.startTime) : 0
  }

  function getEventEndTime(event) {
    return ("endTime" in event) ? this.countEventTime(event.endTime) : 0
  }

  function getEventUiSortPriority(event) {
    return event?.uiSortPriority ?? 0
  }

  function hasEventEndTime(event) {
    return "endTime" in event
  }

  function getEventAchievementGroup(event) {
    return event?.achievementGroup ?? ""
  }

  function onEventSignOut(_p) {
    __game_events.clear()
    eventsLoaded = false
    chapters.updateChapters()
  }

  function getEventMission(eventId) {
    if (!this.checkEventId(eventId))
      return ""
    let list = __game_events[eventId].mission_decl.missions_list
    if (list.len() == 1)
      if (type(list) == "array" && type(list[0]) == "string")
        return list[0]
      else if (type(list) == "table")
        foreach (key, _value in list)
          if (type(key) == "string")
            return key
    return ""
  }

  function getFeaturedEvent() {
    let diff = getCurrentShopDifficulty()
    foreach (eventName, event in __game_events)
      if (this.getEventDifficulty(eventName) == diff &&
          this.isEventEnabled(event))
        return eventName
    return ""
  }

  function getTextsBlock(economicName) {
    return get_gui_regional_blk()?.eventsTexts?[economicName]
  }

  //!!! function only for compatibility with version without gui_regional
  function getNameLocOldStyle(event, economicName) {
    return event?.loc_name ?? $"events/{economicName}/name"
  }

  function getMaxBrText(event) {
    local maxBR = -1
    foreach (team in this.getSidesList(event)) {
      let teamData = this.getTeamData(event, team)
      if (!teamData || !this.isTeamDataPlayable(teamData))
        continue
      foreach (rule in this.getAlowedCrafts(teamData)) {
        if ("mranks" not in rule)
          continue
        maxBR = max(maxBR,  rule.mranks?.max ?? getMaxEconomicRank())
      }
      if (maxBR == -1)
        maxBR = getMaxEconomicRank()
      foreach (rule in this.getForbiddenCrafts(teamData)) {
        if (rule?.mranks.max == null && rule?.mranks.min == null)
          continue
        if ((rule.mranks?.max ?? getMaxEconomicRank()) == maxBR)
          maxBR = (rule.mranks?.min ?? 1) - 1
      }
    }
    return  loc("mainmenu/maxBR", { br = format("%.1f", calcBattleRatingFromRank(maxBR)) })
  }

  function getEventNameText(event) {
    let economicName = getEventEconomicName(event)
    if (economicName in eventNameText)
      return eventNameText[economicName]
    let addText = isEventForClan(event) ? loc("ui/parentheses/space", { text = this.getMaxBrText(event) }) : ""
    let res = getLocTextFromConfig(this.getTextsBlock(economicName), "name", "")
    if (res.len()) {
      eventNameText[economicName] <- $"{res}{addText}"
      return eventNameText[economicName]
    }
    if (event?.chapter == "competitive") {
      eventNameText[economicName] <- loc($"tournament/{economicName}")
      return eventNameText[economicName]
    }
    eventNameText[economicName] <- $"{loc(this.getNameLocOldStyle(event, economicName), economicName)}{addText}"
    return eventNameText[economicName]
  }

  function getNameByEconomicName(economicName) {
    return this.getEventNameText(events.getEventByEconomicName(economicName))
  }

  function getBaseDescByEconomicName(economicName) {
    let res = getLocTextFromConfig(this.getTextsBlock(economicName), "desc", "")
    if (res.len())
      return res

    let event = events.getEventByEconomicName(economicName)
    return loc(event?.loc_desc ?? $"events/{economicName}/desc", "")
  }


  function isEventRandomBattlesById(eventId) {
    let event = this.getEvent(eventId)
    return event != null && isEventRandomBattles(event)
  }

  function isEventTanksCompatible(eventId) {
    let event = this.getEvent(eventId)
    return event ? this.isUnitTypeAvailable(event, ES_UNIT_TYPE_TANK) : false
  }

  function getMainLbRequest(event) {
    return _leaderboards.getMainLbRequest(event)
  }

  /**
   * Function requests leaderboards asynchronously and puts result
   * as argument to callback function
   */
  function requestLeaderboard(requestData, id, callback = null, context = null) {
    _leaderboards.requestLeaderboard(requestData, id, callback, context)
  }

  /**
   * Function requests self leaderboard row asynchronously and puts result
   * as argument to callback function
   */
  function requestSelfRow(requestData, id, callback = null, context = null) {
    _leaderboards.requestSelfRow(requestData, id, callback, context)
  }

  function lbBlkToArray(blk) {
    return _leaderboards.lbBlkToArray(blk)
  }

  function isClanLbRequest(requestData) {
    return _leaderboards.isClanLbRequest(requestData)
  }

  function validateRequestData(requestData) {
    return _leaderboards.validateRequestData(requestData)
  }

  function compareRequests(req1, req2) {
    return _leaderboards.compareRequests(req1, req2)
  }

  function checkLbRowVisibility(row, params = {}) {
    if (!::leaderboardModel.checkLbRowVisibility(row, params))
      return false

    local event = events.getEvent(params?.eventId)
    return row.isVisibleInEvent(event)
  }

  function fillAirsList(handler, teamObj, teamData, allowedUnitTypes, roomSpecialRules = null) {
    let allowedAirsObj = teamObj.findObject("allowed_crafts")
    let haveAllowedRules = this.generateRulesText(handler, this.getAlowedCrafts(teamData, roomSpecialRules), allowedAirsObj, true)
    allowedAirsObj.show(haveAllowedRules)

    let forbiddenAirsObj = teamObj.findObject("forbidden_crafts")
    let haveForbiddenRules = this.generateRulesText(handler, this.getForbiddenCrafts(teamData), forbiddenAirsObj)
    forbiddenAirsObj.show(haveForbiddenRules)

    let requiredAirsObj = teamObj.findObject("required_crafts")
    let haveRequiredRules = this.generateRulesText(handler, this.getRequiredCrafts(teamData), requiredAirsObj, true, true)
    requiredAirsObj.show(haveRequiredRules)

    if ((allowedUnitTypes & (1 << ES_UNIT_TYPE_BOAT)) != 0)
      allowedUnitTypes = allowedUnitTypes & ~(1 << ES_UNIT_TYPE_BOAT)
    let needTypeText = (!haveAllowedRules && !haveForbiddenRules && !haveRequiredRules) || allowedUnitTypes != allUnitTypesMask
    let allowedUnitTypesObj = teamObj.findObject("allowed_unit_types")
    allowedUnitTypesObj.show(needTypeText)
    if (!needTypeText)
      return

    local allowId = "all_units_allowed"
    local allowText = ""
    if (stdMath.number_of_set_bits(allowedUnitTypes) == 1)
      allowId = "allowed_only/" + ::getUnitTypeText(stdMath.number_of_set_bits(allowedUnitTypes - 1))
    if (stdMath.number_of_set_bits(allowedUnitTypes) == 2) {
      let masksArray = unitTypes.getArrayBybitMask(allowedUnitTypes)
      if (masksArray && masksArray.len() == 2) {
        let allowUnitId = "events/allowed_units"
        allowText = loc(allowUnitId, {
          unitType = loc(allowUnitId + "/" + masksArray[0].name),
          unitType2 = loc(allowUnitId + "/" + masksArray[1].name) })
        allowText = toUpper(allowText, 1)
      }
    }
    allowText = allowText == "" ? loc("events/" + allowId) : allowText
    allowedUnitTypesObj.findObject("allowed_unit_types_text").setValue(allowText)
  }

  function generateRulesText(handler, rules, rulesObj, _highlightRules = false, checkAllRules = false) {
    // Using special container 'tdiv' for proper 'rulesObj' reuse.
    local craftsListObj = rulesObj.findObject("crafts_list")
    if (!checkObj(craftsListObj)) {
      craftsListObj = handler.guiScene.createElement(rulesObj, "tdiv", handler)
      craftsListObj["id"] = "crafts_list"
      craftsListObj["flow"] = "vertical"
    }
    handler.guiScene.replaceContentFromText(craftsListObj, "", 0, handler)

    local haveRules = false
    let blk = "%gui/events/airRuleItem.blk"
    foreach (rule in rules) {
      if (!checkAllRules && ("class" in rule) && rule.len() == 1)
        continue

      haveRules = true
      let ruleObj = handler.guiScene.createElementByObject(craftsListObj, blk, "tdiv", handler)
      let ruleTextObj = ruleObj.findObject("rule_text")
      let ruleString = this.generateEventRule(rule, false, ruleObj)
      ruleTextObj.setValue(ruleString)
    }
    return haveRules
  }

  function generateEventRule(rule, onlyText = false, ruleObj = null) {
    local ruleString = ""
    if ("name" in rule) {
      let air = getAircraftByName(rule.name)
      if (!air) {
        log($"rule for unit {rule.name}:")
        debugTableData(rule)
        debug_dump_stack()
        logerr("Wrong unit name in event rule")
      }
      if (onlyText || !air)
        ruleString = getUnitName(air, true)

      if (air && checkObj(ruleObj)) {
        let airNameObj = ruleObj.findObject("air_name")
        airNameObj.setValue(loc(rule.name + "_shop"))

        if (::isUnitUsable(air))
          airNameObj.airBought = "yes"
        else if (air && canBuyUnit(air))
          airNameObj.airCanBuy = "yes"
        else {
          let reason = ::getCantBuyUnitReason(air, true)
          airNameObj.airCanBuy = reason == "" ? "yes" : "no"
        }

        let airIconObj = ruleObj.findObject("air_icon")
        airIconObj["background-image"] = ::getUnitClassIco(rule.name)
        airIconObj.shopItemType = getUnitRole(rule.name)

        ruleObj.findObject("tooltip_obj").tooltipId = getTooltipType("UNIT").getTooltipId(air.name, { needShopInfo = true })
      }
    }
    else if ("type" in rule)
      ruleString += loc($"mainmenu/type_{rule.type}")
    else if ("class" in rule) {
      local ruleClass = rule["class"]
      if (ruleClass == "ship")
        ruleClass = "ship_and_boat"
      ruleString += loc($"mainmenu/type_{ruleClass}")
    }
    if ("ranks" in rule) {
      let minRank = max(1, rule.ranks?.min ?? 1)
      let maxRank = rule.ranks?.max ?? ::max_country_rank
      local rankText = get_roman_numeral(minRank)
                     + ((minRank != maxRank) ? " - " + get_roman_numeral(maxRank) : "")
      rankText = format(loc("events/rank"), rankText)
      if (ruleString.len())
        ruleString += loc("ui/parentheses/space", { text = rankText })
      else
        ruleString = rankText
    }

    if ("mranks" in rule) {
      let mranks = rule.mranks
      let minBR = format("%.1f", calcBattleRatingFromRank(mranks?.min ?? 0))
      let maxBR = format("%.1f", calcBattleRatingFromRank(mranks?.max ?? getMaxEconomicRank()))
      local brText = minBR + ((minBR != maxBR) ? " - " + maxBR : "")
      brText = format(loc("events/br"), brText)
      if (ruleString.len())
        ruleString += loc("ui/parentheses/space", { text = brText })
      else
        ruleString = brText
    }
    return ruleString
  }

  function getRulesText(rules, separator = "\n") {
    let textsList = rules.map(function(rule) { return this.generateEventRule(rule, true) }.bindenv(this))
    return separator.join(textsList, true)
  }

  function getSpecialRequirementsText(event, separator = "\n") {
    let requirements = this.getSpecialRequirements(event)
    return requirements ? this.getRulesText(requirements, separator) : ""
  }

  function getPlayersRangeTextData(event) {
    let minSize = this.getMinTeamSize(event)
    let maxSize = this.getMaxTeamSize(event)
    let isEqual = minSize == maxSize
    let res = {
      label = isEqual ? loc("events/players_range_single") : loc("events/players_short")
      value = minSize + (isEqual ? "" : " - " + maxSize)
      isValid = minSize > 0 && maxSize > 0
    }
    return res
  }

  function checkCurrentCraft(event, room = null) {
    let unit = getCurSlotbarUnit()
    if (!unit)
      return false

    let ediff = this.getEDiffByEvent(event)
    if (room) {
      let roomSpecialRules = room && ::SessionLobby.getRoomSpecialRules(room)
      if (roomSpecialRules && !this.isUnitMatchesRule(unit, roomSpecialRules, true, ediff))
        return false
    }

    let mGameMode = events.getMGameMode(event, room)
    foreach (team in this.getSidesList(mGameMode)) {
      let teamData = this.getTeamDataWithRoom(mGameMode, team, room)
      if (teamData && this.isUnitAllowedByTeamData(teamData, unit.name, ediff))
        return true
    }
    return false
  }

  function isAllowedByRoomBalance(mGameMode, room) {
    if (!room)
      return true
    let maxDisbalance = getMaxLobbyDisbalance(mGameMode)
    if (maxDisbalance >= ::global_max_players_versus)
      return true
    let teams = this.getSidesList(mGameMode)
    let availTeams = this.getAvailableTeams(mGameMode, room)
    if (availTeams.len() != 1 || availTeams.len() == teams.len())
      return true

    let membersCount = g_squad_manager.getOnlineMembersCount()
    let myTeam = availTeams[0]
    let otherTeam = u.search(teams, function(t) { return t != myTeam })
    let countTbl = ::SessionLobby.getMembersCountByTeams(room)
    return (countTbl?[myTeam] ?? 0) + membersCount <= (countTbl?[otherTeam] ?? 0) + maxDisbalance
  }

  function hasPlaceInMyTeam(mGameMode, room) {
    if (!room)
      return true
    let availTeams = this.getAvailableTeams(mGameMode, room)
    if (availTeams.len() != 1)
      return true

    let membersCount = g_squad_manager.getOnlineMembersCount()
    let countTbl = ::SessionLobby.getMembersCountByTeams(room)
    return countTbl[availTeams[0]] + membersCount <= this.getMaxTeamSize(mGameMode)
  }

  function getCantJoinReasonData(event, room = null, params = null) {
    let data = {
      activeJoinButton = false
      reasonText = null
      msgboxReasonText = null
      checkStatus = false
      actionFunc = null
      event = event // Used to backtrack event in actionFunc.
      room = room
      checkXboxOverlayMessage = false
    }.__update(params ?? {})

    let { isFullText = false, isCreationCheck = false } = params
    let mGameMode = events.getMGameMode(event, room)
    if (event == null)
      data.reasonText = loc("events/no_selected_event")
    else if (!this.checkEventFeature(event, true)) {
      let purchData = getFeaturePurchaseData(getEventReqFeature(event))
      data.activeJoinButton = purchData.canBePurchased
      data.reasonText = this.getEventFeatureReasonText(event)
    }
    else if (!this.isEventAllowedByComaptibilityMode(event))
      data.reasonText = loc("events/noCompatibilityMode")
    else if (!isCreationCheck && !this.isEventEnabled(event)) {
      local startTime = events.getEventStartTime(event)
      if (startTime > 0)
        data.reasonText = loc("events/event_not_started_yet")
      else if (events.getEventEndTime(event) > 0)
        data.reasonText = loc("events/event_will_begin_soon")
      else
        data.reasonText = loc("events/event_disabled")
      data.actionFunc = function (reasonData) {
        local messageText = reasonData.reasonText
        startTime = events.getEventStartTime(reasonData.event)
        if (startTime > 0)
          messageText +=  "\n" + format(loc("events/event_starts_in"), colorize("activeTextColor",
            time.hoursToString(time.secondsToHours(startTime))))
        scene_msg_box("cant_join", null, messageText,
            [["ok", function() {}]], "ok")
      }
    }
    else if (!isMultiplayerPrivilegeAvailable.value) {
      data.reasonText = loc("xbox/noMultiplayer")
      data.msgboxReasonText = loc("xbox/noMultiplayer")
      data.checkXboxOverlayMessage = true
    }
    else if (!this.isEventPlatformOnlyAllowed(mGameMode) && !crossplayModule.isCrossPlayEnabled()) {
      data.reasonText = loc("xbox/crossPlayRequired")
      data.msgboxReasonText = loc("xbox/actionNotAvailableCrossNetworkPlay")
      data.checkXboxOverlayMessage = true
    }
    else if (!this.checkSpecialRequirements(event)) {
      if (isFullText)
        data.reasonText = loc("events/specialRequirements") + loc("ui/colon") + "\n"
                        + this.getSpecialRequirementsText(event)
      else
        data.reasonText = loc("events/no_specialRequirements")
    }
    else if (!this.getAvailableTeams(mGameMode, room).len())
      data.reasonText = loc("events/no_selected_country")
    else if (!this.checkPlayersCrafts(mGameMode, room))
      data.reasonText = loc("events/no_allowed_crafts")
    else if (isEventForClan(event) && !::my_clan_info)
      data.reasonText = loc("events/clan_only")
    else if (!isCreationCheck && this.isEventEnded(event))
      data.reasonText = loc("events/event_disabled")
    else if (!this.checkRequiredUnits(mGameMode, room))
      data.reasonText = loc("events/no_required_crafts") + loc("ui/dot")
    else if (!this.isEventMultiSlotEnabled(event) && !this.checkCurrentCraft(mGameMode, room))
      data.reasonText = loc("events/selected_craft_is_not_allowed")
    else if (!this.checkClan(event))
      data.reasonText = loc("events/wrong_clan_for_this_tornament")
    else if (this.eventRequiresTicket(event) && this.getEventActiveTicket(event) == null) {
      data.activeJoinButton = true
      data.reasonText = loc("ticketBuyWindow/mainText")
      data.actionFunc = @(_reasonData) events.checkAndBuyTicket(event)
    }
    else if (this.getEventActiveTicket(event) != null && !this.getEventActiveTicket(event).getTicketTournamentData(getEventEconomicName(event)).canJoinTournament) {
      data.reasonText = loc("events/wait_for_sessions_to_finish/main")
      data.actionFunc = function (reasonData) {
        ::g_event_ticket_buy_offer.offerTicket(reasonData.event)
      }
    }
    else if (g_squad_manager.getOnlineMembersCount() < this.getMinSquadSize(event))
      data.reasonText = loc("events/minSquadSize", { minSize = this.getMinSquadSize(event) })
    else if (g_squad_manager.getOnlineMembersCount() > this.getMaxSquadSize(event))
      data.reasonText = loc("events/maxSquadSize", { maxSize = this.getMaxSquadSize(event) })
    else if (!this.hasPlaceInMyTeam(mGameMode, room)) {
      let myTeam = this.getAvailableTeams(mGameMode, room)[0]
      data.reasonText = loc("multiplayer/chosenTeamIsFull",
        {
          chosenTeam = colorize("teamBlueColor", g_team.getTeamByCode(myTeam).getShortName())
        })
    }
    else if (!this.isAllowedByRoomBalance(mGameMode, room)) {
      let teamsCnt = ::SessionLobby.getMembersCountByTeams(room)
      let myTeam = this.getAvailableTeams(mGameMode, room)[0]
      let otherTeam = u.search(this.getSidesList(mGameMode), @(t) t != myTeam)
      let membersCount = g_squad_manager.getOnlineMembersCount()
      let locParams = {
        chosenTeam = colorize("teamBlueColor", g_team.getTeamByCode(myTeam).getShortName())
        otherTeam =  colorize("teamRedColor", g_team.getTeamByCode(otherTeam).getShortName())
        chosenTeamCount = teamsCnt[myTeam]
        otherTeamCount =  teamsCnt[otherTeam]
        reqOtherteamCount = teamsCnt[myTeam] - getMaxLobbyDisbalance(mGameMode) + membersCount
      }
      let locKey = "multiplayer/enemyTeamTooLowMembers" + (isFullText ? "" : "/short")
      data.reasonText = loc(locKey, locParams)
    }
    else if (!this.haveEventAccessByCost(event)) {
      data.reasonText = loc("events/notEnoughMoney")
    }
    else {
      data.reasonText = ""
      data.checkStatus = true
      data.activeJoinButton = true
    }

    if (data.actionFunc == null && !data.checkStatus) {
      data.actionFunc = function(reasonData) {
        if (!reasonData.checkXboxOverlayMessage)
          showInfoMsgBox(reasonData.msgboxReasonText || reasonData.reasonText, "cant_join")
        else if (!isMultiplayerPrivilegeAvailable.value)
          checkAndShowMultiplayerPrivilegeWarning()
        else if (!isShowGoldBalanceWarning())
          checkAndShowCrossplayWarning(
            @() showInfoMsgBox(reasonData.msgboxReasonText || reasonData.reasonText, "cant_join"))
      }
    }

    return data
  }

  function getEventStartTimeText(event) {
    if (events.isEventEnabled(event)) {
      let startTime = events.getEventStartTime(event)
      if (startTime > 0)
        return format(loc("events/event_started_at"), colorize("activeTextColor", time.hoursToString(time.secondsToHours(startTime))))
    }
    return ""
  }

  function getEventTimeText(event) {
    let endTime = events.getEventEndTime(event)
    if (events.isEventEnabled(event)) {
      if (endTime > 0)
        return format(loc("events/event_ends_in"), colorize("activeTextColor", time.hoursToString(time.secondsToHours(endTime))))
      else
        return ""
    }
    let startTime = events.getEventStartTime(event)
    if (startTime > 0)
      return format(loc("events/event_starts_in"), colorize("activeTextColor", time.hoursToString(time.secondsToHours(startTime))))
    if (endTime > 0)
      return loc("events/event_will_begin_soon")
    return loc("events/event_disabled")
  }

  //
  // Sort/compare functions.
  //

  function sortEventsByDiff(a, b) {
    let diffA = (type(a) == "string" ? __game_events[a] : a).diffWeight
    let diffB = (type(b) == "string" ? __game_events[b] : b).diffWeight
    if (diffA > diffB)
      return 1
    else if (diffA < diffB)
      return -1
    return 0
  }

  function gameModeCompare(gm1, gm2) {
    local cmp = this.forClanCompare(gm1.forClan, gm2.forClan)
    if (cmp != 0)
      return cmp
    cmp = this.displayTypeCompare(gm1.displayType, gm2.displayType)
    if (cmp != 0)
      return cmp
    cmp = this.diffCodeCompare(gm1.diffCode, gm2.diffCode)
    if (cmp != 0)
      return cmp
    return this.unitTypesCompare(gm1.unitTypes, gm2.unitTypes)
  }

  function displayTypeCompare(dt1, dt2) {
    if (dt1 == dt2)
      return 0
    return dt1.showInEventsWindow ? 1 : -1
  }

  function diffCodeCompare(d1, d2) {
    if (d1 > d2)
      return 1
    if (d1 < d2)
      return -1
    return 0
  }

  function unitTypesCompare(uts1, uts2) {
    if (uts1.len() == 1 && uts2.len() == 1) {
      if (uts1[0] > uts2[0])
        return 1
      if (uts1[0] < uts2[0])
        return -1
    }
    if (uts1.len() == uts2.len())
      return 0
    return uts1.len() > uts2.len() ? 1 : -1
  }

  function forClanCompare(fc1, fc2) {
    if (fc1 == fc2)
      return 0
    return fc1 ? 1 : -1
  }

  /** Returns tickets available for purchase. */
  function getEventTickets(event, canBuyOnly = false) {
    let eventId = getEventEconomicName(event)
    let tickets = ::ItemsManager.getItemsList(itemType.TICKET,
      @(item) item.isForEvent(eventId) && (!canBuyOnly || item.isCanBuy()))
    return tickets
  }

  /** Returns null if no such ticket found. */
  function getEventActiveTicket(event) {
    let eventId = event.economicName
    if (!have_you_valid_tournament_ticket(eventId))
      return null
    let tickets = ::ItemsManager.getInventoryList(itemType.TICKET,
      @(item) item.isForEvent(eventId) && item.isActive())
    return tickets.len() > 0 ? tickets[0] : null
  }

  function getEventActiveTicketText(event, valueColor = "activeTextColor") {
    let ticket = this.getEventActiveTicket(event)
    if (!ticket)
      return ""

    return "\n".join([
        ticket.getCost() > ::zero_money
          ? loc("events/ticket_cost", {
            cost = colorize(valueColor, ticket.getCost(true).getTextAccordingToBalance()) })
          : "",
        ticket.getAvailableDefeatsText(getEventEconomicName(event))
      ], true)
  }

  /**
   * @param useShortText Setting to true will
   * return only price with no text label.
   */
  function getEventBattleCostText(event, valueColor = "activeTextColor", useShortText = false, colored = true) {
    let cost = this.getEventBattleCost(event)
    if (cost <= ::zero_money)
      return ""
    let shortText = colored
      ? cost.getTextAccordingToBalance()
      : cost.getUncoloredText()
    if (useShortText)
      return shortText
    return loc("events/battle_cost", { cost = colorize(valueColor, shortText) })
  }

  function getEventBattleCost(event) {
    if (event == null)
      return Cost()
    return Cost().setFromTbl(get_tournament_battle_cost(event.economicName))
  }

  function haveEventAccessByCost(event) {
    return get_gui_balance() >= this.getEventBattleCost(event)
  }

  function hasEventTicket(event) {
    return this.getEventActiveTicket(event) != null
  }

  function eventRequiresTicket(event) {
    // Event has at least one ticket available in shop.
    return this.getEventTickets(event).len() != 0
  }

  function checkAndBuyTicket(event) {
    if (!this.eventRequiresTicket(event))
      return
    let ticket = this.getEventActiveTicket(event)
    if (ticket != null)
      return
    let purchasableTickets = this.getEventTickets(event, true)
    if (purchasableTickets.len() == 0) {
      let locParams = {
        eventName = this.getEventNameText(event)
      }
      let message = loc("msgbox/need_ticket/no_tickets", locParams)
      showInfoMsgBox(message, "no_tickets")
      return
    }
    // Player has to purchase one of available tickets via special window.
    loadHandler(gui_handlers.TicketBuyWindow, { event, tickets = purchasableTickets })
  }

  /**
   * Some clan tournaments dont allow to take a part for differnt clan.
   * This function returns true if current clan (if exists) is the same as clan
   * you first time took part in this tournamnet you was in.
   */
  function checkClan(event) {
    let clanTournament = getBlkValueByPath(get_tournaments_blk(), event.name + "/clanTournament", false)
    if (!clanTournament)
      return true
    if (!::is_in_clan())
      return false
    if (getBlkValueByPath(get_tournaments_blk(), event.name + "/allowToSwitchClan"))
      return true
    let tournamentBlk = getTournamentInfoBlk(getEventEconomicName(event))
    return tournamentBlk?.clanId ? clan_get_my_clan_id() == tournamentBlk.clanId.tostring() : true
  }

  function checkMembersForQueue(event, room = null, continueQueueFunc = null, cancelFunc = null) {
    if (!g_squad_manager.isInSquad())
      return continueQueueFunc && continueQueueFunc(null)

    let teams = this.getAvailableTeams(event, room)
    let membersTeams = this.getMembersTeamsData(event, room, teams)
    if (!membersTeams) //we are become squad member or gamemod data is missing
      return cancelFunc && cancelFunc()

    let membersInfo = this.getMembersInfo(membersTeams.teamsData)
    if (membersTeams.haveRestrictions) {
      let func = @() continueQueueFunc && continueQueueFunc(membersInfo)
      this.showCantFlyMembersMsgBox(membersTeams, func, cancelFunc)
      return
    }

    if (continueQueueFunc)
      continueQueueFunc(membersInfo)
  }

  function getMembersInfo(membersTeams) {
    if (membersTeams.len() == 0)
      return null

    let notRestrictionsTeamsData = membersTeams.filter(@(v) !v.haveRestrictions)
    let membersData = notRestrictionsTeamsData.len() > 0
      ? notRestrictionsTeamsData[rnd() % notRestrictionsTeamsData.len()]
      : membersTeams[rnd() % membersTeams.len()]
    let membersQuery = this.prepareMembersForQueue(membersData)
    return membersQuery
  }

  function getEventsChapter(event) {
    if (events.isEventEnableOnDebug(event))
      return "test_events"
    local chapterName = event?.chapter ?? "basic_events"
    if (events.isEventEnded(event) && isInArray(chapterName, standardChapterNames))
      chapterName += "/ended"
    return chapterName
  }

  function getChapters() {
    return chapters.getChapters()
  }

  function checkEventDisableSquads(handler, eventId) {
    if (!g_squad_manager.isNotAloneOnline())
      return false
    let event = events.getEvent(eventId)
    if (event == null)
      return false
    let { disableSquads = false } = event
    if (disableSquads) {
      handler.msgBox("squads_disabled", loc("events/squads_disabled"),
        [
          ["ok", function() {}]
        ], "ok")
      return true
    }
    return false
  }

  function getEventIsVisible(event) {
    if (this.isEventEnabled(event))
      return true
    return event?.visible ?? true
  }

  isEventVisibleInEventsWindow = @(event) event?.chapter != "competitive"
    && getEventDisplayType(event).showInEventsWindow
    && (this.checkEnableOnDebug(event) || this.getEventIsVisible(event))
  /**
   * @param teamDataByTeamName This can be event or session info.
   */
  function isEventAllUnitAllowed(teamDataByTeamName) {
    foreach (team in events.getSidesList()) {
      let teamName = this.getTeamName(team)
      let teamData = teamDataByTeamName?[teamName]
      if (!teamData || !this.isTeamDataPlayable(teamData))
        continue
      let types = this.getUnitTypesByTeamDataAndName(teamData, teamName)
      if (stdMath.number_of_set_bits(types) < ES_UNIT_TYPE_TOTAL_RELEASED)
        return false
      if (this.getAlowedCrafts(teamData).len() > 0)
        return false
      if (this.getForbiddenCrafts(teamData).len() > 0)
        return false
      if (this.getRequiredCrafts(teamData).len() > 0)
        return false
    }
    return true
  }

  function descFormat(name, value) {
    if (u.isEmpty(value))
      return ""
    return "".concat(name, loc("ui/colon"), colorize("@activeTextColor", value))
  }

  function getEventRewardText(event) {
    let muls = events.getEventRewardMuls(event.name)
    let wpText = this.buildBonusText((100.0 * (muls.wp  - 1.0) + 0.5).tointeger(), "% " + loc("warpoints/short/colored"))
    let expText = this.buildBonusText((100.0 * (muls.exp - 1.0) + 0.5).tointeger(), "% " + loc("currency/researchPoints/sign/colored"))
    return wpText + ((wpText.len() && expText.len()) ? ", " : "") + expText
  }

  function buildBonusText(value, endingText) {
    if (!value || value <= 0)
      return ""
    return "+" + value + endingText
  }

  function getEventDescriptionText(event, mroom = null, hasEventFeatureReasonText = false) {
    let textsList = []

    textsList.append(this.getCustomRulesDesc(event))
    textsList.append(this.getBaseDescByEconomicName(getEventEconomicName(event)))
    textsList.append(this.descFormat(loc("reward"), this.getEventRewardText(event)))
    textsList.append(this.descFormat(loc("events/specialRequirements"), this.getSpecialRequirementsText(event, ", ")))
    textsList.append(this.getUnlockProgress(event))
    textsList.append(this.getTimeAwardingEconomicsDesc(event))

    if (mroom)
      textsList.append(this.descFormat(loc("options/cluster"),
        getClusterShortName(::SessionLobby.getClusterName(mroom))))

    let isTesting = ("event_access" in event) ? isInArray("AccessTest", event.event_access) : false
    if (isTesting)
      textsList.append(colorize("@yellow", loc("events/event_is_testing")))

    if (hasEventFeatureReasonText && !this.checkEventFeature(event, true))
      textsList.append(this.getEventFeatureReasonText(event))

    return "\n".join(textsList, true)
  }

  function isEventAllowSwitchClan(event) {
    return event?.allowSwitchClan ?? false
  }

  function getDifficultyImg(eventId) {
    let diffName = this.getEventDiffName(eventId)
    return this.getDifficultyIcon(diffName)
  }

  function getDifficultyIcon(diffName) {
    let difficulty = g_difficulty.getDifficultyByName(diffName)
    if (!u.isEmpty(difficulty.icon))
      return difficulty.icon

    if (diffName.len() > 6 && diffName.slice(0, 6) == "custom")
      return $"#ui/gameuiskin#mission_{diffName}"

    return ""
  }

  function getDifficultyTooltip(eventId) {
    local custChanges = this.getCustomDifficultyChanges(eventId)
    custChanges = (custChanges.len() ? "\n" : "") + custChanges
    return events.descFormat(loc("multiplayer/difficulty"), this.getDifficultyText(eventId)) + custChanges
  }

  function getDifficultyText(eventId) {
    let difficulty = this.getEventDiffName(eventId)
    if (difficulty.len())
      return loc($"options/{difficulty}")
    return ""
  }

  function getCustomRules(event) {
    return event.mission_decl?.customRules
  }

  function getCustomRulesSetName(event) {
    let customRules = this.getCustomRules(event)
    return customRules?.guiName ?? customRules?.name
  }

  function getCustomRulesDesc(event) {
    let rulesName = this.getCustomRulesSetName(event)
    if (u.isEmpty(rulesName))
      return ""

    let rulesClass = findRulesClassByName(rulesName)
    return rulesClass().getEventDescByRulesTbl(this.getCustomRules(event))
  }

  function getUnlockProgress(event) {
    if (event.mission_decl?.gt_use_unlocks ?? true)
      return ""
    return loc("events/no_unlock_progress")
  }

  function getTimeAwardingEconomicsDesc(event) {
    return event.mission_decl?.useTimeAwardingEconomics ? loc("events/has_time_awarding_economics") : ""
  }

  function isEventForClanGlobalLb(event) {
    let tournamentMode = getEventTournamentMode(event)
    let forClans = _leaderboards.isClanLeaderboard(event)

    return tournamentMode == GAME_EVENT_TYPE.TM_NONE && forClans
  }

  function checkEventFeature(event, isSilent = false) {
    let feature = getEventReqFeature(event)
    if (u.isEmpty(feature) || hasFeature(feature))
      return true

    if (isSilent)
      return false

    let purchData = getFeaturePurchaseData(feature)
    if (!purchData.canBePurchased)
      return showInfoMsgBox(loc("msgbox/notAvailbleYet"))

    let entitlementItem = getEntitlementConfig(purchData.sourceEntitlement)
    let msg = loc("msg/eventAccess/needEntitlements",
                      {
                        event = colorize("activeTextColor", this.getEventNameText(event))
                        entitlement = colorize("userlogColoredText", getEntitlementName(entitlementItem))
                      })
    gui_handlers.ReqPurchaseWnd.open({
      purchaseData = purchData
      checkPackage = getFeaturePack(feature)
      header = this.getEventNameText(event)
      text = msg
      btnStoreText = loc("msgbox/btn_onlineShop_unlockEvent")
    })
    return false
  }

  function onEventEntitlementsPriceUpdated(_p) {
    this.recalcAllEventsDisplayType()
  }

  function onEventPS4OnlyLeaderboardsValueChanged(_p) {
    _leaderboards.resetLbCache()
  }

  // game mode allows to join either from queue or from rooms list
  function isLobbyGameMode(mGameMode) {
    return mGameMode?.withLobby ?? false
  }

  // it is lobby game mode but with sessions that can be created by players
  function isCustomGameMode(mGameMode) {
    return mGameMode?.forCustomLobby ?? false
  }

  function getCustomGameMode(event) {
    return u.search(
      getGameModesByEconomicName(getEventEconomicName(event)),
      this.isCustomGameMode
    )
  }

  function canCreateCustomRoom(event) {
    return hasFeature("CreateEventRoom") && !!this.getCustomGameMode(event)
  }

  function openCreateRoomWnd(event) {
    let customMgm = this.getCustomGameMode(event)
    if (!customMgm)
      return

    loadHandler(gui_handlers.CreateEventRoomWnd,
      { mGameMode = customMgm })
  }

  function getMaxSquadSize(event) {
    return event?.maxSquadSize ?? 4
  }

  function getMinSquadSize(event) {
    return event?.minSquadSize ?? 1
  }

  function isGameTypeOfEvent(event, gameTypeName) {
    return !!event && !!get_meta_mission_info_by_name(this.getEventMission(event.name))?[gameTypeName]
  }

  function onEventEventBattleEnded(params) {
    let event = events.getEvent(params?.eventId)
    if (!event)
      return

    _leaderboards.dropLbCache(event)
  }

  function getEventFeatureReasonText(event) {
    let purchData = getFeaturePurchaseData(getEventReqFeature(event))
    local reasonText = ""
    if (!purchData.canBePurchased)
      reasonText = loc("msgbox/notAvailbleYet")
    else {
      let entitlementItem = getEntitlementConfig(purchData.sourceEntitlement)
      reasonText = loc("events/no_entitlement",
        { entitlement = colorize("userlogColoredText", getEntitlementName(entitlementItem)) })
    }

    return reasonText
  }

  isEventsLoaded = @() eventsLoaded
  getChapter = @(chapterId) chapters.getChapter(chapterId)
}

events = Events()

seenEvents.setListGetter(@() events.getVisibleEventsList())

seenEvents.setSubListGetter(SEEN.S_EVENTS_WINDOW,
  @() events.getEventsForEventsWindow())

seenEvents.setCompatibilityLoadData(function() {
    let res = {}
    let savePath = "seen/events"
    let blk = loadLocalByAccount(savePath)
    if (!u.isDataBlock(blk))
      return res

    for (local i = 0; i < blk.paramCount(); i++)
      res[blk.getParamName(i)] <- blk.getParamValue(i)
    saveLocalByAccount(savePath, null)
    return res
  })

addListenersWithoutEnv({
  GameLocalizationChanged = @(_) eventNameText.clear()
}, CONFIG_VALIDATION)

::events <- freeze(events)