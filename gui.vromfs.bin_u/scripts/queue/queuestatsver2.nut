from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

::queue_stats_versions.StatsVer2 <- class extends ::queue_stats_versions.Base
{
  neutralTeamId = ::get_team_name_by_mp_team(MP_TEAM_NEUTRAL)
  static fullTeamNamesList = [
    ::get_team_name_by_mp_team(MP_TEAM_NEUTRAL)
    ::get_team_name_by_mp_team(MP_TEAM_A)
    ::get_team_name_by_mp_team(MP_TEAM_B)
  ]

  function applyQueueInfo(queueInfo)
  {
    if (!("queueId" in queueInfo) || !("cluster" in queueInfo))
      return false

    if ((!this.isClanStats && !("byTeams" in queueInfo))
        || (this.isClanStats && !("byClans" in queueInfo)))
      return false

    let cluster = queueInfo.cluster
    if (!(cluster in this.source))
      this.source[cluster] <- {}

    this.source[cluster][queueInfo.queueId] <- queueInfo
    this.resetCache()
    return true
  }

  function calcQueueTable()
  {
    this.teamsQueueTable = {}
    this.countriesQueueTable = {}
    this.maxClusterName = ""

    local playersOnMaxCluster = -1
    foreach(cluster, statsByQueueId in this.source)
    {
      this.gatherClusterData(cluster, statsByQueueId)
      if (cluster in this.teamsQueueTable)
      {
        let playersCount = this.teamsQueueTable[cluster].playersCount
        if (playersCount > playersOnMaxCluster)
        {
          this.maxClusterName = cluster
          playersOnMaxCluster = playersCount
          this.isSymmetric = this.teamsQueueTable[cluster].isSymmetric //set symmetric by max queue symmetric
        }
      }
    }
  }

  //return player count on cluster
  function gatherClusterData(cluster, statsByQueueId)
  {
    let dataByTeams = {
      playersCount = 0
      isSymmetric = false
    }
    let dataByCountries = {}

    foreach(fullStats in statsByQueueId)
    {
      let stats = getTblValue("byTeams", fullStats)
      if (!stats)
        continue

      this.mergeToDataByTeams(dataByTeams, stats)
      this.mergeToDataByCountries(dataByCountries, stats)
    }

    this.teamsQueueTable[cluster] <- dataByTeams
    this.countriesQueueTable[cluster] <- this.remapCountries(dataByCountries) //britain -> country_britain
  }

  function mergeToDataByTeams(dataByTeams, stats)
  {
    let neutralTeamStats = getTblValue(this.neutralTeamId, stats)
    if (neutralTeamStats)
    {
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

  function getCountByRank(statsByCountries, rank)
  {
    local res = 0
    if (!::u.isTable(statsByCountries))
      return res

    let key = rank.tostring()
    foreach(countryTbl in statsByCountries)
      res += this.getCountFromStatTbl(getTblValue(key, countryTbl))
    return res
  }

  function getCountFromStatTbl(statTbl)
  {
    return getTblValue("cnt", statTbl, 0)
  }

  function gatherCountsTblByRanks(statsByCountries)
  {
    let res = {}
    for(local i = 1; i <= ::max_country_rank; i++)
      res[i.tostring()] <- this.getCountByRank(statsByCountries, i)
    res.playersCount <- getTblValue(this.myRankInQueue.tostring(), res, 0)
    return res
  }

  function mergeToDataByCountries(dataByCountries, stats)
  {
    foreach(teamName in this.fullTeamNamesList)
      if (teamName in stats)
        foreach(country, countryStats in stats[teamName])
        {
          if (!(country in dataByCountries))
          {
            dataByCountries[country] <- {}
            for(local i = 1; i <= ::max_country_rank; i++)
              dataByCountries[country][i.tostring()] <- 0
          }
          this.mergeCountryStats(dataByCountries[country], countryStats)
        }
  }

  function mergeCountryStats(fullStats, sourceStats)
  {
    foreach(key, value in fullStats)
      if (key in sourceStats)
        fullStats[key] = max(value, this.getCountFromStatTbl(sourceStats[key]))
  }

  function remapCountries(statsByCountries)
  {
    let res = {}
    foreach(country, data in statsByCountries)
      res["country_" + country] <- data
    return res
  }

  function calcClanQueueTable()
  {
    this.myClanQueueTable = null
    this.clansQueueTable = {}
    foreach(_cluster, statsByQueueId in this.source)
      foreach(stats in statsByQueueId)
        if (this.gatherClansData(stats))
          break //clans are multiclusters always. so no need to try merge this data
  }

  function gatherClansData(stats)
  {
    let statsByClans = getTblValue("byClans", stats)
    if (::u.isEmpty(statsByClans))
      return false

    let myClanInfo = getTblValue(::clan_get_my_clan_tag(), statsByClans)
    if (myClanInfo)
      this.myClanQueueTable = clone myClanInfo


    foreach(_clanTag, clanStats in statsByClans)
      this.clansQueueTable = ::u.tablesCombine(
        this.clansQueueTable,
        clanStats,
        @(sumClans, clanPlayers) sumClans + (clanPlayers ? 1 : 0),
        0
      )

    this.clansQueueTable.clansCount <- statsByClans.len()
    return true
  }
}