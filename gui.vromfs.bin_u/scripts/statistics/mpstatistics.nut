let time = require("%scripts/time.nut")
let mpChatModel = require("%scripts/chat/mpChatModel.nut")
let avatars = require("%scripts/user/avatars.nut")
let { setMousePointerInitialPosOnChildByValue } = require("%scripts/controls/mousePointerInitialPos.nut")
let { MISSION_OBJECTIVE } = require("%scripts/missions/missionsUtilsModule.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { updateListLabelsSquad, isShowSquad } = require("%scripts/statistics/squadIcon.nut")

const OVERRIDE_COUNTRY_ID = "override_country"

local MPStatistics = class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndControlsAllowMask = CtrlsInGui.CTRL_ALLOW_MP_STATISTICS
                         | CtrlsInGui.CTRL_ALLOW_VEHICLE_KEYBOARD | CtrlsInGui.CTRL_ALLOW_VEHICLE_JOY

  needPlayersTbl = true
  showLocalTeamOnly = false
  isModeStat = false
  isRespawn = false
  isSpectate = false
  isTeam = false
  isStatScreen = true

  isWideScreenStatTbl = false
  showAircrafts = false

  mplayerTable = null
  missionTable = null

  tblSave1 = null
  numRows1 = 0
  tblSave2 = null
  numRows2 = 0

  gameMode = 0
  gameType = 0
  isOnline = false

  isTeamplay    = false
  isTeamsWithCountryFlags = false
  isTeamsRandom = true

  missionObjectives = MISSION_OBJECTIVE.NONE

  wasTimeLeft = -1000
  updateCooldown = 3

  numMaxPlayers = 16  //its only visual max players. no need to scroll when table near empty.
  isApplyPressed = false

  checkRaceDataOnStart = true
  numberOfWinningPlaces = -1

  defaultRowHeaders         = ["squad", "name", "unitIcon", "aircraft", "missionAliveTime", "score", "kills", "groundKills", "navalKills",
                               "aiKills", "aiGroundKills", "aiNavalKills", "aiTotalKills", "awardDamage", "assists", "captureZone", "damageZone", "deaths"]
  raceRowHeaders            = ["rowNo", "name", "unitIcon", "aircraft", "raceFinishTime", "raceLap", "raceLastCheckpoint",
                               "raceLastCheckpointTime", "deaths"]
  footballRowHeaders        = ["name", "footballScore", "footballGoals", "footballAssists"]

  statTrSize = "pw, 1@baseTrHeight"

  function onActivateOrder()
  {
    ::g_orders.openOrdersInventory()
  }

  function updateTimeToKick(dt)
  {
    updateTimeToKickTimer()
    updateTimeToKickAlert(dt)
  }

  function updateTimeToKickTimer()
  {
    let timeToKickObj = getTimeToKickObj()
    if (!::checkObj(timeToKickObj))
      return
    let timeToKickValue = ::get_mp_kick_countdown()
    // Already in battle or it's too early to show the message.
    if (timeToKickValue <= 0 || ::get_time_to_kick_show_timer() < timeToKickValue)
      timeToKickObj.setValue("")
    else
    {
      let timeToKickText = time.secondsToString(timeToKickValue, true, true)
      let locParams = {
        timeToKick = ::colorize("activeTextColor", timeToKickText)
      }
      timeToKickObj.setValue(::loc("respawn/timeToKick", locParams))
    }
  }

  function updateTimeToKickAlert(dt)
  {
    let timeToKickAlertObj = scene.findObject("time_to_kick_alert_text")
    if (!::checkObj(timeToKickAlertObj))
      return
    let timeToKickValue = ::get_mp_kick_countdown()
    if (timeToKickValue <= 0 || get_time_to_kick_show_alert() < timeToKickValue || isSpectate)
      timeToKickAlertObj.show(false)
    else
    {
      timeToKickAlertObj.show(true)
      let curTime = ::dagor.getCurTime()
      let prevSeconds = ((curTime - 1000 * dt) / 1000).tointeger()
      let currSeconds = (curTime / 1000).tointeger()
      if (currSeconds != prevSeconds)
      {
        timeToKickAlertObj["_blink"] = "yes"
        guiScene.playSound("kick_alert")
      }
    }
  }

  function onOrderTimerUpdate(obj, dt)
  {
    ::g_orders.updateActiveOrder()
    let isOrderCanBeActivated = ::g_orders.orderCanBeActivated()
    if (::checkObj(obj))
    {
      obj.text = ::g_orders.getActivateButtonLabel()
      obj.inactiveColor = !isOrderCanBeActivated ? "yes" : "no"
    }
    if (isOrderCanBeActivated
      && ::get_option_in_mode(::USEROPT_ORDER_AUTO_ACTIVATE, ::OPTIONS_MODE_GAMEPLAY).value)
        ::g_orders.activateSoonExpiredOrder()
  }

  function setTeamInfoTeam(teamObj, team)
  {
    if (!::checkObj(teamObj))
      return
    teamObj.team = team
  }

  function setTeamInfoTeamIco(teamObj, teamIco = null)
  {
    if (!::checkObj(teamObj))
      return
    let teamImgObj = teamObj.findObject("team_img")
    if (::checkObj(teamImgObj))
      teamImgObj.show(teamIco != null)
    if (teamIco != null)
      teamObj.teamIco = teamIco
  }

  function setTeamInfoText(teamObj, text)
  {
    if (!::checkObj(teamObj))
      return
    let textObj = teamObj.findObject("team_text")
    if (::checkObj(textObj))
      textObj.setValue(text)
  }

  /**
   * Sets country flags visibility based
   * on specified country names list.
   */
  function setTeamInfoCountries(teamObj, enabledCountryNames)
  {
    if (!::checkObj(teamObj))
      return
    foreach (countryName in shopCountriesList)
    {
      let countryFlagObj = teamObj.findObject(countryName)
      if (::checkObj(countryFlagObj))
        countryFlagObj.show(::isInArray(countryName, enabledCountryNames))
    }
  }

  function updateOverrideCountry(teamObj, countryIcon) {
    if (!::check_obj(teamObj))
      return

    let countryFlagObj = ::showBtn(OVERRIDE_COUNTRY_ID, countryIcon != null, teamObj)
    if (::check_obj(countryFlagObj))
      countryFlagObj["background-image"] = ::get_country_icon(countryIcon)
  }

  /**
   * Places all available country
   * flags into container.
   */
  function initTeamInfoCountries(teamObj)
  {
    if (!::checkObj(teamObj))
      return
    let countriesBlock = teamObj.findObject("countries_block")
    if (!::checkObj(countriesBlock))
      return
    let view = {
      countries = shopCountriesList
        .map(@(countryName) {
          countryName = countryName
          countryIcon = ::get_country_icon(countryName)
        })
        .append({
          countryName = OVERRIDE_COUNTRY_ID
          countryIcon = ""
        })
    }
    let result = ::handyman.renderCached("%gui/countriesList", view)
    guiScene.replaceContentFromText(countriesBlock, result, result.len(), this)
  }

  function setInfo()
  {
    let timeLeft = ::get_multiplayer_time_left()
    if (timeLeft < 0)
    {
      setGameEndStat(-1)
      return
    }
    local timeDif = wasTimeLeft - timeLeft
    if (timeDif < 0)
      timeDif = -timeDif
    if (timeDif >= 1 || ((wasTimeLeft * timeLeft) < 0))
    {
      setGameEndStat(timeLeft)
      wasTimeLeft = timeLeft
    }
  }

  function initScreen()
  {
    scene.findObject("stat_update").setUserData(this)
    needPlayersTbl = scene.findObject("table_kills_team1") != null

    includeMissionInfoBlocksToGamercard()
    setSceneTitle(getCurMpTitle())
    setInfo()
  }

  function initStats()
  {
    if (!::checkObj(scene))
      return

    initStatsMissionParams()

    let playerTeam = getLocalTeam()
    let friendlyTeam = ::get_player_army_for_hud()
    let teamObj1 = scene.findObject("team1_info")
    let teamObj2 = scene.findObject("team2_info")

    if (!isTeamplay)
    {
      foreach(obj in [teamObj1, teamObj2])
        if (::checkObj(obj))
          obj.show(false)
    }
    else if (needPlayersTbl && playerTeam > 0)
    {
      if (::checkObj(teamObj1))
      {
        setTeamInfoTeam(teamObj1, (playerTeam == friendlyTeam)? "blue" : "red")
        initTeamInfoCountries(teamObj1)
      }
      if (!showLocalTeamOnly && ::checkObj(teamObj2))
      {
        setTeamInfoTeam(teamObj2, (playerTeam == friendlyTeam)? "red" : "blue")
        initTeamInfoCountries(teamObj2)
      }
    }

    if (needPlayersTbl)
    {
      createStats()
      scene.findObject("table_kills_team1").setValue(-1)
      scene.findObject("table_kills_team2").setValue(-1)
    }

    updateCountryFlags()
  }

  function initStatsMissionParams()
  {
    gameMode = ::get_game_mode()
    gameType = ::get_game_type()
    isOnline = ::g_login.isLoggedIn()

    isTeamplay = ::is_mode_with_teams(gameType)
    isTeamsRandom = !isTeamplay || gameMode == ::GM_DOMINATION
    if (::SessionLobby.isInRoom() || ::is_replay_playing())
      isTeamsWithCountryFlags = isTeamplay &&
        (::get_mission_difficulty_int() > 0 || !::SessionLobby.getPublicParam("symmetricTeams", true))

    missionObjectives = ::g_mission_type.getCurrentObjectives()
  }

  function createKillsTbl(objTbl, tbl, tblConfig)
  {
    let team = ::getTblValue("team", tblConfig, -1)
    let num_rows = ::getTblValue("num_rows", tblConfig, numMaxPlayers)
    let showUnits     = tblConfig?.showAircrafts ?? false
    let showAirIcons  = tblConfig?.showAirIcons  ?? showUnits
    let invert = ::getTblValue("invert", tblConfig, false)

    local tblData = [] // columns order

    let markupData = {
      tr_size = statTrSize
      invert = invert
      colorTeam = "blue"
      columns = {}
    }

    if (gameType & ::GT_COOPERATIVE)
    {
      tblData = showAirIcons ? [ "unitIcon", "name" ] : [ "name" ]
      foreach(id in tblData)
        markupData.columns[id] <- ::g_mplayer_param_type.getTypeById(id).getMarkupData()

      if ("name" in markupData.columns)
        markupData.columns["name"].width = "fw"
    }
    else
    {
      let sourceHeaders = gameType & ::GT_FOOTBALL ? footballRowHeaders
        : gameType & ::GT_RACE ? raceRowHeaders
        : defaultRowHeaders

      foreach (id in sourceHeaders)
        if (::g_mplayer_param_type.getTypeById(id).isVisible(missionObjectives, gameType, gameMode))
          tblData.append(id)

      if (!showUnits)
        ::u.removeFrom(tblData, "aircraft")
      if (!isShowSquad())
        ::u.removeFrom(tblData, "squad")

      foreach(name in tblData)
        markupData.columns[name] <- ::g_mplayer_param_type.getTypeById(name).getMarkupData()

      if ("name" in markupData.columns)
      {
        let col = markupData.columns["name"]
        if (isWideScreenStatTbl && ("widthInWideScreen" in col))
          col.width = col.widthInWideScreen
      }

      ::count_width_for_mptable(objTbl, markupData.columns)

      let teamNum = (team==2)? 2 : 1
      let tableObj = scene.findObject($"team_table_{teamNum}")
      if (team == 2)
        markupData.colorTeam = "red"
      if (::checkObj(tableObj))
      {
        let rowHeaderData = createHeaderRow(tableObj, tblData, markupData, teamNum)
        let show = rowHeaderData != ""
        guiScene.replaceContentFromText(tableObj, rowHeaderData, rowHeaderData.len(), this)
        tableObj.show(show)
        tableObj.normalFont = ::is_low_width_screen() ? "yes" : "no"
      }
    }

    if (team == -1 || team == 1)
      tblSave1 = tbl
    else
      tblSave2 = tbl

    if (tbl)
    {
      if (!isTeamplay)
        sortTable(tbl)

      let data = ::build_mp_table(tbl, markupData, tblData, num_rows)
      guiScene.replaceContentFromText(objTbl, data, data.len(), this)
    }
  }

  function sortTable(table)
  {
    table.sort(::mpstat_get_sort_func(gameType))
  }

  function setKillsTbl(objTbl, team, playerTeam, friendlyTeam, showAirIcons=true, customTbl = null)
  {
    if (!::checkObj(objTbl))
      return

    local tbl = null

    objTbl.smallFont = ::is_low_width_screen() ? "yes" : "no"

    if (customTbl)
    {
      let idx = max(team-1, -1)
      if (idx in customTbl?.playersTbl)
        tbl = customTbl.playersTbl[idx]
    }

    local minRow = 0
    if (!tbl)
    {
      if (!isTeamplay)
      {
        let commonTbl = getMplayersList(::GET_MPLAYERS_LIST)
        sortTable(commonTbl)
        if (commonTbl.len() > 0)
        {
          local lastRow = numMaxPlayers - 1
          if (objTbl.id == "table_kills_team2")
          {
            minRow = commonTbl.len() <= numMaxPlayers ? 0 : numMaxPlayers
            lastRow = commonTbl.len()
          }

          tbl = []
          for(local i = lastRow; i >= minRow; --i)
          {
            if (!(i in commonTbl))
              continue

            let block = commonTbl.remove(i)
            block.place <- (i+1).tostring()
            tbl.append(block)
          }
          tbl.reverse()
        }
      }
      else
        tbl = getMplayersList(team)
    }
    else if (!isTeamplay && customTbl && objTbl.id == "table_kills_team2")
      minRow = numMaxPlayers

    if (objTbl.id == "table_kills_team2")
    {
      local shouldShow = true
      if (isTeamplay)
        shouldShow = tbl && tbl.len() > 0
      showSceneBtn("team2-root", shouldShow)
    }

    if (!isTeamplay && minRow >= 0)
    {
      if (minRow == 0)
        tblSave1 = tbl
      else
        tblSave2 = tbl
    }
    else
    {
      if (team == playerTeam || playerTeam == -1 || showLocalTeamOnly)
        tblSave1 = tbl
      else
        tblSave2 = tbl
    }

    if (tbl != null)
    {
      if (!customTbl && isTeamplay)
        sortTable(tbl)

      local numRows = numRows1
      if (team == 2)
        numRows = numRows2

      let params = {
                       max_rows = numRows,
                       showAirIcons = showAirIcons,
                       continueRowNum = minRow,
                       numberOfWinningPlaces = numberOfWinningPlaces
                       playersInfo = customTbl?.playersInfo
                     }
      ::set_mp_table(objTbl, tbl, params)
      ::update_team_css_label(objTbl, getLocalTeam())

      if (friendlyTeam > 0 && team > 0)
        objTbl["team"] = (isTeamplay && friendlyTeam == team)? "blue" : "red"
    }
    updateCountryFlags()
  }

  function isShowEnemyAirs()
  {
    return showAircrafts && ::get_mission_difficulty_int() == 0
  }

  function createStats()
  {
    if (!needPlayersTbl)
      return

    let tblObj1 = scene.findObject("table_kills_team1")
    let tblObj2 = scene.findObject("table_kills_team2")
    let team1Root = scene.findObject("team1-root")
    updateNumMaxPlayers()

    if (!isTeamplay)
    {
      let tbl1 = getMplayersList(::GET_MPLAYERS_LIST)
      sortTable(tbl1)

      let tbl2 = []
      numRows1 = tbl1.len()
      numRows2 = 0
      if (tbl1.len() >= numMaxPlayers)
      {
        numRows1 = numMaxPlayers
        numRows2 = numMaxPlayers

        for(local i = tbl1.len()-1; i >= numMaxPlayers; --i)
        {
          if (!(i in tbl1))
            continue

          let block = tbl1.remove(i)
          block.place <- (i+1).tostring()
          tbl2.append(block)
        }
        tbl2.reverse()
      }

      createKillsTbl(tblObj1, tbl1, {num_rows = numRows1, team = Team.A, showAircrafts = showAircrafts})
      createKillsTbl(tblObj2, tbl2, {num_rows = numRows2, team = Team.B, showAircrafts = showAircrafts})

      if (::checkObj(team1Root))
        team1Root.show(true)
    }
    else if (gameType & ::GT_VERSUS)
    {
      if (showLocalTeamOnly)
      {
        let playerTeam = getLocalTeam()
        let tbl = getMplayersList(playerTeam)
        numRows1 = numMaxPlayers
        numRows2 = 0
        createKillsTbl(tblObj1, tbl, {num_rows = numRows1, showAircrafts = showAircrafts})
      }
      else
      {
        let tbl1 = getMplayersList(1)
        let tbl2 = getMplayersList(2)
        let num_in_one_row = ::global_max_players_versus / 2
        if (tbl1.len() <= num_in_one_row && tbl2.len() <= num_in_one_row)
        {
          numRows1 = num_in_one_row
          numRows2 = num_in_one_row
        }
        else if (tbl1.len() > num_in_one_row)
          numRows2 = ::global_max_players_versus - tbl1.len()
        else if (tbl2.len() > num_in_one_row)
          numRows1 = ::global_max_players_versus - tbl2.len()

        if (numRows1 > numMaxPlayers)
          numRows1 = numMaxPlayers
        if (numRows2 > numMaxPlayers)
          numRows2 = numMaxPlayers

        let showEnemyAircrafts = isShowEnemyAirs()
        let tblConfig1 = {tbl = tbl2, team = Team.A, num_rows = numRows2, showAircrafts = showAircrafts, invert = true}
        let tblConfig2 = {tbl = tbl1, team = Team.B, num_rows = numRows1, showAircrafts = showEnemyAircrafts}

        if (getLocalTeam() == Team.A)
        {
          tblConfig1.tbl = tbl1
          tblConfig1.num_rows = numRows1

          tblConfig2.tbl = tbl2
          tblConfig2.num_rows = numRows2
        }

        createKillsTbl(tblObj1, tblConfig1.tbl, tblConfig1)
        createKillsTbl(tblObj2, tblConfig2.tbl, tblConfig2)

        if (::checkObj(team1Root))
          team1Root.show(true)
      }
    }
    else
    {
      numRows1 = (gameType & ::GT_COOPERATIVE)? ::global_max_players_coop : numMaxPlayers
      numRows2 = 0
      let tbl = getMplayersList(::GET_MPLAYERS_LIST)
      createKillsTbl(tblObj2, tbl, {num_rows = numRows1, showAircrafts = showAircrafts})

      tblObj1.show(false)

      if (::checkObj(team1Root))
        team1Root.show(false)

      let headerObj = scene.findObject("team2_header")
      if (::checkObj(headerObj))
        headerObj.show(false)
    }
  }

  function updateTeams(tbl, playerTeam, friendlyTeam)
  {
    if (!tbl)
      return

    let teamObj1 = scene.findObject("team1_info")
    let teamObj2 = scene.findObject("team2_info")

    let playerTeamIdx = ::clamp(playerTeam - 1, 0, 1)
    let teamTxt = ["", ""]
    switch (gameType & (::GT_MP_SCORE | ::GT_MP_TICKETS))
    {
      case ::GT_MP_SCORE:
        if (!needPlayersTbl)
          break

        let scoreFormat = "%s" + ::loc("multiplayer/score") + ::loc("ui/colon") + "%d"
        if (tbl.len() > playerTeamIdx)
        {
          setTeamInfoText(teamObj1, ::format(scoreFormat, teamTxt[0], tbl[playerTeamIdx].score))
          setTeamInfoTeam(teamObj1, (playerTeam == friendlyTeam) ? "blue" : "red")
        }
        if (tbl.len() > 1 - playerTeamIdx && !showLocalTeamOnly)
        {
          setTeamInfoText(teamObj2, ::format(scoreFormat, teamTxt[1], tbl[1-playerTeamIdx].score))
          setTeamInfoTeam(teamObj2, (playerTeam == friendlyTeam)? "red" : "blue")
        }
        break

      case ::GT_MP_TICKETS:
        let rounds = ::get_mp_rounds()
        let curRound = ::get_mp_current_round()

        if (needPlayersTbl)
        {
          let scoreLoc = (rounds > 0) ? ::loc("multiplayer/rounds") : ::loc("multiplayer/airfields")
          let scoreformat = "%s" + ::loc("multiplayer/tickets") + ::loc("ui/colon") + "%d" + ", " +
                                scoreLoc + ::loc("ui/colon") + "%d"

          if (tbl.len() > playerTeamIdx)
          {
            setTeamInfoText(teamObj1, ::format(scoreformat, teamTxt[0], tbl[playerTeamIdx].tickets, tbl[playerTeamIdx].score))
            setTeamInfoTeam(teamObj1, (playerTeam == friendlyTeam) ? "blue" : "red")
          }
          if (tbl.len() > 1 - playerTeamIdx && !showLocalTeamOnly)
          {
            setTeamInfoText(teamObj2, ::format(scoreformat, teamTxt[1], tbl[1 - playerTeamIdx].tickets, tbl[1 - playerTeamIdx].score))
            setTeamInfoTeam(teamObj2, (playerTeam == friendlyTeam)? "red" : "blue")
          }
        }

        let statObj = scene.findObject("gc_mp_tickets_rounds")
        if (::checkObj(statObj))
        {
          local text = ""
          if (rounds > 0)
            text = ::loc("multiplayer/curRound", { round = curRound+1, total = rounds })
          statObj.setValue(text)
        }
        break
    }
  }

  function updateStats(customTbl = null, customTblTeams = null, customFriendlyTeam = null)
  {
    local playerTeam   = getLocalTeam()
    let friendlyTeam = customFriendlyTeam ?? ::get_player_army_for_hud()
    let tblObj1 = scene.findObject("table_kills_team1")
    let tblObj2 = scene.findObject("table_kills_team2")

    if (needPlayersTbl)
    {
      if (!isTeamplay || (gameType & ::GT_VERSUS))
      {
        if (!isTeamplay)
          playerTeam = Team.A

        setKillsTbl(tblObj1, playerTeam, playerTeam, friendlyTeam, showAircrafts, customTbl) // warning disable: -param-pos
        if (!showLocalTeamOnly && playerTeam > 0)
          setKillsTbl(tblObj2, 3 - playerTeam, playerTeam, friendlyTeam, isShowEnemyAirs(), customTbl)
      }
      else
        setKillsTbl(tblObj2, -1, -1, -1, showAircrafts, customTbl)
    }

    if (playerTeam > 0)
      updateTeams(customTblTeams || ::get_mp_tbl_teams(), playerTeam, friendlyTeam)

    if (checkRaceDataOnStart && ::is_race_started())
    {
      let chObj = scene.findObject("gc_race_checkpoints")
      if (::checkObj(chObj))
      {
        let totalCheckpointsAmount = ::get_race_checkpioints_count()
        local text = ""
        if (totalCheckpointsAmount > 0)
          text = ::getCompoundedText(::loc("multiplayer/totalCheckpoints") + ::loc("ui/colon"), totalCheckpointsAmount, "activeTextColor")
        chObj.setValue(text)
        checkRaceDataOnStart = false
      }

      numberOfWinningPlaces = ::get_race_winners_count()
    }

    ::update_team_css_label(scene.findObject("num_teams"), playerTeam)
  }

  function updateTables(dt)
  {
    updateCooldown -= dt
    if (updateCooldown <= 0)
    {
      updateStats()
      updateCooldown = 3
    }

    if (isStatScreen || !needPlayersTbl)
      return

    if (isRespawn)
    {
      let selectedObj = getSelectedTable()
      if (!isModeStat)
      {
        let objTbl1 = scene.findObject("table_kills_team1")
        let curRow = objTbl1.getValue()
        if (curRow < 0 || curRow >= objTbl1.childrenCount())
          objTbl1.setValue(0)
      }
      else
        if (selectedObj == null)
        {
          scene.findObject("table_kills_team1").setValue(0)
          updateListsButtons()
        }
    }
    else
    {
      scene.findObject("table_kills_team1").setValue(-1)
      scene.findObject("table_kills_team2").setValue(-1)
    }
  }

  function createHeaderRow(tableObj, hdr, markupData, teamNum)
  {
    if (!markupData
        || typeof markupData != "table"
        || !("columns" in markupData)
        || !markupData.columns.len()
        || !::checkObj(tableObj))
      return ""

    let tblData = clone hdr

    if (::getTblValue("invert", markupData, false))
      tblData.reverse()

    let view = {cells = []}
    foreach(name in tblData)
    {
      let value = markupData.columns?[name]
      if (!value || typeof value != "table")
        continue

      view.cells.append({
        id = ::getTblValue("id", value, name)
        fontIcon = ::getTblValue("fontIcon", value, null)
        tooltip = ::getTblValue("tooltip", value, null)
        width = ::getTblValue("width", value, "")
      })
    }

    let tdData = ::handyman.renderCached(("%gui/statistics/statTableHeaderCell"), view)
    let trId = "team-header" + teamNum
    let trSize = ::getTblValue("tr_size", markupData, "0,0")
    let trData = ::format("tr{id:t='%s'; size:t='%s'; %s}", trId, trSize, tdData)
    return trData
  }

  function goBack(obj) {}

  function onUserCard(obj)
  {
    let player = getSelectedPlayer();
    if (!player || player.isBot || !isOnline)
      return;

    ::gui_modal_userCard({ name = player.name /*, id = player.id*/ }); //search by nick no work, but session can be not exist at that moment
  }

  function onUserRClick(obj)
  {
    onStatsTblSelect(obj)
    ::session_player_rmenu(this, getSelectedPlayer(), getChatLog())
  }

  function onUserOptions(obj)
  {
    let selectedTableObj = getSelectedTable()
    if (!::check_obj(selectedTableObj))
      return

    onStatsTblSelect(selectedTableObj)
    let selectedPlayer = getSelectedPlayer()
    let orientation = selectedTableObj.id == "table_kills_team1"? RCLICK_MENU_ORIENT.RIGHT : RCLICK_MENU_ORIENT.LEFT
    ::session_player_rmenu(this, selectedPlayer, getChatLog(), getSelectedRowPos(selectedTableObj, orientation), orientation)
  }

  function getSelectedRowPos(selectedTableObj, orientation)
  {
    let rowNum = selectedTableObj.getValue()
    if (rowNum >= selectedTableObj.childrenCount())
      return null

    let rowObj = selectedTableObj.getChild(rowNum)
    let rowSize = rowObj.getSize()
    let rowPos = rowObj.getPosRC()

    local posX = rowPos[0]
    if (orientation == RCLICK_MENU_ORIENT.RIGHT)
      posX += rowSize[0]

    return [posX, rowPos[1] + rowSize[1]]
  }

  function getPlayerInfo(name)
  {
    if (name && name != "")
      foreach (tbl in [tblSave1, tblSave2])
        if (tbl)
          foreach(player in tbl)
            if (player.name == name)
              return player
    return null
  }

  function refreshPlayerInfo()
  {
    setPlayerInfo()

    let player = getSelectedPlayer()
    showSceneBtn("btn_user_options", isOnline && player && !player.isBot && !isSpectate && ::show_console_buttons)
    updateListLabelsSquad()
  }

  function setPlayerInfo()
  {
    let playerInfo = getSelectedPlayer()
    let teamObj = scene.findObject("player_team")
    if (isTeam && ::checkObj(teamObj))
    {
      local teamTxt = ""
      let team = playerInfo? playerInfo.team : Team.Any
      if (team == Team.A)
        teamTxt = ::loc("multiplayer/teamA")
      else if (team == Team.B)
        teamTxt = ::loc("multiplayer/teamB")
      else
        teamTxt = ::loc("multiplayer/teamRandom")
      teamObj.setValue(::loc("multiplayer/team") + ::loc("ui/colon") + teamTxt)
    }

    ::fill_gamer_card({
                      name = playerInfo? playerInfo.name : ""
                      clanTag = playerInfo? playerInfo.clanTag : ""
                      icon = (!playerInfo || playerInfo.isBot)? "cardicon_bot" : avatars.getIconById(playerInfo.pilotId)
                      country = playerInfo? playerInfo.country : ""
                    },
                    "player_", scene)
  }

  function onComplain(obj)
  {
    let pInfo = getSelectedPlayer()
    if (!pInfo || pInfo.isBot || pInfo.isLocal)
      return

    ::gui_modal_complain(pInfo)
  }

  function updateListsButtons()
  {
    refreshPlayerInfo()
  }

  function onStatTblFocus(obj)
  {
    if (::show_console_buttons && !obj.isHovered())
      obj.setValue(-1)
  }

  function getSelectedPlayer()
  {
    local value = scene.findObject("table_kills_team1")?.getValue() ?? -1
    if (value >= 0)
      return tblSave1?[value]
    value = scene.findObject("table_kills_team2")?.getValue() ?? -1
    return tblSave2?[value]
  }

  function getSelectedTable()
  {
    let objTbl1 = scene.findObject("table_kills_team1")
    if (objTbl1.getValue() >= 0)
      return objTbl1
    let objTbl2 = scene.findObject("table_kills_team2")
    if (objTbl2.getValue() >= 0)
      return objTbl2
    return null
  }

  function onStatsTblSelect(obj)
  {
    if (!needPlayersTbl)
      return
    if (obj.getValue() >= 0) {
      let table_name = obj.id == "table_kills_team2" ? "table_kills_team1" : "table_kills_team2"
      let tblObj = scene.findObject(table_name)
      tblObj.setValue(-1)
    }
    updateListsButtons()
  }

  function selectLocalPlayer()
  {
    if (!needPlayersTbl)
      return false
    foreach (tblIdx, tbl in [ tblSave1, tblSave2 ])
      if (tbl)
        foreach(playerIdx, player in tbl)
          if (::getTblValue("isLocal", player, false))
            return selectPlayerByIndexes(tblIdx, playerIdx)
    return false
  }

  function selectPlayerByIndexes(tblIdx, playerIdx)
  {
    if (!needPlayersTbl)
      return false
    let selectedObj = getSelectedTable()
    if (selectedObj)
      selectedObj.setValue(-1)

    let tblObj = scene.findObject("table_kills_team" + (tblIdx + 1))
    if (!::check_obj(tblObj) || tblObj.childrenCount() <= playerIdx)
      return false

    tblObj.setValue(playerIdx)
    setMousePointerInitialPosOnChildByValue(tblObj)
    updateListsButtons()
    return true
  }

  function includeMissionInfoBlocksToGamercard(fill = true)
  {
    if (!::checkObj(scene))
      return

    let blockSample = "textareaNoTab{id:t='%s'; %s overlayTextColor:t='premiumNotEarned'; textShade:t='yes'; text:t='';}"
    let leftBlockObj = scene.findObject("mission_texts_block_left")
    if (::checkObj(leftBlockObj))
    {
      local data = ""
      if (fill)
        foreach(id in ["gc_time_end", "gc_score_limit", "gc_time_to_kick"])
          data += ::format(blockSample, id, "")
      guiScene.replaceContentFromText(leftBlockObj, data, data.len(), this)
    }

    let rightBlockObj = scene.findObject("mission_texts_block_right")
    if (::checkObj(rightBlockObj))
    {
      local data = ""
      if (fill)
        foreach(id in ["gc_spawn_score", "gc_wp_respawn_balance", "gc_race_checkpoints", "gc_mp_tickets_rounds"])
          data += ::format(blockSample, id, "pos:t='pw-w, 0'; position:t='relative';")
      guiScene.replaceContentFromText(rightBlockObj, data, data.len(), this)
    }
  }

  /**
   * Sets country flag visibility for both
   * teams based on players' countries and units.
   */
  function updateCountryFlags()
  {
    let playerTeam = getLocalTeam()
    if (!needPlayersTbl || playerTeam <= 0)
      return
    let teamObj1 = scene.findObject("team1_info")
    let teamObj2 = scene.findObject("team2_info")
    local countries
    local teamIco

    if (::checkObj(teamObj1))
    {
      let teamOverrideCountryIcon = getOverrideCountryIconByTeam(playerTeam)
      countries = isTeamsWithCountryFlags && !teamOverrideCountryIcon
        ? getCountriesByTeam(playerTeam)
        : []
      if (isTeamsWithCountryFlags)
        teamIco = null
      else
        teamIco = isTeamsRandom ? "allies"
          : playerTeam == Team.A ? "allies" : "axis"
      setTeamInfoTeamIco(teamObj1, teamIco)
      setTeamInfoCountries(teamObj1, countries)
      updateOverrideCountry(teamObj1, teamOverrideCountryIcon)
    }
    if (!showLocalTeamOnly && ::checkObj(teamObj2))
    {
      let opponentTeam = playerTeam == Team.A ? Team.B : Team.A
      let teamOverrideCountryIcon = getOverrideCountryIconByTeam(opponentTeam)
      countries = isTeamsWithCountryFlags && !teamOverrideCountryIcon
        ? getCountriesByTeam(opponentTeam)
        : []
      if (isTeamsWithCountryFlags)
        teamIco = null
      else
        teamIco = isTeamsRandom ? "axis"
          : playerTeam == Team.A ? "axis" : "allies"
      setTeamInfoTeamIco(teamObj2, teamIco)
      setTeamInfoCountries(teamObj2, countries)
      updateOverrideCountry(teamObj2, teamOverrideCountryIcon)
    }
  }

  /**
   * Returns country names list based of players' settings.
   */
  function getCountriesByTeam(team)
  {
    let countries = []
    let players = getMplayersList(team)
    foreach (player in players)
    {
      local country = ::getTblValue("country", player, null)

      // If player/bot has random country we'll
      // try to retrieve country from selected unit.
      // Before spawn bots has wrong unit names.
      if (country == "country_0" && (!player.isDead || player.deaths > 0))
      {
        let unitName = ::getTblValue("aircraftName", player, null)
        let unit = ::getAircraftByName(unitName)
        if (unit != null)
          country = ::getUnitCountry(unit)
      }
      ::u.appendOnce(country, countries, true)
    }
    return countries
  }

  function getEndTimeObj()
  {
    return scene.findObject("gc_time_end")
  }

  function getScoreLimitObj()
  {
    return scene.findObject("gc_score_limit")
  }

  function getTimeToKickObj()
  {
    return scene.findObject("gc_time_to_kick")
  }

  function setGameEndStat(timeLeft)
  {
    let gameEndsObj = getEndTimeObj()
    let scoreLimitTextObj = getScoreLimitObj()

    if (!(gameType & ::GT_VERSUS))
    {
      foreach(obj in [gameEndsObj, scoreLimitTextObj])
        if (::checkObj(obj))
          obj.setValue("")
      return
    }

    if (::get_mp_rounds())
    {
      let rl = ::get_mp_zone_countdown()
      if (rl > 0)
        timeLeft = rl
    }

    if (timeLeft < 0 || (gameType & ::GT_RACE))
    {
      if (!::checkObj(gameEndsObj))
        return

      let val = gameEndsObj.getValue()
      if (typeof val == "string" && val.len() > 0)
        gameEndsObj.setValue("")
    }
    else
    {
      if (::checkObj(gameEndsObj))
        gameEndsObj.setValue(::getCompoundedText(::loc("multiplayer/timeLeft") + ::loc("ui/colon"),
                                                 time.secondsToString(timeLeft, false),
                                                 "activeTextColor"))

      let mp_ffa_score_limit = ::get_mp_ffa_score_limit()
      if (!isTeamplay && mp_ffa_score_limit && ::checkObj(scoreLimitTextObj))
        scoreLimitTextObj.setValue(::getCompoundedText(::loc("options/scoreLimit") + ::loc("ui/colon"),
                                   mp_ffa_score_limit,
                                   "activeTextColor"))
    }
  }

  function updateNumMaxPlayers(shouldHideRows = false)
  {
     local tblObj1 = scene.findObject("table_kills_team1")
     if (!::checkObj(tblObj1))
       return

     let curValue = numMaxPlayers
     numMaxPlayers = ::ceil(tblObj1.getParent().getSize()[1]/(::to_pixels("1@rows16height") || 1)).tointeger()
     if (!shouldHideRows || curValue <= numMaxPlayers)
       return

     hideTableRows(tblObj1, numMaxPlayers, curValue)
     tblObj1 = scene.findObject("table_kills_team2")
     if (!::checkObj(tblObj1))
       return
     hideTableRows(tblObj1, numMaxPlayers, curValue)
  }

  function hideTableRows(tblObj, minRow, maxRow)
  {
    let count = tblObj.childrenCount()
    for (local i = minRow; i < maxRow; i++)
    {
      if (count <= i)
        return

      tblObj.getChild(i).show(false)
    }

  }

  function getChatLog()
  {
    return mpChatModel.getLogForBanhammer()
  }

  getLocalTeam = @() ::get_local_team_for_mpstats()
  getMplayersList = @(team) ::get_mplayers_list(team, true)
  getOverrideCountryIconByTeam = @(team)
    ::g_mis_custom_state.getCurMissionRules().getOverrideCountryIconByTeam(team)
}

::gui_handlers.MPStatistics <- MPStatistics
