local stdMath = require("std/math.nut")
local clustersModule = require("scripts/clusterSelect.nut")
local antiCheat = require("scripts/penitentiary/antiCheat.nut")

enum eRoomFlags { //bit enum. sorted by priority
  CAN_JOIN              = 0x8000 //set by CAN_JOIN_MASK, used for sorting

  ROOM_TIER             = 0x4000 //5 bits to room tier. used only to sort rooms

  //                    = 0x0100
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

class ::gui_handlers.EventRoomsHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName   = "gui/events/eventsModal.blk"
  wndOptionsMode = ::OPTIONS_MODE_MP_DOMINATION

  event = null
  hasBackToEventsButton = false

  curRoomId = ""
  curChapterId = ""
  roomIdToSelect = null
  roomsListData = null
  isSelectedRoomDataChanged = false
  isEventsListInFocus = false
  roomsListObj  = null

  chaptersTree = null
  collapsedChapterNamesArray = null
  viewRoomList = null

  slotbarActions = ["aircraft", "crew", "weapons", "showroom", "repair"]

  eventDescription = null

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

    roomsListObj = scene.findObject("items_list")
    roomsListData = ::MRoomsList.getMRoomsListByRequestParams({ eventEconomicName = ::events.getEventEconomicName(event) })
    eventDescription = ::create_event_description(scene)
    refreshList()
    fillRoomsList()
    updateWindow()
    updateClusters()

    scene.findObject("wnd_title").setValue(::events.getEventNameText(event))
    scene.findObject("event_update").setUserData(this)
    initFocusArray()
  }

  function initFrameOverEventsWnd()
  {
    local frameObj = scene.findObject("wnd_frame")
    frameObj.width = "1@slotbarWidthFull - 6@framePadding"
    frameObj.height = "1@maxWindowHeightWithSlotbar - 1@frameFooterHeight - 1@frameTopPadding"
    frameObj.top = "1@battleBtnBottomOffset - 1@frameFooterHeight - h"

    local roomsListBtn = showSceneBtn("btn_rooms_list", true)
    roomsListBtn.btnName = "B"
    roomsListBtn.isOpened = "yes"
    guiScene.applyPendingChanges(false)

    local pos = roomsListBtn.getPosRC()
    roomsListBtn.noMargin = "yes"
    pos[0] -= guiScene.calcString("3@framePadding", null)
    pos[1] += guiScene.calcString("1@frameFooterHeight", null)
    roomsListBtn.style = format("position:root; pos:%d,%d;", pos[0], pos[1])
  }

  function getMainFocusObj()
  {
    return roomsListObj
  }

  function getCurRoom()
  {
    return roomsListData.getRoom(curRoomId)
  }

  function updateEventsListFocusStatus()
  {
    isEventsListInFocus = !::show_console_buttons || (::check_obj(roomsListObj) && roomsListObj.isFocused())
  }

  function onItemSelect()
  {
    if (!isValid())
      return

    updateEventsListFocusStatus()
    onItemSelectAction()
  }

  function onListItemsFocusChange(obj)
  {
    guiScene.performDelayed(this, function() {
      if (!isValid())
        return

      updateEventsListFocusStatus()
      updateButtons()
    })
  }

  function onItemSelectAction()
  {
    local selItemIdx = roomsListObj.getValue()
    if (selItemIdx < 0 || selItemIdx >= roomsListObj.childrenCount())
      return
    local selItemObj = roomsListObj.getChild(selItemIdx)
    if (!::check_obj(selItemObj) || !selItemObj?.id)
      return

    local selChapterId = getChapterNameByObjId(selItemObj.id)
    local selRoomId = getRoomIdByObjId(selItemObj.id)

    if (!isSelectedRoomDataChanged && selChapterId == curChapterId && selRoomId == curRoomId)
      return

    isSelectedRoomDataChanged = false
    curChapterId = selChapterId
    curRoomId = selRoomId

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

    local configForStatistic = {
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
    roomsListData.requestList()
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
    clustersModule.updateClusters(scene.findObject("cluster_select_button_text"))
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
    local hasRoom = curRoomId.len() != 0
    local reasonData = ::events.getCantJoinReasonData(event, getCurRoom())
    if (!hasRoom && !reasonData.reasonText.len())
      reasonData.reasonText = ::loc("multiplayer/no_room_selected")

    local roomMGM = ::SessionLobby.getMGameMode(getCurRoom())
    local isReady = ::g_squad_manager.isMeReady()
    local isSquadMember = ::g_squad_manager.isSquadMember()

    local joinButtonObj = showSceneBtn("btn_join_event", isEventsListInFocus && hasRoom)
    joinButtonObj.inactiveColor = reasonData.activeJoinButton || isSquadMember ? "no" : "yes"
    joinButtonObj.tooltip = isSquadMember ? reasonData.reasonText : ""
    local availTeams = ::events.getAvailableTeams(roomMGM)
    local startText = ""
    if (isSquadMember)
      startText = ::loc(isReady ? "multiplayer/btnNotReady" : "mainmenu/btnReady")
    else if (roomMGM && !::events.isEventSymmetricTeams(roomMGM) && availTeams.len() == 1)
      startText = ::loc("events/join_event_by_team",
        { team = ::g_team.getTeamByCode(availTeams[0]).getShortName() })
    else
      startText = ::loc("events/join_event")

    local battlePriceText = ::events.getEventBattleCostText(event, "activeTextColor", true, true)
    if (battlePriceText.len() > 0 && reasonData.activeJoinButton)
      startText += ::format(" (%s)", battlePriceText)

    ::set_double_text_to_button(scene, "btn_join_event", startText)
    local reasonTextObj = showSceneBtn("cant_join_reason", reasonData.reasonText.len() > 0)
    reasonTextObj.setValue(reasonData.reasonText)

    showSceneBtn("btn_create_room", ::events.canCreateCustomRoom(event))

    local isHeader = isEventsListInFocus && curChapterId != "" && curRoomId == ""
    local collapsedButtonObj = showSceneBtn("btn_collapsed_chapter", isHeader)
    if (isHeader)
    {
      local isCollapsedChapter = ::isInArray(curChapterId, collapsedChapterNamesArray)
      startText = ::loc(isCollapsedChapter ? "mainmenu/btnExpand" : "mainmenu/btnCollapse")
      collapsedButtonObj.setValue(startText)
    }
  }

  function getCurFilter()
  {
    return { clusters = clustersModule.getCurrentClusters(), hasFullRooms = true }
  }

  function checkRoomsOrder()
  {
    fillRoomsList(true)
  }

  function fillRoomsList(isUpdateOnlyWhenFlagsChanged = false)
  {
    local roomsList = roomsListData.getList(getCurFilter())
    local isFlagsUpdated = updateRoomsFlags(roomsList)
    if (isUpdateOnlyWhenFlagsChanged && !isFlagsUpdated)
      return

    generateChapters(roomsList)
    updateListInfo(roomsList.len())
    restoreFocus()
  }

  function getMGameModeFlags(mGameMode, room, isMultiSlot)
  {
    local res = eRoomFlags.NONE
    if (!::events.getAvailableTeams(mGameMode).len())
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

    return res
  }

  function updateRoomsFlags(roomsList)
  {
    local hasChanges = false
    local isMultiSlot = ::events.isEventMultiSlotEnabled(event)
    local needCheckAvailable = ::events.checkPlayersCrafts(event)
    local teamSize = ::events.getMaxTeamSize(event)
    foreach(room in roomsList)
    {
      local wasFlags = ::getTblValue(EROOM_FLAGS_KEY_NAME, room, eRoomFlags.NONE)
      local flags = eRoomFlags.NONE
      local mGameMode = ::events.getMGameMode(event, room)

      local countTbl = ::SessionLobby.getMembersCountByTeams(room)
      if (countTbl.total < 2 * teamSize)
      {
        flags = flags | eRoomFlags.HAS_PLACES
        local availTeams = ::events.getAvailableTeams(mGameMode)
        if (availTeams.len() > 1 || (availTeams.len() && countTbl[availTeams[0]] < teamSize))
          flags = flags | eRoomFlags.HAS_PLACES_IN_MY_TEAM
      }

      local reqUnits = ::SessionLobby.getRequiredCrafts(Team.A, room)
      if (reqUnits)
        foreach(rule in reqUnits)
        {
          local tier = ::events.getTierNumByRule(rule)
          if (tier > 0)
          {
            flags = flags | (eRoomFlags.ROOM_TIER >> (::min(tier, 5) - 1))
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

  function getRoomNameView(room)
  {
    local isLocked = false
    local flags = room[EROOM_FLAGS_KEY_NAME]
    local mustHaveMask = eRoomFlags.HAS_COUNTRY
                       | eRoomFlags.HAS_AVAILABLE_UNITS | eRoomFlags.HAS_REQUIRED_UNIT
                       | eRoomFlags.HAS_PLACES | eRoomFlags.HAS_PLACES_IN_MY_TEAM
                       | eRoomFlags.IS_ALLOWED_BY_BALANCE
    if ((flags & mustHaveMask) != mustHaveMask)
      isLocked = true

    local text = ::SessionLobby.getMissionNameLoc(room)
    local reqUnits = ::SessionLobby.getRequiredCrafts(Team.A, room)
    if (reqUnits)
    {
      local color = ""
      if (!isLocked && !(room[EROOM_FLAGS_KEY_NAME] & eRoomFlags.HAS_UNIT_MATCH_RULES))
        color = "@warningTextColor"

      local rankText = ::events.getTierTextByRules(reqUnits)
      local ruleTexts = ::u.map(reqUnits, getRuleText)
      local rulesText = ::colorize(color, ::g_string.implode(ruleTexts, ::loc("ui/comma")))

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
    local needWaitIcon = !visibleRoomsAmount && roomsListData.isInUpdate
    scene.findObject("items_list_wait_icon").show(needWaitIcon)

    local infoText = ""
    if (!visibleRoomsAmount && !needWaitIcon)
      infoText = ::loc(roomsListData.getList().len() ? "multiplayer/no_rooms_by_clusters" : "multiplayer/no_rooms")

    scene.findObject("items_list_msg").setValue(infoText)
    roomsListObj.enable(visibleRoomsAmount && !needWaitIcon)
  }

  function getCurrentEdiff()
  {
    local ediff = ::events.getEDiffByEvent(event)
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
      local roomMGM = ::SessionLobby.getMGameMode(room, false)
      local foundChapter = ::u.search(chaptersTree, function(chapter) {return chapter.chapterGameMode == roomMGM})
      if (foundChapter == null)
      {
        chaptersTree.append({
          name = roomMGM? roomMGM.gameModeId.tostring() : "",
          chapterGameMode = roomMGM,
          [EROOM_FLAGS_KEY_NAME] = room[EROOM_FLAGS_KEY_NAME],
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

    local selectedIndex = 1///select first room by default
    local view = { items = [] }

    foreach (idx, chapter in chaptersTree)
    {
      local haveRooms = chapter.rooms.len() > 0
      if (!haveRooms)
        continue

      if (chapter.name == curChapterId)
        selectedIndex = view.items.len()

      local listRow = {
        id = chapter.name
        isCollapsable = true
      }
      local mGameMode = chapter.chapterGameMode
      if (::events.isCustomGameMode(mGameMode))
        listRow.itemText <- ::colorize("activeTextColor", ::loc("events/playersRooms"))
      else
        foreach(side in ::events.getSidesList(mGameMode))
          listRow[::g_team.getTeamByCode(side).name + "Countries"] <-
          {
            country = getFlagsArrayByCountriesArray(
                        ::events.getCountries(::events.getTeamData(mGameMode, side)))
          }
      view.items.append(listRow)

      foreach (roomIdx, room in chapter.rooms)
      {
        local roomId = room.roomId
        if (roomId == curRoomId || roomId == roomIdToSelect)
        {
          selectedIndex = view.items.len()
          if (roomId == roomIdToSelect)
            curRoomId = roomIdToSelect
        }

        local nameView = getRoomNameView(room)

        view.items.append({
          id = chapter.name + ROOM_ID_SPLIT + roomId
          isBattle = ::SessionLobby.isSessionStartedInRoom(room)
          itemText = nameView.text
          isLocked = nameView.isLocked
        })
      }
    }

    if (::u.isEqual(viewRoomList, view))
      return updateWindow()

    viewRoomList = view
    local data = ::handyman.renderCached("gui/events/eventRoomsList", view)
    guiScene.replaceContentFromText(roomsListObj, data, data.len(), this)

    if (roomsList.len())
    {
      roomsListObj.setValue(selectedIndex)
      if (roomIdToSelect == curRoomId)
        roomIdToSelect = null
    }
    else
    {
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

    local id = obj.id
    if (id.len() <= 4 || id.slice(0, 4) != "btn_")
      return

    local listItemCount = roomsListObj.childrenCount()
    for (local i = 0; i < listItemCount; i++)
    {
      local listItemId = roomsListObj.getChild(i).id
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
      local obj = roomsListObj.getChild(i)
      local chapterName = getChapterNameByObjId(obj.id)

      local isCollapsedChapter = ::isInArray(chapterName, collapsedChapterNamesArray)
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
    local index = ::find_in_array(collapsedChapterNamesArray, chapterObj.id)
    local isCollapse = index < 0
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

    local chapterId = itemName && getChapterNameByObjId(itemName)
    local newValue = -1

    guiScene.setUpdatesEnabled(false, false)
    for (local i = 0; i < roomsListObj.childrenCount(); i++)
    {
      local obj = roomsListObj.getChild(i)
      if (obj.id == itemName) //is chapter block, can collapse
      {
        updateCollapseChapterStatus(obj)
        newValue = i
        continue
      }

      local iChapter = getChapterNameByObjId(obj.id)
      if (iChapter != chapterId)
        continue

      local show = !::isInArray(iChapter, collapsedChapterNamesArray)
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
    local result = ROOM_REGEXP.replace("", id)
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
    if (!antiCheat.showMsgboxIfEacInactive(event))
      return

    local diffCode = ::events.getEventDiffCode(event)
    local unitTypeMask = ::events.getEventUnitTypesMask(event)
    local checkTutorUnitType = (stdMath.number_of_set_bits(unitTypeMask)==1) ? stdMath.number_of_set_bits(unitTypeMask - 1) : null
    if(checkDiffTutorial(diffCode, checkTutorUnitType))
      return

    ::events.openCreateRoomWnd(event)
  }

  function onSlotbarPrevAir() { slotbarWeak?.onSlotbarPrevAir?() }
  function onSlotbarNextAir() { slotbarWeak?.onSlotbarNextAir?() }

  function goBackShortcut() { goBack() }
  function onRoomsList()    { goBack() }

  function onLeaveEvent() {}
  function onStart() {}
  function onDownloadPack() {}
  function onQueueOptions() {}
}
