local {localTeam, scoreTeamA, scoreTeamB, timeLeft} = require("reactiveGui/missionState.nut")
local teamColors = require("reactiveGui/style/teamColors.nut")
local { secondsToString } = require("std/time.nut")

local scoreParamsByTeam = {
  localTeam = {
    score = ::Computed(@() localTeam.value == 2 ? scoreTeamB.value : scoreTeamA.value)
    fillColor = "teamBlueColor"
    borderColor = "teamBlueLightColor"
  }
  enemyTeam = {
    score = ::Computed(@() localTeam.value == 2 ? scoreTeamA.value : scoreTeamB.value)
    fillColor = "teamRedColor"
    borderColor = "teamRedLightColor"
  }
}

local function getScoreObj(teamName) {
  local scoreParams = scoreParamsByTeam[teamName]
  return @() {
    watch = teamColors
    rendObj = ROBJ_BOX
    size = [sh(5), sh(6)]
    valign = ALIGN_CENTER
    halign = ALIGN_CENTER
    fillColor = teamColors.value[scoreParams.fillColor]
    borderColor = teamColors.value[scoreParams.borderColor]
    borderWidth = [hdpx(1)]

    children = @() {
      watch = scoreParams.score
      rendObj = ROBJ_DTEXT
      font = Fonts.big_text_hud
      fontFxColor = Color(0, 0, 0, 255)
      fontFxFactor = 50
      fontFx = FFT_GLOW
      text = scoreParams.score.value
    }
  }
}

return {
  flow = FLOW_HORIZONTAL
  children = [
    getScoreObj("localTeam")
    {
      rendObj = ROBJ_SOLID
      size = [sh(12), sh(4.5)]
      valign = ALIGN_CENTER
      halign = ALIGN_CENTER
      color = Color(0, 0, 0, 102)
      children = @(){
        watch = timeLeft
        rendObj = ROBJ_DTEXT
        font = Fonts.medium_text_hud
        color = Color(249, 219, 120)
        text = secondsToString(timeLeft.value, false)
      }
    }
    getScoreObj("enemyTeam")
  ]
}
