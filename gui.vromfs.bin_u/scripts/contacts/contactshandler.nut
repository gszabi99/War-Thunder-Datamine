//-file:plus-string
from "%scripts/dagui_library.nut" import *


let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { subscribe_handler } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { format } = require("string")
let { clearBorderSymbols, utf8ToLower } = require("%sqstd/string.nut")
let { parse_json } = require("json")
let playerContextMenu = require("%scripts/user/playerContextMenu.nut")
let platformModule = require("%scripts/clientState/platform.nut")
let crossplayModule = require("%scripts/social/crossplay.nut")
let { topMenuBorders } = require("%scripts/mainmenu/topMenuStates.nut")
let { isChatEnabled } = require("%scripts/chat/chatStates.nut")
let { showViralAcquisitionWnd } = require("%scripts/user/viralAcquisition.nut")
let { checkAndShowMultiplayerPrivilegeWarning,
  isMultiplayerPrivilegeAvailable } = require("%scripts/user/xboxFeatures.nut")
let { isShowGoldBalanceWarning } = require("%scripts/user/balanceFeatures.nut")
let { hasMenuChatPrivate } = require("%scripts/user/matchingFeature.nut")
let { is_chat_message_empty } = require("chat")
let { isGuestLogin } = require("%scripts/user/userUtils.nut")
let { EPLX_SEARCH, contactsWndSizes } = require("%scripts/contacts/contactsManager.nut")
let { searchContactsResults, searchContacts, addContact, removeContact
} = require("%scripts/contacts/contactsState.nut")

::contacts_prev_scenes <- [] //{ scene, show }
::last_contacts_scene_show <- false

::ContactsHandler <- class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.CUSTOM
  searchText = ""

  listNotPlayerChildsByGroup = null

  wndControlsAllowMask = CtrlsInGui.CTRL_ALLOW_FULL

  scene = null
  sceneChanged = true
  owner = null

  updateSizesTimer = 0.0
  updateSizesDelay = 1.0

  curGroup = ""
  curPlayer = null
  curHoverObjId = null

  searchInProgress = false
  searchShowNotFound = false
  searchShowDefaultOnReset = false
  searchGroupLastShowState = false


  constructor(gui_scene, params = {}) {
    base.constructor(gui_scene, params)
    subscribe_handler(this, ::g_listener_priority.DEFAULT_HANDLER)
    this.listNotPlayerChildsByGroup = {}
  }

  function initScreen(obj, resetList = true) {
    if (checkObj(this.scene) && this.scene.isEqual(obj))
      return

    foreach (group in ::contacts_groups)
      ::contacts[group].sort(::sortContacts)

    this.sceneShow(false)
    this.scene = obj
    this.sceneChanged = true
    if (resetList)
      ::friend_prev_scenes <- []
    this.sceneShow(true)
    this.closeSearchGroup()
  }

  function isValid() {
    return true
  }

  function getControlsAllowMask() {
    if (!this.isContactsWindowActive() || !this.scene.isEnabled())
      return CtrlsInGui.CTRL_ALLOW_FULL
    return this.wndControlsAllowMask
  }

  function updateControlsAllowMask() {
    if (!::last_contacts_scene_show)
      return

    local mask = CtrlsInGui.CTRL_ALLOW_FULL
    if (this.curHoverObjId != null)
      if (::show_console_buttons)
        mask = CtrlsInGui.CTRL_ALLOW_VEHICLE_FULL & ~CtrlsInGui.CTRL_ALLOW_VEHICLE_XINPUT
      else if (this.curHoverObjId == "search_edit_box")
        mask = CtrlsInGui.CTRL_ALLOW_VEHICLE_FULL & ~CtrlsInGui.CTRL_ALLOW_VEHICLE_KEYBOARD

    this.switchControlsAllowMask(mask)
  }

  function switchScene(obj, newOwner = null, onlyShow = false) {
    if (!checkObj(obj) || (checkObj(this.scene) && this.scene.isEqual(obj))) {
      if (!onlyShow || !::last_contacts_scene_show)
        this.sceneShow()
    }
    else {
      ::contacts_prev_scenes.append({ scene = this.scene, show = ::last_contacts_scene_show, owner = this.owner })
      this.owner = newOwner
      this.initScreen(obj, false)
    }
  }

  function goBack() {
    this.sceneShow(false)
  }

  function checkScene() {
    if (checkObj(this.scene))
      return true

    for (local i = ::contacts_prev_scenes.len() - 1; i >= 0; i--) {
      let prevScene = ::contacts_prev_scenes[i].scene
      if (checkObj(prevScene)) {
        let handler = ::contacts_prev_scenes[i].owner
        if (!handler.isSceneActiveNoModals() || !prevScene.isVisible())
          continue
        this.scene = ::contacts_prev_scenes[i].scene
        this.owner = handler
        this.guiScene = this.scene.getScene()
        this.sceneChanged = true
        this.sceneShow(::contacts_prev_scenes[i].show || ::last_contacts_scene_show)
        return true
      }
      else
        ::contacts_prev_scenes.remove(i)
    }
    this.scene = null
    return false
  }

  function sceneShow(show = null) {
    if (!this.checkScene())
      return

    let wasVisible = this.scene.isVisible()
    if (show == null)
      show = !wasVisible
    if (!show)
      this.loadSizes()

    this.scene.show(show)
    this.scene.enable(show)
    ::last_contacts_scene_show = show
    if (show) {
      this.validateCurGroup()
      if (!this.reloadSceneData()) {
        this.setSavedSizes()
        this.fillContactsList()
        this.closeSearchGroup()
      }
      let cgObj = this.scene.findObject("contacts_groups")
      ::move_mouse_on_child(cgObj, cgObj.getValue())
    }

    this.updateControlsAllowMask()
  }

  function loadSizes() {
    if (this.isContactsWindowActive()) {
      let obj = this.scene.findObject("contacts_wnd")
      contactsWndSizes({ pos = obj.getPosRC(), size = obj.getSize() })
      ::saveLocalByScreenSize("contacts_sizes", ::save_to_json(contactsWndSizes.value))
    }
  }

  function setSavedSizes() {
    if (contactsWndSizes.value == null) {
      let data = ::loadLocalByScreenSize("contacts_sizes")
      if (data) {
        let sizeData = parse_json(data)
        if (("pos" in sizeData) && ("size" in sizeData))
          contactsWndSizes({
            pos = [sizeData.pos[0].tointeger(), sizeData.pos[1].tointeger()]
            size = [sizeData.size[0].tointeger(), sizeData.size[1].tointeger()]
          })
      }
    }

    let sizeData = contactsWndSizes.value
    if (this.isContactsWindowActive() && sizeData != null) {
      let obj = this.scene.findObject("contacts_wnd")
      if (!obj)
        return

      let rootSize = this.guiScene.getRoot().getSize()
      for (local i = 0; i <= 1; i++) //pos chat in screen
        if (sizeData.pos[i] < topMenuBorders[i][0] * rootSize[i])
          contactsWndSizes.mutate(@(v) v.pos[i] = (topMenuBorders[i][0] * rootSize[i]).tointeger())
        else if (sizeData.pos[i] + sizeData.size[i] > topMenuBorders[i][1] * rootSize[i])
          contactsWndSizes.mutate(@(v) v.pos[i] = (topMenuBorders[i][1] * rootSize[i] - sizeData.size[i]).tointeger())

      obj.pos = $"{contactsWndSizes.value.pos[0]}, {contactsWndSizes.value.pos[1]}"
      obj.size = $"{contactsWndSizes.value.size[0]}, {contactsWndSizes.value.size[1]}"
    }
  }

  function reloadSceneData() {
    if (!this.checkScene())
      return false

    if (!this.scene.findObject("contacts_wnd")) {
      this.sceneChanged = true
      this.guiScene = this.scene.getScene()
      this.guiScene.replaceContent(this.scene, "%gui/contacts/contacts.blk", this)
      this.setSavedSizes()
      this.scene.findObject("contacts_update").setUserData(this)
      this.fillContactsList()
      return true
    }
    return false
  }

  function onUpdate(_obj, dt) {
    if (::last_contacts_scene_show) {
      this.updateSizesTimer -= dt
      if (this.updateSizesTimer <= 0) {
        this.updateSizesTimer = this.updateSizesDelay
        this.loadSizes()
      }
    }
  }

  function needRebuildPlayersList(gName, listObj) {
    if (gName == EPLX_SEARCH)
      return true //this group often refilled by other objects
    let count = ::contacts[gName].len() + getTblValue(gName, this.listNotPlayerChildsByGroup, -100000)
    return listObj.childrenCount() != count
  }

  needShowContactHoverButtons = @() !::show_console_buttons

  function buildPlayersList(gName, _showOffline = true) {
    let playerListView = {
      playerListItem = []
      playerButton = []
      needHoverButtons = this.needShowContactHoverButtons()
      hasMenuChatPrivate = hasMenuChatPrivate.value
    }
    this.listNotPlayerChildsByGroup[gName] <- 0
    if (gName != EPLX_SEARCH) {
      playerListView.searchAdviceID <- $"group_{gName}_search_advice"
      playerListView.totalContacts <- loc("contacts/total", {
        contactsCount = ::contacts[gName].len(),
        contactsCountMax = EPL_MAX_PLAYERS_IN_LIST
      })
      this.listNotPlayerChildsByGroup[gName] = 2
    }
    foreach (idx, contactData in ::contacts[gName]) {
      playerListView.playerListItem.append({
        blockID = "player_" + gName + "_" + idx
        contactUID = contactData.uid
        pilotIcon = contactData.pilotIcon
      })
    }
    if (gName == EPL_FRIENDLIST && ::isInMenu()) {
      if (hasFeature("Invites") && !isGuestLogin.value)
        playerListView.playerButton.append(this.createPlayerButtonView("btnInviteFriend", "#ui/gameuiskin#btn_invite_friend", "onInviteFriend"))
    }

    this.listNotPlayerChildsByGroup[gName] = this.listNotPlayerChildsByGroup[gName] + playerListView.playerButton.len()
    return handyman.renderCached(("%gui/contacts/playerList.tpl"), playerListView)
  }

  function createPlayerButtonView(gId, gIcon, callback) {
    if (!gId || gId == "")
      return {}

    let shortName = loc("mainmenu/" + gId + "Short", "")
    return {
      name = shortName == "" ? "#mainmenu/" + gId : shortName
      tooltip = "#mainmenu/" + gId
      icon = gIcon
      callback = callback
    }
  }

  function updatePlayersList(gName) {
    local sel = -1
    let selUid = (this.curPlayer && this.curGroup == gName) ? this.curPlayer.uid : ""

    let gObj = this.scene.findObject("contacts_groups")
    foreach (fIdx, f in ::contacts[gName]) {
      let obj = gObj.findObject("player_" + gName + "_" + fIdx)
      if (!checkObj(obj))
        continue

      let fullName = ::g_contacts.getPlayerFullName(f.getName(), f.clanTag)
      let contactNameObj = obj.findObject("contactName")
      contactNameObj.setValue(fullName)
      let contactPresenceObj = obj.findObject("contactPresence")
      if (checkObj(contactPresenceObj)) {
        contactPresenceObj.setValue(f.getPresenceText())
        contactPresenceObj["color-factor"] = f.presence.iconTransparency
      }
      obj.findObject("tooltip").uid = f.uid
      if (selUid == f.uid)
        sel = fIdx

      let imgObj = obj.findObject("statusImg")
      imgObj["background-image"] = f.presence.getIcon()
      imgObj["background-color"] = f.presence.getIconColor()

      obj.findObject("pilotIconImg").setValue(f.pilotIcon)
    }
    return sel
  }

  function fillPlayersList(gName) {
    let listObj = this.scene.findObject("contacts_groups").findObject("group_" + gName)
    if (!listObj)
      return

    if (this.needRebuildPlayersList(gName, listObj)) {
      let data = this.buildPlayersList(gName)
      this.guiScene.replaceContentFromText(listObj, data, data.len(), this)
    }
    this.updateContactButtonsForGroup(gName)
    this.applyContactFilter()
    return this.updatePlayersList(gName)
  }

  function updateContactButtonsForGroup(gName) {
    foreach (idx, contact in ::contacts[gName]) {
      let contactObject = this.scene.findObject(format("player_%s_%s", gName.tostring(), idx.tostring()))
      contactObject.contact_buttons_contact_uid = contact.uid

      let contactButtonsHolder = contactObject.findObject("contact_buttons_holder")
      if (!checkObj(contactButtonsHolder))
        continue

      this.updateContactButtonsVisibility(contact, contactButtonsHolder)
    }
  }

  function onWwOperationInvite(obj) {
    if (!::is_worldwar_enabled())
      return

    this.updateCurPlayer(obj)
    if (this.curPlayer)
      ::g_world_war.inviteToWwOperation(this.curPlayer.uid)
  }

  function updateContactButtonsVisibility(contact, contact_buttons_holder) {
    if (!this.checkScene())
      return

    let isFriend = contact ? contact.isInFriendGroup() : false
    let isBlock = contact ? contact.isInBlockGroup() : false
    let isMe = contact ? contact.isMe() : false
    let contactName = contact?.name ?? ""

    let isPlayerFromXboxOne = platformModule.isPlayerFromXboxOne(contactName)
    let canBlock = !isPlayerFromXboxOne
    let canChat = contact ? contact.canChat() : true
    let canInvite = contact ? contact.canInvite() : true
    let canInteractCrossConsole = platformModule.canInteractCrossConsole(contactName)
    let canInteractCrossPlatform = crossplayModule.isCrossPlayEnabled()
                                     || platformModule.isPlayerFromPS4(contactName)
                                     || isPlayerFromXboxOne

    ::showBtn("btn_friendAdd", !isMe && !isFriend && !isBlock && canInteractCrossConsole, contact_buttons_holder)
    ::showBtn("btn_friendRemove", isFriend, contact_buttons_holder)
    ::showBtn("btn_blacklistAdd", !isMe && !isFriend && !isBlock && canBlock, contact_buttons_holder)
    ::showBtn("btn_blacklistRemove", isBlock && canBlock, contact_buttons_holder)
    ::showBtn("btn_message", this.owner
                           && !isBlock
                           && isChatEnabled()
                           && canChat, contact_buttons_holder)
    ::showBtn("btn_ww_invite", ::is_worldwar_enabled()
      && ::g_world_war.isWwOperationInviteEnable(), contact_buttons_holder)

    let showSquadInvite = hasFeature("SquadInviteIngame")
      && !isMe
      && !isBlock
      && canInteractCrossConsole
      && canInteractCrossPlatform
      && ::g_squad_manager.canInviteMember(contact?.uid ?? "")
      && ::g_squad_manager.canInviteMemberByPlatform(contactName)
      && !::g_squad_manager.isPlayerInvited(contact?.uid ?? "", contactName)
      && canInvite
      && ::g_squad_utils.canSquad()

    let btnObj = ::showBtn("btn_squadInvite", showSquadInvite, contact_buttons_holder)
    if (btnObj && showSquadInvite && contact?.uidInt64)
      this.updateButtonInviteText(btnObj, contact.uidInt64)

    ::showBtn("btn_usercard", hasFeature("UserCards"), contact_buttons_holder)
    ::showBtn("btn_squadInvite_bottom", false, contact_buttons_holder)
  }

  searchGroupActiveTextInclude = @"
    id:t='search_group_active_text';
    Button_close {
      id:t='close_search_group';
      on_click:t='onCloseSearchGroupClicked';
      smallIcon:t='yes'
    }"

  groupFormat = @"group {
    groupHeader {
      canBeClosed:t='yes';
      text:t='%s';
      %s
    }
    groupList {
      id:t='%s';
      %s
      on_select:t='onPlayerSelect';
      on_dbl_click:t='%s';
      on_cancel_edit:t='onPlayerCancel';
      on_hover:t='onContactsFocus';
      on_unhover:t='onContactsFocus';
      contacts_group_list:t='yes';
    }
  }"

  function getIndexOfGroup(group_name) {
    let contactsGroups = this.scene.findObject("contacts_groups")
    for (local idx = contactsGroups.childrenCount() - 1; idx >= 0; --idx) {
      let childObject = contactsGroups.getChild(idx)
      let groupListObject = childObject.getChild(childObject.childrenCount() - 1)
      if (groupListObject?.id == "group_" + group_name) {
        return idx
      }
    }
    return -1
  }

  function getGroupByName(group_name) {
    let contactsGroups = this.scene.findObject("contacts_groups")
    if (checkObj(contactsGroups)) {
      let groupListObject = contactsGroups.findObject("group_" + group_name)
      return groupListObject.getParent()
    }
    return null
  }

  function setSearchGroupVisibility(value) {
    local groupObject = this.getGroupByName(EPLX_SEARCH)
    groupObject.show(value)
    groupObject.enable(value)
    this.searchGroupLastShowState = value
  }

  function onSearchEditBoxActivate(obj) {
    this.doSearch(obj)
  }

  function doSearch(editboxObj = null) {
    if (!editboxObj)
      editboxObj = this.scene.findObject("search_edit_box")
    if (!checkObj(editboxObj))
      return

    local txt = clearBorderSymbols(editboxObj.getValue())
    txt = platformModule.cutPlayerNamePrefix(platformModule.cutPlayerNamePostfix(txt))
    if (txt == "")
      return

    let contactsGroups = this.scene.findObject("contacts_groups")
    if (checkObj(contactsGroups)) {
      let searchGroupIndex = this.getIndexOfGroup(EPLX_SEARCH)
      if (searchGroupIndex != -1) {
        this.setSearchGroupVisibility(true)
        contactsGroups.setValue(searchGroupIndex)
        this.onSearch(null)
      }
    }
  }

  function onSearchEditBoxCancelEdit(obj) {
    if (this.curGroup == EPLX_SEARCH) {
      this.closeSearchGroup()
      return
    }

    if (obj.getValue() == "")
      this.goBack()
    else
      obj.setValue("")
  }

  function onSearchEditBoxChangeValue(obj) {
    this.setSearchText(platformModule.getPlayerName(obj.getValue()), false)
    this.applyContactFilter()
  }

  function onContactsFocus(obj) {
    let isValidCurScene = checkObj(this.scene)
    if (!isValidCurScene) {
      this.curHoverObjId = null
      return
    }
    let newObjId = obj.isHovered() ? obj.id : null
    if (this.curHoverObjId == newObjId)
      return
    this.curHoverObjId = newObjId
    this.updateControlsAllowMask()
    this.updateConsoleButtons()
    this.setSearchAdviceVisibility(!::show_console_buttons && this.curHoverObjId == "search_edit_box")
  }

  function setSearchText(search_text, set_in_edit_box = true) {
    this.searchText = utf8ToLower(search_text)
    if (set_in_edit_box) {
      let searchEditBox = this.scene.findObject("search_edit_box")
      if (checkObj(searchEditBox)) {
        searchEditBox.setValue(search_text)
      }
    }
  }

  function applyContactFilter() {
    if (this.curGroup == ""
        || this.curGroup == EPLX_SEARCH
        || !(this.curGroup in ::contacts))
      return

    foreach (idx, contact_data in ::contacts[this.curGroup]) {
      let contactObjectName = "player_" + this.curGroup + "_" + idx
      let contactObject = this.scene.findObject(contactObjectName)
      if (!checkObj(contactObject))
        continue

      local contactName = utf8ToLower(contact_data.name)
      contactName = platformModule.getPlayerName(contactName)
      let searchResult = this.searchText == "" || contactName.indexof(this.searchText) != null
      contactObject.show(searchResult)
      contactObject.enable(searchResult)
    }
  }

  function fillContactsList() {
    if (!this.checkScene())
      return

    let gObj = this.scene.findObject("contacts_groups")
    if (!gObj)
      return
    this.guiScene.setUpdatesEnabled(false, false)

    local data = ""
    let groups_array = this.getContactsGroups()
    foreach (_gIdx, gName in groups_array) {
      ::contacts[gName].sort(::sortContacts)
      local activateEvent = "onPlayerMsg"
      if (::show_console_buttons || !isChatEnabled())
        activateEvent = "onPlayerMenu"
      let gData = this.buildPlayersList(gName)
      data += format(this.groupFormat, "#contacts/" + gName,
        gName == EPLX_SEARCH ? this.searchGroupActiveTextInclude : "",
        "group_" + gName, gData, activateEvent)
    }
    this.guiScene.replaceContentFromText(gObj, data, data.len(), this)
    foreach (gName in groups_array) {
      this.updateContactButtonsForGroup(gName)
      if (gName == EPLX_SEARCH)
        this.setSearchGroupVisibility(this.searchGroupLastShowState)
    }

    this.applyContactFilter()

    let selected = [-1, -1]
    foreach (gIdx, gName in groups_array) {
      if (gName == EPLX_SEARCH && !this.searchGroupLastShowState)
        continue

      if (selected[0] < 0)
        selected[0] = gIdx

      if (this.curGroup == gName)
        selected[0] = gIdx

      let sel = this.updatePlayersList(gName)
      if (sel > 0)
        selected[1] = sel
    }

    if (::contacts[groups_array[selected[0]]].len() > 0)
      gObj.findObject("group_" + groups_array[selected[0]]).setValue(
              (selected[1] >= 0) ? selected[1] : 0)

    this.guiScene.setUpdatesEnabled(true, true)

    gObj.setValue(selected[0])
    this.onGroupSelectImpl(gObj)
  }

  function isGroupListChanged() {
    let gObj = this.scene.findObject("contacts_groups")
    let groups = this.getContactsGroups()

    if (groups.len() != gObj.childrenCount())
      return true

    for (local i = 0; i < groups.len(); i++) {
      local groupId = $"group_{groups[i]}"
      let curGroupObj = gObj.getChild(i).findObject(groupId)
      if (!(curGroupObj?.isValid() ?? false))
        return true
    }
    return false
  }

  function updateContactsGroup(groupName) {
    if (!this.isContactsWindowActive())
      return

    if (this.isGroupListChanged()) {
      this.fillContactsList()
      return
    }

    if (groupName && !(groupName in ::contacts)) {
      if (this.curGroup == groupName)
        this.curGroup = ""

      this.fillContactsList()
      if (this.searchText == "")
        this.closeSearchGroup()
      return
    }

    if (groupName && groupName in ::contacts) {
      ::contacts[groupName].sort(::sortContacts)
      this.fillPlayersList(groupName)
    }
    else
      foreach (group in this.getContactsGroups())
        if (group in ::contacts) {
          ::contacts[group].sort(::sortContacts)
          this.fillPlayersList(group)
        }
  }

  function onEventContactsGroupUpdate(params) {
    this.validateCurGroup()
    this.updateContactsGroup(params?.groupName)
  }

  function onEventContactsGroupAdd(_) {
    this.fillContactsList()
  }

  function onEventModalWndDestroy(_params) {
    this.checkScene()
  }

  function selectCurContactGroup() {
    if (!this.checkScene())
      return
    let groupsObj = this.scene.findObject("contacts_groups")
    let value = groupsObj.getValue()
    if (value >= 0 && value < groupsObj.childrenCount())
      ::move_mouse_on_child(groupsObj.getChild(value), 0) //header
  }

  function onGroupSelectImpl(obj) {
    this.selectItemInGroup(obj, false)
    this.applyContactFilter()
  }

  prevGroup = -1
  function onGroupSelect(obj) {
    this.onGroupSelectImpl(obj)
    if (!::is_mouse_last_time_used() && this.prevGroup != obj.getValue()) {
      this.guiScene.applyPendingChanges(false)
      this.selectCurContactGroup()
    }
    this.prevGroup = obj.getValue()
  }

  function selectHoveredGroup() {
    let listObj = this.scene.findObject("contacts_groups")
    let total = listObj.childrenCount()
    for (local i = 0; i < total; i++) {
      let child = listObj.getChild(i)
      if (!child.isValid() || !child.isHovered())
        continue
      listObj.setValue(i)
      this.onGroupActivate(listObj)
      return
    }
  }

  function onGroupActivate(obj) {
    this.selectItemInGroup(obj, true)
    this.applyContactFilter()
  }

  function onGroupCancel(_obj) {
    this.goBack()
  }

  onPlayerCancel = @(_obj) ::is_mouse_last_time_used() ? this.goBack() : this.selectCurContactGroup()

  function onSearchButtonClick(_obj) {
    this.doSearch()
  }

  function onBtnSelect(_obj) {
    if (!this.checkScene())
      return

    if (this.curHoverObjId == "contacts_groups")
      this.selectHoveredGroup()
    else if (this.curHoverObjId == "search_edit_box")
      this.doSearch()
    else {
      let groupObj = this.scene.findObject("group_" + this.curGroup)
      if (groupObj?.isValid())
        this.onPlayerMenu(groupObj)
    }
  }

  function selectItemInGroup(obj, switchFocus = false) {
    let groups = this.getContactsGroups()
    let value = obj.getValue()
    if (!(value in groups))
      return

    this.curGroup = groups[value]

    let listObj = obj.findObject("group_" + this.curGroup)
    if (!checkObj(listObj))
      return

    if (::contacts[this.curGroup].len() == 0)
      return

    if (listObj.getValue() < 0 && ::contacts[this.curGroup].len() > 0)
      listObj.setValue(0)

    this.onPlayerSelect(listObj)
    this.showSceneBtn("button_invite_friend", this.curGroup == EPL_FRIENDLIST)

    if (switchFocus)
      ::move_mouse_on_child(listObj, listObj.getValue())
  }

  function onPlayerSelect(obj) {
    if (!obj)
      return

    this.curPlayer = ::contacts?[this.curGroup][obj.getValue()]
  }

  function onPlayerMenu(obj) {
    let value = obj.getValue()
    if (value < 0 || value >= obj.childrenCount())
      return

    let childObj = obj.getChild(value)
    if (!checkObj(childObj))
      return

    if (childObj?.contact_buttons_contact_uid) {
      this.updateCurPlayerByUid(childObj.contact_buttons_contact_uid)
      this.showCurPlayerRClickMenu(childObj.getPosRC())
    }
    else if (childObj?.isButton == "yes")
      this.sendClickButton(childObj)
  }

  function sendClickButton(obj) {
    let clickName = obj?.on_click
    if (!clickName || !(clickName in this))
      return

    this[clickName]()
  }

  function onPlayerRClick(obj) {
    if (!this.checkScene() || !checkObj(obj))
      return

    let id = obj.id
    let prefix = "player_" + this.curGroup + "_"
    if (id.len() <= prefix.len() || id.slice(0, prefix.len()) != prefix)
      return

    let idx = id.slice(prefix.len()).tointeger()
    if ((this.curGroup in ::contacts) && (idx in ::contacts[this.curGroup])) {
      let listObj = this.scene.findObject("group_" + this.curGroup)
      if (!listObj)
        return

      listObj.setValue(idx)
      this.updateCurPlayerByUid(listObj.getChild(idx)?.contact_buttons_contact_uid)
      this.showCurPlayerRClickMenu()
    }
  }

  function onCloseSearchGroupClicked(_obj) {
    this.closeSearchGroup()
  }

  function closeSearchGroup() {
    if (!this.checkScene())
      return

    let contactsGroups = this.scene.findObject("contacts_groups")
    if (checkObj(contactsGroups)) {
      this.setSearchGroupVisibility(false)
      let searchGroupIndex = this.getIndexOfGroup(EPLX_SEARCH)
      if (contactsGroups.getValue() == searchGroupIndex) {
        this.setSearchText("")
        let friendsGroupIndex = this.getIndexOfGroup(EPL_FRIENDLIST)
        contactsGroups.setValue(friendsGroupIndex)
      }
    }
    this.applyContactFilter()
  }

  function setSearchAdviceVisibility(value) {
    foreach (_idx, groupName in this.getContactsGroups()) {
      let searchAdviceID = "group_" + groupName + "_search_advice"
      let searchAdviceObject = this.scene.findObject(searchAdviceID)
      if (checkObj(searchAdviceObject)) {
        searchAdviceObject.show(value)
        searchAdviceObject.enable(value)
      }
    }
  }

  function showCurPlayerRClickMenu(position = null) {
    playerContextMenu.showMenu(this.curPlayer, this,
      {
        position = position
        curContactGroup = this.curGroup
        onClose = function() {
          if (this.checkScene())
            ::move_mouse_on_child_by_value(this.scene.findObject("group_" + this.curGroup))
        }.bindenv(this)
      })
  }

  function isContactsWindowActive() {
    return this.checkScene() && ::last_contacts_scene_show;
  }

  function updateButtonInviteText(btnObj, uid) {
    btnObj.tooltip = ::g_squad_manager.hasApplicationInMySquad(uid)
        ? loc("squad/accept_membership")
        : loc("squad/invite_player")
  }

  function updateConsoleButtons() {
    if (!this.checkScene())
      return

    this.showSceneBtn("contacts_buttons_console", ::show_console_buttons)
    if (!::show_console_buttons)
      return

    let showSelectButton = this.curHoverObjId != null
    let btn = this.showSceneBtn("btn_contactsSelect", showSelectButton)
    if (showSelectButton)
      btn.setValue(loc(this.curHoverObjId == "contacts_groups" ? "contacts/chooseGroup"
        : this.curHoverObjId == "search_edit_box" ? "contacts/search"
        : "contacts/choosePlayer"))
  }

  function updateCurPlayer(button_object) {
    if (!checkObj(button_object))
      return

    let contactButtonsObject = button_object.getParent().getParent()
    this.updateCurPlayerByUid(contactButtonsObject?.contact_buttons_contact_uid)
  }

  function updateCurPlayerByUid(contactUID) {
    if (!contactUID)
      return

    let contact = ::getContact(contactUID)
    this.curPlayer = contact

    let idx = ::contacts[this.curGroup].indexof(contact)
    if (!this.checkScene() || idx == null)
      return

    let groupObject = this.scene.findObject("contacts_groups")
    let listObject = groupObject.findObject("group_" + this.curGroup)
    listObject.setValue(idx)
  }

  function onFriendAdd(obj) {
    this.updateCurPlayer(obj)
    addContact(this.curPlayer, EPL_FRIENDLIST)
  }

  function onFriendRemove(obj) {
    this.updateCurPlayer(obj)
    removeContact(this.curPlayer, EPL_FRIENDLIST)
  }

  function onBlacklistAdd(obj) {
    this.updateCurPlayer(obj)
    addContact(this.curPlayer, EPL_BLOCKLIST)
  }

  function onBlacklistRemove(obj) {
    this.updateCurPlayer(obj)
    removeContact(this.curPlayer, EPL_BLOCKLIST)
  }

  function onPlayerMsg(obj) {
    this.updateCurPlayer(obj)
    if (!this.curPlayer || !this.owner)
      return

    ::openChatPrivate(this.curPlayer.name, this.owner)
  }

  function onSquadInvite(obj) {
    this.updateCurPlayer(obj)

    if (!isMultiplayerPrivilegeAvailable.value) {
      checkAndShowMultiplayerPrivilegeWarning()
      return
    }

    if (isShowGoldBalanceWarning())
      return

    if (this.curPlayer == null)
      return ::g_popups.add("", loc("msgbox/noChosenPlayer"))

    let uid = this.curPlayer.uid
    if (!::g_squad_manager.canInviteMember(uid))
      return

    let name = this.curPlayer.name
    if (::g_squad_manager.hasApplicationInMySquad(uid.tointeger(), name))
      ::g_squad_manager.acceptMembershipAplication(uid.tointeger())
    else
      ::g_squad_manager.inviteToSquad(uid, name)
  }

  function onUsercard(obj) {
    this.updateCurPlayer(obj)
    if (this.curPlayer)
      ::gui_modal_userCard(this.curPlayer)
  }

  function onCancelSearchEdit(obj) {
    if (!obj)
      return

    let value = obj.getValue()
    if (!value || value == "") {
      if (::show_console_buttons)
        this.onPlayerCancel(obj)
      else
        this.goBack()
    }
    else {
      obj.setValue("")
      if (this.searchShowDefaultOnReset) {
        this.fillDefaultSearchList()
        this.updateSearchList()
      }
    }
    this.searchShowNotFound = false
  }

  function getSearchObj() {
    return this.checkScene() ? this.scene.findObject("search_edit_box") : null
  }

  function onSearch(_obj) {
    let sObj = this.getSearchObj()
    if (!sObj || this.searchInProgress)
      return
    local value = sObj.getValue()
    if (!value || value == "*")
      return
    if (is_chat_message_empty(value)) {
      if (this.searchShowDefaultOnReset) {
        this.fillDefaultSearchList()
        this.updateSearchList()
      }
      return
    }

    value = clearBorderSymbols(value)

    let searchGroupActiveTextObject = this.scene.findObject("search_group_active_text")
    let searchGroupText = loc($"contacts/{EPLX_SEARCH}")
    searchGroupActiveTextObject.setValue($"{searchGroupText}: {value}")

    searchContacts(value, Callback(this.onSearchCb, this))
    this.searchInProgress = true
    ::contacts[EPLX_SEARCH] <- []
    this.updateSearchList()
  }

  function onSearchCb() {
    this.searchInProgress = false

    let searchRes = searchContactsResults.value
    ::contacts[EPLX_SEARCH] <- []
    local brokenData = false
    foreach (uid, nick in searchRes) {
      let contact = ::getContact(uid, nick)
      if (contact) {
        if (!contact.isMe() && !contact.isInFriendGroup() && platformModule.isPs4XboxOneInteractionAvailable(contact.name))
          ::contacts[EPLX_SEARCH].append(contact)
      }
      else
        brokenData = true
    }

    if (brokenData) {
      let searchResStr = toString(searchRes) // warning disable: -declared-never-used
      ::script_net_assert_once("broken_searchCb_data", "broken result on searchContacts cb")
    }

    this.updateSearchList()
    if (::show_console_buttons && this.curGroup == EPLX_SEARCH && !::is_mouse_last_time_used() && this.checkScene())
      ::move_mouse_on_child_by_value(this.scene.findObject("group_" + EPLX_SEARCH))
  }

  function updateSearchList() {
    if (!this.checkScene())
      return

    let gObj = this.scene.findObject("contacts_groups")
    let listObj = gObj.findObject("group_" + EPLX_SEARCH)
    if (!listObj)
      return

    this.guiScene.setUpdatesEnabled(false, false)
    local sel = -1
    if (::contacts[EPLX_SEARCH].len() > 0)
      sel = this.fillPlayersList(EPLX_SEARCH)
    else {
      local data = ""
      if (this.searchInProgress)
        data = "animated_wait_icon { pos:t='0.5(pw-w),0.03sh'; position:t='absolute'; background-rotation:t='0' }"
      else if (this.searchShowNotFound)
        data = "textAreaCentered { text:t='#contacts/searchNotFound'; enable:t='no' }"
      else {
        this.fillDefaultSearchList()
        sel = this.fillPlayersList(EPLX_SEARCH)
        data = null
      }

      if (data) {
        this.guiScene.replaceContentFromText(listObj, data, data.len(), this)
        this.searchShowNotFound = true
      }
    }
    this.guiScene.setUpdatesEnabled(true, true)

    if (this.curGroup == EPLX_SEARCH) {
      if (::contacts[EPLX_SEARCH].len() > 0)
        listObj.setValue(sel > 0 ? sel : 0)
      this.onPlayerSelect(listObj)
    }
  }

  function fillDefaultSearchList() {
    ::contacts[EPLX_SEARCH] <- []
  }

  function onInviteFriend() {
    showViralAcquisitionWnd()
  }

  function onEventContactsUpdated(_params) {
    this.updateContactsGroup(null)
  }

  function onEventSquadStatusChanged(_p) {
    this.updateContactsGroup(null)
  }

  function validateCurGroup() {
    if (!(this.curGroup in ::contacts))
      this.curGroup = ""
  }

  function onEventActiveHandlersChanged(_p) {
    this.checkActiveScene()
  }

  function checkActiveScene() {
    if (!checkObj(this.scene) || this.owner == null) {
      this.checkScene()
      return
    }

    if (this.owner.isSceneActiveNoModals() || this.scene?.isVisible())
      return

    let curScene = this.scene
    if (::contacts_prev_scenes.findvalue(@(v) curScene.isEqual(v.scene)) == null)
      ::contacts_prev_scenes.append({ scene = this.scene, show = ::last_contacts_scene_show, owner = this.owner })
    this.scene = null
    return
  }

  function onEventContactsCleared(_p) {
    this.validateCurGroup()
  }

  getContactsGroups = @() ::contacts_groups
}
