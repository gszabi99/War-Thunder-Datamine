local { canInteractCrossConsole,
        isXBoxPlayerName,
        isPlatformSony } = require("scripts/clientState/platform.nut")
local crossplayModule = require("scripts/social/crossplay.nut")
local { updateContacts } = require("scripts/contacts/contactsManager.nut")

::gui_start_search_squadPlayer <- function gui_start_search_squadPlayer()
{
  if (!::g_squad_manager.canInviteMember())
  {
    ::showInfoMsgBox(::loc("squad/not_a_leader"), "squad_not_available")
    return
  }

  updateContacts()
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
    updateSearchContactsGroups()

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
    local isXBoxOnePlayer = isXBoxPlayerName(contactName)
    local canInteractCrossPlatform = isXBoxOnePlayer || crossplayModule.isCrossPlayEnabled()
    local canInvite = curPlayer? curPlayer.canInvite() : true

    local showSquadInvite = !::show_console_buttons
      && ::has_feature("SquadInviteIngame")
      && !isBlock
      && canInteractCrossConsole(contactName)
      && canInteractCrossPlatform
      && ::g_squad_manager.canInviteMember(curPlayer?.uid ?? "")
      && ::g_squad_manager.canInviteMemberByPlatform(contactName)
      && !::g_squad_manager.isPlayerInvited(curPlayer?.uid ?? "", contactName)
      && canInvite
      && ::g_squad_utils.canSquad()

    showSceneBtn("btn_squadInvite_bottom", showSquadInvite)
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

  function onEventContactsCleared(p) {
    updateSearchContactsGroups()
    validateCurGroup()
  }

  function updateSearchContactsGroups() {
    sg_groups = [::EPLX_SEARCH, ::EPL_FRIENDLIST, ::EPL_RECENT_SQUAD]
    if(::is_in_clan()) {
      sg_groups.append(clanGroup)
      ::g_clans.updateClanContacts()
    }
    if (isPlatformSony)
    {
      sg_groups.insert(2, ::EPLX_PS4_FRIENDS)
      if (!(::EPLX_PS4_FRIENDS in ::contacts))
        ::contacts[::EPLX_PS4_FRIENDS] <- []
    }
    fillContactsList()
  }

  getContactsGroups = @() sg_groups
}