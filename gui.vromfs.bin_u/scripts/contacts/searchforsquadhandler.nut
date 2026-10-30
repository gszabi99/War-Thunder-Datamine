from "%scripts/social/crossplay.nut" import isCrossPlayEnabled, canInteractCrossConsole
import "%scripts/contacts/updateContacts.nut" as updateContacts
import "%scripts/queue/queueTypeBit.nut" as QUEUE_TYPE_BIT
from "%scripts/squads/squadManager.nut" import g_squad_manager
from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler, get_gui_handler
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%sqstd/platform.nut" import isSony
from "%appGlobals/clientState/platform.nut" import isXBoxPlayerName
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/contacts/contactsListState.nut" import contactsWndSizes
from "%scripts/options/consoleMode.nut" import showConsoleButtons
from "%scripts/queue/queueManager.nut" import checkQueueAndStart
from "%scripts/clans/clanActions.nut" import updateClanContacts
from "%scripts/squads/squadUtils.nut" import canSquad
from "%scripts/chat/openChat.nut" import openChatPrivate
from "eventbus" import eventbus_subscribe
from "%globalScripts/externalPlayerListConsts.nut" import *
from "%scripts/dagui_library.nut" import *
from "%scripts/clans/clanState.nut" import is_in_clan
from "%scripts/contacts/contactsConsts.nut" import EPLX_SEARCH, EPLX_CLAN, EPLX_PS4_FRIENDS

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { contactsByGroups } = require("%scripts/contacts/contactsListState.nut")
let ContactsHandler = require("%scripts/contacts/contactsHandler.nut")

function guiStartSearchSquadPlayer(_ = null) {
  if (!g_squad_manager.canInviteMember()) {
    showInfoMsgBox(loc("squad/not_a_leader"), "squad_not_available")
    return
  }

  updateContacts()
  handlersManager.loadHandler(get_gui_handler("SearchForSquadHandler"))
}

function openSearchSquadPlayer() {
  checkQueueAndStart(guiStartSearchSquadPlayer, null,
    "isCanModifyQueueParams", QUEUE_TYPE_BIT.DOMINATION | QUEUE_TYPE_BIT.NEWBIE)
}

eventbus_subscribe("guiStartSearchSquadPlayer", guiStartSearchSquadPlayer)

let SearchForSquadHandler = class (ContactsHandler) {
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
    if (contactsWndSizes.get() != null)
      fObj.size = $"{contactsWndSizes.get().size[0]}, {contactsWndSizes.get().size[1]}"
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
    return BaseGuiHandlerWT.isValid.bindenv(this)()
  }

  function goBack() {
    BaseGuiHandlerWT.goBack.bindenv(this)()
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
    let canInteractCrossPlatform = isXBoxOnePlayer || isCrossPlayEnabled()

    local thisCapture = this
    local checkIfPlayerCanInvite = function(callback) {
      if (thisCapture.curPlayer) {
        thisCapture.curPlayer.checkCanInvite(callback)
      } else {
        callback?(true)
      }
    }

    checkIfPlayerCanInvite(function(canInvite) {
      let showSquadInvite = !showConsoleButtons.get()
        && !isBlock
        && canInteractCrossConsole(contactName)
        && canInteractCrossPlatform
        && g_squad_manager.canInviteMember(thisCapture.curPlayer?.uid ?? "")
        && g_squad_manager.canInviteMemberByPlatform(contactName)
        && !g_squad_manager.isPlayerInvited(thisCapture.curPlayer?.uid ?? "", contactName)
        && canInvite
        && canSquad()

      showObjById("btn_squadInvite_bottom", showSquadInvite, thisCapture.scene)
    })
  }

  function onPlayerMsg(obj) {
    this.updateCurPlayer(obj)
    if (this.curPlayer)
      openChatPrivate(this.curPlayer.name, this)
  }

  function isContactsWindowActive() {
    return this.checkScene()
  }

  function onEventContactsCleared(_p) {
    this.updateSearchContactsGroups()
    this.validateCurGroup()
  }

  function onEventContactsGroupUpdate(p) {
    if (p?.groupName == null) 
      this.updateSearchContactsGroups()
    base.onEventContactsGroupUpdate(p)
  }

  function updateSearchContactsGroups() {
    this.sg_groups = [EPLX_SEARCH, EPL_FRIENDLIST, EPL_RECENT_SQUAD]
    if (is_in_clan()) {
      this.sg_groups.append(EPLX_CLAN)
      updateClanContacts()
    }
    if (isSony) {
      this.sg_groups.insert(2, EPLX_PS4_FRIENDS)
      if (!(EPLX_PS4_FRIENDS in contactsByGroups))
        contactsByGroups[EPLX_PS4_FRIENDS] <- {}
    }
    this.fillContactsList()
  }

  getContactsGroups = @() this.sg_groups
}
register_gui_handler("SearchForSquadHandler", SearchForSquadHandler)

return freeze({
  openSearchSquadPlayer
})
