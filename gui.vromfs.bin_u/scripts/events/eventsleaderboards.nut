from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { get_time_msec } = require("dagor.time")
let { requestEventLeaderboardData, requestEventLeaderboardSelfRow,
  requestCustomEventLeaderboardData, convertLeaderboardData
} = require("%scripts/leaderboard/requestLeaderboardData.nut")

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
  function requestLeaderboard(requestData, id, callback, context)
  {
    if (type(id) == "function")
    {
      context  = callback
      callback = id
      id = null
    }

    requestData = this.validateRequestData(requestData)

    let cachedData = this.getCachedLbResult(requestData, "leaderboards")

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
    this.updateEventLb(requestData, id)
  }

  /**
   * Function requests self leaderboard row asynchronously and puts result
   * as argument to callback function
   */
  function requestSelfRow(requestData, id, callback, context)
  {
    if (type(id) == "function")
    {
      context  = callback
      callback = id
      id = null
    }

    requestData = this.validateRequestData(requestData)

    let cachedData = this.getCachedLbResult(requestData, "selfRow")

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
    this.updateEventLbSelfRow(requestData, id)
  }

  function updateEventLbInternal(requestData, id, requestFunc, handleFunc)
  {
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
      )}, this)

    if (this.canRequestEventLb)
      return requestAction()

    if (id)
      foreach (index, request in this.leaderboardsRequestStack)
        if (id == request)
          this.leaderboardsRequestStack.remove(index)

    this.leaderboardsRequestStack.append({fn = requestAction, id = id})
  }

  function updateEventLb(requestData, id)
  {
    this.updateEventLbInternal(requestData, id, this.requestUpdateEventLb, this.handleLbRequest)
  }

  function updateEventLbSelfRow(requestData, id)
  {
    this.updateEventLbInternal(requestData, id, this.requestEventLbSelfRow, this.handleLbSelfRowRequest)
  }

  /**
   * To request persoanl data for clan tournaments (TM_ELO_GROUP)
   * need to override tournament_mode by TM_ELO_GROUP_DETAIL
   */
  function requestUpdateEventLb(requestData, onSuccessCb, onErrorCb)
  {
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
  function requestEventLbSelfRow(requestData, onSuccessCb, onErrorCb)
  {
    if (requestData.lbTable == null) {
      requestEventLeaderboardSelfRow(requestData, onSuccessCb, onErrorCb)
      return
    }

    requestCustomEventLeaderboardData(
      requestData.__merge({
        pos = null
        rowsInPage = 0
        userId = ::my_user_id_int64
      }),
      onSuccessCb, onErrorCb)
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

  function handleLbSelfRowRequest(requestData, id, requestResult)
  {
    let lbData = this.getSelfRowDataFromBlk(requestResult, requestData)

    if (!(requestData.economicName in this.__cache.selfRow))
      this.__cache.selfRow[requestData.economicName] <- {}

    this.__cache.selfRow[requestData.economicName][this.hashLbRequest(requestData)] <- {
      data = lbData
      timestamp = get_time_msec()
    }

    if (id)
      foreach (request in this.leaderboardsRequestStack)
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
    if (!(request_data.economicName in this.__cache[storage_name]))
      return null

    let hash = this.hashLbRequest(request_data)
    if (!(hash in this.__cache[storage_name][request_data.economicName]))
      return null

    if (get_time_msec() - this.__cache[storage_name][request_data.economicName][hash].timestamp > this.cashLifetime)
    {
      this.__cache[storage_name][request_data.economicName].rawdelete(hash)
      return null
    }
    return this.__cache[storage_name][request_data.economicName][hash].data
  }

  function getMainLbRequest(event)
  {
    let newRequest = {}
    foreach (name, item in this.shortLbrequest)
      newRequest[name] <- (name in this) ? this[name] : item

    if (!event)
      return newRequest

    newRequest.economicName <- ::events.getEventEconomicName(event)
    newRequest.tournament <- getTblValue("tournament", event, false)
    newRequest.tournament_mode <- ::events.getEventTournamentMode(event)
    newRequest.forClans <- this.isClanLeaderboard(event)

    let sortLeaderboard = getTblValue("sort_leaderboard", event, null)
    let shortRow = (sortLeaderboard != null)
                      ? ::g_lb_category.getTypeByField(sortLeaderboard)
                      : ::events.getTableConfigShortRowByEvent(event)
    newRequest.inverse = shortRow.inverse
    newRequest.lbField = shortRow.field
    if (event?.leaderboardEventTable ?? false) {
      newRequest.lbTable = event.leaderboardEventTable
      newRequest.lbMode = "stats"
      newRequest.lbField = event?.leaderboardEventBestStat ?? shortRow.field
    }

    return newRequest
  }

  function isClanLbRequest(requestData)
  {
    return getTblValue("forClans", requestData, false)
  }

  function validateRequestData(requestData)
  {
    foreach(name, field in this.defaultRequest)
      if(!(name in requestData))
        requestData[name] <- field
    return requestData
  }

  function compareRequests(req1, req2)
  {
    foreach(name, _field in this.defaultRequest)
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

    if (economicName in this.__cache.leaderboards)
      this.__cache.leaderboards.rawdelete(economicName)

    if (economicName in this.__cache.selfRow)
      this.__cache.selfRow.rawdelete(economicName)

    ::broadcastEvent("EventlbDataRenewed", {eventId = event.name})
  }

  function getLbDataFromBlk(blk, requestData)
  {
    let lbRows = this.lbBlkToArray(blk)
    if (this.isClanLbRequest(requestData))
      foreach(lbRow in lbRows)
        this.postProcessClanLbRow(lbRow)

    let superiorityBattlesThreshold = blk?.superiorityBattlesThreshold ?? 0
    if (superiorityBattlesThreshold > 0)
      foreach(lbRow in lbRows)
        lbRow["superiorityBattlesThreshold"] <- superiorityBattlesThreshold

    let res = {
      rows = lbRows
      updateTime = (blk?.lastUpdateTime ?? "0").tointeger()
    }
    return res
  }

  function getSelfRowDataFromBlk(blk, requestData)
  {
    let res = this.lbBlkToArray(blk)
    if (this.isClanLbRequest(requestData))
      foreach(lbRow in res)
        this.postProcessClanLbRow(lbRow)
    return res
  }

  function lbBlkToArray(blk)
  {
    if (type(blk) == "table") {
      return convertLeaderboardData(blk).rows
    }
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
    this.__cache.leaderboards.clear()
    this.__cache.selfRow.clear()
  }
}
