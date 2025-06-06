from "%scripts/dagui_library.nut" import *

let { g_chat } = require("%scripts/chat/chat.nut")
let { isInReloading } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let { get_time_msec } = require("dagor.time")
let platformModule = require("%scripts/clientState/platform.nut")
let crossplayModule = require("%scripts/social/crossplay.nut")
let { checkChatEnableWithPlayer, isCrossNetworkMessageAllowed } = require("%scripts/chat/chatStates.nut")
let { get_charserver_time_sec } = require("chard")
let { OPTIONS_MODE_GAMEPLAY, USEROPT_SHOW_SOCIAL_NOTIFICATIONS
} = require("%scripts/options/optionsExtNames.nut")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let { INVITE_CHAT_LINK_PREFIX, openInviteWnd, updateNewInvitesAmount, broadcastInviteReceived,
  removeInvite
} = require("%scripts/invites/invites.nut")
let { utf8ToLower } = require("%sqstd/string.nut")
let { addPopup, removePopupByHandler } = require("%scripts/popups/popups.nut")
let { showChatPlayerRClickMenu } = require("%scripts/user/playerContextMenu.nut")
let { get_gui_option_in_mode } = require("%scripts/options/options.nut")
let { getContact } = require("%scripts/contacts/contacts.nut")
let { isUserBlockedByPrivateSetting } = require("%scripts/chat/chatUtils.nut")

let BaseInvite = class {
  static lifeTimeMsec = 3600000

  inviteColor = "@chatTextInviteColor"
  inviteActiveColor = "@chatTextInviteActiveColor"

  uid = ""
  receivedTime = -1

  inviterName = ""
  inviterNameToLower = "" 
  inviterUid  = null

  isSeen = false
  isDelayed = false 
  isAutoAccepted = false
  isRejected = false

  needCheckSystemRestriction = false 
  needCheckCanChatWithPlayer = false 

  timedShowStamp = -1   
  timedExpireStamp = -1 

  reloadParams = null 

  needShowPopup = true

  canChatWithPlayer = false

  constructor(params) {
    this.uid = this.getUidByParams(params)
    this.updateParams(params, true)
  }

  static function getUidByParams(params) { 
    return "".concat("ERR_", getTblValue("inviterName", params, ""))
  }

  function updateParams(params, initial = false) {
    this.reloadParams = params
    this.receivedTime = get_time_msec()
    this.inviterName = params?.inviterName ?? this.inviterName
    this.inviterNameToLower = utf8ToLower(this.inviterName)
    this.inviterUid = params?.inviterUid ?? this.inviterUid
    this.needShowPopup = params?.needShowPopup ?? true
    this.updateCustomParams(params, initial)
  }

  function updateCanChatWithPlayer(cb = null) {
    if (!this.needCheckCanChatWithPlayer)
      return
    let canChatCb = Callback(function(canChat) {
      this.canChatWithPlayer = canChat
      cb?()
    }, this)
    checkChatEnableWithPlayer(this.inviterName, canChatCb)
  }

  function afterScriptsReload(inviteBeforeReload) {
    this.receivedTime = inviteBeforeReload.receivedTime
  }

  function updateCustomParams(_params, _initial = false) {
    this.updateCanChatWithPlayer()
  }

  function isValid() {
    return !this.isAutoAccepted
  }

  function isOutdated() {
    if (!this.isValid())
      return true
    if (this.receivedTime + this.lifeTimeMsec < get_time_msec())
      return true
    if (this.timedExpireStamp > 0 && this.timedExpireStamp <= get_charserver_time_sec())
      return true
    return false
  }

  function getInviterName() {
    return getPlayerName(this.inviterName)
  }

  function isVisible() {
    return !this.isOutdated()
           && !this.isDelayed
           && !this.isAutoAccepted
           && !this.isRejected
           && !isUserBlockedByPrivateSetting(this.inviterUid, this.inviterName)
  }

  function setDelayed(newIsDelayed) {
    if (this.isDelayed == newIsDelayed)
      return

    this.isDelayed = newIsDelayed
    if (this.isDelayed)
      return

    broadcastInviteReceived(this)
    this.showInvitePopup()
  }

  function updateDelayedState(now) {
    if (this.timedShowStamp > 0 && this.timedShowStamp <= now) {
      this.timedShowStamp = -1
      this.setDelayed(false)
    }
  }

  function getNextTriggerTimestamp() {
    if (this.timedShowStamp > 0)
      return this.timedShowStamp

    if (this.timedExpireStamp > 0)
      return this.timedExpireStamp

    return -1
  }

  function setTimedParams(timedShowStamp_, timedExpireStamp_) {
    this.timedShowStamp = timedShowStamp_
    this.timedExpireStamp  = timedExpireStamp_
    if (this.timedShowStamp > 0 && this.timedShowStamp > get_charserver_time_sec())
      this.setDelayed(true)
  }


  function getChatLink() {
    return $"{INVITE_CHAT_LINK_PREFIX}{this.uid}"
  }

  function getChatInviterLink() {
    return g_chat.generatePlayerLink(this.inviterName)
  }

  function checkChatLink(link) {
    return link == this.getChatLink()
  }

  function autoAccept() {
    this.isAutoAccepted = true
    this.accept()
  }
  function accept() {}
  function getChatInviteText() { return "" }
  function getPopupText() { return "" }
  function getRestrictionText() { return "" }
  function getInviteText() { return "" }
  function getIcon() { return "" }
  function haveRestrictions() { return false }

  function showInvitePopup() {
    if (!this.isVisible()
        || isInReloading()
        || get_gui_option_in_mode(USEROPT_SHOW_SOCIAL_NOTIFICATIONS, OPTIONS_MODE_GAMEPLAY) == false
        || !this.needShowPopup
      )
      return
    local msg = this.getPopupText()
    if (!msg.len())
      return

    msg = [colorize(this.inviteColor, msg)]
    msg.append(this.getRestrictionText())

    let buttons = []
    if (!this.haveRestrictions()) {
      buttons.append(
        { id = "reject_invite",
          text = loc("invite/reject"),
          func = this.reject
        }
        { id = "accept_invite",
          text = loc("contacts/accept_invitation"),
          func = this.accept
        }
      )
    }

    addPopup(null, "\n".join(msg, true), openInviteWnd, buttons, this, $"invite_{this.uid}")
  }

  function reject() {
    this.remove()
  }

  function onRemove() {
    removePopupByHandler(this)
  }

  function remove() {
    removeInvite(this)
  }

  function showInviterMenu(position = null) {
    let contact = this.inviterUid && getContact(this.inviterUid, this.inviterName)
    showChatPlayerRClickMenu(this.inviterName, null, contact, position)
  }

  function markSeen(silent = false) {
    if (this.isSeen)
      return false

    this.isSeen = true
    if (!silent)
      updateNewInvitesAmount()
    return true
  }

  function isNew() {
    return !this.isSeen && !this.isOutdated()
  }

  function hasInviter() {
    return this.inviterName != ""
  }

  function isAvailableByCrossPlay() {
    return crossplayModule.isCrossPlayEnabled()
           || platformModule.isXBoxPlayerName(this.inviterName)
           || platformModule.isPS4PlayerName(this.inviterName)
  }

  function isAvailableByChatRestriction() {
    return this.canChatWithPlayer && isCrossNetworkMessageAllowed(this.inviterName)
  }
}

return BaseInvite