enum wwClanSquadInviteColors {
  BUSY = "fadedTextColor"
  ENABLED = "activeTextColor"
  MATCH_GAME = "successTextColor"
}

class ::gui_handlers.WwMyClanSquadInviteModal extends ::gui_handlers.MyClanSquadsListModal
{
  operationId = null
  battleId = null
  country = null
  squadButtonsList = [
    {
      id = "btn_squad_info"
      buttonClass ="image"
      shortcut = ""
      showOnSelect = "hover"
      btnName = "X"
      btnKey = "X"
      tooltip = @() ::loc("squad/info")
      img = "#ui/gameuiskin#btn_help.svg"
      funcName = "onSquadInfo"
      isHidden = false
      isDisabled = false
    },
    {
      id = "btn_ww_battle_invite"
      funcName = "onSquadLeaderInvite"
      shortcut = ""
      showOnSelect = "hover"
      btnName = "A"
      btnKey = "A"
      text = @() ::loc("worldwar/inviteSquad")
      isHidden = true
      isDisabled = true
    }
  ]

  static function open(operationId, battleId, country)
  {
    ::gui_start_modal_wnd(::gui_handlers.WwMyClanSquadInviteModal,
      {operationId = operationId, battleId = battleId, country = country})
  }

  function updateSquadButtons(obj, squad)
  {
    base.updateSquadButtons(obj, squad)
    ::showBtn("btn_ww_battle_invite", canWwBattleInvite(squad), obj)
  }

  function updateSquadDummyButtons()
  {
    if (!selectedSquad)
      return
    ::showBtn("btn_ww_battle_invite", canWwBattleInvite(selectedSquad), dummyButtonsListObj)
  }

  function canWwBattleInvite(squad)
  {
    local presenceParams = squad?.data?.presence ?? {}
    local presenceType = ::g_presence_type.getByPresenceParams(presenceParams)
    return presenceType.canInviteToWWBattle && !isGameParamsMatch(presenceParams) && isSquadOnline(squad)
  }

  function onSquadLeaderInvite(obj)
  {
    local actionSquad = getSquadByObj(obj)
    if (!actionSquad)
      return

    ::msquad.inviteToWWBattle({
      squadId = actionSquad.leader
      squadronId = ::clan_get_my_clan_id(),
      action = "join_ww_battle"
      battle = {
        operationId = operationId
        battleId = battleId
      }
    })
  }

  function getPresence(squad)
  {
    local presenceParams = squad?.data?.presence ?? {}
    local presenceType = ::g_presence_type.getByPresenceParams(presenceParams)
    local presenceText = presenceType.getLocText(presenceParams)

    return colorizePresence(presenceText, presenceParams, presenceType)
  }

  function getBattleParams()
  {
    return {operationId = operationId, battleId = battleId, country = country}
  }

  function colorizePresence(text, presenceParams, presenceType)
  {
    if (isGameParamsMatch(presenceParams))
      return ::colorize(wwClanSquadInviteColors.MATCH_GAME, text)

    local color = presenceType.canInviteToWWBattle
      ? wwClanSquadInviteColors.ENABLED : wwClanSquadInviteColors.BUSY
    return ::colorize(color, text)
  }

  function isGameParamsMatch(presenceParams)
  {
    foreach (key in ["operationId", "battleId", "country"])
      if (this[key] != presenceParams?[key])
        return false

    return true
  }
}
