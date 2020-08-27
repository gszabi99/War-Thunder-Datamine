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
    rowsInPage = ::max(EVENTS_SHORT_LB_REQUIRED_PARTICIPANTS_TO_SHOW, EVENTS_SHORT_LB_VISIBLE_ROWS)
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

    local cachedData = getCachedLbResult(requestData, "leaderboards")

    //trigging callback if data is lready here
    if (cachedData)
    {
      if (context)
        callback.call(context, cachedData)
      else
        callback(cachedData)
      return
    }

    requestData.callBack <- ::Callback(callback, context)
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

    local cachedData = getCachedLbResult(requestData, "selfRow")

    //trigging callback if data is lready here
    if (cachedData)
    {
      if (context)
        callback.call(context, cachedData)
      else
        callback(cachedData)
      return
    }

    requestData.callBack <- ::Callback(callback, context)
    updateEventLbSelfRow(requestData, id)
  }

  function updateEventLbInternal(requestData, id, requestFunc, handleFunc)
  {
    local requestAction = ::Callback(function () {
      local taskId = requestFunc(requestData)
      if (taskId < 0)
        return

      canRequestEventLb = false
      ::add_bg_task_cb(taskId, ::Callback(function() {
        handleFunc(requestData, id)

        if (leaderboardsRequestStack.len())
          leaderboardsRequestStack.remove(0).fn()
        else
          canRequestEventLb = true
      }, this))
    }, this)

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
  function requestUpdateEventLb(requestData)
  {
    local event = ::events.getEvent(requestData.economicName)
    if (requestData.tournament || ::events.isRaceEvent(event))
      return ::events_req_leaderboard_tm(requestData.economicName,
                                         requestData.lbField,
                                         requestData.pos,
                                         requestData.rowsInPage,
                                         requestData.inverse,
                                         requestData.forClans,
                                         requestData.tournament_mode)
    else
      return ::events_req_leaderboard(requestData.economicName,
                                      requestData.lbField,
                                      requestData.pos,
                                      requestData.rowsInPage,
                                      requestData.inverse,
                                      requestData.forClans)
  }

  /**
   * to request persoanl data for clan tournaments (TM_ELO_GROUP)
   * need to override tournament_mode by TM_ELO_GROUP_DETAIL
   */
  function requestEventLbSelfRow(requestData)
  {
    local event = ::events.getEvent(requestData.economicName)
    if (requestData.tournament || ::events.isRaceEvent(event))
      return events_req_leaderboard_position_tm(requestData.economicName,
                                                  requestData.lbField,
                                                  requestData.inverse,
                                                  requestData.forClans,
                                                  requestData.tournament_mode)
    else
      return events_req_leaderboard_position(requestData.economicName,
                                               requestData.lbField,
                                               requestData.inverse,
                                               requestData.forClans)
  }

  /**
   * Function generates hash string from leaderboard request data
   */
  function hashLbRequest(request_data)
  {
    local res = ""
    res += request_data.lbField
    res += ::getTblValue("rowsInPage", request_data, "")
    res += ::getTblValue("inverse", request_data, false)
    res += ::getTblValue("rowsInPage", request_data, "")
    res += ::getTblValue("pos", request_data, "")
    res += ::getTblValue("tournament_mode", request_data, "")
    return res
  }

  function handleLbRequest(requestData, id)
  {

    local blData = getLbDataFromBlk(::events_get_leaderboard_blk(), requestData)

    if (!(requestData.economicName in __cache.leaderboards))
      __cache.leaderboards[requestData.economicName] <- {}

    __cache.leaderboards[requestData.economicName][hashLbRequest(requestData)] <- {
      data = blData
      timestamp = ::dagor.getCurTime()
    }

    if (id)
      foreach (request in leaderboardsRequestStack)
        if (request.id == id)
          return

    if ("callBack" in requestData)
      if ("handler" in requestData)
        requestData.callBack.call(requestData.handler, blData)
      else
        requestData.callBack(blData)
  }

  function handleLbSelfRowRequest(requestData, id)
  {
    local blData = getSelfRowDataFromBlk(::events_get_leaderboard_blk(), requestData)

    if (!(requestData.economicName in __cache.selfRow))
      __cache.selfRow[requestData.economicName] <- {}

    __cache.selfRow[requestData.economicName][hashLbRequest(requestData)] <- {
      data = blData
      timestamp = ::dagor.getCurTime()
    }

    if (id)
      foreach (request in leaderboardsRequestStack)
        if (request.id == id) return

    if ("callBack" in requestData)
      if ("handler" in requestData)
        requestData.callBack.call(requestData.handler, blData)
      else
        requestData.callBack(blData)
  }

  /**
   * Checks cached response and if response exists and fresh returns it.
   * Otherwise returns null.
   */
  function getCachedLbResult(request_data, storage_name)
  {
    if (!(request_data.economicName in __cache[storage_name]))
      return null

    local hash = hashLbRequest(request_data)
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
    local newRequest = {}
    foreach (name, item in shortLbrequest)
      newRequest[name] <- (name in this) ? this[name] : item

    if (!event)
      return newRequest

    newRequest.economicName <- events.getEventEconomicName(event)
    newRequest.tournament <- ::getTblValue("tournament", event, false)
    newRequest.tournament_mode <- ::events.getEventTournamentMode(event)
    newRequest.forClans <- isClanLeaderboard(event)

    local sortLeaderboard = ::getTblValue("sort_leaderboard", event, null)
    local shortRow = (sortLeaderboard != null)
                      ? ::g_lb_category.getTypeByField(sortLeaderboard)
                      : ::events.getTableConfigShortRowByEvent(event)
    newRequest.inverse = shortRow.inverse
    newRequest.lbField = shortRow.field

    return newRequest
  }

  function isClanLbRequest(requestData)
  {
    return ::getTblValue("forClans", requestData, false)
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
    local economicName = ::events.getEventEconomicName(event)

    if (economicName in __cache.leaderboards)
      __cache.leaderboards.rawdelete(economicName)

    if (economicName in __cache.selfRow)
      __cache.selfRow.rawdelete(economicName)

    ::broadcastEvent("EventlbDataRenewed", {eventId = event.name})
  }

  function getLbDataFromBlk(blk, requestData)
  {
    local lbRows = lbBlkToArray(blk)
    if (isClanLbRequest(requestData))
      foreach(lbRow in lbRows)
        postProcessClanLbRow(lbRow)

    local superiorityBattlesThreshold = blk.getInt("superiorityBattlesThreshold", 0)
    if (superiorityBattlesThreshold > 0)
      foreach(lbRow in lbRows)
        lbRow["superiorityBattlesThreshold"] <- superiorityBattlesThreshold

    local res = {}
    res["rows"] <- lbRows
    res["updateTime"] <- blk.getStr("lastUpdateTime", "0").tointeger()
    return res
  }

  function getSelfRowDataFromBlk(blk, requestData)
  {
    local res = lbBlkToArray(blk)
    if (isClanLbRequest(requestData))
      foreach(lbRow in res)
        postProcessClanLbRow(lbRow)
    return res
  }

  function lbBlkToArray(blk)
  {
    local res = []
    foreach (row in blk % "event")
    {
      local table = {}
      for(local i = 0; i < row.paramCount(); i++)
        table[row.getParamName(i)] <- row.getParamValue(i)
      res.append(table)
    }
    return res
  }

  function isClanLeaderboard(event)
  {
    if (!::getTblValue("tournament", event, false))
      return ::events.isEventForClan(event)
    return ::events.getEventTournamentMode(event) == GAME_EVENT_TYPE.TM_ELO_GROUP
  }

  function postProcessClanLbRow(lbRow)
  {
    //check clan name for tag.
    //new leaderboards name param is in forma  "<tag> <name>"
    //old only "<name>"
    //but even with old leaderboards we need something to write in tag for short lb
    local name = ::getTblValue("name", lbRow)
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
}
