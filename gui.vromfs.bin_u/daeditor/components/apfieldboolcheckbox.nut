from "%darg/ui_imports.nut" import *
from "style.nut" import colors

function fieldBoolCheckbox(desc) {
  let { comp_name, value, setValue, readOnly } = desc

  let group = ElemGroup()
  let stateFlags = Watched(0)
  let hoverFlag = Computed(@() stateFlags.get() & S_HOVER)

  function onClick() {
    if (!readOnly)
      setValue(!value.get())
  }

  return function () {
    local mark = null
    if (value.get()) {
      mark = {
        rendObj = ROBJ_SOLID
        color = readOnly ? colors.ReadOnly : (hoverFlag.get() != 0) ? colors.Hover : colors.Interactive
        group
        size = const [pw(50), ph(50)]
        hplace = ALIGN_CENTER
        vplace = ALIGN_CENTER
      }
    }

    return {
      key = comp_name
      size = const [flex(), fontH(100)]
      halign = ALIGN_LEFT
      valign = ALIGN_CENTER

      watch = [value, hoverFlag]

      children = {
        size = const [fontH(80), fontH(80)]
        rendObj = ROBJ_SOLID
        color = colors.ControlBg

        behavior = Behaviors.Button
        group

        children = mark

        onElemState = @(sf) stateFlags.set(sf)

        onClick
      }
    }
  }
}

return fieldBoolCheckbox
