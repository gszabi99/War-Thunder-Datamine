from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

//to allow to able temporary handle different stats versions at once
//before new one completely applied to all circuits
::queue_stats_versions <- {}

const MULTICLUSTER_NAME = "multi"

::queue_stats_versions.Base <- class
{
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

  constructor(queue)
  {
    local queueEvent = ::queues.getQueueEvent(queue)
    isClanStats = ::queues.isClanQueue(queue)
    isMultiCluster = isClanStats || ::events.isMultiCluster(queueEvent)
    isSymmetric = isClanStats
    myRankInQueue = ::queues.getMyRankInQueue(queue)

    source = {}
    init(queue)
  }

  function init(queue) {}

  /*************************************************************************************************/
  /*************************************PUBLIC FUNCTIONS *******************************************/
  /*************************************************************************************************/

  function applyQueueInfo(queueInfo)
  {
    source = queueInfo
    resetCache()
    return false
  }

  function getMaxClusterName()
  {
    recountQueueOnce()
    return maxClusterName
  }

  function getTeamsQueueTable(cluster = null)
  {
    recountQueueOnce()
    if (isMultiCluster)
      cluster = MULTICLUSTER_NAME
    return getTblValue(cluster || maxClusterName, teamsQueueTable)
  }

  function getQueueTableByTeam(teamName, cluster = null)
  {
    return getTblValue(teamName, getTeamsQueueTable(cluster))
  }

  function getPlayersCountByTeam(teamName, cluster = null)
  {
    return getTblValue("playersCount", getQueueTableByTeam(teamName, cluster), 0)
  }

  function getPlayersCountOfAllRanks(cluster = null)
  {
    local res = 0
    let teamQueueTable = getQueueTableByTeam("teamA", cluster)
    for(local i = 1; i <= ::max_country_rank; i++)
      res += teamQueueTable?[i.tostring()] ?? 0

    return res
  }

  function getPlayersCountOfMyRank(cluster = null)
  {
    let rankStr = myRankInQueue.tostring()
    if (isSymmetric)
      return getTblValue(rankStr, getQueueTableByTeam("teamA", cluster), 0)

    local res = 0
    foreach(teamName in teamNamesList)
      res += getTblValue(rankStr, getQueueTableByTeam(teamName, cluster), 0)
    return res
  }

  function getCountriesQueueTable(cluster = null)
  {
    recountQueueOnce()
    if (isMultiCluster)
      cluster = MULTICLUSTER_NAME
    return getTblValue(cluster || maxClusterName, countriesQueueTable)
  }

  //for clans queues
  function getClansCount()
  {
    return getTblValue("clansCount", getClansQueueTable(), 0)
  }

  function getMyClanQueueTable()
  {
    recountQueueOnce()
    return myClanQueueTable
  }

  function getClansQueueTable()
  {
    recountQueueOnce()
    return clansQueueTable
  }

  /*************************************************************************************************/
  /************************************PRIVATE FUNCTIONS *******************************************/
  /*************************************************************************************************/

  function resetCache()
  {
    isStatsCounted = false
  }

  function recountQueueOnce()
  {
    if (isStatsCounted)
      return

    isStatsCounted = true
    if (isClanStats)
      calcClanQueueTable()
    else
      calcQueueTable()
  }

  function calcQueueTable()
  {
    maxClusterName = ""
    teamsQueueTable = {}
    countriesQueueTable = {}
  }

  function calcClanQueueTable()
  {
    myClanQueueTable = null
    clansQueueTable = {}
  }
}