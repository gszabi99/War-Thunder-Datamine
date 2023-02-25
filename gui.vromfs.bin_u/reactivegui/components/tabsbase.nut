from "%rGui/globals/ui_library.nut" import *

let function defTab(tab_item, is_current, handler) {
  let grp = ElemGroup()
  let stateFlags = Watched(0)

  return function () {
    let isHover = (stateFlags.value & S_HOVER)
    local fillColor, textColor
    if (is_current) {
      textColor = isHover ? Color(255, 255, 255) : Color(0, 255, 0)
      fillColor = isHover ? Color(100, 100, 100) : Color(150, 150, 150)
    }
    else {
      textColor = isHover ? Color(255, 255, 255) : Color(255, 255, 0)
      fillColor = isHover ? Color(100, 100, 100) : Color(50, 50, 50)
    }

    return {
      key = tab_item
      rendObj = ROBJ_SOLID
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      size = SIZE_TO_CONTENT
      watch = stateFlags
      group = grp

      color = fillColor

      behavior = Behaviors.Button
      onElemState = @(sf) stateFlags.update(sf)

      onFocus = handler

      children = {
        rendObj = ROBJ_TEXT
        margin = [sh(1), sh(2)]
        color = textColor

        text = tab_item.text
        group = grp
      }
    }
  }
}


let function defHolder(_params) {
  return {
    rendObj = ROBJ_SOLID
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    padding = [0, sh(1)]
    gap = sh(1)

    color = Color(255, 255, 255)
  }
}


let function tabs(holder = defHolder, tab = defTab) {
  return function(params) {
    let children = params.tabs.map(function(item) {
      return tab(item, item.id == params.currentTab, @() params.onChange(item))
    })

    let result = (type(holder) == "function") ? holder(params) : holder
    result.children <- children
    return result
  }
}


return tabs
