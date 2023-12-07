from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { loadLocalByAccount, saveLocalByAccount } = require("%scripts/clientState/localProfile.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { move_mouse_on_child_by_value, handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { checkAndShowMultiplayerPrivilegeWarning, checkAndShowCrossplayWarning,
  isMultiplayerPrivilegeAvailable } = require("%scripts/user/xboxFeatures.nut")
let { isShowGoldBalanceWarning } = require("%scripts/user/balanceFeatures.nut")
let { getSelectedChild } = require("%sqDagui/daguiUtil.nut")
let { clearBorderSymbols, utf8ToLower } = require("%sqstd/string.nut")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let { resetTimeout } = require("dagor.workcycle")

const INVITES_PER_PAGE = 30
const MORE_BTN_ID = "showMoreBtn"
const LIST_UPDATE_TIMER_ID = "timer_invite_list_update"

::gui_start_invites <- function gui_start_invites() {
  handlersManager.loadHandler(gui_handlers.InvitesWnd)
}

gui_handlers.InvitesWnd <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/chat/invitesWnd.blk"

  isAutoClose = true
  showedInvites = INVITES_PER_PAGE
  searchString = ""
  invitesList = null

  function initScreen() {
    this.updateList()
    this.initAutoClose()
    let listObj = this.scene.findObject("invites_list")
    listObj.setValue(0)
    move_mouse_on_child_by_value(listObj)
  }

  function createInvitesObjInList(listObj, count) {
    this.guiScene.createMultiElementsByObject(listObj, "%gui/chat/inviteListRows.blk", "expandable", count, this)
  }

  function updateListView() {
    let filterText = utf8ToLower(clearBorderSymbols(this.searchString))
    let list = filterText == "" ? this.invitesList
      : this.invitesList.filter(@(invite) getPlayerName(invite.inviterNameToLower).indexof(filterText) != null)
    let listObj = this.scene.findObject("invites_list")
      this.guiScene.setUpdatesEnabled(false, false)
    let isFullListVisible = this.showedInvites >= list.len()
    let childrenCount = listObj.childrenCount()
    if (this.showedInvites > childrenCount)
      this.createInvitesObjInList(listObj, this.showedInvites - childrenCount)
    let lastIdx = listObj.childrenCount() - 1
    for (local fIdx = 0; fIdx <= lastIdx; fIdx++) {
      let obj = listObj.getChild(fIdx)
      let invite = list?[fIdx]
      if (invite == null) {
        obj.show(false)
        obj.enable(false)
        continue
      }
      obj.show(true)
      obj.enable(true)
      if (!isFullListVisible && ((this.showedInvites - 1) == fIdx)) {
        obj.id = MORE_BTN_ID
        showObjById("inviterBlock", false, obj)
        obj.findObject("inviteIcon")["background-image"] = ""
        obj.findObject("inviteText").setValue(loc("mainmenu/showMore"))
        obj.findObject("restrictions").setValue("")
        showObjById("buttonsPlace", false, obj)
        continue
      }

      let { uid } = invite
      obj.id = $"invite_{uid}"
      obj.inviteUid = uid
      let hasInviter = invite.hasInviter()
      let inviterBlockObj = showObjById("inviterBlock", hasInviter, obj)
      if (hasInviter) {
        let inviterNameObj = inviterBlockObj.findObject("inviterName")
        inviterNameObj.inviteUid = uid
        inviterNameObj.setValue(invite.getInviterName())
      }
      obj.findObject("inviteIcon")["background-image"] = invite.getIcon()
      obj.findObject("inviteText").setValue(invite.getInviteText())
      obj.findObject("restrictions").setValue(invite.getRestrictionText())
      showObjById("buttonsPlace", true, obj)
      let acceptBtnObj = obj.findObject("acceptBtn")
      acceptBtnObj.inviteUid = uid
      acceptBtnObj.inactiveColor = invite.haveRestrictions() ? "yes" : "no"
      obj.findObject("rejectBtn").inviteUid = uid
    }
    this.guiScene.setUpdatesEnabled(true, true)
  }

  function updateList() {
    this.invitesList = ::g_invites.list.filter(@(invite) invite.isVisible())
    let hasInvites = this.invitesList.len() > 0
    this.scene.findObject("invites_list_place").show(hasInvites)
    this.scene.findObject("now_new_invites").show(!hasInvites)
    if (!hasInvites)
      return

    this.invitesList.sort(@(a, b) b.receivedTime <=> a.receivedTime)
    this.updateListView()
  }

  function updateSingleInvite(invite) {
    let inviteObj = this.scene.findObject($"invite_{invite.uid}")
    if (!checkObj(inviteObj))
      return

    inviteObj.findObject("inviteText").setValue(invite.getInviteText())
    inviteObj.findObject("restrictions").setValue(invite.getRestrictionText())
    inviteObj.findObject("acceptBtn").inactiveColor = invite.haveRestrictions() ? "yes" : "no"
  }

  function getInviteByObj(obj = null) {
    let uid = obj?.inviteUid
    if (uid)
      return ::g_invites.findInviteByUid(uid)

    let listObj = this.scene.findObject("invites_list")
    let value = listObj.getValue() || 0
    if (0 <= value && value < listObj.childrenCount())
      return ::g_invites.findInviteByUid(listObj.getChild(value)?.inviteUid)
    return null
  }

  function onAccept(obj) {
    let invite = this.getInviteByObj(obj)
    if (!invite)
      return

    this.guiScene.performDelayed(this, function() {
      if (invite.haveRestrictions()) {
        if (invite.needCheckSystemRestriction) {
          if (!isMultiplayerPrivilegeAvailable.value) {
            checkAndShowMultiplayerPrivilegeWarning()
            return
          }

          if (isShowGoldBalanceWarning())
            return

          if (!invite.isAvailableByCrossPlay()) {
            checkAndShowCrossplayWarning(@() showInfoMsgBox(invite.getRestrictionText()))
            return
          }
        }
        else
          showInfoMsgBox(invite.getRestrictionText())

        return
      }

      invite.accept()
      if (this.isAutoClose)
        this.goBack()
    })
  }

  function onReject(obj) {
    let invite = this.getInviteByObj(obj)
    if (!invite)
      return

    this.guiScene.performDelayed(this, @() invite.reject())
  }

  function initAutoClose() {
    this.isAutoClose = loadLocalByAccount("wnd/invites_auto_close", true)
    this.scene.findObject("auto_close").setValue(this.isAutoClose)
  }

  function onAutoCloseChange(obj) {
    if (!obj)
      return
    let value = obj.getValue()
    if (value == this.isAutoClose)
      return

    this.isAutoClose = value
    saveLocalByAccount("wnd/invites_auto_close", this.isAutoClose)
  }

  function onInviterInfo(obj) {
    let invite = this.getInviteByObj(obj)
    if (invite)
      invite.showInviterMenu()
  }

  function onInviterInfoAccessKey() {
    let invite = this.getInviteByObj()
    if (!invite)
      return

    if (!invite.hasInviter())
      return

    let inviteObj = this.scene.findObject($"invite_{invite.uid}")
    if (!(inviteObj?.isValid() ?? false))
      return
    inviteObj.scrollToView()
    let nameObj = inviteObj.findObject("inviterName")
    let pos = nameObj.getPosRC()
    pos[0] += nameObj.getSize()[0]
    invite.showInviterMenu(pos)
  }

  function onEventInviteReceived(_p) {
    this.updateList()
  }

  function onEventInviteRemoved(_p) {
    this.updateList()
  }

  function onEventXboxMultiplayerPrivilegeUpdated(_p) {
    this.updateList()
  }

  function onEventInviteUpdated(p) {
    this.updateSingleInvite(p.invite)
  }

  function onEventChatOpenPrivateRoom(_p) {
    this.goBack() //close invites menu when open private caht message in scene behind
  }

  function onDestroy() {
    ::g_invites.markAllSeen()
  }

  function onInviteSelect(obj) {
    let childId = getSelectedChild(obj)?.id ?? ""
    if (childId != MORE_BTN_ID)
      return
    this.showedInvites = this.showedInvites + INVITES_PER_PAGE
    this.updateListView()
  }

  function searchCancel() {
    this.searchString = ""
    this.scene.findObject("search_edit_box").setValue("")
    this.updateList()
  }

  function onSearchEditBoxCancelEdit() {
    if (this.searchString != "")
      this.searchCancel()
    else
      this.goBack()
  }

  function onSearchEditBoxChangeValue(obj) {
    this.searchString = obj.getValue()
    resetTimeout(0.3, (@() (this?.isValid() ?? false) ? this.updateListView() : null).bindenv(this), LIST_UPDATE_TIMER_ID)
  }
}
