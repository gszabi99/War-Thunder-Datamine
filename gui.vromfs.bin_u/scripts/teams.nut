let enums = require("%sqStdLibs/helpers/enums.nut")
global enum Team //better to replace it everywhere by g_teams
{
  Any   = 0,
  A     = 1,
  B     = 2,
  none  = 3
}

::g_team <- {
  types = []
  teams = null
  cache = {
    byCode = {}
    byCountriesOption = {}
  }
}

::g_team.template <- {
  id = "" //filled automatically by type id
  code = -1
  opponentTeamCode = -1
  name = ""
  shortNameLocId = ""
  cssLabel = ""
  teamCountriesOption = -1 //USEROPT_*

  getName = function() {
    return ::loc("events/" + name)
  }
  getNameInPVE = function() {
    return ::loc("multiplayer/" + name)
  }
  getShortName = function() { return ::loc(shortNameLocId) }
}

enums.addTypesByGlobalName("g_team", {
  ANY = {
    code = Team.Any
    opponentTeamCode = Team.none
    name = "unknown"
  }
  A = {
    code = Team.A
    opponentTeamCode = Team.B
    name = "teamA"
    cssLabel = "a"
    shortNameLocId = "teamA"
    teamCountriesOption = ::USEROPT_BIT_COUNTRIES_TEAM_A
  }
  B = {
    code = Team.B
    opponentTeamCode = Team.A
    name = "teamB"
    cssLabel = "b"
    shortNameLocId = "teamB"
    teamCountriesOption = ::USEROPT_BIT_COUNTRIES_TEAM_B
  }
  NONE = {
    code = Team.none
    opponentTeamCode = Team.Any
    name = "unknown"
  }
}, null, "id")

::g_team.teams = [::g_team.A, ::g_team.B]
g_team.getTeams <- function getTeams()
{
  return teams
}

g_team.getTeamByCode <- function getTeamByCode(code)
{
  return enums.getCachedType("code", code, cache.byCode, this, NONE)
}

g_team.getTeamByCountriesOption <- function getTeamByCountriesOption(optionId)
{
  return enums.getCachedType("teamCountriesOption", optionId, cache.byCountriesOption, this, NONE)
}
