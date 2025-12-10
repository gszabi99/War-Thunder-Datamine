from "%rGui/globals/ui_library.nut" import *

let teamColors = require("%rGui/style/teamColors.nut")
let { ticketHudBlurPanel } = require("%rGui/components/blurPanel.nut")

let neutralColor = 0XFFCCCCCC
let darkColor = 0X98000000

let cpBasicSize = hdpxi(22)
let cpInZoneSize = hdpxi(40)
let superiorityIconSize = hdpxi(10)
let progressLineSize = [hdpxi(200), hdpxi(10)]
let zoneSymbols = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p"]


let mkSuperiorityIcon = @(color) {
  size = [superiorityIconSize, superiorityIconSize ]
  rendObj = ROBJ_IMAGE
  image = Picture($"ui/gameuiskin#person_icon.svg:{superiorityIconSize}:{superiorityIconSize}:P")
  color
}


let inZoneFrame = {
  size = flex()
  rendObj = ROBJ_VECTOR_CANVAS
  commands = [
    [VECTOR_POLY,  5,  5, 20,  5,  5, 20],
    [VECTOR_POLY, 95,  5, 80,  5, 95, 20],
    [VECTOR_POLY,  5, 95, 20, 95,  5, 80],
    [VECTOR_POLY, 95, 95, 80, 95, 95, 80],
  ]
  lineWidth = hdpx(1)
  color = neutralColor
  fillColor = neutralColor
}

let SUPERIORITY_STATE = {
  NO_ALLY_IN_ZONE     = 0x0000
  SOME_ALLY_IN_ZONE   = 0x0001
  PARITY_IN_ZONE      = 0x0002
  MOST_ALLY_IN_ZONE   = 0x0004
  ONLY_ALLY_IN_ZONE   = 0x0008
}

let SUPERIORITY_COLOR_BY_PLACE_AVAILABILITY = [
  @(curStateFlag) curStateFlag & (SUPERIORITY_STATE.ONLY_ALLY_IN_ZONE
                                | SUPERIORITY_STATE.MOST_ALLY_IN_ZONE
                                | SUPERIORITY_STATE.PARITY_IN_ZONE
                                | SUPERIORITY_STATE.SOME_ALLY_IN_ZONE),
  @(curStateFlag) curStateFlag & (SUPERIORITY_STATE.ONLY_ALLY_IN_ZONE
                                | SUPERIORITY_STATE.MOST_ALLY_IN_ZONE
                                | SUPERIORITY_STATE.PARITY_IN_ZONE),
  @(curStateFlag) curStateFlag & (SUPERIORITY_STATE.ONLY_ALLY_IN_ZONE
                                | SUPERIORITY_STATE.MOST_ALLY_IN_ZONE),
  @(curStateFlag) curStateFlag & (SUPERIORITY_STATE.ONLY_ALLY_IN_ZONE)
]

function mkCapZoneSuperiority(captureZoneVal, localTeamVal, teamColorsVal) {
  let { teamScoreBlueColor, teamScoreRedColor } = teamColorsVal
  let { numCapturersTeamA = 0, numCapturersTeamB = 0 } = captureZoneVal
  local myTeamCapturers = numCapturersTeamA
  local enemyTeamCapturers = numCapturersTeamB
  if (localTeamVal == 2) {
    myTeamCapturers = numCapturersTeamB
    enemyTeamCapturers = numCapturersTeamA
  }

  let zoneSuperiorityFlag = enemyTeamCapturers == 0 ? SUPERIORITY_STATE.ONLY_ALLY_IN_ZONE
    : myTeamCapturers == 0 ? SUPERIORITY_STATE.NO_ALLY_IN_ZONE
    : myTeamCapturers > enemyTeamCapturers ? SUPERIORITY_STATE.MOST_ALLY_IN_ZONE
    : enemyTeamCapturers > myTeamCapturers ? SUPERIORITY_STATE.SOME_ALLY_IN_ZONE
    : SUPERIORITY_STATE.PARITY_IN_ZONE

  return {
    flow = FLOW_HORIZONTAL
    hplace = ALIGN_CENTER
    children = [null,null,null,null].map(@(_, idx)
      mkSuperiorityIcon(SUPERIORITY_COLOR_BY_PLACE_AVAILABILITY[idx](zoneSuperiorityFlag)
        ? teamScoreBlueColor
        : teamScoreRedColor
    ))
  }
}

let mkTeamCapPoint = @(captureZoneW, localTeamW) function() {
  let captureZoneVal = captureZoneW.get()
  if (captureZoneVal == null)
    return { watch = captureZoneW }

  let { id, progress, watchedHeroInZone, mpTimeX100 = 0 } = captureZoneVal
  let { teamScoreBlueColor, teamScoreRedColor } = teamColors.get()
  let cpSize = watchedHeroInZone ? cpInZoneSize : cpBasicSize

  let curTeam = mpTimeX100 == 0 ? 0
    : mpTimeX100 > 0 ? 2
    : 1
  let teamColor = curTeam == 0 ? neutralColor
    : curTeam == localTeamW.get() ? teamScoreBlueColor
    : teamScoreRedColor

  return {
    watch = [captureZoneW, teamColors, localTeamW]
    flow = FLOW_VERTICAL
    size = [ SIZE_TO_CONTENT, cpInZoneSize ]
    children = [
      {
        size = [ SIZE_TO_CONTENT, cpInZoneSize ]
        valign = ALIGN_CENTER
        children = {
          size = [cpSize, cpSize]
          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
          children = [
            {
              size = flex()
              rendObj = ROBJ_PROGRESS_CIRCULAR
              fValue = progress / 100.0
              fgColor = teamColor
              bgColor = neutralColor
              image = Picture($"ui/gameuiskin#basezone_small_rhombus.svg:{cpSize}:{cpSize}:P")
              keepAspect = true
            }
            watchedHeroInZone ? inZoneFrame : null
            {
              size = flex()
              rendObj = ROBJ_IMAGE
              image = Picture($"ui/gameuiskin#basezone_small_mark_no_bg_{zoneSymbols[id]}.svg:{cpInZoneSize}:{cpInZoneSize}:P")
              color = darkColor
            }
          ]
        }
      }
      watchedHeroInZone
        ? mkCapZoneSuperiority(captureZoneVal, localTeamW.get(), teamColors.get())
        : null
    ]
  }
}

function mkTeamProgressLine(isAlly, teamColor, progress) {
  return {
    size = [pw(progress), flex()]
    rendObj = ROBJ_SOLID
    color = teamColor
    hplace = isAlly ? ALIGN_RIGHT : ALIGN_LEFT
  }
}


function mkTeamProgress(isAlly, ticketsW, maxTicketsW) {
  let teamColorW = Computed(@() isAlly
    ? teamColors.get().teamScoreBlueColor
    : teamColors.get().teamScoreRedColor)
  let progress = Computed(@() maxTicketsW.get() > 0
    ? 100 * ticketsW.get() / maxTicketsW.get()
    : 0)

  return {
    size = progressLineSize
    halign = isAlly ? ALIGN_RIGHT : ALIGN_LEFT
    children = [
      ticketHudBlurPanel
      @() {
        watch = [progress, teamColorW]
        size = progressLineSize
        children = mkTeamProgressLine(isAlly, teamColorW.get(), progress.get())
      }
    ]
  }
}


return {
  mkTeamCapPoint
  mkTeamProgress
}
