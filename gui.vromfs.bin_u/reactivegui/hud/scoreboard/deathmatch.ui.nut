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
let isHudVisible = Computed(@() ticketsTeamA.get() > 0 && ticketsTeamB.get() > 0)

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
    color = "teamBlueColor"
    borderColor = "teamBlueLightColor"
    poly = [ [VECTOR_POLY, 0, 0, 90, 0, 100, 100, 10, 100] ]
  }
  enemyTeam = {
    score = getKillsCount(localTeamTickets)
    color = "teamRedColor"
    borderColor = "teamRedLightColor"
    poly = [ [VECTOR_POLY, 10, 0, 100, 0, 90, 100, 0, 100] ]
  }
}

function getScoreObj(teamName) {
  let scoreParams = scoreParamsByTeam[teamName]
  return {
    size = const [hdpx(92), hdpx(46)]
    margin = const [0, hdpx(10)]
    halign = ALIGN_CENTER

    children = [
      @() {
        watch = teamColors
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        commands = scoreParams.poly
        color = teamColors.get()[scoreParams.color]
        fillColor = teamColors.get()[scoreParams.borderColor]
        opacity = 0.6
      },
      @() {
        watch = scoreParams.score
        rendObj = ROBJ_TEXT
        padding = const [hdpx(1), 0]
        font = Fonts.digital
        fontSize = hdpx(50)
        color = 0xE5E5E5E5
        text = scoreParams.score.get()
      }
    ]
  }
}

return @() {
  watch = isHudVisible
  flow = FLOW_HORIZONTAL
  children = !isHudVisible.get() ? null : [
    getScoreObj("localTeam")
    {
      children = [
      {
        size = const [hdpx(92), hdpx(46)]
        pos = [0, -hdpx(8)]
        rendObj = ROBJ_VECTOR_CANVAS
        commands = [ [VECTOR_POLY, 0, 0, 100, 0, 90, 100, 10, 100] ]
        fillColor = 0x8C364854
        color = 0
        halign = ALIGN_CENTER
        flow = FLOW_VERTICAL
        padding = const [hdpx(2), 0]

        children = [
          @() {
            watch = countKillsToWin
            rendObj = ROBJ_TEXT
            font = Fonts.digital
            fontSize = hdpx(24)
            color = 0xCCCCCCCC
            text = countKillsToWin.get()
          }
          @() {
            watch = timeLeft
            rendObj = ROBJ_TEXT
            font = Fonts.digital
            fontSize = hdpx(18)
            color = 0xCCCCCCCC
            text = secondsToTimeSimpleString(timeLeft.get())
          }
        ]
      }]
    }
    getScoreObj("enemyTeam")
  ]
}
