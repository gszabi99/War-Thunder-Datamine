import "%rGui/style/teamColors.nut" as teamColors
from "%rGui/missionState.nut" import totalDomTeam, localTeam, totalDomEnabled
from "%rGui/hud/scoreboard/missionModeState.nut" import TOTAL_DOMINATION_START_ANIM_ID
from "%rGui/globals/ui_library.nut" import *

let animations = [
  { prop = AnimProp.opacity, from = 0, to = 1, play = false, duration = 0.25,
    trigger = TOTAL_DOMINATION_START_ANIM_ID },
  { prop = AnimProp.opacity, from = 1, to = 1, play = false, duration = 3, delay = 0.25,
    trigger = TOTAL_DOMINATION_START_ANIM_ID },
  { prop = AnimProp.opacity, from = 1, to = 0, play = false, duration = 0.25, delay = 3.25,
    trigger = TOTAL_DOMINATION_START_ANIM_ID }
]


let dominationColor = Computed(@() totalDomTeam.get() == localTeam.get()
  ? teamColors.get().teamScoreBlueColor
  : teamColors.get().teamScoreRedColor)


let dominationNotification = @() !totalDomEnabled.get()
  ? { watch = [ totalDomEnabled ] }
  : {
      watch = [ totalDomEnabled ]
      hplace = ALIGN_CENTER
      opacity = 0
      animations
      children = @() {
        watch = dominationColor
        rendObj = ROBJ_TEXT
        font = Fonts.medium_text_hud
        color = dominationColor.get()
        text = loc("missions/totalDomination")
        fontFxColor = Color(0, 0, 0, 50)
        fontFxFactor = min(64, hdpx(64))
        fontFx = FFT_GLOW
      }
}

return dominationNotification
