class ::gui_handlers.QiHandlerByTeams extends ::gui_handlers.QiHandlerBase
{
  timerUpdateObjId = "queue_box"
  timerTextObjId = "waitText"

  function updateStats()
  {
    local myTeamNum = ::queues.getQueueTeam(queue)
    if (myTeamNum == Team.Any)
    {
      local teams = ::events.getAvailableTeams(event)
      if (teams.len() == 1)
        myTeamNum = teams[0]
    }

    if (event && queue.queueStats)
      updateQueueStats(::queues.getQueueClusters(queue), queue.queueStats, myTeamNum)
  }

  function updateQueueStats(clusters, queueStats, myTeamNum)
  {
    local teams = ::events.getSidesList(event)
    foreach(team in ::events.getSidesList())
    {
      local show = ::isInArray(team, teams)
                   && (!queueStats.isSymmetric || team == Team.A)
      local blockObj = showSceneBtn(team + "_block", show)
      if (!show)
        continue

      local teamName = ::events.getTeamName(team)
      local teamData = ::events.getTeamData(event, team)

      local tableMarkup = ""
      local playersCountText = ""
      local teamColor = ""
      local teamNameLoc = ""

      if (queueStats.isSymmetric)
        teamColor = "any"
      else
      {
        teamColor = (myTeamNum == Team.Any || team == myTeamNum) ? "blue" : "red"
        teamNameLoc = ::loc("events/team" + (team == Team.A ? "A" : "B"))
      }

      if (!queueStats.isClanStats)
      {
        local clusterName = queueStats.getMaxClusterName()
        local players = queueStats.getPlayersCountByTeam(teamName, clusterName)
        if (clusterName == "")
          playersCountText = ::loc("events/players_count")
        else
          playersCountText = ::format("%s (%s)", ::loc("events/max_players_count"),
                                      ::g_clusters.getClusterLocName(clusterName))
        playersCountText += ::loc("ui/colon") + players
        tableMarkup = getQueueTableMarkup(queueStats, teamName, clusters)
      }
      else
      {
        playersCountText = ::loc("events/clans_count") + ::loc("ui/colon") + queueStats.getClansCount()
        tableMarkup = getClanQueueTableMarkup(queueStats)
      }

      fillQueueTeam(blockObj,
                    teamData,
                    tableMarkup,
                    playersCountText,
                    teamColor,
                    teamNameLoc)
    }
  }

  function fillQueueTeam(teamObj, teamData, tableMarkup, playersCountText , teamColor = "any", teamName = "")
  {
    if (!checkObj(teamObj))
      return

    teamObj.bgTeamColor = teamColor
    teamObj.show(!!(teamData && teamData.len()))
    fillCountriesList(teamObj.findObject("countries"), ::events.getCountries(teamData))
    teamObj.findObject("team_name").setValue(teamName)
    teamObj.findObject("players_count").setValue(playersCountText)

    local queueTableObj = teamObj.findObject("table_queue_stat")
    if (!::checkObj(queueTableObj))
      return
    guiScene.replaceContentFromText(queueTableObj, tableMarkup, tableMarkup.len(), this)
  }

  function getQueueTableMarkup(queueStats, teamName, clusters)
  {
    local res = buildQueueStatsHeader()
    local rowParams = "inactive:t='yes'; commonTextColor:t='yes';"

    if (queueStats.isMultiCluster)
    {
      local maxCluster = queueStats.getMaxClusterName()
      local teamStats = queueStats.getQueueTableByTeam(teamName, maxCluster)
      local rowData = buildQueueStatsRowData(teamStats)
      res += ::buildTableRow("", rowData, 0, rowParams, "0")
      return res
    }

    foreach (clusterName in clusters)
    {
      local teamStats = queueStats.getQueueTableByTeam(teamName, clusterName)
      local rowData = buildQueueStatsRowData(teamStats, ::g_clusters.getClusterLocName(clusterName))
      res += ::buildTableRow("", rowData, 0, rowParams, "0")
    }
    return res
  }

  function getClanQueueTableMarkup(queueStats)
  {
    local totalClans = queueStats.getClansCount()
    if (!totalClans)
      return ""

    local res = buildQueueStatsHeader()
    local rowParams = "inactive:t='yes'; commonTextColor:t='yes';"

    local myClanQueueTable = queueStats.getMyClanQueueTable()
    if (myClanQueueTable)
    {
      local headerData = [{
        text = ::loc("multiplayer/playersInYourClan")
        width = "0.1@sf"
      }]
      res += ::buildTableRow("", headerData, null, rowParams, "0")

      local rowData = buildQueueStatsRowData(myClanQueueTable)
      res += ::buildTableRow("", rowData, null, rowParams, "0")
    }

    local headerData = [{
      text = ::loc("multiplayer/clansInQueue")
      width = "0.1@sf"
    }]
    res += ::buildTableRow("", headerData, null, rowParams, "0")

    local rowData = buildQueueStatsRowData(queueStats.getClansQueueTable())
    res += ::buildTableRow("", rowData, null, rowParams, "0")
    return res
  }

  function buildQueueStatsRowData(queueStatData, clusterNameLoc = "")
  {
    local params = []
    params.append({
                    text = clusterNameLoc
                    tdAlign = "center"
                    width="0.4pw"
                 })

    for(local i = 1; i <= ::max_country_rank; i++)
    {
      params.append({
        text = ::getTblValue(i.tostring(), queueStatData, 0).tostring()
        tdAlign = "center"
      })
    }
    return params
  }

  function buildQueueStatsHeader()
  {
    local headerData = []
    for(local i = 0; i <= ::max_country_rank; i++)
    {
      headerData.append({
        text = ::get_roman_numeral(i)
        tdAlign = "center"
      })
    }
    return ::buildTableRow("", headerData, 0, "inactive:t='yes'; commonTextColor:t='yes';", "0")
  }
}