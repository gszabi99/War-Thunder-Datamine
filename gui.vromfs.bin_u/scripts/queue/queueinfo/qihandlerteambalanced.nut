from "%scripts/dagui_library.nut" import *
from "%scripts/teamsConsts.nut" import Team
from "%scripts/utils_sa.nut" import buildTableRow

let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let { getClusterShortName } = require("%scripts/onlineInfo/clustersManagement.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { fillCountriesList } = require("%scripts/matchingRooms/fillCountriesList.nut")
let { getQueueTeam, getQueueClusters } = require("%scripts/queue/queueInfo.nut")
let { getCustomViewCountryData } = require("%scripts/events/eventInfo.nut")

gui_handlers.QiHandlerTeamBalanced <- class (gui_handlers.QiHandlerBase) {
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
    let sidesList = events.getSidesList()
    foreach (team in sidesList) {
      let teamData = events.getTeamData(this.event, team)
      let isShowTeamData = !!(teamData && teamData.len())
      let show = isInArray(team, teams)
        && (!queueStats.isSymmetric || team == Team.A) && isShowTeamData

      let blockObj = showObjById($"{team}_block", show, this.scene)
      if (!show || !(blockObj?.isValid() ?? false))
        continue

      let teamName = events.getTeamName(team)
      local teamColor = ""
      local teamNameLoc = ""

      if (queueStats.isSymmetric)
        teamColor = "any"
      else {
        teamColor = (myTeamNum == Team.Any || team == myTeamNum) ? "blue" : "red"
        teamNameLoc = loc($"events/team{team == Team.A ? "A" : "B"}")
      }

      let tableMarkup = this.getQueueTableMarkup(queueStats, teamName, clusters)
      this.fillQueueTeam(blockObj,
        teamData,
        tableMarkup,
        teamColor,
        teamNameLoc)
    }
  }

  function fillQueueTeam(teamObj, teamData, tableMarkup, teamColor = "any", teamName = "") {
    teamObj.bgTeamColor = teamColor
    fillCountriesList(teamObj.findObject("countries"), events.getCountries(teamData),
      getCustomViewCountryData(this.event))
    teamObj.findObject("team_name").setValue(teamName)
    teamObj.findObject("players_count").show(false)

    let queueTableObj = teamObj.findObject("table_queue_stat")
    if (!queueTableObj.isValid())
      return
    this.guiScene.replaceContentFromText(queueTableObj, tableMarkup, tableMarkup.len(), this)
  }

  function getQueueTableMarkup(queueStats, teamName, clusters) {
    local res = ""
    let rowParams = "inactive:t='yes'; commonTextColor:t='yes';"

    if (queueStats.isMultiCluster) {
      let maxCluster = queueStats.getClusterWithMaxPlayers(teamName, false)
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

  function buildQueueStatsRowData(queueStatData, clusterNameLoc = "") {
    let params = [
      {
        text = clusterNameLoc
        tdalign = "center"
        width = "0.4pw"
      },
      {
        text = (queueStatData?.playersCount ?? 0).tostring()
        tdalign = "center"
      }
    ]
    return params
  }
}