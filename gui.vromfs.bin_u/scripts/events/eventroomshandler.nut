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

::gui_handlers.EventRoomsHandler <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName   = "%gui/events/eventsModal.blk"
  wndOptionsMode = ::OPTIONS_MODE_MP_DOMINATION

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

  listIdxPID = ::dagui_propid.add_name_id("listIdx")
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

  static function open(event, hasBackToEventsButton = false, roomIdToSelect = null)
  {
    if (!event)
      return

    if (::events.getEventDiffCode(event) == ::DIFFICULTY_HARDCORE &&
        !::check_package_and_ask_download("pkg_main"))
      return

    ::handlersManager.loadHandler(::gui_handlers.EventRoomsHandler,
    {
      event = event
      hasBackToEventsButton = hasBackToEventsButton
      roomIdToSelect = roomIdToSelect
    })
  }

  function initScreen()
  {
    collapsedChapterNamesArray = []
    chaptersTree = []
    viewRoomList = {}

    if (hasBackToEventsButton)
      initFrameOverEventsWnd()

    updateMouseMode()
    roomsListObj = scene.findObject("items_list")
    roomsListData = ::MRoomsList.getMRoomsListByRequestParams({ eventEconomicName = ::events.getEventEconomicName(event) })
    eventDescription = ::create_event_description(scene)
    showOnlyAvailableRooms = ::load_local_account_settings("events/showOnlyAvailableRooms", true)
    let obj = this.showSceneBtn("only_available_rooms", true)
    obj.setValue(showOnlyAvailableRooms)
    refreshList()
    fillRoomsList()
    updateWindow()
    updateClusters()

    scene.findObject("wnd_title").setValue(::events.getEventNameText(event))
    scene.findObject("event_update").setUserData(this)

    if (selectedIdx != -1)
    {
      guiScene.applyPendingChanges(false)
      ::move_mouse_on_child_by_value(roomsListObj)
    }
    else
      initTime = ::dagor.getCurTime()
  }

  function initFrameOverEventsWnd()
  {
    let frameObj = scene.findObject("wnd_frame")
    frameObj.width = "1@slotbarWidthFull - 6@framePadding"
    frameObj.height = "1@maxWindowHeightWithSlotbar - 1@frameFooterHeight - 1@frameTopPadding"
    frameObj.top = "1@battleBtnBottomOffset - 1@frameFooterHeight - h"

    let roomsListBtn = this.showSceneBtn("btn_rooms_list", true)
    roomsListBtn.btnName = "B"
    roomsListBtn.isOpened = "yes"
    guiScene.applyPendingChanges(false)

    let pos = roomsListBtn.getPosRC()
    roomsListBtn.noMargin = "yes"
    pos[0] -= guiScene.calcString("3@framePadding", null)
    pos[1] += guiScene.calcString("1@frameFooterHeight", null)
    roomsListBtn.style = format("position:root; pos:%d,%d;", pos[0], pos[1])
  }

  function getCurRoom()
  {
    return roomsListData.getRoom(curRoomId)
  }

  function onItemSelect()
  {
    if (!isValid())
      return

    onItemSelectAction()
  }

  function onItemSelectAction()
  {
    let selItemIdx = roomsListObj.getValue()
    if (selItemIdx < 0 || selItemIdx >= roomsListObj.childrenCount())
      return
    let selItemObj = roomsListObj.getChild(selItemIdx)
    if (!::check_obj(selItemObj) || !selItemObj?.id)
      return

    let selChapterId = getChapterNameByObjId(selItemObj.id)
    let selRoomId = getRoomIdByObjId(selItemObj.id)

    if (!isSelectedRoomDataChanged && selChapterId == curChapterId && selRoomId == curRoomId)
      return

    isSelectedRoomDataChanged = false
    curChapterId = selChapterId
    curRoomId = selRoomId
    selectedIdx = selItemIdx

    updateWindow()
  }

  function updateWindow()
  {
    createSlotbar({ eventId = event.name, room = getCurRoom() })
    updateDescription()
    updateButtons()
  }

  function onJoinEvent()
  {
    joinEvent()
  }

  function joinEvent(isFromDebriefing = false)
  {
    if (curRoomId == "")
      return

    if (!suggestAndAllowPsnPremiumFeatures())
      return

    if (!isMultiplayerPrivilegeAvailable.value) {
      checkAndShowMultiplayerPrivilegeWarning()
      return
    }

    let configForStatistic = {
      actionPlace = isFromDebriefing ? "debriefing" : "event_window"
      economicName = ::events.getEventEconomicName(event)
      difficulty = event?.difficulty ?? ""
      canIntoToBattle = true
      missionsComplete = ::my_stats.getMissionsComplete()
    }

    ::EventJoinProcess(event, getCurRoom(),
      @(event) ::add_big_query_record("to_battle_button", ::save_to_json(configForStatistic)),
      function() {
        configForStatistic.canIntoToBattle <- false
        ::add_big_query_record("to_battle_button", ::save_to_json(configForStatistic))
      })
  }

  function refreshList()
  {
    roomsListData.requestList(getCurFilter())
  }

  function onUpdate(obj, dt)
  {
    doWhenActiveOnce("refreshList")
  }

  function onEventSearchedRoomsChanged(p)
  {
    isSelectedRoomDataChanged = true
    fillRoomsList()
  }

  function onOpenClusterSelect(obj)
  {
    ::queues.checkAndStart(
      ::Callback(@() clustersModule.createClusterSelectMenu(obj, "bottom"), this),
      null,
      "isCanChangeCluster")
  }

  function onEventClusterChange(params)
  {
    updateClusters()
    fillRoomsList()
  }

  function updateClusters()
  {
    clustersModule.updateClusters(scene.findObject("cluster_select_button"))
  }

  function onEventSquadStatusChanged(params)
  {
    updateButtons()
  }

  function onEventSquadSetReady(params)
  {
    updateButtons()
  }

  function onEventSquadDataUpdated(params)
  {
    updateButtons()
  }

  function updateDescription()
  {
    eventDescription.selectEvent(event, getCurRoom())
  }

  function updateButtons()
  {
    let hasRoom = curRoomId.len() != 0

    let isCurItemInFocus = selectedIdx >= 0 && (isMouseMode || hoveredIdx == selectedIdx)
    this.showSceneBtn("btn_select_console", !isCurItemInFocus && hoveredIdx >= 0)

    let reasonData = ::events.getCantJoinReasonData(event, isCurItemInFocus ? getCurRoom() : null)
    if (!hasRoom && !reasonData.reasonText.len())
      reasonData.reasonText = ::loc("multiplayer/no_room_selected")

    let roomMGM = ::SessionLobby.getMGameMode(getCurRoom())
    let isReady = ::g_squad_manager.isMeReady()
    let isSquadMember = ::g_squad_manager.isSquadMember()

    let joinButtonObj = this.showSceneBtn("btn_join_event", isCurItemInFocus && hasRoom)
    joinButtonObj.inactiveColor = reasonData.activeJoinButton || isSquadMember ? "no" : "yes"
    joinButtonObj.tooltip = isSquadMember ? reasonData.reasonText : ""
    let availTeams = ::events.getAvailableTeams(roomMGM)
    local startText = ""
    if (isSquadMember)
      startText = ::loc(isReady ? "multiplayer/btnNotReady" : "mainmenu/btnReady")
    else if (roomMGM && !::events.isEventSymmetricTeams(roomMGM) && availTeams.len() == 1)
      startText = ::loc("events/join_event_by_team",
        { team = ::g_team.getTeamByCode(availTeams[0]).getShortName() })
    else
      startText = ::loc("events/join_event")

    let battlePriceText = ::events.getEventBattleCostText(event, "activeTextColor", true, true)
    if (battlePriceText.len() > 0 && reasonData.activeJoinButton)
      startText += format(" (%s)", battlePriceText)

    setColoredDoubleTextToButton(scene, "btn_join_event", startText)
    let reasonTextObj = this.showSceneBtn("cant_join_reason", reasonData.reasonText.len() > 0)
    reasonTextObj.setValue(reasonData.reasonText)

    this.showSceneBtn("btn_create_room", ::events.canCreateCustomRoom(event))

    let isHeader = isCurItemInFocus && curChapterId != "" && curRoomId == ""
    let collapsedButtonObj = this.showSceneBtn("btn_collapsed_chapter", isHeader)
    if (isHeader)
    {
      let isCollapsedChapter = ::isInArray(curChapterId, collapsedChapterNamesArray)
      startText = ::loc(isCollapsedChapter ? "mainmenu/btnExpand" : "mainmenu/btnCollapse")
      collapsedButtonObj.setValue(startText)
    }
  }

  function getCurFilter()
  {
    return { clusters = clustersModule.getCurrentClusters(), hideFullRooms = false }
  }

  function checkRoomsOrder()
  {
    fillRoomsList(true)
  }

  function fillRoomsList(isUpdateOnlyWhenFlagsChanged = false)
  {
    let roomsList = roomsListData.getList()
    let isFlagsUpdated = updateRoomsFlags(roomsList)
    if (isUpdateOnlyWhenFlagsChanged && !isFlagsUpdated)
      return

    generateChapters(roomsList)
    updateListInfo(roomsList.len())

    if (initTime != -1 && selectedIdx != -1)
    {
      if (::dagor.getCurTime() - initTime < NOTICEABLE_RESPONCE_DELAY_TIME_MS)
        ::move_mouse_on_child_by_value(roomsListObj)
      initTime = -1
    }
  }

  function getMGameModeFlags(mGameMode, room, isMultiSlot)
  {
    local res = eRoomFlags.NONE
    let teams = ::events.getAvailableTeams(mGameMode)
    if (teams.len() == 0)
      return res
    res = res | eRoomFlags.HAS_COUNTRY

    if ((!isMultiSlot && ::events.isCurUnitMatchesRoomRules(event, room))
        || (isMultiSlot && ::events.checkPlayersCraftsRoomRules(event, room)))
    {
      res = res | eRoomFlags.HAS_UNIT_MATCH_RULES
      if (::events.checkRequiredUnits(mGameMode, room))
        res = res | eRoomFlags.HAS_REQUIRED_UNIT
    }

    if ((!isMultiSlot && ::events.checkCurrentCraft(mGameMode))
        || (isMultiSlot && ::events.checkPlayersCrafts(mGameMode)))
      res = res | eRoomFlags.HAS_AVAILABLE_UNITS

    if (::events.isAllowedByRoomBalance(mGameMode, room))
      res = res | eRoomFlags.IS_ALLOWED_BY_BALANCE

    if (::g_squad_manager.isInSquad() && ::g_squad_manager.isSquadLeader()) {
      let membersTeams = ::events.getMembersTeamsData(event, room, teams)
      if (!(membersTeams?.haveRestrictions ?? false))
        res = res | eRoomFlags.AVAILABLE_FOR_SQUAD
    }
    else
      res = res | eRoomFlags.AVAILABLE_FOR_SQUAD

    return res
  }

  function updateRoomsFlags(roomsList)
  {
    local hasChanges = false
    let isMultiSlot = ::events.isEventMultiSlotEnabled(event)
    let needCheckAvailable = ::events.checkPlayersCrafts(event)
    let teamSize = ::events.getMaxTeamSize(event)
    foreach(room in roomsList)
    {
      let wasFlags = ::getTblValue(EROOM_FLAGS_KEY_NAME, room, eRoomFlags.NONE)
      local flags = eRoomFlags.NONE
      let mGameMode = ::events.getMGameMode(event, room)

      let countTbl = ::SessionLobby.getMembersCountByTeams(room)
      if (countTbl.total < 2 * teamSize)
      {
        flags = flags | eRoomFlags.HAS_PLACES
        let availTeams = ::events.getAvailableTeams(mGameMode)
        if (availTeams.len() > 1 || (availTeams.len() && countTbl[availTeams[0]] < teamSize))
          flags = flags | eRoomFlags.HAS_PLACES_IN_MY_TEAM
      }

      let reqUnits = ::SessionLobby.getRequiredCrafts(Team.A, room)
      if (reqUnits)
        foreach(rule in reqUnits)
        {
          let tier = ::events.getTierNumByRule(rule)
          if (tier > 0)
          {
            flags = flags | (eRoomFlags.ROOM_TIER >> (min(tier, 5) - 1))
            break
          }
        }

      if (needCheckAvailable)
        flags = flags | getMGameModeFlags(mGameMode, room, isMultiSlot)

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

  function getRoomNameView(room)
  {
    let roomFlags = room[EROOM_FLAGS_KEY_NAME]
    let isLocked = isLockedByMask(roomFlags)

    local text = ::SessionLobby.getMissionNameLoc(room)
    let reqUnits = ::SessionLobby.getRequiredCrafts(Team.A, room)
    if (reqUnits)
    {
      local color = ""
      if (!isLocked && !(roomFlags & eRoomFlags.HAS_UNIT_MATCH_RULES))
        color = "@warningTextColor"
      let rankText = ::events.getBrTextByRules(reqUnits)
      let ruleTexts = ::u.map(reqUnits, getRuleText)
      let rulesText = ::colorize(color, ::g_string.implode(ruleTexts, ::loc("ui/comma")))

      text = ::colorize(color, rankText) + " " + text
      if (rulesText.len())
        text += ::loc("ui/comma") + rulesText
    }

    return {
      text = text
      isLocked = isLocked
    }
  }

  function getRuleText(rule, needTierRule = false)
  {
    if (!needTierRule && ::events.getTierNumByRule(rule) != -1)
      return ""
    return ::events.generateEventRule(rule, true)
  }

  function updateListInfo(visibleRoomsAmount)
  {
    let needWaitIcon = !visibleRoomsAmount && roomsListData.isInUpdate
    scene.findObject("items_list_wait_icon").show(needWaitIcon)

    local infoText = ""
    if (!visibleRoomsAmount && !needWaitIcon)
      infoText = ::loc(roomsListData.getList().len() ? "multiplayer/no_rooms_by_clusters" : "multiplayer/no_rooms")

    scene.findObject("items_list_msg").setValue(infoText)
    roomsListObj.enable(visibleRoomsAmount && !needWaitIcon)
  }

  function getCurrentEdiff()
  {
    let ediff = ::events.getEDiffByEvent(event)
    return ediff != -1 ? ediff : ::get_current_ediff()
  }

  function onEventCountryChanged(p)
  {
    updateButtons()
    checkRoomsOrder()
  }

  function updateChaptersTree(roomsList)
  {
    chaptersTree.clear()
    foreach (idx, room in roomsList)
    {
      let chapterGameMode = ::SessionLobby.getMGameMode(room, true)
      let isCustomMode = ::events.isCustomGameMode(chapterGameMode)
      let isSeparateCustomRoomsList = isCustomMode && (chapterGameMode?.separateRoomsListForCustomMode ?? true)
      let itemView = {
        itemText = isSeparateCustomRoomsList
          ? ::colorize("activeTextColor", ::loc("events/playersRooms"))
          : null
      }
      local name = ""
      foreach(side in ::events.getSidesList(chapterGameMode)) {
        let countries = ::events.getCountries(::events.getTeamData(chapterGameMode, side))
        name = isSeparateCustomRoomsList ? "customRooms"
          : "|".concat(name, "_".join(countries.map(@(c) cutPrefix(c, "country_", c))))
        if (!isCustomMode || !isSeparateCustomRoomsList)
          itemView[$"{::g_team.getTeamByCode(side).name}Countries"] <- {
            country = getFlagsArrayByCountriesArray(countries)
        }
      }

      let foundChapter = chaptersTree.findvalue(@(chapter) chapter.name == name)
      if (foundChapter == null)
      {
        chaptersTree.append({
          name
          [EROOM_FLAGS_KEY_NAME] = room[EROOM_FLAGS_KEY_NAME]
          itemView
          rooms = [room]
        })
      }
      else
      {
        foundChapter.rooms.append(room)
        foundChapter[EROOM_FLAGS_KEY_NAME] = foundChapter[EROOM_FLAGS_KEY_NAME] | room[EROOM_FLAGS_KEY_NAME]
      }
    }

    chaptersTree.sort(@(a, b) b[EROOM_FLAGS_KEY_NAME] <=> a[EROOM_FLAGS_KEY_NAME])
    foreach (idx, chapter in chaptersTree)
      chapter.rooms.sort(@(a, b) b[EROOM_FLAGS_KEY_NAME] <=> a[EROOM_FLAGS_KEY_NAME])

    return chaptersTree
  }

  function generateChapters(roomsList)
  {
    updateChaptersTree(roomsList)

    selectedIdx = 1 //select first room by default
    let view = { items = [] }

    foreach (idx, chapter in chaptersTree)
    {
      let haveRooms = chapter.rooms.len() > 0
      if (!haveRooms || (showOnlyAvailableRooms && isLockedByMask(chapter[EROOM_FLAGS_KEY_NAME])))
        continue

      if (chapter.name == curChapterId)
        selectedIdx = view.items.len()

      let listRow = {
        id = chapter.name
        isCollapsable = true
        isNeedOnHover = ::show_console_buttons
      }.__update(chapter.itemView)
      view.items.append(listRow)

      foreach (roomIdx, room in chapter.rooms)
      {
        if (showOnlyAvailableRooms && isLockedByMask(room[EROOM_FLAGS_KEY_NAME]))
          continue

        let roomId = room.roomId
        if (roomId == curRoomId || roomId == roomIdToSelect)
        {
          selectedIdx = view.items.len()
          if (roomId == roomIdToSelect)
            curRoomId = roomIdToSelect
        }

        let nameView = getRoomNameView(room)

        view.items.append({
          id = chapter.name + ROOM_ID_SPLIT + roomId
          isBattle = ::SessionLobby.isSessionStartedInRoom(room)
          itemText = nameView.text
          isLocked = nameView.isLocked
          isNeedOnHover = ::show_console_buttons
        })
      }
    }

    if (::u.isEqual(viewRoomList, view))
      return updateWindow()

    viewRoomList = view
    let data = ::handyman.renderCached("%gui/events/eventRoomsList", view)
    guiScene.replaceContentFromText(roomsListObj, data, data.len(), this)
    let roomsCount = roomsListObj.childrenCount()
    for (local i = 0; i < roomsCount; i++)
      roomsListObj.getChild(i).setIntProp(listIdxPID, i)

    if (roomsCount > 0)
    {
      roomsListObj.setValue(selectedIdx)
      if (roomIdToSelect == curRoomId)
        roomIdToSelect = null
    }
    else
    {
      selectedIdx = -1
      curRoomId = ""
      curChapterId = ""
      updateWindow()
    }

    updateCollapseChaptersStatuses()
  }

  function getFlagsArrayByCountriesArray(countriesArray)
  {
    return ::u.map(
              countriesArray,
              function(country)
              {
                return {image = ::get_country_icon(country)}
              }
            )
  }

  function onCollapsedChapter()
  {
    collapse(curChapterId)
    updateButtons()
  }

  function onCollapse(obj)
  {
    if (!obj)
      return

    let id = obj.id
    if (id.len() <= 4 || id.slice(0, 4) != "btn_")
      return

    let listItemCount = roomsListObj.childrenCount()
    for (local i = 0; i < listItemCount; i++)
    {
      let listItemId = roomsListObj.getChild(i).id
      if (listItemId == id.slice(4))
      {
        collapse(listItemId)
        break
      }
    }
    updateButtons()
  }

  function updateCollapseChaptersStatuses()
  {
    if (!::check_obj(roomsListObj))
      return

    for (local i = 0; i < roomsListObj.childrenCount(); i++)
    {
      let obj = roomsListObj.getChild(i)
      let chapterName = getChapterNameByObjId(obj.id)

      let isCollapsedChapter = ::isInArray(chapterName, collapsedChapterNamesArray)
      if (!isCollapsedChapter)
        continue

      if (obj.id == chapterName)
        obj.collapsed = "yes"
      else
      {
        obj.show(false)
        obj.enable(false)
      }
    }
  }

  function updateCollapseChapterStatus(chapterObj)
  {
    let index = ::find_in_array(collapsedChapterNamesArray, chapterObj.id)
    let isCollapse = index < 0
    if (isCollapse)
      collapsedChapterNamesArray.append(chapterObj.id)
    else
      collapsedChapterNamesArray.remove(index)

    chapterObj.collapsed = isCollapse ? "yes" : "no"
  }

  function collapse(itemName = null)
  {
    if (!::check_obj(roomsListObj))
      return

    let chapterId = itemName && getChapterNameByObjId(itemName)
    local newValue = -1

    guiScene.setUpdatesEnabled(false, false)
    for (local i = 0; i < roomsListObj.childrenCount(); i++)
    {
      let obj = roomsListObj.getChild(i)
      if (obj.id == itemName) //is chapter block, can collapse
      {
        updateCollapseChapterStatus(obj)
        newValue = i
        continue
      }

      let iChapter = getChapterNameByObjId(obj.id)
      if (iChapter != chapterId)
        continue

      let show = !::isInArray(iChapter, collapsedChapterNamesArray)
      obj.enable(show)
      obj.show(show)
    }
    guiScene.setUpdatesEnabled(true, true)

    if (newValue >= 0)
      roomsListObj.setValue(newValue)
  }

  function getChapterNameByObjId(id)
  {
    return CHAPTER_REGEXP.replace("", id)
  }

  function getRoomIdByObjId(id)
  {
    let result = ROOM_REGEXP.replace("", id)
    if (result == id)
      return ""
    return result
  }

  function getObjIdByChapterNameRoomId(chapterName, roomId)
  {
    return chapterName + "/" + roomId
  }

  _isDelayedCrewchangedStarted = false
  function onEventCrewChanged(p)
  {
    if (_isDelayedCrewchangedStarted) //!!FIX ME: need to solve multiple CrewChanged events after change preset
      return
    _isDelayedCrewchangedStarted = true
    guiScene.performDelayed(this, function()
    {
      if (!isValid())
        return
      _isDelayedCrewchangedStarted = false
      updateButtons()
      checkRoomsOrder()
    })
  }

  function onEventAfterJoinEventRoom(ev)
  {
    ::handlersManager.requestHandlerRestore(this, ::gui_handlers.EventsHandler)
  }

  function onEventEventsDataUpdated(p)
  {
    //is event still exist
    if (::events.getEventByEconomicName(::events.getEventEconomicName(event)))
      return

    guiScene.performDelayed(this, function()
    {
      if (isValid())
        goBack()
    })
  }

  function getHandlerRestoreData()
  {
    return {
      openData = {
        event = event
        hasBackToEventsButton = hasBackToEventsButton
      }
    }
  }

  function onCreateRoom()
  {
    if (!antiCheat.showMsgboxIfEacInactive(event)||
        !showMsgboxIfSoundModsNotAllowed(event))
      return

    let diffCode = ::events.getEventDiffCode(event)
    let unitTypeMask = ::events.getEventUnitTypesMask(event)
    let checkTutorUnitType = (stdMath.number_of_set_bits(unitTypeMask)==1) ? stdMath.number_of_set_bits(unitTypeMask - 1) : null
    if(checkDiffTutorial(diffCode, checkTutorUnitType))
      return

    ::events.openCreateRoomWnd(event)
  }

  function onItemDblClick() {
    if (::show_console_buttons)
      return

    if (curRoomId == "") {
      collapse(curChapterId)
      updateButtons()
    } else
      joinEvent()
  }

  function onItemHover(obj)
  {
    if (!::show_console_buttons)
      return
    let isHover = obj.isHovered()
    let idx = obj.getIntProp(listIdxPID, -1)
    if (isHover == (hoveredIdx == idx))
      return
    hoveredIdx = isHover ? idx : -1
    updateMouseMode()
    updateButtons()
  }

  function onHoveredItemSelect(obj)
  {
    if (hoveredIdx != -1 && ::check_obj(roomsListObj))
      roomsListObj.setValue(hoveredIdx)
  }

  function updateMouseMode()
  {
    isMouseMode = !::show_console_buttons || ::is_mouse_last_time_used()
  }

  function goBackShortcut() { goBack() }
  function onRoomsList()    { goBack() }

  function onLeaveEvent() {}
  function onDownloadPack() {}
  function onQueueOptions() {}

  function onShowOnlyAvailableRooms(obj) {
    let newValue = obj.getValue()
    if (newValue == showOnlyAvailableRooms)
      return

    showOnlyAvailableRooms = newValue
    ::save_local_account_settings("events/showOnlyAvailableRooms", newValue)
    fillRoomsList()
  }
}
