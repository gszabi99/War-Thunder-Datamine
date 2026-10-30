


from "%rGui/globals/ui_library.nut" import *
from "%rGui/dagui/units.nut" import cssConst, px
from "%rGui/components/text.nut" import mkText
import "%rGui/style/fontsState.nut" as fontsState
import "%appGlobals/style/cssColors.nut" as cssColors

let soundWt = require_optional("sound_wt")

let headerFont = fontsState.get("medium")
let itemFont = fontsState.get("normal")
let dpPx = cssConst("dp")
let itemH = cssConst("baseTrHeight")
let blockInterval = cssConst("blockInterval")
let itemMarginLeft = px("3*@sf/@pf_outdated")
let headerText = loc("mainmenu/navigation")

function navItem(item, idx, state, onSelect) {
  let sf = Watched(0)
  let text = item?.text ?? item?.id ?? ""
  return function() {
    let isSelected = state.get() == idx
    let isHover = (sf.get() & S_HOVER) != 0
    return {
      watch = [state, sf]
      size = [flex(), itemH]
      margin = [0, 0, 0, itemMarginLeft]
      rendObj = ROBJ_SOLID
      color = isSelected ? cssColors.listboxSelOptionColor
        : isHover ? cssColors.listboxHoverOptionColor
        : 0
      behavior = Behaviors.Button
      onElemState = @(s) sf.set(s)
      function onClick() {
        soundWt?.playSound("click")
        if (!isSelected)
          onSelect?(idx)
      }
      children = mkText(text, itemFont,
        isSelected ? cssColors.missionUnlockedSelectColor
          : isHover ? cssColors.missionUnlockedHoverColor
          : cssColors.missionUnlockedColor,
        { pos = [itemH + blockInterval, 0], vplace = ALIGN_CENTER })
    }
  }
}

function navigationPanel(p, state, onSelect = null) {
  let panelW = px(p?.panelWidth ?? "@defaultNavPanelWidth")
  let headerH = px(p?.headerHeight ?? "0.05@sf")
  let offsetX = px(p?.headerOffsetX ?? "0.015@sf")
  let offsetY = px(p?.headerOffsetY ?? "0.015@sf")
  let items = p?.items ?? []
  if (items.len() < 2)
    return null
  let innerW = panelW - 2 * blockInterval - dpPx
  let headerW = innerW - 2 * offsetX
  return {
    size = [panelW, flex()]
    flow = FLOW_HORIZONTAL
    children = [
      {
        size = [innerW, flex()]
        flow = FLOW_VERTICAL
        children = [
          {
            size = [headerW, headerH]
            margin = [offsetY, offsetX]
            halign = ALIGN_CENTER
            valign = ALIGN_CENTER
            children = mkText(headerText, headerFont, cssColors.activeTextColor)
          }
          {
            size = flex()
            flow = FLOW_VERTICAL
            clipChildren = true
            children = items.map(@(item, idx) navItem(item, idx, state, onSelect))
          }
        ]
      }
      {
        size = [dpPx, flex()]
        margin = [0, blockInterval]
        rendObj = ROBJ_SOLID
        color = cssColors.separatorBlockColor
      }
    ]
  }
}

return navigationPanel
