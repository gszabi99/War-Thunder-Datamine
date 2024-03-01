from "%scripts/dagui_library.nut" import *
from "%scripts/teamsConsts.nut" import Team

let enums = require("%sqStdLibs/helpers/enums.nut")
let { USEROPT_BIT_COUNTRIES_TEAM_A, USEROPT_BIT_COUNTRIES_TEAM_B
} = require("%scripts/options/optionsExtNames.nut")

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
    return loc($"events/{this.name}")
  }
  getNameInPVE = function() {
    return loc($"multiplayer/{this.name}")
  }
  getShortName = function() { return loc(this.shortNameLocId) }
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
    teamCountriesOption = USEROPT_BIT_COUNTRIES_TEAM_A
  }
  B = {
    code = Team.B
    opponentTeamCode = Team.A
    name = "teamB"
    cssLabel = "b"
    shortNameLocId = "teamB"
    teamCountriesOption = USEROPT_BIT_COUNTRIES_TEAM_B
  }
  NONE = {
    code = Team.none
    opponentTeamCode = Team.Any
    name = "unknown"
  }
}, null, "id")

::g_team.teams = [::g_team.A, ::g_team.B]
::g_team.getTeams <- function getTeams() {
  return this.teams
}

::g_team.getTeamByCode <- function getTeamByCode(code) {
  return enums.getCachedType("code", code, this.cache.byCode, this, this.NONE)
}

::g_team.getTeamByCountriesOption <- function getTeamByCountriesOption(optionId) {
  return enums.getCachedType("teamCountriesOption", optionId, this.cache.byCountriesOption, this, this.NONE)
}
