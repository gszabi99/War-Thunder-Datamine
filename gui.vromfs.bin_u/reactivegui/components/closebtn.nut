from "%rGui/globals/ui_library.nut" import *

let colors = require("%rGui/style/colors.nut")
let JB = require("%rGui/control/gui_buttons.nut")

let closeButtonHeight = scrn_tgt(0.045)
let function closeBtn(override) {
  let stateFlags = Watched(0)
  return @() {
    size = [closeButtonHeight, closeButtonHeight]
    rendObj = ROBJ_SOLID
    watch = stateFlags
    color = stateFlags.value & S_ACTIVE ? colors.menu.buttonCloseColorPushed
      : stateFlags.value & S_HOVER ? colors.menu.buttonCloseColorHover
      : colors.transparent
    behavior = Behaviors.Button
    onClick = null
    onElemState = @(v) stateFlags(v)
    hplace = ALIGN_RIGHT
    hotkeys = [["Esc | {0}".subst(JB.B)]]
    children = {
      rendObj = ROBJ_IMAGE
      size = flex()
      image = Picture($"!ui/gameuiskin#btn_close.svg:{closeButtonHeight}:{closeButtonHeight}:K")
      color = colors.white
    }
  }.__merge(override)
}

return closeBtn
