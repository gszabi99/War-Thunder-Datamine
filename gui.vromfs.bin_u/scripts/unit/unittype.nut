local unitTypes = require("scripts/unit/unitTypesList.nut")

//************************************************************************//
//*********************functions to work with esUnitType******************//
//********************but better to work with g_unit_type*****************//
//************************************************************************//

::getUnitTypeText <- function getUnitTypeText(esUnitType)
{
  return unitTypes.getByEsUnitType(esUnitType).name
}

::getUnitTypeByText <- function getUnitTypeByText(typeName, caseSensitive = false)
{
  return unitTypes.getByName(typeName, caseSensitive).esUnitType
}

::get_first_chosen_unit_type <- function get_first_chosen_unit_type(defValue = ::ES_UNIT_TYPE_INVALID)
{
  foreach(unitType in unitTypes.types)
    if (unitType.isFirstChosen())
      return unitType.esUnitType
  return defValue
}

::get_unit_class_icon_by_unit <- function get_unit_class_icon_by_unit(unit, iconName)
{
  local esUnitType = ::get_es_unit_type(unit)
  local t = unitTypes.getByEsUnitType(esUnitType)
  local fileExt = esUnitType == ::ES_UNIT_TYPE_AIRCRAFT ? ".svg" : ""
  return $"{t.uiClassSkin}{iconName}{fileExt}"
}

::get_unit_icon_by_unit <- function get_unit_icon_by_unit(unit, iconName)
{
  local esUnitType = ::get_es_unit_type(unit)
  local t = unitTypes.getByEsUnitType(esUnitType)
  return t.uiSkin + iconName
}

::get_tomoe_unit_icon <- function get_tomoe_unit_icon(iconName)
{
  return "!#ui/unitskin#tomoe_" + iconName
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
