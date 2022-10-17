from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let unitTypes = require("%scripts/unit/unitTypesList.nut")

//************************************************************************//
//*********************functions to work with esUnitType******************//
//*******************but better to work with unitTypes enum***************//
//************************************************************************//

::getUnitTypeText <- function getUnitTypeText(esUnitType)
{
  return unitTypes.getByEsUnitType(esUnitType).name
}

::getUnitTypeByText <- function getUnitTypeByText(typeName, caseSensitive = false)
{
  return unitTypes.getByName(typeName, caseSensitive).esUnitType
}

::get_unit_class_icon_by_unit <- function get_unit_class_icon_by_unit(unit, iconName)
{
  let esUnitType = ::get_es_unit_type(unit)
  let t = unitTypes.getByEsUnitType(esUnitType)
  return $"{t.uiClassSkin}{iconName}.svg"
}

::get_unit_icon_by_unit <- function get_unit_icon_by_unit(unit, iconName)
{
  let esUnitType = ::get_es_unit_type(unit)
  let t = unitTypes.getByEsUnitType(esUnitType)
  return $"{t.uiSkin}{iconName}.ddsx"
}

::get_tomoe_unit_icon <- function get_tomoe_unit_icon(iconName, isForGroup = false)
{
  return $"!#ui/unitskin#tomoe_{iconName}{isForGroup ? "_group" : ""}.ddsx"
}

::get_unit_type_font_icon <- function get_unit_type_font_icon(esUnitType)
{
  return unitTypes.getByEsUnitType(esUnitType).fontIcon
}

::get_army_id_by_es_unit_type <- function get_army_id_by_es_unit_type(esUnitType)
{
  return unitTypes.getByEsUnitType(esUnitType).armyId
}

::get_unit_type_army_text <- function get_unit_type_army_text(esUnitType)
{
  return unitTypes.getByEsUnitType(esUnitType).getArmyLocName()
}
