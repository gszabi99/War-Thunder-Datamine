::g_invites <- {
  [PERSISTENT_DATA_PARAMS] = ["list", "newInvitesAmount"]

  popupTextColor = "@chatInfoColor"

  list = []
  newInvitesAmount = 0
  refreshInvitesTask = -1
  knownTournamentInvites = []
}

g_invites.addInvite <- function addInvite(inviteClass, params)
{
  checkCleanList()

  local uid = inviteClass.getUidByParams(params)
  local invite = findInviteByUid(uid)
  if (invite)
  {
    invite.updateParams(params)
    updateNewInvitesAmount()
    broadcastInviteUpdated(invite)
    return invite
  }

  invite = inviteClass(params)
  if (invite.isValid())
  {
    list.append(invite)
    updateNewInvitesAmount()
    broadcastInviteReceived(invite)
  }
  return invite
}

g_invites.broadcastInviteReceived <- function broadcastInviteReceived(invite)
{
  if (!invite.isDelayed && !invite.isAutoAccepted)
    ::broadcastEvent("InviteReceived", { invite = invite })
}

g_invites.broadcastInviteUpdated <- function broadcastInviteUpdated(invite)
{
  if (invite.isVisible())
    ::broadcastEvent("InviteUpdated", { invite = invite })
}

g_invites.addChatRoomInvite <- function addChatRoomInvite(roomId, inviterName)
{
  return addInvite(::g_invites_classes.ChatRoom, { roomId = roomId, inviterName = inviterName })
}

g_invites.addSessionRoomInvite <- function addSessionRoomInvite(roomId, inviterUid, inviterName, password = null)
{
  return addInvite(::g_invites_classes.SessionRoom,
                   {
                     roomId      = roomId
                     inviterUid  = inviterUid
                     inviterName = inviterName
                     password    = password
                   })
}

g_invites.addTournamentBattleInvite <- function addTournamentBattleInvite(battleId, inviteTime, startTime, endTime)
{
  return addInvite(::g_invites_classes.TournamentBattle,
                   {
                     battleId = battleId
                     inviteTime = inviteTime
                     startTime = startTime
                     endTime = endTime
                   })
}

g_invites.addInviteToSquad <- function addInviteToSquad(squadId, leaderId)
{
  return addInvite(::g_invites_classes.Squad, {squadId = squadId, leaderId = leaderId})
}

g_invites.removeInviteToSquad <- function removeInviteToSquad(squadId)
{
  local uid = ::g_invites_classes.Squad.getUidByParams({squadId = squadId})
  local invite = findInviteByUid(uid)
  if (invite)
    remove(invite)
}

g_invites.addFriendInvite <- function addFriendInvite(name, uid)
{
  if (::u.isEmpty(name) || ::u.isEmpty(uid))
    return
  return addInvite(::g_invites_classes.Friend, { inviterName = name, inviterUid = uid })
}

::g_invites._lastCleanTime <- -1
g_invites.checkCleanList <- function checkCleanList()
{
  local isRemoved = false
  for(local i = list.len() - 1; i >= 0; i--)
    if (list[i].isOutdated())
    {
      list.remove(i)
      isRemoved = true
    }
  if (isRemoved)
    ::broadcastEvent("InviteRemoved")
}

g_invites.remove <- function remove(invite)
{
  foreach(idx, inv in list)
    if (inv == invite)
    {
      invite.onRemove()
      list.remove(idx)
      updateNewInvitesAmount()
      ::broadcastEvent("InviteRemoved")
      break
    }
}

g_invites.findInviteByChatLink <- function findInviteByChatLink(link)
{
  foreach(invite in list)
    if (invite.checkChatLink(link))
      return invite
  return null
}

g_invites.findInviteByUid <- function findInviteByUid(uid)
{
  foreach(invite in list)
    if (invite.uid == uid)
      return invite
  return null
}

g_invites.acceptInviteByLink <- function acceptInviteByLink(link)
{
  if (!::g_string.startsWith(link, ::BaseInvite.chatLinkPrefix))
    return false

  local invite = ::g_invites.findInviteByChatLink(link)
  if (invite && !invite.isOutdated())
    invite.accept()
  else
    showExpiredInvitePopup()
  return true
}

g_invites.showExpiredInvitePopup <- function showExpiredInvitePopup()
{
  ::g_popups.add(null, ::colorize(popupTextColor, ::loc("multiplayer/invite_is_overtimed")))
}

g_invites.showLeaveSessionFirstPopup <- function showLeaveSessionFirstPopup()
{
  ::g_popups.add(null, ::colorize(popupTextColor, ::loc("multiplayer/leave_session_first")))
}

g_invites.markAllSeen <- function markAllSeen()
{
  local changed = false
  foreach(invite in list)
    if (invite.markSeen(true))
      changed = true

  if (changed)
    updateNewInvitesAmount()
}

g_invites.updateNewInvitesAmount <- function updateNewInvitesAmount()
{
  local amount = 0
  foreach(invite in list)
    if (invite.isNew() && invite.isVisible())
      amount++
  if (amount == newInvitesAmount)
    return

  newInvitesAmount = amount
  ::do_with_all_gamercards(::update_gc_invites)
}

g_invites._timedInvitesUpdate <- function _timedInvitesUpdate( dt = 0 )
{
  local now = ::get_charserver_time_sec()
  checkCleanList()

  foreach(invite in list)
    invite.updateDelayedState( now )

  updateNewInvitesAmount()

  ::g_invites.rescheduleInvitesTask()
}

g_invites.rescheduleInvitesTask <- function rescheduleInvitesTask()
{
  if ( refreshInvitesTask >= 0 )
  {
    ::periodic_task_unregister( refreshInvitesTask )
    refreshInvitesTask = -1
  }

  checkCleanList()

  local nextTriggerTimestamp = -1
  foreach(invite in list)
  {
    local  ts = invite.getNextTriggerTimestamp()
    if (ts < 0)
      continue
    if (nextTriggerTimestamp < 0 || nextTriggerTimestamp > ts )
      nextTriggerTimestamp = ts
  }

  if ( nextTriggerTimestamp < 0 )
    return

  local triggerDelay = nextTriggerTimestamp - ::get_charserver_time_sec();
  if ( triggerDelay < 1 )
    triggerDelay = 1  //  in case we have some timed outs

  refreshInvitesTask = ::periodic_task_register( this,
                                                 _timedInvitesUpdate,
                                                 triggerDelay )

  ::dagor.debug("Rescheduled refreshInvitesTask " + refreshInvitesTask+" with delay "+triggerDelay);
}

g_invites.fetchNewInvitesFromUserlogs <- function fetchNewInvitesFromUserlogs()
{
  local needReshedule = false
  local now = ::get_charserver_time_sec();
  local total = ::get_user_logs_count()
  for (local i = total-1; i >= 0; i--)
  {
    local blk = ::DataBlock()
    ::get_user_log_blk_body(i, blk)

    if ( blk.type == ::EULT_WW_CREATE_OPERATION ||
         blk.type == ::EULT_WW_START_OPERATION )
    {
      if (blk?.disabled)
        continue

      ::g_world_war.addOperationInvite(
        blk.body?.operationId ?? -1,
        blk.body?.clanId ?? -1,
        blk.type == ::EULT_WW_START_OPERATION,
        blk?.timeStamp ?? 0)

      ::disable_user_log_entry(i)
      needReshedule = true
    }
    else if (blk.type == ::EULT_INVITE_TO_TOURNAMENT)
    {
      if (!::has_feature("Tournaments"))
      {
        ::disable_user_log_entry(i)
        continue
      }

      local ulogId = blk.id
      local battleId = ::getTblValue("battleId", blk.body, "")
      local inviteTime = ::getTblValue("inviteTime", blk.body, -1)
      local startTime = ::getTblValue("startTime", blk.body, -1)
      local endTime = ::getTblValue("endTime", blk.body, -1)

      ::dagor.debug( "checking battle invite ulog ("+ulogId+") : battleId '"+battleId+"'");
      if ( startTime <= now || ::isInArray(ulogId, ::g_invites.knownTournamentInvites) )
        continue

      ::g_invites.knownTournamentInvites.append(ulogId)

      ::dagor.debug( "Got userlog EULT_INVITE_TO_TOURNAMENT: battleId '"+battleId+"'");
      ::g_invites.addTournamentBattleInvite(battleId, inviteTime, startTime, endTime);
      needReshedule = true
    }
  }

  if ( needReshedule )
    ::g_invites.rescheduleInvitesTask()
}

g_invites.onEventProfileUpdated <- function onEventProfileUpdated(p)
{
  if (::g_login.isLoggedIn())
    fetchNewInvitesFromUserlogs()
}

g_invites.onEventLoginComplete <- function onEventLoginComplete(p)
{
  fetchNewInvitesFromUserlogs()
}

g_invites.onEventScriptsReloaded <- function onEventScriptsReloaded(p)
{
  list = ::u.map(list, function(invite)
  {
    local params = invite.reloadParams
    foreach(inviteClass in ::g_invites_classes)
      if (inviteClass.getUidByParams(params) == invite.uid)
      {
        local newInvite = inviteClass(params)
        newInvite.afterScriptsReload(invite)
        return newInvite
      }
    return invite
  })
}


::subscribe_handler(::g_invites, ::g_listener_priority.DEFAULT_HANDLER)
::g_script_reloader.registerPersistentDataFromRoot("g_invites")
