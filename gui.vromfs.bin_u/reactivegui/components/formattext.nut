from "%sqstd/platform.nut" import is_pc, platformId
from "%rGui/globals/ui_library.nut" import *

let formatters = require("%rGui/components/textFormatters.nut")
let { defStyle } = formatters
function filter(object) {
  return !(object?.platform == null || object.platform.indexof(platformId) != null
    || (is_pc && object.platform.indexof("pc") != null))
}
let formatText = require("%darg/helpers/mkFormatAst.nut")({ formatters, style = defStyle, filter })

return {
  formatText
  defStyle
}
