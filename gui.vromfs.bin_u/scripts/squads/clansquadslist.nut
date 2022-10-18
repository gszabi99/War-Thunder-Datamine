from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { get_time_msec } = require("dagor.time")
let { format } = require("string")
  const CLAN_SQUADS_LIST_REFRESH_MIN_TIME = 3000 //ms
  const CLAN_SQUADS_LIST_REQUEST_TIME_OUT = 45000 //ms
  const CLAN_SQUADS_LIST_TIME_OUT = 180000
  const MAX_SQUADS_LIST_LEN = 100

local ClanSquadsList = class
{

  clanSquadsList = []
  clanId = ""
  lastUpdateTimeMsec = - CLAN_SQUADS_LIST_TIME_OUT
  lastRequestTimeMsec = - CLAN_SQUADS_LIST_REQUEST_TIME_OUT
  isInUpdate = false

/*************************************************************************************************/
/*************************************PUBLIC FUNCTIONS *******************************************/
/*************************************************************************************************/

  function isNewest()
  {
    return (clanId == ::clan_get_my_clan_id()) && !isInUpdate
             && get_time_msec() - lastUpdateTimeMsec < CLAN_SQUADS_LIST_REFRESH_MIN_TIME
  }

  function canRequestByTime()
  {
    let checkTime = isInUpdate ? CLAN_SQUADS_LIST_REQUEST_TIME_OUT
      : CLAN_SQUADS_LIST_REFRESH_MIN_TIME
    return  get_time_msec() - lastRequestTimeMsec >= checkTime
  }

  function canRequest()
  {
    return !isNewest() && canRequestByTime()
  }

  function isListValid()
  {
    return ((clanId == ::clan_get_my_clan_id())
      && (get_time_msec() - lastUpdateTimeMsec < CLAN_SQUADS_LIST_TIME_OUT))
  }

  function validateList()
  {
    if (!isListValid())
      clanSquadsList.clear()
  }

  function getList()
  {
    validateList()
    requestList()

    return clanSquadsList
  }

  function requestList()
  {
    if (!canRequest())
      return false

    isInUpdate = true
    lastRequestTimeMsec = get_time_msec()

    let requestClanId = ::clan_get_my_clan_id()
    let cb = Callback(@(resp) requestListCb(resp, requestClanId), this)

    ::matching_api_func("msquad.get_squads", cb, {players = getClanUidsList()})
    return true
  }

/*************************************************************************************************/
/************************************PRIVATE FUNCTIONS *******************************************/
/*************************************************************************************************/

  function getClanUidsList()
  {
    let clanPlayersUid = []
    foreach (member in ::g_clans.getMyClanMembers())
    {
      let memberUid = member?.uid
      if (memberUid)
       clanPlayersUid.append(memberUid.tointeger())
    }
    return clanPlayersUid
  }

  function requestListCb(p, requestClanId)
  {
    isInUpdate = false
    clanId = requestClanId

    let squads = ::checkMatchingError(p, false) ? (p?.squads) : null
    if (!squads)
      return

    lastUpdateTimeMsec = get_time_msec()
    updateClanSquadsList(squads)
    ::broadcastEvent("ClanSquadsListChanged", { clanSquadsList = clanSquadsList })
  }

  function updateClanSquadsList(squads) //can be called each update
  {
    if (squads.len() > MAX_SQUADS_LIST_LEN)
    {
      let message = format("Error in clanSquads::updateClanSquadsList:\nToo long clan squads list - %d",
                                squads.len())
      ::script_net_assert_once("too long clan squads list", message)

      squads.resize(MAX_SQUADS_LIST_LEN)
    }

    clanSquadsList.clear()
    foreach(squad in squads)
      clanSquadsList.append(squad)
  }

}

return ClanSquadsList()