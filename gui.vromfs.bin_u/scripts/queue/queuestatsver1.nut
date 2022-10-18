::queue_stats_versions.StatsVer1 <- class extends ::queue_stats_versions.Base
{
  queueWeak = null //need to able recalc some stats and convertion to countries list from teams list

  function init(queue)
  {
    queueWeak = queue.weakref()
  }

  function applyQueueInfo(queueInfo)
  {
    if (!source.len())
      isSymmetric = isSymmetric || ::getTblValue("symmetric", queueInfo, false)
    source[queueInfo.cluster] <- queueInfo
    resetCache()
    return true
  }

  function calcQueueTable()
  {
    teamsQueueTable = {}
    countriesQueueTable = {}
    maxClusterName = ""
    local playersOnMaxCluster = -1
    let event = queueWeak && ::queues.getQueueEvent(queueWeak)

    foreach(cluster, queueInfo in source)
    {
      let infoByTeams = {}
      local playersCount = 0
      foreach(teamName in teamNamesList)
      {
        infoByTeams[teamName] <- gatherTeamStats(::getTblValue(teamName, queueInfo))
        playersCount += infoByTeams[teamName].playersCount
      }
      infoByTeams.playersCount <- playersCount

      if (playersCount > playersOnMaxCluster)
      {
        maxClusterName = cluster
        playersOnMaxCluster = playersCount
      }

      teamsQueueTable[cluster] <- infoByTeams
      if (event)
        countriesQueueTable[cluster] <- calcCountriesTableByQueueInfo(infoByTeams, event)
    }
  }

  function gatherTeamStats(queueInfoTeam)
  {
    let res = { playersCount = 0 }
    if (!queueInfoTeam)
      return res

    let tiers = ::getTblValue("tiers", queueInfoTeam)
    if (tiers)
      foreach(rank, value in tiers)
        res[rank] <- value

    res.playersCount <- ::getTblValue("players_cnt", queueInfoTeam, 0)
    return res
  }

  function calcClanQueueTable()
  {
    myClanQueueTable = null
    clansQueueTable = {}
    foreach(cluster, queueInfo in source)
      if (gatherClansData(queueInfo))
        break //clans are multiclusters always. so no need to try merge this data
  }

  function gatherClansData(queueInfo)
  {
    let teamInfo = ::getTblValue("teamA", queueInfo) //clans are symmetric, so all data in teamA
    let clansList = ::getTblValue("clans", teamInfo)
    if (!clansList)
      return false

    let myClanInfo = ::getTblValue(::clan_get_my_clan_tag(), clansList)
    if (myClanInfo)
      myClanQueueTable = clone myClanInfo


    foreach(clanTag, clanData in clansList)
      clansQueueTable = ::u.tablesCombine(
        clansQueueTable,
        clanData,
        @(sumClans, clanPlayers) sumClans + (clanPlayers ? 1 : 0),
        0
      )

    clansQueueTable.clansCount <- clansList.len()
    return true
  }

  function calcCountriesTableByQueueInfo(infoByTeams, event)
  {
    let res = {}
    foreach(teamNum in ::events.getSidesList(event))
    {
      let teamData = ::events.getTeamData(event, teamNum)
      let teamCountries = ::events.getCountries(teamData)
      let teamName = ::events.getTeamName(teamNum)
      let teamTable = ::getTblValue(teamName, infoByTeams)

      foreach(country in teamCountries)
      {
        if (!(country in res))
          res[country] <- {}

        foreach(rank, value in teamTable)
          res[country][rank] <- ::ceil(value.tofloat() / teamCountries.len()).tointeger()
      }

      if (isSymmetric)
        break
    }
    return res
  }
}