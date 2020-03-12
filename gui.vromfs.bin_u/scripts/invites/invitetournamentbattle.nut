class ::g_invites_classes.TournamentBattle extends ::BaseInvite
{
  //custom class params, not exist in base invite
  battleId = ""
  inviteTime = -1
  startTime = -1
  endTime = -1
  isAccepted = false

  static function getUidByParams(params)
  {
    return "TB_" + ::getTblValue("battleId", params, "")
  }

  function updateCustomParams(params, initial = false)
  {
    battleId = ::getTblValue("battleId", params, battleId)
    inviteTime = ::getTblValue("inviteTime", params, inviteTime)
    startTime = ::getTblValue("startTime", params, startTime)
    endTime = ::getTblValue("endTime", params, endTime)
    isAccepted = false

    setTimedParams( inviteTime, startTime )
  }

  function getTournamentBattleLink()
  {
    return ::BaseInvite.chatLinkPrefix + "TB_" + battleId;
  }

  function getChatInviteText()
  {
    local nameF = "<Link=%s><Color="+inviteActiveColor+">%s</Color></Link>"

    return ::format(nameF, getTournamentBattleLink(), ::loc("multiplayer/invite_to_tournament_battle_link_text"))
  }

  function getInviteText()
  {
    return ::loc("multiplayer/invite_to_tournament_battle_message")
  }

  function getPopupText()
  {
    return ::loc("multiplayer/invite_to_tournament_battle_message")
  }

  function getIcon()
  {
    return "#ui/gameuiskin#lb_each_player_session.svg"
  }

  function disableCurInviteUserlog()
  {
    local needSave = false

    local total = ::get_user_logs_count()
    for (local i = total-1; i >= 0; i--)
    {
      local blk = ::DataBlock()
      ::get_user_log_blk_body(i, blk)

      if ( (blk.type == ::EULT_INVITE_TO_TOURNAMENT) &&
           (::getTblValue("battleId", blk.body, "")  == battleId) &&
           (::disable_user_log_entry(i)) )
        needSave = true
    }
    return needSave
  }

  function remove()
  {
    local needSave = disableCurInviteUserlog()

    base.remove()

    if (needSave)
    {
      dagor.debug("TournamentBattle invite - needSave")
      ::save_online_job()
    }
  }


  function accept()
  {
    if (isOutdated())
      return ::g_invites.showExpiredInvitePopup()

    if ( !::isInMenu() )
      return ::g_invites.showLeaveSessionFirstPopup()

    ::dagor.debug("Going to join to battleId(" + battleId + ") via accepted invite");
    ::SessionLobby.joinBattle(battleId)

    isAccepted = true
    remove()
  }

}

