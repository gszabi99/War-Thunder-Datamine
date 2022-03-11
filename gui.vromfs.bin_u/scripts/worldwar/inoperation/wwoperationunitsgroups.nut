let { getUnitRole } = require("scripts/unit/unitInfoTexts.nut")
let { getOperationById } = require("scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")
let { UNIT_GROUP } = require("scripts/utils/genericTooltipTypes.nut")

let function getUnitsGroups() {
  let unitsGroupByCountry = getOperationById(
    ::ww_get_operation_id())?.getMap().getUnitsGroupsByCountry()
  if (unitsGroupByCountry == null)
    return null

  let fullGroupsList = {}
  foreach (country in unitsGroupByCountry)
    fullGroupsList.__update(country.groups)
  return fullGroupsList
}

let function overrideUnitViewParamsByGroups(wwUnitViewParams, unitsGroups) {
  let group = unitsGroups?[wwUnitViewParams.id]
  if (group == null)
    return wwUnitViewParams

  let defaultUnit = group?.defaultUnit
  wwUnitViewParams.name         = ::loc(group.name)
  wwUnitViewParams.icon         = ::getUnitClassIco(defaultUnit)
  wwUnitViewParams.shopItemType = getUnitRole(defaultUnit)
  wwUnitViewParams.tooltipId    = UNIT_GROUP.getTooltipId(group)
  wwUnitViewParams.hasPresetWeapon = false
  return wwUnitViewParams
}

let function overrideUnitsViewParamsByGroups(wwUnitsViewParams) {
  let unitsGroups = getUnitsGroups()
  if (unitsGroups == null)
    return wwUnitsViewParams

  return wwUnitsViewParams.map(@(wwUnit) overrideUnitViewParamsByGroups(wwUnit, unitsGroups))
}

return {
  getUnitsGroups
  overrideUnitViewParamsByGroups
  overrideUnitsViewParamsByGroups
}