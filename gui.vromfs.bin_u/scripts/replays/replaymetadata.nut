//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { split_by_chars } = require("string")
let datablockConverter = require("%scripts/utils/datablockConverter.nut")
let { get_replay_info } = require("replays")
let DataBlock = require("DataBlock")

let buildReplayMpTable = function(replayPath) {
  let res = []

  let replayInfo = get_replay_info(replayPath)
  let commentsBlk = replayInfo?.comments
  if (!commentsBlk)
    return res
  let playersBlkList = commentsBlk % "player"
  if (!playersBlkList.len())
    return res

  let gameType = replayInfo?.gameType ?? 0
  let authorUserId = ::to_integer_safe(commentsBlk?.authorUserId ?? "", -1000, false)
  let authorBlk = ::u.search(playersBlkList, @(v) ::to_integer_safe(v?.userId ?? "", 0, false) == authorUserId)
  let authorSquadId = authorBlk?.squadId ?? INVALID_SQUAD_ID

  foreach (b in playersBlkList) {
    let userId = ::to_integer_safe(b?.userId ?? "", 0, false)
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
      isInHeroSquad = ::SessionLobby.isEqualSquadId(b?.squadId, authorSquadId)
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

    foreach (p in ::g_mplayer_param_type.types)
      if (!(p.id in mplayer) && p != ::g_mplayer_param_type.UNKNOWN)
        mplayer[p.id] <- b?[p.id] ?? p?.defVal

    res.append(mplayer)
  }

  res.sort(::mpstat_get_sort_func(gameType))
  return res
}

let saveReplayScriptCommentsBlk = function(blk) {
  blk.uiScriptsData = DataBlock()
  blk.uiScriptsData.playersInfo = datablockConverter.dataToBlk(::SessionLobby.playersInfo)
}

let restoreReplayScriptCommentsBlk = function(replayPath) {
  // Works for Local replays
  let commentsBlk = get_replay_info(replayPath)?.comments
  let playersInfo = datablockConverter.blkToData(commentsBlk?.uiScriptsData?.playersInfo) || {}

  // Works for Server replays
  if (!playersInfo.len()) {
    let mplayersList = ::get_mplayers_list(GET_MPLAYERS_LIST, true)
    foreach (mplayer in mplayersList) {
      if (mplayer?.isBot || mplayer?.userId == null)
        continue
      playersInfo[mplayer.userId] <- {
        id = mplayer.userId
        team = mplayer?.team
        name = mplayer?.name
        clanTag = mplayer?.clanTag
        squad = mplayer?.squadId ?? INVALID_SQUAD_ID
        auto_squad = !!(mplayer?.autoSquad ?? true)
      }
    }
  }

  ::SessionLobby.setCustomPlayersInfo(playersInfo)
}

// Creates global func, which is called from client.
getroottable()["save_replay_script_comments_blk"] <- @(blk) saveReplayScriptCommentsBlk(blk)

return {
  buildReplayMpTable = buildReplayMpTable
  saveReplayScriptCommentsBlk = saveReplayScriptCommentsBlk
  restoreReplayScriptCommentsBlk = restoreReplayScriptCommentsBlk
}
