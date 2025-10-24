from "%rGui/globals/ui_library.nut" import *

let teamColors = require("%rGui/style/teamColors.nut")
let fontsState = require("%rGui/style/fontsState.nut")


let cpBasicSize = hdpxi(25)
let cpInZoneSize = hdpxi(32)
let progressLineSize = [hdpx(180), hdpx(12)]

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
  color = 0xFFFFFFFF
  fillColor = 0xFFFFFFFF
}

let mkTeamCapPoint = @(captureZoneW, localTeamW)
  function() {
    let watch = [captureZoneW, teamColors, localTeamW]
    let captureZoneVal = captureZoneW.get()
    if (captureZoneVal == null)
      return { watch }

    let { id, progress, watchedHeroInZone, mpTimeX100 = 0 } = captureZoneVal
    let { teamBlueColor, teamRedColor } = teamColors.get()
    let cpSize = watchedHeroInZone ? cpInZoneSize : cpBasicSize

    let curTeam = mpTimeX100 == 0 ? 0
      : mpTimeX100 > 0 ? 2
      : 1
    let teamColor = curTeam == 0 ? 0xFFFFFFFF
      : curTeam == localTeamW.get() ? teamBlueColor
      : teamRedColor

    return {
      watch
      size = [cpSize, cpSize]
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      children = [
        {
          size = flex()
          rendObj = ROBJ_PROGRESS_CIRCULAR
          fValue = progress / 100.0
          fgColor = teamColor
          bgColor = 0XFF5B5C60
          image = Picture($"ui/gameuiskin#basezone_small_rhombus.svg:{cpSize}:{cpSize}:P")
          keepAspect = true
        }
        watchedHeroInZone ? inZoneFrame : null
        {
          rendObj = ROBJ_TEXT
          font = fontsState.get("tiny")
          color = 0xFF171C22
          text = loc($"CAPTURE_ZONE_{id}")
        }
      ]
    }
  }


function mkTeamProgress(isAlly, ticketsW, maxTicketsW) {
  let teamColorW = Computed(@() isAlly
    ? teamColors.get().teamBlueColor
    : teamColors.get().teamRedColor)

  let progress = Computed(@() maxTicketsW.get() > 0
    ? 100 * ticketsW.get() / maxTicketsW.get()
    : 0)

  return {
    size = progressLineSize
    padding = hdpx(2)
    halign = isAlly ? ALIGN_RIGHT : ALIGN_LEFT
    rendObj = ROBJ_SOLID
    color = 0xFF171C22
    children = @() {
      watch = [progress, teamColorW]
      size = [pw(progress.get()), flex()]
      rendObj = ROBJ_SOLID
      color = teamColorW.get()
    }
  }
}


return {
  mkTeamCapPoint
  mkTeamProgress
}
