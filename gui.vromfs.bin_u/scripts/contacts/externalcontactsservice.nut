from "%scripts/dagui_natives.nut" import xbox_find_friends_result, ps4_find_friends_result, xbox_find_friends, ps4_find_friends
from "%scripts/dagui_library.nut" import *

const MAX_UNKNOWN_IDS_PEER_REQUEST = 100
let DataBlock = require("DataBlock")
let { convertBlk } = require("%sqstd/datablock.nut")
let { addTask } = require("%scripts/tasker.nut")
let { steam_find_friends, steam_find_friends_result } = require("steam_wt")

local requestUnknownXboxIds = function(_playersList, _knownUsers, _cb) {} 
requestUnknownXboxIds = function(playersList, knownUsers, cb) {
  if (!playersList.len()) {
    
    
    
    
    
    
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
  if (!playersList.len()) {
    cb(knownUsers)
    return
  }

  let self = callee()
  let cutIndex = min(playersList.len(), MAX_UNKNOWN_IDS_PEER_REQUEST)
  let requestList = playersList.slice(0, cutIndex)
  let leftList = playersList.slice(cutIndex)

  let taskId = steam_find_friends(requestList.map(@(v) v.tostring()))
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