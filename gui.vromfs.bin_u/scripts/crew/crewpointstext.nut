from "%scripts/dagui_library.nut" import *

let { decimalFormat } = require("%scripts/langUtils/textFormat.nut")

let getCrewSpText = @(sp) $"{decimalFormat(sp)}{loc("currency/skillPoints/sign/colored")}"
let getCrewSpTextIfNotZero = @(sp) sp == 0 ? "" : getCrewSpText(sp)

return {
  getCrewSpText
  getCrewSpTextIfNotZero
}