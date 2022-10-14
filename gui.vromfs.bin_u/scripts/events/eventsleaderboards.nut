from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let { getSeparateLeaderboardPlatformName } = require("%scripts/social/crossplay.nut")

::events._leaderboards = {
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
    rowsInPage = max(EVENTS_SHORT_LB_REQUIRED_PARTICIPANTS_TO_SHOW, EVENTS_SHORT_LB_VISIBLE_ROWS)
    inverse = false,
    forClans = false,
    tournament = false,
    tournament_mode = GAME_EVENT_TYPE.TM_NONE
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
  }

  canRequestEventLb    = true
  leaderboardsRequestStack = []

  /**
   * Function requests leaderboards asynchronously and puts result
   * as argument to callback function
   */
  function requestLeaderboard(requestData, id, callback, context)
  {
    if (typeof id == "function")
    {
      context  = callback
      callback = id
      id = null
    }

    requestData = validateRequestData(requestData)

    let cachedData = getCachedLbResult(requestData, "leaderboards")

    //trigging callback if data is lready here
    if (cachedData)
    {
      if (context)
        callback.call(context, cachedData)
      else
        callback(cachedData)
      return
    }

    requestData.callBack <- Callback(callback, context)
    updateEventLb(requestData, id)
  }

  /**
   * Function requests self leaderboard row asynchronously and puts result
   * as argument to callback function
   */
  function requestSelfRow(requestData, id, callback, context)
  {
    if (typeof id == "function")
    {
      context  = callback
      callback = id
      id = null
    }

    requestData = validateRequestData(requestData)

    let cachedData = getCachedLbResult(requestData, "selfRow")

    //trigging callback if data is lready here
    if (cachedData)
    {
      if (context)
        callback.call(context, cachedData)
      else
        callback(cachedData)
      return
    }

    requestData.callBack <- Callback(callback, context)
    updateEventLbSelfRow(requestData, id)
  }

  function updateEventLbInternal(requestData, id, requestFunc, handleFunc)
  {
    let requestAction = Callback(function() {
      requestFunc(
        requestData,
        Callback(function(successData) {
          canRequestEventLb = false
          handleFunc(requestData, id, successData)

          if (leaderboardsRequestStack.len())
            leaderboardsRequestStack.remove(0).fn()
          else
            canRequestEventLb = true
        }, this),
        Callback(function(errorId) {
          canRequestEventLb = true
        }, this)
      )}, this)

    if (canRequestEventLb)
      return requestAction()

    if (id)
      foreach (index, request in leaderboardsRequestStack)
        if (id == request)
          leaderboardsRequestStack.remove(index)

    leaderboardsRequestStack.append({fn = requestAction, id = id})
  }

  function updateEventLb(requestData, id)
  {
    updateEventLbInternal(requestData, id, requestUpdateEventLb, handleLbRequest)
  }

  function updateEventLbSelfRow(requestData, id)
  {
    updateEventLbInternal(requestData, id, requestEventLbSelfRow, handleLbSelfRowRequest)
  }

  /**
   * To request persoanl data for clan tournaments (TM_ELO_GROUP)
   * need to override tournament_mode by TM_ELO_GROUP_DETAIL
   */
  function requestUpdateEventLb(requestData, onSuccessCb, onErrorCb)
  {
    let blk = ::DataBlock()
    blk.event = requestData.economicName
    blk.sortField = requestData.lbField
    blk.start = requestData.pos
    blk.count = requestData.rowsInPage
    blk.inverse = requestData.inverse
    blk.clan = requestData.forClans
    blk.tournamentMode = GAME_EVENT_TYPE.TM_NONE
    blk.version = 1
    blk.targetPlatformFilter = getSeparateLeaderboardPlatformName()

    if (blk.start == null || blk.start < 0)
    {
      let event = blk.event  // warning disable: -declared-never-used
      let start = blk.start  // warning disable: -declared-never-used
      let count = blk.count  // warning disable: -declared-never-used
      ::script_net_assert_once("event_leaderboard__invalid_start", "Event leaderboard: Invalid start")
      log($"Error: Event '{event}': Invalid leaderboard start={start} (count={count})")

      blk.start = 0
    }
    if (blk.count == null || blk.count <= 0)
    {
      let event = blk.event  // warning disable: -declared-never-used
      let count = blk.count  // warning disable: -declared-never-used
      let start = blk.start  // warning disable: -declared-never-used
      ::script_net_assert_once("event_leaderboard__invalid_count", "Event leaderboard: Invalid count")
      log($"Error: Event '{event}': Invalid leaderboard count={count} (start={start})")

      blk.count = 49  // unusual value indicate problem
    }

    let event = ::events.getEvent(requestData.economicName)
    if (requestData.tournament || ::events.isRaceEvent(event))
      blk.tournamentMode = requestData.tournament_mode

    return ::g_tasker.charRequestBlk("cln_get_events_leaderboard", blk, null, onSuccessCb, onErrorCb)
  }

  /**
   * to request persoanl data for clan tournaments (TM_ELO_GROUP)
   * need to override tournament_mode by TM_ELO_GROUP_DETAIL
   */
  function requestEventLbSelfRow(requestData, onSuccessCb, onErrorCb)
  {
    let blk = ::DataBlock()
    blk.event = requestData.economicName
    blk.sortField = requestData.lbField
    blk.start = -1
    blk.count = -1
    blk.clanId = ::clan_get_my_clan_id();
    blk.inverse = requestData.inverse
    blk.clan = requestData.forClans
    blk.version = 1
    blk.tournamentMode = GAME_EVENT_TYPE.TM_NONE
    blk.targetPlatformFilter = getSeparateLeaderboardPlatformName()

    let event = ::events.getEvent(requestData.economicName)
    if (requestData.tournament || ::events.isRaceEvent(event))
      blk.tournamentMode = requestData.tournament_mode

    return ::g_tasker.charRequestBlk("cln_get_events_leaderboard", blk, null, onSuccessCb, onErrorCb)
  }

  /**
   * Function generates hash string from leaderboard request data
   */
  function hashLbRequest(request_data)
  {
    local res = ""
    res += request_data.lbField
    res += getTblValue("rowsInPage", request_data, "")
    res += getTblValue("inverse", request_data, false)
    res += getTblValue("rowsInPage", request_data, "")
    res += getTblValue("pos", request_data, "")
    res += getTblValue("tournament_mode", request_data, "")
    return res
  }

  function handleLbRequest(requestData, id, requestResult)
  {
    let lbData = getLbDataFromBlk(requestResult, requestData)

    if (!(requestData.economicName in __cache.leaderboards))
      __cache.leaderboards[requestData.economicName] <- {}

    __cache.leaderboards[requestData.economicName][hashLbRequest(requestData)] <- {
      data = lbData
      timestamp = ::dagor.getCurTime()
    }

    if (id)
      foreach (request in leaderboardsRequestStack)
        if (request.id == id)
          return

    if ("callBack" in requestData)
      if ("handler" in requestData)
        requestData.callBack.call(requestData.handler, lbData)
      else
        requestData.callBack(lbData)
  }

  function handleLbSelfRowRequest(requestData, id, requestResult)
  {
    let lbData = getSelfRowDataFromBlk(requestResult, requestData)

    if (!(requestData.economicName in __cache.selfRow))
      __cache.selfRow[requestData.economicName] <- {}

    __cache.selfRow[requestData.economicName][hashLbRequest(requestData)] <- {
      data = lbData
      timestamp = ::dagor.getCurTime()
    }

    if (id)
      foreach (request in leaderboardsRequestStack)
        if (request.id == id) return

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
  function getCachedLbResult(request_data, storage_name)
  {
    if (!(request_data.economicName in __cache[storage_name]))
      return null

    let hash = hashLbRequest(request_data)
    if (!(hash in __cache[storage_name][request_data.economicName]))
      return null

    if (::dagor.getCurTime() - __cache[storage_name][request_data.economicName][hash].timestamp > cashLifetime)
    {
      __cache[storage_name][request_data.economicName].rawdelete(hash)
      return null
    }
    return __cache[storage_name][request_data.economicName][hash].data
  }

  function getMainLbRequest(event)
  {
    let newRequest = {}
    foreach (name, item in shortLbrequest)
      newRequest[name] <- (name in this) ? this[name] : item

    if (!event)
      return newRequest

    newRequest.economicName <- ::events.getEventEconomicName(event)
    newRequest.tournament <- getTblValue("tournament", event, false)
    newRequest.tournament_mode <- ::events.getEventTournamentMode(event)
    newRequest.forClans <- isClanLeaderboard(event)

    let sortLeaderboard = getTblValue("sort_leaderboard", event, null)
    let shortRow = (sortLeaderboard != null)
                      ? ::g_lb_category.getTypeByField(sortLeaderboard)
                      : ::events.getTableConfigShortRowByEvent(event)
    newRequest.inverse = shortRow.inverse
    newRequest.lbField = shortRow.field

    return newRequest
  }

  function isClanLbRequest(requestData)
  {
    return getTblValue("forClans", requestData, false)
  }

  function validateRequestData(requestData)
  {
    foreach(name, field in defaultRequest)
      if(!(name in requestData))
        requestData[name] <- field
    return requestData
  }

  function compareRequests(req1, req2)
  {
    foreach(name, field in defaultRequest)
    {
      if ((name in req1) != (name in req2))
        return false
      if (!(name in req1)) //no name in both req
        continue
      if (req1[name] != req2[name])
        return false
    }
    return true
  }

  function dropLbCache(event)
  {
    let economicName = ::events.getEventEconomicName(event)

    if (economicName in __cache.leaderboards)
      __cache.leaderboards.rawdelete(economicName)

    if (economicName in __cache.selfRow)
      __cache.selfRow.rawdelete(economicName)

    ::broadcastEvent("EventlbDataRenewed", {eventId = event.name})
  }

  function getLbDataFromBlk(blk, requestData)
  {
    let lbRows = lbBlkToArray(blk)
    if (isClanLbRequest(requestData))
      foreach(lbRow in lbRows)
        postProcessClanLbRow(lbRow)

    let superiorityBattlesThreshold = blk.getInt("superiorityBattlesThreshold", 0)
    if (superiorityBattlesThreshold > 0)
      foreach(lbRow in lbRows)
        lbRow["superiorityBattlesThreshold"] <- superiorityBattlesThreshold

    let res = {}
    res["rows"] <- lbRows
    res["updateTime"] <- blk.getStr("lastUpdateTime", "0").tointeger()
    return res
  }

  function getSelfRowDataFromBlk(blk, requestData)
  {
    let res = lbBlkToArray(blk)
    if (isClanLbRequest(requestData))
      foreach(lbRow in res)
        postProcessClanLbRow(lbRow)
    return res
  }

  function lbBlkToArray(blk)
  {
    let res = []
    foreach (row in blk % "event")
    {
      let table = {}
      for(local i = 0; i < row.paramCount(); i++)
        table[row.getParamName(i)] <- row.getParamValue(i)
      res.append(table)
    }
    return res
  }

  function isClanLeaderboard(event)
  {
    if (!getTblValue("tournament", event, false))
      return ::events.isEventForClan(event)
    return ::events.getEventTournamentMode(event) == GAME_EVENT_TYPE.TM_ELO_GROUP
  }

  function postProcessClanLbRow(lbRow)
  {
    //check clan name for tag.
    //new leaderboards name param is in forma  "<tag> <name>"
    //old only "<name>"
    //but even with old leaderboards we need something to write in tag for short lb
    let name = getTblValue("name", lbRow)
    if (!::u.isString(name) || !name.len())
      return

    local searchIdx = -1
    for(local skipSpaces = 0; skipSpaces >= 0; skipSpaces--)
    {
      searchIdx = name.indexof(" ", searchIdx + 1)
      if (searchIdx == null) //no tag at all
      {
        lbRow.tag <- name
        break
      }
      //tag dont have spaces, but it decoaration can be double space
      if (searchIdx == 0)
      {
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
    __cache.leaderboards.clear()
    __cache.selfRow.clear()
  }
}
