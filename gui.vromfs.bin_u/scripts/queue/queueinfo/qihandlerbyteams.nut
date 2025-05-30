from "%scripts/dagui_library.nut" import *
from "%scripts/teamsConsts.nut" import Team
from "%scripts/utils_sa.nut" import buildTableRow

let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let { getClusterShortName } = require("%scripts/onlineInfo/clustersManagement.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { format } = require("string")
let { MAX_COUNTRY_RANK } = require("%scripts/ranks.nut")
let { fillCountriesList } = require("%scripts/matchingRooms/fillCountriesList.nut")
let { getQueueTeam, getQueueClusters } = require("%scripts/queue/queueInfo.nut")
let { getCustomViewCountryData, isTeamSizeBalancedEvent } = require("%scripts/events/eventInfo.nut")

gui_handlers.QiHandlerByTeams <- class (gui_handlers.QiHandlerBase) {
  timerUpdateObjId = "queue_box"
  timerTextObjId = "waitText"

  function updateStats() {
    local myTeamNum = getQueueTeam(this.queue)
    if (myTeamNum == Team.Any) {
      let teams = events.getAvailableTeams(this.event)
      if (teams.len() == 1)
        myTeamNum = teams[0]
    }

    if (this.event && this.queue.queueStats)
      this.updateQueueStats(getQueueClusters(this.queue), this.queue.queueStats, myTeamNum)
  }

  function updateQueueStats(clusters, queueStats, myTeamNum) {
    let teams = events.getSidesList(this.event)
    foreach (team in events.getSidesList()) {
      let show = isInArray(team, teams)
                   && (!queueStats.isSymmetric || team == Team.A)
      let blockObj = showObjById($"{team}_block", show, this.scene)
      if (!show)
        continue

      let teamName = events.getTeamName(team)
      let teamData = events.getTeamData(this.event, team)

      local tableMarkup = ""
      local playersCountText = ""
      local teamColor = ""
      local teamNameLoc = ""

      if (queueStats.isSymmetric)
        teamColor = "any"
      else {
        teamColor = (myTeamNum == Team.Any || team == myTeamNum) ? "blue" : "red"
        teamNameLoc = loc($"events/team{team == Team.A ? "A" : "B"}")
      }

      let onlyOwnRankCount = !isTeamSizeBalancedEvent(this.event)
      if (!queueStats.isClanStats) {
        let clusterName = queueStats.getClusterWithMaxPlayers(teamName, onlyOwnRankCount)
        let players = queueStats.getPlayersCountByTeam(teamName, clusterName, onlyOwnRankCount)
        if (clusterName == "")
          playersCountText = loc("events/players_count")
        else
          playersCountText = format("%s (%s)",
            loc("events/max_players_count"), getClusterShortName(clusterName))

        playersCountText = loc("ui/colon").concat(playersCountText, players)
        tableMarkup = this.getQueueTableMarkup(queueStats, teamName, clusters)
      }
      else {
        playersCountText = loc("ui/colon").concat(loc("events/clans_count"), queueStats.getClansCount())
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

  function fillQueueTeam(teamObj, teamData, tableMarkup, playersCountText, teamColor = "any", teamName = "") {
    if (!checkObj(teamObj))
      return

    teamObj.bgTeamColor = teamColor
    let isShowTeamData = !!(teamData && teamData.len())
    teamObj.show(isShowTeamData)
    if (!isShowTeamData)
      return

    fillCountriesList(teamObj.findObject("countries"), events.getCountries(teamData),
      getCustomViewCountryData(this.event))
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
      let onlyOwnRankCount = !isTeamSizeBalancedEvent(this.event)
      let maxCluster = queueStats.getClusterWithMaxPlayers(teamName, onlyOwnRankCount)
      let teamStats = queueStats.getQueueTableByTeam(teamName, maxCluster)
      let rowData = this.buildQueueStatsRowData(teamStats)
      res = "".concat(res, buildTableRow("", rowData, 0, rowParams, "0"))
      return res
    }

    foreach (clusterName in clusters) {
      let teamStats = queueStats.getQueueTableByTeam(teamName, clusterName)
      let rowData = this.buildQueueStatsRowData(teamStats, getClusterShortName(clusterName))
      res = "".concat(res, buildTableRow("", rowData, 0, rowParams, "0"))
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
      res = "".concat(res, buildTableRow("", headerData, null, rowParams, "0"))

      let rowData = this.buildQueueStatsRowData(myClanQueueTable)
      res = "".concat(res, buildTableRow("", rowData, null, rowParams, "0"))
    }

    let headerData = [{
      text = loc("multiplayer/clansInQueue")
      width = "0.1@sf"
    }]
    res = "".concat(res, buildTableRow("", headerData, null, rowParams, "0"))

    let rowData = this.buildQueueStatsRowData(queueStats.getClansQueueTable())
    res = "".concat(res, buildTableRow("", rowData, null, rowParams, "0"))
    return res
  }

  function buildQueueStatsRowData(queueStatData, clusterNameLoc = "") {
    let params = []
    params.append({
                    text = clusterNameLoc
                    tdalign = "center"
                    width = "0.4pw"
                 })

    for (local i = 1; i <= MAX_COUNTRY_RANK; i++) {
      params.append({
        text = getTblValue(i.tostring(), queueStatData, 0).tostring()
        tdalign = "center"
      })
    }
    return params
  }

  function buildQueueStatsHeader() {
    let headerData = []
    for (local i = 0; i <= MAX_COUNTRY_RANK; i++) {
      headerData.append({
        text = get_roman_numeral(i)
        tdalign = "center"
      })
    }
    return buildTableRow("", headerData, 0, "inactive:t='yes'; commonTextColor:t='yes';", "0")
  }
}