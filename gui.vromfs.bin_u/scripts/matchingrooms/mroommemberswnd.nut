//-file:plus-string
from "%scripts/dagui_library.nut" import *


let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let SecondsUpdater = require("%sqDagui/timer/secondsUpdater.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let time = require("%scripts/time.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")

gui_handlers.MRoomMembersWnd <- class extends gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneBlkName = null
  sceneTplName = "%gui/mpLobby/mRoomMembersWnd.tpl"

  room = null

  teams = null
  playersListWidgetWeak = null

  static function open(room) {
    if (room)
      handlersManager.loadHandler(gui_handlers.MRoomMembersWnd, { room = room })
  }

  function getSceneTplView() {
    let view = {
      maxRows = this.getMaxTeamSize()
    }

    let mgm = ::SessionLobby.getMGameMode(this.room)
    if (mgm)
      view.headerData <- {
        difficultyImage = ::events.getDifficultyImg(mgm.name)
        difficultyTooltip = ::events.getDifficultyTooltip(mgm.name)
        headerText = ::events.getEventNameText(mgm) + " " + ::events.getRespawnsText(mgm)
      }

    if (showConsoleButtons.value)
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

  function initScreen() {
    this.setFullRoomInfo()
    this.teams = ::g_team.getTeams()

    this.playersListWidgetWeak = gui_handlers.MRoomPlayersListWidget.create({
      scene = this.scene.findObject("players_list")
      room = this.room
      teams = this.teams
      onPlayerDblClickCb = Callback(this.openUserCard, this)
      onPlayerRClickCb = Callback(this.onUserRClick, this)
    })
    if (this.playersListWidgetWeak)
      this.playersListWidgetWeak = this.playersListWidgetWeak.weakref()
    this.registerSubHandler(this.playersListWidgetWeak)

    this.scene.findObject("update_timer").setUserData(this)
    this.updateTeamsHeader()
    this.initRoomTimer()
  }

  function updateTeamsHeader() {
    let headerNest = this.scene.findObject("teams_header")

    let countTbl = ::SessionLobby.getMembersCountByTeams(this.room)
    let countTblReady = ::SessionLobby.getMembersCountByTeams(this.room, true)
    foreach (team in this.teams) {
      let teamObj = headerNest.findObject("num_team" + team.id)
      if (!checkObj(teamObj))
        continue

      local locId = "multiplayer/teamPlayers"
      let locParams = {
        players = countTblReady[team.code]
        maxPlayers = this.getMaxTeamSize()
        unready = countTbl[team.code] - countTblReady[team.code]
      }
      if (locParams.unready)
        locId = "multiplayer/teamPlayers/hasUnready"
      let text = loc(locId, locParams)
      teamObj.setValue(text)
    }

    ::update_team_css_label(headerNest)
  }

  function getMaxTeamSize() {
    let mgm = ::SessionLobby.getMGameMode(this.room)
    return mgm ? ::events.getMaxTeamSize(mgm) : ::SessionLobby.getMaxMembersCount(this.room) / 2
  }

  function initRoomTimer() {
    let timerObj = this.scene.findObject("event_time")
    SecondsUpdater(timerObj, Callback(function(obj, _params) {
      local text = ""
      let startTime = ::SessionLobby.getRoomSessionStartTime(this.room)
      if (startTime > 0) {
        let secToStart = startTime - ::get_matching_server_time()
        if (secToStart <= 0)
          text = loc("multiplayer/battleInProgressTime", { time = time.secondsToString(-secToStart, true) })
        else
          text = loc("multiplayer/battleStartsIn", { time = time.secondsToString(secToStart, true) })
      }
      obj.setValue(text)
    }, this))
  }

  function setFullRoomInfo() {
    let roomInfo = ::g_mroom_info.get(this.room.roomId)
    if (roomInfo.isRoomDestroyed)
      return this.goBack()

    let fullRoom = roomInfo.getFullRoomData()
    if (fullRoom)
      this.room = fullRoom
  }

  function onEventMRoomInfoUpdated(p) {
    if (p.roomId == this.room.roomId) {
      this.setFullRoomInfo()
      this.updateTeamsHeader()
    }
  }

  function openUserCard(player) {
    if (player && !player.isBot)
      ::gui_modal_userCard({ name = player.name, uid = player.userId.tostring() })
  }

  function onUserRClick(player) {
    ::session_player_rmenu(this, player)
  }

  function onUserActions(_obj) {
    if (!this.playersListWidgetWeak)
      return

    let player = this.playersListWidgetWeak.getSelectedPlayer()
    let pos = this.playersListWidgetWeak.getSelectedRowPos()
    ::session_player_rmenu(this, player, null, pos)
  }

  function onUpdate(_obj, _dt) {
    ::g_mroom_info.get(this.room.roomId).checkRefresh()
  }
}
