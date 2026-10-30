from "%scripts/utils/genericTooltipTypes.nut" import getTooltipType
from "%scripts/slotbar/slotbarView.nut" import buildUnitSlot
from "%scripts/unit/unitInfo.nut" import image_for_air
from "%scripts/dagui_library.nut" import *

function getGroupUnitMarkUp(name, unit, group, overrideParams = {}) {
  let params = {
    status = "owned"
    inactive = true
    isLocalState = false
    needMultiLineName = true
    tooltipParams = { showLocalState = false }
    tooltipId = getTooltipType("UNIT_GROUP").getTooltipId(group)
  }.__update(overrideParams)

  if (group != null)
    unit = {
      name = name
      nameLoc = overrideParams?.nameLoc ?? ""
      image = image_for_air(unit)
      isFakeUnit = true
    }

  return buildUnitSlot(name, unit, params)
}


return freeze({
  getGroupUnitMarkUp
})