import "%scripts/matchingRooms/fillSessionInfo.nut" as fillSessionInfo
import "%scripts/matchingRooms/lobbyStates.nut" as lobbyStates
from "%scripts/squads/squadManager.nut" import g_squad_manager
from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/genericOptions.nut" import GenericOptions
from "%scripts/sqDagui/daguiUtil.nut" import move_mouse_on_child_by_value
from "%scripts/user/psnFeatures.nut" import suggestAndAllowPsnPremiumFeatures
from "%scripts/matchingRooms/matchingGameModesUtils.nut" import isGameModeCoop
from "%scripts/user/premium.nut" import havePremium
from "%scripts/user/xboxFeatures.nut" import checkAndShowMultiplayerPrivilegeWarning, isMultiplayerPrivilegeAvailable
from "%scripts/user/balanceFeatures.nut" import isShowGoldBalanceWarning
from "%scripts/options/optionsExtNames.nut" import OPTIONS_MODE_SEARCH, USEROPT_SEARCH_GAMEMODE, USEROPT_SEARCH_DIFFICULTY
from "%scripts/matchingRooms/sessionLobbyState.nut" import sessionLobbyStatus, getRoomMembersCnt, getRoomSize, getSessionLobbyGameMode
from "%scripts/options/optionsExt.nut" import create_options_container, get_option
from "%scripts/missions/startMissionsList.nut" import checkAndCreateGamemodeWnd
from "%scripts/missions/missionsStates.nut" import matchSearchGm
from "%scripts/matchingRooms/sessionLobbyInfo.nut" import getRoomsInfoTbl
from "%scripts/matchingRooms/sessionLobbyActions.nut" import joinSessionLobbyFoundRoom
from "%scripts/statistics/mpStatisticsUtil.nut" import countWidthForMpTable
from "%scripts/statistics/buildMpTables.nut" import buildMpTable
from "%scripts/missions/missionsUtils.nut" import canPlayGamemodeBySquad
from "%scripts/squads/squadUtils.nut" import canJoinFlightMsgBox
from "guiOptions" import setGuiOptionsMode
from "%scripts/dagui_library.nut" import *
from "%globalScripts/gameModeNativeConsts.nut" import *
from "%scripts/utils_sa.nut" import is_multiplayer
from "%globalScripts/loc_helpers.nut" import locByVendor
from "%sqStdLibs/helpers/u.nut" import isEqual
from "%scripts/contacts/contactsInfo.nut" import colorizeWhitePsnIcon
from "types" import Array

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let MRoomsList = require("%scripts/matchingRooms/mRoomsList.nut")

function fillRoomRow(rowObj, roomInfo) {
  rowObj.findObject("td_hasPassword").getChild(0)["background-image"] = roomInfo.hasPassword ? "#ui/gameuiskin#password.svg" : ""
  rowObj.findObject("txt_mission").setValue(roomInfo.mission.tostring())
  rowObj.findObject("name-text").setValue(colorizeWhitePsnIcon(roomInfo?.name ?? ""))
  let { numPlayers, numPlayersTotal } = roomInfo
  let playersObj = rowObj.findObject("td_numPlayers").getChild(0)
  playersObj.setValue($"{numPlayers}/{numPlayersTotal}")
  playersObj.overlayTextColor = numPlayers >= numPlayersTotal ? "warning" : ""
}

register_gui_handler("SessionsList", class (GenericOptions) {
  sceneBlkName = "%gui/sessionsList.blk"
  sceneNavBlkName = "%gui/navSessionsList.blk"
  optionsContainer = "mp_coop_options"
  isCoop = true

  sessionsListObj = null
  
  roomsListData = null
  roomsList = null
  shownRoomsInfo = null

  curDifficulty = -1

  function initScreen() {
    base.initScreen()
    this.scene.findObject("skirmish_no_progress").setValue(locByVendor("mainmenu/skirmish/noProgress"))
    this.sessionsListObj = this.scene.findObject("sessions_table")

    this.roomsList = []
    this.roomsListData = MRoomsList.getMRoomsListByRequestParams(null) 

    this.isCoop = isGameModeCoop(matchSearchGm.get())
    this.scene.findObject("sessions_update").setUserData(this)

    this.updateRoomsHeader()
    this.initOptions()

    this.onSessionsUpdate(null, 0.0)
    this.updateRoomsList()
    this.updateButtons()
  }

  function updateButtons() {
    local title = ""
    if (this.isCoop) {
      showObjById("btn_dynamic", true)
      let dynBtn = this.guiScene["btn_dynamic"]
      if (checkObj(dynBtn)) {
        dynBtn.inactiveColor = havePremium.get() ? "no" : "yes"
        dynBtn.tooltip = havePremium.get() ? "" : loc("mainmenu/onlyWithPremium")
      }

      showObjById("btn_coop", true)
      showObjById("btn_builder", true)
      title = loc("mainmenu/btnMissions")
    }
    else {
      showObjById("btn_skirmish", true)
      title = loc("mainmenu/btnCustomMatch")
    }

    this.setSceneTitle(title)
  }

  function initOptions() {
    setGuiOptionsMode(OPTIONS_MODE_SEARCH)
    local options = null
    if (this.isCoop)
      options = [
        [USEROPT_SEARCH_GAMEMODE, "spinner"],
        [USEROPT_SEARCH_DIFFICULTY, "spinner"],
      ]
    else if (matchSearchGm.get() == GM_SKIRMISH)
      options = [
        [USEROPT_SEARCH_DIFFICULTY, "spinner"],
      ]

    if (!options)
      return

    let container = create_options_container(this.optionsContainer, options, false, 0.5, false)
    let optObj = this.scene.findObject("session-options")
    if (checkObj(optObj))
      this.guiScene.replaceContentFromText(optObj, container.tbl, container.tbl.len(), this)

    this.optionsContainers.append(container.descr)
  }

  function onGamemodeChange(obj) {
    if (!obj)
      return
    let value = obj.getValue()
    let option = get_option(USEROPT_SEARCH_GAMEMODE)
    if (!(value in option.values))
      return

    matchSearchGm.set(option.values[value])
  }

  function onDifficultyChange(obj) {
    if (!checkObj(obj))
      return

    let value = obj.getValue()
    let option = get_option(USEROPT_SEARCH_DIFFICULTY)
    if (!(value in option.values))
      return

    let newDiff = option.idxValues[value]
    if (this.curDifficulty == newDiff)
      return

    this.curDifficulty = newDiff
    this.updateRoomsList()
  }

  function onSkirmish(_obj) { checkAndCreateGamemodeWnd(this, GM_SKIRMISH) }

  function onSessionsUpdate(_obj = null, _dt = 0.0) {
    if (handlersManager.isAnyModalHandlerActive()
        || is_multiplayer()
        || sessionLobbyStatus.get() != lobbyStates.NOT_IN_ROOM)
      return

    this.roomsListData.requestList(this.getCurFilter())
  }

  function onEventSearchedRoomsChanged(_p) {
    this.updateRoomsList()
  }

  function onEventRoomsSearchStarted(_p) {
    this.updateSearchMsg()
  }

  function updateSearchMsg() {
    let infoText = this.guiScene["info-text"]
    if (checkObj(infoText)) {
      let show = (!(this.roomsList instanceof Array)) || (this.roomsList.len() == 0)
      if (show)
        infoText.setValue(this.roomsListData.isNewest() ? loc("wait/sessionNone") : loc("wait/sessionSearch"))
      infoText.show(show)
    }
  }

  function getCurFilter() {
    return { diff = this.curDifficulty }
  }

  function sortRoomsList() {
    
    
    foreach (room in this.roomsList) {
      let size = getRoomSize(room)
      room._players <- getRoomMembersCnt(room)
      room._full <- room._players >= size
    }
    this.roomsList.sort(function(a, b) {
      if (a._full != b._full)
        return a._full ? 1 : -1
      if (a._players != b._players)
        return (a._players > b._players) ? -1 : 1
      return 0
    })
  }

  _columnsList = null
  function getColumnsList() {
    if (this._columnsList)
      return this._columnsList
    if (this.isCoop)
      this._columnsList = ["hasPassword", "mission", "name", "numPlayers", "gm"  ]
    else
      this._columnsList = ["hasPassword", "mission", "name", "numPlayers"  ]
    return this._columnsList
  }

  _roomsMarkUpData = null
  function getRoomsListMarkUpData() {
    if (this._roomsMarkUpData)
      return this._roomsMarkUpData

    this.guiScene.applyPendingChanges(false)
    this._roomsMarkUpData = {
      tr_size = "pw, @baseTrHeight"
      is_header = true
      columns = {
        hasPassword   = { width = "1@baseTrHeight + 1@tablePad" }
        mission       = { halign = "left", relWidth = 50 }
        name          = { width = "@nameWidth" }
        numPlayers    = { relWidth = 10 }
        gm            = { relWidth = 20 }
        
      }
    }

    let columnsOrder = this.getColumnsList()
    let deletedArr = []
    foreach (id, _data in this._roomsMarkUpData.columns)
      if (!isInArray(id, columnsOrder))
        deletedArr.append(id)

    foreach (id in deletedArr)
      this._roomsMarkUpData.columns.$rawdelete(id)

    if (checkObj(this.sessionsListObj))
      countWidthForMpTable(this.sessionsListObj, this._roomsMarkUpData.columns)

    return this._roomsMarkUpData
  }

  function updateRoomsHeader() {
    let headerObj = this.scene.findObject("sessions-header")
    if (!checkObj(headerObj))
      return

    let header = [{
      country = ""
      mission = "#options/mp_mission"
      numPlayers = "#multiplayer/numPlayers"
      gm = "#multiplayer/gamemode"
      difficultyStr = "#multiplayer/difficultyShort"
      name = "#multiplayer/game_host"
    }]
    let headerData = buildMpTable(header, this.getRoomsListMarkUpData(), this.getColumnsList())
    this.guiScene.replaceContentFromText(headerObj, headerData, headerData.len(), this)
  }

  function updateRoomsList() {
    this.roomsListData.requestList(this.getCurFilter())
    let selectedRoomId = this.getCurRoom()?.roomId
    this.roomsList = clone this.roomsListData.getList()
    this.sortRoomsList()
    this.updateSearchMsg()

    this.updateRoomsTable(selectedRoomId)
  }

  function updateRoomsTable(selectedRoomId) {
    if (!checkObj(this.sessionsListObj))
      return

    local selectedRow = this.roomsList.findindex(@(room) room.roomId == selectedRoomId) ?? -1
    if (selectedRow < 0 && this.roomsList.len() > 0)
      selectedRow = clamp(this.sessionsListObj.getValue(), 0, this.roomsList.len() - 1)

    let scrollY = this.sessionsListObj.getScrollY()
    this.guiScene.setUpdatesEnabled(false, false)
    this.updateRoomRows(getRoomsInfoTbl(this.roomsList))
    this.guiScene.setUpdatesEnabled(true, true)

    if (this.sessionsListObj.getValue() != selectedRow)
      this.sessionsListObj.setValue(selectedRow)
    this.sessionsListObj.scrollToY(scrollY)
    this.updateCurRoomInfo()
  }

  function updateRoomRows(roomsInfoTbl) {
    let listObj = this.sessionsListObj
    let shownCount = listObj.childrenCount()
    let count = roomsInfoTbl.len()
    for (local i = shownCount - 1; i >= count; i--)
      this.guiScene.destroyElement(listObj.getChild(i))
    if (count > shownCount) {
      let data = buildMpTable([], this.getRoomsListMarkUpData(), this.getColumnsList(), count - shownCount)
      this.guiScene.appendWithBlk(listObj, data, this)
    }

    for (local i = 0; i < count; i++) {
      let rowObj = listObj.getChild(i)
      let isNewRow = i >= shownCount
      if (isNewRow) {
        rowObj.even = i % 2 == 0 ? "yes" : "no"
        rowObj.inactive = "no"
      }
      if (isNewRow || !isEqual(this.shownRoomsInfo?[i], roomsInfoTbl[i]))
        fillRoomRow(rowObj, roomsInfoTbl[i])
    }
    this.shownRoomsInfo = roomsInfoTbl
  }

  function getCurRoom() {
    if (!checkObj(this.sessionsListObj))
      return null

    let curRow = this.sessionsListObj.getValue()
    if (curRow in this.roomsList)
      return this.roomsList[curRow]
    return null
  }

  function updateCurRoomInfo() {
    let room = this.getCurRoom()
    fillSessionInfo(this.scene, room?.public)

    let btnObj = this.scene.findObject("btn_select")
    if (checkObj(btnObj))
      btnObj.inactiveColor = room ? "no" : "yes"
  }

  function onSessionSelect() {
    this.updateCurRoomInfo()
  }

  doSelectSessions = @() move_mouse_on_child_by_value(this.sessionsListObj)

  function onGamercard(_obj) {
  }

  function onStart(_obj) {
    if (!suggestAndAllowPsnPremiumFeatures())
      return

    if (!isMultiplayerPrivilegeAvailable.get()) {
      checkAndShowMultiplayerPrivilegeWarning()
      return
    }

    if (isShowGoldBalanceWarning())
      return

    let room = this.getCurRoom()
    if (!room)
      return this.msgBox("no_room_selected", loc("ui/nothing_selected"), [["ok"]], "ok")

    let roomId = to_integer_safe(room.roomId, -1, false)
    if (g_squad_manager.getSquadRoomId() != roomId
      && !canJoinFlightMsgBox(
          {
            isLeaderCanJoin = canPlayGamemodeBySquad(getSessionLobbyGameMode(room)),
            showOfflineSquadMembersPopup = true
          }
        )
      )
      return

    this.checkedNewFlight(@() joinSessionLobbyFoundRoom(room))
  }
})