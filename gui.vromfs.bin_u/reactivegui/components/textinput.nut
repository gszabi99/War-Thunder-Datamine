from "%rGui/globals/ui_library.nut" import *

let textInput = require("%rGui/components/textInputBase.nut")
let colors = require("%rGui/style/colors.nut")
let focusBorder = require("%rGui/components/focusBorder.nut")


let hudFrame = @(inputObj, group, sf) {
  rendObj = ROBJ_BOX
  size = [flex(), fpx(30) + 2 * (dp() + fpx(3))]
  fillColor = colors.menu.textInputBgColor
  borderColor = colors.menu.textInputBorderColor
  borderWidth = static [hdpx(1), hdpx(1), hdpx(2), hdpx(1)]

  group = group
  children = [ inputObj,
    (sf & S_KB_FOCUS) != 0 ? focusBorder() : null
  ]
}


let export = class {
  hud = @(text_state, options = {}) textInput(text_state, options, hudFrame)
  _call = @(_self, text_state, options = {}) textInput(text_state, options)
}()


return export