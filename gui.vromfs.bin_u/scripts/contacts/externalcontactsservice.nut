local MAX_UNKNOWN_IDS_PEER_REQUEST = 100

local requestUnknownXboxIds = function(playersList, knownUsers, cb) {} //forward declaration
requestUnknownXboxIds = function(playersList, knownUsers, cb)
{
  if (!playersList.len())
  {
    //Need to update contacts list, because empty list - means no users,
    //and returns -1, for not to send empty array to char.
    //So, contacts list must be cleared in this case from xbox users.
    //Send knownUsers if we already have all required data,
    //playersList is not empty and no need to
    //request char-server for known data.
    cb(knownUsers)
    return
  }

  local cutIndex = ::min(playersList.len(), MAX_UNKNOWN_IDS_PEER_REQUEST)
  local requestList = playersList.slice(0, cutIndex)
  local leftList = playersList.slice(cutIndex)

  local taskId = ::xbox_find_friends(requestList)
  ::g_tasker.addTask(taskId, null, function() {
      local blk = ::DataBlock()
      blk = ::xbox_find_friends_result()

      local table = ::buildTableFromBlk(blk)
      table.__update(knownUsers)

      requestUnknownXboxIds(leftList, table, cb)
    }.bindenv(this)
  )
}

local function requestUnknownPSNIds(playersList, knownUsers, cb) {}
requestUnknownPSNIds = function(playersList, knownUsers, cb) {
  if (!playersList.len()) {
    cb(knownUsers)
    return
  }

  local cutIndex = ::min(playersList.len(), MAX_UNKNOWN_IDS_PEER_REQUEST)
  local requestList = playersList.slice(0, cutIndex)
  local leftList = playersList.slice(cutIndex)

  local taskId = ::ps4_find_friends(requestList)
  ::g_tasker.addTask(taskId, null, function() {
    local blk = ::DataBlock()
    blk = ::ps4_find_friends_result()

    local table = ::buildTableFromBlk(blk)
    table.__update(knownUsers)

    requestUnknownPSNIds(leftList, table, cb)
  }.bindenv(this))
}

return {
  requestUnknownXboxIds = requestUnknownXboxIds
  requestUnknownPSNIds = requestUnknownPSNIds
}