//-file:plus-string
from "%scripts/dagui_library.nut" import *
from "%scripts/teamsConsts.nut" import Team

let { getClusterShortName } = require("%scripts/onlineInfo/clustersManagement.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { format } = require("string")

gui_handlers.QiHandlerByTeams <- class (gui_handlers.QiHandlerBase) {
  timerUpdateObjId = "queue_box"
  timerTextObjId = "waitText"

  function updateStats() {
    local myTeamNum = ::queues.getQueueTeam(this.queue)
    if (myTeamNum == Team.Any) {
      let teams = ::events.getAvailableTeams(this.event)
      if (teams.len() == 1)
        myTeamNum = teams[0]
    }

    if (this.event && this.queue.queueStats)
      this.updateQueueStats(::queues.getQueueClusters(this.queue), this.queue.queueStats, myTeamNum)
  }

  function updateQueueStats(clusters, queueStats, myTeamNum) {
    let teams = ::events.getSidesList(this.event)
    foreach (team in ::events.getSidesList()) {
      let show = isInArray(team, teams)
                   && (!queueStats.isSymmetric || team == Team.A)
      let blockObj = this.showSceneBtn(team + "_block", show)
      if (!show)
        continue

      let teamName = ::events.getTeamName(team)
      let teamData = ::events.getTeamData(this.event, team)

      local tableMarkup = ""
      local playersCountText = ""
      local teamColor = ""
      local teamNameLoc = ""

      if (queueStats.isSymmetric)
        teamColor = "any"
      else {
        teamColor = (myTeamNum == Team.Any || team == myTeamNum) ? "blue" : "red"
        teamNameLoc = loc("events/team" + (team == Team.A ? "A" : "B"))
      }

      if (!queueStats.isClanStats) {
        let clusterName = queueStats.getMaxClusterName()
        let players = queueStats.getPlayersCountByTeam(teamName, clusterName)
        if (clusterName == "")
          playersCountText = loc("events/players_count")
        else
          playersCountText = format("%s (%s)",
            loc("events/max_players_count"), getClusterShortName(clusterName))

        playersCountText += loc("ui/colon") + players
        tableMarkup = this.getQueueTableMarkup(queueStats, teamName, clusters)
      }
      else {
        playersCountText = loc("events/clans_count") + loc("ui/colon") + queueStats.getClansCount()
        tableMarkup = this.getClanQueueTableMarkup(queueStats)
      }

      this.fillQueueTeam(blockObj,
                    teamData,
                    tableMarkup,
                    playersCountText,
                    teamColor,
                    teamNameLoc)
    }
  }

  function fillQueueTeam(teamObj, teamData, tableMarkup, playersCountText,  teamColor = "any", teamName = "") {
    if (!checkObj(teamObj))
      return

    teamObj.bgTeamColor = teamColor
    teamObj.show(!!(teamData && teamData.len()))
    ::fillCountriesList(teamObj.findObject("countries"), ::events.getCountries(teamData))
    teamObj.findObject("team_name").setValue(teamName)
    teamObj.findObject("players_count").setValue(playersCountText)

    let queueTableObj = teamObj.findObject("table_queue_stat")
    if (!checkObj(queueTableObj))
      return
    this.guiScene.replaceContentFromText(queueTableObj, tableMarkup, tableMarkup.len(), this)
  }

  function getQueueTableMarkup(queueStats, teamName, clusters) {
    local res = this.buildQueueStatsHeader()
    let rowParams = "inactive:t='yes'; commonTextColor:t='yes';"

    if (queueStats.isMultiCluster) {
      let maxCluster = queueStats.getMaxClusterName()
      let teamStats = queueStats.getQueueTableByTeam(teamName, maxCluster)
      let rowData = this.buildQueueStatsRowData(teamStats)
      res += ::buildTableRow("", rowData, 0, rowParams, "0")
      return res
    }

    foreach (clusterName in clusters) {
      let teamStats = queueStats.getQueueTableByTeam(teamName, clusterName)
      let rowData = this.buildQueueStatsRowData(teamStats, getClusterShortName(clusterName))
      res += ::buildTableRow("", rowData, 0, rowParams, "0")
    }
    return res
  }

  function getClanQueueTableMarkup(queueStats) {
    let totalClans = queueStats.getClansCount()
    if (!totalClans)
      return ""

    local res = this.buildQueueStatsHeader()
    let rowParams = "inactive:t='yes'; commonTextColor:t='yes';"

    let myClanQueueTable = queueStats.getMyClanQueueTable()
    if (myClanQueueTable) {
      let headerData = [{
        text = loc("multiplayer/playersInYourClan")
        width = "0.1@sf"
      }]
      res += ::buildTableRow("", headerData, null, rowParams, "0")

      let rowData = this.buildQueueStatsRowData(myClanQueueTable)
      res += ::buildTableRow("", rowData, null, rowParams, "0")
    }

    let headerData = [{
      text = loc("multiplayer/clansInQueue")
      width = "0.1@sf"
    }]
    res += ::buildTableRow("", headerData, null, rowParams, "0")

    let rowData = this.buildQueueStatsRowData(queueStats.getClansQueueTable())
    res += ::buildTableRow("", rowData, null, rowParams, "0")
    return res
  }

  function buildQueueStatsRowData(queueStatData, clusterNameLoc = "") {
    let params = []
    params.append({
                    text = clusterNameLoc
                    tdalign = "center"
                    width = "0.4pw"
                 })

    for (local i = 1; i <= ::max_country_rank; i++) {
      params.append({
        text = getTblValue(i.tostring(), queueStatData, 0).tostring()
        tdalign = "center"
      })
    }
    return params
  }

  function buildQueueStatsHeader() {
    let headerData = []
    for (local i = 0; i <= ::max_country_rank; i++) {
      headerData.append({
        text = get_roman_numeral(i)
        tdalign = "center"
      })
    }
    return ::buildTableRow("", headerData, 0, "inactive:t='yes'; commonTextColor:t='yes';", "0")
  }
}