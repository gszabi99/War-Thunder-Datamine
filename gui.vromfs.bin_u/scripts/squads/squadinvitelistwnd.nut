from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let { format } = require("string")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

::gui_handlers.squadInviteListWnd <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType             = handlerType.MODAL
  sceneBlkName        = "%gui/squads/squadInvites.blk"

  inviteListTplName   = "%gui/squads/squadInvites"

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

    if (!checkObj(alignObj))
      return null

    let params = {
      alignObj = alignObj
    }

    return ::handlersManager.loadHandler(::gui_handlers.squadInviteListWnd, params)
  }

  static function canOpen()
  {
    return hasFeature("Squad") && hasFeature("SquadWidget")
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
    let playersList = configPlayersList.playersList()
    let listObj = scene.findObject(configPlayersList.listObjId)
    let viewData = getMembersViewData(playersList)
    let viewBlk = ::handyman.renderCached(inviteListTplName, viewData)
    let isFocused = listObj.isFocused()
    local selectedIdx = listObj.getValue()
    local selectedObjId = null
    if ((selectedIdx >= 0) && (selectedIdx < listObj.childrenCount()) && isFocused)
      selectedObjId = listObj.getChild(selectedIdx).id

    guiScene.replaceContentFromText(listObj, viewBlk, viewBlk.len(), this)
    local i = 0
    foreach(memberData in playersList)
    {
      let inviteObjId = "squad_invite_" + memberData.uid
      let inviteObj = listObj.findObject(inviteObjId)
      if (checkObj(inviteObj))
      {
        if (::u.isEqual(selectedObjId, inviteObjId) && isFocused)
          selectedIdx = i
        inviteObj.setUserData(memberData)
      }
      i++
    }
    let countPlayers = listObj.childrenCount()
    if (isFocused && countPlayers > 0)
      listObj.setValue(clamp(selectedIdx, 0, countPlayers - 1))
    scene.findObject(configPlayersList.headerObjId).show(playersList.len() > 0)
    updateSize(listObj, playersList)
    updatePosition()
  }

  function getMembersViewData(membersData)
  {
    let items = []
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
    let isAvailable = ::g_squad_manager.canChangeSquadSize(false)
    optionsObj.show(isAvailable)
    optionsObj.enable(isAvailable)
    if (!isAvailable)
      return

    let sizes = ::u.map(::g_squad_manager.squadSizesList,
      @(s) s.value + loc("ui/comma") + loc("squadSize/" + s.name))
    let curValue = ::g_squad_manager.getMaxSquadSize()
    let curIdx = ::g_squad_manager.squadSizesList.findindex(@(s) s.value == curValue) ?? 0

    let optionObj = scene.findObject("squad_size_option")
    let markup = ::create_option_combobox("", sizes, curIdx, null, false)
    guiScene.replaceContentFromText(optionObj, markup, markup.len(), this)
    optionObj.setValue(curIdx)
    optionObj.enable(::g_squad_manager.canChangeSquadSize())
  }

  function updateReceiveApplicationsOption()
  {
    let isAvailable = ::g_squad_manager.canChangeReceiveApplications(false)
    let obj = this.showSceneBtn("receive_applications", isAvailable)
    if (!isAvailable || !obj)
      return

    obj.setValue(::g_squad_manager.isApplicationsEnabled())
    obj.enable(::g_squad_manager.canChangeReceiveApplications())
  }

  function updateSize(listObj, playersList)
  {
    if (!checkObj(listObj))
      return

    let total = playersList.len()
    let rows = total && ::ceil(total.tofloat() / MAX_COLUMNS.tofloat())
    let columns = rows && ::ceil(total.tofloat() / rows.tofloat())

    let sizeFormat = "%d@mIco"
    listObj.width = format(sizeFormat, columns)
    listObj.height = format(sizeFormat, rows)
  }

  function updatePosition()
  {
    let nestObj = scene.findObject(NEST_OBJ_ID)
    if (checkObj(nestObj))
      align = ::g_dagui_utils.setPopupMenuPosAndAlign(alignObj, align, nestObj)
  }

  function checkActiveForDelayedAction()
  {
    return isSceneActive()
  }

  function onMemberClicked(obj)
  {
    ::g_squad_utils.showMemberMenu(obj)
  }

  function onSquadSizeChange(obj)
  {
    let idx = obj.getValue()
    if (idx in ::g_squad_manager.squadSizesList)
      ::g_squad_manager.setSquadSize(::g_squad_manager.squadSizesList[idx].value)
  }

  function onReceiveApplications(obj)
  {
    if (!obj)
      return
    let value = obj.getValue()
    if (value == ::g_squad_manager.isApplicationsEnabled())
      return

    ::g_squad_manager.enableApplications(value)
    if (!::g_squad_manager.isApplicationsEnabled() && ::g_squad_manager.getApplicationsToSquad().len() > 0)
      this.msgBox("denyAllMembershipApplications", loc("squad/ConfirmDenyApplications"),
        [
          ["yes", function() { ::g_squad_manager.denyAllAplication() }],
          ["no",  function() {} ],
        ], "no")
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
