from "%rGui/globals/ui_library.nut" import *
let teamColors = require("%rGui/style/teamColors.nut")
let { localTeam, ticketsTeamA, ticketsTeamB, timeLeft, scoreLimit,
  deathPenaltyMul, ctaDeathTicketPenalty, isZoneALocal } = require("%rGui/missionState.nut")
let { ceil, floor } = require("%sqstd/math.nut")
let { secondsToTimeSimpleString } = require("%sqstd/time.nut")
let { capZones } = require("%rGui/hud/capZones/capZonesState.nut")

let getScoresForOneKillW = @() Computed(@() deathPenaltyMul.get() * ctaDeathTicketPenalty.get())

let function getCountKillsToWinW() {
  let scoresOneKillW = getScoresForOneKillW()
  return Computed(@() scoresOneKillW.get() == 0 ? 0 : ceil(scoreLimit.get() / scoresOneKillW.get()).tointeger())
}

let getLocalTeamTicketsW = @() Computed(@() localTeam.get() == 2 ? ticketsTeamB.get() : ticketsTeamA.get())
let getEnemyTeamTicketsW = @() Computed(@() localTeam.get() == 2 ? ticketsTeamA.get() : ticketsTeamB.get())

let getAllyCapZoneIdxW  = @() Computed(@() isZoneALocal.get() ? 0 : 1)
let getEnemyCapZoneIdxW = @() Computed(@() isZoneALocal.get() ? 1 : 0)

let getCapZoneStateW = @(idxW) Computed(@() capZones.get()?[idxW.get()])
let getCapZoneColorW = @(zoneStateW, allyColorW, enemyColorW)
  Computed(function() {
    let { mpTimeX100 = 0 } = zoneStateW.get()
    let team = mpTimeX100 == 0 ? 0
      : mpTimeX100 > 0 ? 2
      : 1
    return team == 0
      ? 0xFFFFFFFF
      : team == localTeam.get() ? allyColorW.get()
      : enemyColorW.get()
  })

let function getKillsCount(oppositeTeamTicketsW) {
  let scoresOneKillW = getScoresForOneKillW()
  return Computed(function() {
    if (scoresOneKillW.get() <= 0)
      return 0

    return floor((scoreLimit.get() - oppositeTeamTicketsW.get()) / scoresOneKillW.get()).tointeger()
  })
}

let getAllyTeamScoreW = @() getKillsCount(getEnemyTeamTicketsW())
let getEnemyTeamScoreW = @() getKillsCount(getLocalTeamTicketsW())

let getAllyTeamColorW = @() Computed(@() teamColors.get().teamBlueColor)
let getEnemyTeamColorW = @() Computed(@() teamColors.get().teamRedColor)

let getTimeLeftStrW = @() Computed(@() secondsToTimeSimpleString(timeLeft.get()))

return {
  getAllyTeamColorW
  getEnemyTeamColorW
  getCountKillsToWinW
  getTimeLeftStrW
  getAllyCapZoneIdxW
  getEnemyCapZoneIdxW
  getAllyTeamScoreW
  getEnemyTeamScoreW
  getCapZoneStateW
  getCapZoneColorW
}