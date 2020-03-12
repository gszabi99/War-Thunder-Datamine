local textInputBase = require("daRg/components/textInput.nut")
local colors = require("reactiveGui/style/colors.nut")


local hudFrame = function(inputObj, group, sf) {
  return {
    rendObj = ROBJ_BOX
    size = [flex(), ::fpx(30) + 2 * (::dp() + ::fpx(3))]
    fillColor = colors.menu.textInputBgColor
    borderColor = colors.menu.textInputBorderColor
    borderWidth = [::dp()]

    group = group
    children = inputObj
  }
}


local export = class {
  hud = @(text_state, options={}, handlers={}) textInputBase(text_state, options, handlers, hudFrame)
  _call = @(self, text_state, options={}, handlers={}) textInputBase(text_state, options, handlers)
}()


return export