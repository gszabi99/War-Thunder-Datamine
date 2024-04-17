//-file:plus-string
from "%scripts/dagui_natives.nut" import get_race_checkpioints_count, get_player_army_for_hud, is_race_started, get_race_winners_count, get_mp_ffa_score_limit, mpstat_get_sort_func, get_multiplayer_time_left
from "%scripts/dagui_library.nut" import *
from "%scripts/teamsConsts.nut" import Team
from "%scripts/wndLib/wndConsts.nut" import RCLICK_MENU_ORIENT

let { g_team } = require("%scripts/teams.nut")
let { g_mission_type } = require("%scripts/missions/missionType.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { ceil } = require("math")
let { get_time_msec } = require("dagor.time")
let { format } = require("string")
let time = require("%scripts/time.nut")
let mpChatModel = require("%scripts/chat/mpChatModel.nut")
let avatars = require("%scripts/user/avatars.nut")
let { setMousePointerInitialPosOnChildByValue } = require("%scripts/controls/mousePointerInitialPos.nut")
let { MISSION_OBJECTIVE } = require("%scripts/missions/missionsUtilsModule.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { updateListLabelsSquad, isShowSquad } = require("%scripts/statistics/squadIcon.nut")
let { getMplayersList } = require("%scripts/statistics/mplayersList.nut")
let { is_replay_playing } = require("replays")
let { get_game_mode, get_game_type } = require("mission")
let { get_mission_difficulty_int, get_mp_tbl_teams } = require("guiMission")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { OPTIONS_MODE_GAMEPLAY, USEROPT_ORDER_AUTO_ACTIVATE
} = require("%scripts/options/optionsExtNames.nut")
let { getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")
let { getUnitCountry } = require("%scripts/unit/unitInfo.nut")
let { isInSessionRoom } = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { getSkillBonusTooltipText, get_time_to_kick_show_timer, get_time_to_kick_show_alert } = require("%scripts/statistics/mpStatisticsUtil.nut")
let { getEventEconomicName } = require("%scripts/events/eventInfo.nut")
let { setMissionEnviroment } = require("%scripts/missions/missionsUtils.nut")
let { is_low_width_screen } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getCurMissionRules } = require("%scripts/misCustomRules/missionCustomState.nut")
let { openOrdersInventory, updateActiveOrder, orderCanBeActivated,
  getActivateButtonLabel, activateSoonExpiredOrder
} = require("%scripts/items/orders.nut")

const OVERRIDE_COUNTRY_ID = "override_country"

local MPStatistics = class (gui_handlers.BaseGuiHandlerWT) {
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
  tblSave2 = null

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
  footballRowHeaders        = ["name", "footballScore", "footballGoals", "footballSaves", "footballAssists"]

  statTrSize = "pw, 1@baseTrHeight"

  function onActivateOrder() {
    openOrdersInventory()
  }

  function updateTimeToKick(dt) {
    this.updateTimeToKickTimer()
    this.updateTimeToKickAlert(dt)
  }

  function updateTimeToKickTimer() {
    let timeToKickObj = this.getTimeToKickObj()
    if (!checkObj(timeToKickObj))
      return
    let timeToKickValue = ::get_mp_kick_countdown()
    // Already in battle or it's too early to show the message.
    if (timeToKickValue <= 0 || get_time_to_kick_show_timer() < timeToKickValue)
      timeToKickObj.setValue("")
    else {
      let timeToKickText = time.secondsToString(timeToKickValue, true, true)
      let locParams = {
        timeToKick = colorize("activeTextColor", timeToKickText)
      }
      timeToKickObj.setValue(loc("respawn/timeToKick", locParams))
    }
  }

  function updateTimeToKickAlert(dt) {
    let timeToKickAlertObj = this.scene.findObject("time_to_kick_alert_text")
    if (!checkObj(timeToKickAlertObj))
      return
    let timeToKickValue = ::get_mp_kick_countdown()
    if (timeToKickValue <= 0 || get_time_to_kick_show_alert() < timeToKickValue || this.isSpectate)
      timeToKickAlertObj.show(false)
    else {
      timeToKickAlertObj.show(true)
      let curTime = get_time_msec()
      let prevSeconds = ((curTime - 1000 * dt) / 1000).tointeger()
      let currSeconds = (curTime / 1000).tointeger()
      if (currSeconds != prevSeconds) {
        timeToKickAlertObj["_blink"] = "yes"
        this.guiScene.playSound("kick_alert")
      }
    }
  }

  function onOrderTimerUpdate(obj, _dt) {
    updateActiveOrder()
    let isOrderCanBeActivated = orderCanBeActivated()
    if (checkObj(obj)) {
      obj.text = getActivateButtonLabel()
      obj.inactiveColor = !isOrderCanBeActivated ? "yes" : "no"
    }
    if (isOrderCanBeActivated
      && ::get_option_in_mode(USEROPT_ORDER_AUTO_ACTIVATE, OPTIONS_MODE_GAMEPLAY).value)
        activateSoonExpiredOrder()
  }

  function setTeamInfoTeam(teamObj, team) {
    if (!checkObj(teamObj))
      return
    teamObj.team = team
  }

  function setTeamInfoTeamIco(teamObj, teamIco = null) {
    if (!checkObj(teamObj))
      return
    let teamImgObj = teamObj.findObject("team_img")
    if (checkObj(teamImgObj))
      teamImgObj.show(teamIco != null)
    if (teamIco != null)
      teamObj.teamIco = teamIco
  }

  function setTeamInfoText(teamObj, text) {
    if (!checkObj(teamObj))
      return
    let textObj = teamObj.findObject("team_text")
    if (checkObj(textObj))
      textObj.setValue(text)
  }

  /**
   * Sets country flags visibility based
   * on specified country names list.
   */
  function setTeamInfoCountries(teamObj, enabledCountryNames) {
    if (!checkObj(teamObj))
      return
    foreach (countryName in shopCountriesList) {
      let countryFlagObj = teamObj.findObject(countryName)
      if (checkObj(countryFlagObj))
        countryFlagObj.show(isInArray(countryName, enabledCountryNames))
    }
  }

  function updateOverrideCountry(teamObj, countryIcon) {
    if (!checkObj(teamObj))
      return

    let countryFlagObj = showObjById(OVERRIDE_COUNTRY_ID, countryIcon != null, teamObj)
    if (checkObj(countryFlagObj))
      countryFlagObj["background-image"] = getCountryIcon(countryIcon)
  }

  /**
   * Places all available country
   * flags into container.
   */
  function initTeamInfoCountries(teamObj) {
    if (!checkObj(teamObj))
      return
    let countriesBlock = teamObj.findObject("countries_block")
    if (!checkObj(countriesBlock))
      return
    let view = {
      countries = shopCountriesList
        .map(@(countryName) {
          countryName = countryName
          countryIcon = getCountryIcon(countryName)
        })
        .append({
          countryName = OVERRIDE_COUNTRY_ID
          countryIcon = ""
        })
    }
    let result = handyman.renderCached("%gui/countriesList.tpl", view)
    this.guiScene.replaceContentFromText(countriesBlock, result, result.len(), this)
  }

  function setInfo() {
    let timeLeft = get_multiplayer_time_left()
    if (timeLeft < 0) {
      this.setGameEndStat(-1)
      return
    }
    local timeDif = this.wasTimeLeft - timeLeft
    if (timeDif < 0)
      timeDif = -timeDif
    if (timeDif >= 1 || ((this.wasTimeLeft * timeLeft) < 0)) {
      this.setGameEndStat(timeLeft)
      this.wasTimeLeft = timeLeft
    }
  }

  function initScreen() {
    this.scene.findObject("stat_update").setUserData(this)
    this.needPlayersTbl = this.scene.findObject("table_kills_team1") != null

    this.includeMissionInfoBlocksToGamercard()
    this.setSceneTitle(::getCurMpTitle())
    this.setSceneMissionEnviroment()
    this.setInfo()
  }

  function initStats() {
    if (!checkObj(this.scene))
      return

    this.initStatsMissionParams()

    let playerTeam = this.getLocalTeam()
    let friendlyTeam = get_player_army_for_hud()
    let teamObj1 = this.scene.findObject("team1_info")
    let teamObj2 = this.scene.findObject("team2_info")

    if (!this.isTeamplay) {
      foreach (obj in [teamObj1, teamObj2])
        if (checkObj(obj))
          obj.show(false)
    }
    else if (this.needPlayersTbl && playerTeam > 0) {
      if (checkObj(teamObj1)) {
        this.setTeamInfoTeam(teamObj1, (playerTeam == friendlyTeam) ? "blue" : "red")
        this.initTeamInfoCountries(teamObj1)
      }
      if (!this.showLocalTeamOnly && checkObj(teamObj2)) {
        this.setTeamInfoTeam(teamObj2, (playerTeam == friendlyTeam) ? "red" : "blue")
        this.initTeamInfoCountries(teamObj2)
      }
    }

    if (this.needPlayersTbl) {
      this.createStats()
      this.scene.findObject("table_kills_team1").setValue(-1)
      this.scene.findObject("table_kills_team2").setValue(-1)
    }

    this.updateCountryFlags()
  }

  function initStatsMissionParams() {
    this.gameMode = get_game_mode()
    this.gameType = get_game_type()
    this.isOnline = ::g_login.isLoggedIn()

    this.isTeamplay = ::is_mode_with_teams(this.gameType)
    this.isTeamsRandom = !this.isTeamplay || this.gameMode == GM_DOMINATION
    if (isInSessionRoom.get() || is_replay_playing())
      this.isTeamsWithCountryFlags = this.isTeamplay &&
        (get_mission_difficulty_int() > 0 || !::SessionLobby.getPublicParam("symmetricTeams", true))

    this.missionObjectives = g_mission_type.getCurrentObjectives()
  }

  function createKillsTbl(objTbl, tbl, tblConfig) {
    let team = getTblValue("team", tblConfig, -1)
    let showUnits     = tblConfig?.showAircrafts ?? false
    let showAirIcons  = tblConfig?.showAirIcons  ?? showUnits
    let invert = getTblValue("invert", tblConfig, false)

    local tblData = [] // columns order

    let markupData = {
      tr_size = this.statTrSize
      invert = invert
      colorTeam = "blue"
      columns = {}
    }

    if (this.gameType & GT_COOPERATIVE) {
      tblData = showAirIcons ? [ "unitIcon", "name" ] : [ "name" ]
      foreach (id in tblData)
        markupData.columns[id] <- ::g_mplayer_param_type.getTypeById(id).getMarkupData()

      if ("name" in markupData.columns)
        markupData.columns["name"].width = "fw"
    }
    else {
      let sourceHeaders = this.gameType & GT_FOOTBALL ? this.footballRowHeaders
        : this.gameType & GT_RACE ? this.raceRowHeaders
        : this.defaultRowHeaders

      foreach (id in sourceHeaders)
        if (::g_mplayer_param_type.getTypeById(id).isVisible(this.missionObjectives, this.gameType, this.gameMode))
          tblData.append(id)

      if (!showUnits)
        u.removeFrom(tblData, "aircraft")
      if (!isShowSquad())
        u.removeFrom(tblData, "squad")

      foreach (name in tblData)
        markupData.columns[name] <- ::g_mplayer_param_type.getTypeById(name).getMarkupData()

      if ("name" in markupData.columns) {
        let col = markupData.columns["name"]
        if (this.isWideScreenStatTbl && ("widthInWideScreen" in col))
          col.width = col.widthInWideScreen
      }

      ::count_width_for_mptable(objTbl, markupData.columns)

      let teamNum = (team == 2) ? 2 : 1
      let tableObj = this.scene.findObject($"team_table_{teamNum}")
      if (team == 2)
        markupData.colorTeam = "red"
      if (checkObj(tableObj)) {
        let rowHeaderData = this.createHeaderRow(tableObj, tblData, markupData, teamNum)
        let show = rowHeaderData != ""
        this.guiScene.replaceContentFromText(tableObj, rowHeaderData, rowHeaderData.len(), this)
        tableObj.show(show)
        tableObj.normalFont = is_low_width_screen() ? "yes" : "no"
      }
    }

    if (team == -1 || team == 1)
      this.tblSave1 = tbl
    else
      this.tblSave2 = tbl

    if (tbl) {
      if (!this.isTeamplay)
        this.sortTable(tbl)

      let data = ::build_mp_table(tbl, markupData, tblData, 1, {canHasBonusIcon = true})
      this.guiScene.replaceContentFromText(objTbl, data, data.len(), this)
    }
  }

  function sortTable(table) {
    table.sort(mpstat_get_sort_func(this.gameType))
  }

  function onSkillBonusTooltip(obj) {
    let tooltipView = {
      tooltipComment = getSkillBonusTooltipText(this.getRoomEventEconomicName())
      commentMaxWidth = "@expSkillBonusCommentMaxWidth"
    }

    let markup = handyman.renderCached("%gui/debriefing/statRowTooltip.tpl", tooltipView)
    this.guiScene.replaceContentFromText(obj, markup, markup.len(), this)
  }

  function setKillsTbl(objTbl, team, playerTeam, friendlyTeam, showAirIcons = true, customTbl = null) {
    if (!checkObj(objTbl))
      return

    local tbl = null

    objTbl.smallFont = is_low_width_screen() ? "yes" : "no"

    if (customTbl) {
      let idx = max(team - 1, -1)
      if (idx in customTbl?.playersTbl)
        tbl = customTbl.playersTbl[idx]
    }

    local minRow = 0
    if (!tbl) {
      if (!this.isTeamplay) {
        let commonTbl = this.getMplayersList()
        this.sortTable(commonTbl)
        if (commonTbl.len() > 0) {
          local lastRow = this.numMaxPlayers - 1
          if (objTbl.id == "table_kills_team2") {
            minRow = this.numMaxPlayers
            lastRow = commonTbl.len() - 1
          }

          tbl = []
          for (local i = minRow; i <= lastRow; i++) {
            if (i not in commonTbl)
              break

            let block = commonTbl[i]
            block.place <- (i + 1).tostring()
            tbl.append(block)
          }
        }
      }
      else
        tbl = this.getMplayersList(team)
    }
    else if (!this.isTeamplay && customTbl && objTbl.id == "table_kills_team2")
      minRow = this.numMaxPlayers

    if (objTbl.id == "table_kills_team2")
      showObjById("team2-root", tbl && tbl.len() > 0, this.scene)

    if (!this.isTeamplay && minRow >= 0) {
      if (minRow == 0)
        this.tblSave1 = tbl
      else
        this.tblSave2 = tbl
    }
    else {
      if (team == playerTeam || playerTeam == -1 || this.showLocalTeamOnly)
        this.tblSave1 = tbl
      else
        this.tblSave2 = tbl
    }

    if (tbl != null) {
      if (!customTbl && this.isTeamplay)
        this.sortTable(tbl)

      ::set_mp_table(objTbl, tbl, {
        showAirIcons
        handler = this
        continueRowNum = minRow
        canHasBonusIcon = true
        numberOfWinningPlaces = this.numberOfWinningPlaces
        playersInfo = customTbl?.playersInfo
        roomEventName = this.getRoomEventEconomicName()
      })
      ::update_team_css_label(objTbl, this.getLocalTeam())

      if (friendlyTeam > 0 && team > 0)
        objTbl["team"] = (this.isTeamplay && friendlyTeam == team) ? "blue" : "red"
    }
    this.updateCountryFlags()
  }

  function getRoomEventEconomicName() {
    if ( this?.debriefingResult.roomEvent ) {
      return getEventEconomicName(this?.debriefingResult.roomEvent)
    } else if (::SessionLobby.getRoomEvent()) {
      return getEventEconomicName(::SessionLobby.getRoomEvent())
    }
    return null
  }

  function isShowEnemyAirs() {
    return this.showAircrafts && get_mission_difficulty_int() == 0
  }

  function createStats() {
    if (!this.needPlayersTbl)
      return

    let tblObj1 = this.scene.findObject("table_kills_team1")
    let tblObj2 = this.scene.findObject("table_kills_team2")
    let team1Root = this.scene.findObject("team1-root")
    this.updateNumMaxPlayers()

    if (!this.isTeamplay) {
      let tbl1 = this.getMplayersList()
      this.sortTable(tbl1)

      let tbl2 = []
      if (tbl1.len() >= this.numMaxPlayers) {
        for (local i = tbl1.len() - 1; i >= this.numMaxPlayers; --i) {
          if (!(i in tbl1))
            continue

          let block = tbl1.remove(i)
          block.place <- (i + 1).tostring()
          tbl2.append(block)
        }
        tbl2.reverse()
      }

      this.createKillsTbl(tblObj1, tbl1, { team = Team.A, showAircrafts = this.showAircrafts })
      this.createKillsTbl(tblObj2, tbl2, { team = Team.B, showAircrafts = this.showAircrafts })

      if (checkObj(team1Root))
        team1Root.show(true)
    }
    else if (this.gameType & GT_VERSUS) {
      if (this.showLocalTeamOnly) {
        let playerTeam = this.getLocalTeam()
        let tbl = this.getMplayersList(playerTeam)
        this.createKillsTbl(tblObj1, tbl, { showAircrafts = this.showAircrafts })
      }
      else {
        let tbl1 = this.getMplayersList(g_team.A.code)
        let tbl2 = this.getMplayersList(g_team.B.code)
        let showEnemyAircrafts = this.isShowEnemyAirs()
        let tblConfig1 = { tbl = tbl2, team = Team.A, showAircrafts = this.showAircrafts, invert = true }
        let tblConfig2 = { tbl = tbl1, team = Team.B, showAircrafts = showEnemyAircrafts }

        if (this.getLocalTeam() == Team.A) {
          tblConfig1.tbl = tbl1
          tblConfig2.tbl = tbl2
        }

        this.createKillsTbl(tblObj1, tblConfig1.tbl, tblConfig1)
        this.createKillsTbl(tblObj2, tblConfig2.tbl, tblConfig2)

        if (checkObj(team1Root))
          team1Root.show(true)
      }
    }
    else {
      let tbl = this.getMplayersList()
      this.createKillsTbl(tblObj2, tbl, { showAircrafts = this.showAircrafts })

      tblObj1.show(false)

      if (checkObj(team1Root))
        team1Root.show(false)

      let headerObj = this.scene.findObject("team2_header")
      if (checkObj(headerObj))
        headerObj.show(false)
    }
  }

  function updateTeams(tbl, playerTeam, friendlyTeam) {
    if (!tbl)
      return

    let teamObj1 = this.scene.findObject("team1_info")
    let teamObj2 = this.scene.findObject("team2_info")

    let playerTeamIdx = clamp(playerTeam - 1, 0, 1)
    let teamTxt = ["", ""]

    let scoreType = this.gameType & (GT_MP_SCORE | GT_MP_TICKETS)
    if (scoreType == GT_MP_SCORE) {
      if (!this.needPlayersTbl)
        return

      let scoreFormat = "%s" + loc("multiplayer/score") + loc("ui/colon") + "%d"
      if (tbl.len() > playerTeamIdx) {
        this.setTeamInfoText(teamObj1, format(scoreFormat, teamTxt[0], tbl[playerTeamIdx].score))
        this.setTeamInfoTeam(teamObj1, (playerTeam == friendlyTeam) ? "blue" : "red")
      }
      if (tbl.len() > 1 - playerTeamIdx && !this.showLocalTeamOnly) {
        this.setTeamInfoText(teamObj2, format(scoreFormat, teamTxt[1], tbl[1 - playerTeamIdx].score))
        this.setTeamInfoTeam(teamObj2, (playerTeam == friendlyTeam) ? "red" : "blue")
      }
      return
    }

    if (scoreType == GT_MP_TICKETS) {
      if (this.needPlayersTbl) {
        let scoreformat = "%s" + loc("multiplayer/tickets") + loc("ui/colon") + "%d" + ", " +
          loc("multiplayer/airfields") + loc("ui/colon") + "%d"

        if (tbl.len() > playerTeamIdx) {
          this.setTeamInfoText(teamObj1, format(scoreformat, teamTxt[0], tbl[playerTeamIdx].tickets, tbl[playerTeamIdx].score))
          this.setTeamInfoTeam(teamObj1, (playerTeam == friendlyTeam) ? "blue" : "red")
        }
        if (tbl.len() > 1 - playerTeamIdx && !this.showLocalTeamOnly) {
          this.setTeamInfoText(teamObj2, format(scoreformat, teamTxt[1], tbl[1 - playerTeamIdx].tickets, tbl[1 - playerTeamIdx].score))
          this.setTeamInfoTeam(teamObj2, (playerTeam == friendlyTeam) ? "red" : "blue")
        }
      }
    }
  }

  function updateStats(customTbl = null, customTblTeams = null, customFriendlyTeam = null) {
    local playerTeam   = this.getLocalTeam()
    let friendlyTeam = customFriendlyTeam ?? get_player_army_for_hud()
    let tblObj1 = this.scene.findObject("table_kills_team1")
    let tblObj2 = this.scene.findObject("table_kills_team2")

    if (this.needPlayersTbl) {
      if (!this.isTeamplay || (this.gameType & GT_VERSUS)) {
        if (!this.isTeamplay)
          playerTeam = Team.A

        let showEnemyAirs = this.isShowEnemyAirs()
        let isLeftPlayerTeam = playerTeam == friendlyTeam
        this.setKillsTbl(tblObj1, playerTeam, playerTeam, friendlyTeam, // warning disable: -param-pos
          isLeftPlayerTeam ? this.showAircrafts : showEnemyAirs, customTbl)
        if (!this.showLocalTeamOnly && playerTeam > 0)
          this.setKillsTbl(tblObj2, 3 - playerTeam, playerTeam, friendlyTeam,
            isLeftPlayerTeam ? showEnemyAirs : this.showAircrafts, customTbl)
      }
      else
        this.setKillsTbl(tblObj2, -1, -1, -1, this.showAircrafts, customTbl)
    }

    if (playerTeam > 0)
      this.updateTeams(customTblTeams || get_mp_tbl_teams(), playerTeam, friendlyTeam)

    if (this.checkRaceDataOnStart && is_race_started()) {
      let chObj = this.scene.findObject("gc_race_checkpoints")
      if (checkObj(chObj)) {
        let totalCheckpointsAmount = get_race_checkpioints_count()
        local text = ""
        if (totalCheckpointsAmount > 0)
          text = ::getCompoundedText(loc("multiplayer/totalCheckpoints") + loc("ui/colon"), totalCheckpointsAmount, "activeTextColor")
        chObj.setValue(text)
        this.checkRaceDataOnStart = false
      }

      this.numberOfWinningPlaces = get_race_winners_count()
    }

    ::update_team_css_label(this.scene.findObject("num_teams"), playerTeam)
  }

  function updateTables(dt) {
    this.updateCooldown -= dt
    if (this.updateCooldown <= 0) {
      this.updateStats()
      this.updateCooldown = 3
    }

    if (this.isStatScreen || !this.needPlayersTbl)
      return

    if (this.isRespawn) {
      let selectedObj = this.getSelectedTable()
      if (!this.isModeStat) {
        let objTbl1 = this.scene.findObject("table_kills_team1")
        let curRow = objTbl1.getValue()
        if (curRow < 0 || curRow >= objTbl1.childrenCount())
          objTbl1.setValue(0)
      }
      else if (selectedObj == null) {
          this.scene.findObject("table_kills_team1").setValue(0)
          this.updateListsButtons()
      }
    }
    else {
      this.scene.findObject("table_kills_team1").setValue(-1)
      this.scene.findObject("table_kills_team2").setValue(-1)
    }
  }

  function createHeaderRow(tableObj, hdr, markupData, teamNum) {
    if (!markupData
        || type(markupData) != "table"
        || !("columns" in markupData)
        || !markupData.columns.len()
        || !checkObj(tableObj))
      return ""

    let tblData = clone hdr

    if (getTblValue("invert", markupData, false))
      tblData.reverse()

    let view = { cells = [] }
    foreach (name in tblData) {
      let value = markupData.columns?[name]
      if (!value || type(value) != "table")
        continue

      view.cells.append({
        id = getTblValue("id", value, name)
        fontIcon = getTblValue("fontIcon", value, null)
        tooltip = getTblValue("tooltip", value, null)
        width = getTblValue("width", value, "")
      })
    }

    let tdData = handyman.renderCached(("%gui/statistics/statTableHeaderCell.tpl"), view)
    let trId = "team-header" + teamNum
    let trSize = getTblValue("tr_size", markupData, "0,0")
    let trData = format("tr{id:t='%s'; size:t='%s'; %s}", trId, trSize, tdData)
    return trData
  }

  function goBack(_obj) {}

  function onUserCard(_obj) {
    let player = this.getSelectedPlayer();
    if (!player || player.isBot || !this.isOnline)
      return;

    ::gui_modal_userCard({ uid = player.userId });
  }

  function onUserRClick(obj) {
    this.onStatsTblSelect(obj)
    ::session_player_rmenu(this, this.getSelectedPlayer(), this.getChatLog())
  }

  function onUserOptions(_obj) {
    let selectedTableObj = this.getSelectedTable()
    if (!checkObj(selectedTableObj))
      return

    this.onStatsTblSelect(selectedTableObj)
    let selectedPlayer = this.getSelectedPlayer()
    let orientation = selectedTableObj.id == "table_kills_team1" ? RCLICK_MENU_ORIENT.RIGHT : RCLICK_MENU_ORIENT.LEFT
    ::session_player_rmenu(this, selectedPlayer, this.getChatLog(), this.getSelectedRowPos(selectedTableObj, orientation), orientation)
  }

  function getSelectedRowPos(selectedTableObj, orientation) {
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

  function getPlayerInfo(name) {
    if (name && name != "")
      foreach (tbl in [this.tblSave1, this.tblSave2])
        if (tbl)
          foreach (player in tbl)
            if (player.name == name)
              return player
    return null
  }

  function refreshPlayerInfo() {
    this.setPlayerInfo()

    let player = this.getSelectedPlayer()
    showObjById("btn_user_options", this.isOnline && player && !player.isBot && !this.isSpectate && showConsoleButtons.value, this.scene)
    updateListLabelsSquad()
  }

  function setPlayerInfo() {
    let playerInfo = this.getSelectedPlayer()
    let teamObj = this.scene.findObject("player_team")
    if (this.isTeam && checkObj(teamObj)) {
      local teamTxt = ""
      let team = playerInfo ? playerInfo.team : Team.Any
      if (team == Team.A)
        teamTxt = loc("multiplayer/teamA")
      else if (team == Team.B)
        teamTxt = loc("multiplayer/teamB")
      else
        teamTxt = loc("multiplayer/teamRandom")
      teamObj.setValue(loc("multiplayer/team") + loc("ui/colon") + teamTxt)
    }

    ::fill_gamer_card({
                      name = playerInfo ? playerInfo.name : ""
                      clanTag = playerInfo ? playerInfo.clanTag : ""
                      icon = (!playerInfo || playerInfo.isBot) ? "cardicon_bot" : avatars.getIconById(playerInfo.pilotId)
                      country = playerInfo ? playerInfo.country : ""
                    },
                    "player_", this.scene)
  }

  function onComplain(_obj) {
    let pInfo = this.getSelectedPlayer()
    if (!pInfo || pInfo.isBot || pInfo.isLocal)
      return

    ::gui_modal_complain(pInfo)
  }

  function updateListsButtons() {
    this.refreshPlayerInfo()
  }

  function onStatTblFocus(obj) {
    if (showConsoleButtons.value && !obj.isHovered())
      obj.setValue(-1)
  }

  function getSelectedPlayer() {
    local value = this.scene.findObject("table_kills_team1")?.getValue() ?? -1
    if (value >= 0)
      return this.tblSave1?[value]
    value = this.scene.findObject("table_kills_team2")?.getValue() ?? -1
    return this.tblSave2?[value]
  }

  function getSelectedTable() {
    let objTbl1 = this.scene.findObject("table_kills_team1")
    if (objTbl1.getValue() >= 0)
      return objTbl1
    let objTbl2 = this.scene.findObject("table_kills_team2")
    if (objTbl2.getValue() >= 0)
      return objTbl2
    return null
  }

  function onStatsTblSelect(obj) {
    if (!this.needPlayersTbl)
      return
    if (obj.getValue() >= 0) {
      let table_name = obj.id == "table_kills_team2" ? "table_kills_team1" : "table_kills_team2"
      let tblObj = this.scene.findObject(table_name)
      tblObj.setValue(-1)
    }
    this.updateListsButtons()
  }

  function selectLocalPlayer() {
    if (!this.needPlayersTbl)
      return false
    foreach (tblIdx, tbl in [ this.tblSave1, this.tblSave2 ])
      if (tbl)
        foreach (playerIdx, player in tbl)
          if (getTblValue("isLocal", player, false))
            return this.selectPlayerByIndexes(tblIdx, playerIdx)
    return false
  }

  function selectPlayerByIndexes(tblIdx, playerIdx) {
    if (!this.needPlayersTbl)
      return false
    let selectedObj = this.getSelectedTable()
    if (selectedObj)
      selectedObj.setValue(-1)

    let tblObj = this.scene.findObject("table_kills_team" + (tblIdx + 1))
    if (!checkObj(tblObj) || tblObj.childrenCount() <= playerIdx)
      return false

    tblObj.setValue(playerIdx)
    setMousePointerInitialPosOnChildByValue(tblObj)
    this.updateListsButtons()
    return true
  }

  function includeMissionInfoBlocksToGamercard(fill = true) {
    if (!checkObj(this.scene))
      return

    let blockSample = "textareaNoTab{id:t='%s'; %s overlayTextColor:t='premiumNotEarned'; textShade:t='yes'; text:t='';}"
    let leftBlockObj = this.scene.findObject("mission_texts_block_left")
    if (checkObj(leftBlockObj)) {
      local data = ""
      if (fill)
        foreach (id in ["mission_environment", "gc_time_end", "gc_score_limit", "gc_time_to_kick"])
          data += format(blockSample, id, "")
      this.guiScene.replaceContentFromText(leftBlockObj, data, data.len(), this)
    }

    let rightBlockObj = this.scene.findObject("mission_texts_block_right")
    if (checkObj(rightBlockObj)) {
      local data = ""
      if (fill)
        foreach (id in ["gc_spawn_score", "gc_wp_respawn_balance", "gc_race_checkpoints", "gc_mp_tickets_rounds"])
          data += format(blockSample, id, "pos:t='pw-w, 0'; position:t='relative';")
      this.guiScene.replaceContentFromText(rightBlockObj, data, data.len(), this)
    }
  }

  /**
   * Sets country flag visibility for both
   * teams based on players' countries and units.
   */
  function updateCountryFlags() {
    let playerTeam = this.getLocalTeam()
    if (!this.needPlayersTbl || playerTeam <= 0)
      return
    let teamObj1 = this.scene.findObject("team1_info")
    let teamObj2 = this.scene.findObject("team2_info")
    local countries
    local teamIco

    if (checkObj(teamObj1)) {
      let teamOverrideCountryIcon = this.getOverrideCountryIconByTeam(playerTeam)
      countries = this.isTeamsWithCountryFlags && !teamOverrideCountryIcon
        ? this.getCountriesByTeam(playerTeam)
        : []
      if (this.isTeamsWithCountryFlags)
        teamIco = null
      else
        teamIco = this.isTeamsRandom ? "allies"
          : playerTeam == Team.A ? "allies" : "axis"
      this.setTeamInfoTeamIco(teamObj1, teamIco)
      this.setTeamInfoCountries(teamObj1, countries)
      this.updateOverrideCountry(teamObj1, teamOverrideCountryIcon)
    }
    if (!this.showLocalTeamOnly && checkObj(teamObj2)) {
      let opponentTeam = playerTeam == Team.A ? Team.B : Team.A
      let teamOverrideCountryIcon = this.getOverrideCountryIconByTeam(opponentTeam)
      countries = this.isTeamsWithCountryFlags && !teamOverrideCountryIcon
        ? this.getCountriesByTeam(opponentTeam)
        : []
      if (this.isTeamsWithCountryFlags)
        teamIco = null
      else
        teamIco = this.isTeamsRandom ? "axis"
          : playerTeam == Team.A ? "axis" : "allies"
      this.setTeamInfoTeamIco(teamObj2, teamIco)
      this.setTeamInfoCountries(teamObj2, countries)
      this.updateOverrideCountry(teamObj2, teamOverrideCountryIcon)
    }
  }

  /**
   * Returns country names list based of players' settings.
   */
  function getCountriesByTeam(team) {
    let countries = []
    let players = this.getMplayersList(team)
    foreach (player in players) {
      local country = getTblValue("country", player, null)

      // If player/bot has random country we'll
      // try to retrieve country from selected unit.
      // Before spawn bots has wrong unit names.
      if (country == "country_0" && (!player.isDead || player.deaths > 0)) {
        let unitName = getTblValue("aircraftName", player, null)
        let unit = getAircraftByName(unitName)
        if (unit != null)
          country = getUnitCountry(unit)
      }
      u.appendOnce(country, countries, true)
    }
    return countries
  }

  function getEndTimeObj() {
    return this.scene.findObject("gc_time_end")
  }

  function getScoreLimitObj() {
    return this.scene.findObject("gc_score_limit")
  }

  function getTimeToKickObj() {
    return this.scene.findObject("gc_time_to_kick")
  }

  function setGameEndStat(timeLeft) {
    let gameEndsObj = this.getEndTimeObj()
    let scoreLimitTextObj = this.getScoreLimitObj()

    if (!(this.gameType & GT_VERSUS)) {
      foreach (obj in [gameEndsObj, scoreLimitTextObj])
        if (checkObj(obj))
          obj.setValue("")
      return
    }

    if (timeLeft < 0 || (this.gameType & GT_RACE)) {
      if (!checkObj(gameEndsObj))
        return

      let val = gameEndsObj.getValue()
      if (type(val) == "string" && val.len() > 0)
        gameEndsObj.setValue("")
    }
    else {
      if (checkObj(gameEndsObj))
        gameEndsObj.setValue(::getCompoundedText(loc("multiplayer/timeLeft") + loc("ui/colon"),
                                                 time.secondsToString(timeLeft, false),
                                                 "activeTextColor"))

      let mp_ffa_score_limit = get_mp_ffa_score_limit()
      if (!this.isTeamplay && mp_ffa_score_limit && checkObj(scoreLimitTextObj))
        scoreLimitTextObj.setValue(::getCompoundedText(loc("options/scoreLimit") + loc("ui/colon"),
                                   mp_ffa_score_limit,
                                   "activeTextColor"))
    }
  }

  function updateNumMaxPlayers(shouldHideRows = false) {
     local tblObj1 = this.scene.findObject("table_kills_team1")
     if (!checkObj(tblObj1))
       return

     let curValue = this.numMaxPlayers
     this.numMaxPlayers = ceil(tblObj1.getParent().getSize()[1] / (to_pixels("1@rows16height") || 1)).tointeger()
     if (!shouldHideRows || curValue <= this.numMaxPlayers)
       return

     this.hideTableRows(tblObj1, this.numMaxPlayers, curValue)
     tblObj1 = this.scene.findObject("table_kills_team2")
     if (!checkObj(tblObj1))
       return
     this.hideTableRows(tblObj1, this.numMaxPlayers, curValue)
  }

  function hideTableRows(tblObj, minRow, maxRow) {
    let count = tblObj.childrenCount()
    for (local i = minRow; i < maxRow; i++) {
      if (count <= i)
        return

      tblObj.getChild(i).show(false)
    }
  }

  function getChatLog() {
    return mpChatModel.getLogForBanhammer()
  }

  getLocalTeam = @() ::get_local_team_for_mpstats()
  getOverrideCountryIconByTeam = @(team)
    getCurMissionRules().getOverrideCountryIconByTeam(team)
  getMplayersList = @(t = GET_MPLAYERS_LIST) getMplayersList(t)

  setSceneMissionEnviroment = @() setMissionEnviroment(this.scene.findObject("mission_environment"))
}

gui_handlers.MPStatistics <- MPStatistics