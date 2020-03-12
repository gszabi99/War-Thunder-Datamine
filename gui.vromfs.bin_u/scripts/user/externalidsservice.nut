local updateExternalIDsTable = function(request)
{
  local blk = ::DataBlock()
  ::get_player_external_ids(blk)

  local eIDtable = blk?.externalIds
  if (!eIDtable)
    return

  local table = {}
//STEAM
  if (eIDtable?[::EPL_STEAM]?.id && ::steam_is_running())
    table.steamName <- ::steam_get_name_by_id(blk.externalIds[::EPL_STEAM].id)

//FACEBOOK
  if (eIDtable?[::EPL_FACEBOOK]?.id && ::facebook_is_logged_in() && ::no_dump_facebook_friends)
  {
    local fId = eIDtable[::EPL_FACEBOOK].id
    if (fId in ::no_dump_facebook_friends)
      table.facebookName <- ::no_dump_facebook_friends[fId]
  }

//PLAYSTATION NETWORK
  if (eIDtable?[::EPL_PSN]?.id)
    table.psnName <- eIDtable[::EPL_PSN].id

//XBOX ONE
  if (eIDtable?[::EPL_XBOXONE]?.id)
    table.xboxId <- eIDtable[::EPL_XBOXONE].id

  ::broadcastEvent("UpdateExternalsIDs", {externalIds = table, request = request})
}

local requestExternalIDsFromServer = function(taskId, request, taskOptions)
{
  ::g_tasker.addTask(taskId, taskOptions, @() updateExternalIDsTable(request))
}

local function reqPlayerExternalIDsByPlayerId(playerId, taskOptions = {}, afterSuccessUpdateFunc = null)
{
  local taskId = ::req_player_external_ids_by_player_id(playerId)
  requestExternalIDsFromServer(taskId, {playerId = playerId, afterSuccessUpdateFunc = afterSuccessUpdateFunc}, taskOptions)
}

local function reqPlayerExternalIDsByUserId(uid, taskOptions = {}, afterSuccessUpdateFunc = null)
{
  local taskId = ::req_player_external_ids(uid)
  requestExternalIDsFromServer(taskId, {uid = uid, afterSuccessUpdateFunc = afterSuccessUpdateFunc}, taskOptions)
}

local function getSelfExternalIds()
{
  local table = {}

//STEAM
  local steamId = ::get_my_external_id(::EPL_STEAM)
  if (steamId != null)
    table.steamName <- ::steam_get_name_by_id(steamId)

//FACEBOOK
  if (::facebook_is_logged_in() && ::no_dump_facebook_friends)
  {
    local fId = ::get_my_external_id(::EPL_FACEBOOK)
    if (fId in ::no_dump_facebook_friends)
      table.facebookName <- ::no_dump_facebook_friends[fId]
  }

//PLAYSTATION NETWORK
  local psnId = ::get_my_external_id(::EPL_PSN)
  if (psnId != null)
    table.psnName <- psnId

//XBOX ONE
  local xboxId = ::get_my_external_id(::EPL_XBOXONE)
  if (xboxId != null)
    table.xboxId <- xboxId

  return table
}

return {
  reqPlayerExternalIDsByPlayerId = reqPlayerExternalIDsByPlayerId
  reqPlayerExternalIDsByUserId = reqPlayerExternalIDsByUserId
  getSelfExternalIds = getSelfExternalIds
}