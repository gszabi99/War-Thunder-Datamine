::gui_start_invites <- function gui_start_invites()
{
  ::handlersManager.loadHandler(::gui_handlers.InvitesWnd)
}

class ::gui_handlers.InvitesWnd extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/chat/invitesWnd.blk"

  isAutoClose = true

  function initScreen()
  {
    updateList()
    initAutoClose()
  }

  function updateList()
  {
    local listObj = scene.findObject("invites_list")
    local selInvite = getInviteByObj()
    local list = ::u.filter(::g_invites.list,
      function (invite) { return invite.isVisible() })

    list.sort(function(a, b) {
      if (a.receivedTime != b.receivedTime)
        return a.receivedTime > b.receivedTime ? -1 : 1
      return 0
    })

    local view = { invites = list }
    local data = ::handyman.renderCached("gui/chat/inviteListRows", view)
    guiScene.replaceContentFromText(listObj, data, data.len(), this)
    listObj.select()

    if (list.len())
      listObj.setValue(::find_in_array(list, selInvite, 0))

    scene.findObject("now_new_invites").show(list.len() == 0)
  }

  function updateSingleInvite(invite)
  {
    local inviteObj = scene.findObject("invite_" + invite.uid)
    if (!::check_obj(inviteObj))
      return

    inviteObj.findObject("text").setValue(invite.getInviteText())
    inviteObj.findObject("restrictions").setValue(invite.getRestrictionText())
    inviteObj.findObject("accept").inactiveColor = invite.haveRestrictions() ? "yes" : "no"
  }

  function getInviteByObj(obj = null)
  {
    local uid = obj?.inviteUid
    if (uid)
      return ::g_invites.findInviteByUid(uid)

    local listObj = scene.findObject("invites_list")
    local value = listObj.getValue() || 0
    if (0 <= value && value < listObj.childrenCount())
      return ::g_invites.findInviteByUid(listObj.getChild(value)?.inviteUid)
    return null
  }

  function onAccept(obj)
  {
    local invite = getInviteByObj(obj)
    if (!invite)
      return

    guiScene.performDelayed(this, (@(invite) function() {
      if (invite.haveRestrictions())
      {
        if (invite.needCheckSystemCrossplayRestriction
            && !invite.isAvailableByCrossPlay()) {
          if (!::xbox_try_show_crossnetwork_message())
            ::showInfoMsgBox(invite.getRestrictionText())
        }
        else
          ::showInfoMsgBox(invite.getRestrictionText())

        return
      }

      invite.accept()
      if (isAutoClose)
        goBack()
    })(invite))
  }

  function onReject(obj)
  {
    local invite = getInviteByObj(obj)
    if (!invite)
      return

    guiScene.performDelayed(this, (@(invite) function() {
      invite.reject()
    })(invite))
  }

  function initAutoClose()
  {
    isAutoClose = ::loadLocalByAccount("wnd/invites_auto_close", true)
    scene.findObject("auto_close").setValue(isAutoClose)
  }

  function onAutoCloseChange(obj)
  {
    if (!obj)
      return
    local value = obj.getValue()
    if (value == isAutoClose)
      return

    isAutoClose = value
    ::saveLocalByAccount("wnd/invites_auto_close", isAutoClose)
  }

  function onInviterInfo(obj)
  {
    local invite = getInviteByObj(obj)
    if (invite)
      invite.showInviterMenu()
  }

  function onInviterInfoAccessKey()
  {
    local invite = getInviteByObj()
    if (!invite)
      return

    if (!invite.hasInviter())
      return

    local pos = null
    local nameObj = scene.findObject("inviterName_" + invite.uid)
    if (::checkObj(nameObj))
    {
      pos = nameObj.getPosRC()
      pos[0] += nameObj.getSize()[0]
    }
    invite.showInviterMenu(pos)
  }

  function onEventInviteReceived(p)
  {
    updateList()
  }

  function onEventInviteRemoved(p)
  {
    updateList()
  }

  function onEventInviteUpdated(p)
  {
    updateSingleInvite(p.invite)
  }

  function onEventChatOpenPrivateRoom(p)
  {
    goBack() //close invites menu when open private caht message in scene behind
  }

  function onDestroy()
  {
    ::g_invites.markAllSeen()
  }
}
