local getGamepadHotkeys = require("getGamepadHotkeys.nut")
local { mkImageCompByDargKey } = require("gamepadImgByKey.nut")
local { showConsoleButtons } = require("reactiveGui/ctrlsState.nut")
local focusBorder = require("reactiveGui/components/focusBorder.nut")

local gap = ::scrn_tgt(0.005)
return function(textComp, params, handler, group, sf){
  local gamepadHotkey = getGamepadHotkeys(params?.hotkeys)
  if (gamepadHotkey == "")
    return textComp
  local gamepadBtn = mkImageCompByDargKey(gamepadHotkey, sf)
  return [
    function() {
      local ac = showConsoleButtons.value
      return ac ? {
        size = SIZE_TO_CONTENT
        minWidth = ::scrn_tgt(0.16)
        gap = gap
        flow = FLOW_HORIZONTAL
        halign = ALIGN_LEFT
        valign = ALIGN_CENTER
        margin = [::fpx(3), ::scrn_tgt(0.005)-gap]
        watch = showConsoleButtons
        children = [
          gamepadBtn
          textComp.__merge({margin = 0})
        ]
      }
      : textComp.__merge({ watch = showConsoleButtons })
    },
    (sf & S_HOVER) != 0 ? focusBorder() : null
  ]
}