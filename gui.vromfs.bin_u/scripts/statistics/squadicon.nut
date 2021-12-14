local listLabelsSquad = {}
local nextLabel = { team1 = 1, team2 = 1}
local topSquads = {}
local playersInfo = {}

local getPlayersInfo = @() playersInfo
local function updateIconPlayersInfo()
{
  local sessionPlayersInfo = ::SessionLobby.getPlayersInfo()
  if (sessionPlayersInfo.len() > 0 && !::u.isEqual(playersInfo, sessionPlayersInfo))
    playersInfo = clone sessionPlayersInfo
}

local function initListLabelsSquad()
{
  listLabelsSquad.clear()
  nextLabel.team1 = 1
  nextLabel.team2 = 1
  topSquads = {}
  playersInfo = {}
  updateIconPlayersInfo()
}

local function updateListLabelsSquad()
{
  foreach(label in listLabelsSquad)
    label.count = 0;
  local team = ""
  foreach(uid, member in getPlayersInfo())
  {
    team = "team"+member.team
    if (!(team in nextLabel))
      continue

    local squadId = member.squad
    if (squadId == INVALID_SQUAD_ID)
      continue
    if (squadId in listLabelsSquad)
    {
      if (listLabelsSquad[squadId].count < 2)
      {
        listLabelsSquad[squadId].count++
        if (listLabelsSquad[squadId].count > 1 && listLabelsSquad[squadId].label == "")
        {
          listLabelsSquad[squadId].label = nextLabel[team].tostring()
          nextLabel[team]++
        }
      }
    }
    else
      listLabelsSquad[squadId] <- {
        squadId = squadId
        count = 1
        label = ""
        autoSquad = ::getTblValue("auto_squad", member, false)
        teamId = member.team
      }
  }
}

local function getSquadInfo(idSquad)
{
  if (idSquad == INVALID_SQUAD_ID)
    return null
  local squad = (idSquad in listLabelsSquad) ? listLabelsSquad[idSquad] : null
  if (squad == null)
    return null
  else if (squad.count < 2)
    return null
  return squad
}

local function getSquadInfoByMemberName(name)
{
  if (name == "")
    return null

  foreach(uid, member in getPlayersInfo())
    if (member.name == name)
      return getSquadInfo(member.squad)

  return null
}

local isShowSquad = @() ::SessionLobby.getGameMode() != ::GM_SKIRMISH
local function updateTopSquadScore(mplayers)
{
  if (!isShowSquad())
    return
  local teamId = mplayers.len() ? ::getTblValue("team", mplayers[0], null) : null
  if (teamId == null)
    return

  local topSquadId = null

  local topSquadScore = 0
  local squads = {}
  foreach (player in mplayers)
  {
    local squadScore = ::getTblValue("squadScore", player, 0)
    if (!squadScore || squadScore < topSquadScore)
      continue
    local name = ::getTblValue("name", player, "")
    local squadId = ::getTblValue("squadId", getSquadInfoByMemberName(name), INVALID_SQUAD_ID)
    if (squadId == INVALID_SQUAD_ID)
      continue
    if (squadScore > topSquadScore)
    {
      topSquadScore = squadScore
      squads.clear()
    }
    local score = ::getTblValue("score", player, 0)
    if (!(squadId in squads))
      squads[squadId] <- { playerScore = 0, members = 0 }
    squads[squadId].playerScore += score
    squads[squadId].members++
  }

  local topAvgPlayerScore = 0.0
  foreach (squadId, data in squads)
  {
    local avg = data.playerScore * 1.0 / data.members
    if (topSquadId == null || avg > topAvgPlayerScore)
    {
      topSquadId = squadId
      topAvgPlayerScore = avg
    }
  }

  topSquads[teamId] <- topSquadId
}

local getTopSquadId = @(teamId) topSquads?.teamId

return {
  getPlayersInfo
  initListLabelsSquad
  updateIconPlayersInfo
  updateTopSquadScore
  updateListLabelsSquad
  getSquadInfo
  isShowSquad
  getSquadInfoByMemberName
  getTopSquadId
}
