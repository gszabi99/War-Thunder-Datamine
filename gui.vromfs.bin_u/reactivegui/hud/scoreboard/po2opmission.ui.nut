from "%rGui/missionState.nut" import roundTimeLeft, missionProgressScore
from "%sqstd/time.nut" import secondsToTimeSimpleString
from "%rGui/globals/ui_library.nut" import *

let timeFillColor = Computed(@() roundTimeLeft.get() > 0 ? 0xB200AF0E : 0xB2AF0100)

const blockWidth = hdpx(156)
let iconWidth = (0.33 * blockWidth).tointeger()
const blockHeight = hdpx(36)
const borderWidth = hdpx(2)

const borderColor = 0xFFFFFFFF

let textParams = {
  rendObj = ROBJ_TEXT
  font = Fonts.small_text_hud
  halign = ALIGN_CENTER
  fontFx = FFT_GLOW
  fontFxColor = 0xFF000000
  fontFxFactor = max(64, hdpx(64))
}

let killsIcon = textParams.__merge({
  size = [iconWidth, SIZE_TO_CONTENT]
  text = "▓"
})

let killsText = @() textParams.__merge({
  watch = missionProgressScore
  size = FLEX_H
  text = missionProgressScore.get()
})

let timeIcon = textParams.__merge({
  size = [iconWidth, SIZE_TO_CONTENT]
  pos = const [0, hdpx(2)]  
  text = "╎"
})

let timeText = @() textParams.__merge({
  watch = roundTimeLeft
  size = FLEX_H
  text = secondsToTimeSimpleString(roundTimeLeft.get())
})

return {
  size = const [blockWidth, SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  gap = -borderWidth
  children = [
    {
      rendObj = ROBJ_BOX
      size = const [FLEX, blockHeight]
      flow = FLOW_HORIZONTAL
      valign = ALIGN_CENTER
      fillColor = 0xB2383F49
      borderColor
      borderWidth
      children = [
        killsIcon
        killsText
      ]
    }
    @() {
      watch = timeFillColor
      rendObj = ROBJ_BOX
      size = const [FLEX, blockHeight]
      flow = FLOW_HORIZONTAL
      valign = ALIGN_CENTER
      fillColor = timeFillColor.get()
      borderColor
      borderWidth
      children = [
        timeIcon
        timeText
      ]
    }
  ]
}
