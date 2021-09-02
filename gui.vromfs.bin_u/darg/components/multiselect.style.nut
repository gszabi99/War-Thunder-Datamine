local calcColor = @(sf) (sf & S_HOVER) ? 0xFFFFFFFF : 0xA0A0A0A0

local lineWidth = hdpx(2)
local boxSize = hdpx(20)

local function box(isSelected, sf) {
  local color = calcColor(sf)
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
          color = color
        }
      : null
  }
}

local label = @(text, sf) {
  size = [flex(), SIZE_TO_CONTENT]
  rendObj = ROBJ_DTEXT
  color = calcColor(sf)
  text = text
}

local function optionCtor(option, isSelected, onClick) {
  local stateFlags = ::Watched(0)
  return function() {
    local sf = stateFlags.value

    return {
      size = [flex(), SIZE_TO_CONTENT]
      watch = stateFlags
      behavior = Behaviors.Button
      onElemState = @(s) stateFlags(s)
      onClick = onClick
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
  optionCtor = optionCtor
}