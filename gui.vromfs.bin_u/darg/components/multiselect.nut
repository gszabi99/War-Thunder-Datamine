local baseStyle = require("multiselect.style.nut")

local mkMultiselect = @(selected /*Watched({ <key> = true })*/, options /*[{ key, text }, ...]*/, minOptions = 0, maxOptions = 0, rootOverride = {}, style = baseStyle)
  function() {
    local numSelected = ::Computed(@() selected.value.filter(@(v,k) v).len())
    local mkOnClick = @(option) function() {
      local curVal = selected.value?[option.key] ?? false
      local resultNum = numSelected.value + (curVal ? -1 : 1)
      if ((minOptions == 0 || resultNum >= minOptions) //result num would
          && (maxOptions==0 || resultNum <= maxOptions))
        selected(function(s) { s[option.key] <- !curVal })

    }
    return style.root.__merge({
      watch = selected
      children = options.map(@(option) style.optionCtor(option, selected.value?[option.key] ?? false, mkOnClick(option)))
    })
    .__merge(rootOverride)
 }

return ::kwarg(mkMultiselect)
