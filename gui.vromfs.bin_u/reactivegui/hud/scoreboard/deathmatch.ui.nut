from "%rGui/globals/ui_library.nut" import *

let { ceil, floor } = require("%sqstd/math.nut")
let { localTeam, ticketsTeamA, ticketsTeamB, timeLeft, scoreLimit,
  deathPenaltyMul, ctaDeathTicketPenalty } = require("%rGui/missionState.nut")
let teamColors = require("%rGui/style/teamColors.nut")
let { secondsToTimeSimpleString } = require("%sqstd/time.nut")

let scoresForOneKill = Computed(@() deathPenaltyMul.get() * ctaDeathTicketPenalty.get())
let countKillsToWin = Computed(@() scoresForOneKill.get() == 0
  ? 0
  : ceil(scoreLimit.get() / scoresForOneKill.get()).tointeger()
)

let localTeamTickets = Computed(@() localTeam.get() == 2 ? ticketsTeamB.get() : ticketsTeamA.get())
let enemyTeamTickets = Computed(@() localTeam.get() == 2 ? ticketsTeamA.get() : ticketsTeamB.get())

function getKillsCount(oppositeTeamTickets) {
  return Computed(function() {
    if (scoresForOneKill.get() == 0)
      return 0

    return floor((scoreLimit.get() - oppositeTeamTickets.get()) / scoresForOneKill.get()).tointeger()
  })
}

let scoreParamsByTeam = {
  localTeam =  {
    score = getKillsCount(enemyTeamTickets)
    fontColor = "teamBlueColor"
    halign = ALIGN_RIGHT
  }
  enemyTeam = {
    score = getKillsCount(localTeamTickets)
    fontColor = "teamRedColor"
    halign = ALIGN_LEFT
  }
}

function getScoreObj(teamName) {
  let scoreParams = scoreParamsByTeam[teamName]
  return @() {
    watch = [scoreParams.score, teamColors]
    rendObj = ROBJ_TEXT
    size = static [sh(9), sh(6)]
    valign = ALIGN_CENTER
    halign = scoreParams.halign
    padding = static [hdpx(4), hdpx(7)]
    font = Fonts.big_text_hud
    color = teamColors.value[scoreParams.fontColor]
    fontFxFactor = 10
    fontFx = FFT_SHADOW
    text = scoreParams.score.value
  }
}

return {
  flow = FLOW_HORIZONTAL
  children = [
    getScoreObj("localTeam")
    {
      size = SIZE_TO_CONTENT
      flow = FLOW_VERTICAL
      halign = ALIGN_CENTER

      children = [
      {
        rendObj = ROBJ_TEXT
        font = Fonts.tiny_text_hud
        text = loc("multiplayer/deathmatch/goal")
      }
      {
        rendObj = ROBJ_SOLID
        size = SIZE_TO_CONTENT
        halign = ALIGN_CENTER
        padding = static [hdpx(5), hdpx(7), hdpx(2), hdpx(7)]
        color = Color(42, 48, 55, 204)
        children = @() {
          watch = countKillsToWin
          rendObj = ROBJ_TEXT
          font = Fonts.tiny_text_hud
          text = loc("multiplayer/deathmatch/goal/kills", { killsCount = countKillsToWin.get() })
        }
      }
      @() {
        watch = timeLeft
        rendObj = ROBJ_TEXT
        font = Fonts.small_text_hud
        text = secondsToTimeSimpleString(timeLeft.get())
      }]
    }
    getScoreObj("enemyTeam")
  ]
}
