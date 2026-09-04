import "%rGui/components/getGamepadHotkeys.nut" as getGamepadHotkeys
import "%rGui/components/focusBorder.nut" as focusBorder
from "%rGui/components/gamepadImgByKey.nut" import mkImageCompByDargKey
from "%rGui/ctrlsState.nut" import showConsoleButtons
from "%rGui/globals/ui_library.nut" import *

let gap = scrn_tgt(0.005)
return function(textComp, params, _handler, _group, sf) {
  let gamepadHotkey = getGamepadHotkeys(params?.hotkeys)
  if (gamepadHotkey == "")
    return textComp
  let gamepadBtn = mkImageCompByDargKey(gamepadHotkey, sf)
  return [
    function() {
      let ac = showConsoleButtons.get()
      return ac ? {
        size = SIZE_TO_CONTENT
        minWidth = scrn_tgt(0.16)
        gap = gap
        flow = FLOW_HORIZONTAL
        halign = ALIGN_LEFT
        valign = ALIGN_CENTER
        margin = [fpx(3), scrn_tgt(0.005) - gap]
        watch = showConsoleButtons
        children = [
          gamepadBtn
          textComp.__merge({ margin = 0, padding = [0, fpx(6), 0, 0] })
        ]
      }
      : textComp.__merge({ watch = showConsoleButtons, padding = [0, fpx(6), 0, fpx(6)] })
    },
    (sf & S_HOVER) != 0 ? focusBorder() : null
  ]
}