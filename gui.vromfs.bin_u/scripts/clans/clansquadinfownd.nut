from "%scripts/dagui_library.nut" import *

let { getObjIdByPrefix } = require("%scripts/utils_sa.nut")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { setPopupMenuPosAndAlign } = require("%sqDagui/daguiUtil.nut")
let squadsListData = require("%scripts/squads/clanSquadsList.nut")
let { requestUsersInfo } = require("%scripts/user/usersInfoManager.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { contactPresence } = require("%scripts/contacts/contactPresence.nut")
let { getCustomNick } = require("%scripts/contacts/customNicknames.nut")
let { showChatPlayerRClickMenu } = require("%scripts/user/playerContextMenu.nut")

gui_handlers.clanSquadInfoWnd <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType             = handlerType.MODAL
  sceneBlkName   = "%gui/clans/clanSquadInfo.blk"
  needVoiceChat = false
  memberTplName = "%gui/squads/squadMembers.tpl"
  membersObj = null
  align = ALIGN.BOTTOM

  alignObj = null
  squad = null

  selectedMember = null
  selectedIndex = 0

  static function open(alignObj, squad) {
    if (!checkObj(alignObj))
      return null

    let params = {
      alignObj = alignObj
      squad = squad
    }

    return loadHandler(gui_handlers.clanSquadInfoWnd, params)
  }

  function initScreen() {
    this.membersObj = this.scene.findObject("members")
    let viewBlk = handyman.renderCached(this.memberTplName,
      { members = array(this.squad?.data?.propertis?.maxMembers ?? g_squad_manager.getSMMaxSquadSize(), null) })
    this.guiScene.replaceContentFromText(this.membersObj, viewBlk, viewBlk.len(), this)
    this.scene.findObject("squad_info_update").setUserData(this)
    this.refreshList()
    this.updatePosition()

    this.membersObj.setValue(0)
  }

  function refreshList() {
    let leader = this.squad?.leader
    local memberViewIndex = 0
    if (leader == this.selectedMember)
      this.selectedIndex = memberViewIndex
    this.updateMemberView(memberViewIndex++, leader)
    foreach (uid in this.squad?.members ?? []) {
      if (uid == leader)
        continue

      if (uid == this.selectedMember)
        this.selectedIndex = memberViewIndex
      this.updateMemberView(memberViewIndex++, uid)
    }

    while (memberViewIndex < (this.squad?.data?.propertis?.maxMembers ?? g_squad_manager.getSMMaxSquadSize()))
      this.updateMemberView(memberViewIndex++, null)
    this.selectedIndex = clamp(this.selectedIndex, 0, (this.squad?.members ?? []).len() - 1)
    this.membersObj.setValue(this.selectedIndex)
  }

  function updateMemberView(mebmerObjIndex, memberUid) {
    let isVisible = memberUid != null
    let memberObj = this.getSquadObj(mebmerObjIndex)
    memberObj.show(isVisible)
    memberObj.enable(isVisible)
    if (!isVisible || !checkObj(memberObj))
      return

    let memeberUidStr = memberUid.tostring()
    let contact = ::getContact(memeberUidStr)
    if (!contact)
      requestUsersInfo([memeberUidStr])
    memberObj["id"] = $"member_{ memeberUidStr}"
    memberObj.findObject("pilotIconImg").setValue(contact?.pilotIcon ?? "cardicon_bot")
    memberObj.findObject("clanTag").setValue(contact?.clanTag ?? "")
    memberObj.findObject("contactName").setValue(getCustomNick(contact) ?? contact?.getName() ?? "")
    memberObj.findObject("tooltip")["uid"] = memeberUidStr
    memberObj.findObject("not_member_data").show(!contact)
    let statusObj = memberObj.findObject("statusImg")
    if (checkObj(statusObj)) {
      let presence = contact?.presence ?? contactPresence.UNKNOWN
      statusObj["background-image"] = presence.getIcon()
      statusObj["background-color"] = presence.getIconColor()
      statusObj["tooltip"] = presence.getText()
    }
  }

  function getSquadObj(idx) {
    if (this.membersObj.childrenCount() > idx) {
      return this.membersObj.getChild(idx)
    }
    return this.membersObj.getChild(idx - 1).getClone(this.membersObj, this)
  }

  function updatePosition() {
    this.align = setPopupMenuPosAndAlign(this.alignObj, this.align, this.scene.findObject("squad_info"))
  }

  function getMemberUidByObj(obj) {
    local id = getObjIdByPrefix(obj, "member_")
    return id ? id.tointeger() : null
  }

  function onMemberClick(obj) {
    local memberUid = this.getMemberUidByObj(obj)
    obj = memberUid ? obj : this.getSquadObj(this.selectedIndex)
    memberUid = memberUid || this.selectedMember
    if (!memberUid || !checkObj(obj))
      return

    let position = obj.getPosRC()
    position[1] += obj.getSize()[1]
    let contact = ::getContact(memberUid.tostring())
    if (!contact)
      return
    let memberName = contact ? contact.getName() : ""
    showChatPlayerRClickMenu(memberName, null, contact, position)
  }

  function onItemSelect(obj) {
    let countListItem = (this.squad?.members ?? []).len()
    if (countListItem <= 0) {
        this.selectedMember = null
        this.selectedIndex = -1
        return
    }

    let index = obj.getValue()
    this.selectedMember = this.getMemberUidByObj(obj.getChild(index))
    this.selectedIndex = this.selectedMember ? index : -1
  }

  function onEventClanSquadsListChanged(_params) {
    let leader = this.squad.leader
    let newSquad = u.search(squadsListData.getList(), @(s) s?.leader == leader)
    if (!newSquad) {
      this.goBack()
      return
    }
    this.squad = newSquad
    this.doWhenActiveOnce("refreshList")
  }

  function onEventContactsUpdated(_params) {
    this.doWhenActiveOnce("refreshList")
  }

  function onUpdate(_obj, _dt) {
    squadsListData.requestList()
  }
}
