from "eventbus" import eventbus_subscribe
from "%globalScripts/externalPlayerListConsts.nut" import *
from "%scripts/dagui_library.nut" import *
from "%scripts/clans/clanState.nut" import is_in_clan
from "%scripts/contacts/contactsConsts.nut" import EPLX_SEARCH, EPLX_CLAN, EPLX_PS4_FRIENDS

let { g_squad_manager } = require("%scripts/squads/squadManager.nut")
let { register_gui_handler, get_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { BaseGuiHandlerWT } = require("%scripts/baseGuiHandlerWT.nut")
let { canInteractCrossConsole, isXBoxPlayerName, isPlatformSony } = require("%scripts/clientState/platform.nut")
let { handlerType } = require("%scripts/sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let crossplayModule = require("%scripts/social/crossplay.nut")
let updateContacts = require("%scripts/contacts/updateContacts.nut")
let { addPromoAction } = require("%scripts/promo/promoActions.nut")
let { addPromoButtonConfig } = require("%scripts/promo/promoButtonsConfig.nut")
let { contactsWndSizes, contactsByGroups } = require("%scripts/contacts/contactsListState.nut")
let { getPromoVisibilityById } = require("%scripts/promo/promo.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let ContactsHandler = require("%scripts/contacts/contactsHandler.nut")
let { isMeNewbie } = require("%scripts/myStats.nut")
let QUEUE_TYPE_BIT = require("%scripts/queue/queueTypeBit.nut")
let { checkQueueAndStart } = require("%scripts/queue/queueManager.nut")
let { updateClanContacts } = require("%scripts/clans/clanActions.nut")
let { isAnyQueuesActive } = require("%scripts/queue/queueState.nut")
let { canSquad } = require("%scripts/squads/squadUtils.nut")
let { openChatPrivate } = require("%scripts/chat/openChat.nut")

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
    let canInteractCrossPlatform = isXBoxOnePlayer || crossplayModule.isCrossPlayEnabled()

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
        && hasFeature("SquadInviteIngame")
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
    if (isPlatformSony) {
      this.sg_groups.insert(2, EPLX_PS4_FRIENDS)
      if (!(EPLX_PS4_FRIENDS in contactsByGroups))
        contactsByGroups[EPLX_PS4_FRIENDS] <- {}
    }
    this.fillContactsList()
  }

  getContactsGroups = @() this.sg_groups
}
register_gui_handler("SearchForSquadHandler", SearchForSquadHandler)

addPromoAction("squad_contacts", @(_handler, _params, _obj) openSearchSquadPlayer())

const promoButtonId = "invite_squad_mainmenu_button"

addPromoButtonConfig({
  promoButtonId = promoButtonId
  updateFunctionInHandler = function() {
    const id = promoButtonId
    let show = !isMeNewbie() && getPromoVisibilityById(id)
    let buttonObj = showObjById(id, show, this.scene)
    if (!show || !checkObj(buttonObj))
      return

    buttonObj.inactiveColor = isAnyQueuesActive() ? "yes" : "no"
  }
  updateByEvents = ["QueueChangeState"]
})

return {
  openSearchSquadPlayer
}
