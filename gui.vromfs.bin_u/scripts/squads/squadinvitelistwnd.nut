class ::gui_handlers.squadInviteListWnd extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType             = handlerType.MODAL
  sceneBlkName        = "gui/squads/squadInvites.blk"
  shouldBlurSceneBg   = false

  inviteListTplName   = "gui/squads/squadInvites"

  CONFIG_PLAYERS_LISTS = {
    invites = { listObjId = "invites_list"
      playersList = @() ::g_squad_manager.getInvitedPlayers()
      headerObjId = "invited_players_header"
    }
    applications = { listObjId = "applications_list"
      playersList = @() ::g_squad_manager.getApplicationsToSquad()
      headerObjId = "applications_list_header"
    }
  }
  MAX_COLUMNS = 5
  NEST_OBJ_ID = "squad_invites"

  align = "top"
  alignObj = null

  optionsObj = null

  static function open(alignObj)
  {
    if (!canOpen())
      return null

    if (!::checkObj(alignObj))
      return null

    local params = {
      alignObj = alignObj
    }

    return ::handlersManager.loadHandler(::gui_handlers.squadInviteListWnd, params)
  }

  static function canOpen()
  {
    return ::has_feature("Squad") && ::has_feature("SquadWidget")
      && ::g_squad_manager.isInSquad()
      && (::g_squad_manager.canChangeSquadSize(false) || ::g_squad_manager.getInvitedPlayers().len() > 0
          || ::g_squad_manager.getApplicationsToSquad().len() > 0)
  }

  function initScreen()
  {
    optionsObj = scene.findObject("options_block")

    updateSquadSizeOption()
    updateReceiveApplicationsOption()
    updateInviteesList()
    updateApplicationsList()

    initFocusArray()
    restoreFocus()
  }

  function updateInviteesList()
  {
    updateList(CONFIG_PLAYERS_LISTS.invites)
  }

  function updateApplicationsList()
  {
     updateList(CONFIG_PLAYERS_LISTS.applications)
    ::g_squad_manager.markAllApplicationsSeen()
  }

  function updateList(configPlayersList)
  {
    local playersList = configPlayersList.playersList()
    local listObj = scene.findObject(configPlayersList.listObjId)
    local viewData = getMembersViewData(playersList)
    local viewBlk = ::handyman.renderCached(inviteListTplName, viewData)
    local isFocused = listObj.isFocused()
    local selectedIdx = listObj.getValue()
    local selectedObjId = null
    if ((selectedIdx >= 0) && (selectedIdx < listObj.childrenCount()) && isFocused)
      selectedObjId = listObj.getChild(selectedIdx).id

    guiScene.replaceContentFromText(listObj, viewBlk, viewBlk.len(), this)
    local i = 0
    foreach(memberData in playersList)
    {
      local inviteObjId = "squad_invite_" + memberData.uid
      local inviteObj = listObj.findObject(inviteObjId)
      if (::checkObj(inviteObj))
      {
        if (::u.isEqual(selectedObjId, inviteObjId) && isFocused)
          selectedIdx = i
        inviteObj.setUserData(memberData)
      }
      i++
    }
    local countPlayers = listObj.childrenCount()
    if (isFocused && countPlayers > 0)
      listObj.setValue(clamp(selectedIdx, 0, countPlayers - 1))
    scene.findObject(configPlayersList.headerObjId).show(playersList.len() > 0)
    updateSize(listObj, playersList)
    updatePosition()
  }

  function getMembersViewData(membersData)
  {
    local items = []
    foreach(memberData in membersData)
      items.append(
        {
          id = memberData.uid
          pilotIcon = memberData.pilotIcon
        }
      )

    return { items = items }
  }

  function updateSquadSizeOption()
  {
    local isAvailable = ::g_squad_manager.canChangeSquadSize(false)
    optionsObj.show(isAvailable)
    optionsObj.enable(isAvailable)
    if (!isAvailable)
      return

    local sizes = ::u.map(::g_squad_manager.squadSizesList,
      @(s) s.value + ::loc("ui/comma") + ::loc("squadSize/" + s.name))
    local curValue = ::g_squad_manager.getMaxSquadSize()
    local curIdx = ::g_squad_manager.squadSizesList.findindex(@(s) s.value == curValue) ?? 0

    local optionObj = scene.findObject("squad_size_option")
    local markup = ::create_option_combobox("", sizes, curIdx, null, false)
    guiScene.replaceContentFromText(optionObj, markup, markup.len(), this)
    optionObj.setValue(curIdx)
    optionObj.enable(::g_squad_manager.canChangeSquadSize())
  }

  function updateReceiveApplicationsOption()
  {
    local isAvailable = ::g_squad_manager.canChangeReceiveApplications(false)
    local obj = showSceneBtn("receive_applications", isAvailable)
    if (!isAvailable || !obj)
      return

    obj.setValue(::g_squad_manager.isApplicationsEnabled())
    obj.enable(::g_squad_manager.canChangeReceiveApplications())
  }

  function updateSize(listObj, playersList)
  {
    if (!::checkObj(listObj))
      return

    local total = playersList.len()
    local rows = total && ::ceil(total.tofloat() / MAX_COLUMNS.tofloat())
    local columns = rows && ::ceil(total.tofloat() / rows.tofloat())

    local sizeFormat = "%d@mIco"
    listObj.width = ::format(sizeFormat, columns)
    listObj.height = ::format(sizeFormat, rows)
  }

  function updatePosition()
  {
    local nestObj = scene.findObject(NEST_OBJ_ID)
    if (::checkObj(nestObj))
      align = ::g_dagui_utils.setPopupMenuPosAndAlign(alignObj, align, nestObj)
  }

  function checkActiveForDelayedAction()
  {
    return isSceneActive()
  }

  function onInviteMemberMenu(obj)
  {
    local childrenCount = obj.childrenCount()
    if (!childrenCount)
      return

    local value = ::clamp(obj.getValue(), 0, childrenCount - 1)
    local selectedObj = obj.getChild(value)

    ::g_squad_utils.showMemberMenu(selectedObj)
  }

  function onMemberClicked(obj)
  {
    ::g_squad_utils.showMemberMenu(obj)
  }

  function onSquadSizeChange(obj)
  {
    local idx = obj.getValue()
    if (idx in ::g_squad_manager.squadSizesList)
      ::g_squad_manager.setSquadSize(::g_squad_manager.squadSizesList[idx].value)
  }

  function onReceiveApplications(obj)
  {
    if (!obj)
      return
    local value = obj.getValue()
    if (value == ::g_squad_manager.isApplicationsEnabled())
      return

    ::g_squad_manager.enableApplications(value)
    if (!::g_squad_manager.isApplicationsEnabled() && ::g_squad_manager.getApplicationsToSquad().len() > 0)
      msgBox("denyAllMembershipApplications", ::loc("squad/ConfirmDenyApplications"),
        [
          ["yes", function() { ::g_squad_manager.denyAllAplication() }],
          ["no",  function() {} ],
        ], "no")
  }

  function getMainFocusObj()
  {
    return scene.findObject(CONFIG_PLAYERS_LISTS.invites.listObjId)
  }

  function getMainFocusObj2()
  {
    return scene.findObject(CONFIG_PLAYERS_LISTS.applications.listObjId)
  }

  /**event handlers**/
  function onEventSquadInvitesChanged(params)
  {
    doWhenActiveOnce("updateInviteesList")
  }

  function onEventSquadApplicationsChanged(params)
  {
    doWhenActiveOnce("updateApplicationsList")
  }

  function onEventSquadPropertiesChanged(params)
  {
    doWhenActiveOnce("updateReceiveApplicationsOption")
  }
}
