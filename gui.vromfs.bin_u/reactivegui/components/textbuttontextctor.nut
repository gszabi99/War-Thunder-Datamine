local getGamepadHotkeys = require("getGamepadHotkeys.nut")
local { mkImageCompByDargKey } = require("gamepadImgByKey.nut")
local { showConsoleButtons } = require("reactiveGui/ctrlsState.nut")

local gap = ::scrn_tgt(0.005)
return function(textComp, params, handler, group, sf){
  local gamepadHotkey = getGamepadHotkeys(params?.hotkeys)
  if (gamepadHotkey == "")
    return textComp
  local gamepadBtn = mkImageCompByDargKey(gamepadHotkey, sf)
  return function() {
    local ac = showConsoleButtons.value
    return ac ? {
      size = SIZE_TO_CONTENT
      minWidth = ::scrn_tgt(0.16)
      gap = gap
      flow = FLOW_HORIZONTAL
      halign = ALIGN_LEFT
      valign = ALIGN_CENTER
      margin = [0, -gap]
      watch = showConsoleButtons
      children = [
        gamepadBtn
        textComp.__merge({margin = 0})
      ]
    }
    : textComp.__merge({ watch = showConsoleButtons })
  }
}