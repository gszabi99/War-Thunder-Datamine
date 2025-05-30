from "%scripts/dagui_library.nut" import *

let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")

let wwTooltipTypes = {}

return {
  setWwTooltipTypes = @(tooltipTypes) wwTooltipTypes.__update(tooltipTypes)
  getWwTooltipType = @(typeName) wwTooltipTypes?[typeName] ?? getTooltipType("EMPTY")
}
