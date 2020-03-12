local Color = ::Color
local contextStyle = {
  menuBgColor = Color(20, 30, 36)
  listItem = function (text, action) {
    local group = ::ElemGroup()
    local stateFlags = ::Watched(0)

    return @() {
      behavior = Behaviors.Button
      rendObj = ROBJ_SOLID
      color = (stateFlags.value & S_HOVER) ? Color(68, 80, 87) : Color(20, 30, 36)
      size = [flex(), SIZE_TO_CONTENT]
      group = group
      watch = stateFlags

      onClick = action
      onElemState = @(sf) stateFlags.update(sf)

      children = {
        rendObj = ROBJ_DTEXT
        margin = sh(0.5)
        text = text
        group = group
        color = (stateFlags.value & S_HOVER) ? Color(255,255,255) : Color(120,150,160)
      }
    }
  }
}

return contextStyle
