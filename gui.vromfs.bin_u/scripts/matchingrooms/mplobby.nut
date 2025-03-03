from "%scripts/dagui_library.nut" import *
from "%scripts/teamsConsts.nut" import Team

let { g_chat } = require("%scripts/chat/chat.nut")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let { g_team } = require("%scripts/teams.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { showSessionPlayerRClickMenu } = require("%scripts/user/playerContextMenu.nut")
let antiCheat = require("%scripts/penitentiary/antiCheat.nut")
let { isChatEnabled } = require("%scripts/chat/chatStates.nut")
let fillSessionInfo = require("%scripts/matchingRooms/fillSessionInfo.nut")
let { setDoubleTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { getUnitItemStatusText } = require("%scripts/unit/unitInfoTexts.nut")
let { showMsgboxIfSoundModsNotAllowed } = require("%scripts/penitentiary/soundMods.nut")
let { getToBattleLocId } = require("%scripts/viewUtils/interfaceCustomization.nut")
let { needUseHangarDof } = require("%scripts/viewUtils/hangarDof.nut")
let { setGuiOptionsMode } = require("guiOptions")
let lobbyStates = require("%scripts/matchingRooms/lobbyStates.nut")
let { set_game_mode, get_game_mode, get_mp_local_team } = require("mission")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { isInSessionRoom, sessionLobbyStatus, isInSessionLobbyEventRoom, isMeSessionLobbyRoomOwner,
  isRoomInSession, getSessionLobbyTeam, getSessionLobbyIsSpectator, getSessionLobbyIsReady,
  getIsInLobbySession, getIsSpectatorSelectLocked, hasSessionInLobby, canJoinSession, isUserCanChangeReadyInLobby,
  canChangeSessionLobbySettings, canStartLobbySession, getSessionLobbyCurRoomEdiff, getSessionLobbyMissionParam,
  getSessionLobbyPublicParam, getSessionInfo, getSessionLobbyGameMode, getSessionLobbyChatRoomPassword,
  getSessionLobbyMaxMembersCount, getSessionLobbyRoomId
} = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { bit_unit_status } = require("%scripts/unit/unitInfo.nut")
let { buildUnitSlot, fillUnitSlotTimers } = require("%scripts/slotbar/slotbarView.nut")
let { guiStartMislist } = require("%scripts/missions/startMissionsList.nut")
let { getCurrentGameModeEdiff } = require("%scripts/gameModes/gameModeManagerState.nut")
let { g_player_state } = require("%scripts/contacts/playerStateTypes.nut")
let { checkShowMultiplayerAasWarningMsg } = require("%scripts/user/antiAddictSystem.nut")
let { fill_gamer_card } = require("%scripts/gamercard.nut")
let { gui_modal_userCard } = require("%scripts/user/userCard/userCardView.nut")
let { getRoomEvent, getRoomSpecialRules, getSessionLobbyLockedCountryData, getRoomMGameMode,
  getRoomMaxDisbalance, canChangeTeamInLobby, canBeSpectator, getLobbyRandomTeam, getRoomActiveTimers,
  getMembersCountByTeams
} = require("%scripts/matchingRooms/sessionLobbyInfo.nut")
let { getRoomMembersReadyStatus } = require("%scripts/matchingRooms/sessionLobbyMembersInfo.nut")
let { g_chat_room_type } = require("%scripts/chat/chatRoomType.nut")
let { updateTeamCssLabel } = require("%scripts/statistics/mpStatisticsUtil.nut")
let { updateVehicleInfoButton } = require("%scripts/vehiclesWindow.nut")
let { setMyTeamInRoom, setSessionLobbyReady, switchMyTeamInRoom, switchSpectator, leaveSessionRoom,
  tryJoinSession, startSession
} = require("%scripts/matchingRooms/sessionLobbyManager.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")

function getLobbyChatRoomId() {
  return g_chat_room_type.MP_LOBBY.getRoomId(getSessionLobbyRoomId())
}


gui_handlers.MPLobby <- class (gui_handlers.BaseGuiHandlerWT) {
  sceneBlkName = "%gui/mpLobby/mpLobby.blk"
  shouldBlurSceneBgFn = needUseHangarDof
  handlerLocId = "multiplayer/lobby"

  tblData = null
  tblMarkupData = null

  haveUnreadyButton = false
  waitBox = null
  optionsBox = null
  curGMmode = -1
  slotbarActions = ["autorefill", "aircraft", "crew", "sec_weapons", "weapons", "repair"]

  playersListWidgetWeak = null
  tableTeams = null
  isInfoByTeams = false
  isTimerVisible = false

  viewPlayer = null
  isPlayersListHovered = true

  function initScreen() {
    if (!isInSessionRoom.get())
      return

    this.curGMmode = getSessionLobbyGameMode()
    setGuiOptionsMode(::get_options_mode(this.curGMmode))

    this.scene.findObject("mplobby_update").setUserData(this)

    this.initTeams()

    this.playersListWidgetWeak = gui_handlers.MRoomPlayersListWidget.create({
      scene = this.scene.findObject("players_tables_place")
      teams = this.tableTeams
      onPlayerSelectCb = Callback(this.refreshPlayerInfo, this)
      onPlayerDblClickCb = Callback(this.openUserCard, this)
      onPlayerRClickCb = Callback(this.onUserRClick, this)
      onTablesHoverChange = Callback(this.onPlayersListHover, this)
    })
    if (this.playersListWidgetWeak)
      this.playersListWidgetWeak = this.playersListWidgetWeak.weakref()
    this.registerSubHandler(this.playersListWidgetWeak)
    this.playersListWidgetWeak?.moveMouse()

    if (!getSessionLobbyPublicParam("symmetricTeams", true))
      setMyTeamInRoom(getLobbyRandomTeam(), true)

    this.updateSessionInfo()
    this.createSlotbar({ getLockedCountryData  = getSessionLobbyLockedCountryData })
    this.setSceneTitle(loc("multiplayer/lobby"))
    this.updateWindow()
    this.updateRoomInSession()

    this.initChat()
    let sessionInfo = getSessionInfo()
    updateVehicleInfoButton(this.scene, sessionInfo)
  }

  function initTeams() {
    this.tableTeams = [g_team.ANY]
    if (isInSessionLobbyEventRoom.get()) {
      this.tableTeams = [g_team.A, g_team.B]
      this.isInfoByTeams = true
    }
  }

  function initChat() {
    if (!isChatEnabled())
      return

    let chatObj = this.scene.findObject("lobby_chat_place")
    if (checkObj(chatObj))
      broadcastEvent("ChatJoinCustomObjRoom", {
        sceneObj = chatObj
        roomId = getLobbyChatRoomId()
        password = getSessionLobbyChatRoomPassword()
        ownerHandler = this
      })
  }

  function updateSessionInfo() {
    let mpMode = getSessionLobbyGameMode()
    if (this.curGMmode != mpMode) {
      this.curGMmode = mpMode
      set_game_mode(this.curGMmode)
      setGuiOptionsMode(::get_options_mode(this.curGMmode))
    }

    fillSessionInfo(this.scene, getSessionInfo())
  }

  function updateTableHeader() {
    let commonHeader = showObjById("common_list_header", !this.isInfoByTeams, this.scene)
    let byTeamsHeader = showObjById("list_by_teams_header", this.isInfoByTeams, this.scene)
    let teamsNest = this.isInfoByTeams ? byTeamsHeader : commonHeader.findObject("num_teams")

    let maxMembers = getSessionLobbyMaxMembersCount()
    let countTbl = getMembersCountByTeams()
    let countTblReady = getMembersCountByTeams(null, true)
    if (!this.isInfoByTeams) {
      let totalNumPlayersTxt = "".concat(loc("multiplayer/playerList"),
        loc("ui/parentheses/space", { text = $"{countTbl.total}/{maxMembers}" }))
      commonHeader.findObject("num_players").setValue(totalNumPlayersTxt)
    }

    let event = getRoomEvent()
    foreach (team in this.tableTeams) {
      let teamObj = teamsNest.findObject($"num_team{team.id}")
      if (!checkObj(teamObj))
        continue

      local text = ""
      if (this.isInfoByTeams && event) {
        local locId = "multiplayer/teamPlayers"
        let locParams = {
          players = countTblReady[team.code]
          maxPlayers = events.getMaxTeamSize(event)
          unready = countTbl[team.code] - countTblReady[team.code]
        }
        if (locParams.unready)
          locId = "multiplayer/teamPlayers/hasUnready"
        text = loc(locId, locParams)
      }
      teamObj.setValue(text)
    }

    updateTeamCssLabel(teamsNest)
  }

  function updateRoomInSession() {
    if (checkObj(this.scene))
      this.scene.findObject("battle_in_progress").wink = isRoomInSession.get() ? "yes" : "no"
    this.updateTimerInfo()
  }

  function updateWindow() {
    this.updateTableHeader()
    this.updateSessionStatus()
    this.updateButtons()
  }

  function onEventLobbyMembersChanged(_p) {
    this.updateWindow()
  }

  function onEventLobbyMemberInfoChanged(_p) {
    this.updateWindow()
  }

  function onEventLobbySettingsChange(_p) {
    this.updateSessionInfo()
    this.reinitSlotbar()
    this.updateWindow()
    this.updateTimerInfo()
  }

  function onEventLobbyRoomInSession(_p) {
    this.updateRoomInSession()
    this.updateButtons()
  }

  function getSelectedPlayer() {
    return this.playersListWidgetWeak && this.playersListWidgetWeak.getSelectedPlayer()
  }

  function refreshPlayerInfo(player) {
    this.viewPlayer = player
    this.updatePlayerInfo(player)
    showObjById("btn_usercard", player != null && !showConsoleButtons.value && hasFeature("UserCards"), this.scene)
    this.updateOptionsButton()
  }

  updateOptionsButton = @() showObjById("btn_user_options",
    showConsoleButtons.value && this.viewPlayer != null && this.isPlayersListHovered, this.scene)

  function updatePlayerInfo(player) {
    let mainObj = this.scene.findObject("player_info")
    if (!checkObj(mainObj) || !player)
      return

    let titleObj = mainObj.findObject("player_title")
    if (checkObj(titleObj))
      titleObj.setValue((player.title != "") ? loc("ui/colon").concat(loc("title/title"), loc($"title/{player.title}")) : "")

    let spectatorObj = mainObj.findObject("player_spectator")
    if (checkObj(spectatorObj)) {
      let desc = g_player_state.getStateByPlayerInfo(player).getText(player)
      spectatorObj.setValue((desc != "") ? loc("ui/colon").concat(loc("multiplayer/state"), desc) : "")
    }

    let myTeam = (sessionLobbyStatus.get() == lobbyStates.IN_LOBBY) ? getSessionLobbyTeam() : get_mp_local_team()
    mainObj.playerTeam = myTeam == Team.A ? "a" : (myTeam == Team.B ? "b" : "")

    let teamObj = mainObj.findObject("player_team")
    if (checkObj(teamObj)) {
      local teamTxt = ""
      local teamStyle = ""
      let team = player ? player.team : Team.Any
      if (team == Team.A) {
        teamStyle = "a"
        teamTxt = loc("multiplayer/teamA")
      }
      else if (team == Team.B) {
        teamStyle = "b"
        teamTxt = loc("multiplayer/teamB")
      }

      teamObj.team = teamStyle
      let teamIcoObj = teamObj.findObject("player_team_ico")
      teamIcoObj.show(teamTxt != "")
      teamIcoObj.tooltip = loc("ui/colon").concat(loc("multiplayer/team"), teamTxt)
    }
    let playerIcon = (!player || player.isBot) ? "cardicon_bot" : player.pilotIcon
    fill_gamer_card({
                      name = player.name
                      clanTag = player.clanTag
                      country = player?.country ?? ""
                      icon = playerIcon
                      frame = player.frame
                    },
                    "player_", mainObj)

    let airObj = mainObj.findObject("curAircraft")
    if (!checkObj(airObj))
      return

    let showAirItem = getSessionLobbyMissionParam("maxRespawns", -1) == 1 && player.country && player.selAirs.len() > 0
    airObj.show(showAirItem)

    if (showAirItem) {
      let airName = getTblValue(player.country, player.selAirs, "")
      let air = getAircraftByName(airName)
      if (!air) {
        airObj.show(false)
        return
      }

      let existingAirObj = airObj.findObject("curAircraft_place")
      if (checkObj(existingAirObj))
        this.guiScene.destroyElement(existingAirObj)

      let params = {
        getEdiffFunc = Callback(this.getCurrentEdiff, this)
        status = getUnitItemStatusText(bit_unit_status.owned)
      }
      local data = buildUnitSlot(airName, air, params)
      data = "rankUpList { id:t='curAircraft_place'; holdTooltipChildren:t='yes'; {0} }".subst(data)
      this.guiScene.appendWithBlk(airObj, data, this)
      fillUnitSlotTimers(airObj.findObject(airName), air)
    }
  }

  function getMyTeamDisbalanceMsg(isFullText = false) {
    let countTbl = getMembersCountByTeams(null, true)
    let maxDisbalance = getRoomMaxDisbalance()
    let myTeam = getSessionLobbyTeam()
    if (myTeam != Team.A && myTeam != Team.B)
      return ""

    let otherTeam = g_team.getTeamByCode(myTeam).opponentTeamCode
    if (countTbl[myTeam] - maxDisbalance < countTbl[otherTeam])
      return ""

    let params = {
      chosenTeam = colorize("teamBlueColor", g_team.getTeamByCode(myTeam).getShortName())
      otherTeam =  colorize("teamRedColor", g_team.getTeamByCode(otherTeam).getShortName())
      chosenTeamCount = countTbl[myTeam]
      otherTeamCount =  countTbl[otherTeam]
      reqOtherteamCount = countTbl[myTeam] - maxDisbalance + 1
    }
    let locKey = $"multiplayer/enemyTeamTooLowMembers{isFullText ? "" : "/short"}"
    return loc(locKey, params)
  }

  function getReadyData() {
    let res = {
      readyBtnText = ""
      readyBtnHint = ""
      isVisualDisabled = false
    }

    if (!isUserCanChangeReadyInLobby() && !hasSessionInLobby())
      return res

    let isReady = hasSessionInLobby() ? getIsInLobbySession() : getSessionLobbyIsReady()
    if (canStartLobbySession() && isReady)
      res.readyBtnText = loc("multiplayer/btnStart")
    else if (isRoomInSession.get()) {
      res.readyBtnText = loc(getToBattleLocId())
      res.isVisualDisabled = !canJoinSession()
    }
    else if (!isReady)
      res.readyBtnText = loc("mainmenu/btnReady")

    if (!isReady && isInSessionLobbyEventRoom.get() && isRoomInSession.get()) {
      res.readyBtnHint = this.getMyTeamDisbalanceMsg()
      res.isVisualDisabled = res.readyBtnHint.len() > 0
    }
    return res
  }

  function updateButtons() {
    let readyData = this.getReadyData()
    let readyBtn = showObjById("btn_ready", readyData.readyBtnText.len(), this.scene)
    setDoubleTextToButton(this.scene, "btn_ready", readyData.readyBtnText)
    readyBtn.inactiveColor = readyData.isVisualDisabled ? "yes" : "no"
    this.scene.findObject("cant_ready_reason").setValue(readyData.readyBtnHint)

    let spectatorBtnObj = this.scene.findObject("btn_spectator")
    if (checkObj(spectatorBtnObj)) {
      let isSpectator = getSessionLobbyIsSpectator()
      let buttonText = "".concat(loc("mainmenu/btnReferee"),
        isSpectator ? "".concat(loc("ui/colon"), loc("options/on")) : "")
      spectatorBtnObj.setValue(buttonText)
      spectatorBtnObj.active = isSpectator ? "yes" : "no"
    }

    let isReady = getSessionLobbyIsReady()
    showObjById("btn_not_ready", isUserCanChangeReadyInLobby() && isReady, this.scene)
    showObjById("btn_ses_settings", canChangeSessionLobbySettings(), this.scene)
    showObjById("btn_team", !isReady && canChangeTeamInLobby(), this.scene)
    showObjById("btn_spectator", !isReady && canBeSpectator()
      && !getIsSpectatorSelectLocked(), this.scene)
  }

  function getCurrentEdiff() {
    let ediff = getSessionLobbyCurRoomEdiff()
    return ediff != -1 ? ediff : getCurrentGameModeEdiff()
  }

  function onEventLobbyMyInfoChanged(params) {
    this.updateButtons()
    if ("team" in params)
      this.guiScene.performDelayed(this, function () {
        this.reinitSlotbar()
      })
  }

  function onEventLobbyReadyChanged(_p) {
    this.updateButtons()
  }

  function updateSessionStatus() {
    let needSessionStatus = !this.isInfoByTeams && !isRoomInSession.get()
    let sessionStatusObj = showObjById("session_status", needSessionStatus, this.scene)
    if (needSessionStatus)
      sessionStatusObj.setValue(getRoomMembersReadyStatus().statusText)

    let mGameMode = getRoomMGameMode()
    let needTeamStatus = this.isInfoByTeams && !isRoomInSession.get() && !!mGameMode
    local countTbl = null
    if (needTeamStatus)
      countTbl = getMembersCountByTeams()
    foreach (_idx, team in this.tableTeams) {
      let teamObj = showObjById($"team_status_{team.id}", needTeamStatus, this.scene)
      if (!teamObj || !needTeamStatus)
        continue

      local status = ""
      let minSize = events.getMinTeamSize(mGameMode)
      let teamSize = countTbl[team.code]
      if (teamSize < minSize)
        status = loc("multiplayer/playersTeamLessThanMin", { minSize = minSize })
      else {
        let maxDisbalance = getRoomMaxDisbalance()
        let otherTeamSize = countTbl[team.opponentTeamCode]
        if (teamSize - maxDisbalance > max(otherTeamSize, minSize))
          status = loc("multiplayer/playersTeamDisbalance", { maxDisbalance = maxDisbalance })
      }
      teamObj.setValue(status)
    }
  }

  function updateTimerInfo() {
    let timers = getRoomActiveTimers()
    let isVisibleNow = timers.len() > 0 && !isRoomInSession.get()
    if (!isVisibleNow && !this.isTimerVisible)
      return

    this.isTimerVisible = isVisibleNow
    let timerObj = showObjById("battle_start_countdown", this.isTimerVisible, this.scene)
    if (timerObj && this.isTimerVisible)
      timerObj.setValue(timers[0].text)
  }

  function onUpdate(_obj, _dt) {
    this.updateTimerInfo()
  }

  function getChatLog() {
    let chatRoom = g_chat.getRoomById(getLobbyChatRoomId())
    return chatRoom != null ? chatRoom.getLogForBanhammer() : null
  }

  function openUserCard(player) {
    if (player && !player.isBot)
      gui_modal_userCard({ name = player.name, uid = player.userId });
  }

  function onUserCard(_obj) {
    this.openUserCard(this.getSelectedPlayer())
  }

  function onUserRClick(player) {
    showSessionPlayerRClickMenu(this, player, this.getChatLog())
  }

  function onUserOption(_obj) {
    let pos = this.playersListWidgetWeak && this.playersListWidgetWeak.getSelectedRowPos()
    showSessionPlayerRClickMenu(this, this.getSelectedPlayer(), this.getChatLog(), pos)
  }

  function onSessionSettings() {
    if (!isMeSessionLobbyRoomOwner.get())
      return

    if (getSessionLobbyIsReady()) {
      this.msgBox("cannot_options_on_ready", loc("multiplayer/cannotOptionsOnReady"),
        [["ok", function() {}]], "ok", { cancel_fn = function() {} })
      return
    }

    if (isRoomInSession.get()) {
      this.msgBox("cannot_options_on_ready", loc("multiplayer/cannotOptionsWhileInBattle"),
        [["ok", function() {}]], "ok", { cancel_fn = function() {} })
      return
    }

    //local gm = getSessionLobbyGameMode()
    //if (gm == GM_SKIRMISH)
    guiStartMislist(true, get_game_mode())
  }

  function onSpectator(_obj) {
    switchSpectator()
  }

  function onTeam(_obj) {
    let isSymmetric = getSessionLobbyPublicParam("symmetricTeams", true)
    switchMyTeamInRoom(!isSymmetric)
  }

  function onPlayers(_obj) {
  }

  function doQuit() {
    leaveSessionRoom()
  }

  function onEventLobbyStatusChange(_params) {
    if (!isInSessionRoom.get())
      this.goBack()
    else
      this.updateButtons()
  }

  onEventToBattleLocChanged = @(_params) this.updateButtons()

  function onNotReady() {
    if (getSessionLobbyIsReady())
      setSessionLobbyReady(false)
  }

  function onCancel() {
    this.msgBox("ask_leave_lobby", loc("flightmenu/questionQuitGame"),
    [
      ["yes", this.doQuit],
      ["no", function() { }]
    ], "no", { cancel_fn = function() {} })
  }

  function onReadyImpl() {
    if (tryJoinSession())
      return

    if (!isMeSessionLobbyRoomOwner.get() || !getSessionLobbyIsReady())
      return setSessionLobbyReady(true)

    let status = getRoomMembersReadyStatus()
    if (status.readyToStart)
      return startSession()

    local msg = status.statusText
    local buttons = [["ok", function() {}]]
    local defButton = "ok"
    if (status.ableToStart) {
      buttons = [["#multiplayer/btnStart", function() { startSession() }], ["cancel", function() {}]]
      defButton = "cancel"
      msg = "\n".concat(msg, loc("ask/startGameAnyway"))
    }

    this.msgBox("ask_start_session", msg, buttons, defButton, { cancel_fn = function() {} })
  }

  function onReady() {
    let event = getRoomEvent()
    if (event != null) {
      if (!antiCheat.showMsgboxIfEacInactive(event) || !showMsgboxIfSoundModsNotAllowed(event))
        return

      checkShowMultiplayerAasWarningMsg(Callback(this.onReadyImpl, this))
      return
    }
    this.onReadyImpl()
  }

  function onCustomChatCancel() {
    this.onCancel()
  }

  function canPresetChange() {
    return true
  }

  function onVehiclesInfo(_obj) {
    loadHandler(gui_handlers.VehiclesWindow, {
      teamDataByTeamName = getSessionInfo()
      roomSpecialRules = getRoomSpecialRules()
    })
  }

  function onPlayersListHover(_tblId, isHovered) {
    this.isPlayersListHovered = isHovered
    this.updateOptionsButton()
  }

  function onEventUserInfoManagerDataUpdated(param) {
    if (this.viewPlayer == null || this.viewPlayer.userId not in param.usersInfo)
      return
    let userInfo = param.usersInfo[this.viewPlayer.userId]
    this.viewPlayer.pilotIcon = userInfo.pilotIcon
    this.viewPlayer.frame = userInfo.frame
    this.updatePlayerInfo(this.viewPlayer)
  }
}