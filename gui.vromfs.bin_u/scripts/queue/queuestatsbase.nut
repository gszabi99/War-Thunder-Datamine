from "%scripts/dagui_library.nut" import *


//to allow to able temporary handle different stats versions at once
//before new one completely applied to all circuits
::queue_stats_versions <- {}

const MULTICLUSTER_NAME = "multi"

::queue_stats_versions.Base <- class {
  isClanStats = false
  isSymmetric = false
  isMultiCluster = false
  myRankInQueue = 0
  source = null

  static teamNamesList = ["teamA", "teamB"]

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
    this.init(queue)
  }

  function init(_queue) {}

  /*************************************************************************************************/
  /*************************************PUBLIC FUNCTIONS *******************************************/
  /*************************************************************************************************/

  function applyQueueInfo(queueInfo) {
    this.source = queueInfo
    this.resetCache()
    return false
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
    for (local i = 1; i <= ::max_country_rank; i++)
      res += teamQueueTable?[i.tostring()] ?? 0

    return res
  }

  function getPlayersCountOfMyRank(cluster = null) {
    this.recountQueueOnce()
    let rankStr = this.myRankInQueue.tostring()
    if (this.isSymmetric)
      return getTblValue(rankStr, this.getQueueTableByTeam("teamA", cluster), 0)

    local res = 0
    foreach (teamName in this.teamNamesList)
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

  /*************************************************************************************************/
  /************************************PRIVATE FUNCTIONS *******************************************/
  /*************************************************************************************************/

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

  function calcQueueTable() {
    this.maxClusterName = ""
    this.teamsQueueTable = {}
    this.countriesQueueTable = {}
  }

  function calcClanQueueTable() {
    this.myClanQueueTable = null
    this.clansQueueTable = {}
  }
}