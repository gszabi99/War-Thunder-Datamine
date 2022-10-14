from "%rGui/globals/ui_library.nut" import *

let {strip, startswith} = require("string")

let function parse(hotkey){
  local hotkeys_list = hotkey.replace("^", "").split("|")
  hotkeys_list = hotkeys_list.map(@(v) strip(v))
  let gamepadUiBtns = hotkeys_list.filter(@(v) startswith(v,"J:"))
  let dainputBtns = hotkeys_list.filter(@(v) startswith(v,"@"))
  let kbdUiBtns = hotkeys_list.filter(@(v) !(startswith(v,"J:") || startswith(v,"@")))
  return {gamepad = gamepadUiBtns, dainput = dainputBtns, kbd = kbdUiBtns}
}

return parse