from "%scripts/dagui_library.nut" import *
let DataBlock  = require("DataBlock")
let { requestUsersInfo } = require("%scripts/user/usersInfoManager.nut")
let { isShowGoldBalanceWarning } = require("%scripts/user/balanceFeatures.nut")
let { actionWithGlobalStatusRequest } = require("%scripts/worldWar/operations/model/wwGlobalStatus.nut")
let { notifyMailRead } = require("%scripts/matching/serviceNotifications/postbox.nut")
let { draw_attention_to_inactive_window } = require("app")
let { get_charserver_time_sec } = require("chard")
let { registerInviteClass, findInviteClass } = require("%scripts/invites/invitesClasses.nut")
let BaseInvite = require("%scripts/invites/inviteBase.nut")
let { isInMenu } = require("%scripts/clientState/clientStates.nut")
let { updateNewInvitesAmount, findInviteByUid, showExpiredInvitePopup, removeInvite
} = require("%scripts/invites/invites.nut")
let { getContact } = require("%scripts/contacts/contacts.nut")
let { checkQueueAndStart } = require("%scripts/queue/queueManager.nut")
let { canJoinFlightMsgBox } = require("%scripts/squads/squadUtils.nut")
let { add_event_listener } = require("%sqStdLibs/helpers/subscriptions.nut")

let g_world_war = require("%scripts/worldWar/worldWarUtils.nut")

function removeInviteToOperation(operationId) {
  let uid = findInviteClass("Operation")?.getUidByParams({ mail = { operationId = operationId } })
  let invite = findInviteByUid(uid)
  if (invite)
    removeInvite(invite)
}

const WW_OPERATION_INVITE_EXPIRE_SEC = 3600
let inviteActiveColor = "userlogColoredText"

let Operation = class (BaseInvite) {
  mailId           = null
  operationId      = -1
  senderId         = ""
  country          = ""
  clanTag          = ""

  isAccepted                 = false
  senderContact              = null
  needCheckSystemRestriction = true

  static function getUidByParams(p) {
    return $"OP_{p?.operationId ?? ""}"
  }


  isValid = @() !this.isAccepted && !this.isRejected

  getIcon = @() "#ui/gameuiskin#battles_open"

  function updateCustomParams(p, initial = false) {
    this.mailId = p?.mail_id
    this.senderId = p?.senderId ?? this.senderId
    this.country = p?.country ?? this.country
    this.operationId = p?.operationId ?? this.operationId
    this.clanTag = p?.clanTag ?? this.clanTag

    this.updateInviterContact()

    this.setDelayed(true)
    requestUsersInfo(this.senderId)

    this.isAccepted = false

    if (initial) {
      this.setTimedParams(0, get_charserver_time_sec() + WW_OPERATION_INVITE_EXPIRE_SEC)
      draw_attention_to_inactive_window()

      add_event_listener("UserInfoManagerDataUpdated",
        function(params) {
          if (this.senderId not in params.usersInfo)
            return
          this.updateInviterContact()
          this.setDelayed(false)
          updateNewInvitesAmount()
        }, this)
    }
  }

  function updateInviterContact() {
    this.senderContact = getContact(this.senderId)
    this.updateInviterName()
  }

  function updateInviterName() {
    if (this.senderContact)
      this.inviterName = this.senderContact.getName()
  }

  function getInviteText() {
    let operationStr = colorize(inviteActiveColor, $"{loc("ui/number_sign")}{this.operationId}")
    return this.clanTag != ""
      ? loc("worldWar/userlog/startOperation", {
        clan = colorize(inviteActiveColor, this.clanTag)
        operation = operationStr
      })
      : loc("worldwar/inviteOperation", {
        name = colorize(inviteActiveColor, this.getInviterName())
        operation = operationStr
      })
  }

  getPopupText = @() this.getInviteText()
  haveRestrictions = @() !isInMenu.get()

  function getRestrictionText() {
    if (this.haveRestrictions())
      return loc("invite/session/cant_apply_in_flight")
    return ""
  }

  function implAccept() {
    if (this.isOutdated()) {
      showExpiredInvitePopup()
      return
    }

    let onSuccess = Callback(function() {
        this.isAccepted = true
        this.remove()
        removeInviteToOperation(this.operationId)
        if (this.mailId)
          notifyMailRead(this.mailId)
    }, this)
    let requestBlk = DataBlock()
    requestBlk.operationId = this.operationId
    actionWithGlobalStatusRequest("cln_ww_global_status_short", requestBlk, null,
      @() g_world_war.joinOperationById(this.operationId, this.country, null, onSuccess, true))
  }

  function accept() {
    if (isShowGoldBalanceWarning())
      return

    let acceptCallback = Callback(this.implAccept, this)
    let callback = function () { checkQueueAndStart(acceptCallback, null, "isCanNewflight") }
    let canJoin = canJoinFlightMsgBox(
      { isLeaderCanJoin = true, msgId = "squad/leave_squad_for_invite" },
      callback
    )

    if (!canJoin)
      return

    callback()
  }

  function reject() {
    if (this.mailId)
      notifyMailRead(this.mailId)

    if (this.isOutdated())
      return this.remove()

    this.isRejected = true
    this.remove()
    removeInviteToOperation(this.operationId)
  }
}

registerInviteClass("Operation", Operation)
