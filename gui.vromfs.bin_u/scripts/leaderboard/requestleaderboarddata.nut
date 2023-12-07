from "%scripts/dagui_library.nut" import *
from "%scripts/leaderboard/leaderboardConsts.nut" import LEADERBOARD_VALUE_TOTAL
from "%scripts/events/eventsConsts.nut" import GAME_EVENT_TYPE

let u = require("%sqStdLibs/helpers/u.nut")
let ww_leaderboard = require("ww_leaderboard")
let { getSeparateLeaderboardPlatformName } = require("%scripts/social/crossplay.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let DataBlock = require("DataBlock")
let { charRequestBlk } = require("%scripts/tasker.nut")
let { isRaceEvent } = require("%scripts/events/eventInfo.nut")

const APP_ID_CUSTOM_LEADERBOARD = 1231
/*
dataParams = {
  gameMode = ""
  table    = day && day > 0 ? "day" + day : "season"
  start    = 1  // start position lb request
  count    = 0  // count of records
  category = lbCategoryTypes.WW_EVENTS_PERSONAL_ELO.field // sort field parametr
  platformFilter = "" //"ps4" for ps4 only players
}
headersParams = {
  userId = -1 //optional parameter. Equal to user id for user leaderboard and clan id for clan leaderboard
  appId = -1
} */

let function requestLeaderboardData(dataParams, headers, cb) {
  let requestData = {
    add_token = true
    action = ("userId" in headers) ? "ano_get_leaderboard_json" : "cln_get_leaderboard_json" //Need use ano_get_leaderboard_json for request with userId
    headers
    data = {
      valueType   = LEADERBOARD_VALUE_TOTAL
      resolveNick = true
    }.__update(dataParams)
  }

  ww_leaderboard.request(requestData, cb)
}

let function requestEventLeaderboardData(requestData, onSuccessCb, onErrorCb) {
  let blk = DataBlock()
  blk.event = requestData.economicName
  blk.sortField = requestData.lbField
  blk.start = requestData.pos
  blk.count = requestData.rowsInPage
  blk.inverse = requestData.inverse
  blk.clan = requestData.forClans
  blk.tournamentMode = GAME_EVENT_TYPE.TM_NONE
  blk.version = 1
  blk.targetPlatformFilter = getSeparateLeaderboardPlatformName()

  if (blk.start == null || blk.start < 0) {
    let event = blk.event  // warning disable: -declared-never-used
    let start = blk.start  // warning disable: -declared-never-used
    let count = blk.count  // warning disable: -declared-never-used
    script_net_assert_once("event_leaderboard__invalid_start", "Event leaderboard: Invalid start")
    log($"Error: Event '{event}': Invalid leaderboard start={start} (count={count})")

    blk.start = 0
  }
  if (blk.count == null || blk.count <= 0) {
    let event = blk.event  // warning disable: -declared-never-used
    let count = blk.count  // warning disable: -declared-never-used
    let start = blk.start  // warning disable: -declared-never-used
    script_net_assert_once("event_leaderboard__invalid_count", "Event leaderboard: Invalid count")
    log($"Error: Event '{event}': Invalid leaderboard count={count} (start={start})")

    blk.count = 49  // unusual value indicate problem
  }

  let event = ::events.getEvent(requestData.economicName)
  if (requestData.tournament || isRaceEvent(event))
    blk.tournamentMode = requestData.tournament_mode

  return charRequestBlk("cln_get_events_leaderboard", blk, null, onSuccessCb, onErrorCb)
}

let function requestEventLeaderboardSelfRow(requestData, onSuccessCb, onErrorCb) {
  let blk = DataBlock()
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
  if (requestData.tournament || isRaceEvent(event))
    blk.tournamentMode = requestData.tournament_mode

  return charRequestBlk("cln_get_events_leaderboard", blk, null, onSuccessCb, onErrorCb)
}

let function requestCustomEventLeaderboardData(requestData, onSuccessCb, onErrorCb) {
  let { pos, rowsInPage, lbField, lbTable, lbMode, userId = null } = requestData
  let function resultCb(result) {
    if (result?.error) {
      onErrorCb(result.error)
      return
    }
    onSuccessCb(result)
  }
  let dataParams = {
    gameMode = lbMode
    table    = lbTable
    start    = pos
    count    = rowsInPage
    category = lbField
    platformFilter = getSeparateLeaderboardPlatformName()
  }
  let headers = {
    appId = APP_ID_CUSTOM_LEADERBOARD
  }
  if (userId != null)
    headers.userId <- userId
  requestLeaderboardData(dataParams, headers, resultCb)
}

let leaderboardValueFactors = {
  rating = 0.0001
  operation_winrate = 0.0001
  battle_winrate = 0.0001
  avg_place = 0.0001
  avg_score = 0.0001
}
let leaderboardKeyCorrection = {
  idx = "pos"
  playerAKills = "air_kills_player"
  playerGKills = "ground_kills_player"
  playerNKills = "naval_kills_player"
  aiAKills = "air_kills_ai"
  aiGKills = "ground_kills_ai"
  aiNKills = "naval_kills_ai"
}

let function convertLeaderboardData(result, applyLocalisationToName = false) {
  let list = []
  foreach (rowId, rowData in result) {
    if (type(rowData) != "table")
      continue

    let lbData = {
      name = applyLocalisationToName ? loc(rowId) : rowId
    }
    foreach (columnId, columnData in rowData) {
      let key = leaderboardKeyCorrection?[columnId] ?? columnId
      if (key in lbData && u.isEmpty(columnData))
        continue

      let valueFactor = leaderboardValueFactors?[columnId]
      local value = type(columnData) == "table"
        ? columnData?.value_total
        : columnId == "name" && applyLocalisationToName
            ? loc(columnData)
            : columnData
      if (valueFactor && value)
        value = value * valueFactor

      lbData[key] <- value
    }
    list.append(lbData)
  }
  list.sort(@(a, b) a.pos < 0 <=> b.pos < 0 || a.pos <=> b.pos)

  return { rows = list }
}

return {
  APP_ID_CUSTOM_LEADERBOARD
  requestLeaderboardData
  requestEventLeaderboardData
  requestEventLeaderboardSelfRow
  requestCustomEventLeaderboardData
  convertLeaderboardData
}
