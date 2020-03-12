local platformModule = require("scripts/clientState/platform.nut")
local avatars = ::require("scripts/user/avatars.nut")
local playerContextMenu = ::require("scripts/user/playerContextMenu.nut")
local antiCheat = require("scripts/penitentiary/antiCheat.nut")
local { isChatEnabled } = require("scripts/chat/chatStates.nut")

::mplobby_spawn_time <- 5.0 // this changes from native code when isMultiplayerDebug option enabled
::back_from_lobby <- ::gui_start_mainmenu

//::use_debug_fake_players <- false

::session_fill_info <- function session_fill_info(scene, sessionInfo)
{
  if (!::checkObj(scene))
    return
  if (!sessionInfo)
    return ::session_clear_info(scene)

  local textSample = "<color=@activeTextColor>%s</color>%s"
  local setTextToObj = function(obj, coloredText, value)
  {
    if (!::checkObj(obj))
      return

    if (::u.isBool(value))
      value = ::loc("options/" + (value ? "yes" : "no"))
    obj.setValue((!::u.isEmpty(value)) ? ::format(textSample, coloredText, value.tostring()) : "")
  }
  local setTextToObjByOption = function(objId, optionId, value)
  {
    local obj = scene.findObject(objId)
    if ( ! obj || ! ::checkObj(obj))
      return
    local option = ::get_option(optionId)
    local displayValue = option.getValueLocText(value)
    setTextToObj(obj, option.getTitle() + ::loc("ui/colon"), displayValue)
  }

  local gt = ::SessionLobby.getGameType(sessionInfo)
  local missionInfo = ("mission" in sessionInfo)? sessionInfo.mission : {}
  local isEventRoom = ::SessionLobby.isInRoom() && ::SessionLobby.isEventRoom

  local nameObj = scene.findObject("session_creator")
  local creatorName = platformModule.getPlayerName(sessionInfo?.creator ?? "")
  setTextToObj(nameObj, ::loc("multiplayer/game_host") + ::loc("ui/colon"), creatorName)

  local teams = ::SessionLobby.getTeamsCountries(sessionInfo)
  local isEqual = teams.len() == 1 || ::u.isEqual(teams[0], teams[1])
  local cObj1 = scene.findObject("countries1")
  local cObj2 = scene.findObject("countries2")
  if (::checkObj(cObj1))
  {
    cObj1.show(true)
    fillCountriesList(cObj1, teams[0])
    cObj2.show(!isEqual)
    if (!isEqual)
      fillCountriesList(cObj2, teams[1])
  }
  local vsObj = scene.findObject("vsText")
  if (::checkObj(vsObj))
    vsObj.show(!isEqual)

  local mapNameObj = scene.findObject("session_mapName")
  if (::SessionLobby.isUserMission(sessionInfo))
    setTextToObj(mapNameObj, ::loc("options/mp_user_mission") + ::loc("ui/colon"), ::getTblValue("userMissionName", sessionInfo))
  else if (::SessionLobby.isUrlMission(sessionInfo))
  {
    local url = ::getTblValue("missionURL", sessionInfo, "")
    local urlMission =  ::g_url_missions.findMissionByUrl(url)
    local missionName = urlMission ? urlMission.name : url
    setTextToObj(mapNameObj, ::loc("urlMissions/sessionInfoHeader") + ::loc("ui/colon"), missionName)
  } else
    setTextToObj(mapNameObj, ::loc("options/mp_mission") + ::loc("ui/colon"), get_combine_loc_name_mission(missionInfo))

  local pasObj = scene.findObject("session_hasPassword")
  setTextToObj(pasObj, ::loc("options/session_password") + ::loc("ui/colon"),
               isEventRoom ? null : ::getTblValue("hasPassword", sessionInfo, false))

  local tlObj = scene.findObject("session_teamLimit")
  local rangeData = ::events.getPlayersRangeTextData(::SessionLobby.getMGameMode(sessionInfo))
  setTextToObj(tlObj, rangeData.label,
               isEventRoom && rangeData.isValid ? rangeData.value : null)

  local craftsObj = scene.findObject("session_battleRating")
  local reqUnits = ::SessionLobby.getRequiredCrafts(Team.A, sessionInfo)
  setTextToObj(craftsObj, ::loc("events/required_crafts"), ::events.getRulesText(reqUnits))

  local envObj = scene.findObject("session_environment")
  local envTexts = []
  if ("weather" in missionInfo)
    envTexts.append(::loc("options/weather" + missionInfo.weather))
  if ("environment" in missionInfo)
    envTexts.append(::get_mission_time_text(missionInfo.environment))
  setTextToObj(envObj, ::loc("sm_conditions") + ::loc("ui/colon"), ::g_string.implode(envTexts, ", "))

  local difObj = scene.findObject("session_difficulty")
  local diff = ::getTblValue("difficulty", missionInfo)
  setTextToObj(difObj, ::loc("multiplayer/difficultyShort") + ::loc("ui/colon"), ::loc("options/" + diff))
  local diffTooltip = ""
  if (diff=="custom")
  {
    local custDiff = ::getTblValue("custDifficulty", missionInfo, null)
    if (custDiff)
      diffTooltip = ::get_custom_difficulty_tooltip_text(custDiff)
  }
  difObj.tooltip = diffTooltip


  local bObj = scene.findObject("session_laps")
  setTextToObj(bObj, ::loc("options/race_laps") + ::loc("ui/colon"),
               (gt & ::GT_RACE)? ::getTblValue("raceLaps", missionInfo) : null)
  bObj = scene.findObject("session_winners")
  setTextToObj(bObj, ::loc("options/race_winners") + ::loc("ui/colon"),
               (gt & ::GT_RACE)? ::getTblValue("raceWinners", missionInfo) : null)
  bObj = scene.findObject("session_can_shoot")
  setTextToObj(bObj, ::loc("options/race_can_shoot") + ::loc("ui/colon"),
               (gt & ::GT_RACE)? !::getTblValue("raceForceCannotShoot", missionInfo, false) : null)

  setTextToObjByOption("session_timeLimit", ::USEROPT_TIME_LIMIT, ::SessionLobby.getTimeLimit(sessionInfo))

  setTextToObjByOption("limited_fuel", ::USEROPT_LIMITED_FUEL, ::getTblValue("isLimitedFuel", missionInfo))
  setTextToObjByOption("limited_ammo", ::USEROPT_LIMITED_AMMO, ::getTblValue("isLimitedAmmo", missionInfo))

  setTextToObjByOption("session_respawn", ::USEROPT_VERSUS_RESPAWN, ::getTblValue("maxRespawns", missionInfo, -1))

  local tObj = scene.findObject("session_takeoff")
  setTextToObj(tObj, ::loc("options/optional_takeoff") + ::loc("ui/colon"),
               ::getTblValue("optionalTakeOff", missionInfo, false))

  setTextToObjByOption("session_allowbots", ::USEROPT_IS_BOTS_ALLOWED,
               (gt & ::GT_RACE)? null : ::getTblValue("isBotsAllowed", missionInfo))
  setTextToObjByOption("session_botsranks", ::USEROPT_BOTS_RANKS,
               (gt & ::GT_RACE)? null : ::getTblValue("ranks", missionInfo))

  bObj = scene.findObject("session_jip")
  setTextToObj(bObj, ::loc("options/allow_jip") + ::loc("ui/colon"),
               ::getTblValue("allowJIP", sessionInfo, true))

  setTextToObjByOption("session_cluster", ::USEROPT_CLUSTER, ::getTblValue("cluster", sessionInfo))

  setTextToObjByOption("disable_airfields", ::USEROPT_DISABLE_AIRFIELDS, ::getTblValue("disableAirfields", missionInfo))

  setTextToObjByOption("spawn_ai_tank_on_tank_maps", ::USEROPT_SPAWN_AI_TANK_ON_TANK_MAPS, ::getTblValue("spawnAiTankOnTankMaps", missionInfo))

  setTextToObjByOption("content_allowed_preset", ::USEROPT_CONTENT_ALLOWED_PRESET, missionInfo?.allowedTagsPreset)

  local slotOverrideText = ""
  if (::SessionLobby.isSlotbarOverrided(sessionInfo))
    slotOverrideText = ::colorize("userlogColoredText", ::loc("multiplayer/slotbarOverrided"))
  scene.findObject("slotbar_override").setValue(slotOverrideText)
}

::session_clear_info <- function session_clear_info(scene)
{
  foreach (name in ["session_creator", "session_mapName", "session_hasPassword",
                    "session_environment", "session_difficulty", "session_timeLimit",
                    "session_limits", "session_respawn", "session_takeoff",
                    "session_allowbots", "session_botsranks", "session_jip",
                    "limited_fuel", "limited_ammo", "session_teamLimit",
                    "session_battleRating", "session_cluster", "disable_airfields",
                    "session_laps", "session_winners", "session_can_shoot",
                    "spawn_ai_tank_on_tank_maps", "content_allowed_preset"])
  {
    local obj = scene.findObject(name)
    if (::checkObj(obj)) obj.setValue("")
  }
  foreach (name in ["countries1", "vsText", "countries2"])
  {
    local obj = scene.findObject(name)
    if (::checkObj(obj)) obj.show(false)
  }
}

::session_player_rmenu <- function session_player_rmenu(handler, player, chatLog = null, position = null, orientation = null)
{
  if (!player || player.isBot || !("userId" in player) || !::g_login.isLoggedIn())
    return

  playerContextMenu.showMenu(null, handler, {
    playerName = player.name
    uid = player.userId.tostring()
    clanTag = player.clanTag
    position = position
    orientation = orientation
    chatLog = chatLog
    isMPLobby = true
    canComplain = true
  })
}

::gui_start_mp_lobby <- function gui_start_mp_lobby()
{
  if (::SessionLobby.status != lobbyStates.IN_LOBBY)
  {
    ::back_from_lobby()
    return
  }

  if (::SessionLobby.getGameMode() == ::GM_SKIRMISH && !::g_missions_manager.isRemoteMission)
    ::back_from_lobby = ::gui_start_skirmish
  else
  {
    local lastEvent = ::SessionLobby.getRoomEvent()
    if (lastEvent && ::events.eventRequiresTicket(lastEvent) && ::events.getEventActiveTicket(lastEvent) == null)
    {
      ::back_from_lobby()
      return
    }
    ::back_from_lobby = ::gui_start_mainmenu
  }

  ::g_missions_manager.isRemoteMission = false
  ::handlersManager.loadHandler(::gui_handlers.MPLobby, { backSceneFunc = ::back_from_lobby })
}

class ::gui_handlers.MPLobby extends ::gui_handlers.BaseGuiHandlerWT
{
  sceneBlkName = "gui/mpLobby/mpLobby.blk"
  shouldBlurSceneBg = true

  tblData = null
  tblMarkupData = null

  haveUnreadyButton = false
  waitBox = null
  spawnTime = mplobby_spawn_time
  curStatus = -1
  optionsBox = null
  curGMmode = -1
  slotbarActions = ["autorefill", "aircraft", "crew", "weapons", "repair"]

  playersListWidgetWeak = null
  tableTeams = null
  isInfoByTeams = false
  isTimerVisible = false

  function initScreen()
  {
    if (!::SessionLobby.isInRoom())
      return

    curGMmode = ::SessionLobby.getGameMode()
    ::set_gui_options_mode(::get_options_mode(curGMmode))

    scene.findObject("mplobby_update").setUserData(this)

    initTeams()

    playersListWidgetWeak = ::gui_handlers.MRoomPlayersListWidget.create({
      scene = scene.findObject("players_tables_place")
      teams = tableTeams
      onPlayerSelectCb = ::Callback(refreshPlayerInfo, this)
      onPlayerDblClickCb = ::Callback(openUserCard, this)
      onPlayerRClickCb = ::Callback(onUserRClick, this)
      onWrapUpCb = ::Callback(onWrapUp, this)
      onWrapDownCb = ::Callback(onWrapDown, this)
    })
    if (playersListWidgetWeak)
      playersListWidgetWeak = playersListWidgetWeak.weakref()
    registerSubHandler(playersListWidgetWeak)

    if (!::SessionLobby.getPublicParam("symmetricTeams", true))
      ::SessionLobby.setTeam(::SessionLobby.getRandomTeam(), true)

    updateSessionInfo()
    createSlotbar()
    setSceneTitle(::loc("multiplayer/lobby"))
    updateWindow()
    updateRoomInSession()

    initChat()
    initFocusArray()
    local sessionInfo = ::SessionLobby.getSessionInfo()
    ::update_vehicle_info_button(scene, sessionInfo)

    checkNotInvitedPlayers()
  }

  function initTeams()
  {
    tableTeams = [::g_team.ANY]
    if (::SessionLobby.isEventRoom)
    {
      tableTeams = [::g_team.A, ::g_team.B]
      isInfoByTeams = true
    }
  }

  function getMainFocusObj()
  {
    return playersListWidgetWeak && playersListWidgetWeak.getFocusObj()
  }

  function getMainFocusObj2()
  {
    local chatPlace = getObj("lobby_chat_place")
    return ::checkObj(chatPlace)? ::getCustomObjEditbox(chatPlace) : null
  }

  function initChat()
  {
    if (!isChatEnabled())
      return

    local chatObj = scene.findObject("lobby_chat_place")
    if (::checkObj(chatObj))
      ::joinCustomObjRoom(chatObj, ::SessionLobby.getChatRoomId(), ::SessionLobby.getChatRoomPassword(), this)

    restoreFocus()
  }

  function updateSessionInfo()
  {
    local mpMode = ::SessionLobby.getGameMode()
    if (curGMmode != mpMode)
    {
      curGMmode = mpMode
      ::set_mp_mode(curGMmode)
      ::set_gui_options_mode(::get_options_mode(curGMmode))
    }

    ::session_fill_info(scene, ::SessionLobby.getSessionInfo())
  }

  function updateTableHeader()
  {
    local commonHeader = showSceneBtn("common_list_header", !isInfoByTeams)
    local byTeamsHeader = showSceneBtn("list_by_teams_header", isInfoByTeams)
    local teamsNest = isInfoByTeams ? byTeamsHeader : commonHeader.findObject("num_teams")

    local maxMembers = ::SessionLobby.getMaxMembersCount()
    local countTbl = ::SessionLobby.getMembersCountByTeams()
    local countTblReady = ::SessionLobby.getMembersCountByTeams(null, true)
    if (!isInfoByTeams)
    {
      local totalNumPlayersTxt = ::loc("multiplayer/playerList")
        + ::loc("ui/parentheses/space", { text = countTbl.total + "/" + maxMembers })
      commonHeader.findObject("num_players").setValue(totalNumPlayersTxt)
    }

    local event = ::SessionLobby.getRoomEvent()
    foreach(team in tableTeams)
    {
      local teamObj = teamsNest.findObject("num_team" + team.id)
      if (!::check_obj(teamObj))
        continue

      local text = ""
      if (isInfoByTeams && event)
      {
        local locId = "multiplayer/teamPlayers"
        local locParams = {
          players = countTblReady[team.code]
          maxPlayers = ::events.getMaxTeamSize(event)
          unready = countTbl[team.code] - countTblReady[team.code]
        }
        if (locParams.unready)
          locId = "multiplayer/teamPlayers/hasUnready"
        text = ::loc(locId, locParams)
      }
      teamObj.setValue(text)
    }

    ::update_team_css_label(teamsNest)
  }

  function updateRoomInSession()
  {
    if (::checkObj(scene))
      scene.findObject("battle_in_progress").wink = ::SessionLobby.isRoomInSession ? "yes" : "no"
    updateTimerInfo()
  }

  function updateWindow()
  {
    updateTableHeader()
    updateSessionStatus()
    updateButtons()
  }

  function onEventLobbyMembersChanged(p)
  {
    updateWindow()
  }

  function onEventLobbyMemberInfoChanged(p)
  {
    updateWindow()
  }

  function onEventLobbySettingsChange(p)
  {
    updateSessionInfo()
    reinitSlotbar()
    updateWindow()
    updateTimerInfo()
  }

  function onEventLobbyRoomInSession(p)
  {
    updateRoomInSession()
    updateButtons()
  }

  function getSelectedPlayer()
  {
    return playersListWidgetWeak && playersListWidgetWeak.getSelectedPlayer()
  }

  function refreshPlayerInfo(player)
  {
    updatePlayerInfo(player)
    showSceneBtn("btn_usercard", player != null && !::show_console_buttons && ::has_feature("UserCards"))
    showSceneBtn("btn_user_options", player != null && ::show_console_buttons)
  }

  function updatePlayerInfo(player)
  {
    local mainObj = scene.findObject("player_info")
    if (!::checkObj(mainObj) || !player)
      return

    local titleObj = mainObj.findObject("player_title")
    if (::checkObj(titleObj))
      titleObj.setValue((player.title != "") ? (::loc("title/title") + ::loc("ui/colon") + ::loc("title/" + player.title)) : "")

    local spectatorObj = mainObj.findObject("player_spectator")
    if (::checkObj(spectatorObj))
    {
      local desc = ::g_player_state.getStateByPlayerInfo(player).getText(player)
      spectatorObj.setValue((desc != "") ? (::loc("multiplayer/state") + ::loc("ui/colon") + desc) : "")
    }

    local myTeam = (::SessionLobby.status == lobbyStates.IN_LOBBY)? ::SessionLobby.team : ::get_mp_local_team()
    mainObj.playerTeam = myTeam==Team.A? "a" : (myTeam == Team.B? "b" : "")

    local teamObj = mainObj.findObject("player_team")
    if (::checkObj(teamObj))
    {
      local teamTxt = ""
      local teamStyle = ""
      local team = player? player.team : Team.Any
      if (team == Team.A)
      {
        teamStyle = "a"
        teamTxt = ::loc("multiplayer/teamA")
      }
      else if (team == Team.B)
      {
        teamStyle = "b"
        teamTxt = ::loc("multiplayer/teamB")
      }

      teamObj.team = teamStyle
      local teamIcoObj = teamObj.findObject("player_team_ico")
      teamIcoObj.show(teamTxt != "")
      teamIcoObj.tooltip = ::loc("multiplayer/team") + ::loc("ui/colon") + teamTxt
    }

    local playerIcon = (!player || player.isBot)? "cardicon_bot" : avatars.getIconById(player.pilotId)
    ::fill_gamer_card({
                      name = player.name
                      clanTag = player.clanTag
                      icon = playerIcon
                      country = player?.country ?? ""
                    },
                    "player_", mainObj)

    local airObj = mainObj.findObject("curAircraft")
    if (!::checkObj(airObj))
      return

    local showAirItem = ::SessionLobby.getMissionParam("maxRespawns", -1) == 1 && player.country && player.selAirs.len() > 0
    airObj.show(showAirItem)

    if (showAirItem)
    {
      local airName = ::getTblValue(player.country, player.selAirs, "")
      local air = getAircraftByName(airName)
      if (!air)
      {
        airObj.show(false)
        return
      }

      local existingAirObj = airObj.findObject("curAircraft_place")
      if (::checkObj(existingAirObj))
        guiScene.destroyElement(existingAirObj)

      local params = {
        getEdiffFunc = ::Callback(getCurrentEdiff, this)
        status = ::getUnitItemStatusText(bit_unit_status.owned)
      }
      local data = ::build_aircraft_item(airName, air, params)
      data = "tdiv { id:t='curAircraft_place'; class:t='rankUpList';" + data + "}"
      guiScene.appendWithBlk(airObj, data, this)
      ::fill_unit_item_timers(airObj.findObject(airName), air)
    }
  }

  function getMyTeamDisbalanceMsg(isFullText = false)
  {
    local countTbl = ::SessionLobby.getMembersCountByTeams(null, true)
    local maxDisbalance = ::SessionLobby.getMaxDisbalance()
    local myTeam = ::SessionLobby.team
    if (myTeam != Team.A && myTeam != Team.B)
      return ""

    local otherTeam = ::g_team.getTeamByCode(myTeam).opponentTeamCode
    if (countTbl[myTeam] - maxDisbalance < countTbl[otherTeam])
      return ""

    local params = {
      chosenTeam = ::colorize("teamBlueColor", ::g_team.getTeamByCode(myTeam).getShortName())
      otherTeam =  ::colorize("teamRedColor", ::g_team.getTeamByCode(otherTeam).getShortName())
      chosenTeamCount = countTbl[myTeam]
      otherTeamCount =  countTbl[otherTeam]
      reqOtherteamCount = countTbl[myTeam] - maxDisbalance + 1
    }
    local locKey = "multiplayer/enemyTeamTooLowMembers" + (isFullText ? "" : "/short")
    return ::loc(locKey, params)
  }

  function getReadyData()
  {
    local res = {
      readyBtnText = ""
      readyBtnHint = ""
      isVisualDisabled = false
    }

    if (!::SessionLobby.isUserCanChangeReady() && !::SessionLobby.hasSessionInLobby())
      return res

    local isReady = ::SessionLobby.hasSessionInLobby() ? ::SessionLobby.isInLobbySession : ::SessionLobby.isReady
    if (::SessionLobby.canStartSession() && isReady)
      res.readyBtnText = ::loc("multiplayer/btnStart")
    else if (::SessionLobby.isRoomInSession)
    {
      res.readyBtnText = ::loc("mainmenu/toBattle")
      res.isVisualDisabled = !::SessionLobby.canJoinSession()
    } else if (!isReady)
      res.readyBtnText = ::loc("mainmenu/btnReady")

    if (!isReady && ::SessionLobby.isEventRoom && ::SessionLobby.isRoomInSession)
    {
      res.readyBtnHint = getMyTeamDisbalanceMsg()
      res.isVisualDisabled = res.readyBtnHint.len() > 0
    }
    return res
  }

  function updateButtons()
  {
    local readyData = getReadyData()
    local readyBtn = showSceneBtn("btn_ready", readyData.readyBtnText.len())
    ::setDoubleTextToButton(scene, "btn_ready", readyData.readyBtnText)
    readyBtn.inactiveColor = readyData.isVisualDisabled ? "yes" : "no"
    scene.findObject("cant_ready_reason").setValue(readyData.readyBtnHint)

    local spectatorBtnObj = scene.findObject("btn_spectator")
    if (::checkObj(spectatorBtnObj))
    {
      local isSpectator = ::SessionLobby.spectator
      local buttonText = ::loc("mainmenu/btnReferee")
        + (isSpectator ? (::loc("ui/colon") + ::loc("options/on")) : "")
      spectatorBtnObj.setValue(buttonText)
      spectatorBtnObj.active = isSpectator ? "yes" : "no"
    }

    local isReady = ::SessionLobby.isReady
    showSceneBtn("btn_not_ready", ::SessionLobby.isUserCanChangeReady() && isReady)
    showSceneBtn("btn_ses_settings", ::SessionLobby.canChangeSettings())
    showSceneBtn("btn_team", !isReady && ::SessionLobby.canChangeTeam())
    showSceneBtn("btn_spectator", !isReady && ::SessionLobby.canBeSpectator()
      && !::SessionLobby.isSpectatorSelectLocked)
  }

  function getCurrentEdiff()
  {
    local ediff = ::SessionLobby.getCurRoomEdiff()
    return ediff != -1 ? ediff : ::get_current_ediff()
  }

  function onEventLobbyMyInfoChanged(params)
  {
    updateButtons()
    if ("team" in params)
      guiScene.performDelayed(this, function () {
        reinitSlotbar()
      })
  }

  function onEventLobbyReadyChanged(p)
  {
    updateButtons()
  }

  function updateSessionStatus()
  {
    local needSessionStatus = !isInfoByTeams && !::SessionLobby.isRoomInSession
    local sessionStatusObj = showSceneBtn("session_status", needSessionStatus)
    if (needSessionStatus)
      sessionStatusObj.setValue(::SessionLobby.getMembersReadyStatus().statusText)

    local mGameMode = ::SessionLobby.getMGameMode()
    local needTeamStatus = isInfoByTeams && !::SessionLobby.isRoomInSession && !!mGameMode
    local countTbl = null
    if (needTeamStatus)
      countTbl = ::SessionLobby.getMembersCountByTeams()
    foreach(idx, team in tableTeams)
    {
      local teamObj = showSceneBtn("team_status_" + team.id, needTeamStatus)
      if (!teamObj || !needTeamStatus)
        continue

      local status = ""
      local minSize = ::events.getMinTeamSize(mGameMode)
      local teamSize = countTbl[team.code]
      if (teamSize < minSize)
        status = ::loc("multiplayer/playersTeamLessThanMin", { minSize = minSize })
      else
      {
        local maxDisbalance = ::SessionLobby.getMaxDisbalance()
        local otherTeamSize = countTbl[team.opponentTeamCode]
        if (teamSize - maxDisbalance > ::max(otherTeamSize, minSize))
          status = ::loc("multiplayer/playersTeamDisbalance", { maxDisbalance = maxDisbalance })
      }
      teamObj.setValue(status)
    }
  }

  function updateTimerInfo()
  {
    local timers = ::SessionLobby.getRoomActiveTimers()
    local isVisibleNow = timers.len() > 0 && !::SessionLobby.isRoomInSession
    if (!isVisibleNow && !isTimerVisible)
      return

    isTimerVisible = isVisibleNow
    local timerObj = showSceneBtn("battle_start_countdown", isTimerVisible)
    if (timerObj && isTimerVisible)
      timerObj.setValue(timers[0].text)
  }

  function onUpdate(obj, dt)
  {
    updateTimerInfo()
  }

  function getChatLog()
  {
    local chatRoom = ::g_chat.getRoomById(::SessionLobby.getChatRoomId())
    return chatRoom!= null ? chatRoom.getLogForBanhammer() : null
  }

  function onComplain(obj)
  {
    local player = getSelectedPlayer()
    if (player && !player.isBot && !player.isLocal)
      ::gui_modal_complain({uid = player.userId, name = player.name }, getChatLog())
  }

  function openUserCard(player)
  {
    if (player && !player.isBot)
      ::gui_modal_userCard({ name = player.name, uid = player.userId });
  }

  function onUserCard(obj)
  {
    openUserCard(getSelectedPlayer())
  }

  function onUserRClick(player)
  {
    session_player_rmenu(this, player, getChatLog())
  }

  function onUserOption(obj)
  {
    local pos = playersListWidgetWeak && playersListWidgetWeak.getSelectedRowPos()
    session_player_rmenu(this, getSelectedPlayer(), getChatLog(), pos)
  }

  function onSessionSettings()
  {
    if (!::SessionLobby.isRoomOwner)
      return

    if (::SessionLobby.isReady)
    {
      msgBox("cannot_options_on_ready", ::loc("multiplayer/cannotOptionsOnReady"),
        [["ok", function() {}]], "ok", {cancel_fn = function() {}})
      return
    }

    if (::SessionLobby.isRoomInSession)
    {
      msgBox("cannot_options_on_ready", ::loc("multiplayer/cannotOptionsWhileInBattle"),
        [["ok", function() {}]], "ok", {cancel_fn = function() {}})
      return
    }

    //local gm = ::SessionLobby.getGameMode()
    //if (gm == ::GM_SKIRMISH)
    ::gui_start_mislist(true, ::get_mp_mode())
  }

  function onSpectator(obj)
  {
    ::SessionLobby.switchSpectator()
  }

  function onTeam(obj)
  {
    local isSymmetric = ::SessionLobby.getPublicParam("symmetricTeams", true)
    ::SessionLobby.switchTeam(!isSymmetric)
  }

  function onPlayers(obj)
  {
  }

  function doQuit()
  {
    SessionLobby.leaveRoom()
  }

  function onEventLobbyStatusChange(params)
  {
    if (!::SessionLobby.isInRoom())
      goBack()
    else
      updateButtons()
  }

  function onNotReady()
  {
    if (::SessionLobby.isReady)
      ::SessionLobby.setReady(false)
  }

  function onCancel()
  {
    msgBox("ask_leave_lobby", ::loc("flightmenu/questionQuitGame"),
    [
      ["yes", doQuit],
      ["no", function() { }]
    ], "no", { cancel_fn = function() {}})
  }

  function onReady()
  {
    local event = ::SessionLobby.getRoomEvent()
    if (event != null && !antiCheat.showMsgboxIfEacInactive(event))
      return

    if (::SessionLobby.tryJoinSession())
      return

    if (!::SessionLobby.isRoomOwner || !::SessionLobby.isReady)
      return ::SessionLobby.setReady(true)

    local status = ::SessionLobby.getMembersReadyStatus()
    if (status.readyToStart)
      return ::SessionLobby.startSession()

    local msg = status.statusText
    local buttons = [["ok", function() {}]]
    local defButton = "ok"
    if (status.ableToStart)
    {
      buttons = [["#multiplayer/btnStart", function() { ::SessionLobby.startSession() }], ["cancel", function() {}]]
      defButton = "cancel"
      msg += "\n" + ::loc("ask/startGameAnyway")
    }

    msgBox("ask_start_session", msg, buttons, defButton, { cancel_fn = function() {}})
  }

  function onCustomChatCancel()
  {
    onCancel()
  }

  function canPresetChange()
  {
    return true
  }

  function onVehiclesInfo(obj)
  {
    ::gui_start_modal_wnd(::gui_handlers.VehiclesWindow, {
      teamDataByTeamName = ::SessionLobby.getSessionInfo()
      roomSpecialRules = ::SessionLobby.getRoomSpecialRules()
    })
  }

  function checkNotInvitedPlayers()
  {
    if (curGMmode != ::GM_SKIRMISH)
      return

    local members = ::g_squad_manager.getNotInvitedToSessionUsersList()
    if (members.len())
    {
      local namesText = members.map(@(m) ::colorize("mySquadColor", m.name))
      ::g_popups.add(::loc("mainmenu/playersAreNotInvited"), ::g_string.implode(namesText, ", "))
    }
  }
}

::gui_modal_joiningGame <- function gui_modal_joiningGame()
{
  ::gui_start_modal_wnd(::gui_handlers.JoiningGame)
}

class ::gui_handlers.JoiningGame extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/msgBox.blk"
  timeToShowCancel = 30
  timer = -1

  function initScreen()
  {
    scene.findObject("msgWaitAnimation").show(true)
    scene.findObject("msg_box_timer").setUserData(this)
    updateInfo()
  }

  function onEventLobbyStatusChange(params)
  {
    updateInfo()
  }

  function onEventEventsDataUpdated(params)
  {
    updateInfo()
  }

  function updateInfo()
  {
    if (!::SessionLobby.needJoiningWnd())
      return goBack()

    resetTimer() //statusChanged
    checkGameMode()

    local misData = ::SessionLobby.getMissionParams()
    local msg = ::loc("wait/sessionJoin")
    if (::SessionLobby.status == lobbyStates.UPLOAD_CONTENT)
      msg = ::loc("wait/sessionUpload")
    if (misData)
    {
      msg += "\n\n" + ::colorize("activeTextColor", getCurrentMissionGameMode())
      msg += "\n" + ::colorize("userlogColoredText", getCurrentMissionName())
    }
    scene.findObject("msgText").setValue(msg)
  }

  function getCurrentMissionGameMode()
  {
    local gameModeName = ::get_cur_game_mode_name()
    if (gameModeName == "domination")
    {
      local event = ::SessionLobby.getRoomEvent()
      if (event == null ||
          ::events.getEventDisplayType(event) != ::g_event_display_type.RANDOM_BATTLE)
        gameModeName = "event"
    }
    return ::loc("multiplayer/" + gameModeName + "Mode")
  }

  function getCurrentMissionName()
  {
    if (::get_game_mode() == ::GM_DOMINATION)
    {
      local event = ::SessionLobby.getRoomEvent()
      if (event)
        return ::events.getEventNameText(event)
    }
    else
    {
      local misName = ::SessionLobby.getMissionNameLoc()
      if (misName != "")
        return misName
    }
    return ""
  }

  function checkGameMode()
  {
    local gm = ::SessionLobby.getGameMode()
    local curGm = ::get_game_mode()
    if (gm < 0 || curGm==gm)
      return

    ::set_mp_mode(gm)
    if (mainGameMode < 0)
      mainGameMode = curGm  //to restore gameMode after close window
  }

  function showCancelButton(show)
  {
    local btnId = "btn_cancel"
    local obj = scene.findObject(btnId)
    if (obj)
    {
      obj.show(show)
      obj.enable(show)
      if (show)
        obj.select()
      return
    }
    if (!show)
      return

    local data = format("Button_text { id:t='%s'; btnName:t='AB'; text:t='#msgbox/btn_cancel'; on_click:t='onCancel' }", btnId)
    local holderObj = scene.findObject("buttons_holder")
    if (!holderObj)
      return

    guiScene.appendWithBlk(holderObj, data, this)
    obj = scene.findObject(btnId)
    obj.select()
  }

  function resetTimer()
  {
    timer = timeToShowCancel
    showCancelButton(false)
  }

  function onUpdate(obj, dt)
  {
    if (timer < 0)
      return
    timer -= dt
    if (timer < 0)
      showCancelButton(true)
  }

  function onCancel()
  {
    guiScene.performDelayed(this, function()
    {
      if (timer >= 0)
        return
      ::destroy_session_scripted()
      ::SessionLobby.leaveRoom()
    })
  }
}
