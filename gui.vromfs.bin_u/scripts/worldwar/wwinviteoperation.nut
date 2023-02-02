from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { requestUsersInfo } = require("%scripts/user/usersInfoManager.nut")
let { isShowGoldBalanceWarning } = require("%scripts/user/balanceFeatures.nut")
let { actionWithGlobalStatusRequest } = require("%scripts/worldWar/operations/model/wwGlobalStatus.nut")
let { notifyMailRead } = require("%scripts/matching/serviceNotifications/postbox.nut")
let { removeInviteToOperation } = require("%scripts/worldWar/wwInvites.nut")

const WW_OPERATION_INVITE_EXPIRE_SEC = 3600

::g_invites_classes.Operation <- class extends ::BaseInvite {
  mailId           = null
  operationId      = -1
  senderId         = ""

  startTime                  = -1
  isAccepted                 = false
  senderContact              = null
  needCheckSystemRestriction = true

  inviteActiveColor = "userlogColoredText"

  static function getUidByParams(p) {
    return $"OP_{p?.mail.operationId ?? ""}"
  }


  isValid = @() !this.isAccepted && !this.isRejected

  getIcon = @() "#ui/gameuiskin#battles_open.png"

  function updateCustomParams(p, initial = false) {
    this.mailId = p?.mail_id
    this.senderId = p?.mail.sender_id.tostring() ?? this.senderId
    this.operationId = p?.mail.operationId ?? this.operationId

    this.updateInviterContact()

    this.setDelayed(true)
    let cb = Callback(function(_) {
        this.updateInviterContact()
        this.setDelayed(false)
      }, this)

    requestUsersInfo([this.senderId], cb, cb)

    this.isAccepted = false

    if (initial)
      this.setTimedParams(0, ::get_charserver_time_sec() + WW_OPERATION_INVITE_EXPIRE_SEC)
  }

  function updateInviterContact() {
    this.senderContact = ::getContact(this.senderId)
    this.updateInviterName()
  }

  function updateInviterName() {
    if (this.senderContact)
      this.inviterName = this.senderContact.name
  }

  getInviteText = @() loc("worldwar/inviteOperation", {
      name = colorize(this.inviteActiveColor, this.getInviterName())
      operation = colorize(this.inviteActiveColor, $"{loc("ui/number_sign")}{this.operationId}")
    })

  getPopupText = @() this.getInviteText()
  haveRestrictions = @() !::isInMenu()

  function getRestrictionText(){
    if (this.haveRestrictions())
      return loc("invite/session/cant_apply_in_flight")
    return ""
  }

  function implAccept() {
    if (this.isOutdated()) {
      ::g_invites.showExpiredInvitePopup()
      return
    }

    let onSuccess = Callback(function() {
        this.isAccepted = true
        this.remove()
        removeInviteToOperation(this.operationId)
        if (this.mailId)
          notifyMailRead(this.mailId)
    }, this)
    let requestBlk = ::DataBlock()
    requestBlk.operationId = this.operationId
    actionWithGlobalStatusRequest("cln_ww_global_status_short", requestBlk, null,
      @() ::g_world_war.joinOperationById(this.operationId, null, null, onSuccess))
  }

  function accept() {
    if (isShowGoldBalanceWarning())
      return

    let acceptCallback = Callback(this.implAccept, this)
    let callback = function () { ::queues.checkAndStart(acceptCallback, null, "isCanNewflight")}
    let canJoin = ::g_squad_utils.canJoinFlightMsgBox(
      { isLeaderCanJoin = true, msgId = "squad/leave_squad_for_invite" },
      callback
    )

    if (!canJoin)
      return

    callback()
  }

  function reject() {
    notifyMailRead(this.mailId)
    if (this.isOutdated())
      return this.remove()

    this.isRejected = true
    this.remove()
    removeInviteToOperation(this.operationId)
  }
}
