local {colors} = require("style.nut")


local function nameFilter(watched_text, params) {
  local group = ::ElemGroup()
  local stateFlags = Watched(0)

  local placeholder = null
  if (params?.placeholder) {
    placeholder = {
      rendObj = ROBJ_DTEXT
      text = params.placeholder
      color = Color(160, 160, 160)
    }
  }

  return @() {
    size = [flex(), SIZE_TO_CONTENT]
    watch = [watched_text, stateFlags]

    rendObj = ROBJ_SOLID
    color = colors.ControlBg

    children = {
      size = [flex(), SIZE_TO_CONTENT]
      rendObj = ROBJ_FRAME
      color = (stateFlags.value & S_KB_FOCUS) ? colors.FrameActive : colors.FrameDefault
      group = group

      children = {
        rendObj = ROBJ_DTEXT
        size = [flex(), fontH(100)]
        margin = sh(0.5)

        text = watched_text.value
        behavior = Behaviors.TextInput
        group = group

        onChange = params?.onChange
        onEscape = params?.onEscape
        onElemState = @(sf) stateFlags.update(sf)

        children = watched_text.value.len() ? null : placeholder
      }
    }
  }
}


return nameFilter
