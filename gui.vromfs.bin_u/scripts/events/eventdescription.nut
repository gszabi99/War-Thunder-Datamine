from "%scripts/dagui_library.nut" import *
from "%scripts/teamsConsts.nut" import Team
from "%scripts/events/eventsConsts.nut" import EVENT_TYPE, EVENTS_SHORT_LB_VISIBLE_ROWS
from "%scripts/mainConsts.nut" import HELP_CONTENT_SET
from "%scripts/utils_sa.nut" import buildTableRow

let { zero_money } = require("%scripts/money.nut")
let { g_mission_type } = require("%scripts/missions/missionType.nut")
let { g_team } = require("%scripts/teams.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let DataBlock = require("DataBlock")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { format } = require("string")
let SecondsUpdater = require("%sqDagui/timer/secondsUpdater.nut")
let time = require("%scripts/time.nut")
let { isPlatformXboxOne, isPlatformSony } = require("%scripts/clientState/platform.nut")
let { isLeaderboardsAvailable, isEventForClan, getMaxLobbyDisbalance
} = require("%scripts/events/eventInfo.nut")
let { haveRewards, getBaseVictoryReward } = require("%scripts/events/eventRewards.nut")
let { get_meta_mission_info_by_name } = require("guiMission")
let { setMapPreview } = require("%scripts/missions/mapPreview.nut")
let { USEROPT_TIME_LIMIT } = require("%scripts/options/optionsExtNames.nut")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let { getLbCategoryTypeByField } = require("%scripts/leaderboard/leaderboardCategoryType.nut")
let { getMroomInfo } = require("%scripts/matchingRooms/mRoomInfoManager.nut")
let { guiStartProfile } = require("%scripts/user/profileHandler.nut")
let { loadCustomCraftTree } = require("%scripts/items/workshop/workshopCraftTreeWnd.nut")
let { getSetById } = require("%scripts/items/workshop/workshop.nut")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let { getRoomSessionStartTime } = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { getSessionLobbyMissionNameLoc, getSessionLobbyTimeLimit,
  getRoomSpecialRules, getRoomRequiredCrafts, getMembersCountByTeams
} = require("%scripts/matchingRooms/sessionLobbyInfo.nut")
let { getSessionLobbyMissionName } = require("%scripts/missions/missionsUtilsModule.nut")
let { getMatchingServerTime } = require("%scripts/onlineInfo/onlineInfo.nut")
let { get_option } = require("%scripts/options/optionsExt.nut")
let { gui_modal_event_leaderboards } = require("%scripts/leaderboard/leaderboard.nut")
let { gui_modal_help } = require("%scripts/help/helpWnd.nut")
let { fillCountriesList } = require("%scripts/matchingRooms/fillCountriesList.nut")

function create_event_description(parent_scene, event = null, needEventHeader = true) {
  let containerObj = parent_scene.findObject("item_desc")
  if (!checkObj(containerObj))
    return null
  let params = {
    scene = containerObj
    selectedEvent = event
    needEventHeader = needEventHeader
  }
  local handler = handlersManager.loadHandler(gui_handlers.EventDescription, params)
  return handler
}

gui_handlers.EventDescription <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/empty.blk"

  selectedEvent = null
  room = null
  needEventHeader = true

  playersInTable = null
  currentFullRoomData = null

  
  newSelfRowRequest = null

  workshopSetHandler = null

  function initScreen() {
    this.playersInTable = []
    let blk = handyman.renderCached("%gui/events/eventDescription.tpl", {})
    this.guiScene.replaceContentFromText(this.scene, blk, blk.len(), this)
    this.updateContent()
  }

  function selectEvent(event, eventRoom = null) {
    if (this.room)
      getMroomInfo(this.room.roomId).checkRefresh()
    if (this.selectedEvent == event && u.isEqual(this.room, eventRoom))
      return

    this.selectedEvent = event
    this.room = eventRoom
    this.updateContent()
  }

  function updateContent() {
    if (!checkObj(this.scene))
      return

    this.guiScene.setUpdatesEnabled(false, false)
    this._updateContent()
    this.guiScene.setUpdatesEnabled(true, true)
  }

  function updateBottomDesc(roomMGM) {
    
    local teamObj = null
    let sides = events.getSidesList(roomMGM)
    foreach (team in events.getSidesList()) {
      let teamName = events.getTeamName(team)
      teamObj = this.getObject(teamName)
      if (teamObj == null)
        continue

      let show = isInArray(team, sides)
      teamObj.show(show)
      if (!show)
        continue

      let titleObj = teamObj.findObject("team_title")
      if (checkObj(titleObj)) {
        let isEventFreeForAll = events.isEventFreeForAll(roomMGM)
        titleObj.show(! events.isEventSymmetricTeams(roomMGM) || isEventFreeForAll)
        titleObj.setValue(isEventFreeForAll ? loc("events/ffa")
          : g_team.getTeamByCode(team).getName())
      }

      let teamData = events.getTeamDataWithRoom(roomMGM, team, this.room)
      let playersCountObj = this.getObject("players_count", teamObj)
      if (playersCountObj)
        playersCountObj.setValue(sides.len() > 1 ? this.getTeamPlayersCountText(team, teamData, roomMGM) : "")

      fillCountriesList(this.getObject("countries", teamObj), events.getCountries(teamData))
      let unitTypes = events.getUnitTypesByTeamDataAndName(teamData, teamName)
      let roomSpecialRules = this.room && getRoomSpecialRules(this.room)
      events.fillAirsList(this, teamObj, teamData, unitTypes, roomSpecialRules)
    }

    
    let separatorObj = this.getObject("teams_separator")
    if (separatorObj != null)
      separatorObj.show(sides.len() > 1)

    
    this.loadMap()
    this.fetchLbData()
  }

  function updateBottomCustomDesc() {
    let craftSetId = this.selectedEvent?.craftTree ?? ""
    let workshopSet = getSetById(craftSetId)
    if (workshopSet == null)
      return

    let obj = this.getObject("bottom_event_custom_desc")
    if (this.workshopSetHandler == null)
      this.workshopSetHandler = loadCustomCraftTree({
        scene = obj
        workshopSet
        maxWindowWidth = obj.getSize()[0]
      }).weakref()
    else
      this.workshopSetHandler.updateHandlerData({ workshopSet })
  }

  function updateTopDesc(roomMGM) {
    if (this.needEventHeader)
      this.updateContentHeader()

    let eventDescTextObj = this.getObject("event_desc_text")
    if (eventDescTextObj != null)
      eventDescTextObj.setValue(events.getEventDescriptionText(this.selectedEvent, this.room))

    
    let eventDifficultyObj = this.getObject("event_difficulty")
    if (eventDifficultyObj != null) {
      let difficultyText = events.isDifficultyCustom(this.selectedEvent)
        ? loc("options/custom")
        : events.getDifficultyText(this.selectedEvent.name)
      let respawnText = events.getRespawnsText(this.selectedEvent)
      eventDifficultyObj.text = format(" %s %s", difficultyText, respawnText)
    }

    
    let eventPlayersRangeObj = this.getObject("event_players_range")
    if (eventPlayersRangeObj != null) {
      let rangeData = events.getPlayersRangeTextData(roomMGM)
      eventPlayersRangeObj.show(rangeData.isValid)
      if (rangeData.isValid) {
        let labelObj = this.getObject("event_players_range_label")
        if (labelObj != null)
          labelObj.setValue(rangeData.label)
        let valueObj = this.getObject("event_players_range_text")
        if (valueObj != null)
          valueObj.setValue(rangeData.value)
      }
    }

    
    let clanOnlyInfoObj = this.getObject("clan_event")
    if (clanOnlyInfoObj != null)
      clanOnlyInfoObj.show(isEventForClan(this.selectedEvent))

    
    let allowSwitchClanObj = this.getObject("allow_switch_clan")
    if (allowSwitchClanObj != null) {
      let eventType = getTblValue("type", this.selectedEvent, 0)
      let clanTournamentType = EVENT_TYPE.TOURNAMENT | EVENT_TYPE.CLAN
      let showMessage = (eventType & clanTournamentType) == clanTournamentType
      allowSwitchClanObj.show(showMessage)
      if (showMessage) {
        let locId = "".concat("events/allowSwitchClan/",
          events.isEventAllowSwitchClan(this.selectedEvent).tostring())
        allowSwitchClanObj.text = loc(locId)
      }
    }

    
    let timerObj = this.getObject("event_time")
    if (timerObj != null) {
        SecondsUpdater(timerObj, Callback(function(obj, _params) {
          let text = this.getDescriptionTimeText()
          obj.setValue(text)
          return text.len() == 0
        }, this))
    }

    let timeLimitObj = showObjById("event_time_limit", !!this.room, this.scene)
    if (timeLimitObj && this.room) {
      let timeLimit = getSessionLobbyTimeLimit(this.room)
      local timeText = ""
      if (timeLimit > 0) {
        let option = get_option(USEROPT_TIME_LIMIT)
        timeText = "".concat(option.getTitle(), loc("ui/colon"), option.getValueLocText(timeLimit))
      }
      timeLimitObj.setValue(timeText)
    }

    showObjById("players_list_btn", !!this.room, this.scene)
    showObjById("help_btn", this.selectedEvent?.helpBlkPath != null, this.scene)
    this.updateCostText()
  }

  function _updateContent() {
    this.currentFullRoomData = this.getFullRoomData()

    let eventDescNest = showObjById("event_desc_nest", this.selectedEvent != null, this.scene)

    if (this.selectedEvent == null)
      return

    let roomMGM = events.getMGameMode(this.selectedEvent, this.room)
    this.updateTopDesc(roomMGM)

    let hasCustomDesc = (this.selectedEvent?.craftTree ?? "") != ""
    showObjById("bottom_event_desc", !hasCustomDesc, eventDescNest)
    showObjById("bottom_event_custom_desc", hasCustomDesc, eventDescNest)

    this.getObject("event_desc", eventDescNest)["overflow-y"] = hasCustomDesc ? "no" : "auto"
    if (hasCustomDesc)
      this.updateBottomCustomDesc()
    else
      this.updateBottomDesc(roomMGM)
  }

  function getTeamPlayersCountText(team, teamData, roomMGM) {
    if (!this.room) {
      if (events.hasTeamSizeHandicap(roomMGM))
        return colorize("activeTextColor", "".concat(loc("events/handicap"), events.getTeamSize(teamData)))
      return ""
    }

    let otherTeam = g_team.getTeamByCode(team).opponentTeamCode
    let countTblReady = getMembersCountByTeams(this.currentFullRoomData, true)
    local countText = countTblReady[team]
    if (countTblReady[team] >= events.getTeamSize(teamData)
        || countTblReady[team] - getMaxLobbyDisbalance(roomMGM) >= countTblReady[otherTeam])
      countText = colorize("warningTextColor", countText)

    let countTbl = this.currentFullRoomData && getMembersCountByTeams(this.currentFullRoomData)
    local locId = "multiplayer/teamPlayers"
    let locParams = {
      players = countText
      maxPlayers = events.getMaxTeamSize(roomMGM)
      unready = max(0, getTblValue(team, countTbl, 0) - countTblReady[team])
    }
    if (locParams.unready)
      locId = "multiplayer/teamPlayers/hasUnready"
    return "".concat(loc("events/players_count"), loc("ui/colon"), loc(locId, locParams))
  }

  function updateContentHeader() {
    
    let difficultyImgObj = this.getObject("difficulty_img")
    if (difficultyImgObj) {
      difficultyImgObj["background-image"] = events.getDifficultyImg(this.selectedEvent.name)
      difficultyImgObj["tooltip"] = events.getDifficultyTooltip(this.selectedEvent.name)
    }

    
    let eventNameObj = this.getObject("event_name")
    if (eventNameObj)
      eventNameObj.setValue(this.getHeaderText())
  }

  function getHeaderText() {
    if (!this.room)
      return  " ".concat(events.getEventNameText(this.selectedEvent),
        events.getRespawnsText(this.selectedEvent))

    local res = ""
    let reqUnits = getRoomRequiredCrafts(Team.A, this.room)
    let tierText = events.getBrTextByRules(reqUnits)
    if (tierText.len())
      res = $"{tierText} "

    res = "".concat(res, getSessionLobbyMissionNameLoc(this.room))

    let teamsCnt = getMembersCountByTeams(this.currentFullRoomData)
    local teamsCntText = ""
    if (events.isEventSymmetricTeams(events.getMGameMode(this.selectedEvent, this.room)))
      teamsCntText = "".concat(loc("events/players_count"), loc("ui/colon"),
        (teamsCnt[Team.A] + teamsCnt[Team.B]))
    else
      teamsCntText =  " ".concat(teamsCnt[Team.A], loc("country/VS"), teamsCnt[Team.B])
    res = "".concat(res, loc("ui/parentheses/space", { text = teamsCntText }))
    return res
  }

  function updateCostText() {
    if (this.selectedEvent == null)
      return

    let costDescObj = this.getObject("cost_desc")
    if (costDescObj == null)
      return

    local text = events.getEventActiveTicketText(this.selectedEvent, "activeTextColor")
    text = "".concat(text, text.len() ? "\n" : "", events.getEventBattleCostText(this.selectedEvent, "activeTextColor"))
    costDescObj.setValue(text)

    let ticketBoughtImgObj = this.getObject("bought_ticket_img")
    if (ticketBoughtImgObj != null) {
      let showImg = events.hasEventTicket(this.selectedEvent)
        && events.getEventActiveTicket(this.selectedEvent).getCost() > zero_money
      ticketBoughtImgObj.show(showImg)
    }

    let hasAchievementGroup = (events.getEventAchievementGroup(this.selectedEvent) != "")
    showObjById("rewards_list_btn",
      haveRewards(this.selectedEvent) || getBaseVictoryReward(this.selectedEvent)
        || hasAchievementGroup, this.scene)
  }

  function loadMap() {
    if (this.selectedEvent.name.len() == 0)
      return

    local misName = ""
    if (this.room)
      misName = getSessionLobbyMissionName(true, this.room)
    if (!misName.len())
      misName = events.getEventMission(this.selectedEvent.name)

    local hasMission = misName != ""
    if (hasMission) {
      let misData = get_meta_mission_info_by_name(misName)
      if (misData) {
        let m = DataBlock()
        m.load(misData.getStr("mis_file", ""))
        setMapPreview(this.scene.findObject("tactical-map"), m)
      }
      else {
        log($"Error: Event {this.selectedEvent.name}: not found mission info for mission {misName}")
        hasMission = false
      }
    }
    showObjById("tactical_map_single", hasMission, this.scene)

    let multipleMapObj = showObjById("multiple_mission", !hasMission, this.scene)
    if (!hasMission && multipleMapObj)
      multipleMapObj["background-image"] = "#ui/random_mission_map.ddsx"
  }

  function getDescriptionTimeText() {
    if (!this.room)
      return events.getEventTimeText(events.getMGameMode(this.selectedEvent, this.room))

    let startTime = getRoomSessionStartTime(this.room)
    if (startTime <= 0)
      return ""

    let secToStart = startTime - getMatchingServerTime()
    if (secToStart <= 0)
      return loc("multiplayer/battleInProgressTime", { time = time.secondsToString(-secToStart, true) })
    return loc("multiplayer/battleStartsIn", { time = time.secondsToString(secToStart, true) })
  }

  function fetchLbData() {
    let isLbAvailable = isLeaderboardsAvailable()
    this.hideEventLeaderboard(isLbAvailable)
    if (!isLbAvailable) {
      this.showEventLb(null)
      return
    }

    this.newSelfRowRequest = events.getMainLbRequest(this.selectedEvent)
    events.requestSelfRow(
      this.newSelfRowRequest,
      "mini_lb_self",
      (@(selectedEvent) function (_self_row) { 
        events.requestLeaderboard(events.getMainLbRequest(selectedEvent),
        "mini_lb_self",
        function (lb_data) {
          this.showEventLb(lb_data)
        }, this)
      })(this.selectedEvent), this)
  }

  function showEventLb(lb_data) {
    if (!checkObj(this.scene))
      return

    let lbWrapObj = this.getObject("lb_wrap")
    let lbWaitBox = this.getObject("msgWaitAnimation")
    if (lbWrapObj == null || lbWaitBox == null)
      return

    let btnLb = this.getObject("leaderboards_btn", lbWrapObj)
    let lbTable = this.getObject("lb_table", lbWrapObj)
    if (btnLb == null || lbTable == null)
      return

    let isLbAvailable = isLeaderboardsAvailable()
    let lbRows = lb_data?.rows ?? []
    this.playersInTable = []
    this.guiScene.replaceContentFromText(lbTable, "", 0, this)
    lbWaitBox.show(!lb_data && isLbAvailable)

    if (events.isEventForClanGlobalLb(this.selectedEvent) || this.newSelfRowRequest == null)
      return

    let field = this.newSelfRowRequest.lbField
    let lbCategory = events.getLbCategoryByField(field)
    let showTable = this.checkLbTableVisible(lbRows, lbCategory)
    let showButton = lbRows.len() > 0 && isLbAvailable
    lbTable.show(showTable)
    btnLb.show(showButton)
    if (!showTable)
      return

    local data = ""
    local rowIdx = 0
    foreach (row in lbRows) {
      if ((row?[lbCategory.field] ?? -1) <= 0)
        continue
      data = "".concat(data, this.generateRowTableData(row, rowIdx++, lbCategory))
      this.playersInTable.append("nick" in row ? row.nick : -1)
      if (rowIdx >= EVENTS_SHORT_LB_VISIBLE_ROWS)
        break
    }
    this.guiScene.replaceContentFromText(lbTable, data, data.len(), this)
  }

  function checkLbTableVisible(lb_rows, lbCategory) {
    if (isPlatformSony || isPlatformXboxOne || lbCategory == null || lb_rows.len() == 0)
      return false

    return true
  }

  function generateRowTableData(row, rowIdx, lbCategory) {
    if (!this.newSelfRowRequest)
      return ""

    let rowName = $"row_{rowIdx}"
    let forClan = events.isClanLbRequest(this.newSelfRowRequest)

    let name = getPlayerName(row?.name ?? "")
    local text = name
    if (forClan)
      text = row?.tag ?? ""

    let rowData = [
      {
        text = (row.pos + 1).tostring()
        width = "0.01*@sf"
        cellType = "top_numeration"
      }
      {
        id = "name"
        width = "3fw"
        textRawParam = "width:t='pw'; pare-text:t='yes';"
        tdalign = "left"
        text = text
        tooltip = forClan ? name : ""
        active = false
      }
    ]

    if (lbCategory) {
      let td = lbCategory.getItemCell(getTblValue(lbCategory.field, row, -1))
      td.tdalign <- "right"
      rowData.append(td)
    }
    let data = buildTableRow(rowName, rowData, 0, "inactive:t='yes'; commonTextColor:t='yes';", "0")
    return data
  }

  function getObject(id, parentObject = null) {
    if (parentObject == null)
      parentObject = this.scene
    let obj = parentObject.findObject(id)
    return checkObj(obj) ? obj : null
  }

  function onEventInventoryUpdate(_params) {
    this.updateCostText()
  }

  function onEventEventlbDataRenewed(params) {
    if (getTblValue("eventId", params) == getTblValue("name", this.selectedEvent))
      this.fetchLbData()
  }

  function onEventItemBought(params) {
    let item = getTblValue("item", params)
    if (item && item.isForEvent(getTblValue("name", this.selectedEvent)))
      this.updateCostText()
  }

  function onOpenEventLeaderboards() {
    if (this.selectedEvent == null)
      return

    gui_modal_event_leaderboards({
      eventId = this.selectedEvent.name
      lb_presets = this.selectedEvent?.leaderboardEventBestStat != null
        ? [ getLbCategoryTypeByField(this.selectedEvent.leaderboardEventBestStat) ]
        : null
    })
  }

  function onRewardsList() {
    let eventAchievementGroup = events.getEventAchievementGroup(this.selectedEvent)
    if (eventAchievementGroup != "") {
      guiStartProfile({
        initialSheet = "UnlockAchievement"
        curAchievementGroupName = eventAchievementGroup
      })
    }
    else
      gui_handlers.EventRewardsWnd.open([{
          header = loc("tournaments/rewards")
          event = this.selectedEvent
        }])
  }

  function onPlayersList() {
    gui_handlers.MRoomMembersWnd.open(this.room)
  }

  function onHelp() {
    if (this.selectedEvent?.helpBlkPath == null)
      return

    let misType = g_mission_type.getTypeByMissionName(this.selectedEvent.name)
    if (misType == g_mission_type.UNKNOWN)
      return

    gui_modal_help(false, HELP_CONTENT_SET.MISSION_WINDOW, misType)
  }

  function hideEventLeaderboard(showWaitBox = true) {
    let lbWrapObj = this.getObject("lb_wrap")
    if (lbWrapObj == null)
      return
    let btnLb = this.getObject("leaderboards_btn", lbWrapObj)
    if (btnLb != null)
      btnLb.show(false)
    let lbTable = this.getObject("lb_table", lbWrapObj)
    if (lbTable != null)
      lbTable.show(false)
    let lbWaitBox = this.getObject("msgWaitAnimation")
    if (lbWaitBox != null)
      lbWaitBox.show(showWaitBox)
  }

  function getFullRoomData() {
    return this.room && getMroomInfo(this.room.roomId).getFullRoomData()
  }

  function onEventMRoomInfoUpdated(p) {
    if (this.room && p.roomId == this.room.roomId && !u.isEqual(this.currentFullRoomData, this.getFullRoomData()))
      this.updateContent()
  }
}

return {
  create_event_description
}