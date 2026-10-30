from "%scripts/unit/unitInfoRoles.nut" import getUnitRole
from "%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut" import getOperationById
from "%scripts/utils/genericTooltipTypes.nut" import getTooltipType
from "%scripts/unit/unitInfoTexts.nut" import getUnitClassIco
from "worldwar" import wwGetOperationId
from "%scripts/dagui_library.nut" import *

function getUnitsGroups() {
  let unitsGroupByCountry = getOperationById(
    wwGetOperationId())?.getMap().getUnitsGroupsByCountry()
  if (unitsGroupByCountry == null)
    return null

  let fullGroupsList = {}
  foreach (country in unitsGroupByCountry)
    fullGroupsList.__update(country.groups)
  return fullGroupsList
}

function overrideUnitViewParamsByGroups(wwUnitViewParams, unitsGroups) {
  let group = unitsGroups?[wwUnitViewParams.id]
  if (group == null)
    return wwUnitViewParams

  let defaultUnit = group?.defaultUnit
  wwUnitViewParams.name         = loc(group.name)
  wwUnitViewParams.icon         = getUnitClassIco(defaultUnit)
  wwUnitViewParams.shopItemType = getUnitRole(defaultUnit)
  wwUnitViewParams.tooltipId    = getTooltipType("UNIT_GROUP").getTooltipId(group)
  wwUnitViewParams.hasPresetWeapon = false
  return wwUnitViewParams
}

function overrideUnitsViewParamsByGroups(wwUnitsViewParams) {
  let unitsGroups = getUnitsGroups()
  if (unitsGroups == null)
    return wwUnitsViewParams

  return wwUnitsViewParams.map(@(wwUnit) overrideUnitViewParamsByGroups(wwUnit, unitsGroups))
}

return freeze({
  getUnitsGroups
  overrideUnitViewParamsByGroups
  overrideUnitsViewParamsByGroups
})