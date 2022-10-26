from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

::g_invites_classes.Friend <- class extends ::BaseInvite
{
  static function getUidByParams(params)
  {
    return "FR_" + getTblValue("inviterUid", params, "")
  }

  function updateCustomParams(params, initial = false)
  {
    this.inviterName = getTblValue("inviterName", params, this.inviterName)
    this.inviterUid = getTblValue("inviterUid", params, this.inviterUid)
    this.isAutoAccepted = this.isAlreadyAccepted()

    if (initial)
      ::add_event_listener("ContactsGroupUpdate",
                           function (_p) {
                             if (this.isAlreadyAccepted())
                               this.remove()
                           },
                           this)
  }

  function isValid()
  {
    return base.isValid() && !::u.isEmpty(this.inviterUid)
  }

  function isOutdated()
  {
    return base.isOutdated() || this.isAlreadyAccepted()
  }

  function isAlreadyAccepted()
  {
    return ::isPlayerInContacts(this.inviterUid, EPL_FRIENDLIST)
  }

  function getInviteText()
  {
    return loc("contacts/friend_invitation_recieved/no_nick")
  }

  function getPopupText()
  {
    return loc("contacts/popup_friend_invitation_recieved",
      { userName = colorize("goodTextColor", this.getInviterName()) })
  }

  function getIcon()
  {
    return "#ui/gameuiskin#btn_friend_add.svg"
  }

  function accept()
  {
    if (this.isValid())
      ::editContactMsgBox(::getContact(this.inviterUid, this.inviterName), EPL_FRIENDLIST, true)
    this.remove()
  }
}