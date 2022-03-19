local  AT_RUNWAY = {
  name = "AT_RUNWAY"
  objName = "airfield"
  locId = "air"
  spriteType = "Airfield"
  configurableValue = "airArmiesLimitPerArmyGroup"
  wwUnitClass = WW_UNIT_CLASS.FIGHTER
  unitType = ::g_ww_unit_type.AIR
  overrideUnitType = null
  flyoutSound = "ww_unit_move_airplanes"
}

local  AT_HELIPAD = {
  name = "AT_HELIPAD"
  objName = "helipad"
  locId = "helicopter"
  spriteType = "Helipad"
  configurableValue = "helicopterArmiesLimitPerArmyGroup"
  wwUnitClass = WW_UNIT_CLASS.HELICOPTER
  unitType = ::g_ww_unit_type.HELICOPTER
  overrideUnitType = ::g_ww_unit_type.HELICOPTER.code
  flyoutSound = "ww_unit_move_helicopters"
}

return {
  AT_RUNWAY  = AT_RUNWAY
  AT_HELIPAD = AT_HELIPAD
}