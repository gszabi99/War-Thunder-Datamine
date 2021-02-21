local baseButton = require("daRg/components/textButton.nut")

local function textButton(text, action, extra_params={}) {
  local params = {
    font = Fonts.small_text
    margin = [hdpx(1),hdpx(20)]
  }.__merge(extra_params)
  return baseButton(text, action, params)
}

return textButton
