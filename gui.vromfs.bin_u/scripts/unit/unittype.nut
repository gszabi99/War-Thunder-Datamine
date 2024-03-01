from "%scripts/dagui_library.nut" import *

let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { getEsUnitType } = require("%scripts/unit/unitInfo.nut")

//************************************************************************//
//*********************functions to work with esUnitType******************//
//*******************but better to work with unitTypes enum***************//
//************************************************************************//

::getUnitTypeText <- function getUnitTypeText(esUnitType) {
  return unitTypes.getByEsUnitType(esUnitType).name
}

::getUnitTypeByText <- function getUnitTypeByText(typeName, caseSensitive = false) {
  return unitTypes.getByName(typeName, caseSensitive).esUnitType
}

::get_unit_icon_by_unit <- function get_unit_icon_by_unit(unit, iconName) {
  let esUnitType = getEsUnitType(unit)
  let t = unitTypes.getByEsUnitType(esUnitType)
  return $"{t.uiSkin}{iconName}.ddsx"
}

::get_tomoe_unit_icon <- function get_tomoe_unit_icon(iconName, isForGroup = false) {
  return $"!#ui/unitskin#tomoe_{iconName}{isForGroup ? "_group" : ""}.ddsx"
}

::get_unit_type_font_icon <- function get_unit_type_font_icon(esUnitType) {
  return unitTypes.getByEsUnitType(esUnitType).fontIcon
}

::get_army_id_by_es_unit_type <- function get_army_id_by_es_unit_type(esUnitType) {
  return unitTypes.getByEsUnitType(esUnitType).armyId
}
