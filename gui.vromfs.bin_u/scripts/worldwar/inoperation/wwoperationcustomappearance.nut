local getCustomAppearance = @(mapName) ::g_world_war.getSetting("mapCustomAppearance", null)?[mapName]

local function getCustomViewCountryData(countryName, mapName = null) {
  mapName = mapName ?? ::g_ww_global_status.getOperationById(::ww_get_operation_id())?.getMapId() ?? ""
  local customAppearance = getCustomAppearance(mapName)?[countryName]
  return {
    icon = ::get_country_icon(customAppearance?.flag ?? countryName)
    locId = customAppearance?.name ?? countryName
  }
}

return {
  getCustomViewCountryData = getCustomViewCountryData
}