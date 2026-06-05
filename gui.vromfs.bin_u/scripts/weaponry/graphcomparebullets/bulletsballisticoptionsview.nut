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

return {
  mkSliderMarkup
}
