//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { addContact, rejectContact } = require("%scripts/contacts/contactsState.nut")
let { add_event_listener } = require("%sqStdLibs/helpers/subscriptions.nut")
let { registerInviteClass } = require("%scripts/invites/invitesClasses.nut")
let BaseInvite = require("%scripts/invites/inviteBase.nut")

let Friend = class (BaseInvite) {
  static function getUidByParams(params) {
    return "FR_" + getTblValue("inviterUid", params, "")
  }

  function updateCustomParams(_params, initial = false) {
    this.isAutoAccepted = this.isAlreadyAccepted()

    if (initial)
      add_event_listener("ContactsGroupUpdate",
                           function (_p) {
                             if (this.isAlreadyAccepted())
                               this.remove()
                           },
                           this)
  }

  function isValid() {
    return base.isValid() && this.inviterUid != null && this.inviterUid != ""
  }

  function isOutdated() {
    return base.isOutdated() || this.isAlreadyAccepted()
  }

  function isAlreadyAccepted() {
    return ::isPlayerInContacts(this.inviterUid, EPL_FRIENDLIST)
  }

  function getInviteText() {
    return loc("contacts/friend_invitation_received/no_nick")
  }

  function getPopupText() {
    return loc("contacts/popup_friend_invitation_received",
      { userName = colorize("goodTextColor", this.getInviterName()) })
  }

  function getIcon() {
    return "#ui/gameuiskin#btn_friend_add.svg"
  }

  function accept() {
    if (this.isValid())
      addContact(::getContact(this.inviterUid, this.inviterName), EPL_FRIENDLIST)
    this.remove()
  }

  function reject() {
    if (this.isValid())
      rejectContact({ uid = this.inviterUid, name = this.inviterName })
    this.remove()
  }
}

registerInviteClass("Friend", Friend)
