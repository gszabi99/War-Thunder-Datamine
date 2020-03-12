class ::g_invites_classes.Friend extends ::BaseInvite
{
  static function getUidByParams(params)
  {
    return "FR_" + ::getTblValue("inviterUid", params, "")
  }

  function updateCustomParams(params, initial = false)
  {
    inviterName = ::getTblValue("inviterName", params, inviterName)
    inviterUid = ::getTblValue("inviterUid", params, inviterUid)
    isAutoAccepted = isAlreadyAccepted()

    if (initial)
      ::add_event_listener("ContactsGroupUpdate",
                           function (p) {
                             if (isAlreadyAccepted())
                               remove()
                           },
                           this)
  }

  function isValid()
  {
    return base.isValid() && !::u.isEmpty(inviterUid)
  }

  function isOutdated()
  {
    return base.isOutdated() || isAlreadyAccepted()
  }

  function isAlreadyAccepted()
  {
    return ::isPlayerInContacts(inviterUid, ::EPL_FRIENDLIST)
  }

  function getInviteText()
  {
    return ::loc("contacts/friend_invitation_recieved/no_nick")
  }

  function getPopupText()
  {
    return ::loc("contacts/popup_friend_invitation_recieved",
      { userName = ::colorize("goodTextColor", getInviterName()) })
  }

  function getIcon()
  {
    return "#ui/gameuiskin#btn_friend_add.svg"
  }

  function accept()
  {
    if (isValid())
      ::editContactMsgBox(::getContact(inviterUid, inviterName), ::EPL_FRIENDLIST, true)
    remove()
  }
}