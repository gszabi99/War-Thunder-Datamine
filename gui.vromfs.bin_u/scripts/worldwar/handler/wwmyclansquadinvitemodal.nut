from "%scripts/dagui_natives.nut" import clan_get_my_clan_id
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { addMail } =  require("%scripts/matching/serviceNotifications/postbox.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getByPresenceParams } = require("%scripts/user/presenceType.nut")

enum wwClanSquadInviteColors {
  BUSY = "fadedTextColor"
  ENABLED = "activeTextColor"
  MATCH_GAME = "successTextColor"
}

gui_handlers.WwMyClanSquadInviteModal <- class (gui_handlers.MyClanSquadsListModal) {
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
    loadHandler(gui_handlers.WwMyClanSquadInviteModal,
      { operationId = operationId, battleId = battleId, country = country })
  }

  function updateSquadButtons(obj, squad) {
    base.updateSquadButtons(obj, squad)
    showObjById("btn_ww_battle_invite", this.canWwBattleInvite(squad), obj)
  }

  function updateSquadDummyButtons() {
    if (!this.selectedSquad)
      return
    showObjById("btn_ww_battle_invite", this.canWwBattleInvite(this.selectedSquad), this.dummyButtonsListObj)
  }

  function canWwBattleInvite(squad) {
    let presenceParams = squad?.data.presence ?? {}
    let presenceType = getByPresenceParams(presenceParams)
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
          squadronId = clan_get_my_clan_id()
          operationId = this.operationId
          battleId = this.battleId
        }
      }
      ttl = 3600
    })
  }

  function getPresence(squad) {
    let presenceParams = squad?.data.presence ?? {}
    let presenceType = getByPresenceParams(presenceParams)
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
