from "%rGui/globals/ui_library.nut" import *
let { timeLeft, missionProgressAttackShip, missionProgressDefendShip, localTeam } = require("%rGui/missionState.nut")
let { secondsToTimeSimpleString } = require("%sqstd/time.nut")

let mainBlockDefFontStyles = {
  fontSize = hdpx(20)
  fontFxFactor = 20
  fontFxColor = 0xFF000000
  fontFx = FFT_SHADOW
}

let timerComp = {
  size = static [hdpx(52), hdpx(19)]
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

function mkMainBlock (teamScoreW, teamTextW, icon, iconSize) {
  return {
    padding = static [hdpx(10), hdpx(15)]
    rendObj = ROBJ_BOX
    fillColor = 0x99324149
    borderColor = 0xFF606F79
    borderWidth = hdpx(2)
    flow = FLOW_HORIZONTAL
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER

    children = [
      {
        size = iconSize
        margin = static [0, hdpx(10)]
        rendObj = ROBJ_IMAGE
        image = Picture($"{icon}:{iconSize[0]}:{iconSize[1]}:K:P")
        keepAspect = true
        color = 0xAFAFAF
      }
      @() {
        watch = teamTextW
        rendObj = ROBJ_TEXT
        text = teamTextW.get()
        font = Fonts.small_text
        color = 0xAFAFAF
      }.__update(mainBlockDefFontStyles)
      @() {
        watch = teamScoreW
        margin = static [0, hdpx(4)]
        rendObj = ROBJ_TEXT
        text = teamScoreW.get()
        font = Fonts.medium_text
        color = 0xFFFFFF
      }.__update(mainBlockDefFontStyles)
    ]
  }
}

function mkHudForAssimBattles(textAttack, textDefend, icon, iconSize) {
  let isAttackingTeam = Computed(@() localTeam.get() == 2)
  let teamText = Computed(@() isAttackingTeam.get() ? textAttack : textDefend)
  let teamScore = Computed(@() isAttackingTeam.get()
    ? missionProgressAttackShip.get()
    : missionProgressDefendShip.get())
  let isHudVisible = Computed(@() teamScore.get() > 0)

  return @() {
    watch = isHudVisible
    children = isHudVisible.get()
      ? [
          mkMainBlock(teamScore, teamText, icon, iconSize)
          timerComp
        ]
      : null
  }
}


let sead = mkHudForAssimBattles(
  loc("hud/sead/attack_text"),
  loc("hud/sead/defend_text"),
  "ui/gameuiskin#objective_sam.avif",
  [hdpxi(43), hdpxi(27)]
)

let oil_refinery_strbomb = mkHudForAssimBattles(
  loc("hud/oil_refinery_strbomb/attack_text"),
  loc("hud/oil_refinery_strbomb/defend_text"),
  "ui/gameuiskin#army_building_oil_refinery.svg",
  [hdpxi(28), hdpxi(28)]
)

let power_plant_strbomb = mkHudForAssimBattles(
  loc("hud/power_plant_strbomb/attack_text"),
  loc("hud/power_plant_strbomb/defend_text"),
  "ui/gameuiskin#army_building_power_plant.svg",
  [hdpxi(28), hdpxi(28)]
)

return {
  sead,
  oil_refinery_strbomb,
  power_plant_strbomb
}
