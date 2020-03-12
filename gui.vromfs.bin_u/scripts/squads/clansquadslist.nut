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
             && ::dagor.getCurTime() - lastUpdateTimeMsec < CLAN_SQUADS_LIST_REFRESH_MIN_TIME
  }

  function canRequestByTime()
  {
    local checkTime = isInUpdate ? CLAN_SQUADS_LIST_REQUEST_TIME_OUT
      : CLAN_SQUADS_LIST_REFRESH_MIN_TIME
    return  ::dagor.getCurTime() - lastRequestTimeMsec >= checkTime
  }

  function canRequest()
  {
    return !isNewest() && canRequestByTime()
  }

  function isListValid()
  {
    return ((clanId == ::clan_get_my_clan_id())
      && (::dagor.getCurTime() - lastUpdateTimeMsec < CLAN_SQUADS_LIST_TIME_OUT))
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
    lastRequestTimeMsec = ::dagor.getCurTime()

    local requestClanId = ::clan_get_my_clan_id()
    local cb = ::Callback(@(resp) requestListCb(resp, requestClanId), this)

    matching_api_func("msquad.get_squads", cb, {players = getClanUidsList()})
    return true
  }

/*************************************************************************************************/
/************************************PRIVATE FUNCTIONS *******************************************/
/*************************************************************************************************/

  function getClanUidsList()
  {
    local clanPlayersUid = []
    foreach (member in ::g_clans.getMyClanMembers())
    {
      local memberUid = member?.uid
      if (memberUid)
       clanPlayersUid.append(memberUid.tointeger())
    }
    return clanPlayersUid
  }

  function requestListCb(p, requestClanId)
  {
    isInUpdate = false
    clanId = requestClanId

    local squads = ::checkMatchingError(p, false) ? (p?.squads) : null
    if (!squads)
      return

    lastUpdateTimeMsec = ::dagor.getCurTime()
    updateClanSquadsList(squads)
    ::broadcastEvent("ClanSquadsListChanged", { clanSquadsList = clanSquadsList })
  }

  function updateClanSquadsList(squads) //can be called each update
  {
    if (squads.len() > MAX_SQUADS_LIST_LEN)
    {
      local message = ::format("Error in clanSquads::updateClanSquadsList:\nToo long clan squads list - %d",
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