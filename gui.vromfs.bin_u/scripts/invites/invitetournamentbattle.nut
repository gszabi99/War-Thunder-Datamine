//-file:plus-string
from "%scripts/dagui_library.nut" import *


let DataBlock = require("DataBlock")
let antiCheat = require("%scripts/penitentiary/antiCheat.nut")
let { getTextWithCrossplayIcon,
        needShowCrossPlayInfo } = require("%scripts/social/crossplay.nut")
let { saveOnlineJob } = require("%scripts/userLog/userlogUtils.nut")
let { checkAndShowMultiplayerPrivilegeWarning,
  isMultiplayerPrivilegeAvailable } = require("%scripts/user/xboxFeatures.nut")
let { isShowGoldBalanceWarning } = require("%scripts/user/balanceFeatures.nut")

let knownTournamentInvites = []

::g_invites_classes.TournamentBattle <- class extends ::BaseInvite {
  //custom class params, not exist in base invite
  battleId = ""
  inviteTime = -1
  startTime = -1
  endTime = -1
  isAccepted = false
  needCheckSystemRestriction = true

  static function getUidByParams(params) {
    return "TB_" + getTblValue("battleId", params, "")
  }

  function updateCustomParams(params, _initial = false) {
    this.battleId = getTblValue("battleId", params, this.battleId)
    this.inviteTime = getTblValue("inviteTime", params, this.inviteTime)
    this.startTime = getTblValue("startTime", params, this.startTime)
    this.endTime = getTblValue("endTime", params, this.endTime)
    this.isAccepted = false

    this.setTimedParams(this.inviteTime, this.startTime)
  }

  function getTournamentBattleLink() {
    return $"{::BaseInvite.chatLinkPrefix}TB_{this.battleId}"
  }

  function getChatInviteText() {
    return "<Link={0}>{1}</Link>".subst(
      this.getTournamentBattleLink(),
      colorize(this.inviteActiveColor,
        getTextWithCrossplayIcon(
          needShowCrossPlayInfo(),
          loc("multiplayer/invite_to_tournament_battle_link_text")
        )
      )
    )
  }

  function getInviteText() {
    return getTextWithCrossplayIcon(needShowCrossPlayInfo(), loc("multiplayer/invite_to_tournament_battle_message"))
  }

  function getPopupText() {
    return this.getInviteText()
  }

  function getIcon() {
    return "#ui/gameuiskin#lb_each_player_session.svg"
  }

  function disableCurInviteUserlog() {
    local needSave = false

    let total = ::get_user_logs_count()
    for (local i = total - 1; i >= 0; i--) {
      let blk = DataBlock()
      ::get_user_log_blk_body(i, blk)

      if ((blk.type == EULT_INVITE_TO_TOURNAMENT) &&
           (getTblValue("battleId", blk.body, "")  == this.battleId) &&
           (::disable_user_log_entry(i)))
        needSave = true
    }
    return needSave
  }

  function remove() {
    let needSave = this.disableCurInviteUserlog()

    base.remove()

    if (needSave) {
      log("Invites: Tournament: invite - needSave")
      saveOnlineJob()
    }
  }

  function haveRestrictions() {
    return !::isInMenu() || !this.isAvailableByCrossPlay() || this.isOutdated() || !isMultiplayerPrivilegeAvailable.value
  }

  function getRestrictionText() {
    if (!this.haveRestrictions())
      return ""

    if (this.isOutdated())
      return loc("multiplayer/invite_is_overtimed")
    if (!isMultiplayerPrivilegeAvailable.value)
      return loc("xbox/noMultiplayer")
    if (!this.isAvailableByCrossPlay())
      return loc("xbox/crossPlayRequired")

    return loc("invite/session/cant_apply_in_flight")
  }

  function accept() {
    if (this.isOutdated())
      return ::g_invites.showExpiredInvitePopup()

    if (!::isInMenu())
      return ::g_invites.showLeaveSessionFirstPopup()

    if (!antiCheat.showMsgboxIfEacInactive({ enableEAC = true }))
      return

    if (!isMultiplayerPrivilegeAvailable.value) {
      checkAndShowMultiplayerPrivilegeWarning()
      return
    }

    if (isShowGoldBalanceWarning())
      return

    if (!this.isAvailableByCrossPlay())
      return ::g_popups.add(null, loc("xbox/crossPlayRequired"))

    log($"Invites: Tournament: Going to join to battleId({this.battleId}) via accepted invite")
    ::SessionLobby.joinBattle(this.battleId)

    this.isAccepted = true
    this.remove()
  }

}

::g_invites.registerInviteUserlogHandler(EULT_INVITE_TO_TOURNAMENT, function(blk, idx) {
  if (!hasFeature("Tournaments")) {
    ::disable_user_log_entry(idx)
    return false
  }

  let ulogId = blk?.id
  let battleId = blk?.body.battleId ?? ""
  let inviteTime = blk?.body.inviteTime ?? -1
  let startTime = blk?.body.startTime ?? -1
  let endTime = blk?.body.endTime ?? -1

  log($"checking battle invite ulog ({ulogId}) : battleId '{battleId}'");
  if (startTime <= ::get_charserver_time_sec()
    || isInArray(ulogId, knownTournamentInvites))
    return

  knownTournamentInvites.append(ulogId)

  log($"Got userlog EULT_INVITE_TO_TOURNAMENT: battleId '{battleId}'");
  ::g_invites.addTournamentBattleInvite(battleId, inviteTime, startTime, endTime)
  return true
})

