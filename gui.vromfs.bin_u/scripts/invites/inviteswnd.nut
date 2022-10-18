from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { checkAndShowMultiplayerPrivilegeWarning,
  isMultiplayerPrivilegeAvailable } = require("%scripts/user/xboxFeatures.nut")

::gui_start_invites <- function gui_start_invites()
{
  ::handlersManager.loadHandler(::gui_handlers.InvitesWnd)
}

::gui_handlers.InvitesWnd <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/chat/invitesWnd.blk"

  isAutoClose = true

  function initScreen()
  {
    updateList()
    initAutoClose()
  }

  function updateList()
  {
    let listObj = this.scene.findObject("invites_list")
    let selInvite = getInviteByObj()
    let list = ::u.filter(::g_invites.list,
      function (invite) { return invite.isVisible() })

    list.sort(function(a, b) {
      if (a.receivedTime != b.receivedTime)
        return a.receivedTime > b.receivedTime ? -1 : 1
      return 0
    })

    let view = { invites = list }
    let data = ::handyman.renderCached("%gui/chat/inviteListRows", view)
    this.guiScene.replaceContentFromText(listObj, data, data.len(), this)

    if (list.len())
    {
      listObj.setValue(::find_in_array(list, selInvite, 0))
      ::move_mouse_on_child_by_value(listObj)
    }

    this.scene.findObject("now_new_invites").show(list.len() == 0)
  }

  function updateSingleInvite(invite)
  {
    let inviteObj = this.scene.findObject("invite_" + invite.uid)
    if (!checkObj(inviteObj))
      return

    inviteObj.findObject("text").setValue(invite.getInviteText())
    inviteObj.findObject("restrictions").setValue(invite.getRestrictionText())
    inviteObj.findObject("accept").inactiveColor = invite.haveRestrictions() ? "yes" : "no"
  }

  function getInviteByObj(obj = null)
  {
    let uid = obj?.inviteUid
    if (uid)
      return ::g_invites.findInviteByUid(uid)

    let listObj = this.scene.findObject("invites_list")
    let value = listObj.getValue() || 0
    if (0 <= value && value < listObj.childrenCount())
      return ::g_invites.findInviteByUid(listObj.getChild(value)?.inviteUid)
    return null
  }

  function onAccept(obj)
  {
    let invite = getInviteByObj(obj)
    if (!invite)
      return

    this.guiScene.performDelayed(this, (@(invite) function() {
      if (invite.haveRestrictions())
      {
        if (invite.needCheckSystemRestriction) {
          if (!isMultiplayerPrivilegeAvailable.value) {
            checkAndShowMultiplayerPrivilegeWarning()
            return
          }

          if (!invite.isAvailableByCrossPlay() && !::xbox_try_show_crossnetwork_message()) {
            ::showInfoMsgBox(invite.getRestrictionText())
            return
          }
        }
        else
          ::showInfoMsgBox(invite.getRestrictionText())

        return
      }

      invite.accept()
      if (isAutoClose)
        this.goBack()
    })(invite))
  }

  function onReject(obj)
  {
    let invite = getInviteByObj(obj)
    if (!invite)
      return

    this.guiScene.performDelayed(this, (@(invite) function() {
      invite.reject()
    })(invite))
  }

  function initAutoClose()
  {
    isAutoClose = ::loadLocalByAccount("wnd/invites_auto_close", true)
    this.scene.findObject("auto_close").setValue(isAutoClose)
  }

  function onAutoCloseChange(obj)
  {
    if (!obj)
      return
    let value = obj.getValue()
    if (value == isAutoClose)
      return

    isAutoClose = value
    ::saveLocalByAccount("wnd/invites_auto_close", isAutoClose)
  }

  function onInviterInfo(obj)
  {
    let invite = getInviteByObj(obj)
    if (invite)
      invite.showInviterMenu()
  }

  function onInviterInfoAccessKey()
  {
    let invite = getInviteByObj()
    if (!invite)
      return

    if (!invite.hasInviter())
      return

    local pos = null
    let nameObj = this.scene.findObject("inviterName_" + invite.uid)
    if (checkObj(nameObj))
    {
      pos = nameObj.getPosRC()
      pos[0] += nameObj.getSize()[0]
    }
    invite.showInviterMenu(pos)
  }

  function onEventInviteReceived(_p)
  {
    updateList()
  }

  function onEventInviteRemoved(_p)
  {
    updateList()
  }

  function onEventXboxMultiplayerPrivilegeUpdated(_p) {
    updateList()
  }

  function onEventInviteUpdated(p)
  {
    updateSingleInvite(p.invite)
  }

  function onEventChatOpenPrivateRoom(_p)
  {
    this.goBack() //close invites menu when open private caht message in scene behind
  }

  function onDestroy()
  {
    ::g_invites.markAllSeen()
  }
}
