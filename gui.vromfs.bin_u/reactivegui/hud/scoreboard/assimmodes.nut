from "%rGui/globals/ui_library.nut" import *
let { timeLeft, missionProgressAttackShip, missionProgressDefendShip, localTeam } = require("%rGui/missionState.nut")
let { secondsToTimeSimpleString } = require("%sqstd/time.nut")

let iconWidth = hdpxi(43)
let iconHeight = hdpxi(27)
let mainBlockDefFontStyles = {
  fontSize = hdpx(20)
  fontFxFactor = 20
  fontFxColor = 0xFF000000
  fontFx = FFT_SHADOW
}

let timerComp = {
  size = const [hdpx(52), hdpx(19)]
  pos = [0, -hdpx(9)]
  hplace = ALIGN_CENTER
  rendObj = ROBJ_VECTOR_CANVAS
  commands = [ [VECTOR_POLY, 8, 49, 0, 0, 100, 0, 92, 49, 84, 100, 16, 100] ]
  fillColor = 0xFF364854
  color = 0xFF37454D
  lineWidth = hdpx(2)
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER

  children = @() {
    watch = timeLeft
    rendObj = ROBJ_TEXT
    text = secondsToTimeSimpleString(timeLeft.get())
    color = 0xAFAFAF
    fontSize = hdpx(15)
  }
}

function mkMainBlock (textAttack, textDefend, icon) {
  let isAttackingTeam = Computed(@() localTeam.get() == 2)
  let teamText = Computed(@() isAttackingTeam.get() ? textAttack : textDefend)
  let teamScore = Computed(@() isAttackingTeam.get()
    ? missionProgressAttackShip.get()
    : missionProgressDefendShip.get())

  return {
    padding = const [hdpx(10), hdpx(30)]
    rendObj = ROBJ_BOX
    fillColor = 0x99324149
    borderColor = 0xFF606F79
    borderWidth = hdpx(2)
    flow = FLOW_HORIZONTAL
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER

    children = [
      {
        size = [iconWidth, iconHeight]
        margin = const [0, hdpx(10)]
        rendObj = ROBJ_IMAGE
        image = Picture($"{icon}:{iconWidth}:{iconHeight}:K:P")
        keepAspect = true
        color = 0xAFAFAF
      }
      @() {
        watch = teamText
        rendObj = ROBJ_TEXT
        text = teamText.get()
        font = Fonts.small_text
        color = 0xAFAFAF
      }.__update(mainBlockDefFontStyles)
      @() {
        watch = teamScore
        margin = const [0, hdpx(4)]
        rendObj = ROBJ_TEXT
        text = teamScore.get()
        font = Fonts.medium_text
        color = 0xFFFFFF
      }.__update(mainBlockDefFontStyles)
    ]
  }
}

let mkHudForAssimBattles = @(textAttack, textDefend, icon) {
  children = [
    mkMainBlock(textAttack, textDefend, icon)
    timerComp
  ]
}


let sead = mkHudForAssimBattles(
  loc("hud/sead/attack_text"),
  loc("hud/sead/defend_text"),
  "ui/gameuiskin#objective_sam.avif"
)

return { sead }
