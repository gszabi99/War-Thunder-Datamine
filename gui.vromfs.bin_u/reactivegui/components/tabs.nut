local tabsBase = require("daRg/components/tabs.nut")
local colors = require("reactiveGui/style/colors.nut")
local fontsState = require("reactiveGui/style/fontsState.nut")


local function tabCtor(tab, is_current, handler) {
  local grp = ::ElemGroup()
  local stateFlags = ::Watched(0)

  return function() {
    local isHover = (stateFlags.value & S_HOVER)
    local isActive = (stateFlags.value & S_ACTIVE)
    local fillColor, textColor, borderColor
    if (is_current) {
      textColor = colors.menu.activeTextColor
      fillColor = colors.menu.listboxSelOptionColor
      borderColor = colors.menu.headerOptionSelectedColor
    } else {
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
      size = [ SIZE_TO_CONTENT, ::fpx(30) + 2 * (::dp() + ::fpx(3))]
      watch = stateFlags
      group = grp
      padding = [::fpx(2)+ ::scrn_tgt(0.005), ::scrn_tgt(0.01), ::scrn_tgt(0.005), ::scrn_tgt(0.01)]
      margin = [0, ::dp()]
      behavior = Behaviors.Button

      fillColor = fillColor
      borderColor = borderColor
      borderWidth = [0, 0, ::dp(2), 0]

      onClick = handler
      onElemState = @(sf) stateFlags.update(sf)

      children = {
        rendObj = ROBJ_DTEXT
        font = fontsState.get("small")
        color = textColor
        text = tab.text
        group = grp
      }
    }
  }
}


local tabsHolder = @(params){
  rendObj = ROBJ_SOLID
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_HORIZONTAL
  padding = [::dp(2)]
  gap = ::dp()

  color = colors.menu.tabBackgroundColor
}


return tabsBase(tabsHolder, tabCtor)
