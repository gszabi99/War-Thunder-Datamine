//-file:plus-string
from "%scripts/dagui_natives.nut" import is_mouse_last_time_used
from "%scripts/dagui_library.nut" import *
from "%scripts/teamsConsts.nut" import Team

let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { move_mouse_on_child_by_value, handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { get_time_msec } = require("dagor.time")
let { format } = require("string")
let regexp2 = require("regexp2")
let stdMath = require("%sqstd/math.nut")
let { cutPrefix } = require("%sqstd/string.nut")
let clustersModule = require("%scripts/clusterSelect.nut")
let antiCheat = require("%scripts/penitentiary/antiCheat.nut")
let { setColoredDoubleTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { checkDiffTutorial } = require("%scripts/tutorials/tutorialsData.nut")
let { suggestAndAllowPsnPremiumFeatures } = require("%scripts/user/psnFeatures.nut")
let { showMsgboxIfSoundModsNotAllowed } = require("%scripts/penitentiary/soundMods.nut")
let { checkAndShowMultiplayerPrivilegeWarning,
  isMultiplayerPrivilegeAvailable } = require("%scripts/user/xboxFeatures.nut")
let { isShowGoldBalanceWarning } = require("%scripts/user/balanceFeatures.nut")
let openClustersMenuWnd = require("%scripts/onlineInfo/clustersMenuWnd.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { OPTIONS_MODE_MP_DOMINATION } = require("%scripts/options/optionsExtNames.nut")
let { getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")
let { getEventEconomicName } = require("%scripts/events/eventInfo.nut")
let { getMissionsComplete } = require("%scripts/myStats.nut")
let { getCurrentGameModeEdiff } = require("%scripts/gameModes/gameModeManagerState.nut")
let { showMultiplayerLimitByAasMsg, hasMultiplayerLimitByAas } = require("%scripts/user/antiAddictSystem.nut")

enum eRoomFlags { //bit enum. sorted by priority
  CAN_JOIN              = 0x8000 //set by CAN_JOIN_MASK, used for sorting

  ROOM_TIER             = 0x4000 //5 bits to room tier. used only to sort rooms

  AVAILABLE_FOR_SQUAD   = 0x0100
  HAS_PLACES            = 0x0080
  HAS_PLACES_IN_MY_TEAM = 0x0040

  HAS_COUNTRY           = 0x0020
  HAS_UNIT_MATCH_RULES  = 0x0010
  HAS_AVAILABLE_UNITS   = 0x0008 //has available unis by game mode without checking room rules
  HAS_REQUIRED_UNIT     = 0x0004
  IS_ALLOWED_BY_BALANCE = 0x0002

  //masks
  NONE                  = 0x0000
  CAN_JOIN_MASK         = 0x00FE
  ALL                   = 0xFFFF
}

const EROOM_FLAGS_KEY_NAME = "_flags" //added to room root params for faster sort.
const NOTICEABLE_RESPONCE_DELAY_TIME_MS = 250

gui_handlers.EventRoomsHandler <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName   = "%gui/events/eventsModal.blk"
  wndOptionsMode = OPTIONS_MODE_MP_DOMINATION

  event = null
  hasBackToEventsButton = false

  curRoomId = ""
  curChapterId = ""
  roomIdToSelect = null
  roomsListData = null
  isSelectedRoomDataChanged = false
  roomsListObj  = null

  chaptersTree = null
  collapsedChapterNamesArray = null
  viewRoomList = null

  slotbarActions = ["aircraft", "crew", "sec_weapons", "weapons", "showroom", "repair"]

  eventDescription = null

  listIdxPID = dagui_propid_add_name_id("listIdx")
  hoveredIdx  = -1
  selectedIdx = -1
  isMouseMode = true
  initTime = -1

  showOnlyAvailableRooms = true

  static TEAM_DIVIDE = "/"
  static COUNTRY_DIVIDE = ", "

  static ROOM_ID_SPLIT = ":"
  static CHAPTER_REGEXP = regexp2(":.*$")
  static ROOM_REGEXP = regexp2(".*(:)")

  static function open(event, hasBackToEventsButton = false, roomIdToSelect = null) {
    if (!event)
      return

    if (::events.getEventDiffCode(event) == DIFFICULTY_HARDCORE &&
        !::check_package_and_ask_download("pkg_main"))
      return

    handlersManager.loadHandler(gui_handlers.EventRoomsHandler,
    {
      event = event
      hasBackToEventsButton = hasBackToEventsButton
      roomIdToSelect = roomIdToSelect
    })
  }

  function initScreen() {
    this.collapsedChapterNamesArray = []
    this.chaptersTree = []
    this.viewRoomList = {}

    if (this.hasBackToEventsButton)
      this.initFrameOverEventsWnd()

    this.updateMouseMode()
    this.roomsListObj = this.scene.findObject("items_list")
    this.roomsListData = ::MRoomsList.getMRoomsListByRequestParams({ eventEconomicName = getEventEconomicName(this.event) })
    this.eventDescription = ::create_event_description(this.scene)
    this.showOnlyAvailableRooms = loadLocalAccountSettings("events/showOnlyAvailableRooms", true)
    let obj = showObjById("only_available_rooms", true, this.scene)
    obj.setValue(this.showOnlyAvailableRooms)
    this.refreshList()
    this.fillRoomsList()
    this.updateWindow()
    this.updateClusters()

    this.scene.findObject("wnd_title").setValue(::events.getEventNameText(this.event))
    this.scene.findObject("event_update").setUserData(this)

    if (this.selectedIdx != -1) {
      this.guiScene.applyPendingChanges(false)
      move_mouse_on_child_by_value(this.roomsListObj)
    }
    else
      this.initTime = get_time_msec()
  }

  function initFrameOverEventsWnd() {
    let frameObj = this.scene.findObject("wnd_frame")
    frameObj.width = "1@slotbarWidthFull - 6@framePadding"
    frameObj.height = "1@maxWindowHeightWithSlotbar - 1@frameFooterHeight - 1@frameTopPadding"
    frameObj.top = "1@battleBtnBottomOffset - 1@frameFooterHeight - h"

    let roomsListBtn = showObjById("btn_rooms_list", true, this.scene)
    roomsListBtn.btnName = "B"
    roomsListBtn.isOpened = "yes"
    this.guiScene.applyPendingChanges(false)

    let pos = roomsListBtn.getPosRC()
    roomsListBtn.noMargin = "yes"
    pos[0] -= this.guiScene.calcString("3@framePadding", null)
    pos[1] += this.guiScene.calcString("1@frameFooterHeight", null)
    roomsListBtn.style = format("position:root; pos:%d,%d;", pos[0], pos[1])
  }

  function getCurRoom() {
    return this.roomsListData.getRoom(this.curRoomId)
  }

  function onItemSelect() {
    if (!this.isValid())
      return

    this.onItemSelectAction()
  }

  function onItemSelectAction() {
    let selItemIdx = this.roomsListObj.getValue()
    if (selItemIdx < 0 || selItemIdx >= this.roomsListObj.childrenCount())
      return
    let selItemObj = this.roomsListObj.getChild(selItemIdx)
    if (!checkObj(selItemObj) || !selItemObj?.id)
      return

    let selChapterId = this.getChapterNameByObjId(selItemObj.id)
    let selRoomId = this.getRoomIdByObjId(selItemObj.id)

    if (!this.isSelectedRoomDataChanged && selChapterId == this.curChapterId && selRoomId == this.curRoomId)
      return

    this.isSelectedRoomDataChanged = false
    this.curChapterId = selChapterId
    this.curRoomId = selRoomId
    this.selectedIdx = selItemIdx

    this.updateWindow()
  }

  function updateWindow() {
    this.createSlotbar({ eventId = this.event.name, room = this.getCurRoom() })
    this.updateDescription()
    this.updateButtons()
  }

  function onJoinEvent() {
    this.joinEvent()
  }

  function joinEvent(isFromDebriefing = false) {
    if (this.curRoomId == "")
      return

    if (!suggestAndAllowPsnPremiumFeatures())
      return

    if (!isMultiplayerPrivilegeAvailable.value) {
      checkAndShowMultiplayerPrivilegeWarning()
      return
    }

    if (isShowGoldBalanceWarning())
      return

    let configForStatistic = {
      actionPlace = isFromDebriefing ? "debriefing" : "event_window"
      economicName = getEventEconomicName(this.event)
      difficulty = this.event?.difficulty ?? ""
      canIntoToBattle = true
      missionsComplete = getMissionsComplete()
    }

    ::EventJoinProcess(this.event, this.getCurRoom(),
      @(_event) sendBqEvent("CLIENT_BATTLE_2", "to_battle_button", configForStatistic),
      function() {
        configForStatistic.canIntoToBattle <- false
        sendBqEvent("CLIENT_BATTLE_2", "to_battle_button", configForStatistic)
      })
  }

  function refreshList() {
    this.roomsListData.requestList(this.getCurFilter())
  }

  function onUpdate(_obj, _dt) {
    this.doWhenActiveOnce("refreshList")
  }

  function onEventSearchedRoomsChanged(_p) {
    this.isSelectedRoomDataChanged = true
    this.fillRoomsList()
  }

  function onOpenClusterSelect(obj) {
    ::queues.checkAndStart(
      Callback(@() openClustersMenuWnd(obj, "bottom"), this),
      null,
      "isCanChangeCluster")
  }

  function onEventClusterChange(_params) {
    this.updateClusters()
    this.fillRoomsList()
  }

  function updateClusters() {
    clustersModule.updateClusters(this.scene.findObject("cluster_select_button"))
  }

  function onEventSquadStatusChanged(_params) {
    this.updateButtons()
  }

  function onEventSquadSetReady(_params) {
    this.updateButtons()
  }

  function onEventSquadDataUpdated(_params) {
    this.updateButtons()
  }

  function updateDescription() {
    this.eventDescription.selectEvent(this.event, this.getCurRoom())
  }

  function updateButtons() {
    let hasRoom = this.curRoomId.len() != 0

    let isCurItemInFocus = this.selectedIdx >= 0 && (this.isMouseMode || this.hoveredIdx == this.selectedIdx)
    showObjById("btn_select_console", !isCurItemInFocus && this.hoveredIdx >= 0, this.scene)

    let reasonData = ::events.getCantJoinReasonData(this.event, isCurItemInFocus ? this.getCurRoom() : null)
    if (!hasRoom && !reasonData.reasonText.len())
      reasonData.reasonText = loc("multiplayer/no_room_selected")

    let roomMGM = ::SessionLobby.getMGameMode(this.getCurRoom())
    let isReady = g_squad_manager.isMeReady()
    let isSquadMember = g_squad_manager.isSquadMember()

    let joinButtonObj = showObjById("btn_join_event", isCurItemInFocus && hasRoom, this.scene)
    joinButtonObj.inactiveColor = reasonData.activeJoinButton || isSquadMember ? "no" : "yes"
    joinButtonObj.tooltip = isSquadMember ? reasonData.reasonText : ""
    let availTeams = ::events.getAvailableTeams(roomMGM)
    local startText = ""
    if (isSquadMember)
      startText = loc(isReady ? "multiplayer/btnNotReady" : "mainmenu/btnReady")
    else if (roomMGM && !::events.isEventSymmetricTeams(roomMGM) && availTeams.len() == 1)
      startText = loc("events/join_event_by_team",
        { team = ::g_team.getTeamByCode(availTeams[0]).getShortName() })
    else
      startText = loc("events/join_event")

    let battlePriceText = ::events.getEventBattleCostText(this.event, "activeTextColor", true, true)
    if (battlePriceText.len() > 0 && reasonData.activeJoinButton)
      startText += format(" (%s)", battlePriceText)

    setColoredDoubleTextToButton(this.scene, "btn_join_event", startText)
    let reasonTextObj = showObjById("cant_join_reason", reasonData.reasonText.len() > 0, this.scene)
    reasonTextObj.setValue(reasonData.reasonText)

    showObjById("btn_create_room", ::events.canCreateCustomRoom(this.event), this.scene)

    let isHeader = isCurItemInFocus && this.curChapterId != "" && this.curRoomId == ""
    let collapsedButtonObj = showObjById("btn_collapsed_chapter", isHeader, this.scene)
    if (isHeader) {
      let isCollapsedChapter = isInArray(this.curChapterId, this.collapsedChapterNamesArray)
      startText = loc(isCollapsedChapter ? "mainmenu/btnExpand" : "mainmenu/btnCollapse")
      collapsedButtonObj.setValue(startText)
    }
  }

  function getCurFilter() {
    return { clusters = clustersModule.getCurrentClusters(), hideFullRooms = false }
  }

  function checkRoomsOrder() {
    this.fillRoomsList(true)
  }

  function fillRoomsList(isUpdateOnlyWhenFlagsChanged = false) {
    let roomsList = this.roomsListData.getList()
    let isFlagsUpdated = this.updateRoomsFlags(roomsList)
    if (isUpdateOnlyWhenFlagsChanged && !isFlagsUpdated)
      return

    this.generateChapters(roomsList)
    this.updateListInfo(roomsList.len())

    if (this.initTime != -1 && this.selectedIdx != -1) {
      if (get_time_msec() - this.initTime < NOTICEABLE_RESPONCE_DELAY_TIME_MS)
        move_mouse_on_child_by_value(this.roomsListObj)
      this.initTime = -1
    }
  }

  function getMGameModeFlags(mGameMode, room, isMultiSlot) {
    local res = eRoomFlags.NONE
    let teams = ::events.getAvailableTeams(mGameMode)
    if (teams.len() == 0)
      return res
    res = res | eRoomFlags.HAS_COUNTRY

    if ((!isMultiSlot && ::events.isCurUnitMatchesRoomRules(this.event, room))
        || (isMultiSlot && ::events.checkPlayersCraftsRoomRules(this.event, room))) {
      res = res | eRoomFlags.HAS_UNIT_MATCH_RULES
      if (::events.checkRequiredUnits(mGameMode, room))
        res = res | eRoomFlags.HAS_REQUIRED_UNIT
    }

    if ((!isMultiSlot && ::events.checkCurrentCraft(mGameMode))
        || (isMultiSlot && ::events.checkPlayersCrafts(mGameMode)))
      res = res | eRoomFlags.HAS_AVAILABLE_UNITS

    if (::events.isAllowedByRoomBalance(mGameMode, room))
      res = res | eRoomFlags.IS_ALLOWED_BY_BALANCE

    if (g_squad_manager.isInSquad() && g_squad_manager.isSquadLeader()) {
      let membersTeams = ::events.getMembersTeamsData(this.event, room, teams)
      if (!(membersTeams?.haveRestrictions ?? false))
        res = res | eRoomFlags.AVAILABLE_FOR_SQUAD
    }
    else
      res = res | eRoomFlags.AVAILABLE_FOR_SQUAD

    return res
  }

  function updateRoomsFlags(roomsList) {
    local hasChanges = false
    let isMultiSlot = ::events.isEventMultiSlotEnabled(this.event)
    let needCheckAvailable = ::events.checkPlayersCrafts(this.event)
    let teamSize = ::events.getMaxTeamSize(this.event)
    foreach (room in roomsList) {
      let wasFlags = getTblValue(EROOM_FLAGS_KEY_NAME, room, eRoomFlags.NONE)
      local flags = eRoomFlags.NONE
      let mGameMode = ::events.getMGameMode(this.event, room)

      let countTbl = ::SessionLobby.getMembersCountByTeams(room)
      if (countTbl.total < 2 * teamSize) {
        flags = flags | eRoomFlags.HAS_PLACES
        let availTeams = ::events.getAvailableTeams(mGameMode)
        if (availTeams.len() > 1 || (availTeams.len() && countTbl[availTeams[0]] < teamSize))
          flags = flags | eRoomFlags.HAS_PLACES_IN_MY_TEAM
      }

      let reqUnits = ::SessionLobby.getRequiredCrafts(Team.A, room)
      if (reqUnits)
        foreach (rule in reqUnits) {
          let tier = ::events.getTierNumByRule(rule)
          if (tier > 0) {
            flags = flags | (eRoomFlags.ROOM_TIER >> (min(tier, 5) - 1))
            break
          }
        }

      if (needCheckAvailable)
        flags = flags | this.getMGameModeFlags(mGameMode, room, isMultiSlot)

      if ((flags & eRoomFlags.CAN_JOIN_MASK) == eRoomFlags.CAN_JOIN_MASK)
        flags = flags | eRoomFlags.CAN_JOIN

      room[EROOM_FLAGS_KEY_NAME] <- flags
      hasChanges = hasChanges || wasFlags != flags
    }
    return hasChanges
  }

  function isLockedByMask(flags) {
    let mustHaveMask = eRoomFlags.HAS_COUNTRY
                       | eRoomFlags.HAS_AVAILABLE_UNITS | eRoomFlags.HAS_REQUIRED_UNIT
                       | eRoomFlags.HAS_PLACES | eRoomFlags.HAS_PLACES_IN_MY_TEAM
                       | eRoomFlags.IS_ALLOWED_BY_BALANCE | eRoomFlags.AVAILABLE_FOR_SQUAD

    return (flags & mustHaveMask) != mustHaveMask
  }

  function getRoomNameView(room) {
    let roomFlags = room[EROOM_FLAGS_KEY_NAME]
    let isLocked = this.isLockedByMask(roomFlags)

    local text = ::SessionLobby.getMissionNameLoc(room)
    let reqUnits = ::SessionLobby.getRequiredCrafts(Team.A, room)
    if (reqUnits) {
      local color = ""
      if (!isLocked && !(roomFlags & eRoomFlags.HAS_UNIT_MATCH_RULES))
        color = "@warningTextColor"
      let rankText = ::events.getBrTextByRules(reqUnits)
      let ruleTexts = reqUnits.map(this.getRuleText)
      let rulesText = colorize(color, loc("ui/comma").join(ruleTexts, true))

      text = colorize(color, rankText) + " " + text
      if (rulesText.len())
        text += loc("ui/comma") + rulesText
    }

    return {
      text = text
      isLocked = isLocked
    }
  }

  function getRuleText(rule, needTierRule = false) {
    if (!needTierRule && ::events.getTierNumByRule(rule) != -1)
      return ""
    return ::events.generateEventRule(rule, true)
  }

  function updateListInfo(visibleRoomsAmount) {
    let needWaitIcon = !visibleRoomsAmount && this.roomsListData.isInUpdate
    this.scene.findObject("items_list_wait_icon").show(needWaitIcon)

    local infoText = ""
    if (!visibleRoomsAmount && !needWaitIcon)
      infoText = loc(this.roomsListData.getList().len() ? "multiplayer/no_rooms_by_clusters" : "multiplayer/no_rooms")

    this.scene.findObject("items_list_msg").setValue(infoText)
    this.roomsListObj.enable(visibleRoomsAmount && !needWaitIcon)
  }

  function getCurrentEdiff() {
    let ediff = ::events.getEDiffByEvent(this.event)
    return ediff != -1 ? ediff : getCurrentGameModeEdiff()
  }

  function onEventCountryChanged(_p) {
    this.updateButtons()
    this.checkRoomsOrder()
  }

  function updateChaptersTree(roomsList) {
    this.chaptersTree.clear()
    foreach (_idx, room in roomsList) {
      let chapterGameMode = ::SessionLobby.getMGameMode(room, true)
      let isCustomMode = ::events.isCustomGameMode(chapterGameMode)
      let isSeparateCustomRoomsList = isCustomMode && (chapterGameMode?.separateRoomsListForCustomMode ?? true)
      let itemView = {
        itemText = isSeparateCustomRoomsList
          ? colorize("activeTextColor", loc("events/playersRooms"))
          : null
      }
      local name = ""
      foreach (side in ::events.getSidesList(chapterGameMode)) {
        let countries = ::events.getCountries(::events.getTeamData(chapterGameMode, side))
        name = isSeparateCustomRoomsList ? "customRooms"
          : "|".concat(name, "_".join(countries.map(@(c) cutPrefix(c, "country_", c))))
        if (!isCustomMode || !isSeparateCustomRoomsList)
          itemView[$"{::g_team.getTeamByCode(side).name}Countries"] <- {
            country = this.getFlagsArrayByCountriesArray(countries)
        }
      }

      let foundChapter = this.chaptersTree.findvalue(@(chapter) chapter.name == name)
      if (foundChapter == null) {
        this.chaptersTree.append({
          name
          [EROOM_FLAGS_KEY_NAME] = room[EROOM_FLAGS_KEY_NAME]
          itemView
          rooms = [room]
        })
      }
      else {
        foundChapter.rooms.append(room)
        foundChapter[EROOM_FLAGS_KEY_NAME] = foundChapter[EROOM_FLAGS_KEY_NAME] | room[EROOM_FLAGS_KEY_NAME]
      }
    }

    this.chaptersTree.sort(@(a, b) b[EROOM_FLAGS_KEY_NAME] <=> a[EROOM_FLAGS_KEY_NAME])
    foreach (_idx, chapter in this.chaptersTree)
      chapter.rooms.sort(@(a, b) b[EROOM_FLAGS_KEY_NAME] <=> a[EROOM_FLAGS_KEY_NAME])

    return this.chaptersTree
  }

  function generateChapters(roomsList) {
    this.updateChaptersTree(roomsList)

    this.selectedIdx = 1 //select first room by default
    let view = { items = [] }

    foreach (_idx, chapter in this.chaptersTree) {
      let haveRooms = chapter.rooms.len() > 0
      if (!haveRooms || (this.showOnlyAvailableRooms && this.isLockedByMask(chapter[EROOM_FLAGS_KEY_NAME])))
        continue

      if (chapter.name == this.curChapterId)
        this.selectedIdx = view.items.len()

      let listRow = {
        id = chapter.name
        isCollapsable = true
        isNeedOnHover = showConsoleButtons.value
      }.__update(chapter.itemView)
      view.items.append(listRow)

      foreach (_roomIdx, room in chapter.rooms) {
        if (this.showOnlyAvailableRooms && this.isLockedByMask(room[EROOM_FLAGS_KEY_NAME]))
          continue

        let roomId = room.roomId
        if (roomId == this.curRoomId || roomId == this.roomIdToSelect) {
          this.selectedIdx = view.items.len()
          if (roomId == this.roomIdToSelect)
            this.curRoomId = this.roomIdToSelect
        }

        let nameView = this.getRoomNameView(room)

        view.items.append({
          id = chapter.name + this.ROOM_ID_SPLIT + roomId
          isBattle = ::SessionLobby.isSessionStartedInRoom(room)
          itemText = nameView.text
          isLocked = nameView.isLocked
          isNeedOnHover = showConsoleButtons.value
        })
      }
    }

    if (u.isEqual(this.viewRoomList, view))
      return this.updateWindow()

    this.viewRoomList = view
    let data = handyman.renderCached("%gui/events/eventRoomsList.tpl", view)
    this.guiScene.replaceContentFromText(this.roomsListObj, data, data.len(), this)
    let roomsCount = this.roomsListObj.childrenCount()
    for (local i = 0; i < roomsCount; i++)
      this.roomsListObj.getChild(i).setIntProp(this.listIdxPID, i)

    if (roomsCount > 0) {
      this.roomsListObj.setValue(this.selectedIdx)
      if (this.roomIdToSelect == this.curRoomId)
        this.roomIdToSelect = null
    }
    else {
      this.selectedIdx = -1
      this.curRoomId = ""
      this.curChapterId = ""
      this.updateWindow()
    }

    this.updateCollapseChaptersStatuses()
  }

  function getFlagsArrayByCountriesArray(countriesArray) {
    return countriesArray.map(@(country) { image = getCountryIcon(country) })
  }

  function onCollapsedChapter() {
    this.collapse(this.curChapterId)
    this.updateButtons()
  }

  function onCollapse(obj) {
    if (!obj)
      return

    let id = obj.id
    if (id.len() <= 4 || id.slice(0, 4) != "btn_")
      return

    let listItemCount = this.roomsListObj.childrenCount()
    for (local i = 0; i < listItemCount; i++) {
      let listItemId = this.roomsListObj.getChild(i).id
      if (listItemId == id.slice(4)) {
        this.collapse(listItemId)
        break
      }
    }
    this.updateButtons()
  }

  function updateCollapseChaptersStatuses() {
    if (!checkObj(this.roomsListObj))
      return

    for (local i = 0; i < this.roomsListObj.childrenCount(); i++) {
      let obj = this.roomsListObj.getChild(i)
      let chapterName = this.getChapterNameByObjId(obj.id)

      let isCollapsedChapter = isInArray(chapterName, this.collapsedChapterNamesArray)
      if (!isCollapsedChapter)
        continue

      if (obj.id == chapterName)
        obj.collapsed = "yes"
      else {
        obj.show(false)
        obj.enable(false)
      }
    }
  }

  function updateCollapseChapterStatus(chapterObj) {
    let index = u.find_in_array(this.collapsedChapterNamesArray, chapterObj.id)
    let isCollapse = index < 0
    if (isCollapse)
      this.collapsedChapterNamesArray.append(chapterObj.id)
    else
      this.collapsedChapterNamesArray.remove(index)

    chapterObj.collapsed = isCollapse ? "yes" : "no"
  }

  function collapse(itemName = null) {
    if (!checkObj(this.roomsListObj))
      return

    let chapterId = itemName && this.getChapterNameByObjId(itemName)
    local newValue = -1

    this.guiScene.setUpdatesEnabled(false, false)
    for (local i = 0; i < this.roomsListObj.childrenCount(); i++) {
      let obj = this.roomsListObj.getChild(i)
      if (obj.id == itemName) { //is chapter block, can collapse
        this.updateCollapseChapterStatus(obj)
        newValue = i
        continue
      }

      let iChapter = this.getChapterNameByObjId(obj.id)
      if (iChapter != chapterId)
        continue

      let show = !isInArray(iChapter, this.collapsedChapterNamesArray)
      obj.enable(show)
      obj.show(show)
    }
    this.guiScene.setUpdatesEnabled(true, true)

    if (newValue >= 0)
      this.roomsListObj.setValue(newValue)
  }

  function getChapterNameByObjId(id) {
    return this.CHAPTER_REGEXP.replace("", id)
  }

  function getRoomIdByObjId(id) {
    let result = this.ROOM_REGEXP.replace("", id)
    if (result == id)
      return ""
    return result
  }

  function getObjIdByChapterNameRoomId(chapterName, roomId) {
    return chapterName + "/" + roomId
  }

  _isDelayedCrewchangedStarted = false
  function onEventCrewChanged(_p) {
    if (this._isDelayedCrewchangedStarted) //!!FIX ME: need to solve multiple CrewChanged events after change preset
      return
    this._isDelayedCrewchangedStarted = true
    this.guiScene.performDelayed(this, function() {
      if (!this.isValid())
        return
      this._isDelayedCrewchangedStarted = false
      this.updateButtons()
      this.checkRoomsOrder()
    })
  }

  function onEventAfterJoinEventRoom(_ev) {
    handlersManager.requestHandlerRestore(this, gui_handlers.EventsHandler)
  }

  function onEventEventsDataUpdated(_p) {
    //is event still exist
    if (::events.getEventByEconomicName(getEventEconomicName(this.event)))
      return

    this.guiScene.performDelayed(this, function() {
      if (this.isValid())
        this.goBack()
    })
  }

  function getHandlerRestoreData() {
    return {
      openData = {
        event = this.event
        hasBackToEventsButton = this.hasBackToEventsButton
      }
    }
  }

  function onCreateRoom() {
    if (!antiCheat.showMsgboxIfEacInactive(this.event) ||
        !showMsgboxIfSoundModsNotAllowed(this.event))
      return

    if (hasMultiplayerLimitByAas.get()) {
      showMultiplayerLimitByAasMsg()
      return
    }

    let diffCode = ::events.getEventDiffCode(this.event)
    let unitTypeMask = ::events.getEventUnitTypesMask(this.event)
    let checkTutorUnitType = (stdMath.number_of_set_bits(unitTypeMask) == 1) ? stdMath.number_of_set_bits(unitTypeMask - 1) : null
    if (checkDiffTutorial(diffCode, checkTutorUnitType))
      return

    ::events.openCreateRoomWnd(this.event)
  }

  function onItemDblClick() {
    if (showConsoleButtons.value)
      return

    if (this.curRoomId == "") {
      this.collapse(this.curChapterId)
      this.updateButtons()
    }
    else
      this.joinEvent()
  }

  function onItemHover(obj) {
    if (!showConsoleButtons.value)
      return
    let isHover = obj.isHovered()
    let idx = obj.getIntProp(this.listIdxPID, -1)
    if (isHover == (this.hoveredIdx == idx))
      return
    this.hoveredIdx = isHover ? idx : -1
    this.updateMouseMode()
    this.updateButtons()
  }

  function onHoveredItemSelect(_obj) {
    if (this.hoveredIdx != -1 && checkObj(this.roomsListObj))
      this.roomsListObj.setValue(this.hoveredIdx)
  }

  function updateMouseMode() {
    this.isMouseMode = !showConsoleButtons.value || is_mouse_last_time_used()
  }

  function goBackShortcut() { this.goBack() }
  function onRoomsList()    { this.goBack() }

  function onLeaveEvent() {}
  function onDownloadPack() {}
  function onQueueOptions() {}

  function onShowOnlyAvailableRooms(obj) {
    let newValue = obj.getValue()
    if (newValue == this.showOnlyAvailableRooms)
      return

    this.showOnlyAvailableRooms = newValue
    saveLocalAccountSettings("events/showOnlyAvailableRooms", newValue)
    this.fillRoomsList()
  }
}
