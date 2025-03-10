from "%scripts/dagui_library.nut" import *
from "%scripts/options/optionsCtors.nut" import create_option_combobox

let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { setPopupMenuPosAndAlign } = require("%sqDagui/daguiUtil.nut")
let { format } = require("string")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { ceil } = require("math")
let { showSquadMemberMenu } = require("%scripts/user/playerContextMenu.nut")

gui_handlers.squadInviteListWnd <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType             = handlerType.MODAL
  sceneBlkName        = "%gui/squads/squadInvites.blk"

  inviteListTplName   = "%gui/squads/squadInvites.tpl"

  CONFIG_PLAYERS_LISTS = {
    invites = { listObjId = "invites_list"
      playersList = @() g_squad_manager.getInvitedPlayers()
      headerObjId = "invited_players_header"
    }
    applications = { listObjId = "applications_list"
      playersList = @() g_squad_manager.getApplicationsToSquad()
      headerObjId = "applications_list_header"
    }
  }
  MAX_COLUMNS = 5
  NEST_OBJ_ID = "squad_invites"

  align = "top"
  alignObj = null

  optionsObj = null

  static function open(alignObj) {
    if (!this.canOpen())
      return null

    if (!checkObj(alignObj))
      return null

    let params = {
      alignObj = alignObj
    }

    return handlersManager.loadHandler(gui_handlers.squadInviteListWnd, params)
  }

  static function canOpen() {
    return hasFeature("Squad") && hasFeature("SquadWidget")
      && g_squad_manager.isInSquad()
      && (g_squad_manager.canChangeSquadSize(false) || g_squad_manager.getInvitedPlayers().len() > 0
          || g_squad_manager.getApplicationsToSquad().len() > 0)
  }

  function initScreen() {
    this.optionsObj = this.scene.findObject("options_block")

    this.updateSquadSizeOption()
    this.updateReceiveApplicationsOption()
    this.updateInviteesList()
    this.updateApplicationsList()
  }

  function updateInviteesList() {
    this.updateList(this.CONFIG_PLAYERS_LISTS.invites)
  }

  function updateApplicationsList() {
    this.updateList(this.CONFIG_PLAYERS_LISTS.applications)
    g_squad_manager.markAllApplicationsSeen()
  }

  function updateList(configPlayersList) {
    let playersList = configPlayersList.playersList()
    let listObj = this.scene.findObject(configPlayersList.listObjId)
    let viewData = this.getMembersViewData(playersList)
    let viewBlk = handyman.renderCached(this.inviteListTplName, viewData)
    let isFocused = listObj.isFocused()
    local selectedIdx = listObj.getValue()
    local selectedObjId = null
    if ((selectedIdx >= 0) && (selectedIdx < listObj.childrenCount()) && isFocused)
      selectedObjId = listObj.getChild(selectedIdx).id

    this.guiScene.replaceContentFromText(listObj, viewBlk, viewBlk.len(), this)
    local i = 0
    foreach (memberData in playersList) {
      let inviteObjId =$"squad_invite_{memberData.uid}"
      let inviteObj = listObj.findObject(inviteObjId)
      if (checkObj(inviteObj)) {
        if (u.isEqual(selectedObjId, inviteObjId) && isFocused)
          selectedIdx = i
        inviteObj.setUserData(memberData)
      }
      i++
    }
    let countPlayers = listObj.childrenCount()
    if (isFocused && countPlayers > 0)
      listObj.setValue(clamp(selectedIdx, 0, countPlayers - 1))
    this.scene.findObject(configPlayersList.headerObjId).show(playersList.len() > 0)
    this.updateSize(listObj, playersList)
    this.updatePosition()
  }

  function getMembersViewData(membersData) {
    let items = []
    foreach (memberData in membersData)
      items.append(
        {
          id = memberData.uid
          pilotIcon = memberData.pilotIcon
        }
      )

    return { items = items }
  }

  function updateSquadSizeOption() {
    let isAvailable = g_squad_manager.canChangeSquadSize(false)
    this.optionsObj.show(isAvailable)
    this.optionsObj.enable(isAvailable)
    if (!isAvailable)
      return

    let sizes = g_squad_manager.getSquadSizesList().map(@(s) "".concat(s.value, loc("ui/comma"), loc($"squadSize/{s.name}")))
    let curValue = g_squad_manager.getMaxSquadSize()
    let curIdx = g_squad_manager.getSquadSizesList().findindex(@(s) s.value == curValue) ?? 0

    let optionObj = this.scene.findObject("squad_size_option")
    let markup = create_option_combobox("", sizes, curIdx, null, false)
    this.guiScene.replaceContentFromText(optionObj, markup, markup.len(), this)
    optionObj.setValue(curIdx)
    optionObj.enable(g_squad_manager.canChangeSquadSize())
  }

  function updateReceiveApplicationsOption() {
    let isAvailable = g_squad_manager.canChangeReceiveApplications(false)
    let obj = showObjById("receive_applications", isAvailable, this.scene)
    if (!isAvailable || !obj)
      return

    obj.setValue(g_squad_manager.isApplicationsEnabled())
    obj.enable(g_squad_manager.canChangeReceiveApplications())
  }

  function updateSize(listObj, playersList) {
    if (!checkObj(listObj))
      return

    let total = playersList.len()
    let rows = total && ceil(total.tofloat() / this.MAX_COLUMNS.tofloat())
    let columns = rows && ceil(total.tofloat() / rows.tofloat())

    let sizeFormat = "%d@mIco"
    listObj.width = format(sizeFormat, columns)
    listObj.height = format(sizeFormat, rows)
  }

  function updatePosition() {
    let nestObj = this.scene.findObject(this.NEST_OBJ_ID)
    if (checkObj(nestObj))
      this.align = setPopupMenuPosAndAlign(this.alignObj, this.align, nestObj)
  }

  function checkActiveForDelayedAction() {
    return this.isSceneActive()
  }

  function onMemberClicked(obj) {
    showSquadMemberMenu(obj)
  }

  function onSquadSizeChange(obj) {
    let idx = obj.getValue()
    if (idx in g_squad_manager.getSquadSizesList())
      g_squad_manager.setSquadSize(g_squad_manager.getSquadSizesList()[idx].value)
  }

  function onReceiveApplications(obj) {
    if (!obj)
      return
    let value = obj.getValue()
    if (value == g_squad_manager.isApplicationsEnabled())
      return

    g_squad_manager.enableApplications(value)
    if (!g_squad_manager.isApplicationsEnabled() && g_squad_manager.getApplicationsToSquad().len() > 0)
      this.msgBox("denyAllMembershipApplications", loc("squad/ConfirmDenyApplications"),
        [
          ["yes", function() { g_squad_manager.denyAllAplication() }],
          ["no",  function() {} ],
        ], "no")
  }

  
  function onEventSquadInvitesChanged(_params) {
    this.doWhenActiveOnce("updateInviteesList")
  }

  function onEventSquadApplicationsChanged(_params) {
    this.doWhenActiveOnce("updateApplicationsList")
  }

  function onEventSquadPropertiesChanged(_params) {
    this.doWhenActiveOnce("updateReceiveApplicationsOption")
  }
}
