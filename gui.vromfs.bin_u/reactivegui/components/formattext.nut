local formatters = require("textFormatters.nut")
local {defStyle} = formatters
local filter = function(object) {
  return !(object?.platform == null || object.platform.indexof(::get_platform())!=null
    || (::cross_call.platform.is_pc() && object.platform.indexof("pc")!=null))
}
local formatText = require("daRg/components/mkFormatAst.nut")({formatters=formatters, style=defStyle, filter=filter})

return {
  formatText = formatText
  defStyle = defStyle
}
