import "%scripts/penitentiary/antiCheat.nut" as antiCheat
import "%scripts/matchingRooms/fillSessionInfo.nut" as fillSessionInfo
from "%scripts/chat/chatStorage.nut" import getRoomById
from "%scripts/events/eventsManager.nut" import events
from "%scripts/teams.nut" import g_team
from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/matchingRooms/mRoomPlayersListWidget.nut" import MRoomPlayersListWidget
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%scripts/user/playerContextMenu.nut" import showSessionPlayerRClickMenu
from "%scripts/chat/chatStates.nut" import isChatEnabled
from "%scripts/viewUtils/objectTextUpdate.nut" import setDoubleTextToButton
from "%scripts/penitentiary/soundMods.nut" import showMsgboxIfSoundModsNotAllowed
from "%scripts/viewUtils/interfaceCustomization.nut" import getToBattleLocId
from "%scripts/viewUtils/hangarDof.nut" import needUseHangarDof
from "%scripts/options/consoleMode.nut" import showConsoleButtons
from "%scripts/matchingRooms/sessionLobbyState.nut" import isInSessionRoom, isInSessionLobbyEventRoom, isMeSessionLobbyRoomOwner, isRoomInSession, getSessionLobbyTeam, getSessionLobbyIsSpectator
  , getSessionLobbyIsReady, getIsInLobbySession, getIsSpectatorSelectLocked, hasSessionInLobby, canJoinSession, isUserCanChangeReadyInLobby, canChangeSessionLobbySettings
  , canStartLobbySession, getSessionLobbyCurRoomEdiff, getSessionLobbyMaxRespawns, getSessionLobbyPublicParam, getSessionInfo, getSessionLobbyGameMode, getSessionLobbyChatRoomPassword
  , getSessionLobbyMaxMembersCount, getSessionLobbyRoomId
from "%scripts/missions/startMissionsList.nut" import guiStartMislist
from "%scripts/gameModes/gameModeManagerState.nut" import getCurrentGameModeEdiff
from "%scripts/user/antiAddictSystem.nut" import checkShowMultiplayerAasWarningMsg
from "%scripts/user/userCard/userCardView.nut" import gui_modal_userCard
from "%scripts/matchingRooms/sessionLobbyInfo.nut" import getRoomEvent, getSessionLobbyLockedCountryData, getRoomMGameMode, getRoomMaxDisbalance, canChangeTeamInLobby, canBeSpectator
  , getLobbyRandomTeam, getRoomActiveTimers, getMembersCountByTeams, isUnitAllowedForRoom, canSetReadyInLobby
from "%scripts/matchingRooms/sessionLobbyMembersInfo.nut" import getRoomMembersReadyStatus
from "%scripts/statistics/mpStatisticsUtil.nut" import updateTeamCssLabel
from "%scripts/matchingRooms/sessionLobbyManager.nut" import setMyTeamInRoom, setSessionLobbyReady, switchMyTeamInRoom, switchSpectator, leaveSessionRoom, tryJoinSession, startSession
from "%scripts/squads/squadUtils.nut" import checkSquadInRoomAndReady, isAllSquadInRoom, hasSquadNonAcceptedInvites
from "%scripts/options/options.nut" import getOptionsMode
from "%scripts/slotbar/slotbarOverride.nut" import isSlotbarOverrided
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "guiOptions" import setGuiOptionsMode
from "mission" import set_game_mode, get_game_mode
from "%scripts/dagui_library.nut" import *
from "%globalScripts/gameModeNativeConsts.nut" import *
from "%scripts/teamsConsts.nut" import Team
from "%scripts/unit/brokenAirsInfo.nut" import getBrokenAirsInfo
from "%scripts/instantAction.nut" import checkBrokenAirsAndDo
from "%scripts/user/playerCountry.nut" import profileCountrySq
from "%appGlobals/missions/respawnCountModes.nut" import isRespawnAllowed
from "%scripts/missions/missionsUtils.nut" import isSquadGamemode

let { g_chat_room_type } = require("%scripts/chat/chatRoomType.nut")

function getLobbyChatRoomId() {
  return g_chat_room_type.MP_LOBBY.getRoomId(getSessionLobbyRoomId())
}

function hasRespawnsInMission() {
  return isRespawnAllowed(getSessionLobbyMaxRespawns())
}


register_gui_handler("MPLobby", class (BaseGuiHandlerWT) {
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

  hasRepairInfoChecked = false

  function initScreen() {
    if (!isInSessionRoom.get())
      return

    this.curGMmode = getSessionLobbyGameMode()
    setGuiOptionsMode(getOptionsMode(this.curGMmode))

    this.scene.findObject("mplobby_update").setUserData(this)

    this.initTeams()

    this.playersListWidgetWeak = MRoomPlayersListWidget.create({
      scene = this.scene.findObject("players_tables_place")
      teams = this.tableTeams
      hasPlayerTooltip = true
      onPlayerSelectCb = Callback(this.onPlayerSelect, this)
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
    this.createSlotbar({
      getLockedCountryData  = getSessionLobbyLockedCountryData
      needPresetsPanel = !isSlotbarOverrided()
    })
    this.setSceneTitle(loc("multiplayer/lobby"))
    this.updateWindow()
    this.updateRoomInSession()

    this.initChat()
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
      setGuiOptionsMode(getOptionsMode(this.curGMmode))
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

  function onEventCountryChanged(_p) {
    this.hasRepairInfoChecked = false
  }

  function onEventLobbyMemberInfoChanged(_p) {
    this.updateWindow()
  }

  function onEventSquadDataUpdated(_p) {
    this.updateSessionStatus()
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

  function onPlayerSelect(player) {
    this.viewPlayer = player
    showObjById("btn_usercard", player != null && !showConsoleButtons.get(), this.scene)
    this.updateOptionsButton()
  }

  updateOptionsButton = @() showObjById("btn_user_options",
    showConsoleButtons.get() && this.viewPlayer != null && this.isPlayersListHovered, this.scene)

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
    if (needSessionStatus) {
      let isSquadInLobby = !isSquadGamemode(getSessionLobbyGameMode()) || isAllSquadInRoom()
      sessionStatusObj.setValue(isSquadInLobby
        ? getRoomMembersReadyStatus().statusText
        : loc("squad/member_not_in_room"))
    }

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
    let chatRoom = getRoomById(getLobbyChatRoomId())
    return chatRoom != null ? chatRoom.getLogForBanhammer() : null
  }

  function openUserCard(player) {
    if (player && !player.isBot)
      gui_modal_userCard({ name = player.name, uid = player.userId });
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

    let isGMAvailableForSquad = isSquadGamemode(getSessionLobbyGameMode())
    if (isGMAvailableForSquad && !checkSquadInRoomAndReady())
      return

    let status = getRoomMembersReadyStatus()
    let hasNonAcceptedInvites = isGMAvailableForSquad && hasSquadNonAcceptedInvites()
    if (status.readyToStart && !hasNonAcceptedInvites)
      return startSession()

    let msgLines = []
    if (!status.readyToStart)
      msgLines.append(status.statusText)
    if (hasNonAcceptedInvites)
      msgLines.append(loc("squad/has_non_accept_invites"))

    local msg = "\n".join(msgLines)
    local buttons = [["ok", function() {}]]
    local defButton = "ok"
    if (status.readyToStart || status.ableToStart) {
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

    
    
    
    if (this.hasRepairInfoChecked || getSessionLobbyIsSpectator() || !canSetReadyInLobby(true)) {
      this.onReadyImpl()
      return
    }

    let repairInfo = getBrokenAirsInfo([profileCountrySq.get()], hasRespawnsInMission(), isUnitAllowedForRoom)
    this.hasRepairInfoChecked = checkBrokenAirsAndDo(repairInfo, this, this.onReadyImpl, false)
  }

  function onCustomChatCancel() {
    this.onCancel()
  }

  function canPresetChange() {
    return true
  }

  function onPlayersListHover(_tblId, isHovered) {
    this.isPlayersListHovered = isHovered
    this.updateOptionsButton()
  }
})