//checked for plus_string
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let squadsListData = require("%scripts/squads/clanSquadsList.nut")
let squadApplications = require("%scripts/squads/squadApplications.nut")
let { findInviteClass } = require("%scripts/invites/invitesClasses.nut")

const OFFLINE_SQUAD_TEXT_COLOR = "contactOfflineColor"

dagui_propid_add_name_id("leaderUid")

gui_handlers.MyClanSquadsListModal <- class extends gui_handlers.BaseGuiHandlerWT {
  wndType      = handlerType.MODAL
  sceneBlkName = "%gui/clans/clanSquadsModal.blk"
  squadsListObj = null
  dummyButtonsListObj = null
  minListItems = 5
  onlineUsersTable = null

  squadButtonsList = [
    {
      id = "btn_squad_info"
      buttonClass = "image"
      shortcut = ""
      showOnSelect = "hover"
      btnName = "X"
      btnKey = "X"
      tooltip = @() loc("squad/info")
      img = "#ui/gameuiskin#btn_help.svg"
      funcName = "onSquadInfo"
      isHidden = false
      isDisabled = false
    },
    {
      id = "btn_application"
      buttonClass = "image"
      shortcut = ""
      showOnSelect = "hover"
      btnName = "A"
      btnKey = "A"
      tooltip = @() loc("squad/membership_request")
      img = "#ui/gameuiskin#btn_invite.svg"
      funcName = "onApplication"
      isHidden = true
      isDisabled = true
    },
    {
      id = "btn_revoke_application"
      buttonClass = "image"
      shortcut = ""
      showOnSelect = "hover"
      btnName = "A"
      btnKey = "A"
      isColoredImg = "yes"
      tooltip = @() loc("squad/revoke_membership_request")
      img = "#ui/gameuiskin#icon_primary_fail.svg"
      funcName = "onRevokeApplication"
      isHidden = true
      isDisabled = true
    }
  ]

  curList = null
  selectedSquad = null
  selectedIndex = 0

  static function open() {
    ::gui_start_modal_wnd(gui_handlers.MyClanSquadsListModal)
  }

  function initScreen() {
    this.squadsListObj = this.scene.findObject("clan_squads_list")
    this.dummyButtonsListObj = this.scene.findObject("clan_squads_modal")
    if (!checkObj(this.squadsListObj))
      return this.goBack()
    this.curList = []
    this.selectedSquad = null
    this.onlineUsersTable = {}
    let view = { squad = array(this.minListItems, { buttonsList = this.createSquadButtons() }) }
    local blk = handyman.renderCached(("%gui/clans/clanSquadsList.tpl"), view)
    this.guiScene.appendWithBlk(this.squadsListObj, blk, this)

    blk = this.createDummyButtons()
    this.guiScene.appendWithBlk(this.dummyButtonsListObj, blk, this)

    this.scene.findObject("squad_list_update").setUserData(this)

    this.refreshOnlineUsersTable()
    this.updateSquadsList()
    this.updateSquadsListInfo(this.curList.len())
  }

  function createSquadButtons() {
    local markUp = ""
    foreach (buttonView in this.squadButtonsList)
      markUp += handyman.renderCached("%gui/commonParts/button.tpl", buttonView)
    return markUp
  }

  function createDummyButtons() {
    local markUp = ""
    foreach (buttonView in this.squadButtonsList)
      markUp += handyman.renderCached("%gui/commonParts/dummyButton.tpl", buttonView)
    return markUp
  }

  function refreshList() {
    squadsListData.requestList()
  }

  function updateSquadsList() {
    let newList = clone squadsListData.getList()
    let total = max(newList.len(), this.curList.len())
    local isSelected = false
    for (local i = 0; i < total; i++) {
      this.updateSquadInfo(i, this.curList?[i], newList?[i])
      if (!isSelected && u.isEqual(this.selectedSquad, newList?[i]) && (this.selectedIndex != -1)) {
          if (this.selectedIndex != i) {
            this.squadsListObj.setValue(i)
            this.selectedIndex = i
          }
          this.selectedSquad = newList?[i]
          isSelected = true
      }
    }
    this.curList = newList
    if (!isSelected && newList.len() > 0) {
      this.selectedIndex = clamp(this.selectedIndex, 0, newList.len() - 1)
      this.selectedSquad = newList[this.selectedIndex]
      this.squadsListObj.setValue(this.selectedIndex)
    }
    else if (newList.len() <= 0) {
        this.selectedSquad = null
        this.selectedIndex = -1
        ::gui_bhv.posNavigator.clearSelect(this.squadsListObj)
    }
    this.updateSquadDummyButtons()
    this.updateSquadsListInfo(this.curList.len())
  }

  function updateSquadInfo(idx, curSquad, newSquad) {
    if (curSquad == newSquad || (u.isEqual(curSquad, newSquad)))
      return

    let obj = this.getSquadObj(idx)
    let show = newSquad ? true : false
    obj.show(show)
    obj.enable(show)
    if (!show)
      return null
    obj.findObject("leader_name").setValue(this.getLeaderName(newSquad))
    obj.findObject("num_members").setValue(this.getNumMembers(newSquad))
    obj.findObject("btn_user_options").leaderUid = newSquad?.leader
    obj.findObject("btn_squad_info").leaderUid = newSquad?.leader
    obj.findObject("application_disabled").show(
      !(newSquad?.data?.properties?.isApplicationsEnabled ?? true))
    this.fillPresence(obj, newSquad)
    let buttonsContainerObj = obj.findObject("buttons_container")
    buttonsContainerObj.leaderUid = newSquad?.leader

    this.updateSquadButtons(buttonsContainerObj, newSquad)
  }

  function fillPresence(obj, squad) {
    obj.findObject("presence").setValue(!this.isSquadOnline(squad)
      ? colorize(OFFLINE_SQUAD_TEXT_COLOR, loc("matching/SQUAD_LEADER_OFFLINE"))
      : this.getPresence(squad))
  }

  function updateSquadButtons(obj, squad) {
    let show = this.canApplyForMembership(squad)
    let btnObj = showObjById("btn_application", show, obj)
    if (checkObj(btnObj) && show)
      btnObj.tooltip = this.getInvitationInSquad(squad) ? loc("squad/join") : loc("squad/membership_request")

    showObjById("btn_revoke_application", this.canRevokeApplication(squad), obj)
  }

  function updateSquadDummyButtons() {
    if (!this.selectedSquad)
      return
    showObjById("btn_application", this.canApplyForMembership(this.selectedSquad), this.dummyButtonsListObj)
    showObjById("btn_revoke_application", this.canRevokeApplication(this.selectedSquad), this.dummyButtonsListObj)
  }

  function canApplyForMembership(squad) {
    return !squadApplications.hasApplication(squad.leader)
      && !this.isMySquad(squad)
      && (squad?.data?.properties?.isApplicationsEnabled ?? true)
  }

  function canRevokeApplication(squad) {
    return squadApplications.hasApplication(squad.leader)
      && !::g_squad_manager.isInSquad()
  }

  function getInvitationInSquad(squad) {
    let uid = findInviteClass("Squad")?.getUidByParams({ squadId = squad.leader })
    return ::g_invites.findInviteByUid(uid)
  }

  function getSquadObj(idx) {
    if (this.squadsListObj.childrenCount() > idx) {
        return this.squadsListObj.getChild(idx)
    }
    return this.squadsListObj.getChild(idx - 1).getClone(this.squadsListObj, this)
  }

  function isMySquad(squad) {
    if (!::g_squad_manager.isInSquad())
      return false

    return isInArray(::my_user_id_int64, squad?.members ?? [])
      || squad?.leader.tostring() == ::g_squad_manager.getLeaderUid()
  }

  function getLeaderName(squad) {
    let contact = ::getContact(squad?.leader.tostring())
    return contact ? contact.getName() : ""
  }

  function getNumMembers(squad) {
    return loc("squad/size", { numMembers = this.getNumberMembers(squad)
                          maxMembers = this.getMaxMembers(squad) })
  }

  function getPresence(squad) {
    let presenceParams = squad?.data?.presence ?? {}
    return ::g_presence_type.getByPresenceParams(presenceParams).getLocText(presenceParams)
  }

  function onUpdate(_obj, _dt) {
    this.refreshList()
  }

  function updateSquadsListInfo(visibleSquadsAmount) {
    let needWaitIcon = !visibleSquadsAmount && squadsListData.isInUpdate
      && !squadsListData.isListValid()
    this.scene.findObject("items_list_wait_icon").show(needWaitIcon)

    local infoText = ""
    if (!visibleSquadsAmount && squadsListData.isListValid())
      infoText = loc("clan/no_squads_in_clan")

    this.scene.findObject("items_list_msg").setValue(infoText)
  }

  function getNumberMembers(squad) {
    return (squad?.members ?? []).len()
  }

  function getMaxMembers(squad) {
    return squad?.data?.properties?.maxMembers ?? ""
  }

  function onItemSelect(obj) {
    let countListItem = this.curList.len()
    if (countListItem <= 0) {
        this.selectedSquad = null
        this.selectedIndex = -1
        return
    }

    let index = obj.getValue()
    if (index < 0 || index >= countListItem) {
      return
    }

    this.selectedIndex = index
    this.selectedSquad = this.curList[index]
    this.updateSquadDummyButtons()
  }

  function onLeaderClick(obj) {
    let actionSquad = this.getSquadByObj(obj)
    if (!actionSquad)
      return

    obj = this.getSquadObj(this.curList.indexof(actionSquad)).findObject("btn_user_options")
    let position = obj.getPosRC()
    position[1] += obj.getSize()[1]
    let leaderUid = actionSquad?.leader.tostring()
    let contact = leaderUid && ::getContact(leaderUid)
    let leaderName = contact ? contact.getName() : ""
    ::g_chat.showPlayerRClickMenu(leaderName, null, contact, position)
  }

  function getSelectedSquadInHover() {
    if (!this.squadsListObj.isHovered())
      return null

    if (this.selectedIndex < 0 || this.selectedIndex >= this.squadsListObj.childrenCount())
      return null

    let squadObj = this.squadsListObj.getChild(this.selectedIndex)
    if (!squadObj.isHovered())
      return null

    return this.selectedSquad
  }

  function getSquadByObj(obj) {
    if (!obj)
      return null

    let leaderUidStr = obj?.leaderUid ?? obj.getParent()?.leaderUid
    if (!leaderUidStr)
      return this.getSelectedSquadInHover()

    let leaderUid = to_integer_safe(leaderUidStr)
    foreach (squad in this.curList)
      if (squad?.leader && squad?.leader == leaderUid)
        return squad

    return null
  }

  function applicationToSquad(actionSquad) {
    let invite = this.getInvitationInSquad(actionSquad)
    if (invite) {
      invite.accept()
      return
    }

    ::g_squad_manager.membershipAplication(actionSquad?.leader)
  }

  revokeApplication = @(actionSquad) ::g_squad_manager.revokeMembershipAplication(actionSquad?.leader)

  function onApplication(obj) {
    let actionSquad = this.getSquadByObj(obj)
    if (!actionSquad)
      return

    this.applicationToSquad(actionSquad)
  }

  function onRevokeApplication(obj) {
    let actionSquad = this.getSquadByObj(obj)
    if (!actionSquad)
      return

    this.revokeApplication(actionSquad)
  }

  function onSquadInfo(obj) {
    let actionSquad = this.getSquadByObj(obj)
    if (!actionSquad)
      return

    obj = this.getSquadObj(this.curList.indexof(actionSquad)).findObject("btn_squad_info")
    gui_handlers.clanSquadInfoWnd.open(obj, actionSquad)
  }

  function onEventPlayerApplicationsChanged(params) {
    this.updateSquadButtonsByleadersUid(params.leadersArr)
  }

  function onEventClanSquadsListChanged(_params) {
    this.updateSquadsList()
  }

  function onEventClanRoomMembersChanged(params = {}) {
    this.refreshUserOnlineData(params)
  }

  function updateSquadOnlineStatus(contact) {
    let contactUid = contact.uid.tointeger()
    let idx = this.curList.findindex(@(squad) squad.leader == contactUid)
    if (idx == null)
      return

    let obj = this.getSquadObj(idx)
    let squad = this.curList[idx]
    this.fillPresence(obj, squad)
    this.updateSquadButtons(obj, squad)
  }

  function refreshOnlineUsersTable() {
    let roomId = ::g_chat_room_type.CLAN.roomPrefix + ::clan_get_my_clan_id()
    let room = ::g_chat.getRoomById(roomId)
    if (!room || !("users" in room))
      return

    foreach (user in room.users) {
      let contact = ::Contact.getByName(user.name)
      if (contact)
        this.onlineUsersTable[contact.uid.tointeger()] <- true
    }
  }

  function refreshUserOnlineData(params) {
    if (!("nick" in params) || !("presence" in params))
      return

    let contact = ::Contact.getByName(params.nick)
    if (!contact)
      return

    let uid = contact.uid.tointeger()
    this.onlineUsersTable[uid] <- params.presence != ::g_contact_presence.OFFLINE

    this.updateSquadOnlineStatus(contact)
  }

  function isSquadOnline(squad) {
    return this.onlineUsersTable?[squad.leader] ?? false
  }

  function onEventSquadStatusChanged(_params) {
    if (!::g_squad_manager.isInSquad())
      return false

    let leaderUid = ::g_squad_manager.getLeaderUid()
    if (!leaderUid || leaderUid == "")
      return

    this.updateSquadButtonsByleadersUid([leaderUid.tointeger()])
  }

  function onEventInviteReceived(params) {
    let leaderUid = params.invite?.leaderId
    if (!leaderUid)
      return

    this.updateSquadButtonsByleadersUid([leaderUid.tointeger()])
  }

  function updateSquadButtonsByleadersUid(leadersArr) {
    if (!this.curList.len())
      return

    local leader = null
    local obj = null
    for (local i = 0; i < this.curList.len(); i++) {
      leader = this.curList[i].leader
      if (isInArray(leader, leadersArr)) {
        obj = this.getSquadObj(i)
        this.updateSquadButtons(obj, this.curList[i])
      }
    }
    this.updateSquadDummyButtons()
  }

  function onSquadActivate() {
    if (this.canApplyForMembership(this.selectedSquad)) {
      this.applicationToSquad(this.selectedSquad)
      return
    }

    if (this.canRevokeApplication(this.selectedSquad)) {
      this.revokeApplication(this.selectedSquad)
      return
    }
  }
}
