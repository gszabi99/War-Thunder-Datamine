from "%sqstd/math.nut" import round_by_value
from "%scripts/dagui_library.nut" import *

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")

function mkSliderMarkup(option) {
  return handyman.renderCached("%gui/dmViewer/distanceSlider.tpl", {
    containerId = $"container_{option.id}"
    id = option.id
    sliderWidth = "p.p.w"
    min = option.minValue
    max = option.maxValue
    value = option.value
    step = option.step
    btnOnDec = "onButtonDec"
    btnOnInc = "onButtonInc"
    onChangeSliderValue = "onChangeSliderValue"
  })
}

function mkModeButtonsMarkup(option) {
  let { id, values, value, getItemText } = option
  let btnWidth = $"{round_by_value(1.0 / values.len(), 0.001)}pw"
  local buttons = ""
  foreach (idx, itemValue in values)
    buttons = "".concat(buttons, handyman.renderCached("%gui/commonParts/button.tpl", {
      id = $"{id}_{idx}"
      holderId = idx.tostring()
      btnWidth
      text = getItemText(itemValue)
      onClick = "onChangeShotSettingMode"
      actionParamsMarkup = $"noMargin:t='yes'; {itemValue == value ? "selected:t='yes';" : ""}"
    }))

  return "".concat("tdiv { id:t='", id, "'; width:t='pw'; ", buttons, " }")
}

return {
  mkSliderMarkup
  mkModeButtonsMarkup
}
