let { sessionsListBlkPath } = require("%scripts/matchingRooms/getSessionsListBlkPath.nut")
let fillSessionInfo = require("%scripts/matchingRooms/fillSessionInfo.nut")
let { suggestAndAllowPsnPremiumFeatures } = require("%scripts/user/psnFeatures.nut")
let { isGameModeCoop } = require("%scripts/matchingRooms/matchingGameModesUtils.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { setGuiOptionsMode } = ::require_native("guiOptions")
let lobbyStates = require("%scripts/matchingRooms/lobbyStates.nut")
let { havePremium } = require("%scripts/user/premium.nut")
let { checkAndShowMultiplayerPrivilegeWarning,
  isMultiplayerPrivilegeAvailable } = require("%scripts/user/xboxFeatures.nut")

::match_search_gm <- -1

::back_sessions_func <- ::gui_start_mainmenu

::g_script_reloader.registerPersistentData("SessionsList", ::getroottable(), ["match_search_gm"])

::gui_start_session_list <- function gui_start_session_list(prev_scene_func=null)
{
  if (prev_scene_func)
    ::back_sessions_func = prev_scene_func

  ::handlersManager.loadHandler(::gui_handlers.SessionsList,
                  {
                    wndOptionsMode = ::get_options_mode(::get_game_mode())
                    backSceneFunc = ::back_sessions_func
                  })
}

::gui_start_missions <- function gui_start_missions() //!!FIX ME: is it really used in some cases?
{
  ::match_search_gm = -1
  gui_start_session_list(gui_start_mainmenu)
}

::gui_start_skirmish <- function gui_start_skirmish()
{
  prepare_start_skirmish()
  gui_start_session_list(gui_start_mainmenu)
}

::prepare_start_skirmish <- function prepare_start_skirmish()
{
  ::match_search_gm = ::GM_SKIRMISH
}

::build_check_table <- function build_check_table(session, gm=0)
{
  let ret = {}

  if (session)
    gm = session.gameModeInt

  if (gm == ::GM_BUILDER)
  {
    ret.silentFeature <- "ModeBuilder"
  }
  else if (gm == ::GM_DYNAMIC)
  {
    if (session)
    {
      ret.minRank <- ::dynamic_req_country_rank
      ret.rankCountry <- session.country
    }
    ret.silentFeature <- "ModeDynamic"
  }
  else if (gm == ::GM_SINGLE_MISSION)
  {
    if (session)
      ret.unlock <- session.chapter+"/"+session.map
    ret.silentFeature <- "ModeSingleMissions"
  }

  return ret
}

::gui_handlers.SessionsList <- class extends ::gui_handlers.GenericOptions
{
  sceneBlkName = sessionsListBlkPath.value
  sceneNavBlkName = "%gui/navSessionsList.blk"
  optionsContainer = "mp_coop_options"
  isCoop = true

  sessionsListObj = null
  //currently visible rooms list
  roomsListData = null
  roomsList = null
  curPageRoomsList = null
  curPage = 0
  roomsPerPage = 1

  curDifficulty = -1

  function initScreen()
  {
    base.initScreen()
    sessionsListObj = scene.findObject("sessions_table")

    roomsList = []
    curPageRoomsList = []
    roomsListData = ::MRoomsList.getMRoomsListByRequestParams(null) //skirmish when no params

    isCoop = isGameModeCoop(::match_search_gm)
    scene.findObject("sessions_update").setUserData(this)

    let head = scene.findObject("sessions_diff_header")
    if (::checkObj(head))
      head.setValue(isCoop? ::loc("multiplayer/difficultyShort") : ::loc("multiplayer/createModeShort"))

    updateRoomsHeader()
    initOptions()
    initRoomsPerPage()

    onSessionsUpdate(null, 0.0)
    updateRoomsList()
    updateButtons()
  }

  function initRoomsPerPage()
  {
    let listHeight = sessionsListObj.getSize()[1]
    let rowHeight = guiScene.calcString("@baseTrHeight", null)
    roomsPerPage = max((listHeight / rowHeight).tointeger(), 1)
  }

  function updateButtons()
  {
    local title = ""
    if (isCoop)
    {
      if(::has_feature("ModeDynamic"))
      {
        showBtn("btn_dynamic", true)
        let dynBtn = guiScene["btn_dynamic"]
        if(::checkObj(dynBtn))
        {
          dynBtn.inactiveColor = havePremium.value? "no" : "yes"
          dynBtn.tooltip = havePremium.value? "" : ::loc("mainmenu/onlyWithPremium")
        }
      }

      showBtn("btn_coop", true)
      showBtn("btn_builder", ::has_feature("ModeBuilder"))
      title = ::loc("mainmenu/btnMissions")
    }
    else
    {
      showBtn("btn_skirmish", true)
      title = ::loc("mainmenu/btnCustomMatch")
    }

    setSceneTitle(title)
  }

  function initOptions()
  {
    setGuiOptionsMode(::OPTIONS_MODE_SEARCH)
    local options = null
    if (isCoop)
      options = [
        [::USEROPT_SEARCH_GAMEMODE, "spinner"],
        [::USEROPT_SEARCH_DIFFICULTY, "spinner"],
      ]
    else
    if (::match_search_gm == ::GM_SKIRMISH)
      options = [
        [::USEROPT_SEARCH_DIFFICULTY, "spinner"],
      ]

    if (!options) return

    let container = create_options_container(optionsContainer, options, false, 0.5, false)
    let optObj = scene.findObject("session-options")
    if (::check_obj(optObj))
      guiScene.replaceContentFromText(optObj, container.tbl, container.tbl.len(), this)

    optionsContainers.append(container.descr)
  }

  function onGamemodeChange(obj)
  {
    if (!obj) return
    let value = obj.getValue()
    let option = get_option(::USEROPT_SEARCH_GAMEMODE)
    if (!(value in option.values))
      return

    ::match_search_gm = option.values[value]
  }

  function onDifficultyChange(obj)
  {
    if (!::check_obj(obj))
      return

    let value = obj.getValue()
    let option = get_option(::USEROPT_SEARCH_DIFFICULTY)
    if (!(value in option.values))
      return

    let newDiff = option.idxValues[value]
    if (curDifficulty == newDiff)
      return

    curDifficulty = newDiff
    updateRoomsList()
  }

  function onSkirmish(obj) { ::checkAndCreateGamemodeWnd(this, ::GM_SKIRMISH) }

  function onSessionsUpdate(obj = null, dt = 0.0)
  {
    if (::handlersManager.isAnyModalHandlerActive()
        || ::is_multiplayer()
        || ::SessionLobby.status != lobbyStates.NOT_IN_ROOM)
      return

    roomsListData.requestList(getCurFilter())
  }

  function onEventSearchedRoomsChanged(p)
  {
    updateRoomsList()
  }

  function onEventRoomsSearchStarted(p)
  {
    updateSearchMsg()
  }

  function updateSearchMsg()
  {
    let infoText = guiScene["info-text"]
    if (::checkObj(infoText))
    {
      let show = (type(roomsList) != "array") || (roomsList.len() == 0)
      if (show)
        infoText.setValue(roomsListData.isNewest() ? ::loc("wait/sessionNone") : ::loc("wait/sessionSearch"))
      infoText.show(show)
    }
  }

  function getCurFilter()
  {
    return { diff = curDifficulty }
  }

  function sortRoomsList()
  {
    //need to add ability to sort rooms by categories chosen by user
    //but temporary better to sort work at least as it was before from matching
    foreach(room in roomsList)
    {
      let size = ::SessionLobby.getRoomSize(room)
      room._players <- ::SessionLobby.getRoomMembersCnt(room)
      room._full <- room._players >= size
    }
    roomsList.sort(function(a, b) {
      if (a._full != b._full)
        return a._full ? 1 : -1
      if (a._players != b._players)
        return (a._players > b._players) ? -1 : 1
      return 0
    })
  }

  _columnsList = null
  function getColumnsList()
  {
    if (_columnsList)
      return _columnsList
    if (isCoop)
      _columnsList = ["hasPassword", "mission", "name", "numPlayers", "gm"/*, "difficultyStr"*/]
    else
      _columnsList = ["hasPassword", "mission", "name", "numPlayers"/*, "difficultyStr"*/]
    return _columnsList
  }

  _roomsMarkUpData = null
  function getRoomsListMarkUpData()
  {
    if (_roomsMarkUpData)
      return _roomsMarkUpData

    guiScene.applyPendingChanges(false)
    _roomsMarkUpData = {
      tr_size = "pw, @baseTrHeight"
      is_header = true
      columns = {
        hasPassword   = { width = "1@baseTrHeight + 1@tablePad" }
        mission       = { halign = "left", relWidth = 50 }
        name          = { width = "@nameWidth" }
        numPlayers    = { relWidth = 10 }
        gm            = { relWidth = 20 }
        //difficultyStr = { width = "0.15pw" }
      }
    }

    let columnsOrder = getColumnsList()
    let deletedArr = []
    foreach (id, data in _roomsMarkUpData.columns)
      if (!::isInArray(id, columnsOrder))
        deletedArr.append(id)

    foreach (id in deletedArr)
      delete _roomsMarkUpData.columns[id]

    if (::checkObj(sessionsListObj))
      ::count_width_for_mptable(sessionsListObj, _roomsMarkUpData.columns)

    return _roomsMarkUpData
  }

  function updateRoomsHeader()
  {
    let headerObj = scene.findObject("sessions-header")
    if (!::checkObj(headerObj))
      return

    let header = [{
      country = ""
      mission = "#options/mp_mission"
      numPlayers = "#multiplayer/numPlayers"
      gm = "#multiplayer/gamemode"
      difficultyStr = "#multiplayer/difficultyShort"
      name = "#multiplayer/game_host"
    }]
    let headerData = ::build_mp_table(header, getRoomsListMarkUpData(), getColumnsList())
    guiScene.replaceContentFromText(headerObj, headerData, headerData.len(), this)
  }

  function updateRoomsList()
  {
    roomsListData.requestList(getCurFilter())
    roomsList = roomsListData.getList()
    sortRoomsList()
    updateSearchMsg()

    updateRoomsPage()
  }

  function updateRoomsPage()
  {
    if (!::checkObj(sessionsListObj))
      return

    let selectedRoom = getCurRoom()
    local selectedRow = -1
    curPageRoomsList.clear()

    let maxPage = max((roomsList.len() - 1) / roomsPerPage, 0)
    curPage = clamp(curPage, 0, maxPage)

    let start = curPage * roomsPerPage
    let end = min(start + roomsPerPage, roomsList.len())
    for(local i = start; i < end; i++)
    {
      let room = roomsList[i]
      curPageRoomsList.append(room)
      if (selectedRow < 0 && ::u.isEqual(room, selectedRoom))
         selectedRow = curPageRoomsList.len() - 1
    }
    if (selectedRow < 0 && curPageRoomsList.len())
      selectedRow = clamp(sessionsListObj.getValue(), 0, curPageRoomsList.len() - 1)

    let roomsInfoTbl = ::SessionLobby.getRoomsInfoTbl(curPageRoomsList)
    let data = ::build_mp_table(roomsInfoTbl, getRoomsListMarkUpData(), getColumnsList(), roomsInfoTbl.len())
    sessionsListObj.deleteChildren()
    guiScene.appendWithBlk(sessionsListObj, data, this)

    sessionsListObj.setValue(curPageRoomsList.len() > 0 ? selectedRow : -1)
    updateCurRoomInfo()
    updatePaginator(maxPage)
  }

  function updatePaginator(maxPage)
  {
    let pagObj = scene.findObject("paginator_place")
    if (maxPage > 0)
      ::generatePaginator(pagObj, this, curPage, maxPage, null, true)
    else
      ::hidePaginator(pagObj)
  }

  function goToPage(obj)
  {
    curPage = obj.to_page.tointeger()
    updateRoomsPage()
  }

  function getCurRoom()
  {
    if (!::checkObj(sessionsListObj))
      return null

    let curRow = sessionsListObj.getValue()
    if (curRow in curPageRoomsList)
      return curPageRoomsList[curRow]
    return null
  }

  function updateCurRoomInfo()
  {
    let room = getCurRoom()
    fillSessionInfo(scene, room?.public)
    ::update_vehicle_info_button(scene, room)

    let btnObj = scene.findObject("btn_select")
    if (::checkObj(btnObj))
      btnObj.inactiveColor = room ? "no" : "yes"
  }

  function onSessionSelect()
  {
    updateCurRoomInfo()
  }

  doSelectSessions = @() ::move_mouse_on_child_by_value(sessionsListObj)

  function onGamercard(obj)
  {
  }

  function onStart(obj)
  {
    if (!suggestAndAllowPsnPremiumFeatures())
      return

    if (!isMultiplayerPrivilegeAvailable.value) {
      checkAndShowMultiplayerPrivilegeWarning()
      return
    }

    let room = getCurRoom()
    if (!room)
      return this.msgBox("no_room_selected", ::loc("ui/nothing_selected"), [["ok"]], "ok")

    if (::g_squad_manager.getSquadRoomId() != room.roomId
      && !::g_squad_utils.canJoinFlightMsgBox(
          {
            isLeaderCanJoin = ::can_play_gamemode_by_squad(::SessionLobby.getGameMode(room)),
            showOfflineSquadMembersPopup = true
          }
        )
      )
      return

    checkedNewFlight((@(room) function() {
      ::SessionLobby.joinFoundRoom(room)
    })(room))
  }

  function onVehiclesInfo(obj)
  {
    ::gui_start_modal_wnd(::gui_handlers.VehiclesWindow, {
      teamDataByTeamName = ::getTblValue("public", getCurRoom())
    })
  }
}

::fillCountriesList <- function fillCountriesList(obj, countries, handler = null)
{
  if (!::check_obj(obj))
    return

  if (obj.childrenCount() != shopCountriesList.len())
  {
    let view = {
      countries = ::u.map(shopCountriesList, function (countryName) {
        return {
          countryName = countryName
          countryIcon = ::get_country_icon(countryName)
        }
      })
    }
    let markup = ::handyman.renderCached("%gui/countriesList", view)
    obj.getScene().replaceContentFromText(obj, markup, markup.len(), handler)
  }

  foreach(idx, country in shopCountriesList)
    if (idx < obj.childrenCount())
      obj.getChild(idx).show(::isInArray(country, countries))
}
