let formatters = require("textFormatters.nut")
let {defStyle} = formatters
let filter = function(object) {
  return !(object?.platform == null || object.platform.indexof(::get_platform())!=null
    || (::cross_call.platform.is_pc() && object.platform.indexof("pc")!=null))
}
let formatText = require("%darg/helpers/mkFormatAst.nut")({formatters=formatters, style=defStyle, filter})

return {
  formatText
  defStyle
}
