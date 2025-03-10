from "%scripts/dagui_library.nut" import *

const FULL_ID_SEPARATOR = "."
const DEFAULT_WB_FONT_ICON = "currency/warbond/green"
const MAX_ALLOWED_WARBONDS_BALANCE = 0x7fffffff 

let maxAllowedWarbondsBalance = mkWatched(persist, "maxAllowedWarbondsBalance", MAX_ALLOWED_WARBONDS_BALANCE)

let getWarbondPriceText = @(amount) !amount ? ""  : $"{amount}{loc(DEFAULT_WB_FONT_ICON)}"

return {
  FULL_ID_SEPARATOR
  DEFAULT_WB_FONT_ICON
  getWarbondPriceText
  maxAllowedWarbondsBalance
}