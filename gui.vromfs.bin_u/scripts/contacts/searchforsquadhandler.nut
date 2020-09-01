local platformModule = require("scripts/clientState/platform.nut")
local crossplayModule = require("scripts/social/crossplay.nut")
local xboxContactsManager = require("scripts/contacts/xboxContactsManager.nut")

::gui_start_search_squadPlayer <- function gui_start_search_squadPlayer()
{
  if (!::g_squad_manager.canInviteMember())
  {
    ::showInfoMsgBox(::loc("squad/not_a_leader"), "squad_not_available")
    return
  }

  ::update_ps4_friends()
  xboxContactsManager.updateXboxOneFriends()
  ::handlersManager.loadHandler(::gui_handlers.SearchForSquadHandler)
}

class ::gui_handlers.SearchForSquadHandler extends ::ContactsHandler
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/contacts/contacts.blk"

  curGroup = ::EPL_FRIENDLIST
  searchGroup = ::EPLX_SEARCH
  clanGroup = ::EPLX_CLAN
  searchShowDefaultOnReset = true
  isPrimaryFocus = true

  sg_groups = null

  function initScreen()
  {
    guiScene.setUpdatesEnabled(false, false)

    fillDefaultSearchList()

    local fObj = scene.findObject("contacts_wnd")
    fObj.pos = "0.5(sw-w), 0.4(sh-h)"
    fObj["class"] = ""
    if (::contacts_sizes)
      fObj.size = ::contacts_sizes.size[0] + ", " + ::contacts_sizes.size[1]
    scene.findObject("contacts_backShade").show(true)
    scene.findObject("title").setValue(::loc("mainmenu/btnInvite"))

    sg_groups = [::EPLX_SEARCH, ::EPL_FRIENDLIST, ::EPL_RECENT_SQUAD]
    if(::clan_get_my_clan_id() != "-1" && !::isInArray(clanGroup, sg_groups))
    {
      sg_groups.append(clanGroup)
      if (!(clanGroup in ::contacts))
        ::contacts[clanGroup] <- []
    }
    if (::is_platform_ps4)
    {
      sg_groups.insert(2, ::EPLX_PS4_FRIENDS)
      if (!(::EPLX_PS4_FRIENDS in ::contacts))
        ::contacts[::EPLX_PS4_FRIENDS] <- []
    }

    fillContactsList(sg_groups)
    guiScene.setUpdatesEnabled(true, true)
    initFocusArray()
    closeSearchGroup()
    updateConsoleButtons()
    updateSquadButton()
  }

  function isValid()
  {
    return ::gui_handlers.BaseGuiHandlerWT.isValid.bindenv(this)()
  }

  function goBack()
  {
    ::gui_handlers.BaseGuiHandlerWT.goBack.bindenv(this)()
  }

  function checkScene()
  {
    return checkObj(scene)
  }

  function onPlayerSelect(obj)
  {
    if (!obj) return

    local value = obj.getValue()
    curPlayer = ::getTblValue(value, ::contacts[curGroup])
    updateSquadButton()
  }

  function updateSquadButton()
  {
    local contactName = curPlayer?.name ?? ""
    local isBlock = curPlayer? curPlayer.isInBlockGroup() : false
    local canInteractCrossConsole = platformModule.canInteractCrossConsole(contactName)
    local isXBoxOnePlayer = platformModule.isXBoxPlayerName(contactName)
    local canInteractCrossPlatform = isXBoxOnePlayer || crossplayModule.isCrossPlayEnabled()
    local canInvite = curPlayer? curPlayer.canInvite() : true

    local showSquadInvite = !::show_console_buttons
      && ::has_feature("SquadInviteIngame")
      && !isBlock
      && canInteractCrossConsole
      && canInteractCrossPlatform
      && ::g_squad_manager.canInviteMember(curPlayer?.uid ?? "")
      && ::g_squad_manager.canInviteMemberByPlatform(contactName)
      && !::g_squad_manager.isPlayerInvited(curPlayer?.uid ?? "", contactName)
      && canInvite
      && ::g_squad_utils.canSquad()

    showSceneBtn("btn_squadInvite_bottom", showSquadInvite)
  }

  function onGroupSelect(obj)
  {
    selectItemInGroup(obj, sg_groups, false)
  }

  function onGroupActivate(obj)
  {
    selectItemInGroup(obj, sg_groups, true)
  }

  function onPlayerMsg(obj)
  {
    updateCurPlayer(obj)
    if (curPlayer)
      ::openChatPrivate(curPlayer.name, this)
  }

  function isContactsWindowActive()
  {
    return checkScene()
  }
}