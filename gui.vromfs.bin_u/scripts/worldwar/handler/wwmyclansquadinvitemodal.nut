//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { addMail } =  require("%scripts/matching/serviceNotifications/postbox.nut")

enum wwClanSquadInviteColors {
  BUSY = "fadedTextColor"
  ENABLED = "activeTextColor"
  MATCH_GAME = "successTextColor"
}

::gui_handlers.WwMyClanSquadInviteModal <- class extends ::gui_handlers.MyClanSquadsListModal {
  operationId = null
  battleId = null
  country = null
  squadButtonsList = [
    {
      id = "btn_squad_info"
      buttonClass = "image"
      shortcut = ""
      showOnSelect = "hover"
      btnName = "X"
      btnKey = "X"
      tooltip = @() loc("squad/info")
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
      text = @() loc("worldwar/inviteSquad")
      isHidden = true
      isDisabled = true
    }
  ]

  static function open(operationId, battleId, country) {
    ::gui_start_modal_wnd(::gui_handlers.WwMyClanSquadInviteModal,
      { operationId = operationId, battleId = battleId, country = country })
  }

  function updateSquadButtons(obj, squad) {
    base.updateSquadButtons(obj, squad)
    ::showBtn("btn_ww_battle_invite", this.canWwBattleInvite(squad), obj)
  }

  function updateSquadDummyButtons() {
    if (!this.selectedSquad)
      return
    ::showBtn("btn_ww_battle_invite", this.canWwBattleInvite(this.selectedSquad), this.dummyButtonsListObj)
  }

  function canWwBattleInvite(squad) {
    let presenceParams = squad?.data?.presence ?? {}
    let presenceType = ::g_presence_type.getByPresenceParams(presenceParams)
    return presenceType.canInviteToWWBattle && !this.isGameParamsMatch(presenceParams) && this.isSquadOnline(squad)
  }

  function onSquadLeaderInvite(obj) {
    let actionSquad = this.getSquadByObj(obj)
    if (!actionSquad)
      return

    addMail({
      user_id = actionSquad.leader
      mail = {
        inviteClassName = "WwOperationBattle"
        params = {
          squadronId = ::clan_get_my_clan_id()
          operationId = this.operationId
          battleId = this.battleId
        }
      }
      ttl = 3600
    })
  }

  function getPresence(squad) {
    let presenceParams = squad?.data?.presence ?? {}
    let presenceType = ::g_presence_type.getByPresenceParams(presenceParams)
    let presenceText = presenceType.getLocText(presenceParams)

    return this.colorizePresence(presenceText, presenceParams, presenceType)
  }

  function getBattleParams() {
    return { operationId = this.operationId, battleId = this.battleId, country = this.country }
  }

  function colorizePresence(text, presenceParams, presenceType) {
    if (this.isGameParamsMatch(presenceParams))
      return colorize(wwClanSquadInviteColors.MATCH_GAME, text)

    let color = presenceType.canInviteToWWBattle
      ? wwClanSquadInviteColors.ENABLED : wwClanSquadInviteColors.BUSY
    return colorize(color, text)
  }

  function isGameParamsMatch(presenceParams) {
    foreach (key in ["operationId", "battleId", "country"])
      if (this[key] != presenceParams?[key])
        return false

    return true
  }
}
