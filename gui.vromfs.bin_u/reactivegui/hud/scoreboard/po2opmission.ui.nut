from "%rGui/globals/ui_library.nut" import *
let { roundTimeLeft, missionProgressScore } = require("%rGui/missionState.nut")
let { secondsToTimeSimpleString } = require("%sqstd/time.nut")

let timeFillColor = Computed(@() roundTimeLeft.value > 0 ? 0xB200AF0E : 0xB2AF0100)

let blockWidth = hdpx(156)
let iconWidth = (0.33 * blockWidth).tointeger()
let blockHeight = hdpx(36)
let borderWidth = hdpx(2)

let borderColor = 0xFFFFFFFF

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
  size = [flex(), SIZE_TO_CONTENT]
  text = missionProgressScore.value
})

let timeIcon = textParams.__merge({
  size = [iconWidth, SIZE_TO_CONTENT]
  pos = [0, hdpx(2)]  //use this because the font icon is not centered in the font
  text = "╎"
})

let timeText = @() textParams.__merge({
  watch = roundTimeLeft
  size = [flex(), SIZE_TO_CONTENT]
  text = secondsToTimeSimpleString(roundTimeLeft.value)
})

return {
  size = [blockWidth, SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  gap = -borderWidth
  children = [
    {
      rendObj = ROBJ_BOX
      size = [flex(), blockHeight]
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
      size = [flex(), blockHeight]
      flow = FLOW_HORIZONTAL
      valign = ALIGN_CENTER
      fillColor = timeFillColor.value
      borderColor
      borderWidth
      children = [
        timeIcon
        timeText
      ]
    }
  ]
}
