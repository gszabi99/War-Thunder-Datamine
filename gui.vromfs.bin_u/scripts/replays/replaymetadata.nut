from "%scripts/dagui_natives.nut" import mpstat_get_sort_func
from "%scripts/dagui_library.nut" import *
from "%scripts/teamsConsts.nut" import Team

let { INVALID_SQUAD_ID } = require("matching.errors")
let u = require("%sqStdLibs/helpers/u.nut")
let { split_by_chars } = require("string")
let datablockConverter = require("%scripts/utils/datablockConverter.nut")
let { get_replay_info, is_replay_playing } = require("replays")
let DataBlock = require("DataBlock")
let { get_mplayers_list, GET_MPLAYERS_LIST } = require("mission")
let { g_mplayer_param_type } = require("%scripts/mplayerParamType.nut")
let { isEqualSquadId } = require("%scripts/squads/squadState.nut")
let { getSessionLobbyPlayersInfo } = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { setCustomPlayersInfo } = require("%scripts/matchingRooms/sessionLobbyManager.nut")

local curReplayPlayersMatchingInfo = null

function buildReplayMpTable(replayPath) {
  let res = []

  let replayInfo = get_replay_info(replayPath)
  let commentsBlk = replayInfo?.comments
  if (!commentsBlk)
    return res
  let playersBlkList = commentsBlk % "player"
  if (!playersBlkList.len())
    return res

  let gameType = replayInfo?.gameType ?? 0
  let authorUserId = to_integer_safe(commentsBlk?.authorUserId ?? "", -1000, false)
  let authorBlk = u.search(playersBlkList, @(v) to_integer_safe(v?.userId ?? "", 0, false) == authorUserId)
  let authorSquadId = authorBlk?.squadId ?? INVALID_SQUAD_ID

  foreach (b in playersBlkList) {
    let userId = to_integer_safe(b?.userId ?? "", 0, false)
    if (userId == 0)
      continue
    if ((b?.name ?? "") == "" && (b?.nick ?? "") == "")
      continue

    let mplayer = {
      userId = userId
      name = b?.name ?? ""
      clanTag = b?.clanTag ?? ""
      team = b?.team ?? Team.none
      state = PLAYER_HAS_LEAVED_GAME
      isLocal = userId == authorUserId
      isInHeroSquad = isEqualSquadId(b?.squadId, authorSquadId)
      isBot = userId < 0
      squadId = b?.squadId ?? INVALID_SQUAD_ID
      autoSquad = b?.autoSquad ?? true
      kills = b?.kills ?? b?.airKills ?? 0
    }

    if (mplayer.name == "") {
      let parts = split_by_chars(b?.nick ?? "", " ")
      let hasClanTag = parts.len() == 2
      mplayer.clanTag = hasClanTag ? parts[0] : ""
      mplayer.name    = hasClanTag ? parts[1] : parts[0]
    }

    if (mplayer?.isBot && mplayer?.name.indexof("/") != null)
      mplayer.name = loc(mplayer.name)

    foreach (p in g_mplayer_param_type.types)
      if (!(p.id in mplayer) && p != g_mplayer_param_type.UNKNOWN)
        mplayer[p.id] <- b?[p.id] ?? p?.defVal

    res.append(mplayer)
  }

  res.sort(mpstat_get_sort_func(gameType))
  return res
}

function saveReplayScriptCommentsBlk(blk) {
  blk.uiScriptsData = DataBlock()
  blk.uiScriptsData.playersInfo = datablockConverter.dataToBlk(getSessionLobbyPlayersInfo())
}

function updateReplayMatchingPlayersInfoFromMplayerList() {
  if (!is_replay_playing())
    return

  let curPlayersInfo = getSessionLobbyPlayersInfo()
  if (curPlayersInfo.len() != 0 && !(curPlayersInfo.findvalue(@(_) true)?.isFromMplayersList ?? false))
    return
  let mplayersList = get_mplayers_list(GET_MPLAYERS_LIST, true).filter(@(v) !v?.isBot && v?.userId != null)
  if (curPlayersInfo.len() == mplayersList.len())
    return
  let playersInfo = {}
  foreach (mplayer in mplayersList) {
    let { userId } = mplayer
    let userIdInt = userId.tointeger()
    playersInfo[userIdInt] <- {
      id = userIdInt
      team = mplayer?.team
      name = mplayer?.name
      clanTag = mplayer?.clanTag
      squad = mplayer?.squadId ?? INVALID_SQUAD_ID
      auto_squad = !!(mplayer?.autoSquad ?? true)
      crafts_info = curReplayPlayersMatchingInfo?[userId].crafts_info
      mrank = curReplayPlayersMatchingInfo?[userId]?.mrank ?? 0
      isFromMplayersList = true
    }
  }

  setCustomPlayersInfo(playersInfo)
}

function restoreReplayScriptCommentsBlk(replayPath) {
  
  let commentsBlk = get_replay_info(replayPath)?.comments
  let playersInfo = datablockConverter.blkToData(commentsBlk?.uiScriptsData.playersInfo) ?? {}
  curReplayPlayersMatchingInfo = datablockConverter.blkToData(commentsBlk?.matchingInfo) ?? {}
  if (playersInfo.len() > 0) {
    setCustomPlayersInfo(playersInfo)
    return
  }

  
  updateReplayMatchingPlayersInfoFromMplayerList()
}


getroottable()["save_replay_script_comments_blk"] <- @(blk) saveReplayScriptCommentsBlk(blk)

return {
  buildReplayMpTable
  saveReplayScriptCommentsBlk
  restoreReplayScriptCommentsBlk
  updateReplayMatchingPlayersInfoFromMplayerList
}
