local squadsListData = require("scripts/squads/clanSquadsList.nut")

class ::gui_handlers.clanSquadInfoWnd extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType             = handlerType.MODAL
  sceneBlkName   = "gui/clans/clanSquadInfo.blk"
  needVoiceChat = false
  memberTplName = "gui/squads/squadMembers"
  membersObj = null
  align = AL_ORIENT.BOTTOM

  alignObj = null
  squad = null

  selectedMember = null
  selectedIndex = 0

  static function open(alignObj, squad)
  {
    if (!::checkObj(alignObj))
      return null

    local params = {
      alignObj = alignObj
      squad = squad
    }

    return ::handlersManager.loadHandler(::gui_handlers.clanSquadInfoWnd, params)
  }

  function initScreen()
  {
    membersObj = scene.findObject("members")
    local viewBlk = ::handyman.renderCached(memberTplName,
      {members = array(squad?.data?.propertis?.maxMembers ?? ::g_squad_manager.MAX_SQUAD_SIZE, null)})
    guiScene.replaceContentFromText(membersObj, viewBlk, viewBlk.len(), this)
    scene.findObject("squad_info_update").setUserData(this)
    refreshList()
    updatePosition()

    membersObj.setValue(0)
  }

  function refreshList()
  {
    local leader = squad?.leader
    local memberViewIndex = 0
    if (leader == selectedMember)
      selectedIndex = memberViewIndex
    updateMemberView(memberViewIndex++, leader)
    foreach(uid in squad?.members ?? [])
    {
      if (uid == leader)
        continue

      if (uid == selectedMember)
        selectedIndex = memberViewIndex
      updateMemberView(memberViewIndex++, uid)
    }

    while (memberViewIndex < (squad?.data?.propertis?.maxMembers ?? ::g_squad_manager.MAX_SQUAD_SIZE))
      updateMemberView(memberViewIndex++, null)
    selectedIndex = clamp(selectedIndex, 0, (squad?.members ?? []).len() - 1)
    membersObj.setValue(selectedIndex)
  }

  function updateMemberView(mebmerObjIndex, memberUid)
  {
    local isVisible = memberUid != null
    local memberObj = getSquadObj(mebmerObjIndex)
    memberObj.show(isVisible)
    memberObj.enable(isVisible)
    if (!isVisible || !::checkObj(memberObj))
      return

    local memeberUidStr = memberUid.tostring()
    local contact = getContact(memeberUidStr)
    if (!contact)
      ::g_users_info_manager.requestInfo([memeberUidStr])
    memberObj["id"] = "member_" + memeberUidStr
    memberObj.findObject("pilotIconImg").setValue(contact?.pilotIcon ?? "cardicon_bot")
    memberObj.findObject("clanTag").setValue(contact?.clanTag ?? "")
    memberObj.findObject("contactName").setValue(contact? contact.getName(): "")
    memberObj.findObject("tooltip")["uid"] = memeberUidStr
    memberObj.findObject("not_member_data").show(contact? false : true)
    local statusObj = memberObj.findObject("statusImg")
    if (::checkObj(statusObj))
    {
      local presence = contact?.presence ?? ::g_contact_presence.UNKNOWN
      statusObj["background-image"] = presence.getIcon()
      statusObj["background-color"] = presence.getIconColor()
      statusObj["tooltip"] = presence.getText()
    }
  }

  function getSquadObj(idx)
  {
    if (membersObj.childrenCount() > idx) {
      return membersObj.getChild(idx)
    }
    return membersObj.getChild(idx-1).getClone(membersObj, this)
  }

  function updatePosition()
  {
    align = ::g_dagui_utils.setPopupMenuPosAndAlign(alignObj, align, scene.findObject("squad_info"))
  }

  function getMemberUidByObj(obj)
  {
    local id = ::getObjIdByPrefix(obj, "member_")
    return id ? id.tointeger() : null
  }

  function onMemberClick(obj)
  {
    local memberUid = getMemberUidByObj(obj)
    obj =memberUid? obj : getSquadObj(selectedIndex)
    memberUid = memberUid || selectedMember
    if (!memberUid || !::checkObj(obj))
      return

    local position = obj.getPosRC()
    position[1] += obj.getSize()[1]
    local contact = ::getContact(memberUid.tostring())
    if (!contact)
      return
    local memberName = contact? contact.getName(): ""
    ::g_chat.showPlayerRClickMenu(memberName, null, contact, position)
  }

  function onItemSelect(obj)
  {
    local countListItem = (squad?.members ?? []).len()
    if (countListItem <= 0)
      {
        selectedMember = null
        selectedIndex = -1
        return
      }

    local index = obj.getValue()
    selectedMember = getMemberUidByObj(obj.getChild(index))
    selectedIndex = selectedMember ? index : -1
  }

  function onEventClanSquadsListChanged(params)
  {
    local leader = squad.leader
    local newSquad = ::u.search(squadsListData.getList(), @(s) s?.leader == leader)
    if (!newSquad)
    {
      goBack()
      return
    }
    squad = newSquad
    doWhenActiveOnce("refreshList")
  }

  function onEventContactsUpdated(params)
  {
    doWhenActiveOnce("refreshList")
  }

  function onUpdate(obj, dt)
  {
    squadsListData.requestList()
  }
}
