from "%scripts/dagui_natives.nut" import clan_get_my_clan_tag
from "%scripts/dagui_library.nut" import *

let { get_team_name_by_mp_team } = require("%appGlobals/ranks_common_shared.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { MAX_COUNTRY_RANK } = require("%scripts/ranks.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { deferOnce } = require("dagor.workcycle")

const MULTICLUSTER_NAME = "multi"

let neutralTeamName = get_team_name_by_mp_team(MP_TEAM_NEUTRAL)
let teamAName = get_team_name_by_mp_team(MP_TEAM_A)
let teamBName = get_team_name_by_mp_team(MP_TEAM_B)

let fullTeamNamesList = [neutralTeamName, teamAName, teamBName]
let teamNamesList = [teamAName, teamBName]

let callEventQueueStatsClusterAdded = @() broadcastEvent("QueueStatsClusterAdded")

class QueueStats {
  isClanStats = false
  isSymmetric = false
  isMultiCluster = false
  myRankInQueue = 0
  source = null

  isStatsCounted = false
  maxClusterName = ""

  teamsQueueTable = null
  /*
  teamsQueueTable = {
    [cluster] = {
      playersCount = <total players>
      TeamA = { "<rank>" = <players>, playersCount = <total team players> }
      TeamB = { "<rank>" = <players>, playersCount = <total team players> }
    }
  }
  */

  countriesQueueTable = null
  /*
  countriesQueueTable = {
    [cluster] = {
      <country name> = {
        "<rank>" = <players>
      }
    }
  }
  */

  myClanQueueTable = null
  /*
  myClanQueueTable = { "<rank>" = <players> }
  */

  clansQueueTable = null
  /*
  myClanQueueTable = { "<rank>" = <clans>, clansCount = <total clans> }
  */

  constructor(queue) {
    local queueEvent = ::queues.getQueueEvent(queue)
    this.isClanStats = ::queues.isClanQueue(queue)
    this.isMultiCluster = this.isClanStats || ::events.isMultiCluster(queueEvent)
    this.isSymmetric = this.isClanStats
    this.myRankInQueue = ::queues.getMyRankInQueue(queue)

    this.source = {}
  }

  /*************************************************************************************************/
  /*************************************PUBLIC FUNCTIONS *******************************************/
  /*************************************************************************************************/

  function applyQueueInfo(queueInfo) {
    if (!("queueId" in queueInfo) || !("cluster" in queueInfo))
      return false

    if ((!this.isClanStats && !("byTeams" in queueInfo))
        || (this.isClanStats && !("byClans" in queueInfo)))
      return false

    local needEventClusterAdded = false
    let cluster = queueInfo.cluster
    if (!(cluster in this.source)) {
      needEventClusterAdded = true
      this.source[cluster] <- {}
    }

    this.source[cluster][queueInfo.queueId] <- queueInfo
    this.resetCache()
    if (needEventClusterAdded)
      deferOnce(callEventQueueStatsClusterAdded)
    return true
  }

  function getMaxClusterName() {
    this.recountQueueOnce()
    return this.maxClusterName
  }

  function getTeamsQueueTable(cluster = null) {
    this.recountQueueOnce()
    if (this.isMultiCluster)
      cluster = MULTICLUSTER_NAME
    return getTblValue(cluster || this.maxClusterName, this.teamsQueueTable)
  }

  function getQueueTableByTeam(teamName, cluster = null) {
    return getTblValue(teamName, this.getTeamsQueueTable(cluster))
  }

  function getPlayersCountByTeam(teamName, cluster = null) {
    return getTblValue("playersCount", this.getQueueTableByTeam(teamName, cluster), 0)
  }

  function getPlayersCountOfAllRanks(cluster = null) {
    local res = 0
    let teamQueueTable = this.getQueueTableByTeam("teamA", cluster)
    for (local i = 1; i <= MAX_COUNTRY_RANK; i++)
      res += teamQueueTable?[i.tostring()] ?? 0

    return res
  }

  function getPlayersCountOfMyRank(cluster = null) {
    this.recountQueueOnce()
    let rankStr = this.myRankInQueue.tostring()
    if (this.isSymmetric)
      return getTblValue(rankStr, this.getQueueTableByTeam("teamA", cluster), 0)

    local res = 0
    foreach (teamName in teamNamesList)
      res += getTblValue(rankStr, this.getQueueTableByTeam(teamName, cluster), 0)
    return res
  }

  function getCountriesQueueTable(cluster = null) {
    this.recountQueueOnce()
    if (this.isMultiCluster)
      cluster = MULTICLUSTER_NAME
    return getTblValue(cluster || this.maxClusterName, this.countriesQueueTable)
  }

  //for clans queues
  function getClansCount() {
    return getTblValue("clansCount", this.getClansQueueTable(), 0)
  }

  function getMyClanQueueTable() {
    this.recountQueueOnce()
    return this.myClanQueueTable
  }

  function getClansQueueTable() {
    this.recountQueueOnce()
    return this.clansQueueTable
  }

  getClusters = @() this.source != null ? this.source.keys() : []

  /*************************************************************************************************/
  /************************************PRIVATE FUNCTIONS *******************************************/
  /*************************************************************************************************/

  function calcQueueTable() {
    this.teamsQueueTable = {}
    this.countriesQueueTable = {}
    this.maxClusterName = ""

    local playersOnMaxCluster = -1
    foreach (cluster, statsByQueueId in this.source) {
      this.gatherClusterData(cluster, statsByQueueId)
      if (cluster in this.teamsQueueTable) {
        let playersCount = this.teamsQueueTable[cluster].playersCount
        if (playersCount > playersOnMaxCluster) {
          this.maxClusterName = cluster
          playersOnMaxCluster = playersCount
          this.isSymmetric = this.teamsQueueTable[cluster].isSymmetric //set symmetric by max queue symmetric
        }
      }
    }
  }

  //return player count on cluster
  function gatherClusterData(cluster, statsByQueueId) {
    let dataByTeams = {
      playersCount = 0
      isSymmetric = false
    }
    let dataByCountries = {}

    foreach (fullStats in statsByQueueId) {
      let stats = getTblValue("byTeams", fullStats)
      if (!stats)
        continue

      this.mergeToDataByTeams(dataByTeams, stats)
      this.mergeToDataByCountries(dataByCountries, stats)
    }

    this.teamsQueueTable[cluster] <- dataByTeams
    this.countriesQueueTable[cluster] <- this.remapCountries(dataByCountries) //britain -> country_britain
  }

  function mergeToDataByTeams(dataByTeams, stats) {
    let neutralTeamStats = stats?[neutralTeamName]
    if (neutralTeamStats) {
      let playersCount = this.getCountByRank(neutralTeamStats, this.myRankInQueue)
      if (playersCount <= dataByTeams.playersCount)
        return

      dataByTeams.playersCount <- playersCount
      dataByTeams.teamA <- this.gatherCountsTblByRanks(neutralTeamStats)
      dataByTeams.teamB <- dataByTeams.teamA
      dataByTeams.isSymmetric <- true
      return
    }

    let teamAStats = getTblValue("teamA", stats)
    let teamBStats = getTblValue("teamB", stats)
    let playersCount = this.getCountByRank(teamAStats, this.myRankInQueue)
                       + this.getCountByRank(teamBStats, this.myRankInQueue)
    if (playersCount <= dataByTeams.playersCount)
      return

    dataByTeams.playersCount <- playersCount
    dataByTeams.teamA <- this.gatherCountsTblByRanks(teamAStats)
    dataByTeams.teamB <- this.gatherCountsTblByRanks(teamBStats)
    dataByTeams.isSymmetric <- false
  }

  function getCountByRank(statsByCountries, rank) {
    local res = 0
    if (!u.isTable(statsByCountries))
      return res

    let key = rank.tostring()
    foreach (countryTbl in statsByCountries)
      res += this.getCountFromStatTbl(getTblValue(key, countryTbl))
    return res
  }

  function getCountFromStatTbl(statTbl) {
    return getTblValue("cnt", statTbl, 0)
  }

  function gatherCountsTblByRanks(statsByCountries) {
    let res = {}
    for (local i = 1; i <= MAX_COUNTRY_RANK; i++)
      res[i.tostring()] <- this.getCountByRank(statsByCountries, i)
    res.playersCount <- getTblValue(this.myRankInQueue.tostring(), res, 0)
    return res
  }

  function mergeToDataByCountries(dataByCountries, stats) {
    foreach (teamName in fullTeamNamesList)
      if (teamName in stats)
        foreach (country, countryStats in stats[teamName]) {
          if (!(country in dataByCountries)) {
            dataByCountries[country] <- {}
            for (local i = 1; i <= MAX_COUNTRY_RANK; i++)
              dataByCountries[country][i.tostring()] <- 0
          }
          this.mergeCountryStats(dataByCountries[country], countryStats)
        }
  }

  function mergeCountryStats(fullStats, sourceStats) {
    foreach (key, value in fullStats)
      if (key in sourceStats)
        fullStats[key] = max(value, this.getCountFromStatTbl(sourceStats[key]))
  }

  function remapCountries(statsByCountries) {
    let res = {}
    foreach (country, data in statsByCountries)
      res[$"country_{country}"] <- data
    return res
  }

  function calcClanQueueTable() {
    this.myClanQueueTable = null
    this.clansQueueTable = {}
    foreach (_cluster, statsByQueueId in this.source)
      foreach (stats in statsByQueueId)
        if (this.gatherClansData(stats))
          break //clans are multiclusters always. so no need to try merge this data
  }

  function gatherClansData(stats) {
    let statsByClans = getTblValue("byClans", stats)
    if (u.isEmpty(statsByClans))
      return false

    let myClanInfo = getTblValue(clan_get_my_clan_tag(), statsByClans)
    if (myClanInfo)
      this.myClanQueueTable = clone myClanInfo


    foreach (_clanTag, clanStats in statsByClans)
      this.clansQueueTable = u.tablesCombine(
        this.clansQueueTable,
        clanStats,
        @(sumClans, clanPlayers) sumClans + (clanPlayers ? 1 : 0),
        0
      )

    this.clansQueueTable.clansCount <- statsByClans.len()
    return true
  }

  function resetCache() {
    this.isStatsCounted = false
  }

  function recountQueueOnce() {
    if (this.isStatsCounted)
      return

    this.isStatsCounted = true
    if (this.isClanStats)
      this.calcClanQueueTable()
    else
      this.calcQueueTable()
  }

}

return QueueStats
