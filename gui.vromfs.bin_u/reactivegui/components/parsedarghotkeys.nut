local {strip, startswith} = require("string")

local function parse(hotkey){
  local hotkeys_list = hotkey.replace("^", "").split("|")
  hotkeys_list = hotkeys_list.map(@(v) strip(v))
  local gamepadUiBtns = hotkeys_list.filter(@(v) startswith(v,"J:"))
  local dainputBtns = hotkeys_list.filter(@(v) startswith(v,"@"))
  local kbdUiBtns = hotkeys_list.filter(@(v) !(startswith(v,"J:") || startswith(v,"@")))
  return {gamepad = gamepadUiBtns, dainput = dainputBtns, kbd = kbdUiBtns}
}

return parse