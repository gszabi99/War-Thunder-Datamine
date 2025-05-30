from "%scripts/dagui_library.nut" import *
from "%scripts/clans/clanState.nut" import is_in_clan

let { eventbus_subscribe } = require("eventbus")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { canInteractCrossConsole, isXBoxPlayerName, isPlatformSony } = require("%scripts/clientState/platform.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let crossplayModule = require("%scripts/social/crossplay.nut")
let updateContacts = require("%scripts/contacts/updateContacts.nut")
let { addPromoAction } = require("%scripts/promo/promoActions.nut")
let { addPromoButtonConfig } = require("%scripts/promo/promoButtonsConfig.nut")
let { EPLX_SEARCH, EPLX_CLAN, EPLX_PS4_FRIENDS, contactsWndSizes, contactsByGroups
} = require("%scripts/contacts/contactsManager.nut")
let { getPromoVisibilityById } = require("%scripts/promo/promo.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let ContactsHandler = require("%scripts/contacts/contactsHandler.nut")
let { isMeNewbie } = require("%scripts/myStats.nut")
let QUEUE_TYPE_BIT = require("%scripts/queue/queueTypeBit.nut")
let { checkQueueAndStart } = require("%scripts/queue/queueManager.nut")
let { updateClanContacts } = require("%scripts/clans/clanActions.nut")
let { isAnyQueuesActive } = require("%scripts/queue/queueState.nut")
let { canSquad } = require("%scripts/squads/squadUtils.nut")

function guiStartSearchSquadPlayer(_ = null) {
  if (!g_squad_manager.canInviteMember()) {
    showInfoMsgBox(loc("squad/not_a_leader"), "squad_not_available")
    return
  }

  updateContacts()
  handlersManager.loadHandler(gui_handlers.SearchForSquadHandler)
}

function openSearchSquadPlayer() {
  checkQueueAndStart(guiStartSearchSquadPlayer, null,
    "isCanModifyQueueParams", QUEUE_TYPE_BIT.DOMINATION | QUEUE_TYPE_BIT.NEWBIE)
}

eventbus_subscribe("guiStartSearchSquadPlayer", guiStartSearchSquadPlayer)

gui_handlers.SearchForSquadHandler <- class (ContactsHandler) {
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
    return gui_handlers.BaseGuiHandlerWT.isValid.bindenv(this)()
  }

  function goBack() {
    gui_handlers.BaseGuiHandlerWT.goBack.bindenv(this)()
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
      let showSquadInvite = !showConsoleButtons.value
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

addPromoAction("squad_contacts", @(_handler, _params, _obj) openSearchSquadPlayer())

let promoButtonId = "invite_squad_mainmenu_button"

addPromoButtonConfig({
  promoButtonId = promoButtonId
  updateFunctionInHandler = function() {
    let id = promoButtonId
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
