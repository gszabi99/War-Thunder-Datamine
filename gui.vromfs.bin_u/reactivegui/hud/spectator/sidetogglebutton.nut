

import "%appGlobals/style/cssColors.nut" as cssColors
from "%rGui/globals/ui_library.nut" import *
from "%rGui/dagui/units.nut" import cssConst
from "%rGui/components/tooltip.nut" import withHint, tooltipDetach, mkTooltipText

let soundWt = require_optional("sound_wt")

let btnSize = cssConst("mIco")
let iconSize = cssConst("sIco")

function sideToggleButton(p) {
  let { id, attachSide, isOpen, bgColor = 0 } = p
  let sf = Watched(0)
  let image = Picture($"ui/gameuiskin#spinnerListBox_arrow_up.svg:{iconSize}:{iconSize}:K")
  let openRotate = attachSide == "left" ? 270 : 90
  let closedRotate = 360 - openRotate
  
  let tooltipText = @() mkTooltipText(loc(isOpen.get() ? "mainmenu/btnCollapse" : "mainmenu/btnExpand"),
    { watch = isOpen })
  let onElemState = withHint(sf, id, @() tooltipText)
  let onDetach = tooltipDetach(sf, id)
  function onClick() {
    soundWt?.playSound("click")
    isOpen.set(!isOpen.get())
  }
  return function() {
    let isHover = (sf.get() & S_HOVER) != 0
    return {
      watch = [sf, isOpen]
      key = id
      size = btnSize
      rendObj = ROBJ_SOLID
      color = isHover ? cssColors.menuButtonColorHover : bgColor
      behavior = Behaviors.Button
      onElemState
      onDetach
      onClick
      children = {
        size = iconSize
        hplace = ALIGN_CENTER
        vplace = ALIGN_CENTER
        rendObj = ROBJ_IMAGE
        image
        color = isHover ? 0xFFFFFFFF : cssColors.gray
        transform = { rotate = isOpen.get() ? openRotate : closedRotate }
      }
    }
  }
}

return sideToggleButton
