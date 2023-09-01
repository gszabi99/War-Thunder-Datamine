//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")

let DataBlock = require("DataBlock")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { format } = require("string")
let SecondsUpdater = require("%sqDagui/timer/secondsUpdater.nut")
let time = require("%scripts/time.nut")
let { getPlayerName,
        isPlatformXboxOne,
        isPlatformSony } = require("%scripts/clientState/platform.nut")
let { isLeaderboardsAvailable } = require("%scripts/events/eventInfo.nut")
let { haveRewards, getBaseVictoryReward } = require("%scripts/events/eventRewards.nut")
let { get_meta_mission_info_by_name } = require("guiMission")
let { setMapPreview } = require("%scripts/missions/mapPreview.nut")

::create_event_description <- function create_event_description(parent_scene, event = null, needEventHeader = true) {
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

gui_handlers.EventDescription <- class extends gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/empty.blk"

  selectedEvent = null
  room = null
  needEventHeader = true

  playersInTable = null
  currentFullRoomData = null

  // Most recent request for short leaderboards.
  newSelfRowRequest = null

  function initScreen() {
    this.playersInTable = []
    let blk = handyman.renderCached("%gui/events/eventDescription.tpl", {})
    this.guiScene.replaceContentFromText(this.scene, blk, blk.len(), this)
    this.updateContent()
  }

  function selectEvent(event, eventRoom = null) {
    if (this.room)
      ::g_mroom_info.get(this.room.roomId).checkRefresh()
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

  function _updateContent() {
    this.currentFullRoomData = this.getFullRoomData()
    if (this.selectedEvent == null) {
      this.setEventDescObjVisible(false)
      return
    }

    this.setEventDescObjVisible(true)

    if (this.needEventHeader)
      this.updateContentHeader()

    let roomMGM = ::events.getMGameMode(this.selectedEvent, this.room)

    let eventDescTextObj = this.getObject("event_desc_text")
    if (eventDescTextObj != null)
      eventDescTextObj.setValue(::events.getEventDescriptionText(this.selectedEvent, this.room))

    // Event difficulty
    let eventDifficultyObj = this.getObject("event_difficulty")
    if (eventDifficultyObj != null) {
      let difficultyText = ::events.isDifficultyCustom(this.selectedEvent)
        ? loc("options/custom")
        : ::events.getDifficultyText(this.selectedEvent.name)
      let respawnText = ::events.getRespawnsText(this.selectedEvent)
      eventDifficultyObj.text = format(" %s %s", difficultyText, respawnText)
    }

    // Event players range
    let eventPlayersRangeObj = this.getObject("event_players_range")
    if (eventPlayersRangeObj != null) {
      let rangeData = ::events.getPlayersRangeTextData(roomMGM)
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

    // Clan info
    let clanOnlyInfoObj = this.getObject("clan_event")
    if (clanOnlyInfoObj != null)
      clanOnlyInfoObj.show(::events.isEventForClan(this.selectedEvent))

    // Allow switch clan
    let allowSwitchClanObj = this.getObject("allow_switch_clan")
    if (allowSwitchClanObj != null) {
      let eventType = getTblValue("type", this.selectedEvent, 0)
      let clanTournamentType = EVENT_TYPE.TOURNAMENT | EVENT_TYPE.CLAN
      let showMessage = (eventType & clanTournamentType) == clanTournamentType
      allowSwitchClanObj.show(showMessage)
      if (showMessage) {
        let locId = "events/allowSwitchClan/" + ::events.isEventAllowSwitchClan(this.selectedEvent).tostring()
        allowSwitchClanObj.text = loc(locId)
      }
    }

    // Timer
    let timerObj = this.getObject("event_time")
    if (timerObj != null) {
        SecondsUpdater(timerObj, Callback(function(obj, _params) {
          let text = this.getDescriptionTimeText()
          obj.setValue(text)
          return text.len() == 0
        }, this))
    }

    let timeLimitObj = this.showSceneBtn("event_time_limit", !!this.room)
    if (timeLimitObj && this.room) {
      let timeLimit = ::SessionLobby.getTimeLimit(this.room)
      local timeText = ""
      if (timeLimit > 0) {
        let option = ::get_option(::USEROPT_TIME_LIMIT)
        timeText = option.getTitle() + loc("ui/colon") + option.getValueLocText(timeLimit)
      }
      timeLimitObj.setValue(timeText)
    }

    this.showSceneBtn("players_list_btn", !!this.room)

    // Fill vehicle lists
    local teamObj = null
    let sides = ::events.getSidesList(roomMGM)
    foreach (team in ::events.getSidesList()) {
      let teamName = ::events.getTeamName(team)
      teamObj = this.getObject(teamName)
      if (teamObj == null)
        continue

      let show = isInArray(team, sides)
      teamObj.show(show)
      if (!show)
        continue

      let titleObj = teamObj.findObject("team_title")
      if (checkObj(titleObj)) {
        let isEventFreeForAll = ::events.isEventFreeForAll(roomMGM)
        titleObj.show(! ::events.isEventSymmetricTeams(roomMGM) || isEventFreeForAll)
        titleObj.setValue(isEventFreeForAll ? loc("events/ffa")
          : ::g_team.getTeamByCode(team).getName())
      }

      let teamData = ::events.getTeamDataWithRoom(roomMGM, team, this.room)
      let playersCountObj = this.getObject("players_count", teamObj)
      if (playersCountObj)
        playersCountObj.setValue(sides.len() > 1 ? this.getTeamPlayersCountText(team, teamData, roomMGM) : "")

      ::fillCountriesList(this.getObject("countries", teamObj), ::events.getCountries(teamData))
      let unitTypes = ::events.getUnitTypesByTeamDataAndName(teamData, teamName)
      let roomSpecialRules = this.room && ::SessionLobby.getRoomSpecialRules(this.room)
      ::events.fillAirsList(this, teamObj, teamData, unitTypes, roomSpecialRules)
    }

    // Team separator
    let separatorObj = this.getObject("teams_separator")
    if (separatorObj != null)
      separatorObj.show(sides.len() > 1)

    // Misc
    this.updateCostText()
    this.loadMap()
    this.fetchLbData()
  }

  function getTeamPlayersCountText(team, teamData, roomMGM) {
    if (!this.room) {
      if (::events.hasTeamSizeHandicap(roomMGM))
        return colorize("activeTextColor", loc("events/handicap") + ::events.getTeamSize(teamData))
      return ""
    }

    let otherTeam = ::g_team.getTeamByCode(team).opponentTeamCode
    let countTblReady = ::SessionLobby.getMembersCountByTeams(this.currentFullRoomData, true)
    local countText = countTblReady[team]
    if (countTblReady[team] >= ::events.getTeamSize(teamData)
        || countTblReady[team] - ::events.getMaxLobbyDisbalance(roomMGM) >= countTblReady[otherTeam])
      countText = colorize("warningTextColor", countText)

    let countTbl = this.currentFullRoomData && ::SessionLobby.getMembersCountByTeams(this.currentFullRoomData)
    local locId = "multiplayer/teamPlayers"
    let locParams = {
      players = countText
      maxPlayers = ::events.getMaxTeamSize(roomMGM)
      unready = max(0, getTblValue(team, countTbl, 0) - countTblReady[team])
    }
    if (locParams.unready)
      locId = "multiplayer/teamPlayers/hasUnready"
    return loc("events/players_count") + loc("ui/colon") + loc(locId, locParams)
  }

  function updateContentHeader() {
    // Difficulty image
    let difficultyImgObj = this.getObject("difficulty_img")
    if (difficultyImgObj) {
      difficultyImgObj["background-image"] = ::events.getDifficultyImg(this.selectedEvent.name)
      difficultyImgObj["tooltip"] = ::events.getDifficultyTooltip(this.selectedEvent.name)
    }

    // Event name
    let eventNameObj = this.getObject("event_name")
    if (eventNameObj)
      eventNameObj.setValue(this.getHeaderText())
  }

  function getHeaderText() {
    if (!this.room)
      return ::events.getEventNameText(this.selectedEvent) + " " + ::events.getRespawnsText(this.selectedEvent)

    local res = ""
    let reqUnits = ::SessionLobby.getRequiredCrafts(Team.A, this.room)
    let tierText = ::events.getBrTextByRules(reqUnits)
    if (tierText.len())
      res += tierText + " "

    res += ::SessionLobby.getMissionNameLoc(this.room)

    let teamsCnt = ::SessionLobby.getMembersCountByTeams(this.currentFullRoomData)
    local teamsCntText = ""
    if (::events.isEventSymmetricTeams(::events.getMGameMode(this.selectedEvent, this.room)))
      teamsCntText = loc("events/players_count") + loc("ui/colon") + (teamsCnt[Team.A] + teamsCnt[Team.B])
    else
      teamsCntText = teamsCnt[Team.A] + " " + loc("country/VS") + " " + teamsCnt[Team.B]
    res += loc("ui/parentheses/space", { text = teamsCntText })
    return res
  }

  function updateCostText() {
    if (this.selectedEvent == null)
      return

    let costDescObj = this.getObject("cost_desc")
    if (costDescObj == null)
      return

    local text = ::events.getEventActiveTicketText(this.selectedEvent, "activeTextColor")
    text += (text.len() ? "\n" : "") + ::events.getEventBattleCostText(this.selectedEvent, "activeTextColor")
    costDescObj.setValue(text)

    let ticketBoughtImgObj = this.getObject("bought_ticket_img")
    if (ticketBoughtImgObj != null) {
      let showImg = ::events.hasEventTicket(this.selectedEvent)
        && ::events.getEventActiveTicket(this.selectedEvent).getCost() > ::zero_money
      ticketBoughtImgObj.show(showImg)
    }

    let hasAchievementGroup = (::events.getEventAchievementGroup(this.selectedEvent) != "")
    this.showSceneBtn("rewards_list_btn",
      haveRewards(this.selectedEvent) || getBaseVictoryReward(this.selectedEvent)
        || hasAchievementGroup)
  }

  function loadMap() {
    if (this.selectedEvent.name.len() == 0)
      return

    local misName = ""
    if (this.room)
      misName = ::SessionLobby.getMissionName(true, this.room)
    if (!misName.len())
      misName = ::events.getEventMission(this.selectedEvent.name)

    local hasMission = misName != ""
    if (hasMission) {
      let misData = get_meta_mission_info_by_name(misName)
      if (misData) {
        let m = DataBlock()
        m.load(misData.getStr("mis_file", ""))
        setMapPreview(this.scene.findObject("tactical-map"), m)
      }
      else {
        log("Error: Event " + this.selectedEvent.name + ": not found mission info for mission " + misName)
        hasMission = false
      }
    }
    this.showSceneBtn("tactical_map_single", hasMission)

    let multipleMapObj = this.showSceneBtn("multiple_mission", !hasMission)
    if (!hasMission && multipleMapObj)
      multipleMapObj["background-image"] = "#ui/random_mission_map.ddsx"
  }

  function getDescriptionTimeText() {
    if (!this.room)
      return ::events.getEventTimeText(::events.getMGameMode(this.selectedEvent, this.room))

    let startTime = ::SessionLobby.getRoomSessionStartTime(this.room)
    if (startTime <= 0)
      return ""

    let secToStart = startTime - ::get_matching_server_time()
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

    this.newSelfRowRequest = ::events.getMainLbRequest(this.selectedEvent)
    ::events.requestSelfRow(
      this.newSelfRowRequest,
      "mini_lb_self",
      (@(selectedEvent) function (_self_row) { //-ident-hides-ident
        ::events.requestLeaderboard(::events.getMainLbRequest(selectedEvent),
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

    if (::events.isEventForClanGlobalLb(this.selectedEvent) || this.newSelfRowRequest == null)
      return

    let field = this.newSelfRowRequest.lbField
    let lbCategory = ::events.getLbCategoryByField(field)
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
      data += this.generateRowTableData(row, rowIdx++, lbCategory)
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

    let rowName = "row_" + rowIdx
    let forClan = ::events.isClanLbRequest(this.newSelfRowRequest)

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
    let data = ::buildTableRow(rowName, rowData, 0, "inactive:t='yes'; commonTextColor:t='yes';", "0")
    return data
  }

  function setEventDescObjVisible(value) {
    let eventDescObj = this.getObject("event_desc")
    if (eventDescObj != null)
      eventDescObj.show(value)
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

    ::gui_modal_event_leaderboards({
      eventId = this.selectedEvent.name
      lb_presets = this.selectedEvent?.leaderboardEventBestStat != null
        ? [ ::g_lb_category.getTypeByField(this.selectedEvent.leaderboardEventBestStat) ]
        : null
    })
  }

  function onRewardsList() {
    let eventAchievementGroup = ::events.getEventAchievementGroup(this.selectedEvent)
    if (eventAchievementGroup != "") {
      ::gui_start_profile({
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
    return this.room && ::g_mroom_info.get(this.room.roomId).getFullRoomData()
  }

  function onEventMRoomInfoUpdated(p) {
    if (this.room && p.roomId == this.room.roomId && !u.isEqual(this.currentFullRoomData, this.getFullRoomData()))
      this.updateContent()
  }
}
