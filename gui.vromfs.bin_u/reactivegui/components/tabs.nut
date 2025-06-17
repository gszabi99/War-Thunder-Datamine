from "%rGui/globals/ui_library.nut" import *

let tabsBase = require("tabsBase.nut")
let colors = require("%rGui/style/colors.nut")
let fontsState = require("%rGui/style/fontsState.nut")


function tabCtor(tab, is_current, handler) {
  let grp = ElemGroup()
  let stateFlags = Watched(0)

  return function() {
    let isHover = (stateFlags.value & S_HOVER)
    let isActive = (stateFlags.value & S_ACTIVE)
    local fillColor, textColor, borderColor
    if (is_current) {
      textColor = colors.menu.activeTextColor
      fillColor = colors.menu.listboxSelOptionColor
      borderColor = colors.menu.headerOptionSelectedColor
    }
    else {
      textColor = isHover ? colors.menu.headerOptionSelectedTextColor : colors.menu.headerOptionTextColor
      fillColor = colors.transparent
      borderColor = isActive && isHover ? colors.menu.headerOptionSelectedColor :
        isHover ? colors.menu.headerOptionHoverColor :
        colors.transparent
    }

    return {
      key = tab
      rendObj = ROBJ_BOX
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      size = [ SIZE_TO_CONTENT, fpx(30) + 2 * (dp() + fpx(3))]
      watch = stateFlags
      group = grp
      padding = [fpx(2) + scrn_tgt(0.005), scrn_tgt(0.01), scrn_tgt(0.005), scrn_tgt(0.01)]
      margin = [0, dp()]
      behavior = Behaviors.Button

      fillColor = fillColor
      borderColor = borderColor
      borderWidth = [0, 0, dp(2), 0]

      onClick = handler
      onElemState = @(sf) stateFlags.update(sf)

      children = {
        rendObj = ROBJ_TEXT
        font = fontsState.get("small")
        color = textColor
        text = tab.text
        group = grp
      }
    }
  }
}


let tabsHolder = @(_params) {
  rendObj = ROBJ_SOLID
  size = FLEX_H
  flow = FLOW_HORIZONTAL
  padding = [dp(2)]
  gap = dp()

  color = colors.menu.tabBackgroundColor
}


return tabsBase(tabsHolder, tabCtor)
