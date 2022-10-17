from "%darg/ui_imports.nut" import *
let {colors} = require("style.nut")


let function nameFilter(watched_text, params) {
  let group = ElemGroup()
  let stateFlags = Watched(0)

  local placeholder = null
  if (params?.placeholder) {
    placeholder = {
      rendObj = ROBJ_TEXT
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
        rendObj = ROBJ_TEXT
        size = [flex(), SIZE_TO_CONTENT]
        margin = fsh(0.5)

        text = watched_text.value ?? " "
        behavior = Behaviors.TextInput
        group

        onChange = params?.onChange
        onEscape = params?.onEscape
        onElemState = @(sf) stateFlags.update(sf)

        children = watched_text.value.len() ? null : placeholder
      }
    }
  }
}


return nameFilter
