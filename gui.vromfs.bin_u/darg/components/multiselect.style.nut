from "%darg/ui_imports.nut" import *

let calcColor = @(sf) (sf & S_HOVER) ? 0xFFFFFFFF : 0xA0A0A0A0

let lineWidth = hdpx(2)
let boxSize = hdpx(20)

let function box(isSelected, sf) {
  let color = calcColor(sf)
  return {
    size = [boxSize, boxSize]
    rendObj = ROBJ_BOX
    fillColor = 0xFF000000
    borderWidth = lineWidth
    borderColor = color
    padding = 2 * lineWidth
    children = isSelected
      ? {
          size = flex()
          rendObj = ROBJ_SOLID
          color
        }
      : null
  }
}

let label = @(text, sf) {
  size = [flex(), SIZE_TO_CONTENT]
  rendObj = ROBJ_TEXT
  color = calcColor(sf)
  text = text
}

let function optionCtor(option, isSelected, onClick) {
  let stateFlags = Watched(0)
  return function() {
    let sf = stateFlags.value

    return {
      size = [flex(), SIZE_TO_CONTENT]
      watch = stateFlags
      behavior = Behaviors.Button
      onElemState = @(s) stateFlags(s)
      onClick
      stopHover = true
      flow = FLOW_HORIZONTAL
      valign = ALIGN_CENTER
      gap = hdpx(5)
      children = [
        box(isSelected, sf)
        label(option.text, sf)
      ]
    }
  }
}

return {
  root = {
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    gap = hdpx(5)
  }
  optionCtor
}