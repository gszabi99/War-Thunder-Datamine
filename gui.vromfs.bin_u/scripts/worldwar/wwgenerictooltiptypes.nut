from "%scripts/utils/genericTooltipTypes.nut" import getTooltipType
from "%scripts/dagui_library.nut" import *

let wwTooltipTypes = {}

return freeze({
  setWwTooltipTypes = @(tooltipTypes) wwTooltipTypes.__update(tooltipTypes)
  getWwTooltipType = @(typeName) wwTooltipTypes?[typeName] ?? getTooltipType("EMPTY")
})
