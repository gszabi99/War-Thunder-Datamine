from "%scripts/langUtils/textFormat.nut" import decimalFormat
from "%scripts/dagui_library.nut" import *

let getCrewSpText = @(sp) $"{decimalFormat(sp)}{loc("currency/skillPoints/sign/colored")}"
let getCrewSpTextIfNotZero = @(sp) sp == 0 ? "" : getCrewSpText(sp)

return freeze({
  getCrewSpText
  getCrewSpTextIfNotZero
})