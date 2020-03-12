local missionState = require("missionState.nut")
local teamColors = require("style/teamColors.nut")
local time = require("std/time.nut")
local frp = require("std/frp.nut")

local style = {}

style.scoreText <- {
  font = Fonts.big_text_hud
  fontFxColor = Color(0, 0, 0, 255)
  fontFxFactor = 50
  fontFx = FFT_GLOW
}

local scoreState = {
  localTeam = frp.combine([missionState.localTeam, missionState.scoreTeamA, missionState.scoreTeamB],
            @(list) list[0] == 2 ? list[2] : list[1])
  enemyTeam = frp.combine([missionState.localTeam, missionState.scoreTeamA, missionState.scoreTeamB],
            @(list) list[0] == 2 ? list[1] : list[2])
}

return @() {
  flow = FLOW_HORIZONTAL
  watch = missionState.gameType
  isHidden = (missionState.gameType.value & GT_FOOTBALL) == 0

  children = [
    @() {
      watch = teamColors
      rendObj = ROBJ_BOX
      size = [sh(5), sh(6)]
      valign = ALIGN_CENTER
      halign = ALIGN_CENTER
      fillColor = teamColors.value.teamBlueColor
      borderColor = teamColors.value.teamBlueLightColor
      borderWidth = [hdpx(1)]

      children = @() style.scoreText.__merge({
        watch = scoreState.localTeam
        rendObj = ROBJ_DTEXT
        text = scoreState.localTeam.value
      })
    }
    @() {
      rendObj = ROBJ_SOLID
      size = [sh(12), sh(4.5)]
      valign = ALIGN_CENTER
      halign = ALIGN_CENTER
      color = Color(0, 0, 0, 102)
      children = @(){
        watch = missionState.timeLeft
        rendObj = ROBJ_DTEXT
        font = Fonts.medium_text_hud
        color = Color(249, 219, 120)
        text = time.secondsToString(missionState.timeLeft.value, false)
      }
    }
    @() {
      watch = teamColors
      rendObj = ROBJ_BOX
      size = [sh(5), sh(6)]
      valign = ALIGN_CENTER
      halign = ALIGN_CENTER
      fillColor = teamColors.value.teamRedColor
      borderColor = teamColors.value.teamRedLightColor
      borderWidth = [hdpx(1)]

      children = @() style.scoreText.__merge({
        watch = scoreState.enemyTeam
        rendObj = ROBJ_DTEXT
        text = scoreState.enemyTeam.value
      })
    }
  ]
}
