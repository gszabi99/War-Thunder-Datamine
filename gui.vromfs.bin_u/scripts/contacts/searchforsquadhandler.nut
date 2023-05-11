//-file:plus-string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { canInteractCrossConsole,
        isXBoxPlayerName,
        isPlatformSony } = require("%scripts/clientState/platform.nut")
        let { handlerType } = require("%sqDagui/framework/handlerType.nut")

let crossplayModule = require("%scripts/social/crossplay.nut")
let updateContacts = require("%scripts/contacts/updateContacts.nut")
let { addPromoAction } = require("%scripts/promo/promoActions.nut")
let { addPromoButtonConfig } = require("%scripts/promo/promoButtonsConfig.nut")
let { EPLX_SEARCH, EPLX_CLAN, EPLX_PS4_FRIENDS, contactsWndSizes
} = require("%scripts/contacts/contactsManager.nut")

::gui_start_search_squadPlayer <- function gui_start_search_squadPlayer() {
  if (!::g_squad_manager.canInviteMember()) {
    ::showInfoMsgBox(loc("squad/not_a_leader"), "squad_not_available")
    return
  }

  updateContacts()
  ::handlersManager.loadHandler(::gui_handlers.SearchForSquadHandler)
}

::gui_handlers.SearchForSquadHandler <- class extends ::ContactsHandler {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/contacts/contacts.blk"

  curGroup = EPL_FRIENDLIST
  searchShowDefaultOnReset = true

  sg_groups = null

  function initScreen() {
    this.guiScene.setUpdatesEnabled(false, false)

    this.fillDefaultSearchList()

    let fObj = this.scene.findObject("contacts_wnd")
    fObj.pos = "0.5(sw-w), 0.4(sh-h)"
    fObj["class"] = "wnd"
    if (contactsWndSizes.value != null)
      fObj.size = $"{contactsWndSizes.value.size[0]}, {contactsWndSizes.value.size[1]}"
    this.scene.findObject("contacts_backShade").show(true)
    this.scene.findObject("title").setValue(loc("mainmenu/btnInvite"))
    this.updateSearchContactsGroups()

    this.guiScene.setUpdatesEnabled(true, true)
    this.closeSearchGroup()
    this.selectCurContactGroup()
    this.updateConsoleButtons()
    this.updateSquadButton()
  }

  function isValid() {
    return ::gui_handlers.BaseGuiHandlerWT.isValid.bindenv(this)()
  }

  function goBack() {
    ::gui_handlers.BaseGuiHandlerWT.goBack.bindenv(this)()
  }

  function checkScene() {
    return checkObj(this.scene)
  }

  function onPlayerSelect(obj) {
    base.onPlayerSelect(obj)
    this.updateSquadButton()
  }

  function updateSquadButton() {
    let contactName = this.curPlayer?.name ?? ""
    let isBlock = this.curPlayer ? this.curPlayer.isInBlockGroup() : false
    let isXBoxOnePlayer = isXBoxPlayerName(contactName)
    let canInteractCrossPlatform = isXBoxOnePlayer || crossplayModule.isCrossPlayEnabled()
    let canInvite = this.curPlayer ? this.curPlayer.canInvite() : true

    let showSquadInvite = !::show_console_buttons
      && hasFeature("SquadInviteIngame")
      && !isBlock
      && canInteractCrossConsole(contactName)
      && canInteractCrossPlatform
      && ::g_squad_manager.canInviteMember(this.curPlayer?.uid ?? "")
      && ::g_squad_manager.canInviteMemberByPlatform(contactName)
      && !::g_squad_manager.isPlayerInvited(this.curPlayer?.uid ?? "", contactName)
      && canInvite
      && ::g_squad_utils.canSquad()

    this.showSceneBtn("btn_squadInvite_bottom", showSquadInvite)
  }

  function onPlayerMsg(obj) {
    this.updateCurPlayer(obj)
    if (this.curPlayer)
      ::openChatPrivate(this.curPlayer.name, this)
  }

  function isContactsWindowActive() {
    return this.checkScene()
  }

  function onEventContactsCleared(_p) {
    this.updateSearchContactsGroups()
    this.validateCurGroup()
  }

  function onEventContactsGroupUpdate(p) {
    if (p?.groupName == null) //update all groups
      this.updateSearchContactsGroups()
    base.onEventContactsGroupUpdate(p)
  }

  function updateSearchContactsGroups() {
    this.sg_groups = [EPLX_SEARCH, EPL_FRIENDLIST, EPL_RECENT_SQUAD]
    if (::is_in_clan()) {
      this.sg_groups.append(EPLX_CLAN)
      ::g_clans.updateClanContacts()
    }
    if (isPlatformSony) {
      this.sg_groups.insert(2, EPLX_PS4_FRIENDS)
      if (!(EPLX_PS4_FRIENDS in ::contacts))
        ::contacts[EPLX_PS4_FRIENDS] <- []
    }
    this.fillContactsList()
  }

  getContactsGroups = @() this.sg_groups
}

addPromoAction("squad_contacts", @(_handler, _params, _obj) ::open_search_squad_player())

let promoButtonId = "invite_squad_mainmenu_button"

addPromoButtonConfig({
  promoButtonId = promoButtonId
  updateFunctionInHandler = function() {
    let id = promoButtonId
    let show = !::is_me_newbie() && ::g_promo.getVisibilityById(id)
    let buttonObj = ::showBtn(id, show, this.scene)
    if (!show || !checkObj(buttonObj))
      return

    buttonObj.inactiveColor = ::checkIsInQueue() ? "yes" : "no"
  }
  updateByEvents = ["QueueChangeState"]
})
