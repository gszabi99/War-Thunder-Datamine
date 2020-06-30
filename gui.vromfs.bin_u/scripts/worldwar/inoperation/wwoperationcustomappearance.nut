local getCustomAppearance = @(mapName) ::g_world_war.getSetting("mapCustomAppearance", null)?[mapName]

local function getCustomViewCountryData(countryName, mapName = null, needIconId = false) {
  mapName = mapName ?? ::g_ww_global_status.getOperationById(::ww_get_operation_id())?.getMapId() ?? ""
  local customAppearance = getCustomAppearance(mapName)?[countryName]
  local iconId = customAppearance?.flag ?? countryName
  return {
    icon = needIconId ? iconId : ::get_country_icon(iconId)
    locId = customAppearance?.name ?? countryName
  }
}

return {
  getCustomViewCountryData = getCustomViewCountryData
}