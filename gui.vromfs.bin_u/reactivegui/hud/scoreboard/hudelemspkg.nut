from "%rGui/globals/ui_library.nut" import *

let teamColors = require("%rGui/style/teamColors.nut")


let neutralColor = 0XFFCCCCCC
let darkColor = 0XFF222222

let cpBasicSize = hdpxi(22)
let cpInZoneSize = hdpxi(32)
let progressLineSize = [hdpxi(200), hdpxi(10)]
let lineOffcet = 100 * progressLineSize[1] / progressLineSize[0]
let zoneSymbols = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p"]

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


let mkProgressDecor = @(isAlly) {
  size = flex()
  rendObj = ROBJ_IMAGE
  image = Picture($"ui/gameuiskin#progres_line_decor.svg:{progressLineSize[0]}:{progressLineSize[1]}:P")
  color = darkColor
  opacity = 0.2
  flipY = !isAlly
}

let allyProgressDecor = mkProgressDecor(true)
let enemyProgressDecor = mkProgressDecor(false)


let mkTeamCapPoint = @(captureZoneW, localTeamW)
  function() {
    let watch = [captureZoneW, teamColors, localTeamW]
    let captureZoneVal = captureZoneW.get()
    if (captureZoneVal == null)
      return { watch }

    let { id, progress, watchedHeroInZone, mpTimeX100 = 0 } = captureZoneVal
    let { teamScoreBlueColor, teamScoreRedColor } = teamColors.get()
    let cpSize = watchedHeroInZone ? cpInZoneSize : cpBasicSize

    let curTeam = mpTimeX100 == 0 ? 0
      : mpTimeX100 > 0 ? 2
      : 1
    let teamColor = curTeam == 0 ? neutralColor
      : curTeam == localTeamW.get() ? teamScoreBlueColor
      : teamScoreRedColor

    let zoneSymbol = zoneSymbols[id]
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
          bgColor = neutralColor
          image = Picture($"ui/gameuiskin#basezone_small_rhombus.svg:{cpSize}:{cpSize}:P")
          keepAspect = true
        }
        watchedHeroInZone ? inZoneFrame : null
        {
          size = flex()
          rendObj = ROBJ_IMAGE
          image = Picture($"ui/gameuiskin#basezone_small_mark_no_bg_{zoneSymbol}.svg:{cpInZoneSize}:{cpInZoneSize}:P")
          color = darkColor
        }
      ]
    }
  }


function mkTeamProgressLine(isAlly, teamColor, progress, lineWidth) {
  if (progress <= 0)
    return null

  let commands = []
  if (isAlly)
    commands.append(progress > lineOffcet
      ? [ VECTOR_POLY,  100, 0, 100, 100, 100 - progress, 100,
          100 - progress - lineOffcet, 0 ]
      : [ VECTOR_POLY,  100, 0, 100, 100 * progress / lineOffcet,
          100 - (lineOffcet * progress / lineOffcet), 0 ]
    )
  else
    commands.append(progress > lineOffcet
      ? [ VECTOR_POLY,  0, 0, 0, 100, progress - lineOffcet, 100, progress, 0 ]
      : [ VECTOR_POLY,  0, 0, 0, 100 * progress / lineOffcet,
          lineOffcet * progress / lineOffcet, 0 ]
    )

  return {
    size = progressLineSize
    rendObj = ROBJ_VECTOR_CANVAS
    color = teamColor
    fillColor = teamColor
    commands
    lineWidth
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
      mkTeamProgressLine(isAlly, darkColor, 100, hdpx(3))
      @() {
        watch = [progress, teamColorW]
        children = mkTeamProgressLine(isAlly, teamColorW.get(), progress.get(), hdpx(1))
      }
      isAlly ? allyProgressDecor : enemyProgressDecor
    ]
  }
}


return {
  mkTeamCapPoint
  mkTeamProgress
}
