from "%rGui/globals/ui_library.nut" import *

let { localTeam, scoreTeamA, scoreTeamB, roundTimeLeft } = require("%rGui/missionState.nut")
let teamColors = require("%rGui/style/teamColors.nut")
let { secondsToTimeSimpleString } = require("%sqstd/time.nut")

let teamHeight  = hdpx(36)
let stripWidth  = hdpx(6)
let teamWidth   = hdpx(64)
let scoreBlockW = hdpx(100)
let timeHeight  = hdpx(20)
let blockW      = stripWidth + teamWidth

let bgPanelColor  = 0x99242428
let bgScoreColor  = 0x992E2E32
let bgTimeColor   = 0x77242428
let timeTextColor = 0xDCD7B441


let localTeamLabel = Computed(@() localTeam.get() == 1 ? "TIG" : "DRA")
let enemyTeamLabel = Computed(@() localTeam.get() == 1 ? "DRA" : "TIG")

let localTeamScore = Computed(@() localTeam.get() == 2 ? scoreTeamB.get() : scoreTeamA.get())
let enemyTeamScore = Computed(@() localTeam.get() == 2 ? scoreTeamA.get() : scoreTeamB.get())

let mkStrip = @(colorKey) @() {
  watch = teamColors
  size = [stripWidth, FLEX]
  rendObj = ROBJ_SOLID
  color = teamColors.get()[colorKey]
}

function mkTeamBlock(labelWatch, colorKey, isLocal) {
  let strip = mkStrip(colorKey)
  let labelArea = {
    size = [teamWidth, FLEX]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = [
      @() {
        watch = teamColors
        size = FLEX
        rendObj = ROBJ_SOLID
        color = teamColors.get()[colorKey]
        opacity = 0.5
      }
      @() {
        watch = labelWatch
        rendObj = ROBJ_TEXT
        font = Fonts.medium_text_hud
        color = 0xFFEEEEEE
        text = labelWatch.get()
      }
    ]
  }
  return {
    size = [blockW, FLEX]
    rendObj = ROBJ_SOLID
    color = bgPanelColor
    clipChildren = true
    flow = FLOW_HORIZONTAL
    children = [
      isLocal ? strip : null
      labelArea
      isLocal ? null : strip
    ]
  }
}

let scoreDisplay = {
  size = [scoreBlockW, FLEX]
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  rendObj = ROBJ_SOLID
  color = bgScoreColor
  children = @() {
    watch = [localTeamScore, enemyTeamScore]
    rendObj = ROBJ_TEXT
    font = Fonts.big_text_hud
    color = 0xFFFFFFFF
    text = $"{localTeamScore.get()}-{enemyTeamScore.get()}"
  }
}

let timeBadge = {
  size = [FLEX, timeHeight]
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  rendObj = ROBJ_SOLID
  color = bgTimeColor
  children = @() {
    watch = roundTimeLeft
    rendObj = ROBJ_TEXT
    font = Fonts.small_text_hud
    color = timeTextColor
    text = secondsToTimeSimpleString(roundTimeLeft.get())
  }
}

let mainBar = {
  flow = FLOW_HORIZONTAL
  size = [SIZE_TO_CONTENT, teamHeight]
  children = [
    mkTeamBlock(localTeamLabel, "teamBlueColor", true)
    scoreDisplay
    mkTeamBlock(enemyTeamLabel, "teamRedColor", false)
  ]
}

return {
  flow = FLOW_VERTICAL
  halign = ALIGN_CENTER
  gap = hdpx(2)
  children = [
    mainBar
    timeBadge
  ]
}
