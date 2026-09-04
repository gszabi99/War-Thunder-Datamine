import "%sqStdLibs/helpers/u.nut" as u
import "%sqstd/math.nut" as stdMath
import "DataBlock" as DataBlock
from "%sqStdLibs/helpers/subscriptions.nut" import add_event_listener, removeEventListenersByEnv, subscribe_handler, broadcastEvent, addListenersWithoutEnv
from "%appGlobals/ranks_common_shared.nut" import getMaxEconomicRank, calcBattleRatingFromRank, get_mission_mode, isUnitSpecial
from "string" import format, split_by_chars
from "%sqstd/datablock.nut" import getBlkValueByPath
from "%sqstd/string.nut" import capitalize
from "dagor.debug" import debug_dump_stack
from "dagor.time" import get_time_msec
from "%scripts/dagui_natives.nut" import clan_get_my_clan_id, get_tournament_battle_cost, has_entitlement, get_tournaments_blk, get_tournament_info_blk
from "%globalScripts/unitTypeConsts.nut" import *
from "%globalScripts/gameModeNativeConsts.nut" import *
from "%scripts/dagui_library.nut" import *
from "%scripts/events/eventsConsts.nut" import EVENTS_SHORT_LB_VISIBLE_ROWS, EVENT_TYPE, GAME_EVENT_TYPE
from "%scripts/seen/seenIds.nut" import SEEN
from "%scripts/utils/systemMsg.nut" import COLOR_TAG
from "%scripts/gameModes/gameModeConsts.nut" import MAX_PLAYERS_VERSUS
from "%scripts/clans/clanState.nut" import is_in_clan, myClanInfo
from "types" import Function, Table, String

let { getUnitName, getUnitTypeText } = require("%scripts/unit/unitInfo.nut")
let { sendLocalizedMessageToSquadRoom } = require("%scripts/chat/squadChatRoom.nut")
let { g_team } = require("%scripts/teams.nut")
let { getCurrentShopDifficulty } = require("%scripts/gameModes/gameModeManagerState.nut")
let { g_difficulty } = require("%scripts/difficulty.nut")
let { getOnlineMembersCount, getSquadRoomName, isInSquad, isNotAloneOnline } = require("%scripts/squads/squadState.nut")
let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { get_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { ReqPurchaseWnd } = require("%scripts/onlineShop/reqPurchaseWnd.nut")
let { TicketBuyWindow } = require("%scripts/items/ticketBuyWindow.nut")
let { zero_money, Cost } = require("%scripts/money.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let time = require("%scripts/time.nut")
let systemMsg = require("%scripts/utils/systemMsg.nut")
let seenEvents = require("%scripts/seen/seenList.nut").get(SEEN.EVENTS)
let crossplayModule = require("%scripts/social/crossplay.nut")
let { isPlatformSony, isPlatformPC } = require("%scripts/clientState/platform.nut")
let { getCantBuyUnitReason, getUnitClassIco } = require("%scripts/unit/unitInfoTexts.nut")
let { getUnitRole } = require("%scripts/unit/unitInfoRoles.nut")
let { getFeaturePack } = require("%scripts/user/features.nut")
let { getEntitlementConfig, getEntitlementName } = require("%scripts/onlineShop/entitlements.nut")
let { getFeaturePurchaseData } = require("%scripts/onlineShop/onlineShopState.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { useTouchscreen } = require("%scripts/clientState/touchScreen.nut")
let { checkAndShowMultiplayerPrivilegeWarning, checkAndShowCrossplayWarning, isMultiplayerPrivilegeAvailable } = require("%scripts/user/xboxFeatures.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { isShowGoldBalanceWarning } = require("%scripts/user/balanceFeatures.nut")
let { getGameModesByEconomicName, getAllCountriesSets } = require("%scripts/matching/matchingGameModes.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let { loadLocalByAccount, saveLocalByAccount } = require("%scripts/clientState/localProfileDeprecated.nut")
let { isUnitBroken, isUnitUsable, isUnitsEraUnlocked } = require("%scripts/unit/unitStatus.nut")
let { canBuyUnit, isUnitGift } = require("%scripts/unit/unitShopInfo.nut")
let { getClusterShortName } = require("%scripts/onlineInfo/clustersManagement.nut")
let { get_gui_balance } = require("%scripts/user/balance.nut")
let { getLocTextFromConfig } = require("%scripts/langUtils/language.nut")
let { gameEvents, isEventsLoaded, setEventsLoaded, getEvent, getEventByEconomicName, getEventsList, getLastPlayedEvent, getEventMission, isGameTypeOfEvent, isCustomGameMode, isEventMultiSlotEnabled, isMultiCluster, needRankInfoInQueue, isEventRandomBattlesById, getEventDifficulty, getEventDiffCode } = require("%scripts/events/eventsState.nut")
let { allUnitTypesMask, getTeamData, isTeamDataPlayable, getTeamName, getCountries, getAlowedCrafts, getForbiddenCrafts, getRequiredCrafts, hasUnitRequirements, getMinCraftsToPlay, initSidesOnce, getSidesList, isEventSymmetricTeams, isEventFreeForAll, getCountriesByTeams, isCountryAvailable, getAvailableCountriesByEvent, countAvailableUnitTypes, getUnitTypesByTeamDataAndName, getEventUnitTypesMask, getEventRequiredUnitTypesMask, isUnitTypeAvailable, isUnitTypeRequired, getEDiffByEvent, isUnitMatchesRule, isUnitAllowedByTeamData, isAirRequiredAndAllowedByTeamData, isUnitAllowed, isUnitAllowedForEvent, checkUnitRelevanceForEvent, getMaxBrText } = require("%scripts/events/eventTeamsInfo.nut")
let { getMGameMode, getTeamDataWithRoom, getAvailableTeams, checkRequiredUnits, getCountryRepairInfo, getMembersTeamsData, getMembersInfo } = require("%scripts/events/eventUnitsAvail.nut")
let { getTextsBlock, getEventNameText, getNameByEconomicName } = require("%scripts/events/eventTexts.nut")
let { isEventAllowedByVrMode, isEventAllowedByComaptibilityMode } = require("%scripts/events/eventAllowed.nut")
let { getTierByMaxBr } = require("%scripts/events/eventBrToTier.nut")
let { countEventsList, getEventStartTime, getEventEndTime, isEventEnabled, isEventActive, isEventEnded, isEventEnableOnDebug, isEventDisplayWide, diffCodeCompare, getEventDiffName, getEventTileImageName, getEventPreviewVideoName, getEventsForGcDrawer, getEventIsVisible, isEventVisibleInEventsWindow, getEventsVisibleInEventsWindowCount, getEventsChapter } = require("%scripts/events/eventDisplay.nut")
let { getEventTickets, eventRequiresTicket, getEventActiveTicket, hasEventTicket } = require("%scripts/events/eventTickets.nut")
let { getEventEconomicName, getEventTournamentMode, isEventForClan, hasEventFeature, getEventDisplayType, setEventDisplayType, eventIdsForMainGameModeList, isEventRandomBattles, isEventWithLobby, getMaxLobbyDisbalance, getEventReqFeature, isEventVisibleByFeature, isEventPlatformOnlyAllowed, canJoinWithoutRequireCrafts, isEventAllowedByPackage, getEventLeagueName } = require("%scripts/events/eventInfo.nut")
let { getLbCategoryTypeByField, eventsTableConfig } = require("%scripts/leaderboard/leaderboardCategoryType.nut")
let { isCrewLockedByPrevBattle } = require("%scripts/crew/crewInfo.nut")
let { findRulesClassByName } = require("%scripts/misCustomRules/missionCustomState.nut")
let { getCurSlotbarUnit } = require("%scripts/slotbar/slotbarState.nut")
let { getCrewsListByCountry } = require("%scripts/slotbar/crewsList.nut")
let { requestEventLeaderboardData, requestEventLeaderboardSelfRow, requestCustomEventLeaderboardData, convertLeaderboardData, requestContactLeaderboardData, convertContactLeaderboardData } = require("%scripts/leaderboard/requestLeaderboardData.nut")
let { userIdInt64, userIdStr } = require("%scripts/user/profileStates.nut")
let { getTableActiveIndex } = require("%scripts/userstat/userstat.nut")
let { isNewbieEventId } = require("%scripts/user/myStatsState.nut")
let { g_event_display_type } = require("%scripts/events/eventDisplayType.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { getCrewUnit } = require("%scripts/crew/crew.nut")
let { maxCountryRank } = require("%scripts/ranks.nut")
let { checkLbRowVisibility } = require("%scripts/leaderboard/leaderboardHelpers.nut")
let { enqueueItem, requestLimits } = require("%scripts/items/itemLimits.nut")
let { getSessionLobbyClusterName, getSessionLobbyCurRoomEdiff } = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { getRoomSpecialRules, getMembersCountByTeams, getRoomEvent } = require("%scripts/matchingRooms/sessionLobbyInfo.nut")
let { getMemberStatusLocTag, getMemberStatusLocId } = require("%scripts/squads/squadUtils.nut")
let { havePackage, getPkgLocName } = require("%scripts/clientState/contentPacks.nut")
let { eventChaptersManager } = require("%scripts/events/eventsChapter.nut")
let { MATCHING_EVENTS_DATA_RECEIVED, EVENTS_DATA_UPDATED } = require("%scripts/crossModuleEvents.nut")

const EVENTS_OUT_OF_DATE_DAYS = 15
const EVENT_DEFAULT_TEAM_SIZE = 16

const SQUAD_NOT_READY_LOC_TAG = "#snr"
const SQUAD_PROCEED_ANYWAY = "#spraw"
const ES_UNIT_TYPE_TOTAL_RELEASED = 3

let diffTable = {
  arcade    = 0
  realistic = 2
  hardcore  = 4
}


local events


systemMsg.registerLocTags({
  [SQUAD_NOT_READY_LOC_TAG] = "msgbox/squad_not_ready_for_event",
  [SQUAD_PROCEED_ANYWAY] = "ask/proceedAnyway"
})

local g_event_ticket_buy_offer

let EventTicketBuyOfferProcess = class {
  _event = null
  _tickets = null

  constructor (event) {
    this._event = event
    this._tickets = events.getEventTickets(event, true)
    foreach (ticket in this._tickets)
      enqueueItem(ticket.id)
    if (requestLimits(true))
      add_event_listener("ItemLimitsUpdated", this.onEventItemLimitsUpdated, this)
    else
      this.handleTickets()
  }

  function onEventItemLimitsUpdated(_params) {
    removeEventListenersByEnv("ItemLimitsUpdated", this)
    this.handleTickets()
  }

  function handleTickets() {
    g_event_ticket_buy_offer.currentProcess = null

    
    let availableTickets = []
    foreach (ticket in this._tickets)
      if (ticket.getLimitsCheckData().result)
        availableTickets.append(ticket)

    let activeTicket = events.getEventActiveTicket(this._event)
    if (availableTickets.len() == 0) {
      let msgArr = [loc("events/wait_for_sessions_to_finish/main")]
      if (activeTicket != null) {
        let tournamentData = activeTicket.getTicketTournamentData(getEventEconomicName(this._event))
        msgArr.append(loc("events/wait_for_sessions_to_finish/optional", {
          timeleft = time.secondsToString(tournamentData.timeToWait)
        }))
      }
      scene_msg_box("cant_join", null,  "\n".join(msgArr, true), [["ok"]], "ok")
    }
    else {
      let windowParams = {
        event = this._event
        tickets = availableTickets
        activeTicket = activeTicket
      }
      loadHandler(TicketBuyWindow, windowParams)
    }
  }
}

g_event_ticket_buy_offer = {
  
  
  currentProcess = null

  function offerTicket(event) {
    assert(this.currentProcess == null, "Attempt to use multiple event ticket but offer processes.");
    this.currentProcess = EventTicketBuyOfferProcess(event)
  }
}

let _leaderboards = {
  cashLifetime = 60000
  __cache = {
    leaderboards = {}
    selfRow      = {}
  }


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

    lbContactTable = null
    lbContactIndex = 0
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

    lbContactTable = null
    lbContactIndex = 0
  }

  canRequestEventLb    = true
  leaderboardsRequestStack = []

  



  function requestLeaderboard(requestData, id, callback, context) {
    if (id instanceof Function) {
      context  = callback
      callback = id
      id = null
    }

    requestData = this.validateRequestData(requestData)

    let cachedData = this.getCachedLbResult(requestData, "leaderboards")

    
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

  



  function requestSelfRow(requestData, id, callback, context) {
    if (id instanceof Function) {
      context  = callback
      callback = id
      id = null
    }

    requestData = this.validateRequestData(requestData)

    let cachedData = this.getCachedLbResult(requestData, "selfRow")

    
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

  



  function requestUpdateEventLb(requestData, onSuccessCb, onErrorCb) {
    if (requestData.lbContactTable != null) {
      requestContactLeaderboardData(requestData, onSuccessCb, onErrorCb)
      return
    }
    else if (requestData.lbTable == null) {
      requestEventLeaderboardData(requestData, onSuccessCb, onErrorCb)
      return
    }
    requestCustomEventLeaderboardData(requestData, onSuccessCb, onErrorCb)
  }

  



  function requestEventLbSelfRow(requestData, onSuccessCb, onErrorCb) {
    if (requestData.lbContactTable != null) {
      requestContactLeaderboardData(requestData, onSuccessCb, onErrorCb)
      return
    } else if (requestData.lbTable == null) {
      requestEventLeaderboardSelfRow(requestData, onSuccessCb, onErrorCb)
      return
    }

    requestCustomEventLeaderboardData(
      requestData.__merge({
        pos = null
        rowsInPage = 0
        userId = userIdInt64.get()
      }),
      onSuccessCb, onErrorCb)
  }

  


  function hashLbRequest(request_data) {
    let { lbContactTable = null } = request_data
    if (lbContactTable != null) {
      let { lbField, lbContactIndex, rowsInPage = "", pos = "" } = request_data
      return "".concat(lbContactTable, lbField, lbContactIndex, rowsInPage, pos)
    }

    return "".concat(
      request_data.lbField,
      request_data?.rowsInPage ?? "",
      request_data?.inverse ?? false,
      request_data?.rowsInPage ?? "",
      request_data?.pos ?? "",
      request_data?.tournament_mode ?? "")
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
    let { hasAllPlayersInResult = false } = requestData
    if (hasAllPlayersInResult) {
      let requestDataWithoutCallback = clone requestData
      requestDataWithoutCallback.$rawdelete("callBack")
      this.handleLbRequest(requestDataWithoutCallback, id, requestResult)
    }
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
    newRequest.tournament <- (event?.tournament ?? false)
    newRequest.tournament_mode <- getEventTournamentMode(event)
    newRequest.forClans <- this.isClanLeaderboard(event)

    let sortLeaderboard = event?.sort_leaderboard
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
    else if (event?.leaderboardContactTable != null) {
      let contactTable = event.leaderboardContactTable
      newRequest.lbContactTable = contactTable
      newRequest.lbContactIndex = getTableActiveIndex(contactTable) ?? 0
      newRequest.lbField = event?.leaderboardContactBestStat ?? "ext4"
      newRequest.hasAllPlayersInResult <-true
    }

    return newRequest
  }

  function isClanLbRequest(requestData) {
    return (requestData?.forClans ?? false)
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
      if (!(name in req1)) 
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
    let { lbContactTable = null, lbField } = requestData
    if (lbContactTable != null) {
      let leaderboardData = convertContactLeaderboardData(blk, lbField)
      let allRows = leaderboardData.rows
      let start = requestData?.pos ?? 0
      let end = min(start + (requestData?.rowsInPage ?? allRows.len()), allRows.len())
      return leaderboardData.__update({ rows = allRows.slice(start, end) })
    }

    let { success = true } = blk?.result
    if (!success)
      return { rows = [] }

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
    let { lbContactTable = null, lbField } = requestData
    if (lbContactTable != null) {
      let myId = userIdStr.get()
      return convertContactLeaderboardData(blk, lbField)
        .rows.filter(@(r) r?._id.tostring() == myId)
    }

    let { success = true } = blk?.result
    if (!success)
      return []

    let res = this.lbBlkToArray(blk)
    if (this.isClanLbRequest(requestData))
      foreach (lbRow in res)
        this.postProcessClanLbRow(lbRow)
    return res
  }

  function lbBlkToArray(blk) {
    if (blk instanceof Table) {
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
    if (!(event?.tournament ?? false))
      return isEventForClan(event)
    return getEventTournamentMode(event) == GAME_EVENT_TYPE.TM_ELO_GROUP
  }

  function postProcessClanLbRow(lbRow) {
    
    
    
    
    let name = lbRow?.name
    if (!u.isString(name) || !name.len())
      return

    local searchIdx = -1
    for (local skipSpaces = 0; skipSpaces >= 0; skipSpaces--) {
      searchIdx = name.indexof(" ", searchIdx + 1)
      if (searchIdx == null) { 
        lbRow.tag <- name
        break
      }
      
      if (searchIdx == 0) {
        skipSpaces = 2
        continue
      }
      if (skipSpaces > 0)
        continue

      lbRow.tag <- name.slice(0, searchIdx)

      
      
      
      
      
    }
  }

  function resetLbCache() {
    this.__cache.leaderboards.clear()
    this.__cache.selfRow.clear()
  }
}

let Events = class {
  constructor() {
    subscribe_handler(this, g_listener_priority.DEFAULT_HANDLER)
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
    this.mergeEventsInfo(gameEvents, newEventsData)
    eventChaptersManager.updateChapters()
    setEventsLoaded(true)
    seenEvents.setDaysToUnseen(EVENTS_OUT_OF_DATE_DAYS)
    seenEvents.onListChanged()
    broadcastEvent(EVENTS_DATA_UPDATED)
  }

  function isTankEventActive(eventPrefix) {
    foreach (event in gameEvents) {
      if (event.name.len() >= eventPrefix.len() &&
          event.name.slice(0, eventPrefix.len()) == eventPrefix &&
          this.isEventEnabled(event))
        return true
    }
    return false
  }

  function getTankEvent(eventPrefix) {
    foreach (event in gameEvents)
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
    }
    return diffWeight
  }

  isEventEnableOnDebug = isEventEnableOnDebug

  function isEventNeedInfoButton(event) {
    if (!isMultiplayerPrivilegeAvailable.get())
      return false

    if (!event)
      return false
    return isEventForClan(event) || isEventWithLobby(event) || this.isEventEnableOnDebug(event)
  }

  function openEventInfo(event) {
    if (isEventWithLobby(event))
      get_gui_handler("EventRoomsHandler")?.open(event)
    else
      loadHandler(get_gui_handler("EventDescriptionWindow"), { event = event })
  }


  isEventDisplayWide = isEventDisplayWide

  function checkTankEvents() {
    foreach (event in gameEvents) {
      if (isEventRandomBattles(event) && this.isEventEnabled(event))
        return true
    }
    return false
  }

  isUnitTypeAvailable = isUnitTypeAvailable

  isUnitTypeRequired = isUnitTypeRequired

  getEventUnitTypesMask = getEventUnitTypesMask

  getEventRequiredUnitTypesMask = getEventRequiredUnitTypesMask



  


  countAvailableUnitTypes = countAvailableUnitTypes

  getUnitTypesByTeamDataAndName = getUnitTypesByTeamDataAndName



  


  getEventsForGcDrawer = getEventsForGcDrawer

  function getVisibleEventsList() {
    return this.getEventsList(EVENT_TYPE.ANY, this.getEventIsVisible)
  }

  function getEventsForEventsWindow() {
    return this.getEventsList(EVENT_TYPE.ANY_BASE_EVENTS,  this.isEventVisibleInEventsWindow)
  }

  function _initEventViewData(eventData) {
    if (!("view_data" in eventData))
      return

    
    
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
      assert(false, "".concat($"Bad event loc_name. eventName = {eventData.name}, ",
        "economicName = ", getEventEconomicName(eventData), ", loc_name = ", toString(eventData.loc_name)))
      eventData.$rawdelete("loc_name")
    }

    let { reqPack = null } = eventData
    if (reqPack != null)
     eventData.reqPacks <- reqPack.replace(";", ",").split(",")

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
    foreach (event in gameEvents) {
      let displayType = this._calcEventDisplayType(event)
      if (displayType == getEventDisplayType(event))
        continue

      setEventDisplayType(event, displayType)
      isChanged = true
    }

    if (isChanged) {
      eventChaptersManager.updateChapters()
      broadcastEvent(EVENTS_DATA_UPDATED)
    }
  }

  getEvent = getEvent

  getMGameMode = getMGameMode

  getEventByEconomicName = getEventByEconomicName

  getLastPlayedEvent = getLastPlayedEvent

  


  isMultiCluster = isMultiCluster

  getEDiffByEvent = getEDiffByEvent

  function getCurBattleEdiff() {
    let event = getRoomEvent()
    let ediff = event ? events.getEDiffByEvent(event) : -1
    if (ediff != -1)
      return ediff
    let lobbyEdiff = getSessionLobbyCurRoomEdiff()
    return lobbyEdiff != -1 ? lobbyEdiff : get_mission_mode()
  }

  function getUnitEconomicRankByEvent(event, unit) {
    let ediff = this.getEDiffByEvent(event)
    return unit.getEconomicRank(ediff)
  }

  getTeamData = getTeamData

  getTeamDataWithRoom = getTeamDataWithRoom

  
  
  isTeamDataPlayable = isTeamDataPlayable

  initSidesOnce = initSidesOnce


  getSidesList = getSidesList

  isEventSymmetricTeams = isEventSymmetricTeams

  needRankInfoInQueue = needRankInfoInQueue

  isEventFreeForAll = isEventFreeForAll

  getTeamName = getTeamName

  




  getEventTileImageName = getEventTileImageName


  getEventPreviewVideoName = getEventPreviewVideoName


  isEventEnabled = isEventEnabled

  getEventsList = getEventsList

  __countEventsList = countEventsList

  function getEventsCount(typeMask = EVENT_TYPE.ANY_BASE_EVENTS) {
    return this.__countEventsList(typeMask, this.isEventEnabled)
  }

  isEventActive = isEventActive

  isEventEnded = isEventEnded

  

  isEventAllowedByVrMode = isEventAllowedByVrMode
  isEventAllowedByComaptibilityMode = isEventAllowedByComaptibilityMode

  getEventsVisibleInEventsWindowCount = getEventsVisibleInEventsWindowCount

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

  function getEndedEventsList(typeMask = EVENT_TYPE.ANY_BASE_EVENTS) { 
    let result = this.getEventsList(typeMask, function (event) {
      return getEventDisplayType(event).showInEventsWindow && this.isEventEnded(event)
    }.bindenv(this))
    result.sort(function (a, b) {
        return this.sortEventsByDiff(a, b)
      }.bindenv(this))
    return result
  }



  getCountries = getCountries

  getCountriesByTeams = getCountriesByTeams

  getAllCountriesSets = getAllCountriesSets

  getAvailableTeams = getAvailableTeams

  isCountryAvailable = isCountryAvailable

  





  getAvailableCountriesByEvent = getAvailableCountriesByEvent

  isUnitMatchesRule = isUnitMatchesRule

  getTierByMaxBr = getTierByMaxBr

  
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

  isUnitAllowedForEvent = isUnitAllowedForEvent

  function isUnitAllowedForEventRoom(event, room, unit) {
    let roomSpecialRules = room && getRoomSpecialRules(room)
    if (roomSpecialRules && !this.isUnitMatchesRoomSpecialRules(unit, roomSpecialRules, this.getEDiffByEvent(event)))
      return false

    let mGameMode = events.getMGameMode(event, room)
    return this.isUnitAllowedForEvent(mGameMode, unit)
  }

  isUnitAllowed = isUnitAllowed

  function isUnitMatchesRoomSpecialRules(unit, roomSpecialRules, ediff) {
    return !roomSpecialRules || this.isUnitMatchesRule(unit, roomSpecialRules, true, ediff)
  }

  function isCurUnitMatchesRoomRules(event, room) {
    let unit = getCurSlotbarUnit()
    if (!unit)
      return false

    let roomSpecialRules = room && getRoomSpecialRules(room)
    return !roomSpecialRules || this.isUnitMatchesRoomSpecialRules(unit, roomSpecialRules, this.getEDiffByEvent(event))
  }



  checkRequiredUnits = checkRequiredUnits

  isAirRequiredAndAllowedByTeamData = isAirRequiredAndAllowedByTeamData

  isUnitAllowedByTeamData = isUnitAllowedByTeamData

  checkUnitRelevanceForEvent = checkUnitRelevanceForEvent

  function getSpecialRequirements(event) {
    return event?.specialRequirements
  }

  function checkSpecialRequirements(event) {
    let requirements = this.getSpecialRequirements(event)
    if (!requirements)
      return true

    let ediff = this.getEDiffByEvent(event)
    foreach (unit in getAllUnits())
       if (isUnitUsable(unit) && this.isUnitMatchesRule(unit, requirements, true, ediff))
         return true
    return false
  }

  function checkPlayerCountryCrafts(country, teamData, ediff, roomSpecialRules, minCrafts) {
    let crews = getCrewsListByCountry(country)
    local validCraftsCount = 0
    foreach (crew in crews) {
      if (isCrewLockedByPrevBattle(crew))
        continue

      let unit = getCrewUnit(crew)
      let isValid = unit != null
        && (minCrafts <= 1 || !isUnitBroken(unit))
        && (!roomSpecialRules || this.isUnitMatchesRule(unit, roomSpecialRules, true, ediff))
        && this.isUnitAllowedByTeamData(teamData, crew.aircraft, ediff)
      if (isValid) {
        validCraftsCount++
        if (validCraftsCount >= minCrafts)
          return true
      }
    }
    return false
  }

  function checkPlayersCrafts(event, room = null, minCrafts = 1) {
    if (canJoinWithoutRequireCrafts(event))
      return true
    let mGameMode = events.getMGameMode(event, room)
    let roomSpecialRules = room && getRoomSpecialRules(room)
    let playersCurCountry = profileCountrySq.get()
    let ediff = this.getEDiffByEvent(event)
    foreach (team in this.getSidesList(mGameMode)) {
      let teamData = this.getTeamDataWithRoom(mGameMode, team, room)
      if (teamData && isInArray(playersCurCountry, teamData.countries)
          && this.checkPlayerCountryCrafts(playersCurCountry, teamData, ediff, roomSpecialRules, minCrafts))
          return true
    }
    return false
  }

  function checkPlayersCraftsRoomRules(event, room) {
    let roomSpecialRules = getRoomSpecialRules(room)
    if (!roomSpecialRules)
      return true
    let ediff = this.getEDiffByEvent(event)
    foreach (crew in getCrewsListByCountry(profileCountrySq.get())) {
      let unit = getCrewUnit(crew)
      if (unit && this.isUnitMatchesRoomSpecialRules(unit, roomSpecialRules, ediff))
        return true
    }
    return false
  }

  getCountryRepairInfo = getCountryRepairInfo

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
          statusLocParams = member?.statusLocParams
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
      let teamLangConfig = stacks.map(function(s) {
        let { status, statusLocParams, names } = s
        let statusLoc = statusLocParams != null
          ? { [systemMsg.LOC_ID] = getMemberStatusLocId(status) }.__update(statusLocParams)
          : getMemberStatusLocTag(status)
        return [
          systemMsg.makeColoredValue(COLOR_TAG.USERLOG, ", ".join(names, true)),
          "ui/colon",
          statusLoc
        ]
      })
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
        langConfig.append({ [systemMsg.LOC_ID] = $"events/{g_team.getTeamByCode(teamCode).name}" })
        langConfig.extend(teamLangConfig)
      }

    let buttons = [ ["ok", cancelFunc ] ]
    if (teamData.haveRestrictions && teamData.canFlyout) {
      langConfig.append(SQUAD_PROCEED_ANYWAY)
      buttons[0][0] = "no"
      buttons.insert(0, ["yes", continueQueueFunc ])
    }

    scene_msg_box("members_cant_fly",
                    null,
                    systemMsg.configToLang(langConfig, null, "\n"),
                    buttons,
                    "no",
                    { cancel_fn = cancelFunc })

    sendLocalizedMessageToSquadRoom(getSquadRoomName(), langConfig)
  }

  getMembersTeamsData = getMembersTeamsData




  getAlowedCrafts = getAlowedCrafts

  getForbiddenCrafts = getForbiddenCrafts

  getRequiredCrafts = getRequiredCrafts

  hasUnitRequirements = hasUnitRequirements

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

  



  function isEventRespawnEnabled(event) {
    return event?.respawn ?? false
  }

  



  isEventMultiSlotEnabled = isEventMultiSlotEnabled

  



  function getEventMaxRespawns(event) {
    return event?.mission_decl.maxRespawns ?? 0
  }

  function getEventRewardMuls(eventId) {
    let res = { wp = 1.0, exp = 1.0 }
    let event = getEvent(eventId)
    if (event == null)
      return res

    if ("reward_mul_wp" in event)
      res.wp = event.reward_mul_wp
    if ("reward_mul_exp" in event)
      res.exp = event.reward_mul_exp
    return res
  }

  getEventDifficulty = getEventDifficulty
  getEventDiffCode = getEventDiffCode

  getEventDiffName = getEventDiffName

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
    return max((event?.minTeamSize ?? 1), 1)
  }


  getEventStartTime = getEventStartTime

  getEventEndTime = getEventEndTime



  function getEventAchievementGroup(event) {
    return event?.achievementGroup ?? ""
  }

  function onEventSignOut(_p) {
    gameEvents.clear()
    setEventsLoaded(false)
    eventChaptersManager.updateChapters()
  }

  getEventMission = getEventMission

  function getFeaturedEvent() {
    let diff = getCurrentShopDifficulty()
    foreach (eventName, event in gameEvents)
      if (this.getEventDifficulty(eventName) == diff &&
          this.isEventEnabled(event))
        return eventName
    return ""
  }

  getTextsBlock = getTextsBlock

  

  getMaxBrText = getMaxBrText

  getEventNameText = getEventNameText

  getNameByEconomicName = getNameByEconomicName

  function getBaseDescByEconomicName(economicName) {
    let res = getLocTextFromConfig(this.getTextsBlock(economicName), "desc", "")
    if (res.len())
      return res

    let event = events.getEventByEconomicName(economicName)
    return loc(event?.loc_desc ?? $"events/{economicName}/desc", "")
  }

  function getEventLeaderboardName(event) {
    let leagueName = getEventLeagueName(event)
    return leagueName != "" ? leagueName
      : this.getEventNameText(event)
  }

  isEventRandomBattlesById = isEventRandomBattlesById

  function getMainLbRequest(event) {
    return _leaderboards.getMainLbRequest(event)
  }

  



  function requestLeaderboard(requestData, id, callback = null, context = null) {
    _leaderboards.requestLeaderboard(requestData, id, callback, context)
  }

  



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
    if (!checkLbRowVisibility(row, params))
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
      allowId = "".concat("allowed_only/", getUnitTypeText(stdMath.number_of_set_bits(allowedUnitTypes - 1)))
    if (stdMath.number_of_set_bits(allowedUnitTypes) == 2) {
      let masksArray = unitTypes.getArrayBybitMask(allowedUnitTypes)
      if (masksArray && masksArray.len() == 2) {
        const allowUnitId = "events/allowed_units"
        allowText = loc(allowUnitId, {
          unitType = loc($"{allowUnitId}/{masksArray[0].name}"),
          unitType2 = loc($"{allowUnitId}/{masksArray[1].name}")
        })
        allowText = capitalize(allowText)
      }
    }
    allowText = allowText == "" ? loc($"events/{allowId}") : allowText
    allowedUnitTypesObj.findObject("allowed_unit_types_text").setValue(allowText)
  }

  function generateRulesText(handler, rules, rulesObj, _highlightRules = false, checkAllRules = false) {
    
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
        airNameObj.setValue(loc($"{rule.name}_shop"))

        if (isUnitUsable(air))
          airNameObj.airBought = "yes"
        else if (isUnitGift(air) || canBuyUnit(air))
          airNameObj.airCanBuy = "yes"
        else {
          let special = isUnitSpecial(air)
          let isSquadronVehicle = air.isSquadronVehicle()
          let isEraLocked = !special && !isSquadronVehicle && !isUnitsEraUnlocked(air)
          let isLocked = isEraLocked || getCantBuyUnitReason(air, true) != ""
          airNameObj.airCanBuy = !isLocked? "yes" : "no"
        }

        let airIconObj = ruleObj.findObject("air_icon")
        airIconObj["background-image"] = getUnitClassIco(rule.name)
        airIconObj.shopItemType = getUnitRole(rule.name)

        ruleObj.findObject("tooltip_obj").tooltipId = getTooltipType("UNIT").getTooltipId(air.name, { needShopInfo = true })
      }
    }
    else if ("type" in rule)
      ruleString = "".concat(ruleString, loc($"mainmenu/type_{rule.type}"))
    else if ("class" in rule) {
      local ruleClass = rule["class"]
      if (ruleClass == "ship")
        ruleClass = "ship_and_boat"
      ruleString = "".concat(ruleString, loc($"mainmenu/type_{ruleClass}"))
    }
    if ("ranks" in rule) {
      let minRank = max(1, rule.ranks?.min ?? 1)
      let maxRank = rule.ranks?.max ?? maxCountryRank.get()
      local rankText = "".concat(get_roman_numeral(minRank),
        minRank != maxRank ? $" - {get_roman_numeral(maxRank)}" : "")
      rankText = format(loc("events/rank"), rankText)
      if (ruleString.len())
        ruleString = "".concat(ruleString, loc("ui/parentheses/space", { text = rankText }))
      else
        ruleString = rankText
    }

    if ("mranks" in rule) {
      let mranks = rule.mranks
      let minBR = format("%.1f", calcBattleRatingFromRank(mranks?.min ?? 0))
      let maxBR = format("%.1f", calcBattleRatingFromRank(mranks?.max ?? getMaxEconomicRank()))
      local brText = "".concat(minBR, minBR != maxBR ? $" - {maxBR}" : "")
      brText = format(loc("events/br"), brText)
      if (ruleString.len())
        ruleString = "".concat(ruleString, loc("ui/parentheses/space", { text = brText }))
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
      value = "".concat(minSize, isEqual ? "" : $" - {maxSize}")
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
      let roomSpecialRules = room && getRoomSpecialRules(room)
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
    if (maxDisbalance >= MAX_PLAYERS_VERSUS)
      return true
    let teams = this.getSidesList(mGameMode)
    let availTeams = this.getAvailableTeams(mGameMode, room)
    if (availTeams.len() != 1 || availTeams.len() == teams.len())
      return true

    let membersCount = getOnlineMembersCount()
    let myTeam = availTeams[0]
    let otherTeam = u.search(teams, function(t) { return t != myTeam })
    let countTbl = getMembersCountByTeams(room)
    return (countTbl?[myTeam] ?? 0) + membersCount <= (countTbl?[otherTeam] ?? 0) + maxDisbalance
  }

  function hasPlaceInMyTeam(mGameMode, room) {
    if (!room)
      return true
    let availTeams = this.getAvailableTeams(mGameMode, room)
    if (availTeams.len() != 1)
      return true

    let membersCount = getOnlineMembersCount()
    let countTbl = getMembersCountByTeams(room)
    return countTbl[availTeams[0]] + membersCount <= this.getMaxTeamSize(mGameMode)
  }

  function getCantJoinReasonData(event, room = null, params = null) {
    let data = {
      activeJoinButton = false
      reasonText = null
      msgboxReasonText = null
      checkStatus = false
      actionFunc = null
      event = event 
      room = room
      checkXboxOverlayMessage = false
    }.__update(params ?? {})

    let { isFullText = false, isCreationCheck = false } = params
    let mGameMode = events.getMGameMode(event, room)
    let minCraftsToPlay = this.getMinCraftsToPlay(event)
    if (event == null)
      data.reasonText = loc("events/no_selected_event")
    else if (!hasEventFeature(event)) {
      let purchData = getFeaturePurchaseData(getEventReqFeature(event))
      data.activeJoinButton = purchData.canBePurchased
      data.reasonText = this.getEventFeatureReasonText(event)
    }
    else if (!this.isEventAllowedByComaptibilityMode(event))
      data.reasonText = loc("events/noCompatibilityMode")
    else if (!this.isEventAllowedByVrMode(event))
      data.reasonText = loc("events/noVrMode")
    else if (!isEventAllowedByPackage(event))
      data.reasonText = loc("events/no_entitlement", { entitlement = loc("ui/comma").join(
        event.reqPacks.filter(@(packName) !havePackage(packName))
          .map(@(packName) getPkgLocName(packName, true)))
      })
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
          messageText = "\n".concat(messageText, format(loc("events/event_starts_in"), colorize("activeTextColor",
            time.hoursToString(time.secondsToHours(startTime)))))
        scene_msg_box("cant_join", null, messageText,
            [["ok", function() {}]], "ok")
      }
    }
    else if (!isMultiplayerPrivilegeAvailable.get()) {
      data.reasonText = loc("xbox/noMultiplayer")
      data.msgboxReasonText = loc("xbox/noMultiplayer")
      data.checkXboxOverlayMessage = true
    }
    else if (!isEventPlatformOnlyAllowed(mGameMode) && !crossplayModule.isCrossPlayEnabled()) {
      data.reasonText = loc("xbox/crossPlayRequired")
      data.msgboxReasonText = loc("xbox/actionNotAvailableCrossNetworkPlay")
      data.checkXboxOverlayMessage = true
    }
    else if (!this.checkSpecialRequirements(event)) {
      if (isFullText)
        data.reasonText = "".concat(loc("events/specialRequirements"), loc("ui/colon"), "\n",
          this.getSpecialRequirementsText(event))
      else
        data.reasonText = loc("events/no_specialRequirements")
    }
    else if (!this.getAvailableTeams(mGameMode, room).len())
      data.reasonText = loc("events/no_selected_country")
    else if (!this.checkPlayersCrafts(mGameMode, room, minCraftsToPlay))
      data.reasonText = minCraftsToPlay > 1
        ? loc("events/minCraftsToPlay", { count = minCraftsToPlay })
        : loc("events/no_allowed_crafts")
    else if (isEventForClan(event) && !myClanInfo.get())
      data.reasonText = loc("events/clan_only")
    else if (!isCreationCheck && this.isEventEnded(event))
      data.reasonText = loc("events/event_disabled")
    else if (!this.checkRequiredUnits(mGameMode, room))
      data.reasonText = $"{loc("events/no_required_crafts")}{loc("ui/dot")}"
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
        g_event_ticket_buy_offer.offerTicket(reasonData.event)
      }
    }
    else if (getOnlineMembersCount() < this.getMinSquadSize(event))
      data.reasonText = loc("events/minSquadSize", { minSize = this.getMinSquadSize(event) })
    else if (getOnlineMembersCount() > this.getMaxSquadSize(event))
      data.reasonText = loc("events/maxSquadSize", { maxSize = this.getMaxSquadSize(event) })
    else if (!this.hasPlaceInMyTeam(mGameMode, room)) {
      let myTeam = this.getAvailableTeams(mGameMode, room)[0]
      data.reasonText = loc("multiplayer/chosenTeamIsFull",
        {
          chosenTeam = colorize("teamBlueColor", g_team.getTeamByCode(myTeam).getShortName())
        })
    }
    else if (!this.isAllowedByRoomBalance(mGameMode, room)) {
      let teamsCnt = getMembersCountByTeams(room)
      let myTeam = this.getAvailableTeams(mGameMode, room)[0]
      let otherTeam = u.search(this.getSidesList(mGameMode), @(t) t != myTeam)
      let membersCount = getOnlineMembersCount()
      let locParams = {
        chosenTeam = colorize("teamBlueColor", g_team.getTeamByCode(myTeam).getShortName())
        otherTeam =  colorize("teamRedColor", g_team.getTeamByCode(otherTeam).getShortName())
        chosenTeamCount = teamsCnt[myTeam]
        otherTeamCount =  teamsCnt[otherTeam]
        reqOtherteamCount = teamsCnt[myTeam] - getMaxLobbyDisbalance(mGameMode) + membersCount
      }
      let locKey = "".concat("multiplayer/enemyTeamTooLowMembers", (isFullText ? "" : "/short"))
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
        else if (!isMultiplayerPrivilegeAvailable.get())
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

  
  
  

  function sortEventsByDiff(a, b) {
    let diffA = (a instanceof String ? gameEvents[a] : a).diffWeight
    let diffB = (b instanceof String ? gameEvents[b] : b).diffWeight
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

  diffCodeCompare = diffCodeCompare

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

  
  getEventTickets = getEventTickets

  
  getEventActiveTicket = getEventActiveTicket

  function getEventActiveTicketText(event, valueColor = "activeTextColor") {
    let ticket = this.getEventActiveTicket(event)
    if (!ticket)
      return ""

    return "\n".join([
        ticket.getCost() > zero_money
          ? loc("events/ticket_cost", {
            cost = colorize(valueColor, ticket.getCost(true).getTextAccordingToBalance()) })
          : "",
        ticket.getAvailableDefeatsText(getEventEconomicName(event))
      ], true)
  }

  



  function getEventBattleCostText(event, valueColor = "activeTextColor", useShortText = false, colored = true) {
    let cost = this.getEventBattleCost(event)
    if (cost <= zero_money)
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

  hasEventTicket = hasEventTicket

  eventRequiresTicket = eventRequiresTicket

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
    
    loadHandler(TicketBuyWindow, { event, tickets = purchasableTickets })
  }

  




  function checkClan(event) {
    let clanTournament = getBlkValueByPath(get_tournaments_blk(),$"{event.name}/clanTournament", false)
    if (!clanTournament)
      return true
    if (!is_in_clan())
      return false
    if (getBlkValueByPath(get_tournaments_blk(),$"{event.name}/allowToSwitchClan"))
      return true
    let tournamentBlk = DataBlock()
    get_tournament_info_blk(getEventEconomicName(event), tournamentBlk)
    return tournamentBlk?.clanId ? clan_get_my_clan_id() == tournamentBlk.clanId.tostring() : true
  }

  function checkMembersForQueue(event, room = null, continueQueueFunc = null, cancelFunc = null) {
    if (!isInSquad())
      return continueQueueFunc && continueQueueFunc(null)

    let teams = this.getAvailableTeams(event, room)
    let membersTeams = this.getMembersTeamsData(event, room, teams)
    if (!membersTeams) 
      return cancelFunc && cancelFunc()

    let membersInfo = this.getMembersInfo(membersTeams)
    if (membersTeams.haveRestrictions) {
      let func = @() continueQueueFunc && continueQueueFunc(membersInfo)
      this.showCantFlyMembersMsgBox(membersTeams, func, cancelFunc)
      return
    }

    if (continueQueueFunc)
      continueQueueFunc(membersInfo)
  }

  getMembersInfo = getMembersInfo

  getEventsChapter = getEventsChapter

  function getChapters() {
    return eventChaptersManager.getChapters()
  }

  function checkEventDisableSquads(handler, eventId) {
    if (!isNotAloneOnline())
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

  getEventIsVisible = getEventIsVisible

  isEventVisibleInEventsWindow = isEventVisibleInEventsWindow
  


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
    let wpText = this.buildBonusText((100.0 * (muls.wp  - 1.0) + 0.5).tointeger(), $"% {loc("warpoints/short/colored")}")
    let expText = this.buildBonusText((100.0 * (muls.exp - 1.0) + 0.5).tointeger(), $"% {loc("currency/researchPoints/sign/colored")}")
    return "".concat(wpText, (wpText.len() && expText.len()) ? ", " : "", expText)
  }

  function buildBonusText(value, endingText) {
    if (!value || value <= 0)
      return ""
    return "".concat("+", value, endingText)
  }

  function getEventDescriptionText(event, mroom = null, hasEventFeatureReasonText = false) {
    let textsList = []

    textsList.append(this.getCustomRulesDesc(event))
    textsList.append(this.getBaseDescByEconomicName(getEventEconomicName(event)))
    textsList.append(this.descFormat(loc("reward"), this.getEventRewardText(event)))
    textsList.append(this.descFormat(loc("events/specialRequirements"), this.getSpecialRequirementsText(event, ", ")))
    textsList.append(this.getTextBoostersDoNotWork(event))
    textsList.append(this.getUnlockProgress(event))
    textsList.append(this.getTimeAwardingEconomicsDesc(event))

    if (mroom)
      textsList.append(this.descFormat(loc("options/cluster"),
        getClusterShortName(getSessionLobbyClusterName(mroom))))

    let isTesting = ("event_access" in event) ? isInArray("AccessTest", event.event_access) : false
    if (isTesting)
      textsList.append(colorize("@yellow", loc("events/event_is_testing")))

    if (hasEventFeatureReasonText && !hasEventFeature(event))
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
    return events.descFormat(loc("multiplayer/difficulty"), this.getDifficultyText(eventId))
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

  function getTextBoostersDoNotWork(event) {
    if (event.mission_decl?.gt_use_unlocks ?? true)
      return ""
    return loc("events/boosters_do_not_work")
  }

  function getTimeAwardingEconomicsDesc(event) {
    return event.mission_decl?.useTimeAwardingEconomics ? loc("events/has_time_awarding_economics") : ""
  }

  function isEventForClanGlobalLb(event) {
    let tournamentMode = getEventTournamentMode(event)
    let forClans = _leaderboards.isClanLeaderboard(event)

    return tournamentMode == GAME_EVENT_TYPE.TM_NONE && forClans
  }

  function checkEventFeature(event) {
    if (hasEventFeature(event))
      return true

    let feature = getEventReqFeature(event)

    let purchData = getFeaturePurchaseData(feature)
    if (!purchData.canBePurchased)
      return showInfoMsgBox(loc("msgbox/notAvailbleYet"))

    let entitlementItem = getEntitlementConfig(purchData.sourceEntitlement)
    let msg = loc("msg/eventAccess/needEntitlements",
                      {
                        event = colorize("activeTextColor", this.getEventNameText(event))
                        entitlement = colorize("userlogColoredText", getEntitlementName(entitlementItem))
                      })
    ReqPurchaseWnd.open({
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

  
  isCustomGameMode = isCustomGameMode

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

    loadHandler(get_gui_handler("CreateEventRoomWnd"),
      { mGameMode = customMgm })
  }

  function getMaxSquadSize(event) {
    return event?.maxSquadSize ?? 4
  }

  function getMinSquadSize(event) {
    return event?.minSquadSize ?? 1
  }

  getMinCraftsToPlay = getMinCraftsToPlay

  isGameTypeOfEvent = isGameTypeOfEvent

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

  isEventsLoaded = isEventsLoaded
  getChapter = @(chapterId) eventChaptersManager.getChapter(chapterId)
}

events = Events()

seenEvents.setListGetter(@() events.getVisibleEventsList())

seenEvents.setSubListGetter(SEEN.S_EVENTS_WINDOW,
  @() events.getEventsForEventsWindow())

seenEvents.setCompatibilityLoadData(function() {
    let res = {}
    const savePath = "seen/events"
    let blk = loadLocalByAccount(savePath)
    if (!u.isDataBlock(blk))
      return res

    for (local i = 0; i < blk.paramCount(); i++)
      res[blk.getParamName(i)] <- blk.getParamValue(i)
    saveLocalByAccount(savePath, null)
    return res
  })

addListenersWithoutEnv({
  [MATCHING_EVENTS_DATA_RECEIVED] = @(p) events.updateEventsData(p.eventsData)
}, g_listener_priority.DEFAULT_HANDLER)



events = freeze(events)

return {
  events
}
