local SecondsUpdater = require("sqDagui/timer/secondsUpdater.nut")
local time = require("scripts/time.nut")


class ::gui_handlers.MRoomMembersWnd extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = null
  sceneTplName = "gui/mpLobby/mRoomMembersWnd"

  room = null

  teams = null
  playersListWidgetWeak = null

  static function open(room)
  {
    if (room)
      ::handlersManager.loadHandler(::gui_handlers.MRoomMembersWnd, { room = room })
  }

  function getSceneTplView()
  {
    local view = {
      maxRows = getMaxTeamSize()
    }

    local mgm = ::SessionLobby.getMGameMode(room)
    if (mgm)
      view.headerData <- {
        difficultyImage = ::events.getDifficultyImg(mgm.name)
        difficultyTooltip = ::events.getDifficultyTooltip(mgm.name)
        headerText = ::events.getEventNameText(mgm) + " " + ::events.getRespawnsText(mgm)
      }

    if (::show_console_buttons)
      view.navBar <- {
        left = [
          {
            id = "btn_user_actions"
            text = "#mainmenu/btnUserAction"
            shortcut = "X"
            funcName = "onUserActions"
            button = true
          }
        ]
      }
    return view
  }

  function initScreen()
  {
    setFullRoomInfo()
    teams = ::g_team.getTeams()

    playersListWidgetWeak = ::gui_handlers.MRoomPlayersListWidget.create({
      scene = scene.findObject("players_list")
      room = room
      teams = teams
      onPlayerDblClickCb = ::Callback(openUserCard, this)
      onPlayerRClickCb = ::Callback(onUserRClick, this)
    })
    if (playersListWidgetWeak)
      playersListWidgetWeak = playersListWidgetWeak.weakref()
    registerSubHandler(playersListWidgetWeak)

    local focusObj = playersListWidgetWeak.getFocusObj()
    focusObj.select()

    scene.findObject("update_timer").setUserData(this)
    updateTeamsHeader()
    initRoomTimer()
  }

  function updateTeamsHeader()
  {
    local headerNest = scene.findObject("teams_header")

    local countTbl = ::SessionLobby.getMembersCountByTeams(room)
    local countTblReady = ::SessionLobby.getMembersCountByTeams(room, true)
    foreach(team in teams)
    {
      local teamObj = headerNest.findObject("num_team" + team.id)
      if (!::check_obj(teamObj))
        continue

      local locId = "multiplayer/teamPlayers"
      local locParams = {
        players = countTblReady[team.code]
        maxPlayers = getMaxTeamSize()
        unready = countTbl[team.code] - countTblReady[team.code]
      }
      if (locParams.unready)
        locId = "multiplayer/teamPlayers/hasUnready"
      local text = ::loc(locId, locParams)
      teamObj.setValue(text)
    }

    ::update_team_css_label(headerNest)
  }

  function getMaxTeamSize()
  {
    local mgm = ::SessionLobby.getMGameMode(room)
    return mgm ? ::events.getMaxTeamSize(mgm) : ::SessionLobby.getMaxMembersCount(room) / 2
  }

  function initRoomTimer()
  {
    local timerObj = scene.findObject("event_time")
    SecondsUpdater(timerObj, ::Callback(function(obj, params)
    {
      local text = ""
      local startTime = ::SessionLobby.getRoomSessionStartTime(room)
      if (startTime > 0)
      {
        local secToStart = startTime - ::get_matching_server_time()
        if (secToStart <= 0)
          text = ::loc("multiplayer/battleInProgressTime", { time = time.secondsToString(-secToStart, true) })
        else
          text = ::loc("multiplayer/battleStartsIn", { time = time.secondsToString(secToStart, true) })
      }
      obj.setValue(text)
    }, this))
  }

  function setFullRoomInfo()
  {
    local roomInfo = ::g_mroom_info.get(room.roomId)
    if (roomInfo.isRoomDestroyed)
      return goBack()

    local fullRoom = roomInfo.getFullRoomData()
    if (fullRoom)
      room = fullRoom
  }

  function onEventMRoomInfoUpdated(p)
  {
    if (p.roomId == room.roomId)
    {
      setFullRoomInfo()
      updateTeamsHeader()
    }
  }

  function openUserCard(player)
  {
    if (player && !player.isBot)
      ::gui_modal_userCard({ name = player.name, uid = player.userId.tostring() })
  }

  function onUserRClick(player)
  {
    ::session_player_rmenu(this, player)
  }

  function onUserActions(obj)
  {
    if (!playersListWidgetWeak)
      return

    local player = playersListWidgetWeak.getSelectedPlayer()
    local pos = playersListWidgetWeak.getSelectedRowPos()
    ::session_player_rmenu(this, player, null, pos)
  }

  function onUpdate(obj, dt)
  {
    ::g_mroom_info.get(room.roomId).checkRefresh()
  }
}
