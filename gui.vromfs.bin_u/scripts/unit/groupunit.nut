local function getGroupUnitMarkUp(name, unit, group, overrideParams = {}) {
  local params = {
    status = "owned"
    inactive = true
    isLocalState = false
    needMultiLineName = true
    tooltipParams = { showLocalState = false }
    tooltipId = ::g_tooltip_type.UNIT_GROUP.getTooltipId(group)
  }.__update(overrideParams)

  if (group != null)
    unit = {
      name = name
      nameLoc = overrideParams?.nameLoc ?? ""
      image = ::image_for_air(unit)
      isFakeUnit = true
    }

  return ::build_aircraft_item(name, unit, params)
}


return {
  getGroupUnitMarkUp = getGroupUnitMarkUp
}