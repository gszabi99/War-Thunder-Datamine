from "%rGui/globals/ui_library.nut" import *
let { roundTimeLeft, missionProgressScore, missionProgressDefendShip
} = require("%rGui/missionState.nut")
let { secondsToTimeSimpleString } = require("%sqstd/time.nut")

let blockWidth = hdpx(136)
let blockHeight = hdpx(36)
let borderWidth = hdpx(2)
let blockPadding = [0, hdpx(6)]

let borderColor = 0xFFFFFFFF
let fillColor = 0xB2383F49

let textParams = {
  rendObj = ROBJ_TEXT
  font = Fonts.small_text_hud
  halign = ALIGN_CENTER
  fontFx = FFT_GLOW
  fontFxColor = 0xFF000000
  fontFxFactor = max(64, hdpx(64))
}

let killsIcon = {
  rendObj = ROBJ_IMAGE
  size = [blockHeight, blockHeight]
  image = Picture($"!ui/gameuiskin#objective_ship.svg:{blockHeight}:{blockHeight}")
}



let isVisibleScoreBoard = Computed(@() missionProgressDefendShip.get() > 0)

let killsText = @() textParams.__merge({
  watch = [missionProgressScore, missionProgressDefendShip]
  size = [flex(), SIZE_TO_CONTENT]
  text = $"{missionProgressScore.get()}/{missionProgressDefendShip.get()}"
})

let timeIcon = {
  rendObj = ROBJ_IMAGE
  size = [hdpx(32), hdpx(26)]
  image = Picture("ui/gameuiskin#objective_time.avif")
}

let timeText = @() textParams.__merge({
  watch = roundTimeLeft
  size = [flex(), SIZE_TO_CONTENT]
  text = secondsToTimeSimpleString(roundTimeLeft.value)
})

let mkBlock = @(children) {
  rendObj = ROBJ_BOX
  size = [blockWidth, blockHeight]
  flow = FLOW_HORIZONTAL
  valign = ALIGN_CENTER
  padding = blockPadding
  fillColor
  borderColor
  borderWidth
  children
}

let killsComp = mkBlock([killsIcon, killsText])
let timeComp = mkBlock([timeIcon, timeText])

return @() {
  watch = isVisibleScoreBoard
  flow = FLOW_HORIZONTAL
  gap = -borderWidth
  children = isVisibleScoreBoard.get() ? [killsComp, timeComp]
    : null
}
