let { format } = require("string")
let SecondsUpdater = require("%sqDagui/timer/secondsUpdater.nut")
let time = require("%scripts/time.nut")
let { getPlayerName,
        isPlatformXboxOne,
        isPlatformSony } = require("%scripts/clientState/platform.nut")
let { isLeaderboardsAvailable } = require("%scripts/events/eventInfo.nut")

::create_event_description <- function create_event_description(parent_scene, event = null, needEventHeader = true)
{
  let containerObj = parent_scene.findObject("item_desc")
  if (!::checkObj(containerObj))
    return null
  let params = {
    scene = containerObj
    selectedEvent = event
    needEventHeader = needEventHeader
  }
  local handler = ::handlersManager.loadHandler(::gui_handlers.EventDescription, params)
  return handler
}

::gui_handlers.EventDescription <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/empty.blk"

  selectedEvent = null
  room = null
  needEventHeader = true

  playersInTable = null
  currentFullRoomData = null

  // Most recent request for short leaderboards.
  newSelfRowRequest = null

  function initScreen()
  {
    playersInTable = []
    let blk = ::handyman.renderCached("%gui/events/eventDescription", {})
    guiScene.replaceContentFromText(scene, blk, blk.len(), this)
    updateContent()
  }

  function selectEvent(event, eventRoom = null)
  {
    if (room)
      ::g_mroom_info.get(room.roomId).checkRefresh()
    if (selectedEvent == event && ::u.isEqual(room, eventRoom))
      return

    selectedEvent = event
    room = eventRoom
    updateContent()
  }

  function updateContent()
  {
    if (!::checkObj(scene))
      return

    guiScene.setUpdatesEnabled(false, false)
    _updateContent()
    guiScene.setUpdatesEnabled(true, true)
  }

  function _updateContent()
  {
    currentFullRoomData = getFullRoomData()
    if (selectedEvent == null)
    {
      setEventDescObjVisible(false)
      return
    }

    setEventDescObjVisible(true)

    if (needEventHeader)
      updateContentHeader()

    let roomMGM = ::events.getMGameMode(selectedEvent, room)

    let eventDescTextObj = getObject("event_desc_text")
    if (eventDescTextObj != null)
      eventDescTextObj.setValue(::events.getEventDescriptionText(selectedEvent, room))

    // Event difficulty
    let eventDifficultyObj = getObject("event_difficulty")
    if (eventDifficultyObj != null)
    {
      let difficultyText = ::events.isDifficultyCustom(selectedEvent)
        ? ::loc("options/custom")
        : ::events.getDifficultyText(selectedEvent.name)
      let respawnText = ::events.getRespawnsText(selectedEvent)
      eventDifficultyObj.text = format(" %s %s", difficultyText, respawnText)
    }

    // Event players range
    let eventPlayersRangeObj = getObject("event_players_range")
    if (eventPlayersRangeObj != null)
    {
      let rangeData = ::events.getPlayersRangeTextData(roomMGM)
      eventPlayersRangeObj.show(rangeData.isValid)
      if (rangeData.isValid)
      {
        let labelObj = getObject("event_players_range_label")
        if (labelObj != null)
          labelObj.setValue(rangeData.label)
        let valueObj = getObject("event_players_range_text")
        if (valueObj != null)
          valueObj.setValue(rangeData.value)
      }
    }

    // Clan info
    let clanOnlyInfoObj = getObject("clan_event")
    if(clanOnlyInfoObj != null)
      clanOnlyInfoObj.show(::events.isEventForClan(selectedEvent))

    // Allow switch clan
    let allowSwitchClanObj = getObject("allow_switch_clan")
    if (allowSwitchClanObj != null)
    {
      let eventType = ::getTblValue("type", selectedEvent, 0)
      let clanTournamentType = EVENT_TYPE.TOURNAMENT | EVENT_TYPE.CLAN
      let showMessage = (eventType & clanTournamentType) == clanTournamentType
      allowSwitchClanObj.show(showMessage)
      if (showMessage)
      {
        let locId = "events/allowSwitchClan/" + ::events.isEventAllowSwitchClan(selectedEvent).tostring()
        allowSwitchClanObj.text = ::loc(locId)
      }
    }

    // Timer
    let timerObj = getObject("event_time")
    if (timerObj != null)
    {
        SecondsUpdater(timerObj, ::Callback(function(obj, params)
        {
          let text = getDescriptionTimeText()
          obj.setValue(text)
          return text.len() == 0
        }, this))
    }

    let timeLimitObj = this.showSceneBtn("event_time_limit", !!room)
    if (timeLimitObj && room)
    {
      let timeLimit = ::SessionLobby.getTimeLimit(room)
      local timeText = ""
      if (timeLimit > 0)
      {
        let option = ::get_option(::USEROPT_TIME_LIMIT)
        timeText = option.getTitle() + ::loc("ui/colon") + option.getValueLocText(timeLimit)
      }
      timeLimitObj.setValue(timeText)
    }

    this.showSceneBtn("players_list_btn", !!room)

    // Fill vehicle lists
    local teamObj = null
    let sides = ::events.getSidesList(roomMGM)
    foreach(team in ::events.getSidesList())
    {
      let teamName = ::events.getTeamName(team)
      teamObj = getObject(teamName)
      if (teamObj == null)
        continue

      let show = ::isInArray(team, sides)
      teamObj.show(show)
      if (!show)
        continue

      let titleObj = teamObj.findObject("team_title")
      if(::checkObj(titleObj))
      {
        let isEventFreeForAll = ::events.isEventFreeForAll(roomMGM)
        titleObj.show( ! ::events.isEventSymmetricTeams(roomMGM) || isEventFreeForAll)
        titleObj.setValue(isEventFreeForAll ? ::loc("events/ffa")
          : ::g_team.getTeamByCode(team).getName())
      }

      let teamData = ::events.getTeamDataWithRoom(roomMGM, team, room)
      let playersCountObj = getObject("players_count", teamObj)
      if (playersCountObj)
        playersCountObj.setValue(sides.len() > 1 ? getTeamPlayersCountText(team, teamData, roomMGM) : "")

      ::fillCountriesList(getObject("countries", teamObj), ::events.getCountries(teamData))
      let unitTypes = ::events.getUnitTypesByTeamDataAndName(teamData, teamName)
      let roomSpecialRules = room && ::SessionLobby.getRoomSpecialRules(room)
      ::events.fillAirsList(this, teamObj, teamData, unitTypes, roomSpecialRules)
    }

    // Team separator
    let separatorObj = getObject("teams_separator")
    if (separatorObj != null)
      separatorObj.show(sides.len() > 1)

    // Misc
    updateCostText()
    loadMap()
    fetchLbData()
  }

  function getTeamPlayersCountText(team, teamData, roomMGM)
  {
    if (!room)
    {
      if (::events.hasTeamSizeHandicap(roomMGM))
        return ::colorize("activeTextColor", ::loc("events/handicap") + ::events.getTeamSize(teamData))
      return ""
    }

    let otherTeam = ::g_team.getTeamByCode(team).opponentTeamCode
    let countTblReady = ::SessionLobby.getMembersCountByTeams(currentFullRoomData, true)
    local countText = countTblReady[team]
    if (countTblReady[team] >= ::events.getTeamSize(teamData)
        || countTblReady[team] - ::events.getMaxLobbyDisbalance(roomMGM) >= countTblReady[otherTeam])
      countText = ::colorize("warningTextColor", countText)

    let countTbl = currentFullRoomData && ::SessionLobby.getMembersCountByTeams(currentFullRoomData)
    local locId = "multiplayer/teamPlayers"
    let locParams = {
      players = countText
      maxPlayers = ::events.getMaxTeamSize(roomMGM)
      unready = max(0, ::getTblValue(team, countTbl, 0) - countTblReady[team])
    }
    if (locParams.unready)
      locId = "multiplayer/teamPlayers/hasUnready"
    return ::loc("events/players_count") + ::loc("ui/colon") + ::loc(locId, locParams)
  }

  function updateContentHeader()
  {
    // Difficulty image
    let difficultyImgObj = getObject("difficulty_img")
    if (difficultyImgObj)
    {
      difficultyImgObj["background-image"] = ::events.getDifficultyImg(selectedEvent.name)
      difficultyImgObj["tooltip"] = ::events.getDifficultyTooltip(selectedEvent.name)
    }

    // Event name
    let eventNameObj = getObject("event_name")
    if (eventNameObj)
      eventNameObj.setValue(getHeaderText())
  }

  function getHeaderText()
  {
    if (!room)
      return ::events.getEventNameText(selectedEvent) + " " + ::events.getRespawnsText(selectedEvent)

    local res = ""
    let reqUnits = ::SessionLobby.getRequiredCrafts(Team.A, room)
    let tierText = ::events.getTierTextByRules(reqUnits)
    if (tierText.len())
      res += tierText + " "

    res += ::SessionLobby.getMissionNameLoc(room)

    let teamsCnt = ::SessionLobby.getMembersCountByTeams(currentFullRoomData)
    local teamsCntText = ""
    if (::events.isEventSymmetricTeams(::events.getMGameMode(selectedEvent, room)))
      teamsCntText = ::loc("events/players_count") + ::loc("ui/colon") + (teamsCnt[Team.A] + teamsCnt[Team.B])
    else
      teamsCntText = teamsCnt[Team.A] + " " + ::loc("country/VS") + " " + teamsCnt[Team.B]
    res += ::loc("ui/parentheses/space", { text =teamsCntText })
    return res
  }

  function updateCostText()
  {
    if (selectedEvent == null)
      return

    let costDescObj = getObject("cost_desc")
    if (costDescObj == null)
      return

    local text = ::events.getEventActiveTicketText(selectedEvent, "activeTextColor")
    text += (text.len() ? "\n" : "") + ::events.getEventBattleCostText(selectedEvent, "activeTextColor")
    costDescObj.setValue(text)

    let ticketBoughtImgObj = getObject("bought_ticket_img")
    if (ticketBoughtImgObj != null)
    {
      let showImg = ::events.hasEventTicket(selectedEvent)
        && ::events.getEventActiveTicket(selectedEvent).getCost() > ::zero_money
      ticketBoughtImgObj.show(showImg)
    }

    let hasAchievementGroup = (::events.getEventAchievementGroup(selectedEvent) != "")
    this.showSceneBtn("rewards_list_btn",
      ::EventRewards.haveRewards(selectedEvent) || ::EventRewards.getBaseVictoryReward(selectedEvent)
        || hasAchievementGroup)
  }

  function loadMap()
  {
    if (selectedEvent.name.len() == 0)
      return

    local misName = ""
    if (room)
      misName = ::SessionLobby.getMissionName(true, room)
    if (!misName.len())
      misName = ::events.getEventMission(selectedEvent.name)

    local hasMission = misName != ""
    if (hasMission)
    {
      let misData = ::get_meta_mission_info_by_name(misName)
      if (misData)
      {
        let m = ::DataBlock()
        m.load(misData.getStr("mis_file",""))
        ::g_map_preview.setMapPreview(scene.findObject("tactical-map"), m)
      }
      else
      {
        ::dagor.debug("Error: Event " + selectedEvent.name + ": not found mission info for mission " + misName)
        hasMission = false
      }
    }
    this.showSceneBtn("tactical_map_single", hasMission)

    let multipleMapObj = this.showSceneBtn("multiple_mission", !hasMission)
    if (!hasMission && multipleMapObj)
      multipleMapObj["background-image"] = "#ui/random_mission_map.ddsx"
  }

  function getDescriptionTimeText()
  {
    if (!room)
      return ::events.getEventTimeText(::events.getMGameMode(selectedEvent, room))

    let startTime = ::SessionLobby.getRoomSessionStartTime(room)
    if (startTime <= 0)
      return ""

    let secToStart = startTime - ::get_matching_server_time()
    if (secToStart <= 0)
      return ::loc("multiplayer/battleInProgressTime", { time = time.secondsToString(-secToStart, true) })
    return ::loc("multiplayer/battleStartsIn", { time = time.secondsToString(secToStart, true) })
  }

  function fetchLbData()
  {
    let isLbAvailable = isLeaderboardsAvailable()
    hideEventLeaderboard(isLbAvailable)
    if (!isLbAvailable)
    {
      showEventLb(null)
      return
    }

    newSelfRowRequest = ::events.getMainLbRequest(selectedEvent)
    ::events.requestSelfRow(
      newSelfRowRequest,
      "mini_lb_self",
      (@(selectedEvent) function (self_row) {
        ::events.requestLeaderboard(::events.getMainLbRequest(selectedEvent),
        "mini_lb_self",
        function (lb_data) {
          showEventLb(lb_data)
        }, this)
      })(selectedEvent), this)
  }

  function showEventLb(lb_data)
  {
    if (!::checkObj(scene))
      return

    let lbWrapObj = getObject("lb_wrap")
    let lbWaitBox = getObject("msgWaitAnimation")
    if (lbWrapObj == null || lbWaitBox == null)
      return

    let btnLb = getObject("leaderboards_btn", lbWrapObj)
    let lbTable = getObject("lb_table", lbWrapObj)
    if (btnLb == null || lbTable == null)
      return

    let isLbAvailable = isLeaderboardsAvailable()
    let lbRows = lb_data?.rows ?? []
    playersInTable = []
    guiScene.replaceContentFromText(lbTable, "", 0, this)
    lbWaitBox.show(!lb_data && isLbAvailable)

    if (::events.isEventForClanGlobalLb(selectedEvent) || newSelfRowRequest == null)
      return

    let field = newSelfRowRequest.lbField
    let lbCategory = ::events.getLbCategoryByField(field)
    let showTable = checkLbTableVisible(lbRows, lbCategory)
    let showButton = lbRows.len() > 0 && isLbAvailable
    lbTable.show(showTable)
    btnLb.show(showButton)
    if (!showTable)
      return

    local data = ""
    local rowIdx = 0
    foreach(row in lbRows)
    {
      data += generateRowTableData(row, rowIdx++, lbCategory)
      playersInTable.append("nick" in row ? row.nick : -1)
      if (rowIdx >= EVENTS_SHORT_LB_VISIBLE_ROWS)
        break
    }
    guiScene.replaceContentFromText(lbTable, data, data.len(), this)
  }

  function checkLbTableVisible(lb_rows, lbCategory)
  {
    if (isPlatformSony || isPlatformXboxOne)
      return false

    if (lbCategory == null)
      return false

    let participants = lb_rows ? lb_rows.len() : 0
    if (!participants || (::isProductionCircuit() && participants < EVENTS_SHORT_LB_REQUIRED_PARTICIPANTS_TO_SHOW))
      return false

    let lastValidatedRow = lb_rows[min(EVENTS_SHORT_LB_REQUIRED_PARTICIPANTS_TO_SHOW, participants) - 1]
    return ::getTblValue(lbCategory.field, lastValidatedRow, 0) > 0
  }

  function generateRowTableData(row, rowIdx, lbCategory)
  {
    if (!newSelfRowRequest)
      return ""

    let rowName = "row_" + rowIdx
    let forClan = ::events.isClanLbRequest(newSelfRowRequest)

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

    if (lbCategory)
    {
      let td = lbCategory.getItemCell(::getTblValue(lbCategory.field, row, -1))
      td.tdalign <- "right"
      rowData.append(td)
    }
    let data = ::buildTableRow(rowName, rowData, 0, "inactive:t='yes'; commonTextColor:t='yes';", "0")
    return data
  }

  function setEventDescObjVisible(value)
  {
    let eventDescObj = getObject("event_desc")
    if (eventDescObj != null)
      eventDescObj.show(value)
  }

  function getObject(id, parentObject = null)
  {
    if (parentObject == null)
      parentObject = scene
    let obj = parentObject.findObject(id)
    return ::checkObj(obj) ? obj : null
  }

  function onEventInventoryUpdate(params)
  {
    updateCostText()
  }

  function onEventEventlbDataRenewed(params)
  {
    if (::getTblValue("eventId", params) == ::getTblValue("name", selectedEvent))
      fetchLbData()
  }

  function onEventItemBought(params)
  {
    let item = ::getTblValue("item", params)
    if (item && item.isForEvent(::getTblValue("name", selectedEvent)))
      updateCostText()
  }

  function onOpenEventLeaderboards()
  {
    if (selectedEvent != null)
      ::gui_modal_event_leaderboards(selectedEvent.name)
  }

  function onRewardsList()
  {
    let eventAchievementGroup = ::events.getEventAchievementGroup(selectedEvent)
    if (eventAchievementGroup != "") {
      ::gui_start_profile({
        initialSheet = "UnlockAchievement"
        curAchievementGroupName = eventAchievementGroup
      })
    }
    else
      ::gui_handlers.EventRewardsWnd.open([{
          header = ::loc("tournaments/rewards")
          event = selectedEvent
        }])
  }

  function onPlayersList()
  {
    ::gui_handlers.MRoomMembersWnd.open(room)
  }

  function hideEventLeaderboard(showWaitBox = true)
  {
    let lbWrapObj = getObject("lb_wrap")
    if (lbWrapObj == null)
      return
    let btnLb = getObject("leaderboards_btn", lbWrapObj)
    if (btnLb != null)
      btnLb.show(false)
    let lbTable = getObject("lb_table", lbWrapObj)
    if (lbTable != null)
      lbTable.show(false)
    let lbWaitBox = getObject("msgWaitAnimation")
    if (lbWaitBox != null)
      lbWaitBox.show(showWaitBox)
  }

  function getFullRoomData()
  {
    return room && ::g_mroom_info.get(room.roomId).getFullRoomData()
  }

  function onEventMRoomInfoUpdated(p)
  {
    if (room && p.roomId == room.roomId && !::u.isEqual(currentFullRoomData, getFullRoomData()))
      updateContent()
  }
}
