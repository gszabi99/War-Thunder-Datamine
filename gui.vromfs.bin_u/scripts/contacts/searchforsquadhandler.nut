local { canInteractCrossConsole,
        isXBoxPlayerName,
        isPlatformSony } = require("scripts/clientState/platform.nut")
local crossplayModule = require("scripts/social/crossplay.nut")
local { updateContacts } = require("scripts/contacts/contactsManager.nut")
local { addPromoAction } = require("scripts/promo/promoActions.nut")
local { addPromoButtonConfig } = require("scripts/promo/promoButtonsConfig.nut")

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

  sg_groups = null

  function initScreen()
  {
    guiScene.setUpdatesEnabled(false, false)

    fillDefaultSearchList()

    local fObj = scene.findObject("contacts_wnd")
    fObj.pos = "0.5(sw-w), 0.4(sh-h)"
    fObj["class"] = "wnd"
    if (::contacts_sizes)
      fObj.size = ::contacts_sizes.size[0] + ", " + ::contacts_sizes.size[1]
    scene.findObject("contacts_backShade").show(true)
    scene.findObject("title").setValue(::loc("mainmenu/btnInvite"))
    updateSearchContactsGroups()

    guiScene.setUpdatesEnabled(true, true)
    closeSearchGroup()
    selectCurContactGroup()
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
    curPlayer = ::contacts[curGroup]?[obj.getValue()]
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

addPromoAction("squad_contacts", @(handler, params, obj) ::open_search_squad_player())

local promoButtonId = "invite_squad_mainmenu_button"

addPromoButtonConfig({
  promoButtonId = promoButtonId
  updateFunctionInHandler = function() {
    local id = promoButtonId
    local show = !::is_me_newbie() && ::g_promo.getVisibilityById(id)
    local buttonObj = ::showBtn(id, show, scene)
    if (!show || !::checkObj(buttonObj))
      return

    buttonObj.inactiveColor = ::checkIsInQueue() ? "yes" : "no"
  }
  updateByEvents = ["QueueChangeState"]
})
