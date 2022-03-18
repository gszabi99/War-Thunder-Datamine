::queue_stats_versions.StatsVer2 <- class extends ::queue_stats_versions.Base
{
  neutralTeamId = ::get_team_name_by_mp_team(::MP_TEAM_NEUTRAL)
  static fullTeamNamesList = [
    ::get_team_name_by_mp_team(::MP_TEAM_NEUTRAL)
    ::get_team_name_by_mp_team(::MP_TEAM_A)
    ::get_team_name_by_mp_team(::MP_TEAM_B)
  ]

  function applyQueueInfo(queueInfo)
  {
    if (!("queueId" in queueInfo) || !("cluster" in queueInfo))
      return false

    if ((!isClanStats && !("byTeams" in queueInfo))
        || (isClanStats && !("byClans" in queueInfo)))
      return false

    let cluster = queueInfo.cluster
    if (!(cluster in source))
      source[cluster] <- {}

    source[cluster][queueInfo.queueId] <- queueInfo
    resetCache()
    return true
  }

  function calcQueueTable()
  {
    teamsQueueTable = {}
    countriesQueueTable = {}
    maxClusterName = ""

    local playersOnMaxCluster = -1
    foreach(cluster, statsByQueueId in source)
    {
      gatherClusterData(cluster, statsByQueueId)
      if (cluster in teamsQueueTable)
      {
        let playersCount = teamsQueueTable[cluster].playersCount
        if (playersCount > playersOnMaxCluster)
        {
          maxClusterName = cluster
          playersOnMaxCluster = playersCount
          isSymmetric = teamsQueueTable[cluster].isSymmetric //set symmetric by max queue symmetric
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
      let stats = ::getTblValue("byTeams", fullStats)
      if (!stats)
        continue

      mergeToDataByTeams(dataByTeams, stats)
      mergeToDataByCountries(dataByCountries, stats)
    }

    teamsQueueTable[cluster] <- dataByTeams
    countriesQueueTable[cluster] <- remapCountries(dataByCountries) //britain -> country_britain
  }

  function mergeToDataByTeams(dataByTeams, stats)
  {
    let neutralTeamStats = ::getTblValue(neutralTeamId, stats)
    if (neutralTeamStats)
    {
      let playersCount = getCountByRank(neutralTeamStats, myRankInQueue)
      if (playersCount <= dataByTeams.playersCount)
        return

      dataByTeams.playersCount <- playersCount
      dataByTeams.teamA <- gatherCountsTblByRanks(neutralTeamStats)
      dataByTeams.teamB <- dataByTeams.teamA
      dataByTeams.isSymmetric <- true
      return
    }

    let teamAStats = ::getTblValue("teamA", stats)
    let teamBStats = ::getTblValue("teamB", stats)
    let playersCount = getCountByRank(teamAStats, myRankInQueue)
                       + getCountByRank(teamBStats, myRankInQueue)
    if (playersCount <= dataByTeams.playersCount)
      return

    dataByTeams.playersCount <- playersCount
    dataByTeams.teamA <- gatherCountsTblByRanks(teamAStats)
    dataByTeams.teamB <- gatherCountsTblByRanks(teamBStats)
    dataByTeams.isSymmetric <- false
  }

  function getCountByRank(statsByCountries, rank)
  {
    local res = 0
    if (!::u.isTable(statsByCountries))
      return res

    let key = rank.tostring()
    foreach(countryTbl in statsByCountries)
      res += getCountFromStatTbl(::getTblValue(key, countryTbl))
    return res
  }

  function getCountFromStatTbl(statTbl)
  {
    return ::getTblValue("cnt", statTbl, 0)
  }

  function gatherCountsTblByRanks(statsByCountries)
  {
    let res = {}
    for(local i = 1; i <= ::max_country_rank; i++)
      res[i.tostring()] <- getCountByRank(statsByCountries, i)
    res.playersCount <- ::getTblValue(myRankInQueue.tostring(), res, 0)
    return res
  }

  function mergeToDataByCountries(dataByCountries, stats)
  {
    foreach(teamName in fullTeamNamesList)
      if (teamName in stats)
        foreach(country, countryStats in stats[teamName])
        {
          if (!(country in dataByCountries))
          {
            dataByCountries[country] <- {}
            for(local i = 1; i <= ::max_country_rank; i++)
              dataByCountries[country][i.tostring()] <- 0
          }
          mergeCountryStats(dataByCountries[country], countryStats)
        }
  }

  function mergeCountryStats(fullStats, sourceStats)
  {
    foreach(key, value in fullStats)
      if (key in sourceStats)
        fullStats[key] = ::max(value, getCountFromStatTbl(sourceStats[key]))
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
    myClanQueueTable = null
    clansQueueTable = {}
    foreach(cluster, statsByQueueId in source)
      foreach(stats in statsByQueueId)
        if (gatherClansData(stats))
          break //clans are multiclusters always. so no need to try merge this data
  }

  function gatherClansData(stats)
  {
    let statsByClans = ::getTblValue("byClans", stats)
    if (::u.isEmpty(statsByClans))
      return false

    let myClanInfo = ::getTblValue(::clan_get_my_clan_tag(), statsByClans)
    if (myClanInfo)
      myClanQueueTable = clone myClanInfo


    foreach(clanTag, clanStats in statsByClans)
      clansQueueTable = ::u.tablesCombine(
        clansQueueTable,
        clanStats,
        @(sumClans, clanPlayers) sumClans + (clanPlayers ? 1 : 0),
        0
      )

    clansQueueTable.clansCount <- statsByClans.len()
    return true
  }
}