from "%darg/ui_imports.nut" import *

let baseStyle = require("multiselect.style.nut")

let mkMultiselect = @(selected /*Watched({ <key> = true })*/, options /*[{ key, text }, ...]*/, minOptions = 0, maxOptions = 0, rootOverride = {}, style = baseStyle)
  function() {
    let numSelected = Computed(@() selected.value.filter(@(v) v).len())
    let mkOnClick = @(option) function() {
      let curVal = selected.value?[option.key] ?? false
      let resultNum = numSelected.value + (curVal ? -1 : 1)
      if ((minOptions == 0 || resultNum >= minOptions) //result num would
          && (maxOptions==0 || resultNum <= maxOptions))
        selected.mutate(function(s) { s[option.key] <- !curVal })

    }
    return style.root.__merge({
      watch = selected
      children = options.map(@(option) style.optionCtor(option, selected.value?[option.key] ?? false, mkOnClick(option)))
    })
    .__merge(rootOverride)
 }

return kwarg(mkMultiselect)
