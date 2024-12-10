from "%scripts/dagui_natives.nut" import is_default_aircraft

function isUnitDefault(unit) {
  if (!("name" in unit))
    return false
  return is_default_aircraft(unit.name)
}

return {
  isUnitDefault
}