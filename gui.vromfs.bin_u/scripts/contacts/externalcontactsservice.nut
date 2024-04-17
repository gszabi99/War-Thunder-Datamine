from "%scripts/dagui_natives.nut" import xbox_find_friends_result, ps4_find_friends_result, xbox_find_friends, ps4_find_friends
from "%scripts/dagui_library.nut" import *

const MAX_UNKNOWN_IDS_PEER_REQUEST = 100
let DataBlock = require("DataBlock")
let { convertBlk } = require("%sqstd/datablock.nut")
let { addTask } = require("%scripts/tasker.nut")
let { steam_find_friends_for_compatibility = null, steam_find_friends_result } = require("steam_wt")

local requestUnknownXboxIds = function(_playersList, _knownUsers, _cb) {} //forward declaration
requestUnknownXboxIds = function(playersList, knownUsers, cb) {
  if (!playersList.len()) {
    //Need to update contacts list, because empty list - means no users,
    //and returns -1, for not to send empty array to char.
    //So, contacts list must be cleared in this case from xbox users.
    //Send knownUsers if we already have all required data,
    //playersList is not empty and no need to
    //request char-server for known data.
    cb(knownUsers)
    return
  }

  let cutIndex = min(playersList.len(), MAX_UNKNOWN_IDS_PEER_REQUEST)
  let requestList = playersList.slice(0, cutIndex)
  let leftList = playersList.slice(cutIndex)

  let taskId = xbox_find_friends(requestList)
  addTask(taskId, null, function() {
      local blk = DataBlock()
      blk = xbox_find_friends_result()

      let table = convertBlk(blk)
      table.__update(knownUsers)

      requestUnknownXboxIds(leftList, table, cb)
    }
  )
}

function requestUnknownPSNIds(playersList, knownUsers, cb) {
  if (!playersList.len()) {
    cb(knownUsers)
    return
  }

  let self = callee()
  let cutIndex = min(playersList.len(), MAX_UNKNOWN_IDS_PEER_REQUEST)
  let requestList = playersList.slice(0, cutIndex)
  let leftList = playersList.slice(cutIndex)

  let taskId = ps4_find_friends(requestList)
  addTask(taskId, null, function() {
    local blk = DataBlock()
    blk = ps4_find_friends_result()

    let table = convertBlk(blk)
    table.__update(knownUsers)

    self(leftList, table, cb)
  })
}

function requestUnknownSteamIds(playersList, knownUsers, cb) {
  if (!playersList.len() || steam_find_friends_for_compatibility == null) {
    cb(knownUsers)
    return
  }

  let self = callee()
  let cutIndex = min(playersList.len(), MAX_UNKNOWN_IDS_PEER_REQUEST)
  let requestList = playersList.slice(0, cutIndex)
  let leftList = playersList.slice(cutIndex)

  let taskId = steam_find_friends_for_compatibility(requestList.map(@(v) v.tostring()))
  let function taskCb() {
    local blk = DataBlock()
    blk = steam_find_friends_result()

    let table = convertBlk(blk)
    table.__update(knownUsers)

    self(leftList, table, cb)
  }
  addTask(taskId, null, taskCb, taskCb)
}

return {
  requestUnknownXboxIds = requestUnknownXboxIds
  requestUnknownPSNIds = requestUnknownPSNIds
  requestUnknownSteamIds
}